// Read-only workspace explorer. No shell, network, hooks, index writes or Pi internals.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readdir, lstat, open, realpath } from "node:fs/promises";
import { constants } from "node:fs";
import path from "node:path";

const exec = promisify(execFile);
const PREVIEW_BYTES = 256 * 1024;
const fail = (code) => {
  throw Object.assign(new Error(code), { code });
};
const slash = (value) => value.split(path.sep).join("/");
const same = (a, b) =>
  process.platform === "win32"
    ? path.resolve(a).toLowerCase() === path.resolve(b).toLowerCase()
    : path.resolve(a) === path.resolve(b);
const inside = (root, target) => {
  const relative = path.relative(root, target);
  return (
    relative === "" ||
    (!relative.startsWith(`..${path.sep}`) &&
      relative !== ".." &&
      !path.isAbsolute(relative))
  );
};

async function git(cwd, args, { optional = false, preview = false } = {}) {
  try {
    return (
      await exec(
        "git",
        [
          "--no-optional-locks",
          "--literal-pathspecs",
          "-c",
          "core.fsmonitor=false",
          "-C",
          cwd,
          ...args,
        ],
        {
          windowsHide: true,
          timeout: 15000,
          maxBuffer: preview ? PREVIEW_BYTES : 16 * 1024 * 1024,
          env: {
            ...process.env,
            GIT_OPTIONAL_LOCKS: "0",
            GIT_TERMINAL_PROMPT: "0",
          },
        },
      )
    ).stdout;
  } catch (error) {
    if (error.code === "ENOENT") fail("GIT_UNAVAILABLE");
    if (error.code === "ERR_CHILD_PROCESS_STDIO_MAXBUFFER")
      fail(preview ? "DIFF_TOO_LARGE" : "REPOSITORY_TOO_LARGE");
    if (optional && typeof error.code === "number" && !error.killed)
      return null;
    fail("GIT_FAILED");
  }
}

