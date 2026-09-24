// Real Pi RPC acceptance for the bundled pi-provider-switch 2.x extension.
// Isolated PI_CODING_AGENT_DIR + loopback /models server; never calls a model.
//
// Checks:
//  1. Every profile registers at load time; ids come from GET /models and
//     capabilities from the (seeded) models.dev cache; disabled ids hidden,
//     manual ids kept, a keyless local profile still counts as available.
//  2. Resuming a session keeps its recorded model (1.x forced the "active"
//     profile's default model on every session_start).
//  3. Editing provider-profiles.json while Pi runs updates the model list
//     without a restart (file watcher).
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { lines, resolvePiPackage } from "../assets/backend/workspace_rpc.mjs";

const root = await mkdtemp(path.join(tmpdir(), "pi-gui-provider-switch-"));
const agentDir = path.join(root, "agent");
const cwd = path.join(root, "work");
await mkdir(cwd, { recursive: true });
await mkdir(path.join(agentDir, ".cache", "provider-switch"), { recursive: true });
process.env.PI_CODING_AGENT_DIR = agentDir;
const packageRoot = await resolvePiPackage();
const extension = fileURLToPath(new URL("../pi-provider-switch/extensions/provider-switch.ts", import.meta.url));

let listed = ["gpt-5", "∞【relay】claude-opus-4-5", "mystery-model", "hidden-model"];
let requests = 0;
const server = createServer((request, response) => {
  requests++;
  if (!request.url?.endsWith("/models") || request.headers.authorization !== "Bearer test-key") {
    response.writeHead(401).end();
    return;
  }
  response.writeHead(200, { "content-type": "application/json" });
  response.end(JSON.stringify({ data: listed.map((id) => ({ id })) }));
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const baseUrl = `http://127.0.0.1:${server.address().port}/v1`;

// Seeded models.dev cache: the extension must use it offline.
await writeFile(path.join(agentDir, ".cache", "provider-switch", "models-dev.json"), JSON.stringify({
  version: 1,
  fetchedAt: Date.now(),
  entries: [
    ["openai", "gpt-5", 1, 1, 400000, 128000, ["minimal", "low", "medium", "high"]],
    ["anthropic", "claude-opus-4-5", 1, 1, 200000, 64000, ["low", "medium", "high"]],
  ],
}));
const profilesFile = path.join(agentDir, "provider-profiles.json");
const writeProfiles = (extra = {}) => writeFile(profilesFile, JSON.stringify({
  // Legacy 1.x fields must be ignored.
  active: "relay",
  profiles: {
    relay: {
      baseUrl, api: "openai-completions", apiKey: "test-key", defaultModel: "gpt-5",
      models: [{ id: "hidden-model", disabled: true }, { id: "private-alias", manual: true }],
    },
    local: { baseUrl: "http://127.0.0.1:9/v1", api: "openai-completions", syncModels: false, models: [{ id: "llama", manual: true }] },
    ...extra,
  },
}));
await writeProfiles();
await writeFile(path.join(agentDir, "settings.json"), JSON.stringify({ defaultProvider: "relay", defaultModel: "gpt-5" }));

function startPi(sessionPath) {
  const cli = path.join(packageRoot, "dist", "cli.js");
  const child = spawn(process.execPath, [cli, "--mode", "rpc", "--extension", extension,
    ...(sessionPath ? ["--session", sessionPath] : [])], {
    cwd, env: { ...process.env, PI_CODING_AGENT_DIR: agentDir }, stdio: ["pipe", "pipe", "pipe"], windowsHide: true,
  });
  let stderr = "";
  child.stderr.on("data", (d) => (stderr += d));
  const waits = new Map();
  let n = 0;
  lines(child.stdout, (line) => {
    let message;
    try { message = JSON.parse(line); } catch { return; }
    if (message.type === "response" && waits.has(message.id)) {
      waits.get(message.id)(message);
      waits.delete(message.id);
    }
  });
  const request = (type, fields = {}) => new Promise((resolve, reject) => {
    const id = `r${++n}`;
    const timer = setTimeout(() => reject(new Error(`${type} timed out\n${stderr}`)), 30000);
    waits.set(id, (m) => { clearTimeout(timer); m.success ? resolve(m.data) : reject(new Error(`${type}: ${m.error}`)); });
    child.stdin.write(JSON.stringify({ id, type, ...fields }) + "\n");
  });
  const stop = () => new Promise((resolve) => { child.once("exit", resolve); child.kill(); });
  return { request, stop };
}

const ids = (models, provider) => models.filter((m) => m.provider === provider).map((m) => m.id);
async function waitFor(check, label) {
  for (let i = 0; i < 80; i++) {
    const value = await check();
    if (value) return value;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`timed out waiting for ${label}`);
}

try {
  // 1. Registration + discovery + capabilities.
  let pi = startPi();
  const models = await waitFor(async () => {
    const { models } = await pi.request("get_available_models");
    return ids(models, "relay").includes("gpt-5") ? models : undefined;
  }, "discovered relay models");
  assert.deepEqual(ids(models, "relay"), ["gpt-5", "∞【relay】claude-opus-4-5", "mystery-model", "private-alias"]);
  assert.deepEqual(ids(models, "local"), ["llama"], "keyless manual profile must be available");
  const gpt = models.find((m) => m.provider === "relay" && m.id === "gpt-5");
  assert.equal(gpt.reasoning, true);
  assert.deepEqual(gpt.input, ["text", "image"]);
  assert.equal(gpt.contextWindow, 400000);
  assert.equal(gpt.thinkingLevelMap.xhigh, null);
  const claude = models.find((m) => m.id === "∞【relay】claude-opus-4-5");
  assert.equal(claude.reasoning, true, "decorated relay id resolves through models.dev");
  const mystery = models.find((m) => m.id === "mystery-model");
  assert.equal(mystery.reasoning, false);
  assert.deepEqual(mystery.input, ["text"]);

  await pi.stop();

  // A saved conversation that last used a non-default profile model.
  const { SessionManager } = await import(pathToFileURL(path.join(packageRoot, "dist/index.js")).href);
  const fixture = SessionManager.create(cwd);
  fixture.appendModelChange("relay", "mystery-model");
  fixture.appendMessage({ role: "user", content: "hello", timestamp: 1 });
  fixture.appendMessage({
    role: "assistant", content: [{ type: "text", text: "hi" }], api: "openai-completions",
    provider: "relay", model: "mystery-model", stopReason: "stop", timestamp: 2,
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
  });
  const sessionFile = fixture.getSessionFile();

  // 2. Resume keeps the recorded model (no forced default).
  pi = startPi(sessionFile);
  const resumed = await pi.request("get_state");
  assert.equal(resumed.model?.provider, "relay");
  assert.equal(resumed.model?.id, "mystery-model", "resumed session must keep its model");

  // 3. Live config edit: new profile + upstream change show up without restart.
  listed = [...listed, "gpt-5-mini"];
  await writeProfiles({ extra: { baseUrl, api: "openai-responses", apiKey: "test-key" } });
  const live = await waitFor(async () => {
    const { models } = await pi.request("get_available_models");
    return ids(models, "extra").length ? models : undefined;
  }, "live-added profile");
  assert.ok(ids(live, "extra").includes("gpt-5-mini"));
  const still = await pi.request("get_state");
  assert.equal(still.model?.id, "mystery-model", "config edits must not switch the model");
  await pi.stop();
  assert.ok(requests >= 2);
  console.log("provider-switch RPC checks passed");
} finally {
  server.close();
  await rm(root, { recursive: true, force: true }).catch(() => {});
}
