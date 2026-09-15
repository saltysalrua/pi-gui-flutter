// Bounded, no-model regression: actual native Pi write + public event middleware.
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { createServer } from "node:http";
import path from "node:path";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
import { registerWriteDiff } from "../assets/backend/gui_tool_diff.mjs";
import { PiChild, resolvePiPackage } from "../assets/backend/workspace_rpc.mjs";

const packageRoot = await resolvePiPackage();
const require = createRequire(path.join(packageRoot, "package.json"));
const { createTwoFilesPatch, applyPatch } = require("diff");
const { createWriteTool } = await import(
  pathToFileURL(path.join(packageRoot, "dist/index.js")).href
);
const root = await mkdtemp(path.join(tmpdir(), "pi-gui-write-diff-"));
const callbacks = new Map();
registerWriteDiff(
  {
    on(name, callback) {
      callbacks.set(name, callback);
    },
  },
  createTwoFilesPatch,
);
const emit = (name, event) => callbacks.get(name)?.(event, { cwd: root });
let id = 0;
const call = (file, content) => ({
  toolName: "write",
  toolCallId: `write-${++id}`,
  input: { path: file, content },
});
async function execute(event, originalDetails) {
  const native = await createWriteTool(root).execute(
    event.toolCallId,
    event.input,
  );
  const result = {
    ...event,
    ...native,
    details: originalDetails,
    isError: false,
  };
  const enrichment = await emit("tool_result", result);
  await emit("tool_execution_end", event);
  return enrichment;
}
async function write(file, content, details) {
  const event = call(file, content);
  await emit("tool_call", event);
  return execute(event, details);
}
try {
  const created = await write("nested/中文.txt", "one\ntwo\n");
  assert.equal(created.details.guiWrite.kind, "created");
  assert.equal(applyPatch("", created.details.patch), "one\ntwo\n");
  const modified = await write("nested/中文.txt", "one\nchanged\n");
  assert.equal(modified.details.guiWrite.kind, "modified");
  assert.equal(
    applyPatch("one\ntwo\n", modified.details.patch),
    "one\nchanged\n",
  );
  const unchanged = await write("nested/中文.txt", "one\nchanged\n");
  assert.equal(unchanged.details.guiWrite.kind, "unchanged");
  assert(!unchanged.details.patch.includes("@@"));

  const empty = await write("empty.txt", "");
  assert.equal(empty.details.guiWrite.kind, "created");
  const crlf = await write("crlf.txt", "\ufeff中文\r\n");
  assert.equal(applyPatch("", crlf.details.patch), "\ufeff中文\r\n");
  assert.equal(
    await write("preserved.txt", "value", { patch: "custom evidence" }),
    undefined,
  );
  const enriched = await write("metadata.txt", "value", { customField: 42 });
  assert.equal(enriched.details.customField, 42);

  const first = call("conflict.txt", "first");
  const second = call("./conflict.txt", "second");
  await emit("tool_call", first);
  await emit("tool_call", second);
  assert.equal(await execute(first), undefined);
  assert.equal(await execute(second), undefined);
  assert.equal(
    await readFile(path.join(root, "conflict.txt"), "utf8"),
    "second",
  );

  const competing = call("conflict.txt", "with edit");
  await emit("tool_call", competing);
  const edit = {
    toolName: "edit",
    toolCallId: "edit",
    input: { path: path.join(root, "conflict.txt") },
  };
  await emit("tool_call", edit);
  assert.equal(await execute(competing), undefined);
  await emit("tool_execution_end", edit);
  for (const shellFirst of [false, true]) {
    const event = call("shell.txt", "safe fallback");
    const shell = {
      toolName: "bash",
      toolCallId: `shell-${shellFirst}`,
      input: {},
    };
    for (const item of shellFirst ? [shell, event] : [event, shell])
      await emit("tool_call", item);
    assert.equal(await execute(event), undefined);
    await emit("tool_execution_end", shell);
  }

  const failed = call("failed.txt", "not written");
  await emit("tool_call", failed);
  assert.equal(
    await emit("tool_result", { ...failed, isError: true }),
    undefined,
  );
  await emit("tool_execution_end", failed);
  const changedArgs = call("args.txt", "before");
  await emit("tool_call", changedArgs);
  changedArgs.input.content = "transformed by another extension";
  assert.equal(await execute(changedArgs), undefined);

  const racing = call("racing.txt", "expected");
  await emit("tool_call", racing);
  await writeFile(path.join(root, "racing.txt"), "another writer");
  assert.equal(
    await emit("tool_result", { ...racing, isError: false }),
    undefined,
  );
  await emit("tool_execution_end", racing);
  const oldSession = call("session.txt", "value");
  await emit("tool_call", oldSession);
  await emit("session_shutdown", {});
  assert.equal(await execute(oldSession), undefined);

  await writeFile(path.join(root, "large.txt"), "x".repeat(256 * 1024 + 1));
  assert.equal(await write("large.txt", "small replacement"), undefined);
  await writeFile(path.join(root, "binary.txt"), Buffer.from([0, 1, 2]));
  assert.equal(await write("binary.txt", "text replacement"), undefined);
  await mkdir(path.join(root, "directory"));
  const directory = call("directory", "value");
  await emit("tool_call", directory);
  assert.equal(
    await emit("tool_result", { ...directory, isError: true }),
    undefined,
  );
  await emit("agent_settled", {});
  assert.equal(
    (await write("after-cleanup.txt", "ok")).details.guiWrite.kind,
    "created",
  );
  console.log(
    "PASS: native write create/overwrite/empty/CRLF, patch round trip, metadata, concurrent writes/edit/shell, failure, changed args, unverified result, session cleanup, size/binary limits; no model calls.",
  );
  if (process.argv.includes("--rpc")) await checkRpc();
} finally {
  await rm(root, { recursive: true, force: true, maxRetries: 5 });
}

