// Global package management bridge. Reuses Pi's own PackageManager and
// SettingsManager (same code paths as `pi install/remove/config`), so enable
// patterns and settings writes stay byte-identical with the CLI.
import path from "node:path";
import { pathToFileURL } from "node:url";
import { WorkspaceError } from "./workspace_rpc.mjs";

const fail = (code) => {
  throw new WorkspaceError(code);
};
const text = (value) =>
  typeof value === "string" && value.trim() && !value.includes("\0");

const RESOURCE_TYPES = ["extensions", "skills", "prompts", "themes"];
// The settings page manages the user scope only; the cwd equals the agent
// directory so project-local resources never leak into this view.

export class GuiPackagesBridge {
  constructor({ packageRoot, emit }) {
    this.packageRoot = packageRoot;
    this.emit = emit;
    this.sdk = null;
    this.context = null;
    this.mutations = Promise.resolve();
    this.currentOperation = null;
  }

  async #sdk() {
    if (!this.sdk) {
      this.sdk = await import(
        pathToFileURL(path.join(this.packageRoot, "dist/index.js")).href
      );
    }
    return this.sdk;
  }

  // One SettingsManager + one PackageManager per backend process; reload()
  // before reads so manual edits to settings.json are never clobbered.
  async #context() {
    if (!this.context) {
      const { DefaultPackageManager, SettingsManager, getAgentDir } =
        await this.#sdk();
      const agentDir = getAgentDir();
      const settingsManager = SettingsManager.create(agentDir, agentDir);
      const manager = new DefaultPackageManager({
        cwd: agentDir,
        agentDir,
        settingsManager,
      });
      // Progress events stream to the GUI as control-channel notifications.
      manager.setProgressCallback((event) => this.#progress(event));
      this.context = { settingsManager, manager, agentDir };
    }
    return this.context;
  }

  #progress(event) {
    this.emit?.({
      type: "gui_packages_progress",
      operationId: this.currentOperation ?? null,
      phase: event.type,
      action: event.action,
      source: event.source ?? null,
      message: event.message ?? null,
    });
  }

  #finish(operationId, kind, source, ok, data, error) {
    const message = String(error?.code ?? error?.message ?? "PACKAGES_FAILED");
    this.emit?.({
      type: "gui_packages_finished",
      operationId,
      kind,
      source: source ?? null,
      ok,
      ...(data === undefined ? {} : { data }),
      ...(ok ? {} : { error: message }),
    });
  }

  // Long npm/git operations answer the request immediately and report back
  // through gui_packages_finished carrying the fresh state. Mutations run
  // one at a time; state reads and toggles stay synchronous.
  #enqueue(operationId, kind, source, job) {
    const previous = this.mutations;
    let release;
    this.mutations = new Promise((resolve) => (release = resolve));
    previous
      .then(async () => {
        this.currentOperation = operationId;
        try {
          const data = await job();
          this.#finish(operationId, kind, source, true, data);
        } catch (error) {
          this.#finish(operationId, kind, source, false, undefined, error);
        } finally {
          this.currentOperation = null;
        }
      })
      .catch(() => {})
      .finally(release);
  }

  async state() {
    const { settingsManager, manager, agentDir } = await this.#context();
    await settingsManager.reload();
    const packages = manager.listConfiguredPackages();
    const resolved = await manager.resolve(async () => "skip");
    const resources = {};
    for (const type of RESOURCE_TYPES) {
      resources[type] = (resolved[type] ?? []).map((resource) => ({
        path: resource.path,
        enabled: resource.enabled,
        source: resource.metadata.source,
        scope: resource.metadata.scope,
        origin: resource.metadata.origin,
        baseDir: resource.metadata.baseDir ?? null,
      }));
    }
    return { version: 1, agentDir, packages, resources };
  }

  async install(request) {
    const source = text(request.source)
      ? request.source.trim()
      : fail("INVALID_SOURCE");
    const operationId = text(request.operationId)
      ? request.operationId
      : fail("INVALID_REQUEST");
    const { settingsManager, manager } = await this.#context();
    this.#enqueue(operationId, "install", source, async () => {
      try {
        await manager.installAndPersist(source);
      } finally {
        await settingsManager.flush();
      }
      return this.state();
    });
    return { operationId };
  }

  async remove(request) {
    const source = text(request.source)
      ? request.source.trim()
      : fail("INVALID_SOURCE");
    const operationId = text(request.operationId)
      ? request.operationId
      : fail("INVALID_REQUEST");
    const { settingsManager, manager } = await this.#context();
    this.#enqueue(operationId, "remove", source, async () => {
      const removed = await manager.removeAndPersist(source);
      await settingsManager.flush();
      if (!removed) fail("PACKAGE_NOT_FOUND");
      return this.state();
    });
    return { operationId };
  }

  async update(request) {
    const source =
      request.source == null
        ? undefined
        : text(request.source)
          ? request.source.trim()
          : fail("INVALID_SOURCE");
    const operationId = text(request.operationId)
      ? request.operationId
      : fail("INVALID_REQUEST");
    const { settingsManager, manager } = await this.#context();
    this.#enqueue(operationId, "update", source ?? null, async () => {
      try {
        await manager.update(source);
      } finally {
        await settingsManager.flush();
      }
      return this.state();
    });
    return { operationId };
  }

  async checkUpdates(request) {
    const operationId = text(request.operationId)
      ? request.operationId
      : fail("INVALID_REQUEST");
    const { manager } = await this.#context();
    this.#enqueue(operationId, "check_updates", null, async () => {
      const updates = await manager.checkForAvailableUpdates();
      return {
        updates: updates.map((update) => ({
          source: update.source,
          displayName: update.displayName,
          type: update.type,
          scope: update.scope,
        })),
      };
    });
    return { operationId };
  }

  // Ported 1:1 from pi config's global-scope toggle (config-selector.js):
  // top-level rows write `+pattern`/`-pattern` into settings[resourceType];
  // package rows write into the package entry's filter array, collapsing an
  // empty filter object back to a plain source string.
  async toggle(request) {
    const type = RESOURCE_TYPES.includes(request.resourceType)
      ? request.resourceType
      : fail("INVALID_RESOURCE_TYPE");
    if (request.scope !== "user") fail("PACKAGE_SCOPE_READ_ONLY");
    if (typeof request.path !== "string" || !request.path) fail("INVALID_PATH");
    if (request.origin !== "top-level" && request.origin !== "package")
      fail("INVALID_ORIGIN");
    if (typeof request.enabled !== "boolean") fail("INVALID_REQUEST");
    const { settingsManager, agentDir } = await this.#context();
    await settingsManager.reload();
    const enabled = request.enabled;
    const strip = (entry) =>
      entry.startsWith("!") || entry.startsWith("+") || entry.startsWith("-")
        ? entry.slice(1)
        : entry;
    const run = async () => {
      if (request.origin === "top-level") {
        const baseDir = request.baseDir ?? agentDir;
        const pattern = path.relative(baseDir, request.path);
        const updated = (
          settingsManager.getGlobalSettings()[type] ?? []
        ).filter((entry) => strip(entry) !== pattern);
        updated.push(`${enabled ? "+" : "-"}${pattern}`);
        if (type === "extensions") settingsManager.setExtensionPaths(updated);
        else if (type === "skills") settingsManager.setSkillPaths(updated);
        else if (type === "prompts")
          settingsManager.setPromptTemplatePaths(updated);
        else settingsManager.setThemePaths(updated);
        return;
      }
      const source = text(request.source)
        ? request.source
        : fail("INVALID_SOURCE");
      const packages = [
        ...(settingsManager.getGlobalSettings().packages ?? []),
      ];
      const index = packages.findIndex(
        (pkg) => (typeof pkg === "string" ? pkg : pkg.source) === source,
      );
      if (index === -1) fail("PACKAGE_NOT_FOUND");
      let pkg = packages[index];
      if (typeof pkg === "string") {
        pkg = { source: pkg };
        packages[index] = pkg;
      }
      const baseDir = request.baseDir ?? path.dirname(request.path);
      const pattern = path.relative(baseDir, request.path);
      const updated = (pkg[type] ?? []).filter(
        (entry) => strip(entry) !== pattern,
      );
      updated.push(`${enabled ? "+" : "-"}${pattern}`);
      pkg[type] = updated.length > 0 ? updated : undefined;
      const hasFilters = RESOURCE_TYPES.some((key) => pkg[key] !== undefined);
      if (!hasFilters) packages[index] = pkg.source;
      settingsManager.setPackages(packages);
      await settingsManager.flush();
    };
    await this.#serialize(run);
    return this.state();
  }

  // Toggles are quick settings writes; they still serialize behind installs
  // so a state refresh can never interleave with an in-flight mutation.
  #serialize(job) {
    const previous = this.mutations;
    let release;
    this.mutations = new Promise((resolve) => (release = resolve));
    const run = previous.then(job);
    run.finally(release);
    return run;
  }

  async handle(request) {
    switch (request.type) {
      case "gui_packages_state":
        return this.state();
      case "gui_packages_check_updates":
        return this.checkUpdates(request);
      case "gui_packages_install":
        return this.install(request);
      case "gui_packages_remove":
        return this.remove(request);
      case "gui_packages_update":
        return this.update(request);
      case "gui_packages_toggle":
        return this.toggle(request);
      default:
        fail("UNKNOWN_COMMAND");
    }
  }
}
