/**
 * provider-switch 2.x — config-file driven providers for pi.
 *
 * Every profile in <agent dir>/provider-profiles.json (default ~/.pi/agent,
 * honours PI_CODING_AGENT_DIR) becomes an ordinary pi provider at extension
 * load time, exactly like hand-written relay providers (yuukarin, 猫饭 …):
 * its models show up in /model and the GUI model picker, and pi's own session
 * restore / defaultModel logic decides which model a session uses.
 *
 * The extension never selects a model. 1.x called pi.setModel() for an
 * "active" profile on every session_start, which replaced the model of a
 * resumed session; `active` / `defaultModel` are now ignored.
 *
 * Models:
 * - Ids come live from GET {baseUrl}/models (OpenAI, Anthropic and Google
 *   list shapes) through pi's refreshModels hook and are cached per profile in
 *   <agent dir>/.cache/provider-switch/ — the config file is never rewritten
 *   by a background refresh. `syncModels: false` turns discovery off.
 * - Capabilities (reasoning, image input, context window, output limit,
 *   thinking effort levels) are inferred from the models.dev catalog with the
 *   same relaxed id matching as the 猫饭 relay provider, cached on disk for
 *   offline starts. Explicit settings always win:
 *   model entry > matching modelRule > image probe / pi catalog > models.dev
 *   > profile default.
 * - `models` holds only user pins: `{ id, manual: true }` for ids the
 *   endpoint does not list, `{ id, disabled: true }` to hide an id, and any
 *   per-model override (name, reasoning, input, contextWindow, maxTokens,
 *   api, baseUrl, compat, thinkingLevelMap).
 *
 * Edits to the config file (Pi GUI, /provider-add, a text editor) are picked
 * up by running sessions through a file watcher; no restart is needed.
 *
 * Commands: /providers, /provider-refresh [name], /provider-add,
 * /provider-remove [name].
 */

import { watch, type FSWatcher } from "node:fs";
import { mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { dirname, join } from "node:path";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI, ExtensionContext, ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { InputCapabilities, capabilityKey, validInput, visionChallenge } from "./provider-switch/inputs.js";
import {
	API_TYPES,
	ModelsDevCatalog,
	discoverModelIds,
	endpointKey,
	profileModelEntries,
	readDiscovered,
	removeDiscovered,
	resolveApiKey,
	resolveModel,
	writeDiscovered,
} from "./provider-switch/catalog.mjs";

const AGENT_DIR = getAgentDir();
const STORE_PATH = join(AGENT_DIR, "provider-profiles.json");
const CACHE_DIR = join(AGENT_DIR, ".cache", "provider-switch");
/** Background refreshes re-list an endpoint at most this often. */
const SYNC_MAX_AGE_MS = 10 * 60 * 1000;

export const inputCapabilities = new InputCapabilities(join(AGENT_DIR, ".cache", "provider-inputs"));
export const modelsDev = new ModelsDevCatalog(join(CACHE_DIR, "models-dev.json"));

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
	reasoning?: boolean;
	input?: string[];
	contextWindow?: number;
	maxTokens?: number;
	/** Optional outbound payload rewrite applied by the before_provider_request hook. */
	transform?: "claude-responses";
}

interface ProfileModel extends ModelTransport {
	id: string;
	manual?: boolean;
	disabled?: boolean;
	name?: string;
	reasoning?: boolean;
	input?: string[];
	contextWindow?: number;
	maxTokens?: number;
}

export interface Profile {
	baseUrl: string;
	api: ApiType;
	apiKey?: string;
	headers?: Record<string, string>;
	reasoning?: boolean;
	syncModels?: boolean;
	modelRules?: ModelRule[];
	models?: ProfileModel[];
}

export interface Store {
	/** Explicit consent for billable image capability probes (disabled by default). */
	imageProbeEnabled?: boolean;
	profiles: Record<string, Profile>;
}

interface Discovered {
	version: 1;
	endpoint: string;
	syncedAt: number;
	ids: string[];
}

type RawStore = { profiles: Record<string, unknown> } & Record<string, unknown>;

const validProfile = (p: unknown): p is Profile =>
	!!p && typeof p === "object" && !Array.isArray(p) &&
	typeof (p as Profile).baseUrl === "string" && (API_TYPES as readonly string[]).includes((p as Profile).api);

