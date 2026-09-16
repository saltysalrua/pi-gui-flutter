import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdtemp,
  mkdir,
  writeFile,
  readFile,
  realpath,
  rm,
} from "node:fs/promises";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { PassThrough } from "node:stream";
import {
  WorkspaceService,
  WorkspaceAdapter,
  parseWorktrees,
  gitInfo,
  routePiOutput,
  lines,
} from "../assets/backend/workspace_rpc.mjs";
const exec = promisify(execFile);
const git = async (cwd, ...args) =>
  (await exec("git", ["-C", cwd, ...args])).stdout;
async function fixture(t, withCommit = true) {
  // Windows runners may expose TEMP using different casing or an 8.3 alias.
  // Match the realpath normalization used by the production directory service.
  const root = await realpath(
    await mkdtemp(path.join(tmpdir(), "pi-gui-工作区-")),
  );
  t.after(() => rm(root, { recursive: true, force: true, maxRetries: 3 }));
  const repo = path.join(root, "source with spaces");
  await mkdir(repo);
  await git(repo, "init", "-b", "main");
  await git(repo, "config", "core.autocrlf", "false");
  await git(repo, "config", "user.name", "Pi GUI Test");
  await git(repo, "config", "user.email", "pi-gui-test@example.invalid");
  if (withCommit) {
    await writeFile(path.join(repo, "sample.txt"), "original\n");
    await writeFile(path.join(repo, ".gitignore"), ".env\n");
    await git(repo, "add", ".");
    await git(repo, "commit", "-m", "fixture");
  }
  const service = new WorkspaceService(
    { list: async () => [] },
    path.join(root, "prefs.json"),
    repo,
  );
  await service.initialize();
  return { root, repo, service };
}

const summary = (cwd, name = "title") => ({
  path: `${cwd}/session.jsonl`,
  id: cwd,
  cwd,
  name,
  modified: new Date(1),
  messageCount: 2,
  allMessagesText: "not retained in the GUI cache",
});

test("SDK summaries coalesce reads, expire, force refresh and retry failures without caching full text", async () => {
  let now = 0,
    calls = 0,
    fail = false;
  const service = new WorkspaceService(
    {
      list: async (cwd) => {
        calls++;
        if (fail) throw Error("unavailable");
        return [summary(cwd, String(calls))];
      },
    },
    "unused",
    "/a",
    { now: () => now },
  );
  const initial = await Promise.all([
    service.listSessions(),
    service.listSessions(),
    service.listSessions({ force: true }),
  ]);
  assert.equal(calls, 1);
  assert.strictEqual(initial[0], initial[1]);
  assert.equal(initial[0].sessions[0].allMessagesText, undefined);
  now = 4999;
  assert.strictEqual(await service.listSessions(), initial[0]);
  now = 5000;
  assert.equal((await service.listSessions()).sessions[0].title, "2");
  assert.equal(
    (await service.listSessions({ force: true })).sessions[0].title,
    "3",
  );
  service.invalidateSessions();
  assert.equal((await service.listSessions()).sessions[0].title, "4");
  fail = true;
  await assert.rejects(service.listSessions({ force: true }), {
    code: "SESSIONS_UNAVAILABLE",
  });
  // A failed forced refresh must not resurrect the previous cached result.
  await assert.rejects(service.listSessions(), {
    code: "SESSIONS_UNAVAILABLE",
  });
  fail = false;
  assert.equal((await service.listSessions()).sessions[0].title, "7");
});

test("invalidated and old-workspace scans cannot overwrite a newer summary cache", async () => {
  const reads = [];
  const service = new WorkspaceService(
    {
      list: (cwd) =>
        new Promise((resolve) => {
          reads.push({ cwd, resolve });
        }),
    },
    "unused",
    "/a",
  );
  const old = service.listSessions();
  service.invalidateSessions();
  const fresh = service.listSessions();
  reads[1].resolve([summary("/a", "fresh")]);
  const expected = await fresh;
  reads[0].resolve([summary("/a", "old")]);
  await old;
  assert.strictEqual(await service.listSessions(), expected);
  service.current = "/b";
  const other = service.listSessions();
  service.current = "/a";
  service.invalidateSessions();
  const back = service.listSessions();
  reads[3].resolve([summary("/a", "back")]);
  const returned = await back;
  reads[2].resolve([summary("/b")]);
  await other;
  assert.strictEqual(await service.listSessions(), returned);
  assert.deepEqual(
    reads.map((r) => r.cwd),
    ["/a", "/a", "/b", "/a"],
  );
});

