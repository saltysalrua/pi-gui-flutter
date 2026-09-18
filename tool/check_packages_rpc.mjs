// Bounded, no-model, no-network regression for the settings packages bridge.
// Uses a throwaway PI_AGENT_DIR so real settings are never touched.
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { GuiPackagesBridge } from "../assets/backend/gui_packages.mjs";
import { resolvePiPackage } from "../assets/backend/workspace_rpc.mjs";

const packageRoot = await resolvePiPackage();
const agentDir = await mkdtemp(path.join(tmpdir(), "pi-gui-packages-"));
// The SDK reads PI_CODING_AGENT_DIR (ENV_AGENT_DIR) at getAgentDir() time.
process.env.PI_CODING_AGENT_DIR = agentDir;
const sep = path.sep;
const events = [];
const bridge = new GuiPackagesBridge({
  packageRoot,
  emit: (message) => events.push(message),
});
const settingsPath = path.join(agentDir, "settings.json");
// Failing loud on malformed settings is the point of this probe; the wrap
// only adds context so a SyntaxError is never mistaken for a write bug.
const readSettings = async () => {
  let raw;
  try {
    raw = await readFile(settingsPath, "utf8");
    return JSON.parse(raw);
  } catch (error) {
    assert.fail(`settings.json unreadable: ${String(error)}\n${raw ?? ""}`);
  }
};
const lastEvent = (type) => events.filter((e) => e.type === type).at(-1);

async function put(file, content) {
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, content, "utf8");
}

await mkdir(path.join(agentDir, "extensions"), { recursive: true });
await put(path.join(agentDir, "extensions", "test.ts"), "// test\n");
await put(path.join(agentDir, "extensions", "disabled.ts"), "// off\n");
await put(path.join(agentDir, "skills", "demo", "SKILL.md"), "# demo\n");
await put(path.join(agentDir, "prompts", "p.md"), "prompt\n");
await put(path.join(agentDir, "themes", "t.json"), '{"name":"t"}\n');
const pkgRoot = path.join(agentDir, "npm", "node_modules", "fake-pkg");
await put(
  path.join(pkgRoot, "package.json"),
  JSON.stringify({
    name: "fake-pkg",
    version: "1.0.0",
    keywords: ["pi-package"],
    pi: { extensions: ["./extensions"] },
  }),
);
await put(path.join(pkgRoot, "extensions", "index.ts"), "// pkg\n");
await writeFile(
  settingsPath,
  JSON.stringify({
    packages: ["npm:fake-pkg"],
    extensions: [`-extensions${sep}disabled.ts`],
  }),
  "utf8",
);

// 1. state lists configured packages and resolved resources.
const state = await bridge.handle({ type: "gui_packages_state" });
assert.equal(state.version, 1);
assert.equal(state.agentDir, agentDir);
assert.deepEqual(state.packages, [
  {
    source: "npm:fake-pkg",
    scope: "user",
    filtered: false,
    installedPath: pkgRoot,
  },
]);
const extensions = state.resources.extensions;
const byPath = (list, tail) => list.find((r) => r.path.endsWith(tail));
assert.ok(byPath(extensions, `extensions${sep}test.ts`));
assert.equal(byPath(extensions, `extensions${sep}test.ts`).enabled, true);
assert.equal(byPath(extensions, `extensions${sep}disabled.ts`).enabled, false);
const pkgResource = byPath(extensions, `index.ts`);
assert.ok(pkgResource, "package extension resolved");
assert.equal(pkgResource.origin, "package");
assert.equal(pkgResource.baseDir, pkgRoot);
assert.ok(byPath(state.resources.skills, "SKILL.md"));
assert.ok(byPath(state.resources.prompts, "p.md"));
assert.ok(byPath(state.resources.themes, "t.json"));

// 2. toggling a top-level row writes the same +/- pattern as `pi config`.
const topLevel = byPath(extensions, `extensions${sep}test.ts`);
await bridge.handle({
  type: "gui_packages_toggle",
  resourceType: "extensions",
  ...topLevel,
  enabled: false,
});
let settings = await readSettings();
assert.deepEqual(settings.extensions, [
  `-extensions${sep}disabled.ts`,
  `-extensions${sep}test.ts`,
]);
const afterTop = await bridge.handle({ type: "gui_packages_state" });
assert.equal(
  byPath(afterTop.resources.extensions, `extensions${sep}test.ts`).enabled,
  false,
);
// Re-enabling collapses back to a +pattern entry.
await bridge.handle({
  type: "gui_packages_toggle",
  resourceType: "extensions",
  ...topLevel,
  enabled: true,
});
settings = await readSettings();
assert.ok(settings.extensions.includes(`+extensions${sep}test.ts`));

// 3. toggling a package row writes into the package filter object and an
// empty filter collapses back to a plain source string.
await bridge.handle({
  type: "gui_packages_toggle",
  resourceType: "extensions",
  ...pkgResource,
  enabled: false,
});
settings = await readSettings();
assert.deepEqual(settings.packages, [
  { source: "npm:fake-pkg", extensions: [`-extensions${sep}index.ts`] },
]);
const afterPkg = await bridge.handle({ type: "gui_packages_state" });
assert.equal(afterPkg.packages[0].filtered, true);
assert.equal(byPath(afterPkg.resources.extensions, "index.ts").enabled, false);
await bridge.handle({
  type: "gui_packages_toggle",
  resourceType: "extensions",
  ...pkgResource,
  enabled: true,
});
settings = await readSettings();
// Re-enabling keeps the +pattern, matching pi config byte-for-byte.
assert.deepEqual(settings.packages, [
  { source: "npm:fake-pkg", extensions: [`+extensions${sep}index.ts`] },
]);

// 4. async mutations reply with an operation id and finish via events.
const reply = await bridge.handle({
  type: "gui_packages_update",
  operationId: "op-1",
  source: "npm:not-installed",
});
assert.deepEqual(reply, { operationId: "op-1" });
for (let i = 0; i < 50 && !lastEvent("gui_packages_finished"); i++) {
  await new Promise((resolve) => setTimeout(resolve, 20));
}
const finished = lastEvent("gui_packages_finished");
assert.equal(finished.operationId, "op-1");
assert.equal(finished.ok, false);
assert.ok(finished.error, "error code/message surfaced");

// 5. validation stays strict.
await assert.rejects(
  () => bridge.handle({ type: "gui_packages_bogus" }),
  /UNKNOWN_COMMAND/,
);
await assert.rejects(
  () =>
    bridge.handle({
      type: "gui_packages_toggle",
      resourceType: "extensions",
      path: "x",
      enabled: true,
      origin: "top-level",
      source: "local",
      scope: "project",
    }),
  /PACKAGE_SCOPE_READ_ONLY/,
);
await assert.rejects(
  () => bridge.handle({ type: "gui_packages_install" }),
  /INVALID_SOURCE/,
);

await rm(agentDir, { recursive: true, force: true });
console.log("check_packages_rpc: all assertions passed");
