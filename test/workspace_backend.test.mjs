import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, readFile, realpath, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import {
  WorkspaceService,
  WorkspaceAdapter,
  parseWorktrees,
  gitInfo,
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
          emit(
            JSON.stringify({ type: "response", id: command.id, success: true }),
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