// Optional end-to-end run through the real CLI, extension loader and persistence.
// The only API endpoint is our loopback fixture, not a model or external server.
async function checkRpc() {
  let requests = 0;
  const server = createServer((request, response) => {
    request.resume();
    request.on("end", () => {
      const first = ++requests === 1;
      const packet = (delta, finishReason = null) =>
        `data: ${JSON.stringify({
          id: "fixture",
          object: "chat.completion.chunk",
          created: 1,
          model: "fixture",
          choices: [{ index: 0, delta, finish_reason: finishReason }],
        })}\n\n`;
      response.writeHead(200, {
        "content-type": "text/event-stream",
        connection: "close",
      });
      response.write(
        packet(
          first
            ? {
                role: "assistant",
                tool_calls: [
                  {
                    index: 0,
                    id: "rpc-create",
                    type: "function",
                    function: {
                      name: "write",
                      arguments: JSON.stringify({
                        path: "rpc-new.txt",
                        content: "created\n",
                      }),
                    },
                  },
                  {
                    index: 1,
                    id: "rpc-modify",
                    type: "function",
                    function: {
                      name: "write",
                      arguments: JSON.stringify({
                        path: "rpc-existing.txt",
                        content: "after\n",
                      }),
                    },
                  },
                ],
              }
            : { role: "assistant", content: "done" },
        ),
      );
      response.end(
        packet({}, first ? "tool_calls" : "stop") + "data: [DONE]\n\n",
      );
    });
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const previousAgentDir = process.env.PI_CODING_AGENT_DIR;
  const agentDir = path.join(root, "isolated-agent");
  let child, timer, settled;
  const events = [];
  try {
    await mkdir(agentDir);
    await writeFile(path.join(root, "rpc-existing.txt"), "before\n");
    await writeFile(
      path.join(agentDir, "models.json"),
      JSON.stringify({
        providers: {
          "gui-fixture": {
            baseUrl: `http://127.0.0.1:${server.address().port}/v1`,
            api: "openai-completions",
            apiKey: "local-fixture",
            models: [{ id: "fixture", reasoning: false, input: ["text"] }],
          },
        },
      }),
    );
    process.env.PI_CODING_AGENT_DIR = agentDir;
    child = new PiChild(
      packageRoot,
      root,
      (line) => {
        const event = JSON.parse(line);
        events.push(event);
        if (event.type === "agent_settled") settled?.();
      },
      () => {},
      undefined,
      [
        "--no-extensions",
        "--no-skills",
        "--no-prompt-templates",
        "--provider",
        "gui-fixture",
        "--model",
        "fixture",
        "--session-dir",
        path.join(root, "sessions"),
      ],
    );
    const state = await child.request("get_state");
    assert.equal(state.model.provider, "gui-fixture");
    await child.request("prompt", { message: "Run the local write fixtures." });
    await new Promise((resolve, reject) => {
      if (events.some((event) => event.type === "agent_settled"))
        return resolve();
      settled = resolve;
      timer = setTimeout(() => reject(Error("Fixture did not settle")), 30000);
    });
    clearTimeout(timer);
    const results = events.filter(
      (event) => event.type === "tool_execution_end",
    );
    assert.equal(results.length, 2);
    const created = results.find((event) => event.toolCallId === "rpc-create")
      .result.details;
    const modified = results.find((event) => event.toolCallId === "rpc-modify")
      .result.details;
    assert.equal(created.guiWrite.kind, "created");
    assert.equal(modified.guiWrite.kind, "modified");
    assert.equal(applyPatch("", created.patch), "created\n");
    assert.equal(applyPatch("before\n", modified.patch), "after\n");
    const saved = (await child.request("get_state")).sessionFile;
    await child.request("new_session");
    await child.request("switch_session", { sessionPath: saved });
    const history = (await child.request("get_messages")).messages;
    assert.deepEqual(
      history
        .filter((message) => message.role === "toolResult")
        .map((message) => message.details.guiWrite.kind),
      ["created", "modified"],
    );
    assert.equal(requests, 2);
    assert(!events.some((event) => event.type === "extension_error"));
    console.log(
      "PASS: real Pi RPC + bundled extension, parallel create/overwrite, live patch and persisted history; scripted loopback SSE, no external model calls.",
    );
  } finally {
    clearTimeout(timer);
    await child?.stop();
    if (previousAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
    else process.env.PI_CODING_AGENT_DIR = previousAgentDir;
    await new Promise((resolve) => server.close(resolve));
  }
}
