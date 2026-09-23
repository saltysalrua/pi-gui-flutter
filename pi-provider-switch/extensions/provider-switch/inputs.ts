import { createHash, randomInt, randomUUID } from "node:crypto";
import { readFileSync, mkdirSync, writeFileSync, renameSync, rmSync } from "node:fs";
import { join } from "node:path";
import { deflateSync } from "node:zlib";
import { getBuiltinModels, getBuiltinProviders } from "@earendil-works/pi-ai/providers/all";

export type InputTypes = ("text" | "image")[];
type CatalogModel = { id: string; input: readonly string[] };
type CachedProbe = { version: 1; checkedAt: number; retryAt: number; input?: InputTypes; reason?: string };
export type ProbeResult = boolean | { ok: false; reason: string };

/** Strip routing namespaces and display prefixes, never guess a model family/version. */
export function modelKeys(id: string): string[] {
 const clean = id.trim().toLowerCase().replace(/^.*】/, "");
 return [...new Set([clean, clean.split("/").at(-1)!])].filter(Boolean);
}
export function validInput(value: unknown): InputTypes | undefined {
 if (!Array.isArray(value) || !value.length || value.some(x => x !== "text" && x !== "image")) return;
 return [...new Set(value)] as InputTypes;
}
export function capabilityKey(identity: unknown): string {
 return createHash("sha256").update(JSON.stringify(identity)).digest("hex");
}

/** Positive discoveries are per endpoint/model/auth/transport, never global guesses. */
export class InputCapabilities {
 private index = new Map<string, Set<string>>();
 private inFlight = new Map<string, Promise<boolean>>();
 private memory = new Map<string, CachedProbe>();
 constructor(readonly cacheDir: string, models: CatalogModel[] = getBuiltinProviders().flatMap(p => getBuiltinModels(p)), private now = Date.now) {
  for (const m of models) {
   const input = validInput(m.input);
   if (!input) continue;
   const signature = [...input].sort().join(",");
   for (const key of modelKeys(m.id)) {
    const values = this.index.get(key) ?? new Set<string>();
    values.add(signature); this.index.set(key, values);
   }
  }
 }
 catalog(id: string): InputTypes | undefined {
  for (const key of modelKeys(id)) {
   const values = this.index.get(key);
   if (!values) continue;
   // Conflicting declarations require a real probe, not an optimistic union.
   if (values.size !== 1) return;
   const result = [...values][0].split(",");
   return (["text", "image"] as const).filter(t => result.includes(t));
  }
 }
 private read(key: string): CachedProbe | undefined {
  if (!/^[a-f0-9]{64}$/.test(key)) return;
  try {
   const r = this.memory.get(key) ?? JSON.parse(readFileSync(join(this.cacheDir, key + ".json"), "utf8"));
   if (r.version !== 1 || !Number.isFinite(r.checkedAt) || !Number.isFinite(r.retryAt) || r.checkedAt > this.now()) return;
   return r;
  } catch { return; }
 }
 cached(key: string): InputTypes | undefined {
  const r = this.read(key);
  if (!r || r.retryAt <= this.now()) return;
  return validInput(r.input);
 }
 resolve(id: string, key: string): InputTypes | undefined {
  return this.cached(key) ?? this.catalog(id);
 }
 private save(key: string, r: CachedProbe): void {
  this.memory.set(key, r);
  let temp: string | undefined;
  try {
   mkdirSync(this.cacheDir, { recursive: true });
   temp = join(this.cacheDir, `${key}.${randomUUID()}.tmp`);
   writeFileSync(temp, JSON.stringify(r) + "\n", { mode: 0o600 });
   renameSync(temp, join(this.cacheDir, key + ".json"));
  } catch {
   // A read-only cache must not disable an otherwise successful current-session probe.
  } finally { if (temp) try { rmSync(temp, { force: true }); } catch {} }
 }
 ensure(key: string, probe: (signal: AbortSignal) => Promise<ProbeResult>, parentSignal?: AbortSignal, timeoutMs = 20000): Promise<boolean> {
  const previous = this.read(key);
  if (previous && previous.retryAt > this.now()) return Promise.resolve(previous.input?.includes("image") ?? false);
  if (this.inFlight.has(key)) return this.inFlight.get(key)!;
  const run = (async () => {
   const controller = new AbortController();
   const abort = () => controller.abort(parentSignal?.reason);
   parentSignal?.addEventListener("abort", abort, { once: true });
   if (parentSignal?.aborted) abort();
   const timer = setTimeout(() => controller.abort(new Error("Vision probe timed out")), timeoutMs);
   try {
    if (controller.signal.aborted) return false;
    const expired = new Promise<ProbeResult>(resolve => controller.signal.addEventListener("abort", () => resolve({ ok: false, reason: controller.signal.reason instanceof Error ? controller.signal.reason.message : "aborted" }), { once: true }));
    const result = await Promise.race([Promise.resolve().then(() => probe(controller.signal)).catch((e: unknown) => ({ ok: false as const, reason: `error: ${e instanceof Error ? e.message : String(e)}`.slice(0, 300) })), expired]);
    if (parentSignal?.aborted) return false;
    const ok = result === true;
    const reason = ok ? undefined : result === false ? "mismatch" : result.reason;
    const checkedAt = this.now();
    // Failure is unresolved, not evidence that the model is text-only. Retry after an hour; keep the reason for diagnosis.
    this.save(key, { version: 1, checkedAt, retryAt: checkedAt + (ok ? 30 * 86400000 : 3600000), ...(ok ? { input: ["text", "image"] } : { reason }) });
    return ok;
   } finally { clearTimeout(timer); parentSignal?.removeEventListener("abort", abort); }
  })();
  this.inFlight.set(key, run);
  void run.finally(() => this.inFlight.delete(key));
  return run;
 }
}

// Standalone PNG: a random color sequence exists only in pixels, never in the prompt.
function crc32(buf: Buffer): number {
 let crc = 0xffffffff;
 for (const b of buf) { crc ^= b; for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0); }
 return (crc ^ 0xffffffff) >>> 0;
}
function chunk(name: string, data: Buffer): Buffer {
 const type = Buffer.from(name), len = Buffer.alloc(4), crc = Buffer.alloc(4);
 len.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(Buffer.concat([type, data])));
 return Buffer.concat([len, type, data, crc]);
}
export function visionChallenge(): { expected: string; data: string; mimeType: "image/png" } {
 const names = "RGBY", colors = [[220,30,30], [30,160,30], [30,60,220], [245,215,0]];
 const indices = Array.from({ length: 16 }, () => randomInt(4));
 const expected = indices.map(i => names[i]).join("");
 const size = 40, gap = 10, width = 8 * size + 9 * gap, height = 2 * size + 3 * gap;
 const stride = width * 3 + 1, pixels = Buffer.alloc(height * stride, 255);
 for (let y = 0; y < height; y++) pixels[y * stride] = 0;
 for (let n = 0; n < 16; n++) {
  const left = gap + (n % 8) * (size + gap), top = gap + Math.floor(n / 8) * (size + gap);
  for (let y = top; y < top + size; y++) for (let x = left; x < left + size; x++)
   for (let c = 0; c < 3; c++) pixels[y * stride + 1 + x * 3 + c] = colors[indices[n]][c];
 }
 const header = Buffer.alloc(13); header.writeUInt32BE(width, 0); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = 2;
 const png = Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk("IHDR",header), chunk("IDAT",deflateSync(pixels)), chunk("IEND",Buffer.alloc(0))]);
 return { expected, data: png.toString("base64"), mimeType: "image/png" };
}
