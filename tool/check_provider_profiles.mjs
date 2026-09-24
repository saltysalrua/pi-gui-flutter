// Offline control-adapter check; never touches the user's real Pi agent dir
// and never downloads models.dev (a seeded cache is used).
import assert from "node:assert/strict";
import { access, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import os from "node:os";
import path from "node:path";
import { resolvePiPackage } from "../assets/backend/workspace_rpc.mjs";

const dir = await mkdtemp(path.join(os.tmpdir(), "pi-gui-profiles-"));
process.env.PI_CODING_AGENT_DIR = dir;
const cacheDir = path.join(dir, ".cache", "provider-switch");
await mkdir(cacheDir, { recursive: true });
await writeFile(path.join(cacheDir, "models-dev.json"), JSON.stringify({
  version: 1, fetchedAt: Date.now(),
  entries: [["openai", "m-1", 1, 1, 400000, 64000, ["low", "medium", "high"]]],
}));
try {
  const { GuiProviderProfiles } = await import("../assets/backend/gui_provider_profiles.mjs");
  const packageRoot = process.env.PI_GUI_PI_PACKAGE_DIR ?? await resolvePiPackage();
  const bridge = new GuiProviderProfiles(packageRoot);
  const state = () => bridge.handle({ type: "gui_provider_profiles_state" });
  const file = path.join(dir, "provider-profiles.json");
  assert.equal((await state()).profiles.length, 0);
  await assert.rejects(access(file));

  const profile = { baseUrl: "https://example.test/v1", api: "openai-responses", syncModels: false,
    manual: ["a", "b"], apiKey: "secret-test-key" };
  const saved = await bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile });
  assert.equal(saved.profiles[0].hasApiKey, true);
  assert.equal(JSON.stringify(saved).includes(profile.apiKey), false);
  assert.deepEqual(saved.profiles[0].models.map((m) => [m.id, m.manual, m.enabled]), [["a", true, true], ["b", true, true]]);

  // Advanced per-model settings and unknown fields survive GUI edits; legacy
  // 1.x selection fields are dropped.
  const advanced = JSON.parse(await readFile(file, "utf8"));
  advanced.active = "test-profile";
  advanced.profiles["test-profile"].defaultModel = "a";
  advanced.profiles["test-profile"].modelRules = [{ match: ["b"], reasoning: true }];
  advanced.profiles["test-profile"].models[1].contextWindow = 16384;
  await writeFile(file, JSON.stringify(advanced));
  const edited = await bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: {
    ...profile, manual: ["b"], disabled: [], apiKey: undefined,
  }});
  const disk = JSON.parse(await readFile(file, "utf8"));
  assert.equal(disk.active, undefined);
  assert.equal(disk.profiles["test-profile"].defaultModel, undefined);
  assert.equal(disk.profiles["test-profile"].apiKey, profile.apiKey);
  assert.deepEqual(disk.profiles["test-profile"].models, [{ id: "b", contextWindow: 16384, manual: true }]);
  assert.equal(disk.profiles["test-profile"].modelRules[0].match[0], "b");
  const b = edited.profiles[0].models[0];
  assert.equal(b.reasoning, true, "modelRule reasoning reaches the badge");
  assert.equal(b.contextWindow, 16384);
  assert.equal(b.custom, true);

  await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: {
    ...profile, manual: ["b"], disabled: ["b"], apiKey: undefined,
  }}), { code: "PROFILE_NO_MODELS" });
  await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "__proto__", profile }));
  await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "bad name", profile }));
  await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile, createOnly: true }), { code: "PROFILE_EXISTS" });
  await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: {
    ...profile, baseUrl: "https://other.test/v1", apiKey: undefined,
  }}), { code: "PROFILE_KEY_ENDPOINT_CHANGED" });
  await assert.rejects(bridge.handle({ type: "gui_provider_profiles_activate", name: "test-profile" }), { code: "UNKNOWN_COMMAND" });

  // Loopback /v1/models: /v1 is appended automatically and a blank key reuses
  // the saved key server-side (never returned to the caller).
  const requests = [];
  const server = createServer((req, res) => {
    requests.push(req.url);
    if (req.url === "/redirect/models") { res.writeHead(302, { location: "/should-not-follow" }); return res.end(); }
    if (req.url === "/v1beta/models") {
      assert.equal(req.headers["x-goog-api-key"], profile.apiKey);
      res.writeHead(200); return res.end(JSON.stringify({ models: [{ name: "models/gemini-test" }] }));
    }
    if (req.url === "/anthropic/models") {
      assert.equal(req.headers["x-api-key"], profile.apiKey);
      assert.equal(req.headers["anthropic-version"], "2023-06-01");
      res.writeHead(200); return res.end(JSON.stringify({ data: [{ id: "claude-test" }] }));
    }
    if (req.url === "/empty/models") { res.writeHead(200); return res.end('{"data":[]}'); }
    if (req.url === "/html/models") { res.writeHead(200); return res.end('<html>not a model list</html>'); }
    if (req.url === "/local/models") {
      assert.equal(req.headers.authorization, undefined);
      res.writeHead(200); return res.end('{"data":[{"id":"local-model"}]}');
    }
    if (req.url !== "/v1/models") { res.writeHead(404); return res.end("nope"); }
    if (req.headers.authorization !== `Bearer ${profile.apiKey}`) { res.writeHead(401); return res.end(); }
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ data: [{ id: "m-1" }, { id: "models/m-2" }, { id: "m-1" }] }));
  });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const list = (args) => bridge.handle({ type: "gui_provider_profiles_models", api: "openai-responses", ...args });
    const callsBefore = requests.length;
    await assert.rejects(list({ name: "test-profile", baseUrl }), { code: "PROFILE_KEY_ENDPOINT_CHANGED" });
    assert.equal(requests.length, callsBefore, "must not send a saved key to a changed endpoint");
    await bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: { ...profile, baseUrl, manual: ["b"] } });
    const listed = await list({ name: "test-profile", baseUrl });
    assert.equal(listed.baseUrl, `${baseUrl}/v1`);
    assert.deepEqual(listed.models.map((m) => m.id), ["m-1", "models/m-2"]);
    assert.deepEqual([listed.models[0].reasoning, listed.models[0].image, listed.models[0].contextWindow], [true, true, 400000]);
    assert.equal(listed.models[1].reasoning, false);
    assert.equal(JSON.stringify(listed).includes(profile.apiKey), false);
    assert.deepEqual((await list({ baseUrl: `${baseUrl}/v1beta`, api: "google-generative-ai", apiKey: profile.apiKey })).models.map((m) => m.id), ["gemini-test"]);
    assert.deepEqual((await list({ baseUrl: `${baseUrl}/anthropic`, api: "anthropic-messages", apiKey: profile.apiKey })).models.map((m) => m.id), ["claude-test"]);
    assert.deepEqual((await list({ name: "test-profile", baseUrl: `${baseUrl}/local`, clearApiKey: true })).models.map((m) => m.id), ["local-model"]);
    await assert.rejects(list({ baseUrl: `${baseUrl}/redirect`, api: "google-generative-ai", apiKey: profile.apiKey }), { code: "MODELS_UNREACHABLE" });
    assert.equal(requests.includes("/should-not-follow"), false);
    await assert.rejects(list({ baseUrl: `${baseUrl}/empty`, api: "google-generative-ai" }), { code: "MODELS_EMPTY" });
    await assert.rejects(list({ baseUrl: `${baseUrl}/html`, api: "google-generative-ai" }), { code: "MODELS_NOT_JSON" });
    await assert.rejects(bridge.handle({ type: "gui_provider_profiles_models", baseUrl, api: "openai-completions", apiKey: "wrong" }),
      { code: "MODELS_UNAUTHORIZED" });
    await assert.rejects(bridge.handle({ type: "gui_provider_profiles_models", baseUrl, api: "openai-completions", apiKey: "$PI_GUI_SURELY_MISSING" }),
      { code: "MODELS_KEY_ENV_MISSING" });

    // Sync on: discovered ids go to the cache file, not the config; a disabled
    // id is the only pin written.
    const synced = await bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: {
      ...profile, baseUrl: listed.baseUrl, syncModels: true, manual: [], disabled: ["models/m-2"],
      discovered: listed.models.map((m) => m.id), apiKey: undefined,
    }});
    const syncedDisk = JSON.parse(await readFile(file, "utf8")).profiles["test-profile"];
    assert.equal(syncedDisk.syncModels, undefined);
    assert.deepEqual(syncedDisk.models, [{ id: "b", contextWindow: 16384 }, { id: "models/m-2", disabled: true }],
      "custom legacy entry survives, disabled marker written, discovered ids not copied");
    assert.deepEqual(synced.profiles[0].models.map((m) => [m.id, m.enabled, m.discovered]),
      [["m-1", true, true], ["models/m-2", false, true], ["b", true, false]]);
    assert.ok(synced.profiles[0].syncedAt > 0);
    const cache = JSON.parse(await readFile(path.join(cacheDir, "discovered-test-profile.json"), "utf8"));
    assert.deepEqual(cache.ids, ["m-1", "models/m-2"]);

    const noKey = await bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: {
      ...profile, baseUrl: listed.baseUrl, syncModels: true, manual: [], apiKey: undefined, clearApiKey: true,
    }});
    assert.equal(noKey.profiles[0].hasApiKey, false);
    assert.equal(JSON.parse(await readFile(file, "utf8")).profiles["test-profile"].apiKey, undefined);

    // Rename: entry and discovered cache move to the new name in one write;
    // the plugin's file watcher unregisters the old provider from this.
    const cacheBefore = await readFile(path.join(cacheDir, "discovered-test-profile.json"), "utf8");
    const plain = { ...profile, baseUrl: listed.baseUrl, syncModels: true, manual: [], apiKey: undefined };
    const renamed = await bridge.handle({ type: "gui_provider_profiles_save", name: "renamed-profile", renameFrom: "test-profile", profile: plain });
    assert.deepEqual(Object.keys(JSON.parse(await readFile(file, "utf8")).profiles), ["renamed-profile"]);
    assert.equal(renamed.profiles[0].name, "renamed-profile");
    assert.deepEqual(renamed.profiles[0].models.map((m) => [m.id, m.discovered]),
      [["m-1", true], ["models/m-2", true], ["b", false]]);
    assert.equal(await readFile(path.join(cacheDir, "discovered-renamed-profile.json"), "utf8"), cacheBefore,
      "discovered cache moves with the rename");
    await assert.rejects(access(path.join(cacheDir, "discovered-test-profile.json")));
    // Renaming onto a taken name, or from a missing one, fails cleanly
    // without touching the cache of the profile being renamed.
    const second = await bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: { ...plain, manual: ["c"], apiKey: profile.apiKey } });
    assert.equal(second.profiles.length, 2);
    await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", renameFrom: "renamed-profile", profile: plain }), { code: "PROFILE_EXISTS" });
    assert.equal(await readFile(path.join(cacheDir, "discovered-renamed-profile.json"), "utf8"), cacheBefore);
    await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "other", renameFrom: "ghost", profile: plain }), { code: "PROFILE_NOT_FOUND" });
    await assert.equal((await bridge.handle({ type: "gui_provider_profiles_remove", name: "test-profile" })).profiles.length, 1);
  } finally { server.closeAllConnections(); server.close(); }
  assert.equal((await bridge.handle({ type: "gui_provider_profiles_remove", name: "renamed-profile" })).profiles.length, 0);
  await assert.rejects(access(path.join(cacheDir, "discovered-renamed-profile.json")));
  console.log("provider profiles: isolated save/edit/rename/remove + discovery cache + badges + no key echo + loopback listing OK");
} finally {
  await rm(dir, { recursive: true, force: true });
}
