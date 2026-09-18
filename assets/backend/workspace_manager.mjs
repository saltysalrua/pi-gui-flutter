// One JSONL supervisor; each channel owns an ordinary Pi RPC process.
import path from "node:path";
import { existsSync } from "node:fs";
import {
  WorkspaceService,
  WorkspaceAdapter,
  WorkspaceError,
  directory,
  gitInfo,
} from "./workspace_rpc.mjs";

const key = (value) =>
  process.platform === "win32"
    ? path.normalize(value).toLowerCase()
    : path.normalize(value);
const fail = (code) => {
  throw new WorkspaceError(code);
};
const inside = (parent, child) => {
  const relative = path.relative(key(parent), key(child));
  return (
    relative === "" ||
    (!relative.startsWith(`..${path.sep}`) &&
      relative !== ".." &&
      !path.isAbsolute(relative))
  );
};

export class WorkspaceManager {
  constructor(service, createChild, emit, { resizeImage, packageRoot } = {}) {
    this.resizeImage = resizeImage;
    this.packageRoot = packageRoot;
    this.service = service;
    this.createChild = createChild;
    this.emit = emit;
    this.channels = new Map();
    this.scopes = new Map();
    this.workspaceProjects = new Map();
    this.projects = [];
    this.names = {};
    this.jobs = [];
    this.locks = new Set();
    this.saving = Promise.resolve();
    this.closing = false;
  }
  async initialize() {
    const saved = this.service.catalog;
    if (saved?.version === 1 && Array.isArray(saved.projects)) {
      this.projects = saved.projects.filter(
        (p) => typeof p.path === "string" && typeof p.name === "string",
      );
      this.names =
        saved.names && typeof saved.names === "object" ? saved.names : {};
    } else {
      for (const item of this.service.recent) {
        try {
          await this.register(item.path, false);
        } catch {
          /* Removed recent folder. */
        }
      }
    }
    if (!saved || saved.version !== 1)
      await this.register(this.service.current, false);
    const catalog = await this.catalog();
    if (!this.workspaceProjects.has(key(this.service.current))) {
      const first = catalog.projects
        .flatMap((p) => p.worktrees)
        .find((w) => !w.prunable);
      if (first) this.service.current = first.path;
    }
    await this.save();
  }
  save() {
    this.saving = this.saving.then(async () => {
      this.service.catalog = {
        version: 1,
        projects: this.projects,
        names: this.names,
      };
      await this.service.save();
    });
    return this.saving;
  }
  scope(cwd) {
    const id = key(cwd);
    if (!this.scopes.has(id)) {
      const scope = new WorkspaceService(
        this.service.sessions,
        this.service.storePath,
        cwd,
      );
      // Only the manager writes GUI metadata; parallel scopes never race the store.
      scope.save = async () => {};
      this.scopes.set(id, scope);
    }
    return this.scopes.get(id);
  }
  async register(value, persist = true) {
    const cwd = await directory(value);
    let info;
    try {
      info = await gitInfo(cwd);
    } catch {
      /* Folders remain usable without Git. */
    }
    const root = info?.worktrees.find((w) => !w.bare)?.path ?? cwd;
    const existing = this.projects.find((p) => key(p.path) === key(root));
    if (!existing)
      this.projects.push({
        path: root,
        name: path.basename(root),
        folders: [],
      });
    const project = existing ?? this.projects.at(-1);
    if (!info || !info.worktrees.some((w) => key(w.path) === key(cwd))) {
      project.folders ??= [];
      if (!project.folders.some((p) => key(p) === key(cwd)))
        project.folders.push(cwd);
    }
    if (persist) await this.save();
    return cwd;
  }
  async catalog() {
    const projects = [];
    for (const project of this.projects) {
      let info,
        unavailable = false,
        warning = null;
      try {
        await directory(project.path);
        info = await gitInfo(project.path);
      } catch (error) {
        unavailable = error.code === "DIRECTORY_UNAVAILABLE";
        warning = error.code;
      }
      const worktrees = (info?.worktrees ?? [])
        .filter((w) => !w.bare)
        .map((w, index) => ({
          ...w,
          main: index === 0,
          name:
            this.names[key(w.path)]?.name ?? w.branch ?? path.basename(w.path),
          baseRef: this.names[key(w.path)]?.baseRef ?? null,
        }));
      for (const folder of [project.path, ...(project.folders ?? [])]) {
        if (!worktrees.some((w) => key(w.path) === key(folder)))
          worktrees.push({
            path: folder,
            name: path.basename(folder),
            main: folder === project.path,
            folder: true,
            prunable: unavailable,
          });
      }
      for (const worktree of worktrees)
        this.workspaceProjects.set(key(worktree.path), key(project.path));
      projects.push({
        ...project,
        git: !!info,
        warning,
        branches: [...(info?.branches ?? []), ...(info?.remotes ?? [])],
        baseRef: info?.baseRef ?? "HEAD",
        hasHead: info?.hasHead ?? false,
        worktreeParent: info?.worktreeParent,
        worktrees,
      });
    }
    return {
      version: 1,
      projects,
      channels: [...this.channels.values()].map((c) => this.describe(c)),
      jobs: this.jobs,
      persistenceWarning: this.service.persistenceWarning,
    };
  }
  describe(entry) {
    return {
      id: entry.id,
      workspace: entry.cwd,
      sessionFile: entry.sessionFile ?? null,
      status: entry.status,
    };
  }
  changed() {
    this.output("control", { type: "gui_catalog_changed" });
  }
  // Settings-page package management reuses Pi's own PackageManager; the
  // module is only imported once a gui_packages_* command arrives.
  async packages(request) {
    if (!this.packagesBridge) {
      const { GuiPackagesBridge } = await import("./gui_packages.mjs");
      this.packagesBridge = new GuiPackagesBridge({
        packageRoot: this.packageRoot,
        emit: (message) => this.output("control", message),
      });
    }
    return this.packagesBridge.handle(request);
  }
  output(channel, message) {
    this.emit(JSON.stringify({ type: "gui_channel", channel, message }));
  }
  reply(channel, request, data, error) {
    this.output(channel, {
      type: "response",
      id: request.id,
      command: request.type,
      success: !error,
      ...(error ? { error: error.code ?? "WORKSPACE_FAILED" } : { data }),
    });
  }
  // Serialized through the same saving chain as catalog writes; never
  // reorders the recent list the way service.remember would.
  async rememberSession(cwd, sessionPath) {
    const recent = this.service.recent;
    const entry = recent.find((item) => key(item.path) === key(cwd));
    if (entry) {
      entry.sessionPath = sessionPath;
    } else {
      recent.unshift({ path: cwd, sessionPath });
      if (recent.length > 24) recent.length = 24;
    }
    await this.save();
  }
  // The restart bookmark lives in the store, not on the channel: the
  // primary channel relaunches with it, so identity is checked against it.
  hasBookmark(cwd, sessionFile) {
    const entry = this.service.recent.find(
      (item) => key(item.path) === key(cwd),
    );
    return !!entry?.sessionPath && key(entry.sessionPath) === key(sessionFile);
  }
  start() {
    if (!this.workspaceProjects.has(key(this.service.current)))
      return Promise.resolve();
    // Restart should return to the last conversation, not an empty session.
    // A persisted path is only trusted while the file still exists.
    const recent = this.service.recent.find(
      (item) => key(item.path) === key(this.service.current),
    );
    const sessionFile =
      recent?.sessionPath && existsSync(recent.sessionPath)
        ? recent.sessionPath
        : undefined;
    return this.launch("primary", this.service.current, sessionFile).ready;
  }
  launch(id, cwd, sessionFile) {
    if (this.closing) fail("WORKSPACE_BUSY");
    const entry = { id, cwd, sessionFile, status: "starting", closed: false };
    this.channels.set(id, entry);
    // Each adapter has independent locks, request IDs and file-browser scope.
    const adapter = new WorkspaceAdapter(
      this.scope(cwd),
      (directory, output, sessionPath) =>
        this.createChild(directory, output, sessionPath, () =>
          this.exited(entry),
        ),
      (line) => {
        if (entry.closed) return;
        let message;
        try {
          message = JSON.parse(line);
        } catch {
          message = null;
        }
        if (
          message?.type === "response" &&
          message.command === "get_state" &&
          message.success
        ) {
          entry.sessionFile = message.data?.sessionFile ?? entry.sessionFile;
          // Remember conversations with content so the next GUI restart can
          // reopen the last active one. A channel keeps one sessionFile for
          // its whole life, so dedupe against the persisted bookmark — not
          // the previous observation on this channel, which would freeze a
          // stale entry forever. Empty sessions never overwrite a bookmark.
          if (
            entry.sessionFile &&
            (message.data?.messageCount ?? 0) > 0 &&
            !this.hasBookmark(entry.cwd, entry.sessionFile)
          ) {
            void this.rememberSession(entry.cwd, entry.sessionFile);
          }
        }
        if (["tool_execution_end", "agent_settled"].includes(message?.type))
          this.scope(cwd).browser?.invalidate();
        if (message?.type === "agent_start") entry.status = "running";
        if (message?.type === "agent_settled") entry.status = "ready";
        this.emit(
          JSON.stringify({
            type: "gui_channel",
            channel: id,
            ...(message ? { message } : { line }),
          }),
        );
        if (["agent_start", "agent_settled"].includes(message?.type))
          this.changed();
      },
      () => this.exited(entry),
      { resizeImage: this.resizeImage },
    );
    entry.adapter = adapter;
    entry.ready = adapter
      .start(sessionFile)
      .then((state) => {
        if (entry.closed || entry.status === "exited") return;
        entry.sessionFile = state?.sessionFile ?? entry.sessionFile;
        entry.status = "ready";
        this.changed();
      })
      .catch(() => this.exited(entry));
    return entry;
  }
  exited(entry) {
    if (entry.closed || entry.status === "exited") return;
    entry.status = "exited";
    this.output(entry.id, { type: "gui_channel_exited" });
    this.changed();
  }
  async knownWorkspace(value) {
    const cwd = await directory(value);
    // Fast path uses only validated catalog membership, never arbitrary cwd.
    if (!this.workspaceProjects.has(key(cwd))) await this.catalog();
    if (!this.workspaceProjects.has(key(cwd))) fail("WORKTREE_UNAVAILABLE");
    return cwd;
  }
  async openChannel(request) {
    if (
      typeof request.channelId !== "string" ||
      !/^[a-zA-Z0-9_-]{1,100}$/.test(request.channelId) ||
      ["control", "primary"].includes(request.channelId)
    )
      fail("INVALID_NAME");
    const known = this.channels.get(request.channelId);
    if (known) return this.describe(known); // Stable operation identity after timeout.
    const cwd = await this.knownWorkspace(request.workspace);
    if (this.locks.has(this.workspaceProjects.get(key(cwd))))
      fail("WORKSPACE_BUSY");
    let sessionFile;
    if (request.sessionPath != null) {
      const history = await this.scope(cwd).listSessions({ force: true });
      sessionFile = history.sessions.find(
        (s) => key(s.path) === key(request.sessionPath),
      )?.path;
      if (!sessionFile) fail("SESSIONS_UNAVAILABLE");
      const existing = [...this.channels.values()].find(
        (c) => c.sessionFile && key(c.sessionFile) === key(sessionFile),
      );
      if (existing) return this.describe(existing);
    }
    // Reserving synchronously after the awaits prevents duplicate ownership.
    const existing =
      sessionFile &&
      [...this.channels.values()].find(
        (c) => c.sessionFile && key(c.sessionFile) === key(sessionFile),
      );
    if (existing) return this.describe(existing);
    if (this.channels.has(request.channelId))
      return this.describe(this.channels.get(request.channelId));
    // Recheck after SDK I/O: a sibling worktree may have begun deleting meanwhile.
    if (this.locks.has(this.workspaceProjects.get(key(cwd))))
      fail("WORKSPACE_BUSY");
    const entry = this.launch(request.channelId, cwd, sessionFile);
    this.service.current = cwd;
    await this.save();
    this.changed();
    return this.describe(entry);
  }
  async closeChannel(request) {
    const entry = this.channels.get(request.channelId);
    if (!entry) return {};
    if (entry.status !== "exited" && request.stop !== true) {
      await entry.ready;
      await entry.adapter.ensureIdle();
    }
    entry.closed = true;
    try {
      await entry.adapter.pi?.stop();
    } catch (error) {
      entry.closed = false;
      throw error;
    }
    this.channels.delete(entry.id);
    this.output(entry.id, { type: "gui_channel_exited" });
    this.changed();
    return {};
  }
  async worktreeJob(request) {
    const project = this.projects.find(
      (p) => key(p.path) === key(request.project),
    );
    if (!project) fail("WORKTREE_UNAVAILABLE");
    if (
      typeof request.operationId !== "string" ||
      !/^[a-zA-Z0-9_-]{1,100}$/.test(request.operationId)
    )
      fail("INVALID_NAME");
    const old = this.jobs.find((j) => j.id === request.operationId);
    if (old) return old;
    const lock = key(project.path);
    if (this.locks.has(lock)) fail("WORKSPACE_BUSY");
    this.locks.add(lock);
    const job = {
      id: request.operationId,
      project: project.path,
      name: request.name || request.branch || request.path,
      kind: request.type,
      status: "working",
    };
    this.jobs.push(job);
    // A background job has one durable-in-process identity. No blind retry.
    const work = (async () => {
      try {
        const scope = this.scope(project.path);
        if (request.type === "gui_add_worktree") {
          if (
            typeof request.name !== "string" ||
            !request.name.trim() ||
            request.name.length > 160
          )
            fail("INVALID_NAME");
          const result = await scope.createWorktree(
            request.branch,
            request.baseRef,
          );
          this.names[key(result.path)] = {
            name: request.name.trim(),
            baseRef: request.baseRef,
          };
          job.path = result.path;
        } else {
          const cwd = await directory(request.path);
          if ([...this.channels.values()].some((c) => inside(cwd, c.cwd)))
            fail("WORKTREE_IN_USE");
          const result = await scope.removeWorktree(cwd);
          delete this.names[key(result.path)];
          this.scopes.delete(key(result.path));
          for (const cwd of this.workspaceProjects.keys()) {
            if (inside(result.path, cwd)) this.workspaceProjects.delete(cwd);
          }
          project.folders = (project.folders ?? []).filter(
            (cwd) => !inside(result.path, cwd),
          );
          this.service.recent = this.service.recent.filter(
            (p) => key(p.path) !== key(result.path),
          );
          job.path = result.path;
        }
        job.status = "done";
        await this.save();
      } catch (error) {
        job.status = "failed";
        job.error = error.code ?? "WORKSPACE_FAILED";
      } finally {
        this.locks.delete(lock);
        this.changed();
      }
    })();
    this.work ??= new Set();
    this.work.add(work);
    void work.finally(() => this.work.delete(work));
    this.changed();
    return job;
  }
  async control(request) {
    switch (request.type) {
      case "gui_get_catalog":
        return this.catalog();
      case "gui_add_project": {
        const cwd = await this.register(request.path);
        this.changed();
        return { path: cwd };
      }
      case "gui_forget_project": {
        const project = this.projects.find(
          (p) => key(p.path) === key(request.path),
        );
        if (!project) return {};
        const catalog = await this.catalog();
        const folders = catalog.projects.find(
          (p) => p.path === project.path,
        ).worktrees;
        if (
          this.locks.has(key(project.path)) ||
          [...this.channels.values()].some((c) =>
            folders.some((w) => inside(w.path, c.cwd)),
          )
        )
          fail("WORKTREE_IN_USE");
        this.projects = this.projects.filter((p) => p !== project);
        for (const [cwd, root] of this.workspaceProjects) {
          if (root === key(project.path)) this.workspaceProjects.delete(cwd);
        }
        if (folders.some((w) => inside(w.path, this.service.current))) {
          this.service.current = this.projects[0]?.path ?? process.cwd();
        }
        await this.save();
        this.changed();
        return {};
      }
      case "gui_workspace_history": {
        const cwd = await this.knownWorkspace(request.workspace);
        return this.scope(cwd).listSessions({ force: request.force === true });
      }
      case "gui_open_channel":
        return this.openChannel(request);
      case "gui_close_channel":
        return this.closeChannel(request);
      case "gui_add_worktree":
      case "gui_delete_worktree":
        return this.worktreeJob(request);
      case "gui_packages_state":
      case "gui_packages_check_updates":
      case "gui_packages_install":
      case "gui_packages_remove":
      case "gui_packages_update":
      case "gui_packages_toggle":
        return this.packages(request);
      // Browse any registered worktree without creating an Agent.
      case "gui_list_files":
      case "gui_get_git_graph":
      case "gui_get_git_commit":
      case "gui_get_file_preview": {
        const cwd = await this.knownWorkspace(request.workspace);
        const { WorkspaceBrowser } = await import("./workspace_browser.mjs");
        const scope = this.scope(cwd);
        scope.browser ??= new WorkspaceBrowser(() => cwd);
        const method = {
          gui_list_files: "listFiles",
          gui_get_git_graph: "graph",
          gui_get_git_commit: "details",
          gui_get_file_preview: "preview",
        }[request.type];
        return scope.browser[method](request);
      }
      default:
        fail("UNKNOWN_COMMAND");
    }
  }
  async handle(packet) {
    const channel = packet?.type === "gui_channel" ? packet.channel : "primary";
    const request = packet?.type === "gui_channel" ? packet.message : packet;
    if (
      !request ||
      typeof request.type !== "string" ||
      typeof channel !== "string"
    )
      return;
    try {
      if (channel === "control") {
        this.reply(channel, request, await this.control(request));
        return;
      }
      const entry = this.channels.get(channel);
      if (!entry || entry.closed || entry.status === "exited")
        fail("PI_EXITED");
      if (request.type !== "extension_ui_response") await entry.ready;
      if (entry.closed || entry.status === "exited") fail("PI_EXITED");
      // Channel cwd and historical identity are immutable. New chats get a channel.
      if (
        request.type.startsWith("gui_") &&
        ![
          "gui_get_workspace",
          "gui_list_sessions",
          "gui_list_files",
          "gui_get_git_graph",
          "gui_get_git_commit",
          "gui_get_file_preview",
        ].includes(request.type)
      )
        fail("UNKNOWN_COMMAND");
      if (request.type === "new_session") fail("WORKSPACE_BUSY");
      if (
        request.type === "switch_session" &&
        (!entry.sessionFile ||
          key(request.sessionPath) !== key(entry.sessionFile))
      )
        fail("WORKSPACE_BUSY");
      await entry.adapter.handle(request);
    } catch (error) {
      this.reply(channel, request, null, error);
    }
  }
  async close() {
    this.closing = true;
    await Promise.all(
      [...this.channels.values()].map((entry) => {
        entry.closed = true;
        return entry.adapter.pi?.stop();
      }),
    );
    await Promise.all(this.work ?? []);
    await this.saving;
  }
}
