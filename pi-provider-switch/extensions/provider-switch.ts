/**
 * provider-switch — cc-switch style multi-provider manager for pi.
 *
 * Profiles live in <agent dir>/provider-profiles.json (default ~/.pi/agent, honours PI_CODING_AGENT_DIR).
 * Switching is session-scoped: it calls pi.registerProvider() + pi.setModel()
 * at runtime and never touches models.json.
 *
 * Commands:
 *   /switch [name]      Switch to a profile (no arg: interactive picker)
 *   /providers          List profiles and pick one to activate
 *   /provider-add       Interactive wizard to create a profile
 *   /provider-remove    Delete a profile (interactive picker or pass name)
 *   /provider-thinking [name] [on|off]  Set a profile's default thinking support
 *   /provider-refresh [name]  Re-fetch /models now (default: active profile)
 *
 * Model lists auto-refresh: every /switch and every session_start applies the
 * cached list immediately, then re-fetches /models in the background. New ids
 * are appended; ids gone upstream are dropped only if they carry no custom
 * config and are not defaultModel. Fetch failures keep the cached list.
 *
 * /provider-add fetches the model list from the provider's /models endpoint
 * (OpenAI, Anthropic, and Google shapes supported); manual entry is only a
 * fallback when the fetch fails.
 *
 * Profile fields: baseUrl, api, apiKey (literal, "$ENV_VAR", or "!cmd"),
 * headers?, reasoning? (default false), modelRules? (first keyword match wins),
 * models[] (id required; name/reasoning/contextWindow/maxTokens optional),
 * input is inferred from pi's built-in catalog unless explicitly set on a model.
 * Unknown selected models get one bounded synthetic-image probe; successful
 * results are cached per route for 30 days, inconclusive attempts retry after 1h.
 * No user image or conversation is used for capability detection.
 * Model/rule transport overrides: api?, baseUrl?, compat?, thinkingLevelMap?.
 * Rules may also set transform: "claude-responses" — a before_provider_request
 * hook then rewrites Responses-format tools to chat-wrapped tools and maps
 * reasoning.effort to Anthropic adaptive thinking fields (for gateways whose
 * Responses->Claude conversion only understands those shapes).
 * Priority: explicit model settings > matching rule > profile defaults.
 * A model's explicit API skips a rule for a different API (including its URL/compat).
 * defaultModel? (defaults to first model).
 * Model reasoning overrides the profile default, including explicit false.
 * /provider-thinking changes capability, not the thinking effort level; use
 * pi's thinking controls to choose the effort after enabling support.
 *
 * Note: a profile named like a built-in provider (e.g. "anthropic") overrides
 * that provider for the session — useful for proxy routing.
 */

import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI, ExtensionContext, ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { InputCapabilities, capabilityKey, validInput, visionChallenge } from "./provider-switch/inputs.js";

const STORE_PATH = join(getAgentDir(), "provider-profiles.json");
const STATUS_KEY = "provider-switch";
export const inputCapabilities = new InputCapabilities(join(dirname(STORE_PATH), ".cache", "provider-inputs"));

const API_TYPES = [
	"openai-completions",
	"openai-responses",
	"anthropic-messages",
	"google-generative-ai",
] as const;
type ApiType = (typeof API_TYPES)[number];

interface ModelTransport {
	api?: ApiType;
	baseUrl?: string;
	compat?: ProviderModelConfig["compat"];
	thinkingLevelMap?: ProviderModelConfig["thinkingLevelMap"];
}

interface ModelRule extends ModelTransport {
	/** Any non-empty keyword in the model ID, case-insensitive. First rule wins. */
	match: string[];
	/** Optional outbound payload rewrite applied by the before_provider_request hook. */
	transform?: "claude-responses";
}

interface ProfileModel extends ModelTransport {
	id: string;
	name?: string;
	reasoning?: boolean;
	input?: string[];
	contextWindow?: number;
	maxTokens?: number;
}