test("chunked JSONL preserves large lines, split UTF-8/CRLF and ignores empty records", () => {
  const stream = new PassThrough(),
    output = [];
  lines(stream, (line) => output.push(line));
  const small = JSON.stringify({ text: "中文😀\u2028\u2029" });
  for (const byte of Buffer.from(`\n${small}\r\n`))
    stream.write(Buffer.from([byte]));
  const large = JSON.stringify({ text: "中文😀\u2028\u2029".repeat(20000) });
  const bytes = Buffer.from(large);
  for (let i = 0; i < bytes.length; i += 8191)
    stream.write(bytes.subarray(i, i + 8191));
  stream.write("\r");
  stream.end("\n\r\nlast\n");
  assert.deepEqual(output, [small, large, "last"]);
});

test("Pi output decodes once, preserves unknown/bad lines and keeps internal responses private", () => {
  const pending = new Map(),
    output = [];
  const emit = (line, message) => output.push({ line, message });
  for (const line of ["not JSON", "null", "[]", '{"type":42}']) {
    routePiOutput(line, pending, emit);
    assert.deepEqual(output.at(-1), { line, message: undefined });
  }
  const raw =
    '{ "type": "extension_ui_request", "method": "notify", "text": "中文\\u2028😀" }';
  routePiOutput(raw, pending, emit);
  assert.equal(output.at(-1).line, raw);
  assert.equal(output.at(-1).message.text, "中文\u2028😀");
  let resolved, rejected;
  pending.set("adapter-1", {
    resolve: (data) => {
      resolved = data;
    },
  });
  pending.set("adapter-2", {
    reject: (error) => {
      rejected = error;
    },
  });
  routePiOutput(
    '{"type":"response","id":"adapter-1","success":true,"data":{"value":1}}',
    pending,
    emit,
  );
  routePiOutput(
    '{"type":"response","id":"adapter-2","success":false}',
    pending,
    emit,
  );
  assert.deepEqual(resolved, { value: 1 });
  assert.equal(rejected.code, "PI_REJECTED");
  assert.equal(pending.size, 0);
  assert.equal(output.length, 5);
});

test("adapter invalidates summaries on settlement/writes, not reads; only settled releases busy", async () => {
  let calls = 0;
  const service = new WorkspaceService(
    {
      list: async (cwd) => {
        calls++;
        return [summary(cwd)];
      },
    },
    "unused",
    "/a",
  );
  const output = [];
  const adapter = new WorkspaceAdapter(
    service,
    (_cwd, emit) => ({
      request: async () => ({}),
      send: (request) =>
        routePiOutput(
          JSON.stringify({
            type: "response",
            id: request.id,
            command: request.type,
            success: true,
          }),
          new Map(),
          emit,
        ),
      receive: (line) => routePiOutput(line, new Map(), emit),
    }),
    (line) => output.push(line),
  );
  await adapter.start();
  await service.listSessions();
  await adapter.handle({ id: "read", type: "get_state" });
  await service.listSessions();
  assert.equal(calls, 1);
  for (const type of ["message_end", "compaction_end", "agent_settled"]) {
    adapter.pi.receive(JSON.stringify({ type }));
    await service.listSessions();
  }
  assert.equal(calls, 4);
  await adapter.handle({ id: "rename", type: "set_session_name" });
  await service.listSessions();
  assert.equal(calls, 5);
  await adapter.handle({ id: "force", type: "gui_list_sessions", force: true });
  assert.equal(calls, 6);
  adapter.pi.receive('{"type":"agent_start"}');
  adapter.pi.receive('{"type":"agent_end"}');
  adapter.pi.receive("null");
  assert.equal(adapter.agentBusy, true);
  assert.equal(output.at(-1), "null");
  adapter.pi.receive('{"type":"agent_settled"}');
  assert.equal(adapter.agentBusy, false);
  const old = adapter.pi;
  await adapter.start();
  await service.listSessions();
  const count = calls,
    outputCount = output.length;
  old.receive('{"type":"message_end"}');
  await service.listSessions();
  assert.equal(calls, count);
  assert.equal(output.length, outputCount);
});

test("NUL worktree records preserve quoted paths and lock/prune flags", () => {
  assert.deepEqual(
    parseWorktrees(
      'worktree /tmp/a\n"b\0HEAD abc\0branch refs/heads/main\0\0worktree /tmp/c\0detached\0locked why\0prunable missing\0\0',
    ).map((w) => [w.path, w.branch, w.locked, w.prunable]),
    [
      ['/tmp/a\n"b', "main", false, false],
      ["/tmp/c", null, true, true],
    ],
  );
});

