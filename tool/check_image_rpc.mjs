// Real GUI multiplex -> native Pi -> loopback provider. No external model calls.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createHash, randomFillSync } from "node:crypto";
import { mkdtemp, mkdir, writeFile, rm } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { deflateSync } from "node:zlib";
import { lines, resolvePiPackage } from "../assets/backend/workspace_rpc.mjs";

// Dependency-free fixtures; null RGB produces incompressible, size-heavy pixels.
function png(rgb, width = 2400, height = 1200) {
  const chunk = (type, bytes) => {
    const data = Buffer.concat([Buffer.from(type), bytes]);
    let crc = 0xffffffff;
    for (const byte of data) {
      crc ^= byte;
      for (let bit = 0; bit < 8; bit++)
        crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
    const length = Buffer.alloc(4),
      checksum = Buffer.alloc(4);
    length.writeUInt32BE(bytes.length);
    checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0);
    return Buffer.concat([length, data, checksum]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = 2;
  const stride = 1 + width * 3;
  const pixels = Buffer.alloc(stride * height);
  if (rgb) {
    const row = Buffer.alloc(stride);
    row.fill(Buffer.from(rgb), 1);
    for (let y = 0; y < height; y++) row.copy(pixels, y * stride);
  } else {
    randomFillSync(pixels);
    for (let y = 0; y < height; y++) pixels[y * stride] = 0;
  }
  return Buffer.concat([
    Buffer.from("89504e470d0a1a0a", "hex"),
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(pixels)),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}
const hash = (data) => createHash("sha256").update(data).digest("hex");
const image = (bytes) => ({
  type: "image",
  data: bytes.toString("base64"),
  mimeType: "image/png",
});
const imageHashes = (body) =>
  body.messages.flatMap((m) =>
    Array.isArray(m.content)
      ? m.content
          .filter((p) => p.type === "image_url")
          .map((p) =>
            hash(Buffer.from(p.image_url.url.split(",")[1], "base64")),
          )
      : [],
  );
const root = await mkdtemp(path.join(tmpdir(), "pi-gui-image-rpc-"));
const agentDir = path.join(root, "agent"),
  cwd = path.join(root, "workspace");
const requests = [],
  events = [],
  pending = new Map();
let child,
  sequence = 0;
// Each prompt gets either a read tool round trip or an ordinary scripted response.
const server = createServer((request, response) => {
  let raw = "";
  request.setEncoding("utf8");
  request.on("data", (chunk) => {
    raw += chunk;
  });
  request.on("end", () => {
    let body;
    try {
      body = JSON.parse(raw);
    } catch {
      response.writeHead(400);
      response.end("Invalid fixture request");
      return;
    }
    requests.push(body);
    const last = body.messages.at(-1);
    const text =
      typeof last?.content === "string"
        ? last.content
        : (last?.content
            ?.filter((p) => p.type === "text")
            .map((p) => p.text)
            .join("\n") ?? "");
    const read = last?.role === "user" && text === "fixture:read";
    const highUsage = text === "fixture:compact";
    const packet = (delta, finish_reason = null, usage) =>
      `data: ${JSON.stringify({
        id: "fixture",
        object: "chat.completion.chunk",
        created: 1,
        model: body.model,
        choices: [{ index: 0, delta, finish_reason }],
        ...(usage ? { usage } : {}),
      })}\n\n`;
    response.writeHead(200, {
      "content-type": "text/event-stream",
      connection: "close",
    });
    response.write(
      packet(
        read
          ? {
              role: "assistant",
              tool_calls: [
                {
                  index: 0,
                  id: `read-${requests.length}`,
                  type: "function",
                  function: {
                    name: "read",
                    arguments: JSON.stringify({ path: "current.png" }),
                  },
                },
              ],
            }
          : { role: "assistant", content: "Fixture response." },
      ),
    );
    response.end(
      packet({}, read ? "tool_calls" : "stop", {
        prompt_tokens: highUsage ? 31000 : 100,
        completion_tokens: 5,
        total_tokens: highUsage ? 31005 : 105,
      }) + "data: [DONE]\n\n",
    );
  });
});
function request(channel, type, fields = {}) {
  return new Promise((resolve, reject) => {
    const id = `image-probe-${++sequence}`;
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`Timeout: ${channel}/${type}`));
    }, 30000);
    pending.set(id, { resolve, reject, timer });
    child.stdin.write(
      `${JSON.stringify({ type: "gui_channel", channel, message: { id, type, ...fields } })}\n`,
    );
  });
}
async function prompt(channel, message, images) {
  const start = events.length;
  await request(channel, "prompt", { message, ...(images ? { images } : {}) });
  const deadline = Date.now() + 30000;
  while (
    !events
      .slice(start)
      .some((p) => p.channel === channel && p.message.type === "agent_settled")
  ) {
    if (Date.now() > deadline) throw new Error(`Did not settle: ${channel}`);
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  const failed = events
    .slice(start)
    .find(
      (p) =>
        p.message.type === "message_end" &&
        p.message.message?.stopReason === "error",
    );
  assert.equal(failed, undefined, "Fixture provider failed");
}
try {
  await mkdir(agentDir);
  await mkdir(cwd);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  await writeFile(
    path.join(agentDir, "settings.json"),
    JSON.stringify({
      defaultProvider: "image-fixture",
      defaultModel: "vision",
      compaction: { enabled: true, reserveTokens: 4096, keepRecentTokens: 512 },
    }),
  );
  await writeFile(
    path.join(agentDir, "models.json"),
    JSON.stringify({
      providers: {
        "image-fixture": {
          baseUrl: `http://127.0.0.1:${server.address().port}/v1`,
          api: "openai-completions",
          apiKey: "local-fixture",
          models: [
            {
              id: "vision",
              input: ["text", "image"],
              reasoning: false,
              contextWindow: 32768,
              maxTokens: 1024,
            },
            {
              id: "text-only",
              input: ["text"],
              reasoning: false,
              contextWindow: 32768,
              maxTokens: 1024,
            },
          ],
        },
      },
    }),
  );
  child = spawn(
    process.execPath,
    [
      fileURLToPath(
        new URL("../assets/backend/workspace_rpc.mjs", import.meta.url),
      ),
      "--gui-multiplex",
    ],
    {
      cwd,
      env: {
        ...process.env,
        PI_CODING_AGENT_DIR: agentDir,
        PI_GUI_WORKSPACE_STORE: path.join(root, "gui.json"),
      },
      stdio: ["pipe", "pipe", "pipe"],
      windowsHide: true,
    },
  );
  child.stderr.resume();
  lines(child.stdout, (line) => {
    let packet;
    try {
      packet = JSON.parse(line);
    } catch {
      return;
    }
    if (!packet.message) return;
    events.push(packet);
    const message = packet.message,
      item = pending.get(message.id);
    if (message.type !== "response" || !item) return;
    pending.delete(message.id);
    clearTimeout(item.timer);
    if (message.success) item.resolve(message.data);
    else item.reject(new Error(message.error));
  });
  const state = await request("primary", "get_state");
  assert.equal(state.autoCompactionEnabled, true);
  assert.deepEqual(state.model.input, ["text", "image"]);
  const packageRoot = await resolvePiPackage();
  const { createReadTool, resizeImage } = await import(
    pathToFileURL(path.join(packageRoot, "dist/index.js")).href
  );
  const red = png([255, 0, 0]),
    blue = png([0, 0, 255]);
  const resizedHashes = [];
  for (const bytes of [red, blue]) {
    const result = await resizeImage(bytes, "image/png");
    assert.equal(result.width, 2000);
    assert.equal(result.height, 1000);
    assert.ok(result.data.length < 4.5 * 1024 * 1024);
    resizedHashes.push(hash(Buffer.from(result.data, "base64")));
    assert.notEqual(resizedHashes.at(-1), hash(bytes));
  }
  await prompt("primary", "fixture:red", [image(red)]);
  assert.deepEqual(imageHashes(requests.at(-1)), [resizedHashes[0]]);
  await prompt("primary", "fixture:blue", [image(blue)]);
  assert.deepEqual(imageHashes(requests.at(-1)), resizedHashes);
  const history = (await request("primary", "get_messages")).messages;
  assert.deepEqual(
    history
      .filter((m) => m.role === "user")
      .flatMap((m) =>
        m.content
          .filter((p) => p.type === "image")
          .map((p) => hash(Buffer.from(p.data, "base64"))),
      ),
    resizedHashes,
  );
  console.log(
    "PASS: uploads are resized exactly like Pi (2000x1000); provider order and history match.",
  );

  await request("control", "gui_open_channel", {
    channelId: "other",
    workspace: cwd,
  });
  await prompt("other", "fixture:other", [image(blue)]);
  assert.deepEqual(imageHashes(requests.at(-1)), [resizedHashes[1]]);
  console.log(
    "PASS: a second session does not inherit the first session's images.",
  );

  // Native read must resize and re-read changed bytes even when the path is reused.
  const expected = [];
  for (const bytes of [red, blue]) {
    await writeFile(path.join(cwd, "current.png"), bytes);
    const result = await createReadTool(cwd).execute("expected", {
      path: "current.png",
    });
    const part = result.content.find((p) => p.type === "image");
    assert.ok(part, "Native read returned no image");
    const processed = Buffer.from(part.data, "base64");
    assert.notEqual(hash(processed), hash(bytes));
    expected.push(hash(processed));
    await prompt("other", "fixture:read");
    assert.deepEqual(imageHashes(requests.at(-1)), [
      resizedHashes[1],
      ...expected,
    ]);
  }
  assert.notEqual(expected[0], expected[1]);
  console.log(
    "PASS: read tool resizes images and sees new pixels at the same path; no previous-image cache.",
  );

  await request("control", "gui_open_channel", {
    channelId: "batch",
    workspace: cwd,
  });
  const small = png([0, 255, 0], 64, 32);
  const heavy = png(null, 1200, 1200); // Within 2000px, but base64 exceeds 4.5 MiB.
  assert.ok(image(heavy).data.length > 4.5 * 1024 * 1024);
  const compressed = await resizeImage(heavy, "image/png");
  assert.ok(compressed.data.length < 4.5 * 1024 * 1024);
  assert.equal(compressed.mimeType, "image/jpeg");
  await prompt("batch", "fixture:batch", [
    image(red),
    image(small),
    image(heavy),
    image(blue),
  ]);
  assert.deepEqual(imageHashes(requests.at(-1)), [
    resizedHashes[0],
    hash(small),
    hash(Buffer.from(compressed.data, "base64")),
    resizedHashes[1],
  ]);
  const urls = requests
    .at(-1)
    .messages.at(-1)
    .content.filter((p) => p.type === "image_url");
  assert.ok(urls[2].image_url.url.startsWith("data:image/jpeg;base64,"));
  console.log(
    "PASS: mixed batch preserves order, small images keep original bytes, size-heavy images use bounded JPEG with correct MIME.",
  );
  const beforeRequests = requests.length;
  const beforeMessages = (await request("batch", "get_messages")).messages
    .length;
  await assert.rejects(
    request("batch", "prompt", {
      message: "must not send",
      images: [image(red), image(Buffer.from("invalid png"))],
    }),
    /IMAGE_PREPROCESS_FAILED/,
  );
  assert.equal(requests.length, beforeRequests);
  assert.equal(
    (await request("batch", "get_messages")).messages.length,
    beforeMessages,
  );
  await prompt("batch", "fixture:retry", [image(small)]);
  console.log(
    "PASS: a corrupt image rejects the whole batch before Pi; history is untouched and retry works.",
  );

  await request("control", "gui_open_channel", {
    channelId: "text",
    workspace: cwd,
  });
  await request("text", "set_model", {
    provider: "image-fixture",
    modelId: "text-only",
  });
  await prompt("text", "fixture:text-only", [image(red)]);
  assert.deepEqual(imageHashes(requests.at(-1)), []);
  console.log(
    "PASS: model input=['text'] removes image blocks before the provider request.",
  );

  await prompt("primary", "fixture:compact");
  const compact = events.find(
    (p) =>
      p.channel === "primary" &&
      p.message.type === "compaction_end" &&
      p.message.reason === "threshold",
  );
  assert.ok(
    compact?.message.result,
    "Automatic RPC compaction did not complete",
  );
  assert.equal(compact.message.aborted, false);
  console.log(
    "PASS: real automatic threshold compaction completes through GUI multiplex RPC.",
  );
  assert.equal(
    events.some((p) => p.message.type === "extension_error"),
    false,
  );
} finally {
  for (const item of pending.values()) clearTimeout(item.timer);
  if (child && child.exitCode === null) {
    await new Promise((resolve) => {
      const timer = setTimeout(() => {
        child.kill();
        resolve();
      }, 15000);
      child.once("exit", () => {
        clearTimeout(timer);
        resolve();
      });
      child.stdin.end();
    });
  }
  await new Promise((resolve) => server.close(resolve));
  await rm(root, { recursive: true, force: true, maxRetries: 5 });
}
