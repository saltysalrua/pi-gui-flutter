// Packaged assets -> production --gui-multiplex router -> real Pi child.
// Isolated from user settings/stores; no model calls.
//
// Verifies the built-in hook registry end to end:
//  - gui_hooks_state lists both built-in hooks, default active, empty store
//  - gui_hooks_set off/removed/active transitions persist to hooks.json
//  - injection follows state at spawn time: a channel started after history
//    is unregistered lacks the pi-gui-history extension command, while a
//    channel started before the change keeps it (running sessions unaffected)
//  - unknown hook ids and states fail with explicit error codes
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile, cp } from "node:fs/promises";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { lines, resolvePiPackage } from "../assets/backend/workspace_rpc.mjs";
import { GuiHooks, BUILTIN_HOOKS } from "../assets/backend/gui_hooks.mjs";

const root = await mkdtemp(path.join(tmpdir(), "pi-gui-hooks-"));
const previous = process.env.PI_CODING_AGENT_DIR;
process.env.PI_CODING_AGENT_DIR = path.join(root, "agent");
process.env.PI_OFFLINE = "1";
let child;
const pending = new Map();

// --- unit part: pure registry behavior, no process spawned -----------------
{
  const dir = path.join(root, "unit");
  const hooks = new GuiHooks(path.join(dir, "hooks.json"));
  await hooks.initialize();
  assert.equal(hooks.persistenceWarning, false);
  assert.deepEqual(
    hooks
      .injected()
      .has(...BUILTIN_HOOKS.map((hook) => hook.file)),
    true,
  );
  assert.deepEqual(hooks.list().hooks, [
    { id: "tool_diff", file: "gui_tool_diff.mjs", state: "active" },
    { id: "history", file: "gui_history.mjs", state: "active" },
  ]);
  // Injection order is registry order: tool_diff registers first.
  assert.deepEqual(
    BUILTIN_HOOKS.map((hook) => hook.file),
    ["gui_tool_diff.mjs", "gui_history.mjs"],
  );
  await hooks.set("history", "removed");
  assert.deepEqual([...hooks.injected()], ["gui_tool_diff.mjs"]);
  await hooks.set("history", "active");
  // Fresh installs stay empty: "active" is the default and is never written.
  assert.equal((await readStates(path.join(dir, "hooks.json"))).history, undefined);
  await assert.rejects(hooks.set("nope", "off"), { code: "HOOKS_UNKNOWN" });
  await assert.rejects(hooks.set("tool_diff", "broken"), {
    code: "HOOKS_INVALID_STATE",
  });
}

