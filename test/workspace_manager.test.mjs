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
import { WorkspaceManager } from "../assets/backend/workspace_manager.mjs";
import {
    WorkspaceService,
    routePiOutput,
} from "../assets/backend/workspace_rpc.mjs";
const exec = promisify(execFile);
const git = async (cwd, ...args) =>
    (await exec("git", ["-C", cwd, ...args])).stdout;

async function fixture(t) {
    const root = await realpath(
        await mkdtemp(path.join(tmpdir(), "pi-gui-parallel-")),
    );
    const repo = path.join(root, "中文 repo");
    await mkdir(repo);
    await git(repo, "init", "-b", "main");
    await git(repo, "config", "user.name", "Fixture");
    await git(repo, "config", "user.email", "fixture@example.invalid");
    await writeFile(path.join(repo, "file.txt"), "original\n");
    await writeFile(path.join(repo, ".gitignore"), ".env\n");
    await git(repo, "add", ".");
    await git(repo, "commit", "-m", "initial");
    const service = new WorkspaceService(
        {
            list: async (cwd) => [
                {
                    path: path.join(cwd, "saved.jsonl"),
                    cwd,
                    id: "saved",
                    modified: new Date(),
                    messageCount: 2,
                    name: "Saved",
                },
            ],
        },
        path.join(root, "gui.json"),
        repo,
    );
    await service.initialize();
    const children = [],
        output = [];
    const manager = new WorkspaceManager(
        service,
        (cwd, emit, sessionPath, onExit) => {
            const child = {
                cwd,
                sessionPath,
                sent: [],
                stopped: false,
                request: async () => ({
                    isStreaming: false,
                    messageCount: 0,
                    sessionFile:
                        sessionPath ??
                        path.join(cwd, `session-${children.length}.jsonl`),
                }),
                receive: (event) =>
                    routePiOutput(JSON.stringify(event), new Map(), emit),
                send(request) {
                    this.sent.push(request);
                },
                async stop() {
                    this.stopped = true;
                },
                crash: onExit,
            };
            children.push(child);
            return child;
        },
        (line) => output.push(JSON.parse(line)),
    );
    t.after(async () => {
        await manager.close();
        await rm(root, { recursive: true, force: true, maxRetries: 5 });
    });
    await manager.initialize();
    await manager.start();
    return { root, repo, service, manager, children, output };
}

test("parallel channels isolate identical IDs/events and exit; startup UI replies bypass readiness", async (t) => {
    const { repo, manager, children, output } = await fixture(t);
    await manager.openChannel({ channelId: "a", workspace: repo });
    await manager.openChannel({ channelId: "b", workspace: repo });
    await Promise.all([...manager.channels.values()].map((c) => c.ready));
    const packet = (channel, message) => ({
        type: "gui_channel",
        channel,
        message,
    });
    children[1].receive({ type: "agent_start" });
    await manager.handle(
        packet("a", { id: "same", type: "prompt", message: "A" }),
    );
    await manager.handle(
        packet("b", { id: "same", type: "prompt", message: "B" }),
    );
    children[2].receive({
        id: "same",
        type: "response",
        command: "prompt",
        success: true,
    });
    children[1].receive({
        id: "same",
        type: "response",
        command: "prompt",
        success: true,
    });
    assert.deepEqual(
        output
            .filter((p) => p.message.type === "response")
            .slice(-2)
            .map((p) => p.channel),
        ["b", "a"],
    );
    children[1].receive({ type: "agent_end" });
    await assert.rejects(manager.closeChannel({ channelId: "a" }), {
        code: "WORKSPACE_BUSY",
    });
    children[1].receive({ type: "agent_settled" });
    await manager.closeChannel({ channelId: "a" });
    assert.equal(children[1].stopped, true);
    assert.equal(children[2].stopped, false);
    children[2].crash();
    assert.equal(manager.channels.get("b").status, "exited");
    assert.equal(manager.channels.get("primary").status, "ready");
    const entry = manager.channels.get("primary");
    const ready = entry.ready;
    entry.ready = new Promise(() => {});
    await manager.handle(
        packet("primary", {
            type: "extension_ui_response",
            id: "same",
            value: "answer",
        }),
    );
    assert.equal(children[0].sent.at(-1).value, "answer");
    entry.ready = ready;
});

