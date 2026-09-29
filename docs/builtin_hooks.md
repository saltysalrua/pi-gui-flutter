---
title: "钩子页：内置运行时钩子的开关与卸载"
version: "1.0.0"
status: "implemented"
type: "feature"
tags: [flutter, settings, hooks, pi-backend, rpc]
---

# 钩子页：内置运行时钩子的开关与卸载

设置 → **内置钩子**。列出 GUI 在每次启动新的 Pi 会话时注入的内置扩展钩子，支持**启用 / 停用 / 卸载 / 恢复**。

## 这页是干什么的（人类视角）

GUI 每启动一个 Pi 进程，都会注入两个自带的扩展"钩子"，用来给界面提供文件改动对比（写入 Diff）和历史回溯能力（历史桥）。这页让它们变得可控：

- **停用**：之后的会话不再注入这个钩子，条目仍留在列表里，随时再启用。
- **卸载**：同样不再注入，但条目移到下方"已卸载"分组，点**恢复**还原。
- 内置钩子随应用打包，**文件不会被真正删除**；"卸载"是把选择记在本机配置里（`hooks.json`），应用更新后依然保持卸载状态。
- **修改只对新启动的会话生效**，正在运行的会话不受影响，也不会重启任何正在工作的 Agent。

停用历史桥后，消息打标签、回溯、分支跳转会不可用（界面报 `HISTORY_UNAVAILABLE`）；停用写入 Diff 后，时间线里写入工具只显示中性内容，不再有前后对比。

## Agent 视角：代码路径与数据结构

### 后端注册表（单一真源）

`assets/backend/gui_hooks.mjs`：

- `BUILTIN_HOOKS`：注册表，**顺序即注入顺序**（tool_diff 必须先于 history）。
  ```js
  export const BUILTIN_HOOKS = [
    { id: "tool_diff", file: "gui_tool_diff.mjs" },
    { id: "history", file: "gui_history.mjs" },
  ];
  ```
- `GuiHooks`：三态 `active | off | removed`，`active` 是默认值、**永不落盘**（全新安装的 store 文件不存在）。`injected()` 返回仍要注入的文件名集合。
- 持久化：`%APPDATA%/pi-gui/hooks.json`（测试用 `PI_GUI_HOOKS_STORE` 隔离），原子写（temp + rename），写失败置 `persistenceWarning` 并随 state 返回。

### 注入点（spawn 时一次性决定）

- `assets/backend/workspace_rpc.mjs` `PiChild` 构造函数：按 `hooks?.injected()` 过滤 `BUILTIN_HOOKS` 拼装 `--extension` 参数；`hooks = null`（兼容探针、旧测试脚本）时全量注入，行为不变。
- `main()` 创建共享 `GuiHooks` 实例，传给两个 `PiChild` 工厂和 `WorkspaceManager`（`{ packageRoot, hooks }`）——**状态变更对之后 spawn 的 Pi 生效，绝不触碰运行中的进程**。

### RPC 命令（control 通道）

| 命令 | 请求字段 | 响应 `data` |
| --- | --- | --- |
| `gui_hooks_state` | `{}` | `{ hooks: [{ id, file, state }], persistenceWarning }` |
| `gui_hooks_set` | `{ hookId, state }`（**字段名是 `hookId`**，不能用 `id`——会顶掉 RPC 关联 id，回复永远对不上号） | 同上 |

错误码：`HOOKS_UNKNOWN`（未知钩子）、`HOOKS_INVALID_STATE`（非法状态）、`UNKNOWN_COMMAND`。路由挂在 `assets/backend/workspace_manager.mjs` 的 `control()` switch（`hooks()` 方法，实例存 `this.hooksRegistry`——**字段名不能与方法名重名**，曾经导致 `this.hooks is not a function`）。

### Flutter 侧

- `lib/core/rpc/pi_hooks_types.dart`：`PiHookState` 枚举、`PiHookItem`、`PiHooksState`、`PiHooksService`（`requestGui` 封装）。
- `lib/ui/features/settings/controllers/hooks_controller.dart`：状态页控制器（三态 loading/ready/failed，逐钩子 pending 锁）。
- `lib/ui/features/settings/views/hooks_settings_view.dart`：纯渲染；启用/停用走 `AppMenuButton`（复用插件页模式），已卸载分组用 `AppActionButton.subtle` 恢复。
- `lib/ui/features/settings/views/settings_view.dart`：`SettingsPage.hooks` 导航项（`Icons.webhook_rounded`），无控制通道时走 `_PageUnavailable`。
- i18n：`lib/l10n/app_zh.arb` / `app_en.arb` 的 `hooks*` 词条（走 `flutter gen-l10n`，**绝不手改生成的 dart**）。

### 发布与测试

- 发布清单：`pubspec.yaml`（九个 backend assets，含 `gui_hooks.mjs`）+ `lib/core/rpc/pi_workspace_transport.dart` 解包列表。
- 回归：`node tool/check_hooks_rpc.mjs`（真实 multiplex 路由 + 真实 Pi 子进程，无模型调用）验证默认态、spawn 时裁剪注入（**卸载后新通道没有 `pi-gui-history` 命令，旧通道保留**）、三态落盘、错误码。
- 注意：`assets/backend/pi_launcher.mjs` 是 gitignore 的本地探针运行产物（`check_image_rpc` 原地直跑时生成），不发布、不进 pubspec。