test("workspace creation validates single-child paths and keeps recent directories", async (t) => {
  const { root, service } = await fixture(t);
  await assert.rejects(service.createWorkspace(root, "../escape"), {
    code: "INVALID_NAME",
  });
  const created = await service.createWorkspace(root, "新目录 & spaces");
  assert.ok(existsSync(created.path));
  await assert.rejects(service.createWorkspace(root, "新目录 & spaces"), {
    code: "PATH_EXISTS",
  });
  const restored = new WorkspaceService(
    service.sessions,
    service.storePath,
    root,
  );
  await restored.initialize();
  assert.ok(restored.recent.some((w) => w.path === created.path));
});

test("real Git creates isolated worktree, rejects dirty/locked/active deletion, retains branch", async (t) => {
  const { repo, service } = await fixture(t);
  await writeFile(path.join(repo, "sample.txt"), "local changes\n");
  await writeFile(path.join(repo, "untracked.txt"), "keep me");
  const created = await service.createWorktree("feature/中文", "main");
  assert.equal(
    await readFile(path.join(created.path, "sample.txt"), "utf8"),
    "original\n",
  );
  assert.equal(
    await readFile(path.join(repo, "sample.txt"), "utf8"),
    "local changes\n",
  );
  assert.ok(!existsSync(path.join(created.path, "untracked.txt")));
  await assert.rejects(service.createWorktree("feature/中文", "main"), {
    code: "BRANCH_EXISTS",
  });
  await assert.rejects(service.createWorktree("--orphan", "main"), {
    code: "INVALID_BRANCH",
  });
  await assert.rejects(service.createWorktree("other", "--help"), {
    code: "INVALID_BASE",
  });
  await assert.rejects(service.removeWorktree(repo), {
    code: "WORKTREE_IN_USE",
  });
  await writeFile(path.join(created.path, ".env"), "must survive");
  await assert.rejects(service.removeWorktree(created.path), {
    code: "WORKTREE_DIRTY",
  });
  await rm(path.join(created.path, ".env"));
  await git(repo, "worktree", "lock", created.path);
  await assert.rejects(service.removeWorktree(created.path), {
    code: "WORKTREE_LOCKED",
  });
  await git(repo, "worktree", "unlock", created.path);
  service.current = created.path;
  await assert.rejects(service.removeWorktree(created.path), {
    code: "WORKTREE_IN_USE",
  });
  service.current = repo;
  await service.removeWorktree(created.path);
  assert.ok(!existsSync(created.path));
  assert.match(
    await git(repo, "branch", "--list", "feature/中文"),
    /feature\/中文/,
  );
});

test("unborn repository is readable but cannot create a worktree", async (t) => {
  const { repo, service } = await fixture(t, false);
  assert.equal((await gitInfo(repo)).hasHead, false);
  await assert.rejects(service.createWorktree("feature/a", "HEAD"), {
    code: "NO_COMMIT",
  });
});

test("adapter refuses running/queued operations; failed switch rolls back without replaying prompts", async (t) => {
  const { root, repo, service } = await fixture(t);
  const target = path.join(root, "target");
  await mkdir(target);
  let running = true,
    failTarget = false;
  const created = [],
    output = [];
  const adapter = new WorkspaceAdapter(
    service,
    (cwd, emit, sessionPath) => {
      const child = {
        cwd,
        sessionPath,
        stopped: false,
        request: async () => {
          if (cwd === target && failTarget) throw Error("failed");
          return {
            isStreaming: running,
            pendingMessageCount: 0,
            messageCount: 0,
          };
        },
        stop: async () => {
          child.stopped = true;
        },
        send: (command) =>
          routePiOutput(
            JSON.stringify({ type: "response", id: command.id, success: true }),
            new Map(),
            emit,
          ),
      };
      created.push(child);
      return child;
    },
    (line) => output.push(JSON.parse(line)),
  );
  await adapter.start();
  await adapter.handle({ id: "one", type: "gui_open_workspace", path: target });
  assert.equal(output.at(-1).error, "WORKSPACE_BUSY");
  assert.equal(created.length, 1);
  running = false;
  failTarget = true;
  await adapter.handle({ id: "two", type: "gui_open_workspace", path: target });
  assert.equal(output.at(-1).error, "WORKSPACE_START_FAILED");
  assert.equal(service.current, repo);
  assert.equal(created.at(-1).cwd, repo);
  assert.ok(created.slice(0, -1).every((child) => child.stopped));
  failTarget = false;
  await adapter.handle({
    id: "three",
    type: "gui_open_workspace",
    path: target,
  });
  assert.equal(output.at(-1).success, true);
  assert.ok(
    output.some(
      (item) => item.type === "gui_workspace_changed" && item.path === target,
    ),
  );
});
