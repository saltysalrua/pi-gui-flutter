// No model requests, no changes to the user's Pi history or project checkout.
import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import {
  WorkspaceService,
  WorkspaceAdapter,
  PiChild,
  resolvePiPackage,
} from "../assets/backend/workspace_rpc.mjs";

const root = await mkdtemp(path.join(tmpdir(), "pi-gui-real-rpc-"));
process.env.PI_CODING_AGENT_DIR = path.join(root, "agent");
const repo = path.join(root, "历史 workspace");
await mkdir(repo);
const packageRoot = await resolvePiPackage();
const { SessionManager } = await import(
  pathToFileURL(path.join(packageRoot, "dist/index.js")).href
);
const session = SessionManager.create(repo);
session.appendMessage({
  role: "user",
  content: "fixture 中文\u2028message",
  timestamp: 1,
});
session.appendMessage({
  role: "assistant",
  content: [{ type: "text", text: "saved response" }],
  api: "openai-responses",
  provider: "openai",
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
session.appendSessionInfo("真实 SDK 历史");
const service = new WorkspaceService(
  SessionManager,
  path.join(root, "prefs.json"),
  repo,
);
await service.initialize();
const replies = new Map();
let id = 0,
  active = 0,
  maximum = 0;
const events = [];
const adapter = new WorkspaceAdapter(
  service,
  (cwd, output, sessionPath) => {
    active++;
    maximum = Math.max(active, maximum);
    const child = new PiChild(packageRoot, cwd, output, () => {}, sessionPath, [
      "--no-extensions",
      "--no-skills",
      "--no-prompt-templates",
    ]);
    const stop = child.stop.bind(child);
    child.stop = async () => {
      await stop();
      active--;
    };
    return child;
  },
  (line) => {
    let value;
    try {
      value = JSON.parse(line);
    } catch {
      return;
    }
    if (value.type === "response" && replies.has(value.id)) {
      const pending = replies.get(value.id);
      replies.delete(value.id);
      clearTimeout(pending.timer);
      if (value.success) pending.resolve(value.data);
      else pending.reject(Error(`${value.command}: ${value.error}`));
    } else {
      events.push(value);
    }
  },
);
const request = (type, fields = {}) =>
  new Promise((resolve, reject) => {
    const requestId = `probe-${++id}`;
    const timer = setTimeout(() => reject(Error(`Timeout: ${type}`)), 45000);
    replies.set(requestId, { resolve, reject, timer });
    void adapter.handle({ id: requestId, type, ...fields }).catch(reject);
  });
try {
  await adapter.start();
  const listed = await request("gui_list_sessions");
  assert.equal(listed.sessions.length, 1);
  assert.equal(listed.sessions[0].title, "真实 SDK 历史");
  assert.equal(
    (await request("switch_session", { sessionPath: session.getSessionFile() }))
      .cancelled,
    false,
  );
  const history = await request("get_messages");
  assert.equal(history.messages.length, 2);
  assert.equal(history.messages[1].content[0].text, "saved response");
  const next = await request("gui_create_workspace", {
    parent: root,
    name: "new & 中文",
  });
  const switched = await request("gui_open_workspace", { path: next.path });
  assert.equal(switched.current.path, next.path);
  assert.equal((await request("get_messages")).messages.length, 0);
  assert.equal((await request("gui_list_sessions")).sessions.length, 0);
  const cwd = await request("bash", {
    command: 'node -p "process.cwd()"',
    excludeFromContext: true,
  });
  assert.equal(path.normalize(cwd.output.trim()), path.normalize(next.path));
  await request("gui_open_workspace", { path: repo });
  await request("switch_session", { sessionPath: session.getSessionFile() });
  assert.equal(
    (await request("get_messages")).messages[0].content,
    "fixture 中文\u2028message",
  );
  assert.equal(maximum, 1);
  assert.equal(
    events.filter((e) => e.type === "gui_workspace_changed").length,
    2,
  );
  console.log(
    "PASS: SDK history discovery, RPC content, Unicode/spaces, actual cwd switch, restore, one Pi process; no model calls.",
  );
} finally {
  for (const pending of replies.values()) clearTimeout(pending.timer);
  await adapter.pi?.stop();
  await rm(root, { recursive: true, force: true, maxRetries: 5 });
}
