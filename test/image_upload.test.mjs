import test from "node:test";
import assert from "node:assert/strict";
import { prepareImageUpload } from "../assets/backend/gui_image_upload.mjs";
import { WorkspaceAdapter } from "../assets/backend/workspace_rpc.mjs";

const image = (text) => ({
  type: "image",
  data: Buffer.from(text).toString("base64"),
  mimeType: "image/png",
});
const resized = (text) => ({
  ...image(text),
  mimeType: "image/jpeg",
  width: 2000,
  height: 1000,
});
const failure = { code: "IMAGE_PREPROCESS_FAILED" };
function fixture(resizeImage) {
  const sent = [],
    output = [];
  const service = { current: process.cwd(), invalidateSessions() {} };
  const adapter = new WorkspaceAdapter(
    service,
    (_cwd, emit) => ({
      request: async () => ({ isStreaming: false, pendingMessageCount: 0 }),
      send: (request) => {
        sent.push(request);
        const response = {
          type: "response",
          id: request.id,
          command: request.type,
          success: true,
        };
        emit(JSON.stringify(response), response);
      },
    }),
    (line) => {
      // Only the adapter's own JSON serialization reaches this fixture.
      try {
        output.push(JSON.parse(line));
      } catch {
        assert.fail("Invalid adapter JSON");
      }
    },
    undefined,
    { resizeImage },
  );
  return { adapter, sent, output };
}

test("upload processing preserves originals/order/MIME, rejects a whole failed batch and enforces bounds", async () => {
  const original = [image("red"), image("blue")];
  const snapshot = structuredClone(original),
    seen = [];
  const result = await prepareImageUpload(
    original,
    async (bytes, mime, options) => {
      assert.equal(mime, "image/png");
      assert.deepEqual(options, {
        maxWidth: 2000,
        maxHeight: 2000,
        maxBytes: 4.5 * 1024 * 1024,
      });
      seen.push(bytes.toString());
      return resized(`${bytes}-small`);
    },
  );
  assert.deepEqual(seen, ["red", "blue"]);
  assert.deepEqual(
    result,
    ["red-small", "blue-small"].map((text) => ({
      ...image(text),
      mimeType: "image/jpeg",
    })),
  );
  assert.deepEqual(original, snapshot);
  let calls = 0;
  await assert.rejects(
    prepareImageUpload(original, async () =>
      ++calls === 1 ? resized("ok") : null,
    ),
    failure,
  );
  assert.equal(calls, 2);
  for (const invalid of [
    null,
    [image("x"), { ...image("bad"), data: "!?" }],
    Array(9).fill(image("x")),
  ]) {
    await assert.rejects(
      prepareImageUpload(invalid, () =>
        assert.fail("Invalid batch reached decoder"),
      ),
      failure,
    );
  }
  await assert.rejects(prepareImageUpload(original, undefined), failure);
  for (const result of [
    null,
    { ...resized("bad"), width: 2001 },
    { ...resized("bad"), data: "A".repeat(4.5 * 1024 * 1024) },
  ]) {
    await assert.rejects(
      prepareImageUpload(original, async () => result),
      failure,
    );
  }
});

test("worker timeout rejects before RPC timeout and never starts the next image", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  let finish,
    calls = 0;
  const pending = prepareImageUpload([image("one"), image("two")], () => {
    calls++;
    return new Promise((resolve) => {
      finish = resolve;
    });
  });
  const rejected = assert.rejects(pending, failure);
  t.mock.timers.tick(20000);
  await rejected;
  finish(resized("late"));
  await Promise.resolve();
  assert.equal(calls, 1);
});

test("prompt/steer/follow_up use upload preparation; text/empty uploads stay unchanged and failures never forward", async () => {
  const { adapter, sent, output } = fixture(async () => resized("small"));
  await adapter.start();
  for (const type of ["prompt", "steer", "follow_up"]) {
    const command = {
      id: type,
      type,
      message: "unchanged",
      images: [image("original")],
      streamingBehavior: "followUp",
    };
    const snapshot = structuredClone(command);
    await adapter.handle(command);
    assert.deepEqual(sent.at(-1), {
      ...command,
      images: [{ ...image("small"), mimeType: "image/jpeg" }],
    });
    assert.deepEqual(command, snapshot);
  }
  for (const images of [undefined, []]) {
    const command = { id: "text", type: "prompt", message: "plain", images };
    await adapter.handle(command);
    assert.strictEqual(sent.at(-1), command);
  }
  const count = sent.length;
  adapter.resizeImage = async () => {
    throw new Error("Decoder internal details");
  };
  await adapter.handle({ id: "bad", type: "prompt", images: [image("bad")] });
  assert.equal(sent.length, count);
  assert.equal(output.at(-1).error, failure.code);
  assert.equal(adapter.forwarded.size, 0);
  assert.equal(adapter.preparingImages, false);
  await adapter.ensureIdle();
});

test("preparing images locks session mutations, keeps reads/UI/abort and other sessions live, and abort suppresses late send", async () => {
  let finish;
  const first = fixture(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  const other = fixture(async () => resized("other"));
  await first.adapter.start();
  await other.adapter.start();
  const command = {
    id: "upload",
    type: "prompt",
    message: "draft",
    images: [image("first")],
  };
  const sending = first.adapter.handle(command);
  await assert.rejects(first.adapter.ensureIdle(), { code: "WORKSPACE_BUSY" });
  for (const type of [
    "prompt",
    "steer",
    "follow_up",
    "new_session",
    "switch_session",
  ]) {
    await first.adapter.handle({ id: type, type });
    assert.equal(first.output.at(-1).error, "WORKSPACE_BUSY");
  }
  await first.adapter.handle({ id: "state", type: "get_state" });
  await first.adapter.handle({ id: "ui", type: "extension_ui_response" });
  await other.adapter.handle({ ...command, images: [image("second")] });
  assert.equal(other.sent[0].images[0].data, image("other").data);
  await first.adapter.handle({ id: "stop", type: "abort" });
  finish(resized("late"));
  await sending;
  assert.deepEqual(
    first.sent.map((r) => r.type),
    ["get_state", "extension_ui_response", "abort"],
  );
  assert.equal(first.output.at(-1).id, "upload");
  assert.equal(first.output.at(-1).success, false);
  assert.equal(first.adapter.forwarded.size, 0);
  assert.equal(first.adapter.preparingImages, false);
  await first.adapter.ensureIdle();
});