test("history ownership is deduplicated under concurrent opens; invalid histories never launch", async (t) => {
    const { repo, manager, children } = await fixture(t);
    const result = await Promise.all(
        ["a", "b"].map((channelId) =>
            manager.openChannel({
                channelId,
                workspace: repo,
                sessionPath: path.join(repo, "saved.jsonl"),
            }),
        ),
    );
    assert.equal(result[0].id, result[1].id);
    assert.equal(children.length, 2);
    await assert.rejects(
        manager.openChannel({
            channelId: "escape",
            workspace: repo,
            sessionPath: "not-a-listed-session",
        }),
        { code: "SESSIONS_UNAVAILABLE" },
    );
    assert.equal(children.length, 2);
    await manager.handle({
        type: "gui_channel",
        channel: result[0].id,
        message: {
            id: "switch",
            type: "switch_session",
            sessionPath: "/elsewhere",
        },
    });
    assert.equal(children[1].sent.length, 0);
});

test("background worktree jobs retain branches and reject live/ignored directories without stopping other sessions", async (t) => {
    const { repo, manager, children, service } = await fixture(t);
    children[0].receive({ type: "agent_start" });
    const job = await manager.worktreeJob({
        type: "gui_add_worktree",
        operationId: "create",
        project: repo,
        name: "侧栏任务",
        branch: "feat/sidebar",
        baseRef: "main",
    });
    await Promise.all(manager.work);
    assert.equal(job.status, "done");
    assert.equal(children[0].stopped, false);
    assert.equal(
        (await manager.catalog()).projects[0].worktrees.find(
            (w) =>
                w.path.replaceAll("\\", "/") === job.path.replaceAll("\\", "/"),
        ).name,
        "侧栏任务",
    );
    await manager.openChannel({ channelId: "work", workspace: job.path });
    const blocked = await manager.worktreeJob({
        type: "gui_delete_worktree",
        operationId: "delete-live",
        project: repo,
        path: job.path,
    });
    await Promise.all(manager.work);
    assert.equal(blocked.error, "WORKTREE_IN_USE");
    await manager.closeChannel({ channelId: "work", stop: true });
    await writeFile(path.join(job.path, ".env"), "local secret");
    const dirty = await manager.worktreeJob({
        type: "gui_delete_worktree",
        operationId: "delete-dirty",
        project: repo,
        path: job.path,
    });
    await Promise.all(manager.work);
    assert.equal(dirty.error, "WORKTREE_DIRTY");
    assert.equal(
        await readFile(path.join(job.path, ".env"), "utf8"),
        "local secret",
    );
    await rm(path.join(job.path, ".env"));
    const removed = await manager.worktreeJob({
        type: "gui_delete_worktree",
        operationId: "delete-clean",
        project: repo,
        path: job.path,
    });
    await Promise.all(manager.work);
    assert.equal(removed.status, "done");
    assert.equal(existsSync(job.path), false);
    assert.match(
        await git(repo, "branch", "--list", "feat/sidebar"),
        /feat\/sidebar/,
    );
    assert.equal(
        (
            await manager.worktreeJob({
                type: "gui_add_worktree",
                operationId: "create",
                project: repo,
            })
        ).id,
        "create",
    );
    assert.equal(service.catalog.projects.length, 1);
});

