// Packaged assets -> production --gui-multiplex router -> real Pi + public SDK.
// Isolated from user settings/history; no model calls.
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, rm, readFile, cp } from "node:fs/promises";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";
import { lines, resolvePiPackage } from "../assets/backend/workspace_rpc.mjs";
const root = await mkdtemp(path.join(tmpdir(), "pi-gui-history-"));
const previous = process.env.PI_CODING_AGENT_DIR;
const previousOffline = process.env.PI_OFFLINE;
process.env.PI_CODING_AGENT_DIR = path.join(root, "agent");
process.env.PI_OFFLINE = "1";
let child;
const pending = new Map();
try {
  await mkdir(process.env.PI_CODING_AGENT_DIR);
  await writeFile(path.join(process.env.PI_CODING_AGENT_DIR, "settings.json"), JSON.stringify({ defaultProvider: "anthropic", defaultModel: "claude-sonnet-4-5", compaction: { enabled: false } }));
  const packageRoot = await resolvePiPackage();
  const { SessionManager } = await import(pathToFileURL(path.join(packageRoot, "dist/index.js")).href);
  const sm = SessionManager.create(root);
  const user = (content, timestamp) => sm.appendMessage({ role: "user", content, timestamp });
  const assistant = (text, timestamp) => sm.appendMessage({ role: "assistant", content: [{ type: "text", text }], timestamp, api: "anthropic-messages", provider: "anthropic", model: "claude-sonnet-4-5", stopReason: "stop", usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } });
  const first = user("first prompt", 1);
  const answer = assistant("first answer", 2);
  const image = { type: "image", data: "aGVsbG8=", mimeType: "image/png" };
  const second = user([{ type: "text", text: "edit me" }, image], 3);
  const oldLeaf = assistant("old branch", 4);
  sm.branch(answer);
  const other = user("alternative", 5);
  assistant("new branch", 6);
  sm.appendCompaction("Fixture compacted history", other, 1000);
  sm.appendLabelChange(oldLeaf, "bookmark");
  const sourceFile = sm.getSessionFile();
  const hook = path.join(root, "history-hooks.mjs");
  await writeFile(hook, `export default function(pi) {
    pi.on('session_before_fork', (e) => {
      if(e.entryId === ${JSON.stringify(first)} && e.position === 'before') return {cancel:true};
    });
    pi.on('session_before_tree', (e) => {
      if(e.preparation.targetId === ${JSON.stringify(other)}) return {cancel:true};
      if(e.preparation.userWantsSummary) return {summary:{summary:'Fixture branch summary', details:{fixture:true}}};
    });
  }`);
  await writeFile(path.join(process.env.PI_CODING_AGENT_DIR, "settings.json"), JSON.stringify({ defaultProvider: "anthropic", defaultModel: "claude-sonnet-4-5", compaction: { enabled: false }, extensions: [hook] }));
  const scripts = path.join(root, "backend");
  await mkdir(scripts);
  for (const name of ["workspace_rpc.mjs", "workspace_manager.mjs", "workspace_browser.mjs", "gui_tool_diff.mjs", "gui_history.mjs", "gui_image_upload.mjs", "gui_packages.mjs"]) {
    await cp(fileURLToPath(new URL(`../assets/backend/${name}`, import.meta.url)), path.join(scripts, name));
  }
  const events = [];
  child = spawn(process.execPath, [path.join(scripts, "workspace_rpc.mjs"), "--gui-multiplex"], {
    cwd: root,
    env: { ...process.env, HOME: root, USERPROFILE: root, PI_GUI_WORKSPACE_STORE: path.join(root, "gui.json"), PI_GUI_PI_PACKAGE_DIR: packageRoot },
    stdio: ["pipe", "pipe", "pipe"], windowsHide: true,
  });
  child.stderr.resume();
  const rejectPending = (error) => {
    for (const item of pending.values()) { clearTimeout(item.timer); item.reject(error); }
    pending.clear();
  };
  child.once("error", rejectPending);
  child.once("exit", () => rejectPending(new Error("Multiplex process exited")));
  lines(child.stdout, (line) => {
    const packet = JSON.parse(line), event = packet.message;
    if (!event) return;
    events.push(event);
    if (event.type === "extension_ui_request" && ["select", "confirm", "input", "editor"].includes(event.method)) {
      child.stdin.write(`${JSON.stringify({ type: "gui_channel", channel: packet.channel, message: { type: "extension_ui_response", id: event.id, cancelled: true } })}\n`);
    }
    const key = `${packet.channel}/${event.id}`, item = pending.get(key);
    if (event.type !== "response" || !item) return;
    pending.delete(key); clearTimeout(item.timer);
    if (event.success) item.resolve(event.data); else item.reject(Object.assign(new Error(event.error), { code: event.error }));
  });
  let sequence = 0;
  const requestAt = (channel, type, fields = {}) => new Promise((resolve, reject) => {
    const id = `probe-${++sequence}`, key = `${channel}/${id}`;
    const timer = setTimeout(() => { pending.delete(key); reject(new Error(`Timeout: ${channel}/${type}`)); }, 30000);
    pending.set(key, { resolve, reject, timer });
    child.stdin.write(`${JSON.stringify({ type: "gui_channel", channel, message: { id, type, ...fields } })}\n`);
  });
  await requestAt("control", "gui_get_catalog");
  await requestAt("control", "gui_open_channel", { channelId: "history", workspace: root, sessionPath: sourceFile });
  await requestAt("control", "gui_open_channel", { channelId: "sibling", workspace: root });
  const siblingState = await requestAt("sibling", "get_state");
  const request = (type, fields = {}) => requestAt("history", type, fields);
  const identity = async () => ({ sessionId: (await request("get_state")).sessionId, leafId: (await request("get_entries")).leafId });
  const full = await request("get_entries");
  assert(full.entries.some((e) => e.id === oldLeaf));
  assert(full.entries.some((e) => e.id === full.leafId));
  const initial = await identity();
  assert((await request('get_messages')).messages.some(m => m.role === 'compactionSummary'));
  assert.equal((await request("gui_history_entry", {...initial, entryId: second})).entry.id, second);
  await assert.rejects(requestAt("sibling", "gui_history_entry", {...initial, entryId: second}), {code:"HISTORY_STALE"});
  await request("gui_history_label", {...initial, entryId: answer, label: "kept label"});
  const beforeCancel = await identity();
  assert.equal((await request("gui_history_navigate", {...beforeCancel, entryId: other})).cancelled, true);
  assert.equal((await identity()).leafId, beforeCancel.leafId);
  await assert.rejects(request("gui_history_navigate", {...initial, leafId:"stale", entryId:first}), {code:"HISTORY_STALE"});
  const rewound = await request("gui_history_navigate", {...await identity(), entryId:second});
  assert.equal(rewound.editorText, "edit me");
  assert.deepEqual(rewound.images, [image]);
  assert.equal((await identity()).leafId, answer);
  assert.equal((await request("get_entries")).entries.filter((e)=>e.type==='message').length, 6);
  await request("gui_history_navigate", {...await identity(), entryId:oldLeaf});
  const summarized = await request("gui_history_navigate", {...await identity(), entryId:answer, summarize:true, customInstructions:"focus", replaceInstructions:true});
  assert.equal(summarized.cancelled, false);
  assert((await request("get_entries")).entries.some((e)=>e.type==='branch_summary' && e.summary==='Fixture branch summary'));
  await request("gui_history_navigate", {...await identity(), entryId:first});
  assert.equal((await identity()).leafId, null);
  assert.equal((await request("get_messages")).messages.length, 0);
  // Fork an inactive/abandoned user node without first switching to its path.
  await request("gui_history_navigate", {...await identity(), entryId:answer});
  assert((await request('get_fork_messages')).messages.some(m => m.entryId === second));
  const sourceBeforeFork = await readFile(sourceFile, "utf8");
  assert.equal((await request('gui_history_fork', {...await identity(), entryId:first})).cancelled, true);
  assert.equal((await request('get_state')).sessionFile, sourceFile);
  const fork = await request("gui_history_fork", {...await identity(), entryId:second});
  assert.equal(fork.cancelled, false); assert.equal(fork.editorText, "edit me"); assert.deepEqual(fork.images, [image]);
  const forkState = await request("get_state");
  assert.notEqual(forkState.sessionFile, sourceFile);
  assert.equal(await readFile(sourceFile,"utf8"), sourceBeforeFork);
  assert.equal((await request("get_messages")).messages.filter((m)=>m.role==='user').length, 1);
  const reopened = await requestAt("control", "gui_open_channel", {channelId:"original", workspace:root, sessionPath:sourceFile});
  assert.equal(reopened.id, "original");
  const originalState = await requestAt("original", "get_state");
  assert.equal(originalState.sessionFile, sourceFile);
  assert.notEqual(originalState.sessionId, forkState.sessionId);
  // Replacement reloaded the bridge; labels must still be dispatchable by provenance.
  const forkEntries = await request("get_entries");
  await request("gui_history_label", {...await identity(), entryId:forkEntries.leafId, label:"fork label"});
  assert.equal((await request("gui_history_clone", await identity())).cancelled, false);
  assert.notEqual((await request("get_state")).sessionFile, forkState.sessionFile);
  assert.equal((await requestAt("sibling", "get_state")).sessionId, siblingState.sessionId);
  assert.deepEqual((await requestAt("sibling", "get_messages")).messages, []);
  assert(!events.some((e) => e.type === "agent_start"));
  assert(!events.some((e) => e.type === "extension_error"));
  console.log("PASS: packaged 7 assets + production multiplex + real Pi: preview, full branches, labels, stale guards, extension cancellation/custom summary, root reset, image draft, native fork/clone, source reopen, sibling isolation, bridge reload; no model calls.");
} finally {
  for (const item of pending.values()) clearTimeout(item.timer);
  if (child && child.exitCode === null && child.signalCode === null) {
    await new Promise((resolve) => {
      const timer = setTimeout(() => { child.kill(); resolve(); }, 15000);
      child.once("exit", () => { clearTimeout(timer); resolve(); });
      child.stdin.end();
    });
  }
  if (previous === undefined) delete process.env.PI_CODING_AGENT_DIR; else process.env.PI_CODING_AGENT_DIR = previous;
  if (previousOffline === undefined) delete process.env.PI_OFFLINE; else process.env.PI_OFFLINE = previousOffline;
  await rm(root, {recursive:true,force:true,maxRetries:5});
}