// Store reads go through one guarded helper: a missing file is the normal
// first-run case, a corrupt file is a genuine check failure.
async function readStates(file) {
  let raw;
  try {
    raw = await readFile(file, "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return undefined;
    throw error;
  }
  try {
    return JSON.parse(raw).states ?? {};
  } catch {
    return undefined;
  }
}

// --- e2e part: multiplex router with real Pi children ------------------------
const hooksStore = path.join(root, "hooks.json");
try {
  await mkdir(process.env.PI_CODING_AGENT_DIR);
  // Model metadata without credentials or network/model calls.
  await writeFile(
    path.join(process.env.PI_CODING_AGENT_DIR, "auth.json"),
    JSON.stringify({
      anthropic: { type: "api_key", key: "context-fixture-not-a-real-key" },
    }),
  );
  await writeFile(
    path.join(process.env.PI_CODING_AGENT_DIR, "settings.json"),
    JSON.stringify({
      defaultProvider: "anthropic",
      defaultModel: "claude-senet-4-5",
      compaction: { enabled: false },
    }),
  );
  const scripts = path.join(root, "backend");
  await mkdir(scripts);
  for (const name of [
    "workspace_rpc.mjs",
    "workspace_manager.mjs",
    "workspace_browser.mjs",
    "gui_tool_diff.mjs",
    "gui_history.mjs",
    "gui_hooks.mjs",
    "gui_image_upload.mjs",
    "gui_packages.mjs",
  ]) {
    await cp(
      fileURLToPath(new URL(`../assets/backend/${name}`, import.meta.url)),
      path.join(scripts, name),
    );
  }
  child = spawn(
    process.execPath,
    [path.join(scripts, "workspace_rpc.mjs"), "--gui-multiplex"],
    {
      cwd: root,
      env: {
        ...process.env,
        HOME: root,
        USERPROFILE: root,
        PI_GUI_WORKSPACE_STORE: path.join(root, "gui.json"),
        PI_GUI_HOOKS_STORE: hooksStore,
        PI_GUI_PI_PACKAGE_DIR: await resolvePiPackage(),
      },
      stdio: ["pipe", "pipe", "pipe"],
      windowsHide: true,
    },
  );
  child.stderr.pipe(process.stderr);
  const rejectPending = (error) => {
    for (const item of pending.values()) {
      clearTimeout(item.timer);
      item.reject(error);
    }
    pending.clear();
  };
  child.once("error", rejectPending);
  child.once("exit", () => rejectPending(new Error("Multiplex exited")));
  lines(child.stdout, (line) => {
    const packet = JSON.parse(line);
    const event = packet.message;
    if (!event) return;
    if (
      event.type === "extension_ui_request" &&
      ["select", "confirm", "input", "editor"].includes(event.method)
    ) {
      child.stdin.write(
        `${JSON.stringify({
          type: "gui_channel",
          channel: packet.channel,
          message: {
            type: "extension_ui_response",
            id: event.id,
            cancelled: true,
          },
        })}\n`,
      );
    }
    const key = `${packet.channel}/${event.id}`;
    const item = pending.get(key);
    if (event.type !== "response" || !item) return;
    pending.delete(key);
    clearTimeout(item.timer);
    if (event.success) item.resolve(event.data);
    else {
      const error = new Error(`${event.error} (${event.command})`);
      error.code = event.error;
      item.reject(error);
    }
  });
  let sequence = 0;
  const requestAt = (channel, type, fields = {}) =>
    new Promise((resolve, reject) => {
      const id = `hooks-${++sequence}`;
      const key = `${channel}/${id}`;
      const timer = setTimeout(() => {
        pending.delete(key);
        reject(new Error(`Timeout: ${channel}/${type}`));
      }, 60000);
      pending.set(key, { resolve, reject, timer });
      child.stdin.write(
        `${JSON.stringify({
          type: "gui_channel",
          channel,
          message: { id, type, ...fields },
        })}\n`,
      );
    });
  const control = (type, fields) => requestAt("control", type, fields);
  const openChannel = (name) =>
    control("gui_open_channel", { channelId: name, workspace: root });

  // Warm the router: registers the cwd workspace before channels open.
  await control("gui_get_catalog");

  // Default state: both hooks active, nothing written yet.
  const first = await control("gui_hooks_state");
  assert.deepEqual(first.hooks, [
    { id: "tool_diff", file: "gui_tool_diff.mjs", state: "active" },
    { id: "history", file: "gui_history.mjs", state: "active" },
  ]);
  assert.equal(first.persistenceWarning, false);

  // A channel started now has the history bridge extension command.
  await openChannel("before");
  const beforeCommands = await requestAt("before", "get_commands");
  const beforeHistory = beforeCommands.commands.find(
    (command) => command.name === "pi-gui-history",
  );
  assert.equal(beforeHistory?.source, "extension");

  // Uninstall the history hook; the store reflects it.
  const afterRemove = await control("gui_hooks_set", {
    hookId: "history",
    state: "removed",
  });
  assert.equal(
    afterRemove.hooks.find((hook) => hook.id === "history").state,
    "removed",
  );
  assert.equal((await readStates(hooksStore)).history, "removed");

  // The already-running channel is untouched: changes are spawn-time only.
  const unchangedCommands = await requestAt("before", "get_commands");
  assert(
    unchangedCommands.commands.some(
      (command) => command.name === "pi-gui-history",
    ),
  );

  // A channel started after the removal has no history extension command,
  // proving the injection args were trimmed for the new Pi child.
  await openChannel("after");
  const afterCommands = await requestAt("after", "get_commands");
  assert(
    !afterCommands.commands.some(
      (command) => command.name === "pi-gui-history",
    ),
  );

  // Switching to "off" and back to "active": active is omitted from the store.
  await control("gui_hooks_set", { hookId: "history", state: "off" });
  assert.equal((await readStates(hooksStore)).history, "off");
  const restored = await control("gui_hooks_set", {
    hookId: "history",
    state: "active",
  });
  assert.equal(
    restored.hooks.find((hook) => hook.id === "history").state,
    "active",
  );
  assert.deepEqual(await readStates(hooksStore), {});

  // Explicit error codes for bad requests.
  await assert.rejects(
    control("gui_hooks_set", { hookId: "nope", state: "off" }),
    { code: "HOOKS_UNKNOWN" },
  );
  await assert.rejects(
    control("gui_hooks_set", { hookId: "tool_diff", state: "broken" }),
    { code: "HOOKS_INVALID_STATE" },
  );

  console.log(
    "PASS: packaged assets + multiplex router + real Pi children: hook registry defaults, spawn-time injection cut (new channel lacks the uninstalled extension, running channel keeps it), off/removed/active persistence to hooks.json, explicit HOOKS_* error codes; no model calls.",
  );
} finally {
  process.env.PI_CODING_AGENT_DIR = previous;
  child?.stdin.end();
  await new Promise((resolve) => {
    child?.once("exit", resolve);
    child?.kill();
    setTimeout(resolve, 5000).unref?.();
  });
  child?.kill();
  await rm(root, { recursive: true, force: true, maxRetries: 5 }).catch(() => {});
}