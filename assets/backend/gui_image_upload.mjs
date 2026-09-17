// Upload preparation only. Pi still owns prompts, tools and context management.
const MAX_IMAGES = 8;
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const MAX_TOTAL_BYTES = 20 * 1024 * 1024;
const MAX_BASE64_BYTES = 4.5 * 1024 * 1024;
const MAX_EDGE = 2000;
const PREPARE_TIMEOUT_MS = 20000;
const MIME_TYPES = new Set([
  "image/png",
  "image/jpeg",
  "image/gif",
  "image/webp",
]);

function failed() {
  return Object.assign(new Error("IMAGE_PREPROCESS_FAILED"), {
    code: "IMAGE_PREPROCESS_FAILED",
  });
}

/** Reuse Pi's public, worker-backed resizeImage; no files, caches or LLM calls.
 * Process in order and return a new list only after the WHOLE batch succeeds.
 * The caller must not forward the prompt when this promise rejects. */
export async function prepareImageUpload(images, resizeImage) {
  if (!Array.isArray(images) || images.length > MAX_IMAGES) throw failed();
  if (images.length === 0) return images;
  if (typeof resizeImage !== "function") throw failed();
  let total = 0;
  const inputs = images.map((image) => {
    if (
      image?.type !== "image" ||
      !MIME_TYPES.has(image.mimeType) ||
      typeof image.data !== "string" ||
      image.data.length === 0 ||
      image.data.length > Math.ceil(MAX_IMAGE_BYTES / 3) * 4
    )
      throw failed();
    const bytes = Buffer.from(image.data, "base64");
    total += bytes.length;
    if (
      bytes.length > MAX_IMAGE_BYTES ||
      total > MAX_TOTAL_BYTES ||
      bytes.toString("base64") !== image.data
    )
      throw failed();
    return { bytes, mimeType: image.mimeType };
  });
  let timer,
    expired = false;
  try {
    return await Promise.race([
      (async () => {
        const output = [];
        for (const input of inputs) {
          // No further workers after a timeout. A late result is never sent.
          if (expired) throw failed();
          const result = await resizeImage(input.bytes, input.mimeType, {
            maxWidth: MAX_EDGE,
            maxHeight: MAX_EDGE,
            maxBytes: MAX_BASE64_BYTES,
          });
          if (
            !result ||
            typeof result.data !== "string" ||
            result.data.length === 0 ||
            Buffer.byteLength(result.data) >= MAX_BASE64_BYTES ||
            !MIME_TYPES.has(result.mimeType) ||
            !(result.width > 0 && result.width <= MAX_EDGE) ||
            !(result.height > 0 && result.height <= MAX_EDGE)
          )
            throw failed();
          output.push({
            type: "image",
            data: result.data,
            mimeType: result.mimeType,
          });
        }
        return output;
      })(),
      new Promise((_, reject) => {
        timer = setTimeout(() => {
          expired = true;
          reject(failed());
        }, PREPARE_TIMEOUT_MS);
      }),
    ]);
  } catch {
    throw failed(); // Do not leak image data, decoder internals or file paths.
  } finally {
    clearTimeout(timer);
  }
}
