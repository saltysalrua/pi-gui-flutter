/** Read-only provider registration for Magic Context children.
 * Explicitly allowlisted; outside extensions/ to avoid main-session auto-loading.
 * Uses provider-profiles.json without selecting defaultModel or writing the store.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadStore, resolveProfileModel, findTransformRule, applyClaudeResponsesTransform } from "./extensions/provider-switch.ts";

export default async function (pi: ExtensionAPI) {
  const store = await loadStore();
  for (const [name, profile] of Object.entries(store.profiles)) {
    if (!profile.models.length) continue;
    pi.registerProvider(name, {
      baseUrl: profile.baseUrl,
      api: profile.api,
      apiKey: profile.apiKey,
      headers: profile.headers,
      models: profile.models.map(model => resolveProfileModel(profile, model)),
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
