---
title: "项目、Worktree 与并行会话"
version: "2.0.0"
status: "implemented"
type: "feature-and-architecture"
tags: [flutter, pi-rpc, session, workspace, git-worktree, parallel]
---

# 项目、Worktree 与并行会话

参考 [Orca Worktrees](https://www.onorca.dev/docs/model/worktrees)，采用 **项目 → Worktree / 主目录 → 会话** 的侧栏结构，而不是在弹窗里反复替换一个执行目录。用户已确认：**后台真并行；新会话默认留在当前 Worktree**。

## 入口与操作

- 项目列表右侧的文件夹加号：添加已有仓库或普通文件夹。主目录、Git 已登记的外部 Worktree 会一起显示；同一仓库不会因添加另一个 Worktree 重复成为项目。
- 点击项目 / Worktree 行：展开、收起其内容。点击会话：打开对应标签，不停止其他任务。
- 项目旁 `＋`：新建 Worktree。目录旁 `＋` 或标签栏 `＋`：在该目录 / 当前文档所属目录新建会话，不自动建分支。
- 同一个目录可以运行多个会话；输入区会提示其他会话正在共享这份文件。**会话隔离不等于文件隔离**，需要互不影响代码时显式创建 Worktree。
- 每个目录下面区分已打开会话和历史。运行图标、等待回答图标、未读图标用于快速定位；悬停查看完整标题、目录和状态。历史通过 Pi 官方 SDK 读取，未落盘的空会话不会伪装成历史。
- 搜索项目、Worktree、会话标题。开始搜索后按目录读取历史摘要，最多两个目录同时读取；不读取正文做全文搜索，不遍历用户整个磁盘。
- 刷新重新读取目录树与已展开的历史。失败保留已确认数据并提示，不发送 Prompt。
- 项目菜单“从列表移除项目”仅移除注册，不删除目录、分支或会话；须先关闭该项目所有会话。最后一个项目被移除后，重启不会从旧最近列表重新导入它。

聊天与文件共用原有标签栏，可以拖动、并排、合并。每个会话独立保留文本草稿、图片 / 文件附件、模型与思考档位、消息、滚动状态和扩展组件。切页不调用 `switch_session`，不改变已运行进程的 cwd，也不重新发送 Prompt。详见 [文档标签页](document_tabs.md)。

**空会话输入居中，有消息后才移到底部**。紧凑模型浮层、主题、毛玻璃和共用侧栏宽度不变。正文流式更新仅重绘本会话；侧栏摘要发生变化才通知整页，不让逐 token 事件绕过原聊天合帧。

## 关闭与恢复

- 关闭普通空闲会话只结束其所属 Pi 进程，已保存历史保留；从历史再次打开可恢复。
- 有未发送草稿 / 附件时确认是否丢弃；仍在执行、加载、模型写入或等待问答时确认“停止并关闭”。关闭窗口会对运行任务和草稿进行整体确认。后台 Worktree 创建 / 移除或管理写请求尚未确认时，提示先等待操作完成，不直接杀掉 Git 留下半成品。
- 关闭最后一个标签后显示新建会话入口，不关闭应用。
- 同一份历史在本 GUI 内只允许一个运行实例；重复点击或并发打开会定位已经存在的会话。
- 单个 Pi 退出只影响该通道，其余会话继续；不会自动重放 Prompt。关闭失败会保留会话条目，避免把未确认停止误报为已结束。
- 打开的标签、草稿和扩展状态是本次运行的内存状态，不承诺跨重启保留。重启恢复注册项目、最后打开的目录，并自动重开该目录**最近一次有内容的会话**（见下“重启回到上一个对话”）；找不到已保存内容时才从空会话开始，其余历史仍从侧边栏显式打开。

## Worktree 生命周期与安全

创建表单包含显示名称、独立分支名、起点和存放父目录。名称默认生成分支建议，可单独修改。起点可选 HEAD、本地分支、已有远程跟踪分支，或输入完整 40 / 64 位 Commit SHA。优先采用仓库已知的 `origin/HEAD`，没有时使用 HEAD。**不自动 fetch**；远程分支必须已经存在于本地跟踪引用中。

提交表单立即关闭，后台创建期间侧栏显示进度，其他会话不被停止；完成后出现新的 Worktree，用户自行选择是否在其中开会话。失败保留可见错误，修正输入或环境后从 `＋` 重新创建，不自动重试不确定结果。

- Node 用参数数组执行 `git worktree add -b`，从重新校验的提交创建，不拼 shell、不使用 `--force`。
- 新目录在主 checkout 同级 `<checkout 名称>.worktrees/<规范化分支名>`，已有目录拒绝覆盖。
- 主目录未提交文件、忽略文件、秘密配置及依赖不自动复制，不自动安装环境。
- 不自动 checkout、reset、stash、提交、合并、推送或删除分支。
- 移除必须确认完整目录；主 checkout、锁定 / 失效目录、**任何仍有本 GUI 会话占用的目录及其父 Worktree**不能移除。仅切到别的标签不等于释放占用。
- 移除前重新检查未提交、未跟踪和忽略文件（包括 `.env`）；非空即拒绝，不做强制清理。
- 同一仓库的 Worktree 创建 / 删除互斥；历史读取完成后再次检查锁，避免在删除期间启动新会话。不同仓库和既有运行会话不共用这个锁。
- 创建成功后不会因 UI 或后续启动失败自动删除目录。普通 Worktree 移除保留分支和 Pi 历史。
- 无法检测其他 GUI 实例 / 外部终端占用；仍遵守 Git worktree 锁，移除前应确认外部使用情况。

本轮不包含远程主机、PR 平台、自动化、目录共享 / 秘密复制、父子 Worktree 编排、拖动排序及归档。

## 后端结构

```text
HomeView → WorkbenchController
  │
  ├─ WorkbenchTabs：会话 / 文件 / 提交身份与分组
  ├─ 每会话 WorkbenchSession
  │    ├─ ChatController / ModelPickerController
  │    ├─ 输入草稿 / ImageAttachmentController
  │    └─ PiExtensionUiBridge / 独立 SlotManager
  └─ 每目录 WorkspaceBrowserController
       │
       ▼ 逻辑 PiRpcClient → PiChannelHub（唯一物理传输）
       │ strict JSONL，按 channel 封装
       ▼
workspace_rpc.mjs --gui-multiplex
  └─ WorkspaceManager（workspace_manager.mjs）
       ├─ control：项目目录、官方历史摘要、Git、后台任务
       ├─ primary：WorkspaceAdapter → 原生 pi --mode rpc
       ├─ 会话 A：WorkspaceAdapter → 原生 pi --mode rpc
       └─ 会话 B：WorkspaceAdapter → 原生 pi --mode rpc
```

每个逻辑客户端有自己的请求序号、写确认屏障及事件流；它们不直接创建进程。管理通道可以浏览已注册目录，不需要为查看文件启动 Agent。Agent、工具、模型调用仍由官方 Pi 执行；Flutter 不解析或改写 Pi 私有会话文件。

`WorkspaceService.listSessions` 的 5 秒短缓存按目录分别持有；同目录并发扫描合并。会话结束、消息落盘与写确认使摘要失效；前端同目录读合并，读取期间发生强制刷新时补读一次。缓存只有摘要，不保存 SDK 的 `allMessagesText`。

注册项目、显示名称、起点保存在 **GUI 自有** `workspaces.json` 的 `catalog` 字段，旧 `recent` 仅用于首次迁移。位置仍为 Windows `%APPDATA%/pi-gui/workspaces.json`，其他系统 `$XDG_CONFIG_HOME/pi-gui/workspaces.json` 或 `~/.config/pi-gui/workspaces.json`；`PI_GUI_WORKSPACE_STORE` 可覆盖。只有管理器串行保存，各通道不争写配置；保存失败有提示。

需要 PATH 中的 Node.js、npm 安装的 Pi；Git 功能需要 Git。`PiWorkspaceTransport` 携带六个脚本：`workspace_rpc.mjs`、`workspace_manager.mjs`、`workspace_browser.mjs`、`gui_tool_diff.mjs`、`gui_image_upload.mjs`、`gui_packages.mjs`，解包到同一临时目录。上传图片由适配层复用 Pi 公开缩放函数预处理，见 [图片与附件](images_and_links.md)；插件市场 / 插件管理见 [插件页文档](plugin_packages.md)。关闭应用只清理它自己的进程树和脚本。

不带 `--gui-multiplex` 的适配器继续提供原单会话协议，供兼容性回归 / 探针使用；旧 `WorkspaceController`、`WorkspaceDialog`、`HomeSidebar` 不再是生产首页入口。

### 重启回到上一个对话

重启后 `WorkspaceManager.start()` 不再从空会话启动：它在 `workspaces.json` 的 `recent` 里查最后打开目录（`service.current`）记录的 `sessionPath`，文件仍存在时直接把该会话作为 `--session` 参数传给 primary 通道的 Pi，GUI 收到 catalog 后自动重开标签并 hydrate 出完整时间线；文件已删除或还没有记录时仍从新会话开始。

记录的写入点在 `workspace_manager.mjs` 的子进程行过滤器：凡是通过通道转发的 `get_state` 成功响应，只要返回的 `sessionFile` 与该目录已保存的书签不同（`hasBookmark`，不是与同通道上次观察值比较——新建聊天的 sessionFile 终生不变，那样比较会把书签永久冻结在旧会话上）且 `messageCount > 0`，就把该会话路径写入所属目录的 `recent` 条目（不重排顺序，新建条目时插到队首并保留 24 条上限），随后走同一条串行 `save()` 链持久化。GUI 在 hydrate、agent_settled 后都会读状态，所以每轮对话结束就会落盘；空的全新会话不会覆盖旧记录。旧版本保存的 `workspaces.json` 没有 `sessionPath`，因此**升级后的第一次重启仍是新会话**，聊过一轮之后的重启才会自动回到上次对话。同时打开多个会话时，最后回读状态的通道胜出；重启后只恢复 primary 一个会话，其余历史仍从侧边栏打开。回归见 `test/workspace_manager.test.mjs`。

## 协议

这是 **GUI 适配层协议**，不是新增的 Pi 官方命令。原生请求 / 回复保持原始语义，外层通道建立命名空间：

```json
{"type":"gui_channel","channel":"session-a","message":{"id":"gui-1","type":"prompt","message":"检查当前目录"}}
{"type":"gui_channel","channel":"session-a","message":{"type":"response","id":"gui-1","command":"prompt","success":true}}
{"type":"gui_channel","channel":"session-a","message":{"type":"agent_start"}}
{"type":"gui_channel","channel":"session-a","message":{"type":"extension_ui_request","id":"q1","method":"confirm","title":"继续？"}}
{"type":"gui_channel","channel":"session-a","message":{"type":"extension_ui_response","id":"q1","confirmed":true}}
```

A、B 可以同时使用 `gui-1` 或 `q1`，不会交叉确认。坏的单行在所属通道内隔离，不能杀掉整个连接；`gui_channel_exited` 只关闭对应逻辑传输。请求超时不证明失败，写请求保持确认屏障，不自动重发；`operationId` / `channelId` 支持同次操作回读。

管理命令全部发到 `channel: "control"`：

| 命令 | 字段 | 用途 |
| --- | --- | --- |
| `gui_get_catalog` | 无 | 项目 / Worktree、通道和后台任务快照 |
| `gui_add_project` | `path` | 注册目录，Git 按主 checkout 去重 |
| `gui_forget_project` | `path` | 仅移除注册 |
| `gui_workspace_history` | `workspace`, `force?` | 官方会话摘要 |
| `gui_open_channel` | `channelId`, `workspace`, `sessionPath?` | 新会话或独占恢复历史；返回已有身份时聚焦已有会话 |
| `gui_close_channel` | `channelId`, `stop?` | 空闲关闭，或用户确认后停止并关闭 |
| `gui_add_worktree` | `operationId`, `project`, `name`, `branch`, `baseRef` | 后台创建 |
| `gui_delete_worktree` | `operationId`, `project`, `path` | 后台安全移除 |

后台任务状态为 `working / done / failed`；状态变化发送 `gui_catalog_changed`，触发快照回读。具体文件 / Git 命令仍见 [工作区浏览](workspace_browser.md)。扩展前后台和问答规则见 [扩展槽位](extension_ui_slots.md)。

## 关键路径

| 层 | 路径 |
| --- | --- |
| 后端通道 / 项目 / Git 任务 | `assets/backend/workspace_manager.mjs` |
| 原生 Pi / SDK / Git 基础操作 | `assets/backend/workspace_rpc.mjs` |
| 单物理连接与通道传输 | `lib/core/rpc/pi_channel_hub.dart` |
| 强类型目录与管理 API | `lib/core/rpc/pi_catalog_types.dart` |
| 会话所有权、历史、浏览与选择 | `lib/ui/features/home/controllers/workbench_controller.dart` |
| 全局标签、作用域与窗口关闭 | `lib/ui/features/home/views/home_view.dart` |
| 三级侧栏 | `lib/ui/features/home/widgets/workbench_sidebar.dart` |
| Worktree 表单 | `lib/ui/features/home/widgets/worktree_create_dialog.dart` |
| 扩展隔离 | `lib/core/slots/slot_manager.dart`、`pi_extension_ui_bridge.dart` |

## 验证

```bash
flutter analyze --no-pub
flutter test --no-pub
node --test test/workspace_manager.test.mjs test/workspace_backend.test.mjs test/workspace_browser_backend.test.mjs
node tool/check_parallel_rpc.mjs
node tool/check_workspace_rpc.mjs
```

- 最终 `flutter analyze --no-pub` 无问题；Flutter 全套 **81 项通过**，工作区 Node **20 项通过**，真实并行与旧单会话 RPC 探针均通过。Windows Release 构建成功，四个 backend assets 与源码 SHA-256 一致，发布目录只有正式 `pi_gui.exe`；活动 Debug GUI 未重启。
- Node 使用真实隔离 Git 仓库覆盖分组、命名、并发历史去重、通道相同 ID、退出隔离、启动问答、仓库锁、忽略文件保护、保留分支和配置恢复。
- Dart 核心回归覆盖单物理连接、逆序回复、单通道 EOF、超时不重放 / 不阻塞其他会话、独立扩展槽位 / 相同问答 ID，以及可关闭初始会话的标签状态机。
- 真实 Pi 探针启动多个官方进程，通过双向文件就绪屏障证明两个 `bash` 同时执行；验证相同请求 ID、同目录多会话、历史去重、跨项目 cwd、只关闭指定会话。不访问外部模型，不使用用户历史 / 配置 / 当前仓库。
- Windows 界面通过**临时项目副本中的独立离线应用**走查，截图只读取本应用 `RenderRepaintBoundary`。验证深浅色、并排会话、后台问答、空态居中、草稿保留、新开通道提前事件、Worktree 表单、660px + 150% UI 缩放、文件标签、运行中关闭确认及其他会话保留；11 张截图，最终无运行时错误。临时夹具不进入生产代码，不增加永久样式测试。

**新后端在下次正常启动更新后的 GUI 时装载。不要 hot restart、终止当前 Pi，或热重载重构后的 HomeView 来验证承载 Agent 的活动窗口。**
