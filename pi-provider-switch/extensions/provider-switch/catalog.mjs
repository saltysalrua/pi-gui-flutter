// Shared model discovery + capability metadata for pi-provider-switch.
//
// Plain ESM JavaScript (no TypeScript syntax) on purpose: the pi extension
// imports it through jiti, and the Pi GUI's Node control adapter imports the
// very same file, so listing rules and capability inference never drift.
//
// Capability metadata follows the pattern of the yuukarin / 猫饭 relay
// providers: model ids come live from GET {baseUrl}/models, and reasoning,
// image input, context window, output limit and thinking effort levels are
// synthesized from the community models.dev catalog. The catalog is cached on
// disk so offline starts (Pi refreshes models with allowNetwork=false) still
// get capabilities without touching the network.

import { execSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

export const API_TYPES = [
  "openai-completions",
  "openai-responses",
  "anthropic-messages",
  "google-generative-ai",
];

const MODELS_DEV_URL = "https://models.dev/api.json";
const MODELS_DEV_MAX_AGE_MS = 24 * 60 * 60 * 1000;
const MAX_IDS = 500;

/** Same-key conflicts in models.dev prefer first-party providers. */
const PREFERRED_PROVIDERS = new Set([
  "openai", "anthropic", "google", "deepseek", "mistral", "xai", "meta", "qwen", "moonshotai",
]);

/** Error carrying a stable code (MODELS_*); never includes remote bodies or keys. */
export class CatalogError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}
const fail = (code) => {
  throw new CatalogError(code);
};

/**
 * Resolve a pi-style key reference for our own GET /models call only:
 * literal, "$VAR" / "${VAR}" (whole string) or "!command". Pi resolves the
 * same value again for real requests.
 */
export function resolveApiKey(value) {
  if (typeof value !== "string" || !value) return undefined;
  if (value.startsWith("!")) {
    try {
      return execSync(value.slice(1), { encoding: "utf8", timeout: 5000, windowsHide: true }).trim() || undefined;
    } catch {
      fail("MODELS_KEY_COMMAND_FAILED");
    }
  }
  const env = value.match(/^\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))$/);
  if (env) return process.env[env[1] ?? env[2]] || fail("MODELS_KEY_ENV_MISSING");
  return value;
}

/**
 * GET {root}/models once. Credentials only travel in headers, redirects are
 * refused (a redirect could forward the key to another origin).
 */