test("restart relaunches the current workspace on its persisted last conversation", async (t) => {
    const { root, repo, manager, children, service } = await fixture(t);
    const conversation = path.join(repo, "conversation.jsonl");
    await writeFile(conversation, "{}\n");
    // The GUI reads state after chatting; the forwarded response carries the
    // live session file and its message count.
    children[0].receive({
        id: "state",
        type: "response",
        command: "get_state",
        success: true,
        data: { sessionFile: conversation, messageCount: 3 },
    });
    await manager.saving;
    const store = JSON.parse(
        await readFile(path.join(root, "gui.json"), "utf8"),
    );
    const saved = store.recent.find(
        (item) =>
            path.normalize(item.path).toLowerCase() ===
            path.normalize(repo).toLowerCase(),
    );
    assert.equal(saved?.sessionPath, conversation);
    // Empty sessions never overwrite the bookmark.
    const fresh = path.join(repo, "fresh.jsonl");
    await writeFile(fresh, "{}\n");
    children[0].receive({
        id: "state2",
        type: "response",
        command: "get_state",
        success: true,
        data: { sessionFile: fresh, messageCount: 0 },
    });
    await manager.saving;
    assert.equal(
        JSON.parse(
            await readFile(path.join(root, "gui.json"), "utf8"),
        ).recent.find(
            (item) =>
                path.normalize(item.path).toLowerCase() ===
                path.normalize(repo).toLowerCase(),
        ).sessionPath,
        conversation,
    );
    // A fresh GUI launch restores the same conversation on the same workspace.
    const launched = [];
    const second = new WorkspaceManager(
        service,
        (cwd, emit, sessionPath) => {
            launched.push(sessionPath);
            return {
                cwd,
                sent: [],
                send(request) {
                    this.sent.push(request);
                },
                request: async () => ({
                    isStreaming: false,
                    messageCount: 3,
                    sessionFile: sessionPath,
                }),
                async stop() {},
            };
        },
        () => {},
    );
    await second.initialize();
    await second.start();
    assert.equal(launched[0], conversation);
    await second.close();
    // A deleted session file falls back to a new conversation instead of
    // handing Pi a stale path.
    await rm(conversation);
    const third = new WorkspaceManager(
        service,
        (cwd, emit, sessionPath) => {
            launched.push(sessionPath);
            return {
                cwd,
                sent: [],
                send(request) {
                    this.sent.push(request);
                },
                request: async () => ({
                    isStreaming: false,
                    messageCount: 0,
                    sessionFile: sessionPath,
                }),
                async stop() {},
            };
        },
        () => {},
    );
    await third.initialize();
    await third.start();
    assert.equal(launched[1], undefined);
    await third.close();
    assert.equal(service.persistenceWarning, false);
});

test("an active new chat becomes the restart bookmark even though its sessionFile never changes", async (t) => {
    const { root, repo, manager, children, service } = await fixture(t);
    const conversation = path.join(repo, "conversation.jsonl");
    await writeFile(conversation, "{}\n");
    children[0].receive({
        id: "state",
        type: "response",
        command: "get_state",
        success: true,
        data: { sessionFile: conversation, messageCount: 2 },
    });
    await manager.saving;
    // A brand-new chat gets its own channel. Its sessionFile is assigned at
    // startup (messageCount 0) and then never changes, so comparing against
    // the previous observation would never update the bookmark again.
    const described = await manager.openChannel({
        channelId: "chat",
        workspace: repo,
    });
    assert.equal(described.id, "chat");
    const chat = children[1];
    const chatEntry = manager.channels.get("chat");
    await chatEntry.ready;
    const chatSession = (await chat.request()).sessionFile;
    assert.ok(chatSession && chatSession !== conversation);
    await writeFile(chatSession, "{}\n");
    children[0].receive({
        id: "state-primary",
        type: "response",
        command: "get_state",
        success: true,
        data: { sessionFile: conversation, messageCount: 2 },
    });
    chat.receive({
        id: "state-chat-empty",
        type: "response",
        command: "get_state",
        success: true,
        data: { sessionFile: chatSession, messageCount: 0 },
    });
    await manager.saving;
    // The empty new chat has not displaced the primary conversation yet.
    assert.equal(
        service.recent.find(
            (i) =>
                path.normalize(i.path).toLowerCase() ===
                path.normalize(repo).toLowerCase(),
        )?.sessionPath,
        conversation,
    );
    // The user chats in the new tab; every settle re-reads state with the
    // same sessionFile. Only now must the bookmark follow the active chat.
    chat.receive({
        id: "state-chat",
        type: "response",
        command: "get_state",
        success: true,
        data: { sessionFile: chatSession, messageCount: 7 },
    });
    chat.receive({
        id: "state-chat-again",
        type: "response",
        command: "get_state",
        success: true,
        data: { sessionFile: chatSession, messageCount: 8 },
    });
    await manager.saving;
    assert.equal(
        service.recent.find(
            (i) =>
                path.normalize(i.path).toLowerCase() ===
                path.normalize(repo).toLowerCase(),
        )?.sessionPath,
        chatSession,
    );
    const store = JSON.parse(
        await readFile(path.join(root, "gui.json"), "utf8"),
    );
    assert.equal(
        store.recent.find(
            (i) =>
                path.normalize(i.path).toLowerCase() ===
                path.normalize(repo).toLowerCase(),
        )?.sessionPath,
        chatSession,
    );
    // Restart now returns to the last active conversation, not the stale one.
    const launched = [];
    const next = new WorkspaceManager(
        service,
        (cwd, _emit, sessionPath) => {
            launched.push(sessionPath);
            return {
                cwd,
                sent: [],
                send(request) {
                    this.sent.push(request);
                },
                request: async () => ({
                    isStreaming: false,
                    messageCount: 8,
                    sessionFile: sessionPath,
                }),
                async stop() {},
            };
        },
        () => {},
    );
    await next.initialize();
    await next.start();
    assert.equal(launched[0], chatSession);
    await next.close();
});

