# Provider input capabilities

`provider-switch.ts` now resolves image input for all registered models in one place. Model profiles remain the source of truth for endpoints, credentials, routes, reasoning and token limits; this feature does not rewrite their model entries.

## Resolution

1. An explicit per-model `input` wins, including `["text"]`.
2. A successful, unexpired image probe for the configured route wins next.
3. Otherwise use pi's installed built-in model catalog. Exact IDs are preferred; namespace prefixes and `【group】` display decorations may be removed for lookup. Conflicting declarations remain unresolved. No model-family/version wildcard is treated as capability evidence.
4. By default, unresolved profile models remain text-only: selecting a model makes no billable probe request. Only when the user explicitly sets `"imageProbeEnabled": true` at the top level of `provider-profiles.json`, selecting an unresolved model sends one generated PNG with 16 randomly colored squares through that model's actual registered API. Only an exact match to the private pixel sequence enables image input. No user image or conversation is used in detection.

When `imageProbeEnabled` is explicitly enabled, detection runs for `/model`, cycling and `/switch`, with a 20-second deadline, a 1024-output-token ceiling and low reasoning where supported. It then makes one small billable request when an unknown model is first selected. Successful results are cached for 30 days; failed or inconclusive attempts stay unknown, record their reason (`mismatch`, `Vision probe timed out`, `error: …`) in the cache file, and retry after one hour. Nothing scans or probes every configured model at startup. An unavailable detector never prevents ordinary text use.

Cache files live at `~/.pi/agent/.cache/provider-inputs/<sha256>.json`. The hash binds the model ID, resolved API/URL, configured credential reference, headers, compatibility settings and payload transform. File contents contain only timestamps and the result; no credentials or conversation. Writes are atomic. Concurrent detection is deduplicated within a process; other simultaneous pi processes may independently send a probe. Explicit input settings always override cached results.

`provider-switch/inputs.ts` owns lookup, the challenge image and cache. `provider-switch.ts` owns profile resolution, real authenticated requests, and applying the result to the still-selected model. A late response cannot switch back to an old selection. Reload preserves the selected model in the active profile.

The read-only child registrar `provider-profiles-subagent.ts` shares the same resolver and cached results; it does not run the main session's selection/probe hook. A never-used unknown model in such a child remains conservatively text-only until verified in the main session or explicitly configured.

## Image tool results on Responses routes

pi encodes an image tool result (for example the built-in `read` on a PNG) as `function_call_output.output = [input_text, input_image]`. Some gateways (observed: the d竞技场 Claude route, HTTP 400 `function_call_output 需要字符串 call_id 和 output`) require a string. For every active-profile Responses request, `stringifyToolOutputImages` keeps the text as the string output and forwards the images in an immediately following `user` message labelled with the call id. Payloads without image tool outputs are returned unchanged. The claude-responses transform applies the same rewrite.

## Verification — 2026-09-20

- `node tests/provider-inputs.test.mjs <installed-pi-dir>`: 16 checks passed (adds failure-reason recording and the tool-output image rewrite), including real registration metadata for 178 configured model entries, 92 catalog matches, explicit text-only handling, concurrent detection, timeout/cancel/recovery, per-route cache isolation and successful selection upgrade. Profiles remained byte-for-byte unchanged.
- `node tests/provider-switch.test.mjs <installed-pi-dir>`: 10 acceptance groups passed in actual pi RPC processes. Existing routing, thinking controls, switching, reload and restart passed. A loopback Responses fixture received the image, decoded the pixels, and exercised a successful unknown-model detection; repeat selection and a new process reused the cache without another request. Reload retained the selected nondefault model.
- Live `d竞技场/anthropic/claude-fable-5-1` (2026-09-20 16:11 UTC, the running session's model): the first in-session probe was recorded as failed with no reason (older cache format). Rerun with reason recording passed the color challenge in about 4.5–5.7 s in three consecutive runs. The `read` tool-result image was rejected by that route with the string-output 400 until the rewrite above; afterwards the model returned the screenshot text `天。网站会公开成熟时间，`. The successful capability is now in the real cache for that route.
- Live `d竞技场/gpt-6-astra`: generated color challenge passed in approximately 2.8 seconds. The real built-in `read` output was then sent as a tool-result image through pi's actual model runtime. One image reached the outgoing payload and the model returned the screenshot text `网站会公开成熟时间，`. No OCR was used in this acceptance path. Successful capability evidence is cached for that exact route.
- The original digit-based challenge was replaced because tiny bitmap-digit transcription was unreliable; it was never accepted as positive evidence. Low reasoning and a sufficient output limit avoid exhausting a tiny budget before any answer is returned.

A running main session loads this update on `/reload`; installed files and separately tested runtimes do not hot-patch an already loaded extension instance. No claim is made that all 178 upstream routes have been individually tested.