export async function loadStore(): Promise<Store> {
	try {
		const raw = JSON.parse(await readFile(STORE_PATH, "utf8"));
		const profiles: Record<string, Profile> = {};
		for (const [name, profile] of Object.entries(raw?.profiles ?? {})) {
			if (validProfile(profile)) profiles[name] = profile;
		}
		return { imageProbeEnabled: raw?.imageProbeEnabled === true, profiles };
	} catch {
		return { profiles: {} };
	}
}

/** Read-modify-write that keeps unknown top-level and profile fields. */
async function updateStore(mutate: (raw: RawStore) => void): Promise<void> {
	let raw: RawStore;
	try {
		raw = JSON.parse(await readFile(STORE_PATH, "utf8"));
		if (!raw || typeof raw !== "object" || !raw.profiles || typeof raw.profiles !== "object") throw new Error("invalid");
	} catch (error) {
		if ((error as NodeJS.ErrnoException)?.code !== "ENOENT") throw new Error("provider-profiles.json is not valid; fix it first.");
		raw = { profiles: {} };
	}
	mutate(raw);
	await mkdir(dirname(STORE_PATH), { recursive: true });
	const temporary = `${STORE_PATH}.${randomUUID()}.tmp`;
	try {
		await writeFile(temporary, JSON.stringify(raw, null, 2) + "\n", { encoding: "utf8", mode: 0o600 });
		await rename(temporary, STORE_PATH);
	} finally {
		await unlink(temporary).catch(() => {});
	}
}

/** Include route and auth identity without persisting URLs, headers or credentials. */
export function profileCapabilityKey(profile: Profile, model: ProviderModelConfig): string {
	return capabilityKey({ id: model.id, api: model.api, baseUrl: model.baseUrl, apiKey: profile.apiKey,
		headers: profile.headers, compat: model.compat, transform: findTransformRule(profile, model.id)?.transform });
}

/** Resolve one profile model entry to pi's model config (explicit > rule > evidence > models.dev). */
export function resolveProfileModel(profile: Profile, entry: ProfileModel): ProviderModelConfig {
	return resolveModel(profile, entry, modelsDev, (id: string, config: ProviderModelConfig) =>
		inputCapabilities.resolve(id, profileCapabilityKey(profile, config))).config as ProviderModelConfig;
}

/** Enabled models of a profile in display order. */
export function profileModels(profile: Profile, discovered?: Discovered): ProviderModelConfig[] {
	return (profileModelEntries(profile, discovered) as ProfileModel[])
		.filter((entry) => entry.disabled !== true)
		.map((entry) => resolveProfileModel(profile, entry));
}

/**
 * Responses-style gateways emulating Claude reject array function_call_output.output (pi emits
 * input_text/input_image arrays for image tool results). Keep the text in the tool output and hand the
 * images over in an immediately following user message so any Responses endpoint accepts them.
 */