export async function listModelIds(root, api, key, { signal, timeoutMs = 8000 } = {}) {
  const url = `${root}/models`;
  const headers = api === "anthropic-messages" ? { "anthropic-version": "2023-06-01" } : {};
  if (key) {
    if (api === "anthropic-messages") headers["x-api-key"] = key;
    else if (api === "google-generative-ai") headers["x-goog-api-key"] = key;
    else headers.authorization = `Bearer ${key}`;
  }
  const timeout = AbortSignal.timeout(timeoutMs);
  const combined = signal && typeof AbortSignal.any === "function" ? AbortSignal.any([signal, timeout]) : timeout;
  let res;
  try {
    res = await fetch(url, { headers, redirect: "error", signal: combined });
  } catch {
    fail("MODELS_UNREACHABLE");
  }
  if (res.status === 401 || res.status === 403) fail("MODELS_UNAUTHORIZED");
  if (!res.ok) fail("MODELS_HTTP_ERROR");
  let payload;
  try {
    payload = JSON.parse(await res.text());
  } catch {
    fail("MODELS_NOT_JSON");
  }
  const raw = Array.isArray(payload?.data) ? payload.data : Array.isArray(payload?.models) ? payload.models : [];
  const ids = raw
    .map((m) => (typeof m === "string" ? m : (m?.id ?? m?.name ?? "")))
    .filter((id) => typeof id === "string")
    .map((id) => (api === "google-generative-ai" ? id.replace(/^models\//, "") : id).trim())
    .filter((id) => id && id.length <= 200);
  return [...new Set(ids)].slice(0, MAX_IDS);
}

/**
 * Discover model ids, retrying with "/v1" appended when the user left it out.
 * Returns the base URL that answered so callers can store the corrected one.
 */
export async function discoverModelIds(baseUrl, api, key, options = {}) {
  const root = String(baseUrl).replace(/\/+$/, "");
  const candidates = [root];
  if (api !== "google-generative-ai" && !/\/v\d+[a-z]*$/i.test(root)) candidates.push(`${root}/v1`);
  let lastError;
  for (const candidate of candidates) {
    try {
      const ids = await listModelIds(candidate, api, key, options);
      if (!ids.length) fail("MODELS_EMPTY");
      return { baseUrl: candidate, ids };
    } catch (error) {
      // Credentials will not improve on another path.
      if (error?.code === "MODELS_UNAUTHORIZED") throw error;
      lastError = error;
    }
  }
  throw lastError;
}

/**
 * Strip relay decorations such as "∞【D竞技场】claude-opus-4-6" or
 * "代码【kktoken】glm-5" down to the underlying id for lookup only.
 */
export function stripDecoration(modelId) {
  let base = String(modelId);
  const close = base.lastIndexOf("】");
  if (close >= 0) base = base.slice(close + 1);
  return base.replace(/^[^\p{L}\p{N}]+/u, "").trim();
}

/** Progressively relaxed lowercase lookup keys (mirrors the 猫饭 provider). */
export function candidateKeys(modelId) {
  const keys = [];
  const add = (value) => {
    const key = value.trim().toLowerCase();
    if (key && !keys.includes(key)) keys.push(key);
  };
  const addVariants = (value) => {
    add(value);
    const slash = value.lastIndexOf("/");
    let base = slash >= 0 ? value.slice(slash + 1) : value;
    if (base !== value) add(base);
    const colon = base.indexOf(":");
    if (colon > 0) {
      base = base.slice(0, colon);
      add(base);
    }
    const dated = base.replace(/-\d{4}-\d{2}-\d{2}$/, "");
    if (dated !== base) add(dated);
  };
  addVariants(String(modelId));
  const undecorated = stripDecoration(modelId);
  if (undecorated && undecorated !== modelId) {
    addVariants(undecorated);
    const plain = undecorated.replace(/[-_](thinking|reasoning|think)$/i, "");
    if (plain !== undecorated) addVariants(plain);
  }
  return keys;
}

/**
 * Map pi thinking levels to effort values; unsupported levels become null
 * (hidden). "off" is only mapped when the catalog names an explicit value;
 * otherwise it stays omitted so pi keeps its default way of disabling thinking.
 */
export function thinkingLevelMapFor(efforts) {
  if (!Array.isArray(efforts) || efforts.length === 0) return undefined;
  const supported = new Set(efforts);
  const pick = (level) => (supported.has(level) ? level : null);
  const off = efforts.find((v) => v === "none" || v === "disabled" || v === "off");
  return {
    ...(off ? { off } : {}),
    minimal: pick("minimal"),
    low: pick("low"),
    medium: pick("medium"),
    high: pick("high"),
    xhigh: pick("xhigh"),
    max: pick("max"),
  };
}

/** Compact one models.dev entry: [provider, modelId, reasoning, image, context, output, efforts]. */
function compactEntry(providerId, modelId, raw) {
  if (!raw || typeof raw !== "object") return undefined;
  const output = raw.modalities?.output;
  if (Array.isArray(output) && output.length > 0 && !output.includes("text") && !output.includes("image")) return undefined;
  const input = raw.modalities?.input;
  const efforts = [];
  if (Array.isArray(raw.reasoning_options)) {
    for (const option of raw.reasoning_options) {
      if (option?.type === "effort" && Array.isArray(option.values)) efforts.push(...option.values.map(String));
    }
  }
  const context = typeof raw.limit?.context === "number" && raw.limit.context > 0 ? raw.limit.context : 0;
  const out = typeof raw.limit?.output === "number" && raw.limit.output > 0 ? raw.limit.output : 0;
  return [providerId, modelId, raw.reasoning === true ? 1 : 0, Array.isArray(input) && input.includes("image") ? 1 : 0, context, out, efforts];
}

function compactCatalog(catalog) {
  const entries = [];
  if (!catalog || typeof catalog !== "object") return entries;
  for (const [providerId, provider] of Object.entries(catalog)) {
    const models = provider && typeof provider === "object" ? provider.models : undefined;
    if (!models || typeof models !== "object") continue;
    for (const [modelId, raw] of Object.entries(models)) {
      const entry = compactEntry(providerId, modelId, raw);
      if (entry) entries.push(entry);
    }
  }
  return entries;
}

function buildIndex(entries) {
  const index = new Map();
  const push = (key, entry) => {
    let bucket = index.get(key);
    if (!bucket) index.set(key, (bucket = []));
    bucket.push(entry);
  };
  for (const entry of entries) {
    const modelId = String(entry[1]);
    push(modelId.toLowerCase(), entry);
    const slash = modelId.lastIndexOf("/");
    if (slash >= 0 && slash < modelId.length - 1) push(modelId.slice(slash + 1).toLowerCase(), entry);
  }
  const rank = (entry) => (PREFERRED_PROVIDERS.has(entry[0]) ? 0 : 1);
  for (const bucket of index.values()) bucket.sort((a, b) => rank(a) - rank(b));
  return index;
}

/**
 * Disk-cached models.dev capability index. load() never throws: an
 * unreachable catalog simply leaves lookups empty (callers keep defaults).
 */
export class ModelsDevCatalog {
  constructor(cacheFile) {
    this.cacheFile = cacheFile;
    this.index = new Map();
    this.fetchedAt = 0;
    this.loading = undefined;
  }

  get ready() {
    return this.fetchedAt > 0;
  }

  async #readDisk() {
    try {
      const data = JSON.parse(await readFile(this.cacheFile, "utf8"));
      if (data?.version !== 1 || !Array.isArray(data.entries) || !Number.isFinite(data.fetchedAt)) return;
      if (data.fetchedAt <= this.fetchedAt) return;
      this.index = buildIndex(data.entries);
      this.fetchedAt = data.fetchedAt;
    } catch {
      /* Missing or corrupt cache: stay empty until the next network load. */
    }
  }

  async #download(signal) {
    try {
      const timeout = AbortSignal.timeout(25_000);
      const combined = signal && typeof AbortSignal.any === "function" ? AbortSignal.any([signal, timeout]) : timeout;
      const res = await fetch(MODELS_DEV_URL, { headers: { accept: "application/json" }, signal: combined });
      if (!res.ok) return;
      const entries = compactCatalog(await res.json());
      if (!entries.length) return;
      const fetchedAt = Date.now();
      this.index = buildIndex(entries);
      this.fetchedAt = fetchedAt;
      await mkdir(dirname(this.cacheFile), { recursive: true });
      const temporary = `${this.cacheFile}.${randomUUID()}.tmp`;
      try {
        await writeFile(temporary, JSON.stringify({ version: 1, fetchedAt, entries }));
        await rename(temporary, this.cacheFile);
      } finally {
        await unlink(temporary).catch(() => {});
      }
    } catch {
      /* Keep whatever was loaded before. */
    }
  }

  /** Load from disk; with allowNetwork, refresh when missing or older than maxAgeMs. */
  async load({ allowNetwork = false, signal, maxAgeMs = MODELS_DEV_MAX_AGE_MS } = {}) {
    await this.#readDisk();
    if (!allowNetwork || (this.ready && Date.now() - this.fetchedAt < maxAgeMs)) return this;
    this.loading ??= this.#download(signal).finally(() => {
      this.loading = undefined;
    });
    await this.loading;
    return this;
  }

  /**
   * Capability hints for one (possibly decorated) model id, or undefined.
   * Fields: reasoning, input, contextWindow?, maxTokens?, thinkingLevelMap?.
   */
  lookup(modelId) {
    let hit;
    for (const key of candidateKeys(modelId)) {
      const bucket = this.index.get(key);
      if (bucket?.length) {
        hit = bucket[0];
        break;
      }
    }
    if (!hit) return undefined;
    const [, , reasoning, image, context, output, efforts] = hit;
    const info = { reasoning: reasoning === 1, input: image === 1 ? ["text", "image"] : ["text"] };
    if (context > 0) info.contextWindow = context;
    if (output > 0) info.maxTokens = context > 0 ? Math.min(output, context) : output;
    if (info.reasoning) {
      const map = thinkingLevelMapFor(efforts);
      if (map) info.thinkingLevelMap = map;
    }
    return info;
  }
}