function relativePath(value, { root = true } = {}) {
  if (
    typeof value !== "string" ||
    value.includes("\0") ||
    value.includes("\\") ||
    path.isAbsolute(value) ||
    /^[a-z]:/i.test(value)
  )
    fail("INVALID_PATH");
  if (value === "" && root) return value;
  if (
    !value ||
    value
      .split("/")
      .some(
        (part) =>
          !part ||
          part === "." ||
          part === ".." ||
          part.toLowerCase() === ".git",
      )
  )
    fail("INVALID_PATH");
  if (
    process.platform === "win32" &&
    value
      .split("/")
      .some(
        (part) =>
          /[<>:"|?*\x00-\x1f]/.test(part) ||
          /[. ]$/.test(part) ||
          /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(part),
      )
  )
    fail("INVALID_PATH");
  return value;
}

async function safePath(cwd, relative, { missing = false } = {}) {
  relativePath(relative);
  let target = cwd;
  for (const part of relative.split("/").filter(Boolean)) {
    target = path.join(target, part);
    if (!inside(cwd, target)) fail("INVALID_PATH");
    try {
      if ((await lstat(target)).isSymbolicLink()) fail("SYMLINK_UNAVAILABLE");
    } catch (error) {
      if (missing && error.code === "ENOENT") continue;
      if (error.code === "SYMLINK_UNAVAILABLE") throw error;
      fail("FILE_UNAVAILABLE");
    }
  }
  return target;
}

export function parseStatus(output) {
  const records = output.split("\0");
  const result = new Map();
  for (let i = 0; i < records.length; i++) {
    const record = records[i];
    if (!record) continue;
    if (record.length < 4 || record[2] !== " ") fail("GIT_FAILED");
    const xy = record.slice(0, 2);
    const name = record.slice(3).replace(/\/$/, "");
    const original = /[RC]/.test(xy) ? records[++i] : null;
    if (original === undefined) fail("GIT_FAILED");
    result.set(name, { xy, original });
  }
  return result;
}

export function statusKind(xy) {
  if (!xy || xy === "  ") return "clean";
  if (xy === "??") return "untracked";
  if (xy === "!!") return "ignored";
  if (xy.includes("U") || xy === "AA" || xy === "DD") return "conflict";
  if (xy.includes("D")) return "deleted";
  if (xy.includes("R")) return "renamed";
  if (xy.includes("A")) return "added";
  if (xy[1] !== " ") return "modified";
  return "staged";
}
const priority = {
  none: 0,
  ignored: 1,
  clean: 2,
  untracked: 3,
  staged: 4,
  added: 5,
  renamed: 6,
  modified: 7,
  deleted: 8,
  conflict: 9,
};

export function parseLog(output) {
  const fields = output.split("\0");
  if (fields.at(-1) === "") fields.pop();
  if (fields.length % 5) fail("GIT_FAILED");
  const commits = [];
  for (let i = 0; i < fields.length; i += 5) {
    commits.push({
      hash: fields[i],
      parents: fields[i + 1].split(" ").filter(Boolean),
      author: fields[i + 2],
      date: fields[i + 3],
      subject: fields[i + 4],
      refs: [],
    });
  }
  return commits;
}

export function parseChangedFiles(output) {
  const fields = output.split("\0");
  const files = [];
  for (let i = 0; i < fields.length && fields[i]; ) {
    const code = fields[i++];
    const first = fields[i++];
    const renamed = /^[RC]/.test(code);
    const name = renamed ? fields[i++] : first;
    if (!name || !first) fail("GIT_FAILED");
    files.push({
      path: name,
      original: renamed ? first : null,
      status: code[0],
    });
  }
  return files;
}

export class WorkspaceBrowser {
  constructor(current) {
    this.current = current;
    this.revision = 0;
    this.cache = null;
    this.loading = null;
  }
  invalidate() {
    this.revision++;
    this.cache = null;
  }
  workspace(value) {
    if (
      typeof value !== "string" ||
      !path.isAbsolute(value) ||
      !same(value, this.current())
    )
      fail("WORKSPACE_CHANGED");
    return this.current();
  }
  async scope(cwd, relative) {
    await safePath(cwd, relative, { missing: true });
    let target = cwd,
      scope = cwd;
    for (const part of relative.split("/").filter(Boolean)) {
      target = path.join(target, part);
      try {
        const marker = await lstat(path.join(target, ".git"));
        if (marker.isDirectory() || marker.isFile()) scope = target;
      } catch (error) {
        if (error.code !== "ENOENT") fail("DIRECTORY_UNAVAILABLE");
      }
    }
    return scope;
  }
  async repository(cwd, force = false) {
    if (force) this.invalidate();
    const revision = this.revision;
    const matches = (entry) =>
      entry?.cwd === cwd && entry.revision === revision;
    if (matches(this.cache) && this.cache.expires > Date.now())
      return this.cache.data;
    if (matches(this.loading)) return this.loading.promise;
    const load = { cwd, revision };
    load.promise = this.readRepository(cwd)
      .then((data) => {
        if (revision === this.revision && inside(this.current(), cwd))
          this.cache = { cwd, revision, data, expires: Date.now() + 5000 };
        return data;
      })
      .finally(() => {
        if (this.loading === load) this.loading = null;
      });
    this.loading = load;
    return load.promise;
  }
  async readRepository(cwd) {
    const root = await git(cwd, ["rev-parse", "--show-toplevel"], {
      optional: true,
    });
    if (root === null) return null;
    const repository = root.replace(/\r?\n$/, "");
    if (!inside(repository, cwd)) fail("NOT_GIT");
    const [status, tracked, branch, head] = await Promise.all([
      git(repository, [
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=all",
        "--ignored=matching",
      ]),
      git(repository, ["ls-files", "--cached", "-z"]),
      git(repository, ["symbolic-ref", "--quiet", "--short", "HEAD"], {
        optional: true,
      }),
      git(repository, ["rev-parse", "--verify", "HEAD^{commit}"], {
        optional: true,
      }),
    ]);
    const statuses = parseStatus(status);
    const prefix = slash(path.relative(repository, cwd));
    const local = (name) =>
      prefix
        ? name.startsWith(`${prefix}/`)
          ? name.slice(prefix.length + 1)
          : null
        : name;
    const entries = new Map();
    for (const name of tracked.split("\0").filter(Boolean)) {
      const relative = local(name);
      if (relative)
        entries.set(relative, { status: "clean", xy: "  ", original: null });
    }
    for (const [name, item] of statuses) {
      const relative = local(name);
      if (relative)
        entries.set(relative, { ...item, status: statusKind(item.xy) });
    }
    const directories = new Map();
    for (const [name, entry] of entries) {
      const parts = name.split("/");
      parts.pop();
      while (parts.length) {
        const folder = parts.join("/");
        if ((priority[directories.get(folder)] ?? 0) < priority[entry.status])
          directories.set(folder, entry.status);
        parts.pop();
      }
    }
    return {
      root: repository,
      prefix,
      branch: branch?.trimEnd() ?? null,
      head: head?.trim() ?? null,
      entries,
      directories,
    };
  }
  async listFiles(request) {
    const cwd = this.workspace(request.workspace);
    const relative = relativePath(request.path ?? "");
    const target = await safePath(cwd, relative, { missing: true });
    const scope = await this.scope(cwd, relative);
    const localDirectory = slash(path.relative(scope, target));
    const localPrefix = localDirectory ? `${localDirectory}/` : "";
    let repository = null,
      gitWarning = null;
    try {
      repository = await this.repository(scope, request.force === true);
    } catch (error) {
      gitWarning = error.code ?? "GIT_FAILED";
    }
    let disk;
    try {
      disk = await readdir(target, { withFileTypes: true });
    } catch (error) {
      // Keep deleted tracked folders navigable, but do not swallow access errors.
      if (
        error.code !== "ENOENT" ||
        !repository?.directories.has(localDirectory)
      )
        fail("DIRECTORY_UNAVAILABLE");
      disk = [];
    }
    const children = new Map();
    const prefix = relative ? `${relative}/` : "";
    for (const item of disk) {
      if (item.name.toLowerCase() === ".git") continue;
      children.set(item.name, {
        name: item.name,
        path: prefix + item.name,
        directory: item.isDirectory(),
        symlink: item.isSymbolicLink(),
        missing: false,
      });
    }
    if (repository) {
      for (const [name, entry] of repository.entries) {
        // Sparse-checkout omissions are not deleted workspace files.
        if (entry.status !== "deleted" || !name.startsWith(localPrefix))
          continue;
        const parts = name.slice(localPrefix.length).split("/");
        if (!children.has(parts[0]) && parts[0].toLowerCase() !== ".git")
          children.set(parts[0], {
            name: parts[0],
            path: prefix + parts[0],
            directory: parts.length > 1,
            symlink: false,
            missing: true,
          });
      }
    }
    const ignoredParent =
      repository &&
      [...repository.entries].some(
        ([name, entry]) =>
          entry.status === "ignored" &&
          (localDirectory === name || localDirectory.startsWith(`${name}/`)),
      );
    const items = [...children.values()]
      .map((item) => {
        const key = localPrefix + item.name;
        const entry = repository?.entries.get(key);
        return {
          ...item,
          status: repository
            ? ignoredParent
              ? "ignored"
              : (entry?.status ??
                repository.directories.get(key) ??
                "untracked")
            : "none",
          indexStatus: entry?.xy[0] ?? " ",
          worktreeStatus: entry?.xy[1] ?? " ",
        };
      })
      .sort(
        (a, b) =>
          Number(b.directory) - Number(a.directory) ||
          a.name.localeCompare(b.name, undefined, { numeric: true }) ||
          a.name.localeCompare(b.name),
      );
    const limit = Math.min(
      5000,
      Math.max(500, Number.isInteger(request.limit) ? request.limit : 500),
    );
    return {
      workspace: cwd,
      path: relative,
      entries: items.slice(0, limit),
      hasMore: items.length > limit,
      git: !!repository,
      gitWarning,
      branch: repository?.branch ?? null,
    };
  }
  async graph(request) {
    const cwd = this.workspace(request.workspace);
    const repo = await this.repository(cwd, request.force === true);
    if (!repo) fail("NOT_GIT");
    const limit = Math.min(
      1000,
      Math.max(100, Number.isInteger(request.limit) ? request.limit : 100),
    );
    const [log, refs] = await Promise.all([
      git(repo.root, [
        "log",
        "--all",
        ...(repo.head ? [repo.head] : []),
        "--topo-order",
        `--max-count=${limit + 1}`,
        "-z",
        "--format=%H%x00%P%x00%an%x00%aI%x00%s",
      ]),
      git(repo.root, [
        "for-each-ref",
        "--format=%(objectname)%00%(*objectname)%00%(refname)",
        "refs/heads/",
        "refs/remotes/",
        "refs/tags/",
      ]),
    ]);
    const commits = parseLog(log);
    const byHash = new Map(commits.map((commit) => [commit.hash, commit]));
    for (const line of refs.split("\n").filter(Boolean)) {
      const [hash, peeled, name] = line.split("\0");
      const commit = byHash.get(peeled || hash);
      if (commit) commit.refs.push(name);
    }
    return {
      workspace: cwd,
      root: repo.root,
      branch: repo.branch,
      head: repo.head,
      commits: commits.slice(0, limit),
      hasMore: commits.length > limit,
    };
  }
  commit(value) {
    if (
      typeof value !== "string" ||
      !/^(?:[0-9a-f]{40}|[0-9a-f]{64})$/.test(value)
    )
      fail("INVALID_COMMIT");
    return value;
  }
  async commitData(repo, hash) {
    const output = await git(repo.root, [
      "show",
      "-s",
      "--no-show-signature",
      "--format=%H%x00%P%x00%an%x00%aI%x00%B",
      this.commit(hash),
    ]);
    const [resolved, parents, author, date, message] = output.split("\0");
    return {
      hash: resolved,
      parents: parents.split(" ").filter(Boolean),
      author,
      date,
      message: message.trimEnd(),
    };
  }
  async details(request) {
    const cwd = this.workspace(request.workspace);
    const repo = await this.repository(cwd);
    if (!repo) fail("NOT_GIT");
    const commit = await this.commitData(repo, request.commit);
    const output = await git(repo.root, [
      "diff-tree",
      "--no-commit-id",
      "--root",
      "-r",
      "-z",
      "--name-status",
      "-M",
      ...(commit.parents.length ? [commit.parents[0]] : []),
      commit.hash,
    ]);
    const prefix = repo.prefix ? `${repo.prefix}/` : "";
    const files = parseChangedFiles(output).flatMap((file) => {
      const destination = file.path.startsWith(prefix);
      const source = file.original?.startsWith(prefix);
      if (destination)
        return [
          {
            ...file,
            path: file.path.slice(prefix.length),
            original: source ? file.original.slice(prefix.length) : null,
            status: file.original && !source ? "A" : file.status,
          },
        ];
      return source
        ? [
            {
              path: file.original.slice(prefix.length),
              original: null,
              status: "D",
            },
          ]
        : [];
    });
    return {
      workspace: cwd,
      ...commit,
      files: files.slice(0, 2000),
      limited: files.length > 2000,
    };
  }
  async preview(request) {
    const cwd = this.workspace(request.workspace);
    const relative = relativePath(request.path, { root: false });
    const result = {
      workspace: cwd,
      path: relative,
      content: null,
      kind: "missing",
      stagedDiff: "",
      workingDiff: "",
      commitDiff: "",
      diffLimited: false,
    };
    let repo,
      scope = cwd;
    try {
      if (request.commit == null)
        scope = await this.scope(
          cwd,
          relative.split("/").slice(0, -1).join("/"),
        );
      repo = await this.repository(scope);
    } catch (error) {
      if (error.code === "SYMLINK_UNAVAILABLE") {
        result.kind = "symlink";
        return result;
      }
      if (error.code !== "GIT_UNAVAILABLE") throw error;
    }
    const absolute = path.join(cwd, relative);
    const repoPath = repo
      ? slash(path.relative(repo.root, absolute))
      : relative;
    const paths = [repoPath];
    const original = repo?.entries.get(
      slash(path.relative(scope, absolute)),
    )?.original;
    if (original && inside(cwd, path.join(repo.root, original)))
      paths.push(original);
    const diff = async (args) => {
      try {
        return await git(
          repo.root,
          [
            "diff",
            "--no-ext-diff",
            "--no-textconv",
            "--no-color",
            "--find-renames",
            ...args,
            "--",
            ...paths,
          ],
          { preview: true },
        );
      } catch (error) {
        if (error.code !== "DIFF_TOO_LARGE") throw error;
        result.diffLimited = true;
        return "";
      }
    };
    if (request.commit != null) {
      if (!repo) fail("NOT_GIT");
      const commit = await this.details(request);
      const previous = commit.files.find(
        (file) => file.path === relative,
      )?.original;
      // Use the verified rename pair, not a caller-provided second path.
      paths.splice(1);
      if (previous)
        paths.push(repo.prefix ? `${repo.prefix}/${previous}` : previous);
      if (commit.parents.length)
        result.commitDiff = await diff([commit.parents[0], commit.hash]);
      else {
        try {
          result.commitDiff = await git(
            repo.root,
            [
              "show",
              "--format=",
              "--root",
              "--no-ext-diff",
              "--no-textconv",
              "--no-color",
              "--no-renames",
              commit.hash,
              "--",
              repoPath,
            ],
            { preview: true },
          );
        } catch (error) {
          if (error.code !== "DIFF_TOO_LARGE") throw error;
          result.diffLimited = true;
        }
      }
      return result;
    }
    try {
      const target = await safePath(cwd, relative, { missing: true });
      const info = await lstat(target);
      if (!info.isFile()) result.kind = "unsupported";
      else if (info.size > PREVIEW_BYTES) result.kind = "tooLarge";
      else {
        const handle = await open(
          target,
          constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0),
        );
        try {
          // Recheck the resolved path and descriptor before reading. A fixed
          // buffer also bounds memory if another process grows the file.
          if (!inside(cwd, await realpath(target))) fail("SYMLINK_UNAVAILABLE");
          if (!(await handle.stat()).isFile()) fail("FILE_UNAVAILABLE");
          const buffer = Buffer.alloc(PREVIEW_BYTES + 1);
          let size = 0;
          while (size < buffer.length) {
            const { bytesRead } = await handle.read(
              buffer,
              size,
              buffer.length - size,
              size,
            );
            if (!bytesRead) break;
            size += bytesRead;
          }
          const content = buffer.subarray(0, size);
          if (size > PREVIEW_BYTES) result.kind = "tooLarge";
          else if (content.includes(0)) result.kind = "binary";
          else {
            try {
              result.content = new TextDecoder("utf-8", { fatal: true }).decode(
                content,
              );
              result.kind = "text";
            } catch {
              result.kind = "binary";
            }
          }
        } finally {
          await handle.close();
        }
      }
    } catch (error) {
      if (error.code === "SYMLINK_UNAVAILABLE") result.kind = "symlink";
      else if (error.code !== "ENOENT") throw error;
    }
    if (repo && result.kind !== "symlink") {
      [result.stagedDiff, result.workingDiff] = await Promise.all([
        diff(["--cached"]),
        diff([]),
      ]);
    }
    return result;
  }
}