test("repository lock covers sibling worktree opens, folder projects persist and forgotten projects stay forgotten", async (t) => {
    const { repo, root, manager, service } = await fixture(t);
    const created = await service.createWorktree("feat/lock", "main");
    await manager.catalog();
    const projectKey =
        process.platform === "win32"
            ? path.normalize(repo).toLowerCase()
            : path.normalize(repo);
    manager.locks.add(projectKey);
    await assert.rejects(
        manager.openChannel({ channelId: "locked", workspace: created.path }),
        { code: "WORKSPACE_BUSY" },
    );
    manager.locks.delete(projectKey);
    const folder = path.join(root, "plain");
    await mkdir(folder);
    await manager.register(folder);
    assert.equal((await manager.catalog()).projects.length, 2);
    await manager.control({ type: "gui_forget_project", path: folder });
    assert.equal((await manager.catalog()).projects.length, 1);
    await manager.closeChannel({ channelId: "primary", stop: true });
    await manager.control({ type: "gui_forget_project", path: repo });
    const restored = new WorkspaceManager(
        service,
        () => {
            throw Error("should not launch");
        },
        () => {},
    );
    await restored.initialize();
    await restored.start();
    assert.equal(restored.projects.length, 0);
    await restored.close();
});

test("worktree bases accept only verified local/remote refs or full commit hashes without fetching", async (t) => {
    const { repo, service } = await fixture(t);
    const commit = (await git(repo, "rev-parse", "HEAD")).trim();
    await git(repo, "update-ref", "refs/remotes/origin/main", commit);
    await git(
        repo,
        "symbolic-ref",
        "refs/remotes/origin/HEAD",
        "refs/remotes/origin/main",
    );
    const remote = await service.createWorktree(
        "feat/from-remote",
        "origin/main",
    );
    const pinned = await service.createWorktree("feat/from-commit", commit);
    assert.equal((await git(remote.path, "rev-parse", "HEAD")).trim(), commit);
    assert.equal((await git(pinned.path, "rev-parse", "HEAD")).trim(), commit);
    await assert.rejects(service.createWorktree("feat/invalid", "--help"), {
        code: "INVALID_BASE",
    });
    await assert.rejects(service.createWorktree("feat/invalid", "HEAD~1"), {
        code: "INVALID_BASE",
    });
});

