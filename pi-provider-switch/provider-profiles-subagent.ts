/** Read-only provider registration for Magic Context / subagent children.
 * Explicitly allowlisted; outside extensions/ to avoid main-session auto-loading.
 * Registers every profile from provider-profiles.json with its cached model list;
 * never selects a model, lists endpoints or writes any file.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadStore, modelsDev, profileModels, findTransformRule, applyClaudeResponsesTransform } from "./extensions/provider-switch.ts";
import { readDiscovered } from "./extensions/provider-switch/catalog.mjs";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";

export default async function (pi: ExtensionAPI) {
  const store = await loadStore();
  await modelsDev.load({ allowNetwork: false });
  const cacheDir = join(getAgentDir(), ".cache", "provider-switch");
  for (const [name, profile] of Object.entries(store.profiles)) {
    const models = profileModels(profile, await readDiscovered(cacheDir, name));
    if (!models.length) continue;
    pi.registerProvider(name, {
      baseUrl: profile.baseUrl,
      api: profile.api,
      apiKey: profile.apiKey || "none",
      headers: profile.headers,
      models,
    });
  }
  pi.on("before_provider_request", (event, ctx) => {
    const model = ctx.model;
    if (!model || model.api !== "openai-responses") return;
    const profile = store.profiles[model.provider];
    if (findTransformRule(profile, model.id)?.transform === "claude-responses") {
      return applyClaudeResponsesTransform(event.payload);
    }
  });
}
