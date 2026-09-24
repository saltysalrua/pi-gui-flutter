// Real JSONL supervisor + multiple official Pi processes; no model calls.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, mkdir, cp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { resolvePiPackage, lines } from "../assets/backend/workspace_rpc.mjs";
const root = await mkdtemp(path.join(tmpdir(), "pi-gui-real-parallel-"));
process.env.PI_CODING_AGENT_DIR = path.join(root, "agent");
const packageRoot = await resolvePiPackage();
const { SessionManager } = await import(
  pathToFileURL(path.join(packageRoot, "dist/index.js")).href
);
const cwd = path.join(root, "中文 workspace");
await mkdir(cwd);
const other = path.join(root, "another project");
await mkdir(other);
const scripts = path.join(root, "backend");
await mkdir(scripts);
for (const name of [
  "workspace_rpc.mjs",
  "workspace_manager.mjs",
  "workspace_browser.mjs",
  "gui_tool_diff.mjs",
  "gui_image_upload.mjs",
  "gui_history.mjs",
]) {
  await cp(
    fileURLToPath(new URL(`../assets/backend/${name}`, import.meta.url)),
    path.join(scripts, name),
  );
}
const fixture = SessionManager.create(cwd);
fixture.appendMessage({ role: "user", content: "saved fixture", timestamp: 1 });
fixture.appendMessage({
  role: "assistant",
  content: [{ type: "text", text: "saved answer" }],
  api: "openai-responses",
  provider: "fixture",
  model: "fixture",
  usage: {
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
    totalTokens: 0,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
  },
  stopReason: "stop",
  timestamp: 2,
});
const child = spawn(
  process.execPath,
  [path.join(scripts, "workspace_rpc.mjs"), "--gui-multiplex"],
  {
    cwd,
    env: {
      ...process.env,
      PI_GUI_WORKSPACE_STORE: path.join(root, "gui.json"),
    },
    stdio: ["pipe", "pipe", "pipe"],
    windowsHide: true,
  },
);
child.stderr.resume();
const pending = new Map();
let sequence = 0;
lines(child.stdout, (line) => {
  let packet;
  try {
    packet = JSON.parse(line);
  } catch {
    return;
  }
  const { channel, message } = packet;
  if (
    message?.type === "extension_ui_request" &&
    ["select", "input", "confirm", "editor"].includes(message.method)
  ) {
    child.stdin.write(
      `${JSON.stringify({ type: "gui_channel", channel, message: { type: "extension_ui_response", id: message.id, cancelled: true } })}\n`,
    );
  }
  if (message?.type !== "response") return;
  const id = `${channel}/${message.id}`,
    item = pending.get(id);
  if (!item) return;
  pending.delete(id);
  clearTimeout(item.timer);
  if (message.success) item.resolve(message.data);
  else item.reject(Error(message.error));
});
function request(
  channel,
  type,
  fields = {},
  requestId = `probe-${++sequence}`,
) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(Error(`Timeout: ${channel}/${type}`)),
      45000,
    );
    pending.set(`${channel}/${requestId}`, { resolve, reject, timer });
    child.stdin.write(
      `${JSON.stringify({ type: "gui_channel", channel, message: { id: requestId, type, ...fields } })}\n`,
    );
  });
}
try {
  const catalog = await request("control", "gui_get_catalog");
  assert.equal(catalog.channels[0].id, "primary");
  const primaryState = await request("primary", "get_state");
  await request("control", "gui_open_channel", {
    channelId: "a",
    workspace: cwd,
  });
  await request("control", "gui_open_channel", {
    channelId: "b",
    workspace: cwd,
  });
  await Promise.all(["a", "b"].map((channel) => request(channel, "get_state")));
  const barrier = `const fs = require('fs'); const path = require('path'); const root = ${JSON.stringify(root)}; const me = process.argv[2]; fs.writeFileSync(path.join(root, me), 'ready'); const timer = setInterval(() => { if (fs.existsSync(path.join(root, me === 'a' ? 'b' : 'a'))) { console.log(process.cwd()); clearInterval(timer); process.exit(0); } }, 25); setTimeout(() => process.exit(2), 10000);`;
  await writeFile(path.join(cwd, "barrier.cjs"), barrier);
  const results = await Promise.all(
    ["a", "b"].map((channel) =>
      request(
        channel,
        "bash",
        { command: `node barrier.cjs ${channel}`, excludeFromContext: true },
        "same-id",
      ),
    ),
  );
  assert.ok(
    results.every(
      (r) =>
        r.exitCode === 0 &&
        path.normalize(r.output.trim()) === path.normalize(cwd),
    ),
  );
  const opened = await request("control", "gui_open_channel", {
    channelId: "history",
    workspace: cwd,
    sessionPath: fixture.getSessionFile(),
  });
  assert.equal(opened.id, "history");
  const again = await request("control", "gui_open_channel", {
    channelId: "duplicate",
    workspace: cwd,
    sessionPath: fixture.getSessionFile(),
  });
  assert.equal(again.id, "history");
  const messages = await request("history", "get_messages");
  assert.equal(messages.messages[1].content[0].text, "saved answer");
  await request("control", "gui_add_project", { path: other });
  await request("control", "gui_open_channel", {
    channelId: "other",
    workspace: other,
  });
  const actual = await request("other", "bash", {
    command: 'node -p "process.cwd()"',
    excludeFromContext: true,
  });
  assert.equal(path.normalize(actual.output.trim()), path.normalize(other));
  const bMessages = await request("b", "get_messages");
  await request("control", "gui_close_channel", { channelId: "a" });
  const after = await request("primary", "get_state");
  assert.equal(after.sessionId, primaryState.sessionId);
  assert.deepEqual(await request("b", "get_messages"), bMessages);
  console.log(
    "PASS: real multiplex JSONL, overlapping Pi bash barrier, same request IDs, same-directory sessions, history dedup, cross-project cwd, targeted close; no model calls.",
  );
} finally {
  for (const item of pending.values()) clearTimeout(item.timer);
  child.stdin.end();
  await new Promise((resolve) => {
    const timeout = setTimeout(() => {
      child.kill();
      resolve();
    }, 15000);
    child.once("exit", () => {
      clearTimeout(timeout);
      resolve();
    });
  });
  await rm(root, { recursive: true, force: true, maxRetries: 5 });
}
