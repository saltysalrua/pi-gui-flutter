// Pi GUI's local JSONL adapter. Agent logic and session decoding stay in Pi.
import { spawn, execFile } from "node:child_process";
import { promisify } from "node:util";
import { createRequire } from "node:module";
import { existsSync, writeFileSync } from "node:fs";
import {
  readFile,
  writeFile,
  mkdir,
  realpath,
  stat,
  rename,
} from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";
import { WorkspaceBrowser } from "./workspace_browser.mjs";
import { prepareImageUpload } from "./gui_image_upload.mjs";

const exec = promisify(execFile);
// A short-lived SDK summary, not a second session database or a polling timer.
const SESSION_CACHE_TTL_MS = 5000;
const isWindows = process.platform === "win32";
const key = (value) =>
  isWindows ? path.normalize(value).toLowerCase() : path.normalize(value);
export class WorkspaceError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}
const fail = (code) => {
  throw new WorkspaceError(code);
};
const text = (value) =>
  typeof value === "string" && value.trim() && !value.includes("\0");

export async function directory(value) {
  if (!text(value) || !path.isAbsolute(value)) fail("INVALID_PATH");
  try {
    const resolved = await realpath(value);
    if (!(await stat(resolved)).isDirectory()) fail("INVALID_PATH");
    return resolved;
  } catch {
    fail("DIRECTORY_UNAVAILABLE");
  }
}

// Strictly LF framing; Unicode line separators inside JSON strings are not records.
export function lines(stream, onLine) {
  let fragments = [];
  stream.setEncoding("utf8");
  stream.on("data", (chunk) => {
    let start = 0,
      index;
    while ((index = chunk.indexOf("\n", start)) >= 0) {
      let line = chunk.slice(start, index);
      start = index + 1;
      if (fragments.length) {
        fragments.push(line);
        line = fragments.join("");
        fragments = [];
      }
      if (line.endsWith("\r")) line = line.slice(0, -1);
      if (line) onLine(line);
    }
    if (start < chunk.length) fragments.push(chunk.slice(start));
  });
}

export async function resolvePiPackage() {
  const candidates = [process.env.PI_GUI_PI_PACKAGE_DIR];
  try {
    const require = createRequire(path.join(process.cwd(), "__pi_gui__.cjs"));
    candidates.push(
      path.dirname(
        path.dirname(require.resolve("@earendil-works/pi-coding-agent")),
      ),
    );
  } catch {
    /* Global npm installation is the usual desktop setup. */
  }
  for (const entry of (process.env.PATH ?? "").split(path.delimiter)) {
    candidates.push(
      path.join(entry, "node_modules", "@earendil-works", "pi-coding-agent"),
    );
    candidates.push(
      path.resolve(
        entry,
        "../lib/node_modules/@earendil-works/pi-coding-agent",
      ),
    );
  }
  if (process.env.APPDATA)
    candidates.push(
      path.join(
        process.env.APPDATA,
        "npm/node_modules/@earendil-works/pi-coding-agent",
      ),
    );
  for (const candidate of candidates.filter(Boolean)) {
    if (
      existsSync(path.join(candidate, "dist/index.js")) &&
      existsSync(path.join(candidate, "dist/bundle/cli.js"))
    ) {
      return path.resolve(candidate);
    }
  }
  fail("PI_PACKAGE_UNAVAILABLE");
}

async function git(cwd, args, { allowFailure = false } = {}) {
  try {
    // Never a shell: branch names, paths, Unicode and spaces are literal arguments.
    return (
      await exec("git", ["-C", cwd, ...args], {
        windowsHide: true,
        maxBuffer: 16 * 1024 * 1024,
        timeout: 60000,
      })
    ).stdout;
  } catch (error) {
    if (error.code === "ENOENT") fail("GIT_UNAVAILABLE");
    if (allowFailure && typeof error.code === "number") return null;
    fail("GIT_FAILED");
  }
}

