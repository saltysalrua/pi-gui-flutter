// Real supervisor + real Pi: extension ui.custom screens (e.g. /bill reports)
// must surface as pi-gui-custom: prefixed setWidget events instead of being
// silently dropped by pi's RPC no-op. No model calls.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { cp, mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { resolvePiPackage, lines } from "../assets/backend/workspace_rpc.mjs";

const root = await mkdtemp(path.join(tmpdir(), "pi-gui-custom-rpc-"));
process.env.PI_CODING_AGENT_DIR = path.join(root, "agent");
const agentDir = process.env.PI_CODING_AGENT_DIR;
await mkdir(agentDir);

const extension = [
  "export default function (pi) {",
  "  pi.registerCommand('customtest', {",
  "    description: 'custom screen probe',",
  "    handler: async (_args, ctx) => {",
  "      await ctx.ui.custom((_tui, _theme, _kb, done) => ({",
  "        render(width) {",
  "          return [",
  "            'Usage bill',",
  "            '\u2500'.repeat(Math.min(width, 40)),",
  "            'today - 3 request(s)',",
  "          ];",
  "        },",
  "        invalidate() {},",
  "        handleInput() { done(); },",
  "      }));",
  "    },",
  "  });",
  "}",
].join("\n");
const extensionPath = path.join(root, "customtest.mjs");
await writeFile(extensionPath, extension, "utf8");
await writeFile(
  path.join(agentDir, "settings.json"),
  JSON.stringify({ extensions: [extensionPath] }),
  "utf8",
);

const cwd = path.join(root, "workspace");
await mkdir(cwd);
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
const customEvents = [];
lines(child.stdout, (line) => {
  let packet;
  try {
    packet = JSON.parse(line);
  } catch {
    return;
  }
  const message = packet.message;
  if (message?.type === "extension_ui_request" && message.method === "setWidget") {
    customEvents.push(message);
  }
  if (message?.type !== "response") return;
  const id = `${packet.channel}/${message?.id}`;
  const item = pending.get(id);
  if (!item) return;
  pending.delete(id);
  clearTimeout(item.timer);
  if (message.success) item.resolve(message.data);
  else item.reject(new Error(message.error ?? "PI failed"));
});
function request(target, type, fields = {}, requestId = `probe-${++sequence}`) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`Timeout: ${target}/${type}`)),
      45000,
    );
    pending.set(`${target}/${requestId}`, {
      resolve: (data) => {
        clearTimeout(timer);
        resolve(data);
      },
      reject: (error) => {
        clearTimeout(timer);
        reject(error);
      },
    });
    child.stdin.write(
      `${JSON.stringify({
        type: "gui_channel",
        channel: target,
        message: { id: requestId, type, ...fields },
      })}\n`,
    );
  });
}

try {
  await request("control", "gui_get_catalog", {}, "catalog");
  const commands = await request("primary", "get_commands");
  assert.ok(
    commands.commands.some((command) => command.name === "customtest"),
    "customtest command must be registered",
  );
  // ui.custom now mirrors interactive mode: the slash command stays pending
  // until the component calls done(), so the prompt must NOT resolve yet.
  let promptSettled = false;
  const promptDone = request("primary", "prompt", {
    message: "/customtest",
  }, "slash-run").finally(() => { promptSettled = true; });
  const deadline = Date.now() + 30000;
  while (!customEvents.length && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  assert.ok(
    customEvents.length > 0,
    "ui.custom must emit a setWidget event instead of being dropped",
  );
  const screen = customEvents.find((event) =>
    String(event.widgetKey ?? "").startsWith("pi-gui-custom:"),
  );
  assert.ok(screen, "setWidget event must carry the pi-gui-custom: prefix");
  assert.ok(
    screen.widgetLines.includes("Usage bill"),
    "rendered lines must carry the report title",
  );
  assert.ok(
    screen.widgetLines.includes("today - 3 request(s)"),
    "rendered lines must carry the report body",
  );
  await new Promise((resolve) => setTimeout(resolve, 300));
  assert.equal(promptSettled, false, "command must wait for done()");
  // A GUI keystroke reaches component.handleInput, which calls done().
  child.stdin.write(
    `${JSON.stringify({
      type: "gui_channel",
      channel: "primary",
      message: { type: "extension_ui_response", id: screen.widgetKey, value: "" },
    })}
`,
  );
  await promptDone;
  const clearDeadline = Date.now() + 5000;
  const cleared = () => customEvents.some(
    (event) => event.widgetKey === screen.widgetKey && event.widgetLines == null,
  );
  while (!cleared() && Date.now() < clearDeadline) {
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  assert.ok(cleared(), "done() must clear the custom screen");
  console.log(
    "PASS: ui.custom renders, receives keystrokes, blocks until done() and clears; no model calls.",
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