export function stringifyToolOutputImages<T>(input: T): T | unknown[] {
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

/**
 * Rewrite a Responses payload for gateways that proxy Claude behind
 * /v1/responses but only understand chat-wrapped tools and Anthropic-native
 * thinking fields:
 *   tools: {type:"function",name,parameters,...} -> {type:"function",function:{name,parameters,...}}
 *   reasoning:{effort} -> thinking:{type:"adaptive"} + output_config:{effort}
 * Pure function; returns the payload unchanged when there is nothing to do.
 */
export function applyClaudeResponsesTransform<T>(payload: T): T | Record<string, unknown> {
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

export default async function (pi: ExtensionAPI) {
	let store = await loadStore();
	await modelsDev.load({ allowNetwork: false });
	const discovered = new Map<string, Discovered | undefined>();
	/** Signature of what is currently registered per provider. */
	const registered = new Map<string, string>();
	const syncing = new Map<string, Promise<boolean>>();
	const checkingInputs = new Set<string>();
	let disposed = false;

	const cached = await Promise.all(Object.keys(store.profiles).map(async (name) => [name, await readDiscovered(CACHE_DIR, name)] as const));
	for (const [name, value] of cached) discovered.set(name, value);

	/**
	 * Re-list one endpoint (bounded by SYNC_MAX_AGE_MS unless forced) and
	 * update the per-profile id cache. Never throws; false = kept old list.
	 */
	function syncIds(name: string, profile: Profile, options: { force?: boolean; signal?: AbortSignal } = {}): Promise<boolean> {
		if (profile.syncModels === false) return Promise.resolve(false);
		const cached = discovered.get(name);
		if (!options.force && cached?.endpoint === endpointKey(profile) && Date.now() - cached.syncedAt < SYNC_MAX_AGE_MS) {
			return Promise.resolve(false);
		}
		const running = syncing.get(name);
		if (running) return running;
		const job = (async () => {
			try {
				const { ids } = await discoverModelIds(profile.baseUrl, profile.api, resolveApiKey(profile.apiKey), { signal: options.signal });
				discovered.set(name, await writeDiscovered(CACHE_DIR, name, profile, ids));
				return true;
			} catch {
				return false;
			} finally {
				syncing.delete(name);
			}
		})();
		syncing.set(name, job);
		return job;
	}

	function signatureOf(profile: Profile, models: ProviderModelConfig[]): string {
		return JSON.stringify([profile.baseUrl, profile.api, profile.apiKey ?? null, profile.headers ?? null, models]);
	}

	function providerConfig(name: string, profile: Profile, models: ProviderModelConfig[]) {
		return {
			name,
			baseUrl: profile.baseUrl,
			api: profile.api,
			// Keyless endpoints (local servers) still need a configured credential,
			// otherwise pi lists every model as unavailable.
			apiKey: profile.apiKey || "none",
			headers: profile.headers,
			models,
			// Pi calls this on every model refresh: offline at startup, then a
			// background network refresh (RPC/TUI) and on manual refreshes.
			refreshModels: async (context: { allowNetwork?: boolean; force?: boolean; signal?: AbortSignal }) => {
				const current = store.profiles[name] ?? profile;
				if (context?.allowNetwork) {
					await Promise.all([
						modelsDev.load({ allowNetwork: true, signal: context.signal }),
						syncIds(name, current, { force: context.force, signal: context.signal }),
					]);
				}
				const next = profileModels(current, discovered.get(name));
				// Keep the registration's static list in step so a later catalog
				// rebuild does not fall back to an older list.
				if (signatureOf(current, next) !== registered.get(name)) setTimeout(() => register(name), 0);
				return next;
			},
		};
	}

	function register(name: string, force = false): void {
		if (disposed) return;
		const profile = store.profiles[name];
		try {
			const models = profile ? profileModels(profile, discovered.get(name)) : [];
			// A provider without enabled models would only surface errors.
			if (!profile || !models.length) {
				if (registered.delete(name)) pi.unregisterProvider(name);
				return;
			}
			const signature = signatureOf(profile, models);
			if (!force && registered.get(name) === signature) return;
			pi.registerProvider(name, providerConfig(name, profile, models));
			registered.set(name, signature);
		} catch {
			/* A broken profile must not take the other providers down. */
		}
	}

	/**
	 * Pi only refreshes providers that are already registered. A new profile
	 * (or one whose endpoint changed) has no cached ids yet, so list it once
	 * in the background and register when the ids arrive.
	 */
	function ensureListed(name: string): void {
		const profile = store.profiles[name];
		if (!profile || profile.syncModels === false || process.env.PI_OFFLINE) return;
		if (discovered.get(name)?.endpoint === endpointKey(profile)) return;
		void syncIds(name, profile).then((ok) => {
			if (ok) register(name);
		});
	}

	for (const name of Object.keys(store.profiles)) {
		register(name);
		ensureListed(name);
	}

	// Pick up edits from the GUI / other processes without a restart.
	let reloadTimer: ReturnType<typeof setTimeout> | undefined;
	const reload = () => {
		clearTimeout(reloadTimer);
		reloadTimer = setTimeout(async () => {
			if (disposed) return;
			store = await loadStore();
			await modelsDev.load({ allowNetwork: false });
			for (const name of [...registered.keys()]) {
				if (!store.profiles[name]) register(name);
			}
			for (const name of Object.keys(store.profiles)) {
				discovered.set(name, await readDiscovered(CACHE_DIR, name));
				register(name);
				ensureListed(name);
			}
		}, 250);
	};
	const watchers: FSWatcher[] = [];
	const watchDir = async (dir: string, match: (file: string) => boolean) => {
		try {
			await mkdir(dir, { recursive: true });
			const watcher = watch(dir, { persistent: false }, (_event, file) => {
				if (file && match(String(file))) reload();
			});
			watcher.on("error", () => {});
			watchers.push(watcher);
		} catch {
			/* Watching is best effort; a restart still picks up changes. */
		}
	};
	await watchDir(AGENT_DIR, (file) => file === "provider-profiles.json");
	await watchDir(CACHE_DIR, (file) => (file.startsWith("discovered-") || file === "models-dev.json") && !file.endsWith(".tmp"));

	pi.on("session_shutdown", async () => {
		disposed = true;
		clearTimeout(reloadTimer);
		for (const watcher of watchers.splice(0)) watcher.close();
	});

	// Optional, consent-gated image capability probe for unknown models.
	pi.on("model_select", async (event, ctx) => {
		const selected = event.model;
		// A model selection must never silently make a billable request.
		if (store.imageProbeEnabled !== true) return;
		const profile = store.profiles[selected.provider];
		const entry = profile && (profileModelEntries(profile, discovered.get(selected.provider)) as ProfileModel[])
			.find((m) => m.id === selected.id);
		if (!profile || !entry || validInput(entry.input) || selected.input?.includes("image")) return;
		const resolved = resolveProfileModel(profile, entry);
		const key = profileCapabilityKey(profile, resolved);
		if (checkingInputs.has(key)) return;
		checkingInputs.add(key);
		try {
			const ok = await inputCapabilities.ensure(key, async signal => {
				ctx.ui.notify(`Checking image input: ${entry.id}`, "info");
				const challenge = visionChallenge();
				const response = await ctx.modelRegistry.complete(
					{ ...selected, ...resolved, provider: selected.provider, input: ["text", "image"] },
					{ messages: [{ role: "user", timestamp: Date.now(), content: [
						{ type: "text", text: "This image has two rows of eight colored squares. Read left to right, top row then bottom row. Output one letter per square: R for red, G for green, B for blue, Y for yellow. Reply with exactly 16 letters, nothing else." },
						{ type: "image", data: challenge.data, mimeType: challenge.mimeType },
					] }] },
					{ signal, maxTokens: 1024, reasoningEffort: "low", onPayload: payload => findTransformRule(profile, entry.id)?.transform === "claude-responses" ? applyClaudeResponsesTransform(payload) : undefined },
				);
				const text = response.content.filter(b => b.type === "text").map(b => b.text).join("").trim();
				if (response.stopReason === "error" || response.stopReason === "aborted") return { ok: false, reason: `${response.stopReason}: ${response.errorMessage ?? ""}`.slice(0, 300) };
				if (text.toUpperCase().replace(/\s/g, "") !== challenge.expected) return { ok: false, reason: `mismatch (${response.stopReason}, ${text.length} chars)` };
				return true;
			}, ctx.signal);
			if (!ok) return;
			// Re-registering refreshes the session's current model object in place.
			register(selected.provider, true);
			ctx.ui.notify(`Image input enabled: ${entry.id}`, "info");
		} finally { checkingInputs.delete(key); }
	});

	// Gateways needing a payload rewrite (e.g. Claude behind a Responses-only
	// proxy) declare transform on their model rule; apply it per request.
	pi.on("before_provider_request", (event, ctx) => {
		const profile = ctx.model ? store.profiles[ctx.model.provider] : undefined;
		if (!profile) return undefined;
		const modelId = (event.payload as { model?: unknown } | undefined)?.model;
		if (typeof modelId === "string" && findTransformRule(profile, modelId)?.transform === "claude-responses") {
			return applyClaudeResponsesTransform(event.payload);
		}
		// Image tool results on any Responses route of a profile: same rewrite, no per-model config.
		const payload = event.payload as { input?: unknown } | undefined;
		if (payload && typeof payload === "object" && Array.isArray(payload.input)) {
			const input = stringifyToolOutputImages(payload.input);
			if (input !== payload.input) return { ...payload, input };
		}
		return undefined;
	});

	function describe(name: string, profile: Profile): string {
		const entries = profileModelEntries(profile, discovered.get(name)) as ProfileModel[];
		const enabled = entries.filter((m) => m.disabled !== true).length;
		return `${name} — ${profile.api} @ ${profile.baseUrl} (${enabled}/${entries.length} model(s))`;
	}

	pi.registerCommand("providers", {
		description: "List provider profiles registered from provider-profiles.json",
		handler: async (_args, ctx) => {
			const names = Object.keys(store.profiles);
			if (!names.length) {
				ctx.ui.notify("No provider profiles yet. Add one with /provider-add or in Pi GUI settings.", "info");
				return;
			}
			ctx.ui.notify(names.map((name) => describe(name, store.profiles[name])).join("\n"), "info");
		},
	});

	pi.registerCommand("provider-refresh", {
		description: "Re-fetch /models now: /provider-refresh [name] (default: all profiles)",
		handler: async (args, ctx) => {
			const name = args.trim();
			if (name && !Object.hasOwn(store.profiles, name)) {
				ctx.ui.notify(`Profile "${name}" not found.`, "error");
				return;
			}
			const names = name ? [name] : Object.keys(store.profiles);
			await modelsDev.load({ allowNetwork: true, signal: ctx.signal, maxAgeMs: 0 });
			const results = await Promise.all(names.map(async (n) => [n, await syncIds(n, store.profiles[n], { force: true })] as const));
			for (const [n] of results) register(n, true);
			ctx.ui.notify(results.map(([n, ok]) => `${ok ? "✓" : "✗"} ${describe(n, store.profiles[n])}`).join("\n"), "info");
		},
	});

	pi.registerCommand("provider-add", {
		description: "Interactive wizard: add a provider profile",
		handler: async (_args, ctx: ExtensionContext) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("The add wizard needs an interactive UI.", "warning");
				return;
			}
			const name = (await ctx.ui.input("Profile name (used as provider id):", "e.g. deepseek"))?.trim();
			if (!name) return;
			if (!/^[\p{L}\p{N}][\p{L}\p{N}._-]{0,63}$/u.test(name) || ["__proto__", "constructor", "prototype"].includes(name)) {
				ctx.ui.notify("Use 1–64 letters (any language), digits, dots, dashes or underscores.", "error");
				return;
			}
			if (Object.hasOwn(store.profiles, name)) {
				ctx.ui.notify(`Profile "${name}" already exists.`, "error");
				return;
			}
			let baseUrl = (await ctx.ui.input("Base URL:", "https://api.example.com/v1"))?.trim();
			if (!baseUrl) return;
			const api = await ctx.ui.select("API type:", [...API_TYPES]);
			if (!api) return;
			const apiKey = (await ctx.ui.input("API key (literal, $ENV_VAR, or !cmd; empty to skip):", "$MY_API_KEY"))?.trim();
			let manual: string[] = [];
			try {
				const result = await discoverModelIds(baseUrl, api as ApiType, resolveApiKey(apiKey || undefined));
				baseUrl = result.baseUrl;
				ctx.ui.notify(`Found ${result.ids.length} model(s).`, "info");
			} catch (error) {
				ctx.ui.notify(`Model listing failed (${(error as Error).message}); enter ids manually.`, "warning");
				manual = ((await ctx.ui.input("Model ids, comma-separated:", "model-a, model-b")) ?? "")
					.split(",").map((s) => s.trim()).filter(Boolean);
				if (!manual.length) return;
			}
			await updateStore((raw) => {
				raw.profiles[name] = {
					baseUrl,
					api,
					...(apiKey ? { apiKey } : {}),
					...(manual.length ? { syncModels: false, models: manual.map((id) => ({ id, manual: true })) } : {}),
				};
			});
			ctx.ui.notify(`Profile "${name}" saved. Its models appear in /model shortly.`, "info");
		},
	});

	pi.registerCommand("provider-remove", {
		description: "Remove a provider profile: /provider-remove [name]",
		handler: async (args, ctx) => {
			let name = args.trim();
			if (!name) {
				const names = Object.keys(store.profiles);
				if (!ctx.hasUI || !names.length) {
					ctx.ui.notify(names.length ? "Pass a profile name: /provider-remove <name>" : "No profiles to remove.", "info");
					return;
				}
				const choice = await ctx.ui.select("Remove which profile?", names);
				if (!choice) return;
				name = choice;
			}
			if (!Object.hasOwn(store.profiles, name)) {
				ctx.ui.notify(`Profile "${name}" not found.`, "error");
				return;
			}
			if (ctx.hasUI && !(await ctx.ui.confirm("Remove profile", `Delete "${name}"? This cannot be undone.`))) return;
			await updateStore((raw) => {
				delete raw.profiles[name];
			});
			await removeDiscovered(CACHE_DIR, name);
			ctx.ui.notify(`Profile "${name}" removed.`, "info");
		},
	});
}
