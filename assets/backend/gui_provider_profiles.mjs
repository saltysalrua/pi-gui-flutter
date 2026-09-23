// GUI adapter for provider-switch's own config file (not Pi's models.json).
// No extension is loaded or installed here. Credentials never travel back to Flutter.
import { readFile, mkdir, open, rename, unlink } from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { execSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import { WorkspaceError } from "./workspace_rpc.mjs";

const fail = (code) => { throw new WorkspaceError(code); };
const nameOk = (name) => typeof name === "string" && /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$/.test(name) &&
  !["__proto__", "constructor", "prototype"].includes(name);
const apis = new Set(["openai-completions", "openai-responses", "anthropic-messages", "google-generative-ai"]);
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

// Same key forms as provider-switch: literal, "$VAR"/"${VAR}", "!command".
const resolveKey = (value) => {
  if (typeof value !== "string" || !value) return undefined;
  if (value.startsWith("!")) {
    try { return execSync(value.slice(1), { encoding: "utf8", timeout: 5000, windowsHide: true }).trim() || undefined; }
    catch { fail("MODELS_KEY_COMMAND_FAILED"); }
  }
  const env = value.match(/^\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))$/);
  if (env) return process.env[env[1] ?? env[2]] || fail("MODELS_KEY_ENV_MISSING");
  return value;
};

// Only GET {baseUrl}/models (a listing, not a model request). Mirrors the
// plugin's fetchModelIds so GUI and /provider-add agree on the result.
async function listModels(root, api, key) {
  const url = `${root}/models`;
  // Never put credentials in the URL or follow redirects to another origin.
  const headers = api === "anthropic-messages" ? { "anthropic-version": "2023-06-01" } : {};
  if (key) {
    if (api === "anthropic-messages") { headers["x-api-key"] = key; headers["anthropic-version"] = "2023-06-01"; }
    else if (api === "google-generative-ai") headers["x-goog-api-key"] = key;
    else headers.authorization = `Bearer ${key}`;
  }
  let res;
  try { res = await fetch(url, { headers, redirect: "error", signal: AbortSignal.timeout(8000) }); }
  catch { fail("MODELS_UNREACHABLE"); }
  if (res.status === 401 || res.status === 403) fail("MODELS_UNAUTHORIZED");
  if (!res.ok) fail("MODELS_HTTP_ERROR");
  let payload;
  try { payload = JSON.parse(await res.text()); } catch { fail("MODELS_NOT_JSON"); }
  const raw = Array.isArray(payload?.data) ? payload.data : Array.isArray(payload?.models) ? payload.models : [];
  const ids = raw.map(m => typeof m === "string" ? m : (m?.id ?? m?.name ?? ""))
    .filter(id => typeof id === "string").map(id => (api === "google-generative-ai" ? id.replace(/^models\//, "") : id).trim())
    .filter(id => id && id.length <= 200);
  return [...new Set(ids)].slice(0, 500);
}

export class GuiProviderProfiles {
  constructor(packageRoot) {
    this.packageRoot = packageRoot;
    this.queue = Promise.resolve();
  }

  async #location() {
    const sdk = await import(pathToFileURL(path.join(this.packageRoot, "dist/index.js")).href);
    return path.join(sdk.getAgentDir(), "provider-profiles.json");
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

  #public(store) {
    return {
      active: store.active ?? null,
      profiles: Object.entries(store.profiles).map(([name, p]) => ({
        name, baseUrl: safeEndpoint(p.baseUrl), api: p.api, reasoning: p.reasoning === true,
        models: Array.isArray(p.models) ? p.models.map(m => m.id).filter(id => typeof id === "string") : [],
        defaultModel: p.defaultModel ?? null, hasApiKey: !!p.apiKey,
      })),
    };
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
    let stored;
    if (!request.apiKey && !request.clearApiKey && nameOk(request.name)) {
      await this.queue;
      const store = await this.#read(await this.#location());
      if (Object.hasOwn(store.profiles, request.name)) {
        const profile = store.profiles[request.name];
        if (profile.apiKey && (!sameEndpoint(profile.baseUrl, request.baseUrl, profile.api) || profile.api !== request.api)) fail("PROFILE_KEY_ENDPOINT_CHANGED");
        stored = profile.apiKey;
      }
    }
    const key = resolveKey(typeof request.apiKey === "string" && request.apiKey ? request.apiKey : stored);
    const root = request.baseUrl.replace(/\/+$/, "");
    const candidates = [root];
    if (request.api !== "google-generative-ai" && !/\/v\d+[a-z]*$/i.test(root)) candidates.push(`${root}/v1`);
    let lastError;
    for (const candidate of candidates) {
      try {
        const models = await listModels(candidate, request.api, key);
        if (!models.length) fail("MODELS_EMPTY");
        return { baseUrl: candidate, models };
      } catch (error) {
        // Auth failures will not improve with another path; report them now.
        if (error.code === "MODELS_UNAUTHORIZED") throw error;
        lastError = error;
      }
    }
    throw lastError;
  }

  async handle(request) {
    if (request.type === "gui_provider_profiles_state") {
      await this.queue;
      return this.#public(await this.#read(await this.#location()));
    }
    if (request.type === "gui_provider_profiles_models") return this.#models(request);
    return this.#mutate(async () => {
      const file = await this.#location();
      const store = await this.#read(file);
      const name = request.name;
      if (!nameOk(name)) fail("PROFILE_NAME_INVALID");
      if (request.type === "gui_provider_profiles_save") {
        const p = request.profile;
        if (!p || typeof p !== "object" || !validEndpoint(p.baseUrl) ||
            !apis.has(p.api) || typeof p.reasoning !== "boolean" || !Array.isArray(p.models) ||
            !p.models.length || p.models.length > 500 || p.models.some(id => typeof id !== "string" || !id.trim() || id.length > 200) ||
            typeof p.defaultModel !== "string" || !p.models.includes(p.defaultModel) ||
            !validKey(p)) fail("PROFILE_INVALID");
        if (request.createOnly && Object.hasOwn(store.profiles, name)) fail("PROFILE_EXISTS");
        const existing = Object.hasOwn(store.profiles, name) ? store.profiles[name] : {};
        if (existing.apiKey && !p.apiKey && !p.clearApiKey &&
            (!sameEndpoint(existing.baseUrl, p.baseUrl, existing.api) || existing.api !== p.api)) fail("PROFILE_KEY_ENDPOINT_CHANGED");
        // Preserve advanced model/routing settings for unchanged IDs.
        const oldModels = new Map((Array.isArray(existing.models) ? existing.models : []).map(m => [m.id, m]));
        store.profiles[name] = {
          ...existing, baseUrl: p.baseUrl, api: p.api, reasoning: p.reasoning,
          models: [...new Set(p.models)].map(id => oldModels.get(id) ?? { id }),
          defaultModel: p.defaultModel,
          ...(p.apiKey ? { apiKey: p.apiKey } : {}),
        };
        if (p.clearApiKey) delete store.profiles[name].apiKey;
      } else if (request.type === "gui_provider_profiles_remove") {
        if (!Object.hasOwn(store.profiles, name)) fail("PROFILE_NOT_FOUND");
        delete store.profiles[name];
        if (store.active === name) delete store.active;
      } else if (request.type === "gui_provider_profiles_activate") {
        if (!Object.hasOwn(store.profiles, name)) fail("PROFILE_NOT_FOUND");
        store.active = name;
      } else fail("UNKNOWN_COMMAND");
      await this.#write(file, store);
      return this.#public(store);
    });
  }
}