// ---------------------------------------------------------------------------
// Profile resolution shared by the extension and the GUI adapter.
//
// A profile's `models` array only holds what the user pinned: manually added
// ids (`manual: true`), per-model overrides and `disabled: true` (hidden from
// the model picker). Ids discovered from GET /models live in a separate
// per-profile cache file, so background refreshes in several Pi processes
// never rewrite the user's config file. Until the first successful discovery
// for the current endpoint, every pinned entry is shown (1.x profiles stored
// discovered ids as plain {id} entries).
// ---------------------------------------------------------------------------

/** Cache identity: a changed URL or wire API never reuses another endpoint's list. */
export function endpointKey(profile) {
  return `${profile?.api ?? ""} ${String(profile?.baseUrl ?? "").replace(/\/+$/, "")}`;
}

/** Profile model entries by id (later duplicates ignored). */
function pinnedById(profile) {
  const map = new Map();
  for (const entry of Array.isArray(profile?.models) ? profile.models : []) {
    if (entry && typeof entry.id === "string" && entry.id && !map.has(entry.id)) map.set(entry.id, entry);
  }
  return map;
}

const PLAIN_KEYS = new Set(["id", "disabled", "manual"]);

/** True when an entry carries user settings beyond visibility/manual flags. */
export function hasOverrides(entry) {
  return !!entry && Object.keys(entry).some((key) => !PLAIN_KEYS.has(key));
}