export function parseWorktrees(output) {
  const result = [];
  let current;
  for (const field of output.split("\0")) {
    if (field.startsWith("worktree ")) {
      current = {
        path: field.slice(9),
        branch: null,
        detached: false,
        locked: false,
        prunable: false,
        bare: false,
      };
      result.push(current);
    } else if (current) {
      if (field.startsWith("branch "))
        current.branch = field.slice(7).replace(/^refs\/heads\//, "");
      if (field === "detached") current.detached = true;
      if (field === "bare") current.bare = true;
      if (field === "locked" || field.startsWith("locked "))
        current.locked = true;
      if (field === "prunable" || field.startsWith("prunable "))
        current.prunable = true;
    }
  }
  return result;
}

export async function gitInfo(cwd) {
  const root = await git(cwd, ["rev-parse", "--show-toplevel"], {
    allowFailure: true,
  });
  if (root === null) return null;
  const repository = root.trimEnd();
  const [branch, commit, dirty, branches, worktrees, remotes, remoteHead] =
    await Promise.all([
      git(cwd, ["symbolic-ref", "--quiet", "--short", "HEAD"], {
        allowFailure: true,
      }),
      git(cwd, ["rev-parse", "--verify", "HEAD^{commit}"], {
        allowFailure: true,
      }),
      git(cwd, ["status", "--porcelain", "-z", "--untracked-files=normal"]),
      git(cwd, ["for-each-ref", "--format=%(refname:short)", "refs/heads/"]),
      git(cwd, ["worktree", "list", "--porcelain", "-z"]),
      git(cwd, ["for-each-ref", "--format=%(refname:short)", "refs/remotes/"]),
      git(cwd, ["symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"], {
        allowFailure: true,
      }),
    ]);
  return {
    root: repository,
    branch: branch?.trimEnd() ?? null,
    hasHead: commit !== null,
    dirty: dirty.length > 0,
    branches: branches.trimEnd().split("\n").filter(Boolean),
    remotes: remotes
      .trimEnd()
      .split("\n")
      .filter((ref) => ref && !ref.endsWith("/HEAD")),
    baseRef: remoteHead?.trim().replace(/^refs\/remotes\//, "") ?? "HEAD",
    worktrees: parseWorktrees(worktrees),
    worktreeParent: path.join(
      path.dirname(repository),
      `${path.basename(repository)}.worktrees`,
    ),
  };
}

export class WorkspaceService {
  constructor(
    SessionManager,
    storePath,
    initialPath,
    { now = () => performance.now() } = {},
  ) {
    this.sessions = SessionManager;
    this.storePath = storePath;
    this.current = initialPath;
    this.recent = [];
    this.persistenceWarning = false;
    this.now = now;
    this.sessionRevision = 0;
    this.sessionCache = null;
    this.sessionLoad = null;
  }
  async initialize() {
    try {
      const saved = JSON.parse(await readFile(this.storePath, "utf8"));
      this.catalog = saved.catalog;
      this.recent = Array.isArray(saved.recent)
        ? saved.recent.filter((item) => text(item.path)).slice(0, 24)
        : [];
      if (text(saved.current)) {
        try {
          this.current = await directory(saved.current);
        } catch {
          /* Fall back to launch directory. */
        }
      }
    } catch (error) {
      if (error.code !== "ENOENT") this.persistenceWarning = true;
    }
    this.current = await directory(this.current);
    await this.remember(this.current);
  }
  async save() {
    try {
      await mkdir(path.dirname(this.storePath), { recursive: true });
      const temp = `${this.storePath}.${process.pid}.tmp`;
      await writeFile(
        temp,
        JSON.stringify({
          version: 1,
          current: this.current,
          recent: this.recent,
          ...(this.catalog ? { catalog: this.catalog } : {}),
        }),
        "utf8",
      );
      await rename(temp, this.storePath);
      this.persistenceWarning = false;
    } catch {
      this.persistenceWarning = true;
    }
  }
  async remember(cwd, sessionPath) {
    const old = this.recent.find((item) => key(item.path) === key(cwd));
    this.recent = [
      {
        path: cwd,
        ...(old?.sessionPath ? { sessionPath: old.sessionPath } : {}),
        ...(sessionPath ? { sessionPath } : {}),
      },
      ...this.recent.filter((item) => key(item.path) !== key(cwd)),
    ].slice(0, 24);
    await this.save();
  }
  invalidateSessions() {
    this.sessionRevision++;
    this.sessionCache = null;
  }
  listSessions({ force = false } = {}) {
    const cwd = this.current;
    const revision = this.sessionRevision;
    const matches = (entry) =>
      entry?.cwd === cwd && entry.revision === revision;
    // Even explicit refreshes share an already fresh scan. Invalidated scans
    // belong to an older revision and can neither satisfy nor cache a new read.
    if (matches(this.sessionLoad)) return this.sessionLoad.promise;
    if (
      !force &&
      matches(this.sessionCache) &&
      this.now() < this.sessionCache.expiresAt
    ) {
      return Promise.resolve(this.sessionCache.data);
    }
    this.sessionCache = null;
    const load = { cwd, revision, promise: null };
    load.promise = this.loadSessionSummaries(cwd)
      .then((data) => {
        if (this.current === cwd && this.sessionRevision === revision) {
          this.sessionCache = {
            cwd,
            revision,
            data,
            expiresAt: this.now() + SESSION_CACHE_TTL_MS,
          };
        }
        return data;
      })
      .finally(() => {
        if (this.sessionLoad === load) this.sessionLoad = null;
      });
    this.sessionLoad = load;
    return load.promise;
  }
  async loadSessionSummaries(cwd) {
    try {
      const sessions = await this.sessions.list(cwd);
      // Retain only GUI summaries; release SDK allMessagesText/full-text data.
      return {
        sessions: sessions
          .map((item) => ({
            path: item.path,
            id: item.id,
            cwd: item.cwd,
            title: item.name || item.firstMessage?.split("\n")[0] || "",
            modified: new Date(item.modified).toISOString(),
            messageCount: item.messageCount,
          }))
          .sort((a, b) => b.modified.localeCompare(a.modified)),
      };
    } catch {
      fail("SESSIONS_UNAVAILABLE");
    }
  }
  async snapshot() {
    let repository = null,
      gitWarning = null;
    try {
      repository = await gitInfo(this.current);
    } catch (error) {
      gitWarning = error.code ?? "GIT_FAILED";
    }
    return {
      current: {
        path: this.current,
        name: path.basename(this.current) || this.current,
      },
      recent: this.recent.map((item) => ({
        path: item.path,
        name: path.basename(item.path) || item.path,
      })),
      git: repository,
      gitWarning,
      persistenceWarning: this.persistenceWarning,
    };
  }
  async createWorkspace(parent, name) {
    const resolved = await directory(parent);
    // One new child only. Never silently adopt an existing directory or create arbitrary ancestors.
    if (
      !text(name) ||
      name.trim() !== name ||
      /[<>:"/\\|?*\x00-\x1f]/.test(name) ||
      /[. ]$/.test(name) ||
      /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(name)
    )
      fail("INVALID_NAME");
    const target = path.join(resolved, name);
    try {
      await mkdir(target);
    } catch (error) {
      fail(error.code === "EEXIST" ? "PATH_EXISTS" : "CREATE_FAILED");
    }
    await this.remember(target);
    return { path: target };
  }
  async removeWorktree(target) {
    const info = await gitInfo(this.current);
    if (!info) fail("NOT_GIT");
    const cwd = await directory(target);
    const item = info.worktrees.find((w) => key(w.path) === key(cwd));
    if (!item || item.bare || item.prunable) fail("WORKTREE_UNAVAILABLE");
    if (key(info.root) === key(cwd) || key(info.worktrees[0].path) === key(cwd))
      fail("WORKTREE_IN_USE");
    if (item.locked) fail("WORKTREE_LOCKED");
    // Ignored files also block removal: no accidental deletion of .env or build data.
    const changes = await git(cwd, [
      "status",
      "--porcelain",
      "-z",
      "--untracked-files=normal",
      "--ignored",
    ]);
    if (changes.length) fail("WORKTREE_DIRTY");
    await git(this.current, ["worktree", "remove", "--", cwd]);
    this.recent = this.recent.filter((w) => key(w.path) !== key(cwd));
    await this.save();
    return { path: cwd };
  }
  async createWorktree(branch, baseRef) {
    const info = await gitInfo(this.current);
    if (!info) fail("NOT_GIT");
    if (!info.hasHead) fail("NO_COMMIT");
    if (
      !text(branch) ||
      branch.startsWith("-") ||
      (await git(this.current, ["check-ref-format", `refs/heads/${branch}`], {
        allowFailure: true,
      })) === null
    )
      fail("INVALID_BRANCH");
    if (info.branches.includes(branch)) fail("BRANCH_EXISTS");
    const fullCommit =
      typeof baseRef === "string" &&
      /^(?:[0-9a-f]{40}|[0-9a-f]{64})$/i.test(baseRef);
    if (
      baseRef !== "HEAD" &&
      !fullCommit &&
      !info.branches.includes(baseRef) &&
      !info.remotes.includes(baseRef)
    )
      fail("INVALID_BASE");
    const base =
      baseRef === "HEAD" || fullCommit
        ? baseRef
        : info.branches.includes(baseRef)
          ? `refs/heads/${baseRef}`
          : `refs/remotes/${baseRef}`;
    // Resolve a verified commit before writing. No option or revision expression injection.
    const commit = await git(
      this.current,
      ["rev-parse", "--verify", `${base}^{commit}`],
      { allowFailure: true },
    );
    if (commit === null) fail("INVALID_BASE");
    const folder = branch
      .replace(/[^\p{L}\p{N}._-]+/gu, "-")
      .replace(/^[.-]+/, "")
      .slice(0, 100);
    if (!folder || /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(folder))
      fail("INVALID_BRANCH");
    const target = path.join(info.worktreeParent, folder);
    if (existsSync(target)) fail("PATH_EXISTS");
    await mkdir(info.worktreeParent, { recursive: true });
    // No --force, no checkout/reset in the source, no copying ignored/untracked files.
    await git(this.current, [
      "worktree",
      "add",
      "-b",
      branch,
      "--",
      target,
      commit.trim(),
    ]);
    await this.remember(target);
    return { path: target };
  }
}

function ensureLauncherScript(packageRoot) {
  const launcherPath = path.join(
    path.dirname(fileURLToPath(import.meta.url)),
    "pi_launcher.mjs",
  );
  const code = `import { pathToFileURL } from "node:url";
import path from "node:path";

const root = ${JSON.stringify(packageRoot)};
const sessionPath = pathToFileURL(path.join(root, "dist/core/agent-session.js")).href;
const { AgentSession } = await import(sessionPath);

const origBind = AgentSession.prototype.bindExtensions;
AgentSession.prototype.bindExtensions = async function(options) {
  if (options) {
    options.mode = "tui";
  }
  if (options?.uiContext?.setWidget) {
    const origSetWidget = options.uiContext.setWidget.bind(options.uiContext);
    const activeWidgets = new Map();

    options.uiContext.setWidget = function(key, content, widgetOptions) {
      if (activeWidgets.has(key)) {
        const existing = activeWidgets.get(key);
        if (existing?.component?.dispose) {
          try { existing.component.dispose(); } catch {}
        }
        activeWidgets.delete(key);
      }

      if (typeof content === "function") {
        const placement = widgetOptions?.placement;
        const mockTui = {
          requestRender: () => {
            if (!activeWidgets.has(key)) return;
            try {
              const entry = activeWidgets.get(key);
              const lines = entry.component.render(160);
              origSetWidget(key, Array.isArray(lines) ? lines : [], { placement });
            } catch {}
          }
        };

        try {
          const comp = content(mockTui, options.uiContext.theme);
          activeWidgets.set(key, { component: comp, placement });
          const initialLines = comp?.render ? comp.render(160) : [];
          origSetWidget(key, Array.isArray(initialLines) ? initialLines : [], { placement });
        } catch {}
        return;
      }

      return origSetWidget(key, content, widgetOptions);
    };
  }

  return origBind.call(this, options);
};

const mainPath = pathToFileURL(path.join(root, "dist/main.js")).href;
const { main } = await import(mainPath);
main(process.argv.slice(2));
`;
  writeFileSync(launcherPath, code, "utf8");
  return launcherPath;
}

// Decode once for internal probes and adapter bookkeeping. Public output keeps
// its original bytes/text: unknown events and malformed lines still reach Dart.
export function routePiOutput(line, pendingRequests, emit) {
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    emit(line);
    return;
  }
  if (
    !message ||
    typeof message !== "object" ||
    Array.isArray(message) ||
    typeof message.type !== "string"
  ) {
    emit(line);
    return;
  }
  const pending =
    message.type === "response" && pendingRequests.get(message.id);
  if (pending) {
    pendingRequests.delete(message.id);
    clearTimeout(pending.timer);
    if (message.success) pending.resolve(message.data);
    else pending.reject(new WorkspaceError("PI_REJECTED"));
  } else {
    emit(line, message);
  }
}

// One Pi process at a time. Internal probes never enter the public response namespace.
export class PiChild {
  constructor(
    packageRoot,
    cwd,
    emit,
    onExit,
    sessionPath,
    extraArguments = [],
  ) {
    this.pending = new Map();
    this.nextId = 0;
    this.expectedExit = false;
    this.exited = false;
    const launcher = ensureLauncherScript(packageRoot);
    this.child = spawn(
      process.execPath,
      [
        launcher,
        "--mode",
        "rpc",
        ...extraArguments,
        "--extension",
        path.join(
          path.dirname(fileURLToPath(import.meta.url)),
          "gui_tool_diff.mjs",
        ),
        ...(sessionPath ? ["--session", sessionPath] : []),
      ],
      {
        cwd,
        env: { ...process.env, PI_GUI_PI_PACKAGE_ROOT: packageRoot },
        windowsHide: true,
        stdio: ["pipe", "pipe", "pipe"],
      },
    );
    this.child.stderr.resume(); // Never leak credentials or raw startup errors into the GUI.
    this.child.stdin.on("error", () => {});
    lines(this.child.stdout, (line) => routePiOutput(line, this.pending, emit));
    const ended = () => {
      this.exited = true;
      for (const item of this.pending.values()) {
        clearTimeout(item.timer);
        item.reject(new WorkspaceError("PI_EXITED"));
      }
      this.pending.clear();
      if (!this.expectedExit) onExit();
    };
    this.child.once("error", ended);
    this.child.once("exit", ended);
  }
  send(message) {
    this.child.stdin.write(`${JSON.stringify(message)}\n`);
  }
  request(type, fields = {}, timeoutMs = 20000) {
    return new Promise((resolve, reject) => {
      const id = `adapter-${++this.nextId}`;
      const timer =
        timeoutMs > 0
          ? setTimeout(() => {
              this.pending.delete(id);
              reject(new WorkspaceError("PI_TIMEOUT"));
            }, timeoutMs)
          : undefined;
      this.pending.set(id, { resolve, reject, timer });
      this.send({ id, type, ...fields });
    });
  }
  async stop() {
    this.expectedExit = true;
    if (this.exited) return;
    const ended = new Promise((resolve) => this.child.once("exit", resolve));
    if (isWindows) {
      try {
        await exec("taskkill", ["/PID", String(this.child.pid), "/T", "/F"], {
          windowsHide: true,
          timeout: 5000,
        });
      } catch {
        this.child.kill();
      }
    } else {
      this.child.kill();
    }
    await Promise.race([
      ended,
      new Promise((resolve) => {
        const timer = setTimeout(resolve, 5000);
        timer.unref();
      }),
    ]);
    if (!this.exited) fail("PI_STOP_FAILED");
  }
}

export class WorkspaceAdapter {
  constructor(
    service,
    createChild,
    emit,
    onFatal = () => {},
    { resizeImage } = {},
  ) {
    this.onFatal = onFatal;
    this.resizeImage = resizeImage;
    this.preparingImages = false;
    this.uploadEpoch = 0;
    this.service = service;
    this.browser = new WorkspaceBrowser(() => service.current);
    this.createChild = createChild;
    this.emit = emit;
    this.pi = null;
    this.mutating = false;
    this.agentBusy = false;
    this.forwarded = new Map();
  }
  async start(sessionPath) {
    this.service.invalidateSessions();
    this.browser.invalidate();
    const child = this.createChild(
      this.service.current,
      (line, message) => {
        if (this.pi !== child) return;
        if (message?.type === "response") {
          const command = this.forwarded.get(message.id);
          this.forwarded.delete(message.id);
          // Include extension commands and late write acknowledgements, not
          // just prompt/new_session. Read-only queries leave the cache intact.
          if (
            command &&
            !command.startsWith("get_") &&
            message.success === true
          ) {
            this.service.invalidateSessions();
          }
        }
        if (["tool_execution_end", "agent_settled"].includes(message?.type)) {
          this.browser.invalidate();
        }
        if (message?.type === "agent_start") this.agentBusy = true;
        if (message?.type === "agent_settled") this.agentBusy = false;
        if (
          ["message_end", "agent_settled", "compaction_end"].includes(
            message?.type,
          )
        ) {
          this.service.invalidateSessions();
        }
        this.emit(line);
      },
      sessionPath,
    );
    this.pi = child;
    // Startup extensions may be waiting for the user. A read timeout must not kill Pi.
    return child.request("get_state", {}, 0);
  }
  reply(request, data, error) {
    this.emit(
      JSON.stringify({
        type: "response",
        id: request.id,
        command: request.type,
        success: !error,
        ...(error ? { error: error.code ?? "WORKSPACE_FAILED" } : { data }),
      }),
    );
  }
  async ensureIdle() {
    if (this.agentBusy || this.forwarded.size || this.preparingImages)
      fail("WORKSPACE_BUSY");
    const state = await this.pi.request("get_state");
    if (
      state.isStreaming ||
      state.isCompacting ||
      state.pendingMessageCount > 0
    )
      fail("WORKSPACE_BUSY");
    return state;
  }
  async open(target) {
    const cwd = await directory(target);
    if (key(cwd) === key(this.service.current)) return this.service.snapshot();
    const previous = await this.ensureIdle();
    const previousPath = this.service.current;
    const previousSession =
      previous.messageCount > 0 &&
      previous.sessionFile &&
      existsSync(previous.sessionFile)
        ? previous.sessionFile
        : undefined;
    await this.service.remember(previousPath, previousSession);
    await this.pi.stop();
    this.emit(JSON.stringify({ type: "gui_workspace_reset" }));
    this.service.current = cwd;
    try {
      // A folder switch starts empty; prior conversations are explicitly selectable in the sidebar.
      await this.start();
    } catch {
      await this.pi?.stop();
      this.emit(JSON.stringify({ type: "gui_workspace_reset" }));
      this.service.current = previousPath;
      try {
        await this.start(previousSession);
      } catch {
        fail("PI_RESTART_FAILED");
      }
      fail("WORKSPACE_START_FAILED");
    }
    await this.service.remember(cwd);
    this.emit(JSON.stringify({ type: "gui_workspace_changed", path: cwd }));
    return this.service.snapshot();
  }
  async handle(request) {
    if (!request || typeof request.type !== "string") return;
    if (!request.type.startsWith("gui_")) {
      const prompting = ["prompt", "steer", "follow_up"].includes(request.type);
      if (
        (this.mutating && request.type !== "extension_ui_response") ||
        (this.preparingImages &&
          (prompting ||
            ["new_session", "switch_session"].includes(request.type)))
      ) {
        this.reply(request, null, new WorkspaceError("WORKSPACE_BUSY"));
        return;
      }
      // Stop/read/UI responses must remain live while a worker prepares images.
      if (request.type === "abort") this.uploadEpoch++;
      if (
        typeof request.id === "string" &&
        request.type !== "extension_ui_response"
      )
        this.forwarded.set(request.id, request.type);
      const prepare =
        prompting &&
        request.images !== undefined &&
        !(Array.isArray(request.images) && request.images.length === 0);
      const child = this.pi,
        epoch = this.uploadEpoch;
      try {
        let outgoing = request;
        if (prepare) {
          this.preparingImages = true;
          const images = await prepareImageUpload(
            request.images,
            this.resizeImage,
          );
          if (epoch !== this.uploadEpoch) fail("IMAGE_PREPROCESS_FAILED");
          outgoing = { ...request, images };
        }
        if (child !== this.pi || child.exited || child.expectedExit)
          fail("PI_EXITED");
        child.send(outgoing);
      } catch (error) {
        this.forwarded.delete(request.id);
        this.reply(request, null, error);
      } finally {
        if (prepare) this.preparingImages = false;
      }
      return;
    }
    const mutation = [
      "gui_open_workspace",
      "gui_create_workspace",
      "gui_create_worktree",
      "gui_remove_worktree",
    ].includes(request.type);
    if (this.mutating) {
      this.reply(request, null, new WorkspaceError("WORKSPACE_BUSY"));
      return;
    }
    if (mutation) this.mutating = true;
    try {
      if (mutation) await this.ensureIdle();
      let data;
      switch (request.type) {
        case "gui_list_files":
          data = await this.browser.listFiles(request);
          break;
        case "gui_get_git_graph":
          data = await this.browser.graph(request);
          break;
        case "gui_get_git_commit":
          data = await this.browser.details(request);
          break;
        case "gui_get_file_preview":
          data = await this.browser.preview(request);
          break;
        case "gui_get_workspace":
          data = await this.service.snapshot();
          break;
        case "gui_list_sessions":
          data = await this.service.listSessions({
            force: request.force === true,
          });
          break;
        case "gui_open_workspace":
          data = await this.open(request.path);
          break;
        case "gui_create_workspace":
          data = await this.service.createWorkspace(
            request.parent,
            request.name,
          );
          break;
        case "gui_remove_worktree":
          data = await this.service.removeWorktree(request.path);
          break;
        case "gui_create_worktree":
          data = await this.service.createWorktree(
            request.branch,
            request.baseRef,
          );
          break;
        default:
          fail("UNKNOWN_COMMAND");
      }
      this.reply(request, data);
    } catch (error) {
      this.reply(request, null, error);
    } finally {
      if (mutation) this.mutating = false;
      if (this.pi.exited || this.pi.expectedExit) this.onFatal();
    }
  }
}

async function main() {
  const root = await resolvePiPackage();
  const { SessionManager, resizeImage } = await import(
    pathToFileURL(path.join(root, "dist/index.js")).href
  );
  const storePath =
    process.env.PI_GUI_WORKSPACE_STORE ??
    path.join(
      process.env.APPDATA ??
        process.env.XDG_CONFIG_HOME ??
        path.join(homedir(), ".config"),
      "pi-gui",
      "workspaces.json",
    );
  const service = new WorkspaceService(
    SessionManager,
    storePath,
    process.cwd(),
  );
  await service.initialize();
  const emit = (line) => process.stdout.write(`${line}\n`);
  if (!process.argv.includes("--gui-multiplex")) {
    const adapter = new WorkspaceAdapter(
      service,
      (cwd, output, sessionPath) =>
        new PiChild(
          root,
          cwd,
          output,
          () => {
            if (!adapter.mutating) process.exit(1);
          },
          sessionPath,
        ),
      emit,
      () => process.exit(1),
      { resizeImage },
    );
    const ready = adapter.start();
    lines(process.stdin, (line) => {
      try {
        void adapter.handle(JSON.parse(line)).catch(() => process.exit(1));
      } catch {
        /* Invalid input is isolated. */
      }
    });
    process.stdin.on("end", async () => {
      await adapter.pi?.stop();
      process.exit(0);
    });
    await ready;
    return;
  }
  const { WorkspaceManager } = await import("./workspace_manager.mjs");
  const manager = new WorkspaceManager(
    service,
    (cwd, output, sessionPath, onExit) =>
      new PiChild(root, cwd, output, onExit, sessionPath),
    emit,
    { resizeImage },
  );
  await manager.initialize();
  const ready = manager.start();
  // Replies to startup extension questions must bypass readiness waits.
  lines(process.stdin, (line) => {
    try {
      void manager.handle(JSON.parse(line));
    } catch {
      /* Invalid input is isolated. */
    }
  });
  process.stdin.on("end", async () => {
    await manager.close();
    process.exit(0);
  });
  await ready;
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main().catch(() => {
    process.stderr.write("Pi GUI backend could not start.\n");
    process.exit(1);
  });
}
