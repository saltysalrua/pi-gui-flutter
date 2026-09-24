// GUI adapter for pi-provider-switch's own config file (not Pi's models.json).
// No extension is loaded or installed here. Credentials never travel back to Flutter.
//
// Listing rules and capability inference come from the plugin's catalog.mjs,
// bundled next to this file as provider_catalog.mjs, so the settings page and
// the running extension always agree on ids and badges.
import { readFile, mkdir, open, rename, unlink } from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { pathToFileURL } from "node:url";
import { WorkspaceError } from "./workspace_rpc.mjs";

const fail = (code) => { throw new WorkspaceError(code); };
// Pi provider ids are opaque strings; CJK names (e.g. 猫饭) are fine. No "/"
// (breaks provider/model references) and no whitespace.
const nameOk = (name) => typeof name === "string" && /^[\p{L}\p{N}][\p{L}\p{N}._-]{0,63}$/u.test(name) &&
  !["__proto__", "constructor", "prototype"].includes(name);
const apis = new Set(["openai-completions", "openai-responses", "anthropic-messages", "google-generative-ai"]);
const MAX_MODELS = 500;
/** A listing waits this long for a first models.dev download, then returns without badges. */
const CATALOG_WAIT_MS = 6000;

const safeEndpoint = (value) => {
  try {
    const url = new URL(value);
    return `${url.protocol}//${url.host}${url.pathname}`;
  } catch { return ""; }
};
const validEndpoint = (value) => {
  if (typeof value !== "string" || value.length > 2048) return false;
  try {
    const url = new URL(value);
    return ["https:", "http:"].includes(url.protocol) && !!url.hostname &&
      !url.username && !url.password && !url.search && !url.hash;
  } catch { return false; }
};
const sameEndpoint = (saved, requested, api) => {
  if (!validEndpoint(saved) || !validEndpoint(requested)) return false;
  try {
    const before = new URL(saved).href.replace(/\/+$/, "");
    const after = new URL(requested).href.replace(/\/+$/, "");
    return before === after || (api !== "google-generative-ai" &&
      !/\/v\d+[a-z]*$/i.test(before) && `${before}/v1` === after);
  } catch { return false; }
};
const validKey = (p) =>
  (p.apiKey === undefined || (typeof p.apiKey === "string" && p.apiKey.length <= 4096)) &&
  (p.clearApiKey === undefined || typeof p.clearApiKey === "boolean") &&
  !(p.clearApiKey && p.apiKey);
const idList = (value) => value === undefined || (Array.isArray(value) && value.length <= MAX_MODELS &&
  value.every((id) => typeof id === "string" && id.trim() && id.length <= 200));

// Dev scripts import this file from assets/backend; the app copies the plugin
// catalog next to it as provider_catalog.mjs.
async function loadCatalogModule() {
  try {
    return await import("./provider_catalog.mjs");
  } catch (error) {
    if (error?.code !== "ERR_MODULE_NOT_FOUND") throw error;
    return import("../../pi-provider-switch/extensions/provider-switch/catalog.mjs");
  }
}

export class GuiProviderProfiles {
  constructor(packageRoot) {
    this.packageRoot = packageRoot;
    this.queue = Promise.resolve();
    this.context = undefined;
  }

