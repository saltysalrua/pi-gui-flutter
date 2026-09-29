// Registry + persisted state for the GUI's built-in Pi hooks: the extensions
// injected with --extension at every Pi child launch. No Pi internals, no
// settings.json writes — state lives in a GUI-owned JSON file next to the
// workspace store, so Pi's own configuration is never touched.
//
// States per hook:
//   "active"  injected into newly started Pi processes (default, omitted
//             from the store file so a fresh install stays empty)
//   "off"     switch disabled by the user; same effect as removed in
//             injection terms, but kept visible in the enabled list
//   "removed" "uninstalled" by the user: permanently not injected until
//             restored from the settings page (bundled asset files cannot
//             be deleted; updates re-ship them but keep honoring this file)
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";

const fail = (code) => {
  const error = new Error(code);
  error.code = code;
  throw error;
};

const STATES = new Set(["active", "off", "removed"]);

// Injection order is part of the contract: keep tool_diff before history so
// the write-diff middleware always registers first in every Pi process.
export const BUILTIN_HOOKS = [
  { id: "tool_diff", file: "gui_tool_diff.mjs" },
  { id: "history", file: "gui_history.mjs" },
];

export function hooksStorePath() {
  return (
    process.env.PI_GUI_HOOKS_STORE ??
    path.join(
      process.env.APPDATA ??
        process.env.XDG_CONFIG_HOME ??
        path.join(homedir(), ".config"),
      "pi-gui",
      "hooks.json",
    )
  );
}

export class GuiHooks {
  constructor(storePath = hooksStorePath()) {
    this.storePath = storePath;
    this.states = new Map();
    this.persistenceWarning = false;
  }

  async initialize() {
    try {
      const saved = JSON.parse(await readFile(this.storePath, "utf8"));
      const states = saved?.states;
      if (states && typeof states === "object" && !Array.isArray(states)) {
        for (const hook of BUILTIN_HOOKS) {
          const state = states[hook.id];
          if (STATES.has(state)) this.states.set(hook.id, state);
        }
      }
    } catch (error) {
      // A missing store is the normal first-run case, not a warning.
      if (error.code !== "ENOENT") this.persistenceWarning = true;
    }
  }

  state(id) {
    return this.states.get(id) ?? "active";
  }

  list() {
    return {
      hooks: BUILTIN_HOOKS.map((hook) => ({
        ...hook,
        state: this.state(hook.id),
      })),
      persistenceWarning: this.persistenceWarning,
    };
  }

  /** File names of the hooks to inject into a newly started Pi child. */
  injected() {
    return new Set(
      BUILTIN_HOOKS.filter((hook) => this.state(hook.id) === "active").map(
        (hook) => hook.file,
      ),
    );
  }

  async set(id, state) {
    if (!BUILTIN_HOOKS.some((hook) => hook.id === id)) fail("HOOKS_UNKNOWN");
    if (!STATES.has(state)) fail("HOOKS_INVALID_STATE");
    if (state === "active") this.states.delete(id);
    else this.states.set(id, state);
    await this.save();
    return this.list();
  }

  async save() {
    try {
      await mkdir(path.dirname(this.storePath), { recursive: true });
      const temp = `${this.storePath}.${process.pid}.tmp`;
      await writeFile(
        temp,
        JSON.stringify({
          version: 1,
          states: Object.fromEntries(this.states),
        }),
        "utf8",
      );
      await rename(temp, this.storePath);
      this.persistenceWarning = false;
    } catch {
      this.persistenceWarning = true;
    }
  }
}

// Control-channel bridge. Same lazy-import + handle shape as the packages
// bridge; the instance reuses the one owned by main() so a state change is
// visible to every PiChild spawned afterwards.
export class GuiHooksBridge {
  constructor(hooks) {
    this.hooks = hooks;
  }

  async handle(request) {
    switch (request.type) {
      case "gui_hooks_state":
        return this.hooks.list();
      case "gui_hooks_set":
        return this.hooks.set(request.hookId, request.state);
      default:
        fail("UNKNOWN_COMMAND");
    }
  }
}