test("virtual sections migrate v1, persist ordering/collapse and delete without touching projects or channels", async (t) => {
    const { repo, service, manager, children } = await fixture(t);
    const original = await readFile(path.join(repo, "file.txt"), "utf8");
    service.catalog = { version: 1, projects: manager.projects, names: {} };
    await manager.initialize();
    assert.equal((await manager.catalog()).sections.length, 0);
    assert.equal(manager.projects[0].sectionId, null);
    const control = (type, data) => manager.control({ type, ...data });
    await control("gui_create_section", { sectionId: "work", name: " 工作 " });
    await control("gui_create_section", {
        sectionId: "personal",
        name: "个人",
    });
    // Same request identity is idempotent after an uncertain reply.
    await control("gui_create_section", { sectionId: "work", name: "工作" });
    await control("gui_move_project", { path: repo, sectionId: "work" });
    await control("gui_update_section", {
        sectionId: "personal",
        direction: "up",
        collapsed: true,
        name: "个人项目",
    });
    const saved = JSON.parse(await readFile(service.storePath, "utf8")).catalog;
    assert.equal(saved.version, 2);
    assert.deepEqual(
        saved.sections.map((s) => s.id),
        ["personal", "work"],
    );
    assert.equal(saved.sections[0].collapsed, true);
    assert.equal(saved.projects[0].sectionId, "work");
    await manager.initialize();
    assert.equal((await manager.catalog()).sections[0].name, "个人项目");
    await assert.rejects(
        control("gui_move_project", { path: repo, sectionId: "missing" }),
        { code: "SECTION_UNAVAILABLE" },
    );
    await assert.rejects(
        control("gui_update_section", { sectionId: "work", name: "  " }),
        { code: "INVALID_NAME" },
    );
    await control("gui_delete_section", { sectionId: "work" });
    assert.equal(manager.projects[0].sectionId, null);
    assert.equal(manager.channels.size, 1);
    assert.equal(children[0].stopped, false);
    assert.equal(await readFile(path.join(repo, "file.txt"), "utf8"), original);
    assert.equal(
        JSON.parse(await readFile(service.storePath, "utf8")).catalog
            .projects[0].sectionId,
        null,
    );
});

test("real subdirectories browse and open with their own cwd; removed projects revoke descendant access", async (t) => {
    const { repo, root, manager } = await fixture(t);
    const nested = path.join(repo, "src", "nested");
    await mkdir(nested, { recursive: true });
    await writeFile(path.join(nested, "code.txt"), "contents");
    const listing = await manager.control({
        type: "gui_list_files",
        workspace: repo,
        path: "src/nested",
    });
    assert.equal(listing.entries[0].name, "code.txt");
    const opened = await manager.openChannel({
        channelId: "nested",
        workspace: nested,
    });
    assert.equal(opened.workspace, nested);
    await manager.catalog();
    assert.equal(manager.workspaceProjects.get(nested), repo);
    await assert.rejects(
        manager.control({ type: "gui_forget_project", path: repo }),
        { code: "WORKTREE_IN_USE" },
    );
    manager.locks.add(repo);
    await assert.rejects(
        manager.openChannel({ channelId: "locked", workspace: nested }),
        { code: "WORKSPACE_BUSY" },
    );
    manager.locks.clear();
    await assert.rejects(manager.knownWorkspace(root), {
        code: "WORKTREE_UNAVAILABLE",
    });
    const { symlink } = await import("node:fs/promises");
    await symlink(
        root,
        path.join(repo, "outside"),
        process.platform === "win32" ? "junction" : "dir",
    );
    await assert.rejects(manager.knownWorkspace(path.join(repo, "outside")), {
        code: "WORKTREE_UNAVAILABLE",
    });
    await manager.closeChannel({ channelId: "primary" });
    await manager.closeChannel({ channelId: "nested" });
    await manager.control({ type: "gui_forget_project", path: repo });
    await assert.rejects(manager.knownWorkspace(nested), {
        code: "WORKTREE_UNAVAILABLE",
    });
    assert.equal(existsSync(path.join(nested, "code.txt")), true);
});

test("sections attach to added projects atomically and stale section references migrate to unassigned", async (t) => {
    const { repo, root, manager, service } = await fixture(t);
    const folder = path.join(root, "another");
    await mkdir(folder);
    await assert.rejects(
        manager.control({
            type: "gui_add_project",
            path: folder,
            sectionId: "missing",
        }),
        { code: "SECTION_UNAVAILABLE" },
    );
    assert.equal(manager.projects.length, 1);
    await manager.control({
        type: "gui_create_section",
        sectionId: "group",
        name: "分区",
    });
    await manager.control({
        type: "gui_add_project",
        path: folder,
        sectionId: "group",
    });
    assert.equal(
        manager.projects.find((p) => p.path === folder).sectionId,
        "group",
    );
    const nested = path.join(repo, "nested");
    await mkdir(nested);
    await manager.openChannel({ channelId: "sub", workspace: nested });
    await manager.save();
    service.catalog = { ...service.catalog, sections: [] };
    await manager.initialize();
    assert.equal(service.current, nested);
    assert.equal(manager.workspaceProjects.get(nested), repo);
    assert.equal(
        manager.projects.find((p) => p.path === folder).sectionId,
        null,
    );
});

