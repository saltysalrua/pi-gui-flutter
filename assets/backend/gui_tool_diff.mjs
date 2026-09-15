import { constants } from "node:fs";
import { open, realpath } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import { createRequire } from "node:module";

const MAX_FILE_BYTES = 256 * 1024;
const MAX_PENDING_BYTES = 4 * 1024 * 1024;
const MAX_PATCH_BYTES = 512 * 1024;
const DIFF_TIMEOUT_MS = 100;
const READ_ONLY = new Set(["read", "grep", "find", "ls"]);
const key = (value) =>
  process.platform === "win32" ? value.toLowerCase() : value;

function targetPath(cwd, input) {
  let value = input?.path ?? input?.file_path;
  if (typeof value !== "string" || !value || value.includes("\0")) return;
  if (value.startsWith("@")) value = value.slice(1);
  if (value === "~") value = homedir();
  else if (/^~[/\\]/.test(value)) value = path.join(homedir(), value.slice(2));
  // A rendering observer must never open network shares, devices or streams.
  if (/^(?:\\\\|\/\/)/.test(value) || /:(?![/\\])/.test(value)) return;
  return path.resolve(cwd, value);
}

async function canonical(file) {
  try {
    return key(await realpath(file));
  } catch {
    try {
      return key(
        path.join(await realpath(path.dirname(file)), path.basename(file)),
      );
    } catch {
      return key(file);
    }
  }
}

async function snapshot(file) {
  let handle;
  try {
    handle = await open(file, constants.O_RDONLY | constants.O_NONBLOCK);
    const stat = await handle.stat();
    if (!stat.isFile() || stat.size > MAX_FILE_BYTES) return;
    const buffer = Buffer.alloc(MAX_FILE_BYTES + 1);
    let length = 0;
    while (length < buffer.length) {
      const { bytesRead } = await handle.read(
        buffer,
        length,
        buffer.length - length,
        null,
      );
      if (!bytesRead) break;
      length += bytesRead;
    }
    if (length > MAX_FILE_BYTES || buffer.subarray(0, length).includes(0))
      return;
    const text = new TextDecoder("utf-8", {
      fatal: true,
      ignoreBOM: true,
    }).decode(buffer.subarray(0, length));
    return { text, exists: true, bytes: length };
  } catch (error) {
    if (error.code === "ENOENT") return { text: "", exists: false, bytes: 0 };
    return;
  } finally {
    await handle?.close().catch(() => {});
  }
}

/** Public Pi event middleware only: never replaces tools, gates, arguments or
 * result content. Missing/ambiguous evidence leaves the original result alone. */
export function registerWriteDiff(pi, createPatch) {
  const pending = new Map();
  let pendingBytes = 0;
  const release = (id) => {
    const item = pending.get(id);
    if (item) pendingBytes -= item.before?.bytes ?? 0;
    pending.delete(id);
  };
  const clear = () => {
    pending.clear();
    pendingBytes = 0;
  };

  pi.on("tool_call", async (event, ctx) => {
    if (READ_ONLY.has(event.toolName)) return;
    const item = {
      valid: true,
      file: undefined,
      canonical: undefined,
      before: undefined,
    };
    pending.set(event.toolCallId, item);
    try {
      if (event.toolName === "write" || event.toolName === "edit") {
        item.file = targetPath(ctx.cwd, event.input);
        if (item.file) item.canonical = await canonical(item.file);
      }
      // Sibling calls are preflighted before execution. A competing file tool,
      // shell or unknown custom tool makes attribution unsafe; do not guess.
      for (const other of pending.values()) {
        if (other === item) continue;
        if (
          !item.canonical ||
          !other.canonical ||
          item.canonical === other.canonical
        ) {
          item.valid = false;
          other.valid = false;
        }
      }
      if (
        !item.valid ||
        !item.file ||
        event.toolName !== "write" ||
        typeof event.input?.content !== "string" ||
        Buffer.byteLength(event.input.content) > MAX_FILE_BYTES
      )
        return;
      item.content = event.input.content;
      const before = await snapshot(item.file);
      if (
        pending.get(event.toolCallId) !== item ||
        !item.valid ||
        !before ||
        pendingBytes + before.bytes > MAX_PENDING_BYTES
      )
        return;
      item.before = before;
      pendingBytes += before.bytes;
    } catch {
      item.valid = false; // Display enrichment must never block an actual tool.
    }
  });

  pi.on("tool_result", async (event, ctx) => {
    const item = pending.get(event.toolCallId);
    try {
      if (
        event.toolName !== "write" ||
        event.isError ||
        !item?.valid ||
        !item.before ||
        event.details?.patch != null ||
        event.details?.diff != null ||
        event.input?.content !== item.content ||
        targetPath(ctx.cwd, event.input) !== item.file ||
        ctx.signal?.aborted
      )
        return;
      const after = await snapshot(item.file);
      if (
        !after?.exists ||
        after.text !== item.content ||
        (await canonical(item.file)) !== item.canonical ||
        !item.valid ||
        pending.get(event.toolCallId) !== item
      )
        return;
      const label = (event.input.path ?? event.input.file_path).replace(
        /[\r\n]/g,
        " ",
      );
      const patch = createPatch(
        item.before.exists ? label : "/dev/null",
        label,
        item.before.text,
        after.text,
        undefined,
        undefined,
        { context: 3, timeout: DIFF_TIMEOUT_MS },
      );
      if (
        typeof patch !== "string" ||
        Buffer.byteLength(patch) > MAX_PATCH_BYTES
      )
        return;
      return {
        details: {
          ...event.details,
          patch,
          guiWrite: {
            kind: item.before.exists
              ? item.before.text === after.text
                ? "unchanged"
                : "modified"
              : "created",
          },
        },
      };
    } catch {
      return; // Preserve success/error and all original tool output on failure.
    }
  });

  pi.on("tool_execution_end", (event) => release(event.toolCallId));
  pi.on("agent_settled", clear);
  pi.on("session_shutdown", clear);
}

export default function guiToolDiff(pi) {
  // Reuse Pi's jsdiff dependency, never edit the installed Pi package.
  try {
    const root = process.env.PI_GUI_PI_PACKAGE_ROOT;
    if (!root) return;
    const require = createRequire(path.join(root, "package.json"));
    const { createTwoFilesPatch } = require("diff");
    registerWriteDiff(pi, createTwoFilesPatch);
  } catch {
    // Older Pi installs without jsdiff still retain the honest after-view.
  }
}