/** Discovered ids when the cache belongs to the profile's current endpoint. */
export function currentDiscovered(profile, discovered) {
  return profile?.syncModels !== false && discovered && discovered.endpoint === endpointKey(profile) && Array.isArray(discovered.ids)
    ? discovered.ids.filter((id) => typeof id === "string" && id)
    : undefined;
}

/**
 * Ordered model entries: discovered ids (upstream order), then pinned ids
 * that discovery did not return (manual ones, or all before the first
 * discovery). Returns `{ ...pinnedFields, id, discovered, manual }`,
 * disabled entries included.
 */
export function profileModelEntries(profile, discovered) {
  const pinned = pinnedById(profile);
  const cache = currentDiscovered(profile, discovered);
  const out = [];
  const seen = new Set();
  for (const id of cache ?? []) {
    if (seen.has(id)) continue;
    seen.add(id);
    const entry = pinned.get(id) ?? {};
    out.push({ ...entry, id, discovered: true, manual: entry.manual === true });
  }
  for (const [id, entry] of pinned) {
    // Upstream dropped a plain discovered id: hide it. Manual ids and ids
    // with user overrides (e.g. legacy 1.x custom entries) stay visible.
    if (seen.has(id) || (cache && entry.manual !== true && !hasOverrides(entry))) continue;
    seen.add(id);
    out.push({ ...entry, id, discovered: false, manual: entry.manual === true });
  }
  return out;
}

function matchRule(profile, entry) {
  const id = entry.id.toLowerCase();
  const matched = Array.isArray(profile?.modelRules)
    ? profile.modelRules.find((rule) =>
        Array.isArray(rule?.match) &&
        rule.match.some((keyword) => typeof keyword === "string" && keyword.trim() && id.includes(keyword.trim().toLowerCase())))
    : undefined;
  // Never carry one API's URL/compat into an explicit override for another API.
  return entry.api && matched && entry.api !== (matched.api ?? profile.api) ? undefined : matched;
}

function validInput(value) {
  if (!Array.isArray(value) || !value.length || value.some((x) => x !== "text" && x !== "image")) return undefined;
  const set = new Set(value);
  return ["text", "image"].filter((t) => set.has(t));
}