  async #context() {
    if (!this.context) {
      const [sdk, catalog] = await Promise.all([
        import(pathToFileURL(path.join(this.packageRoot, "dist/index.js")).href),
        loadCatalogModule(),
      ]);
      const agentDir = sdk.getAgentDir();
      const cacheDir = path.join(agentDir, ".cache", "provider-switch");
      this.context = {
        catalog,
        file: path.join(agentDir, "provider-profiles.json"),
        cacheDir,
        modelsDev: new catalog.ModelsDevCatalog(path.join(cacheDir, "models-dev.json")),
      };
    }
    return this.context;
  }

  async #read(file) {
    try {
      const data = JSON.parse(await readFile(file, "utf8"));
      if (!data || typeof data !== "object" || !data.profiles || typeof data.profiles !== "object" || Array.isArray(data.profiles)) fail("PROFILES_INVALID");
      if (Object.values(data.profiles).some(p => !p || typeof p !== "object" || Array.isArray(p) ||
          typeof p.baseUrl !== "string" || typeof p.api !== "string" ||
          (p.models !== undefined && (!Array.isArray(p.models) || p.models.some(m => !m || typeof m.id !== "string"))))) fail("PROFILES_INVALID");
      return data;
    } catch (error) {
      if (error.code === "ENOENT") return { profiles: {} };
      if (error instanceof SyntaxError) fail("PROFILES_INVALID");
      throw error;
    }
  }

  /** Public capability badges for one resolved model. */
  #modelInfo(ctx, profile, entry) {
    const { config } = ctx.catalog.resolveModel(profile, entry, ctx.modelsDev);
    return {
      id: entry.id,
      reasoning: config.reasoning === true,
      image: config.input.includes("image"),
      contextWindow: config.contextWindow,
    };
  }

  async #public(ctx, store) {
    const profiles = [];
    for (const [name, p] of Object.entries(store.profiles)) {
      const discovered = await ctx.catalog.readDiscovered(ctx.cacheDir, name);
      const synced = ctx.catalog.currentDiscovered(p, discovered) !== undefined;
      profiles.push({
        name,
        baseUrl: safeEndpoint(p.baseUrl),
        api: p.api,
        hasApiKey: !!p.apiKey,
        syncModels: p.syncModels !== false,
        syncedAt: synced ? discovered.syncedAt : null,
        models: ctx.catalog.profileModelEntries(p, discovered).map((entry) => ({
          ...this.#modelInfo(ctx, p, entry),
          enabled: entry.disabled !== true,
          manual: entry.manual === true,
          discovered: entry.discovered === true,
          custom: ctx.catalog.hasOverrides(entry),
        })),
      });
    }
    return { profiles };
  }

  async #write(file, store) {
    await mkdir(path.dirname(file), { recursive: true });
    const temporary = `${file}.${randomUUID()}.tmp`;
    try {
      const handle = await open(temporary, "wx", 0o600);
      try { await handle.writeFile(JSON.stringify(store, null, 2) + "\n", "utf8"); }
      finally { await handle.close(); }
      await rename(temporary, file);
    } finally { await unlink(temporary).catch(() => {}); }
  }

  // Serialize with other GUI edits, rereading the file for each operation so
  // plugin-side changes made in the meantime are not overwritten by a stale UI.
  #mutate(job) {
    const result = this.queue.then(job);
    this.queue = result.catch(() => {});
    return result;
  }

  // An empty apiKey reuses the saved key of `name` without echoing it back.
  async #models(request) {
    if (!validEndpoint(request.baseUrl) || !apis.has(request.api) || !validKey(request)) fail("PROFILE_INVALID");
    const ctx = await this.#context();
    let stored;
    if (!request.apiKey && !request.clearApiKey && nameOk(request.name)) {
      await this.queue;
      const store = await this.#read(ctx.file);
      if (Object.hasOwn(store.profiles, request.name)) {
        const profile = store.profiles[request.name];
        if (profile.apiKey && (!sameEndpoint(profile.baseUrl, request.baseUrl, profile.api) || profile.api !== request.api)) fail("PROFILE_KEY_ENDPOINT_CHANGED");
        stored = profile.apiKey;
      }
    }
    // Badges come from models.dev; a slow first download must not hold the list.
    const catalogReady = ctx.modelsDev.load({ allowNetwork: true });
    let result;
    try {
      const key = ctx.catalog.resolveApiKey(typeof request.apiKey === "string" && request.apiKey ? request.apiKey : stored);
      result = await ctx.catalog.discoverModelIds(request.baseUrl, request.api, key);
    } catch (error) {
      fail(typeof error?.code === "string" && error.code.startsWith("MODELS_") ? error.code : "MODELS_UNREACHABLE");
    }
    await Promise.race([catalogReady, new Promise((resolve) => setTimeout(resolve, CATALOG_WAIT_MS))]);
    const profile = { baseUrl: result.baseUrl, api: request.api };
    return {
      baseUrl: result.baseUrl,
      models: result.ids.map((id) => this.#modelInfo(ctx, profile, { id })),
    };
  }

  async #save(ctx, store, name, request) {
    const p = request.profile;
    // Rename: entry + discovered cache move to the new name in one write.
    const previous = typeof request.renameFrom === "string" &&
      request.renameFrom !== name ? request.renameFrom : undefined;
    if (!p || typeof p !== "object" || !validEndpoint(p.baseUrl) || !apis.has(p.api) ||
        typeof p.syncModels !== "boolean" || !idList(p.manual) || !idList(p.disabled) ||
        !idList(p.discovered) || !idList(p.listed) || !validKey(p)) fail("PROFILE_INVALID");
    if (request.createOnly && Object.hasOwn(store.profiles, name)) fail("PROFILE_EXISTS");
    if (previous) {
      if (!nameOk(previous)) fail("PROFILE_NAME_INVALID");
      if (!Object.hasOwn(store.profiles, previous)) fail("PROFILE_NOT_FOUND");
      if (Object.hasOwn(store.profiles, name)) fail("PROFILE_EXISTS");
      await rename(
        ctx.catalog.discoveredFile(ctx.cacheDir, previous),
        ctx.catalog.discoveredFile(ctx.cacheDir, name),
      ).catch(() => {});
    }
    const existing = Object.hasOwn(store.profiles, previous ?? name) ? store.profiles[previous ?? name] : {};
    if (existing.apiKey && !p.apiKey && !p.clearApiKey &&
        (!sameEndpoint(existing.baseUrl, p.baseUrl, existing.api) || existing.api !== p.api)) fail("PROFILE_KEY_ENDPOINT_CHANGED");

    const manual = new Set((p.manual ?? []).map((id) => id.trim()));
    const disabled = new Set((p.disabled ?? []).map((id) => id.trim()));
    const listed = new Set((p.listed ?? []).map((id) => id.trim()));
    const endpoint = ctx.catalog.endpointKey({ baseUrl: p.baseUrl, api: p.api });
    let discovered = await ctx.catalog.readDiscovered(ctx.cacheDir, name);
    if (p.discovered && p.syncModels) discovered = { endpoint, ids: p.discovered };
    // Without any listing for this endpoint, 1.x plain {id} entries are the
    // only model list; keep the ones the editor still shows.
    const keepPlain = !p.syncModels || discovered?.endpoint !== endpoint;
    // Pins keep their advanced per-model settings; only the flags change.
    const models = [];
    const seen = new Set();
    for (const entry of Array.isArray(existing.models) ? existing.models : []) {
      if (!entry || typeof entry.id !== "string" || seen.has(entry.id)) continue;
      seen.add(entry.id);
      const { manual: _m, disabled: _d, ...rest } = entry;
      const next = { ...rest, ...(manual.has(entry.id) ? { manual: true } : {}), ...(disabled.has(entry.id) ? { disabled: true } : {}) };
      if (ctx.catalog.hasOverrides(next) || next.manual || next.disabled || (keepPlain && listed.has(entry.id))) models.push(next);
    }
    for (const id of [...manual, ...disabled]) {
      if (seen.has(id)) continue;
      seen.add(id);
      models.push({ id, ...(manual.has(id) ? { manual: true } : {}), ...(disabled.has(id) ? { disabled: true } : {}) });
    }
    const { defaultModel: _legacyDefault, models: _old, ...kept } = existing;
    const profile = {
      ...kept,
      baseUrl: p.baseUrl,
      api: p.api,
      ...(p.apiKey ? { apiKey: p.apiKey } : {}),
      ...(p.syncModels ? {} : { syncModels: false }),
      ...(models.length ? { models } : {}),
    };
    if (p.syncModels) delete profile.syncModels;
    if (p.clearApiKey) delete profile.apiKey;

    // At least one model must remain visible, or the provider would vanish.
    const visible = ctx.catalog.profileModelEntries(profile, discovered).filter((m) => m.disabled !== true);
    if (!visible.length) fail("PROFILE_NO_MODELS");

    store.profiles[name] = profile;
    if (previous) delete store.profiles[previous];
    // 1.x selection fields are ignored by 2.x; drop them so nobody relies on them.
    delete store.active;
    await this.#write(ctx.file, store);
    if (p.discovered && p.syncModels) await ctx.catalog.writeDiscovered(ctx.cacheDir, name, profile, p.discovered);
    else if (!p.syncModels) await ctx.catalog.removeDiscovered(ctx.cacheDir, name);
  }

  async handle(request) {
    if (request.type === "gui_provider_profiles_state") {
      await this.queue;
      const ctx = await this.#context();
      await ctx.modelsDev.load({ allowNetwork: false });
      return this.#public(ctx, await this.#read(ctx.file));
    }
    if (request.type === "gui_provider_profiles_models") return this.#models(request);
    return this.#mutate(async () => {
      const ctx = await this.#context();
      const store = await this.#read(ctx.file);
      const name = request.name;
      if (!nameOk(name)) fail("PROFILE_NAME_INVALID");
      if (request.type === "gui_provider_profiles_save") {
        await this.#save(ctx, store, name, request);
      } else if (request.type === "gui_provider_profiles_remove") {
        if (!Object.hasOwn(store.profiles, name)) fail("PROFILE_NOT_FOUND");
        delete store.profiles[name];
        if (store.active === name) delete store.active;
        await this.#write(ctx.file, store);
        await ctx.catalog.removeDiscovered(ctx.cacheDir, name);
      } else fail("UNKNOWN_COMMAND");
      await ctx.modelsDev.load({ allowNetwork: false });
      return this.#public(ctx, store);
    });
  }
}