interface Profile {
	baseUrl: string;
	api: ApiType;
	reasoning?: boolean;
	apiKey?: string;
	headers?: Record<string, string>;
	modelRules?: ModelRule[];
	models: ProfileModel[];
	defaultModel?: string;
}

interface Store {
	active?: string;
	/** Explicit consent for billable image capability probes (disabled by default). */
	imageProbeEnabled?: boolean;
	profiles: Record<string, Profile>;
}

/**
 * Resolve a pi-style apiKey value for our own outbound calls (model fetch).
 * pi resolves these again at request time; this is only for GET /models.
 * Supports: literal, "$VAR" / "${VAR}" (whole-string), "!command".
 */
export function resolveApiKey(value?: string): string | undefined {
	if (!value) return undefined;
	if (value.startsWith("!")) {
		return execSync(value.slice(1), { encoding: "utf8" }).trim();
	}
	const m = value.match(/^\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))$/);
	if (m) return process.env[m[1] ?? m[2]];
	return value;
}

/** Fetch one candidate /models URL. Throws on non-OK or non-JSON. */
async function fetchModelsOnce(root: string, api: ApiType, apiKey?: string): Promise<string[]> {
	const url =
		api === "google-generative-ai" && apiKey
			? `${root}/models?key=${encodeURIComponent(apiKey)}`
			: `${root}/models`;
	const headers: Record<string, string> = {};
	if (apiKey) {
		if (api === "anthropic-messages") {
			headers["x-api-key"] = apiKey;
			headers["anthropic-version"] = "2023-06-01";
		} else if (api === "google-generative-ai") {
			headers["x-goog-api-key"] = apiKey;
		} else {
			headers["authorization"] = `Bearer ${apiKey}`;
		}
	}
	const res = await fetch(url, { headers, signal: AbortSignal.timeout(8000) });
	if (!res.ok) throw new Error(`GET ${url} -> HTTP ${res.status}`);
	const text = await res.text();
	let payload: { data?: Array<{ id?: string } | string>; models?: Array<{ name?: string }> };
	try {
		payload = JSON.parse(text);
	} catch {
		throw new Error(`GET ${url} returned non-JSON (no /models endpoint here?)`);
	}
	const raw: unknown[] = Array.isArray(payload.data)
		? payload.data
		: Array.isArray(payload.models)
			? payload.models
			: [];
	return raw
		.map((m) => (typeof m === "string" ? m : ((m as { id?: string; name?: string }).id ?? (m as { name?: string }).name ?? "")))
		.map((s) => s.replace(/^models\//, ""))
		.filter(Boolean);
}

/**
 * Fetch model ids from the provider. Tries baseUrl as entered, then retries
 * with /v1 appended (common omission). Returns the baseUrl that worked so the
 * profile stores the corrected value.
 */
export async function fetchModelIds(
	baseUrl: string,
	api: ApiType,
	apiKey?: string,
): Promise<{ baseUrl: string; ids: string[] }> {
	const root = baseUrl.replace(/\/+$/, "");
	const candidates = [root];
	if (api !== "google-generative-ai" && !/\/v\d+[a-z]*$/i.test(root)) {
		candidates.push(`${root}/v1`);
	}
	let lastErr: unknown;
	for (const candidate of candidates) {
		try {
			return { baseUrl: candidate, ids: await fetchModelsOnce(candidate, api, apiKey) };
		} catch (err) {
			lastErr = err;
		}
	}
	throw lastErr;
}

/**
 * Merge upstream ids into a profile's models. Existing entries keep their
 * per-model config; new ids are appended as bare {id}; stale ids are removed
 * only when they are plain {id} entries and not the defaultModel.
 */
export function mergeModelIds(
	profile: Profile,
	ids: string[],
): { models: ProfileModel[]; added: string[]; removed: string[] } {
	const upstream = new Set(ids);
	const known = new Set(profile.models.map((m) => m.id));
	const removed: string[] = [];
	const kept = profile.models.filter((m) => {
		if (upstream.has(m.id)) return true;
		const custom = Object.keys(m).some((k) => k !== "id");
		if (custom || m.id === profile.defaultModel) return true;
		removed.push(m.id);
		return false;
	});
	const added = ids.filter((id) => !known.has(id));
	return { models: [...kept, ...added.map((id) => ({ id }))], added, removed };
}

export async function loadStore(): Promise<Store> {
	if (!existsSync(STORE_PATH)) return { profiles: {} };
	try {
		const raw = JSON.parse(await readFile(STORE_PATH, "utf8")) as Store;
		return { active: raw.active, profiles: raw.profiles ?? {} };
	} catch {
		return { profiles: {} };
	}
}

async function saveStore(store: Store): Promise<void> {
	await mkdir(dirname(STORE_PATH), { recursive: true });
	await writeFile(STORE_PATH, JSON.stringify(store, null, 2) + "\n", "utf8");
}

/** Resolve model metadata once; registration, switching and thinking refresh share it. */
export function resolveProfileModel(profile: Profile, model: ProfileModel): ProviderModelConfig {
	const id = model.id.toLowerCase();
	const matched = profile.modelRules?.find((rule) =>
		Array.isArray(rule.match) && rule.match.some((keyword) =>
			typeof keyword === "string" && keyword.trim().length > 0 && id.includes(keyword.trim().toLowerCase()),
		),
	);
	// Never carry an Anthropic URL/compat/map into an explicit OpenAI override, or vice versa.
	const rule = model.api && model.api !== (matched?.api ?? profile.api) ? undefined : matched;
	const config = {
		id: model.id,
		name: model.name ?? model.id,
		api: model.api ?? rule?.api ?? profile.api,
		baseUrl: model.baseUrl ?? rule?.baseUrl ?? profile.baseUrl,
		...(rule?.compat || model.compat ? { compat: { ...rule?.compat, ...model.compat } } : {}),
		...(rule?.thinkingLevelMap || model.thinkingLevelMap
			? { thinkingLevelMap: { ...rule?.thinkingLevelMap, ...model.thinkingLevelMap } } : {}),
		reasoning: model.reasoning ?? profile.reasoning ?? false,
		input: ["text"] as ("text" | "image")[],
		cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
		contextWindow: model.contextWindow ?? 128000,
		maxTokens: model.maxTokens ?? 16384,
	};
	config.input = validInput(model.input) ?? inputCapabilities.resolve(model.id, profileCapabilityKey(profile, config)) ?? ["text"];
	return config;
}

/** Include route and auth identity without persisting URLs, headers or credentials. */
export function profileCapabilityKey(profile: Profile, model: ProviderModelConfig): string {
	return capabilityKey({ id: model.id, api: model.api, baseUrl: model.baseUrl, apiKey: profile.apiKey,
		headers: profile.headers, compat: model.compat, transform: findTransformRule(profile, model.id)?.transform });
}

/**
 * Rewrite a Responses payload for gateways that proxy Claude behind
 * /v1/responses but only understand chat-wrapped tools and Anthropic-native
 * thinking fields (observed on a Responses-to-Claude gateway after it retired
 * /chat/completions and /messages):
 *   tools: {type:"function",name,parameters,...} -> {type:"function",function:{name,parameters,...}}
 *   reasoning:{effort} -> thinking:{type:"adaptive"} + output_config:{effort}
 * Pure function; returns the payload unchanged when there is nothing to do.
 */
/** Responses-style gateways emulating Claude reject array function_call_output.output (pi emits
 * input_text/input_image arrays for image tool results). Keep the text in the tool output and hand the
 * images over in an immediately following user message so any Responses endpoint accepts them. */
export function stringifyToolOutputImages(input: unknown): unknown {
	if (!Array.isArray(input) || !input.some(i => i && typeof i === "object" && (i as Record<string, unknown>).type === "function_call_output" && Array.isArray((i as Record<string, unknown>).output))) return input;
	const items: unknown[] = [];
	for (const item of input as unknown[]) {
		const it = item as Record<string, unknown> | null;
		if (it && typeof it === "object" && it.type === "function_call_output" && Array.isArray(it.output)) {
			const parts = it.output as Record<string, unknown>[];
			const text = parts.filter(p => p?.type === "input_text").map(p => String(p.text ?? "")).join("\n");
			const images = parts.filter(p => p?.type === "input_image");
			items.push({ ...it, output: text || (images.length ? "(see attached image)" : "(no tool output)") });
			if (images.length) items.push({ role: "user", content: [{ type: "input_text", text: `Attached image output of tool call ${String(it.call_id ?? "")}`.trim() }, ...images] });
		} else items.push(item);
	}
	return items;
}

export function applyClaudeResponsesTransform(payload: unknown): unknown {
	if (!payload || typeof payload !== "object") return payload;
	const next = { ...(payload as Record<string, unknown>) };
	if (Array.isArray(next.tools)) {
		next.tools = next.tools.map((t) => {
			if (!t || typeof t !== "object") return t;
			const tool = t as Record<string, unknown>;
			if (tool.type !== "function" || typeof tool.name !== "string" || tool.function) return t;
			const { name, description, parameters, strict, ...rest } = tool;
			return {
				type: "function",
				function: {
					name,
					...(description !== undefined ? { description } : {}),
					...(parameters !== undefined ? { parameters } : {}),
					...(strict !== undefined ? { strict } : {}),
				},
				...rest,
			};
		});
	}
	next.input = stringifyToolOutputImages(next.input);
	const reasoning = next.reasoning as { effort?: unknown } | undefined;
	const effort = reasoning && typeof reasoning === "object" ? reasoning.effort : undefined;
	if (typeof effort === "string" && effort && effort !== "off" && effort !== "none") {
		next.thinking = { type: "adaptive" };
		next.output_config = { effort };
		delete next.reasoning;
	} else if (effort === "off" || effort === "none") {
		delete next.reasoning;
	}
	return next;
}

/** First matching rule carrying a transform for the given model id, if any. */
export function findTransformRule(profile: Profile | undefined, modelId: string): ModelRule | undefined {
	const id = modelId.toLowerCase();
	return profile?.modelRules?.find(
		(rule) =>
			rule.transform &&
			Array.isArray(rule.match) &&
			rule.match.some(
				(keyword) => typeof keyword === "string" && keyword.trim().length > 0 && id.includes(keyword.trim().toLowerCase()),
			),
	);
}

export default function (pi: ExtensionAPI) {
	// Providers this extension registered in the current process.
	const registered = new Set<string>();
	const checkingInputs = new Set<string>();

	// /model, model cycling and /switch all use the same capability path.
	pi.on("model_select", async (event, ctx) => {
		const selected = event.model;
		const store = await loadStore();
		// A model selection must never silently make a billable request.
		if (store.imageProbeEnabled !== true) return;
		const profile = store.profiles[selected.provider];
		const model = profile?.models.find(m => m.id === selected.id);
		if (!profile || !model || validInput(model.input)) return;
		const resolved = resolveProfileModel(profile, model);
		const key = profileCapabilityKey(profile, resolved);
		if (checkingInputs.has(key)) return;
		checkingInputs.add(key);
		try {
			let input = inputCapabilities.resolve(model.id, key);
			if (!input) {
				const ok = await inputCapabilities.ensure(key, async signal => {
					ctx.ui.notify(`Checking image input: ${model.id}`, "info");
					const challenge = visionChallenge();
					const response = await ctx.modelRegistry.complete(
						{ ...selected, ...resolved, provider: selected.provider, input: ["text", "image"] },
						{ messages: [{ role: "user", timestamp: Date.now(), content: [
							{ type: "text", text: "This image has two rows of eight colored squares. Read left to right, top row then bottom row. Output one letter per square: R for red, G for green, B for blue, Y for yellow. Reply with exactly 16 letters, nothing else." },
							{ type: "image", data: challenge.data, mimeType: challenge.mimeType },
						] }] },
						{ signal, maxTokens: 1024, reasoningEffort: "low", onPayload: payload => findTransformRule(profile, model.id)?.transform === "claude-responses" ? applyClaudeResponsesTransform(payload) : undefined },
					);
					const text = response.content.filter(b => b.type === "text").map(b => b.text).join("").trim();
					if (response.stopReason === "error" || response.stopReason === "aborted") return { ok: false, reason: `${response.stopReason}: ${response.errorMessage ?? ""}`.slice(0, 300) };
					if (text.toUpperCase().replace(/\s/g, "") !== challenge.expected) return { ok: false, reason: `mismatch (${response.stopReason}, ${text.length} chars)` };
					return true;
				}, ctx.signal);
				if (!ok) return;
				input = inputCapabilities.cached(key);
			}
			// A slow probe must never switch back after the user chose another model.
			if (!input || ctx.model?.provider !== selected.provider || ctx.model.id !== selected.id) return;
			if (JSON.stringify(selected.input) === JSON.stringify(input)) return;
			// Re-read config after network I/O; a changed route needs its own evidence.
			const fresh = (await loadStore()).profiles[selected.provider];
			const freshModel = fresh?.models.find(m => m.id === selected.id);
			if (!fresh || !freshModel || profileCapabilityKey(fresh, resolveProfileModel(fresh, freshModel)) !== key) return;
			registerProfile(selected.provider, fresh);
			const updated = ctx.modelRegistry.find(selected.provider, selected.id);
			if (updated && await pi.setModel(updated)) ctx.ui.notify(`Image input enabled: ${model.id}`, "info");
		} finally { checkingInputs.delete(key); }
	});

	function profileLabel(name: string, p: Profile, active?: string): string {
		const mark = name === active ? " ● active" : "";
		const apiLabel = p.modelRules?.length ? `${p.api} (default; model rules enabled)` : p.api;
		return `${name} — ${apiLabel} @ ${p.baseUrl} (${p.models.length} model(s))${mark}`;
	}

	function registerProfile(name: string, profile: Profile): void {
		pi.registerProvider(name, {
			baseUrl: profile.baseUrl,
			api: profile.api,
			apiKey: profile.apiKey,
			headers: profile.headers,
			models: profile.models.map((model) => resolveProfileModel(profile, model)),
		});
		registered.add(name);
	}

	async function applyProfile(
		name: string,
		ctx: ExtensionContext,
		preserveModel = false,
	): Promise<boolean> {
		const store = await loadStore();
		const profile = store.profiles[name];
		if (!profile) {
			ctx.ui.notify(`Profile "${name}" not found. See /providers.`, "error");
			return false;
		}
		if (profile.models.length === 0) {
			ctx.ui.notify(`Profile "${name}" has no models.`, "error");
			return false;
		}

		registerProfile(name, profile);
		const modelId = preserveModel && ctx.model?.provider === name && profile.models.some(m => m.id === ctx.model!.id)
			? ctx.model.id : profile.defaultModel ?? profile.models[0].id;
		const model = ctx.modelRegistry.find(name, modelId);
		if (!model) {
			ctx.ui.notify(`Registered "${name}" but model "${modelId}" was not found.`, "error");
			return false;
		}
		const ok = await pi.setModel(model);
		if (!ok) {
			ctx.ui.notify(
				`Registered "${name}" but no API key resolved (check apiKey / env var). Model not switched.`,
				"error",
			);
			return false;
		}

		store.active = name;
		await saveStore(store);
		ctx.ui.setStatus(STATUS_KEY, `⚡ ${name}/${modelId}`);
		ctx.ui.notify(`Switched to ${name} (${modelId})`, "info");
		// Non-blocking: cached list is live already; pull upstream changes behind it.
		void refreshProfileModels(name, ctx, false);
		return true;
	}

	// One refresh per profile at a time; a /switch storm must not race saveStore.
	const refreshing = new Set<string>();

	/**
	 * Re-fetch /models for a profile, merge into the store, re-register if the
	 * list changed. Never throws; failures keep the cached list.
	 * `verbose` also reports "no changes" / failures (manual /provider-refresh).
	 */
	async function refreshProfileModels(name: string, ctx: ExtensionContext, verbose: boolean): Promise<void> {
		if (refreshing.has(name)) return;
		refreshing.add(name);
		try {
			let profile = (await loadStore()).profiles[name];
			if (!profile) return;
			let ids: string[];
			try {
				ids = (await fetchModelIds(profile.baseUrl, profile.api, resolveApiKey(profile.apiKey))).ids;
			} catch (err) {
				if (verbose) ctx.ui.notify(`${name}: model refresh failed (${(err as Error).message}); keeping cached list.`, "warning");
				return;
			}
			if (ids.length === 0) {
				if (verbose) ctx.ui.notify(`${name}: /models returned nothing; keeping cached list.`, "warning");
				return;
			}
			// Re-read after the network round-trip so concurrent edits are retained.
			const store = await loadStore();
			profile = store.profiles[name];
			if (!profile) return;
			const { models, added, removed } = mergeModelIds(profile, ids);
			if (added.length === 0 && removed.length === 0) {
				if (verbose) ctx.ui.notify(`${name}: ${ids.length} model(s) upstream, list unchanged.`, "info");
				return;
			}
			profile.models = models;
			await saveStore(store);
			if (registered.has(name) || ctx.model?.provider === name) registerProfile(name, profile);
			const parts = [];
			if (added.length) parts.push(`+${added.length}: ${added.slice(0, 5).join(", ")}${added.length > 5 ? ", …" : ""}`);
			if (removed.length) parts.push(`-${removed.length}: ${removed.slice(0, 5).join(", ")}${removed.length > 5 ? ", …" : ""}`);
			ctx.ui.notify(`${name}: model list refreshed (${parts.join("; ")}) → ${models.length} total.`, "info");
		} catch (err) {
			if (verbose) ctx.ui.notify(`${name}: model refresh error: ${(err as Error).message}`, "warning");
		} finally {
			refreshing.delete(name);
		}
	}

	async function pickAndSwitch(ctx: ExtensionContext): Promise<void> {
		if (!ctx.hasUI) {
			ctx.ui.notify("Interactive picker needs the TUI. Use /switch <name>.", "warning");
			return;
		}
		const store = await loadStore();
		const names = Object.keys(store.profiles);
		if (names.length === 0) {
			ctx.ui.notify("No profiles yet. Create one with /provider-add.", "info");
			return;
		}
		const options = names.map((n) => profileLabel(n, store.profiles[n], store.active));
		const choice = await ctx.ui.select("Switch provider profile:", options);
		if (!choice) return;
		const name = names[options.indexOf(choice)];
		await applyProfile(name, ctx);
	}

	// Gateways needing a payload rewrite (e.g. Claude behind a Responses-only
	// proxy) declare transform on their model rule; apply it per request.
	pi.on("before_provider_request", async (event) => {
		const modelId = (event.payload as { model?: unknown } | undefined)?.model;
		if (typeof modelId !== "string" || modelId.length === 0) return undefined;
		const store = await loadStore();
		const profile = store.active ? store.profiles[store.active] : undefined;
		const rule = findTransformRule(profile, modelId);
		if (rule?.transform === "claude-responses") {
			return applyClaudeResponsesTransform(event.payload);
		}
		// Image tool results on any Responses route of an active profile: same rewrite, no per-model config.
		const payload = event.payload as { input?: unknown } | undefined;
		if (profile && payload && typeof payload === "object" && Array.isArray(payload.input)) {
			const input = stringifyToolOutputImages(payload.input);
			if (input !== payload.input) return { ...payload, input };
		}
		return undefined;
	});

	// Re-apply the active profile on startup/reload/new session so the
	// registration survives pi's runtime teardowns without touching models.json.
	pi.on("session_start", async (event, ctx) => {
		const store = await loadStore();
		if (!store.active || !store.profiles[store.active]) {
			ctx.ui.setStatus(STATUS_KEY, undefined);
			return;
		}
		await applyProfile(store.active, ctx, event.reason === "reload");
	});

	pi.registerCommand("switch", {
		description: "Switch provider profile: /switch <name>, or no arg for a picker",
		handler: async (args, ctx) => {
			const name = args.trim();
			if (name) await applyProfile(name, ctx);
			else await pickAndSwitch(ctx);
		},
	});

	pi.registerCommand("providers", {
		description: "List provider profiles and pick one to activate",
		handler: async (_args, ctx) => {
			await pickAndSwitch(ctx);
		},
	});

	pi.registerCommand("provider-refresh", {
		description: "Re-fetch /models for a profile now: /provider-refresh [name] (default: active)",
		handler: async (args, ctx) => {
			const store = await loadStore();
			const name = args.trim() || store.active;
			if (!name || !Object.hasOwn(store.profiles, name)) {
				ctx.ui.notify(name ? `Profile "${name}" not found.` : "No active profile. Use /provider-refresh <name>.", "error");
				return;
			}
			await refreshProfileModels(name, ctx, true);
		},
	});

	pi.registerCommand("provider-thinking", {
		description: "Set default thinking support: /provider-thinking [name] [on|off] (model overrides preserved)",
		handler: async (args, ctx) => {
			let store = await loadStore();
			let name = args.trim();
			let enabled: boolean | undefined;
			// Prefer an exact profile name, including names containing spaces.
			if (name && !Object.hasOwn(store.profiles, name)) {
				const match = name.match(/^(.*?)\s+(on|off)$/i);
				if (match) {
					name = match[1].trim();
					enabled = match[2].toLowerCase() === "on";
				}
			}
			if (!name) {
				if (!ctx.hasUI) {
					ctx.ui.notify("Use /provider-thinking <name> <on|off>.", "warning");
					return;
				}
				const names = Object.keys(store.profiles);
				if (names.length === 0) {
					ctx.ui.notify("No profiles yet. Create one with /provider-add.", "info");
					return;
				}
				const options = names.map((n) => profileLabel(n, store.profiles[n], store.active));
				const choice = await ctx.ui.select("Set thinking support for which provider?", options);
				if (!choice) return;
				name = names[options.indexOf(choice)];
			}
			if (!Object.hasOwn(store.profiles, name)) {
				ctx.ui.notify(`Profile "${name}" not found. Use /provider-thinking <name> <on|off>.`, "error");
				return;
			}
			if (enabled === undefined) {
				if (!ctx.hasUI) {
					ctx.ui.notify("Use /provider-thinking <name> <on|off>.", "warning");
					return;
				}
				const current = store.profiles[name].reasoning ?? false;
				const choice = await ctx.ui.select(
					`Default thinking support for "${name}" (currently ${current ? "on" : "off"}; model overrides preserved):`,
					["On", "Off"],
				);
				if (!choice) return;
				enabled = choice === "On";
			}

			await ctx.waitForIdle();
			// Re-read after dialogs/waiting so unrelated profile edits are retained.
			store = await loadStore();
			if (!Object.hasOwn(store.profiles, name)) {
				ctx.ui.notify(`Profile "${name}" no longer exists.`, "error");
				return;
			}
			const profile = store.profiles[name];
			profile.reasoning = enabled;
			await saveStore(store);

			const currentModel = ctx.model;
			try {
				if (registered.has(name) || currentModel?.provider === name) {
					registerProfile(name, profile);
				}
				if (currentModel?.provider === name) {
					// Refresh capability on the current model without switching to the default.
					const model = ctx.modelRegistry.find(name, currentModel.id);
					if (!model || !(await pi.setModel(model))) {
						ctx.ui.notify(`Thinking support saved for "${name}", but the current model could not be refreshed. Retry /switch ${name}.`, "warning");
						return;
					}
					ctx.ui.setStatus(STATUS_KEY, `⚡ ${name}/${model.id}`);
				}
			} catch {
				ctx.ui.notify(`Thinking support saved for "${name}", but runtime refresh failed. Retry /switch ${name}.`, "warning");
				return;
			}
			ctx.ui.notify(`Default thinking support for "${name}": ${enabled ? "on" : "off"}. Model overrides preserved.`, "info");
		},
	});

	pi.registerCommand("provider-add", {
		description: "Interactive wizard: add a provider profile",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("The add wizard needs the TUI.", "warning");
				return;
			}
			const name = (await ctx.ui.input("Profile name (used as provider id):", "e.g. deepseek"))?.trim();
			if (!name) return;
			let baseUrl = (await ctx.ui.input("Base URL:", "https://api.example.com/v1"))?.trim();
			if (!baseUrl) return;
			const apiChoice = await ctx.ui.select("API type:", [...API_TYPES]);
			if (!apiChoice) return;
			const apiKey = (await ctx.ui.input("API key (literal, $ENV_VAR, or !cmd; empty to skip):", "$MY_API_KEY"))?.trim();

			// Pull the model catalogue from the provider; fall back to manual entry.
			let models: ProfileModel[] = [];
			try {
				const result = await fetchModelIds(baseUrl, apiChoice as ApiType, resolveApiKey(apiKey || undefined));
				if (result.ids.length > 0) {
					models = result.ids.map((id) => ({ id }));
					if (result.baseUrl !== baseUrl) {
						baseUrl = result.baseUrl;
						ctx.ui.notify(`Auto-corrected baseUrl to ${result.baseUrl}`, "info");
					}
					ctx.ui.notify(`Fetched ${result.ids.length} model(s) from provider.`, "info");
				}
			} catch (err) {
				ctx.ui.notify(`Model fetch failed (${(err as Error).message}); enter manually.`, "warning");
			}
			if (models.length === 0) {
				const modelsRaw = (await ctx.ui.input("Model ids, comma-separated:", "model-a, model-b"))?.trim();
				if (!modelsRaw) return;
				models = modelsRaw
					.split(",")
					.map((s) => s.trim())
					.filter(Boolean)
					.map((id) => ({ id }));
				if (models.length === 0) {
					ctx.ui.notify("No valid model ids.", "error");
					return;
				}
			}
			const defaultChoice = await ctx.ui.select(
				"Default model:",
				models.map((m) => m.id),
			);
			if (!defaultChoice) return;

			const store = await loadStore();
			store.profiles[name] = {
				baseUrl,
				api: apiChoice as ApiType,
				...(apiKey ? { apiKey } : {}),
				models,
				defaultModel: defaultChoice,
			};
			await saveStore(store);
			ctx.ui.notify(`Profile "${name}" saved. Activate with /switch ${name}`, "info");
		},
	});

	pi.registerCommand("provider-remove", {
		description: "Remove a provider profile: /provider-remove [name]",
		handler: async (args, ctx) => {
			const store = await loadStore();
			let name = args.trim();
			if (!name) {
				if (!ctx.hasUI) {
					ctx.ui.notify("Pass a profile name: /provider-remove <name>", "warning");
					return;
				}
				const names = Object.keys(store.profiles);
				if (names.length === 0) {
					ctx.ui.notify("No profiles to remove.", "info");
					return;
				}
				const options = names.map((n) => profileLabel(n, store.profiles[n], store.active));
				const choice = await ctx.ui.select("Remove which profile?", options);
				if (!choice) return;
				name = names[options.indexOf(choice)];
			}
			if (!store.profiles[name]) {
				ctx.ui.notify(`Profile "${name}" not found.`, "error");
				return;
			}
			if (ctx.hasUI) {
				const ok = await ctx.ui.confirm("Remove profile", `Delete "${name}"? This cannot be undone.`);
				if (!ok) return;
			}
			delete store.profiles[name];
			if (store.active === name) delete store.active;
			await saveStore(store);
			if (registered.has(name)) {
				pi.unregisterProvider(name);
				registered.delete(name);
			}
			ctx.ui.notify(`Profile "${name}" removed.`, "info");
		},
	});
}