/**
 * Resolve one entry to a pi model config plus where each capability came
 * from. `inputHint(id, partial)` may supply extra input evidence (the
 * extension's probe cache / pi's built-in catalog); it runs after explicit
 * settings and before models.dev.
 * Priority: model entry > matching rule > probe/built-in evidence > models.dev
 * > profile default > fallback.
 */
export function resolveModel(profile, entry, catalog, inputHint) {
  const rule = matchRule(profile, entry);
  const info = catalog?.lookup(entry.id);
  const config = {
    id: entry.id,
    name: entry.name ?? entry.id,
    api: entry.api ?? rule?.api ?? profile.api,
    baseUrl: entry.baseUrl ?? rule?.baseUrl ?? profile.baseUrl,
    reasoning: false,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: entry.contextWindow ?? rule?.contextWindow ?? info?.contextWindow ?? 128000,
    maxTokens: entry.maxTokens ?? rule?.maxTokens ?? info?.maxTokens ?? 16384,
  };
  if (config.maxTokens > config.contextWindow) config.maxTokens = config.contextWindow;
  const sources = {};
  if (typeof entry.reasoning === "boolean") [config.reasoning, sources.reasoning] = [entry.reasoning, "model"];
  else if (typeof rule?.reasoning === "boolean") [config.reasoning, sources.reasoning] = [rule.reasoning, "rule"];
  else if (info) [config.reasoning, sources.reasoning] = [info.reasoning, "catalog"];
  else if (typeof profile.reasoning === "boolean") [config.reasoning, sources.reasoning] = [profile.reasoning, "profile"];
  else sources.reasoning = "default";

  if (rule?.compat || entry.compat) config.compat = { ...rule?.compat, ...entry.compat };
  const explicitMap = rule?.thinkingLevelMap || entry.thinkingLevelMap
    ? { ...rule?.thinkingLevelMap, ...entry.thinkingLevelMap }
    : undefined;
  const map = explicitMap ?? info?.thinkingLevelMap;
  if (map && config.reasoning) config.thinkingLevelMap = map;

  const explicitInput = validInput(entry.input) ?? validInput(rule?.input);
  const hinted = explicitInput ? undefined : validInput(inputHint?.(entry.id, config));
  if (explicitInput) [config.input, sources.input] = [explicitInput, entry.input ? "model" : "rule"];
  else if (hinted) [config.input, sources.input] = [hinted, "probe"];
  else if (info) [config.input, sources.input] = [info.input, "catalog"];
  else sources.input = "default";
  return { config, sources };
}

// ---------------------------------------------------------------------------
// Discovered-id cache: <cacheDir>/<encoded profile name>.json
// ---------------------------------------------------------------------------

export function discoveredFile(cacheDir, name) {
  return `${cacheDir}/discovered-${encodeURIComponent(name)}.json`;
}

export async function readDiscovered(cacheDir, name) {
  try {
    const data = JSON.parse(await readFile(discoveredFile(cacheDir, name), "utf8"));
    if (data?.version !== 1 || typeof data.endpoint !== "string" || !Array.isArray(data.ids)) return undefined;
    return data;
  } catch {
    return undefined;
  }
}

export async function writeDiscovered(cacheDir, name, profile, ids) {
  const data = {
    version: 1,
    endpoint: endpointKey(profile),
    syncedAt: Date.now(),
    ids: [...new Set(ids)].slice(0, MAX_IDS),
  };
  const file = discoveredFile(cacheDir, name);
  await mkdir(cacheDir, { recursive: true });
  const temporary = `${file}.${randomUUID()}.tmp`;
  try {
    await writeFile(temporary, JSON.stringify(data) + "\n", { mode: 0o600 });
    await rename(temporary, file);
  } finally {
    await unlink(temporary).catch(() => {});
  }
  return data;
}

export async function removeDiscovered(cacheDir, name) {
  await unlink(discoveredFile(cacheDir, name)).catch(() => {});
}