test("removing a project during a descendant history read cannot launch a late channel", async (t) => {
    const { repo, manager } = await fixture(t);
    const nested = path.join(repo, "src");
    await mkdir(nested);
    await manager.closeChannel({ channelId: "primary" });
    let release, started;
    const waiting = new Promise((resolve) => {
        started = resolve;
    });
    manager.scope(nested).listSessions = () => {
        started();
        return new Promise((resolve) => {
            release = resolve;
        });
    };
    const opening = manager.openChannel({
        channelId: "late",
        workspace: nested,
        sessionPath: path.join(nested, "saved.jsonl"),
    });
    const rejected = assert.rejects(opening, { code: "WORKTREE_UNAVAILABLE" });
    await waiting;
    await manager.control({ type: "gui_forget_project", path: repo });
    release({ sessions: [{ path: path.join(nested, "saved.jsonl") }] });
    await rejected;
    assert.equal(manager.channels.size, 0);
});

test("removing the Unassigned heading persists without changing projects or conversations", async (t) => {
    const { repo, manager, service, children } = await fixture(t);
    await manager.control({ type: "gui_hide_unassigned" });
    const catalog = await manager.catalog();
    assert.equal(catalog.unassignedHidden, true);
    assert.equal(catalog.projects[0].path, repo);
    assert.equal(catalog.channels.length, 1);
    assert.equal(children[0].stopped, false);
    assert.equal(
        JSON.parse(await readFile(service.storePath, "utf8")).catalog
            .unassignedHidden,
        true,
    );
    await manager.initialize();
    assert.equal((await manager.catalog()).unassignedHidden, true);
});

test("quick project creation validates names and duplicates and preserves active conversations", async (t) => {
    const { root, manager, children } = await fixture(t);
    await manager.control({
        type: "gui_create_section",
        sectionId: "work",
        name: "工作",
    });
    const result = await manager.control({
        type: "gui_create_project",
        parent: root,
        name: "new project",
        sectionId: "work",
    });
    assert.equal(result.path, path.join(root, "new project"));
    assert.equal(existsSync(result.path), true);
    assert.equal(
        (await manager.catalog()).projects.find((p) => p.path === result.path)
            .sectionId,
        "work",
    );
    assert.equal(manager.channels.size, 1);
    assert.equal(children[0].stopped, false);
    await assert.rejects(
        manager.control({
            type: "gui_create_project",
            parent: root,
            name: "new project",
        }),
        { code: "PATH_EXISTS" },
    );
    await assert.rejects(
        manager.control({
            type: "gui_create_project",
            parent: root,
            name: "../escape",
        }),
        { code: "INVALID_NAME" },
    );
    await assert.rejects(
        manager.control({
            type: "gui_create_project",
            parent: root,
            name: "no-group",
            sectionId: "missing",
        }),
        { code: "SECTION_UNAVAILABLE" },
    );
    assert.equal(existsSync(path.join(root, "no-group")), false);
});

test("child conversation directories stay discoverable after closing channels and reloading catalog", async (t) => {
    const { repo, manager, service } = await fixture(t);
    const nested = path.join(repo, "nested");
    await mkdir(nested);
    await manager.openChannel({ channelId: "child", workspace: nested });
    await manager.closeChannel({ channelId: "child" });
    assert.ok(manager.projects[0].folders.includes(nested));
    const saved = JSON.parse(await readFile(service.storePath, "utf8")).catalog;
    assert.ok(saved.projects[0].folders.includes(nested));
    await manager.initialize();
    assert.ok(
        (await manager.catalog()).projects[0].worktrees.some(
            (w) => w.path === nested,
        ),
    );
});
