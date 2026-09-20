// Real Pi RPC + a loopback error response. No external model or user config.
import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import path from "node:path";
import { PiChild, resolvePiPackage } from "../assets/backend/workspace_rpc.mjs";

const root = await mkdtemp(path.join(tmpdir(), "pi-gui-model-error-"));
const previousAgentDir = process.env.PI_CODING_AGENT_DIR;
const detail = "Model request rejected: 本地错误样例; request_id=gui-error-fixture";
const events = [];
let requests = 0, child, timer, settled;
const server = createServer((request, response) => {
  request.resume();
  request.on("end", () => {
    requests++;
    response.writeHead(400, {
      "content-type": "application/json",
      connection: "close",
    });
    response.end(JSON.stringify({
      error: { message: detail, type: "invalid_request_error", code: "fixture_error" },
    }));
  });
});
try {
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const agentDir = path.join(root, "agent");
  await mkdir(agentDir);
  await writeFile(path.join(agentDir, "settings.json"), JSON.stringify({
    retry: { enabled: false },
  }));
  await writeFile(path.join(agentDir, "models.json"), JSON.stringify({
    providers: {
      "gui-error-fixture": {
        baseUrl: `http://127.0.0.1:${server.address().port}/v1`,
        api: "openai-completions",
        apiKey: "local-fixture",
        models: [{ id: "fixture", reasoning: false, input: ["text"] }],
      },
    },
  }));
  process.env.PI_CODING_AGENT_DIR = agentDir;
  child = new PiChild(
    await resolvePiPackage(),
    root,
    (line) => {
      const event = JSON.parse(line);
      events.push(event);
      if (event.type === "agent_settled") settled?.();
    },
    () => {},
    undefined,
    [
      "--no-extensions", "--no-skills", "--no-prompt-templates",
      "--provider", "gui-error-fixture", "--model", "fixture",
      "--session-dir", path.join(root, "sessions"),
    ],
  );
  assert.equal((await child.request("get_state")).model.provider, "gui-error-fixture");
  await child.request("prompt", { message: "Return the local error fixture." });
  await new Promise((resolve, reject) => {
    if (events.some((event) => event.type === "agent_settled")) return resolve();
    settled = resolve;
    timer = setTimeout(() => reject(Error("Error fixture did not settle")), 15000);
  });
  clearTimeout(timer);
  const failed = events.find((event) =>
    event.type === "message_end" && event.message?.stopReason === "error",
  )?.message;
  assert(failed, "Pi must expose the provider failure as an assistant message");
  assert(failed.errorMessage.includes(detail));
  const history = (await child.request("get_messages")).messages;
  assert.equal(history.at(-1).errorMessage, failed.errorMessage);
  const saved = (await child.request("get_state")).sessionFile;
  await child.request("new_session");
  await child.request("switch_session", { sessionPath: saved });
  const restored = (await child.request("get_messages")).messages;
  assert.equal(restored.at(-1).errorMessage, failed.errorMessage);
  assert.equal(requests, 1);
  assert(!events.some((event) => event.type === "extension_error"));
  console.log(`Captured message.errorMessage: ${JSON.stringify(failed.errorMessage)}`);
  console.log("PASS: real Pi RPC preserves model error in live events, get_messages and restored history; one loopback request, no external model calls.");
} finally {
  clearTimeout(timer);
  await child?.stop();
  if (previousAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
  else process.env.PI_CODING_AGENT_DIR = previousAgentDir;
  server.closeAllConnections();
  await new Promise((resolve) => server.close(resolve));
  await rm(root, { recursive: true, force: true, maxRetries: 5 });
}
