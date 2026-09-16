import { test } from "node:test";
import assert from "node:assert/strict";
import {
  mkdtemp,
  mkdir,
  writeFile,
  readFile,
  rm,
  symlink,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import {
  WorkspaceBrowser,
  parseStatus,
  parseChangedFiles,
  statusKind,
} from "../assets/backend/workspace_browser.mjs";
import { WorkspaceAdapter } from "../assets/backend/workspace_rpc.mjs";
const exec = promisify(execFile);
async function fixture(t) {
  const root = await mkdtemp(path.join(tmpdir(), "pi-browser-test-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const cwd = path.join(root, "项目 repo");
  await mkdir(cwd);
  const git = async (...args) =>
    (
      await exec(
        "git",
        [
          "-C",
          cwd,
          "-c",
          "user.name=Test",
          "-c",
          "user.email=test@example.invalid",
          "-c",
          "commit.gpgsign=false",
          "-c",
          "core.hooksPath=/dev/null",
          ...args,
        ],
        { windowsHide: true },
      )
    ).stdout.trimEnd();
  await git("init", "--initial-branch=main", "--template=");
  const put = async (name, content = `${name}\n`) => {
    await mkdir(path.dirname(path.join(cwd, name)), { recursive: true });
    await writeFile(path.join(cwd, name), content);
  };
  const browser = new WorkspaceBrowser(() => cwd);
  const request = (extra = {}) => ({ workspace: cwd, ...extra });
  return { root, cwd, git, put, browser, request };
}

test("NUL status parsing preserves rename direction, whitespace and index/worktree distinctions", () => {
  const items = parseStatus(
    "R  new\n文.txt\0old\t文.txt\0MM both.txt\0?? space name\0!! ignored/\0",
  );
  assert.equal(items.get("new\n文.txt").original, "old\t文.txt");
  assert.equal(items.get("both.txt").xy, "MM");
  assert.equal(items.get("ignored").xy, "!!");
  assert.equal(statusKind("UU"), "conflict");
  assert.equal(statusKind("AA"), "conflict");
  assert.equal(statusKind(" M"), "modified");
  assert.equal(statusKind("M "), "staged");
  assert.deepEqual(parseChangedFiles("R100\0old\nfile\0new file\0D\0gone\0"), [
    { path: "new file", original: "old\nfile", status: "R" },
    { path: "gone", original: null, status: "D" },
  ]);
});

test("real tree includes clean/dirty/ignored/deleted files, does not recurse, and keeps split diffs", async (t) => {
  const { cwd, git, put, browser, request } = await fixture(t);
  for (const name of [
    "clean.txt",
    "both.txt",
    "staged.txt",
    "gone/deleted.txt",
    "rename-old.txt",
    "子目录/文件.txt",
  ])
    await put(name);
  await put(".gitignore", "ignored/\n");
  await git("add", ".");
  await git("commit", "-m", "initial");
  await put("both.txt", "staged\n");
  await put("staged.txt", "staged\n");
  await git("add", "both.txt", "staged.txt");
  await put("both.txt", "working\n");
  await rm(path.join(cwd, "gone"), { recursive: true });
  await git("mv", "rename-old.txt", "rename-new.txt");
  await put("new file.txt");
  await put("ignored/private.txt");
  const indexBefore = await readFile(path.join(cwd, ".git/index"));
  const listing = await browser.listFiles(request());
  const entries = new Map(listing.entries.map((entry) => [entry.name, entry]));
  assert.equal(entries.has(".git"), false);
  assert.equal(entries.get("clean.txt").status, "clean");
  assert.equal(entries.get("both.txt").indexStatus, "M");
  assert.equal(entries.get("both.txt").worktreeStatus, "M");
  assert.equal(entries.get("staged.txt").status, "staged");
  assert.equal(entries.get("new file.txt").status, "untracked");
  assert.equal(entries.get("ignored").status, "ignored");
  assert.equal(entries.get("gone").directory, true);
  assert.equal(entries.get("gone").missing, true);
  assert.equal(entries.get("rename-new.txt").status, "renamed");
  const deleted = await browser.listFiles(request({ path: "gone" }));
  assert.equal(deleted.entries[0].status, "deleted");
  const ignored = await browser.listFiles(request({ path: "ignored" }));
  assert.equal(ignored.entries[0].status, "ignored");
  const preview = await browser.preview(request({ path: "both.txt" }));
  assert.equal(preview.content, "working\n");
  assert.match(preview.stagedDiff, /\+staged/);
  assert.match(preview.workingDiff, /-staged\n\+working/);
  const renamePreview = await browser.preview(
    request({ path: "rename-new.txt" }),
  );
  assert.match(renamePreview.stagedDiff, /rename from rename-old.txt/);
  assert.match(renamePreview.stagedDiff, /rename to rename-new.txt/);
  assert.deepEqual(await readFile(path.join(cwd, ".git/index")), indexBefore);
  const nested = new WorkspaceBrowser(() => path.join(cwd, "子目录"));
  const nestedFiles = await nested.listFiles({
    workspace: path.join(cwd, "子目录"),
    path: "",
  });
  assert.equal(nestedFiles.entries[0].path, "文件.txt");
  assert.equal(nestedFiles.entries[0].status, "clean");
});

test("graph includes merge parents, branch/tag refs, root diffs and first-parent details", async (t) => {
  const { git, put, browser, request } = await fixture(t);
  const empty = await browser.graph(request());
  assert.deepEqual(empty.commits, []);
  await put("root.txt");
  await git("add", ".");
  await git("commit", "-m", "root");
  const first = await git("rev-parse", "HEAD");
  await git("checkout", "-b", "feature");
  await put("feature.txt");
  await git("add", ".");
  await git("commit", "-m", "feature commit");
  await git("tag", "-a", "v1", "-m", "tag");
  await git("checkout", "main");
  await put("main.txt");
  await git("add", ".");
  await git("commit", "-m", "main commit");
  await git("merge", "--no-ff", "feature", "-m", "merge");
  const graph = await browser.graph(request({ force: true }));
  assert.equal(graph.commits.length, 4);
  assert.equal(graph.commits[0].parents.length, 2);
  assert.equal(graph.commits[0].hash, graph.head);
  assert.ok(graph.commits[0].refs.includes("refs/heads/main"));
  assert.ok(
    graph.commits.some((commit) => commit.refs.includes("refs/tags/v1")),
  );
  const positions = new Map(
    graph.commits.map((commit, index) => [commit.hash, index]),
  );
  for (const [index, commit] of graph.commits.entries())
    for (const parent of commit.parents)
      assert.ok(positions.get(parent) > index);
  const details = await browser.details(request({ commit: graph.head }));
  assert.deepEqual(
    details.files.map((file) => file.path),
    ["feature.txt"],
  );
  const root = await browser.preview(
    request({ path: "root.txt", commit: first }),
  );
  assert.match(root.commitDiff, /\+root.txt/);
  const merge = await browser.preview(
    request({ path: "feature.txt", commit: graph.head }),
  );
  assert.match(merge.commitDiff, /\+feature.txt/);
  await git("mv", "root.txt", "renamed.txt");
  await git("commit", "-m", "rename");
  const hash = await git("rev-parse", "HEAD");
  const renamed = await browser.details(request({ commit: hash }));
  assert.deepEqual(renamed.files, [
    { path: "renamed.txt", original: "root.txt", status: "R" },
  ]);
  const renamePreview = await browser.preview(
    request({ path: "renamed.txt", commit: hash }),
  );
  assert.match(renamePreview.commitDiff, /rename from root.txt/);
  assert.match(renamePreview.commitDiff, /rename to renamed.txt/);
});

test("non-repository, previews, pathspecs, path traversal and symlinks remain bounded and read-only", async (t) => {
  const { cwd, root, put, browser, request } = await fixture(t);
  await put("big.txt", "a".repeat(256 * 1024 + 1));
  await put("binary.bin", Buffer.from([0, 1, 2]));
  if (process.platform !== "win32") {
    await put(":(glob)*.txt", "literal\n");
    assert.equal(
      (await browser.preview(request({ path: ":(glob)*.txt" }))).content,
      "literal\n",
    );
  }
  assert.equal(
    (await browser.preview(request({ path: "big.txt" }))).kind,
    "tooLarge",
  );
  assert.equal(
    (await browser.preview(request({ path: "binary.bin" }))).kind,
    "binary",
  );
  for (const target of [
    "../outside",
    "/outside",
    ".git/config",
    "child/../../outside",
    "C:/outside",
    "file\0name",
  ]) {
    await assert.rejects(browser.preview(request({ path: target })), {
      code: "INVALID_PATH",
    });
  }
  await assert.rejects(browser.graph({ workspace: root }), {
    code: "WORKSPACE_CHANGED",
  });
  await assert.rejects(browser.details(request({ commit: "--all" })), {
    code: "INVALID_COMMIT",
  });
  const outside = path.join(root, "outside");
  await mkdir(outside);
  await writeFile(path.join(outside, "secret"), "not read");
  try {
    await symlink(
      outside,
      path.join(cwd, "link"),
      process.platform === "win32" ? "junction" : "dir",
    );
    await assert.rejects(browser.listFiles(request({ path: "link" })), {
      code: "SYMLINK_UNAVAILABLE",
    });
    assert.equal(
      (await browser.preview(request({ path: "link/secret" }))).kind,
      "symlink",
    );
  } catch (error) {
    if (error.code !== "EPERM") throw error;
  }
  const plain = new WorkspaceBrowser(() => outside);
  assert.equal((await plain.listFiles({ workspace: outside })).git, false);
  await assert.rejects(plain.graph({ workspace: outside }), {
    code: "NOT_GIT",
  });
});

test("nested repositories use their own index; read-only adapter commands remain available while the agent runs", async (t) => {
  const { cwd, git, put, browser, request } = await fixture(t);
  await put("root.txt");
  await git("add", ".");
  await git("commit", "-m", "root");
  await put("nested/clean.txt", "baseline\n");
  const nested = path.join(cwd, "nested");
  await git("-C", nested, "init", "--initial-branch=main", "--template=");
  await git("-C", nested, "add", ".");
  await git("-C", nested, "commit", "-m", "nested");
  assert.equal(
    (await browser.listFiles(request({ path: "nested" }))).entries[0].status,
    "clean",
  );
  await put("nested/clean.txt", "modified\n");
  const listing = await browser.listFiles(
    request({ path: "nested", force: true }),
  );
  assert.equal(listing.entries[0].path, "nested/clean.txt");
  assert.equal(listing.entries[0].status, "modified");
  assert.match(
    (await browser.preview(request({ path: "nested/clean.txt" }))).workingDiff,
    /-baseline\n\+modified/,
  );
  const emitted = [];
  const adapter = new WorkspaceAdapter(
    { current: cwd, invalidateSessions() {} },
    () => ({
      request: async () => ({}),
      send: () => assert.fail("browser request forwarded to agent"),
      exited: false,
      expectedExit: false,
    }),
    (line) => emitted.push(JSON.parse(line)),
  );
  await adapter.start();
  adapter.agentBusy = true;
  for (const type of ["gui_list_files", "gui_get_git_graph"])
    await adapter.handle(request({ id: type, type }));
  assert.ok(emitted.every((response) => response.success));
  assert.equal(emitted[0].data.workspace, cwd);
  assert.equal(adapter.agentBusy, true);
  adapter.mutating = true;
  await adapter.handle(request({ id: "blocked", type: "gui_list_files" }));
  assert.equal(emitted.at(-1).error, "WORKSPACE_BUSY");
});
