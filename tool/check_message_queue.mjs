// Native Pi queue contract over RPC, with a gated loopback SSE provider.
// Isolated configuration/session; no external model calls or GUI restarts.
import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import path from "node:path";
import { PiChild, resolvePiPackage } from "../assets/backend/workspace_rpc.mjs";

const root = await mkdtemp(path.join(tmpdir(), "pi-gui-queue-"));
const previousAgentDir = process.env.PI_CODING_AGENT_DIR;
const requests = [], events = [];
let child, providerFailure;
const server = createServer(async (request, response) => {
  try {
    let body = "";
    for await (const chunk of request) body += chunk;
    requests.push({ body: JSON.parse(body), response });
  } catch (error) {
    providerFailure = error;
    response.writeHead(400);
    response.end();
  }
});
const waitFor = async (predicate, label) => {
  const until = Date.now() + 15000;
  while (!predicate()) {
    if (providerFailure) throw providerFailure;
    if (Date.now() > until) throw new Error(`Timed out: ${label}`);
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
};
function finish(index, tool = false) {
  const response = requests[index].response;
  const packet = (delta, finish_reason = null) => `data: ${JSON.stringify({
    id: `queue-${index}`, object: "chat.completion.chunk", created: 1, model: "fixture",
    choices: [{ index: 0, delta, finish_reason }],
  })}\n\n`;
  response.writeHead(200, { "content-type": "text/event-stream", connection: "close" });
  response.write(packet(tool ? {
    role: "assistant", tool_calls: [{ index: 0, id: "queue-read", type: "function",
      function: { name: "read", arguments: JSON.stringify({ path: "sample.txt" }) } }],
  } : { role: "assistant", content: `reply-${index}` }));
  response.end(packet({}, tool ? "tool_calls" : "stop") + "data: [DONE]\n\n");
}
function userText(index) {
  return requests[index].body.messages.filter((m) => m.role === "user")
    .map((m) => typeof m.content === "string" ? m.content : m.content.map((b) => b.text ?? "").join("\n"))
    .join("\n");
}
try {
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const agentDir = path.join(root, "agent");
  await mkdir(agentDir);
  await writeFile(path.join(root, "sample.txt"), "local queue fixture\n");
  await writeFile(path.join(agentDir, "settings.json"), JSON.stringify({
    retry: { enabled: false }, compaction: { enabled: false },
    steeringMode: "one-at-a-time", followUpMode: "one-at-a-time",
  }));
  await writeFile(path.join(agentDir, "models.json"), JSON.stringify({ providers: {
    "gui-queue-fixture": {
      baseUrl: `http://127.0.0.1:${server.address().port}/v1`, api: "openai-completions", apiKey: "local-fixture",
      models: [{ id: "fixture", reasoning: false, input: ["text"] }],
    },
  } }));
  process.env.PI_CODING_AGENT_DIR = agentDir;
  child = new PiChild(await resolvePiPackage(), root,
    (line) => events.push(JSON.parse(line)), () => {}, undefined,
    ["--no-extensions", "--no-skills", "--no-prompt-templates", "--no-context-files",
      "--provider", "gui-queue-fixture", "--model", "fixture", "--session-dir", path.join(root, "sessions")]);
  const state = await child.request("get_state");
  assert.equal(state.model.provider, "gui-queue-fixture");
  assert.equal(state.steeringMode, "one-at-a-time");
  assert.equal(state.followUpMode, "one-at-a-time");
  await child.request("prompt", { message: "initial", streamingBehavior: "steer" });
  await waitFor(() => requests.length === 1, "initial request");
  for (const [message, streamingBehavior] of [["steer-one", "steer"], ["steer-two", "steer"], ["follow-one", "followUp"], ["follow-two", "followUp"]]) {
    await child.request("prompt", { message, streamingBehavior });
  }
  assert.deepEqual(events.filter((e) => e.type === "queue_update").at(-1), {
    type: "queue_update", steering: ["steer-one", "steer-two"], followUp: ["follow-one", "follow-two"],
  });
  assert.equal((await child.request("get_state")).pendingMessageCount, 4);
  assert.equal((await child.request("get_messages")).messages.filter((m) => m.role === "user").length, 1);
  finish(0, true); // Steering is delivered after this tool turn, not mid-call.
  for (let index = 1; index <= 4; index++) {
    await waitFor(() => requests.length > index, `request ${index + 1}`);
    const content = userText(index);
    const expected = ["steer-one", "steer-two", "follow-one", "follow-two"];
    for (let item = 0; item < expected.length; item++) {
      assert.equal(content.includes(expected[item]), item < index, `${expected[item]} in request ${index}`);
    }
    finish(index);
  }
  await waitFor(() => events.some((e) => e.type === "agent_settled"), "queued run settled");
  assert.equal(events.filter((e) => e.type === "agent_settled").length, 1);
  assert.equal((await child.request("get_state")).pendingMessageCount, 0);
  assert.deepEqual(events.filter((e) => e.type === "queue_update").at(-1).followUp, []);

  // If the run already settled, followUp starts normally rather than stranding a queue.
  await child.request("prompt", { message: "idle-followup", streamingBehavior: "followUp" });
  await waitFor(() => requests.length === 6, "idle follow-up starts immediately");
  await child.request("prompt", { message: "take-steer", streamingBehavior: "steer" });
  await child.request("prompt", { message: "take-follow", streamingBehavior: "followUp" });
  assert.deepEqual(await child.request("clear_queue"), { steering: ["take-steer"], followUp: ["take-follow"] });
  assert.equal((await child.request("get_state")).isStreaming, true); // Dequeue alone does not abort.
  await child.request("abort");
  assert.equal((await child.request("get_state")).pendingMessageCount, 0);
  assert.equal((await child.request("get_state")).isStreaming, false);
  assert.equal(requests.length, 6);
  assert(!events.some((e) => e.type === "extension_error"));
  console.log("PASS: native steering before follow-up, one-at-a-time delivery, queue_update snapshots, idle race, clear_queue then abort; 6 loopback requests, no external model calls.");
} finally {
  await child?.stop();
  if (previousAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
  else process.env.PI_CODING_AGENT_DIR = previousAgentDir;
  server.closeAllConnections();
  await new Promise((resolve) => server.close(resolve));
  await rm(root, { recursive: true, force: true, maxRetries: 5 });
}
