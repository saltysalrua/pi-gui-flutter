// Offline control-adapter check; never touches the user's real Pi agent dir.
import assert from "node:assert/strict";
import { access, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import os from "node:os";
import path from "node:path";
import { resolvePiPackage } from "../assets/backend/workspace_rpc.mjs";

const dir = await mkdtemp(path.join(os.tmpdir(), "pi-gui-profiles-"));
process.env.PI_CODING_AGENT_DIR = dir;
try {
  const { GuiProviderProfiles } = await import("../assets/backend/gui_provider_profiles.mjs");
  const packageRoot = process.env.PI_GUI_PI_PACKAGE_DIR ?? await resolvePiPackage();
  const bridge = new GuiProviderProfiles(packageRoot);
  const state = () => bridge.handle({ type: "gui_provider_profiles_state" });
  assert.equal((await state()).profiles.length, 0);
  await assert.rejects(access(path.join(dir, "provider-profiles.json")));
  const profile = { baseUrl: "https://example.test/v1", api: "openai-responses", reasoning: false,
    models: ["a", "b"], defaultModel: "a", apiKey: "secret-test-key" };
  const saved = await bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile });
  assert.equal(saved.profiles[0].hasApiKey, true);
  assert.equal(JSON.stringify(saved).includes(profile.apiKey), false);
  assert.equal((await state()).profiles[0].models.length, 2);
  const file = path.join(dir, "provider-profiles.json");
  const advanced = JSON.parse(await readFile(file, "utf8"));
  advanced.profiles["test-profile"].modelRules = [{ match: ["b"], reasoning: true }];
  advanced.profiles["test-profile"].models[1].contextWindow = 16384;
  await writeFile(file, JSON.stringify(advanced));
  await bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: {
    ...profile, models: ["b"], defaultModel: "b", apiKey: undefined,
  }});
  const active = await bridge.handle({ type: "gui_provider_profiles_activate", name: "test-profile" });
  assert.equal(active.active, "test-profile");
  const disk = JSON.parse(await readFile(path.join(dir, "provider-profiles.json"), "utf8"));
  assert.equal(disk.profiles["test-profile"].apiKey, profile.apiKey);
  assert.deepEqual(disk.profiles["test-profile"].models, [{ id: "b", contextWindow: 16384 }]);
  assert.equal(disk.profiles["test-profile"].modelRules[0].match[0], "b");
  await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "__proto__", profile }));
  await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "bad name", profile }));
  assert.equal((await state()).profiles.length, 1);
  await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile, createOnly: true }), { code: "PROFILE_EXISTS" });
  await assert.rejects(bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: {
    ...profile, baseUrl: "https://other.test/v1", apiKey: undefined,
  }}), { code: "PROFILE_KEY_ENDPOINT_CHANGED" });

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
    await bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: { ...profile, baseUrl } });
    const listed = await list({ name: "test-profile", baseUrl });
    assert.deepEqual(listed, { baseUrl: `${baseUrl}/v1`, models: ["m-1", "models/m-2"] });
    assert.equal(JSON.stringify(listed).includes(profile.apiKey), false);
    assert.deepEqual((await list({ baseUrl: `${baseUrl}/v1beta`, api: "google-generative-ai", apiKey: profile.apiKey })).models, ["gemini-test"]);
    assert.deepEqual((await list({ baseUrl: `${baseUrl}/anthropic`, api: "anthropic-messages", apiKey: profile.apiKey })).models, ["claude-test"]);
    assert.deepEqual((await list({ name: "test-profile", baseUrl: `${baseUrl}/local`, clearApiKey: true })).models, ["local-model"]);
    await assert.rejects(list({ baseUrl: `${baseUrl}/redirect`, api: "google-generative-ai", apiKey: profile.apiKey }), { code: "MODELS_UNREACHABLE" });
    assert.equal(requests.includes("/should-not-follow"), false);
    await assert.rejects(list({ baseUrl: `${baseUrl}/empty`, api: "google-generative-ai" }), { code: "MODELS_EMPTY" });
    await assert.rejects(list({ baseUrl: `${baseUrl}/html`, api: "google-generative-ai" }), { code: "MODELS_NOT_JSON" });
    await assert.rejects(bridge.handle({ type: "gui_provider_profiles_models", baseUrl, api: "openai-completions", apiKey: "wrong" }),
      { code: "MODELS_UNAUTHORIZED" });
    await assert.rejects(bridge.handle({ type: "gui_provider_profiles_models", baseUrl, api: "openai-completions", apiKey: "$PI_GUI_SURELY_MISSING" }),
      { code: "MODELS_KEY_ENV_MISSING" });
    const noKey = await bridge.handle({ type: "gui_provider_profiles_save", name: "test-profile", profile: {
      ...profile, baseUrl, apiKey: undefined, clearApiKey: true,
    }});
    assert.equal(noKey.profiles[0].hasApiKey, false);
    assert.equal(JSON.parse(await readFile(file, "utf8")).profiles["test-profile"].apiKey, undefined);
  } finally { server.closeAllConnections(); server.close(); }
  assert.equal((await bridge.handle({ type: "gui_provider_profiles_remove", name: "test-profile" })).active, null);
  console.log("provider profiles: isolated read/save/edit/activate/remove + no key echo + loopback model listing OK");
} finally {
  await rm(dir, { recursive: true, force: true });
}
