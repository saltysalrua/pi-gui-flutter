---
title: "历史回溯、分支与复制会话"
version: "1.0.1"
status: "implemented"
type: "feature-and-architecture"
tags: [flutter, pi-rpc, history, tree, fork, clone]
---

# 历史回溯、分支与复制会话

## 范围

本轮按用户确认实现 **Pi 原生会话回溯＋消息快捷操作**，不新增代码文件检查点或回滚。不删除后续消息来伪造回溯，也不以工具 Diff 反向改文件。

以本机 Pi **0.86.0** 的 `sessions.md`、`rpc.md`、`extensions.md`、`session-format.md` 和实际 RPC/SDK 行为核对。借鉴 [Codex 编辑旧提问并分支](https://learn.chatgpt.com/codex/developer-commands)的快捷入口，但保留 Pi 更完整的同文件会话树。没有接入 Codex 后端。Codex 的公开文档和 main 源码对旧 `thread/rollback` 的弃用进度并不完全同步，因此不绑定或仿造该接口。

[Claude Code 检查点](https://code.claude.com/docs/en/checkpointing)的“仅恢复代码／仅恢复会话／两者恢复”可作为后续独立功能参考。本轮明确不实现它，已有历史也不能事后补造文件快照。

## 入口与操作

- 聊天标题栏的 **历史回溯** 图标。空会话及回到根节点后，入口在居中输入区的项目名旁，仍能找回其他分支。
- 用户消息标题旁的历史菜单：**回到这里修改**、**从这里新建会话**。先打开相应节点的预览，不自动修改上下文或发送消息。
- 窗口左侧是历史树，右侧预览正文、图片、思考与工具内容；窄窗口上下排列，底部操作独立于滚动内容。
- 支持搜索文字／标签／节点 ID，默认、隐藏工具结果、仅我的消息、仅有标签、全部五种过滤方式。与 Pi 一样，usage 记录始终不显示，纯工具调用且没有正文的正常 assistant 节点除当前叶外隐藏。
- 当前叶有主题色标记，当前路径优先排列；仅在分叉处增加缩进，长直线会话不会一层层缩到屏幕外。支持折叠、全部展开、定位当前位置、设置／清除节点标签、显示标签时间。
- 点击树后可用 ↑/↓、PageUp/PageDown 选择，←/→ 折叠展开，Enter 进入操作确认，Ctrl+O 切换过滤方式，Shift+L 编辑标签，Shift+T 切换标签时间。搜索框里的按键仍用于编辑，未接管全局双 Esc。

### 三种操作不混用

| 操作 | Pi 语义 | GUI 行为 |
| --- | --- | --- |
| 回到这里修改 / 从这里继续 | `/tree`，同一会话文件移动当前叶 | 用户或 custom_message：移动到其父节点并回填提问；其他节点：移动到该节点，输入留空。根用户消息可回到空上下文。旧路径仍在树中 |
| 从这里新建会话 | 原生 `fork`，选任意分支的用户消息之前 | 创建独立会话，回填原提问；原会话从未删除，无须先改变当前叶再 fork |
| 复制当前分支 | 原生 `clone`，复制整个活动路径到当前节点 | 创建独立会话，不自动发送，也不覆盖现有输入草稿 |

fork/clone 按 Pi 原生行为替换执行它的运行时。GUI 保留这条通道作为新会话，并用 `gui_open_channel` 在另一标签重新打开原历史；不会让同一个 sessionFile 同时被两个 GUI 通道占用。其他并行会话、文件标签、Worktree 不受影响。打开原历史失败时仍保留已经创建的新会话，原历史可从侧栏重开，不重做 fork。

### 分支摘要

同会话回溯可选择：

1. 不生成摘要（默认）；
2. 生成默认摘要；
3. 自定义摘要说明，可补充或替换默认说明。

摘要由 Pi 当前模型生成，产生用量。Pi 负责共同祖先、摘要范围、压缩语义、上下文重建和扩展钩子，GUI 不自建 Agent 或摘要逻辑。fork/clone 不携带这个摘要选项。

### 草稿与安全

- 修改上下文前明确确认；若已有草稿或附件，额外提示会替换输入。成功回填历史中的文本、图片，以及本 GUI 文件附件清单；不自动发送。
- 操作期间若扩展或其他输入改变了草稿，保留新草稿，把历史提问放入 `pendingHistoryDraft`；可用 **载入历史提问** 再确认替换。恢复附件前先准备整个新草稿，解码失败不清空输入。
- 选中当前叶是原生 no-op，不清空草稿。
- Agent 运行／重试／压缩、模型写入、扩展问答、附件选择、休眠、未确认操作期间不允许开始回溯。浏览是只读，不向模型提交提问。
- Node 和扩展都核对 `sessionId` 与 `leafId`。旧窗口上的过期选择会拒绝，要求刷新，不悄悄作用到新位置。
- 扩展的 `session_before_tree`、`session_tree`、`session_before_fork`、replacement 生命周期全部保留。扩展可以取消或自行处理摘要；扩展 UI 仍显示在历史窗口上方。
- **GUI 不回滚文件，不代表第三方扩展不能改文件**。已安装的回溯／检查点扩展钩子照常执行，界面对此有说明。
- 确认超时或损坏不代表失败：保留会话写屏障，禁止重复提交；停止和扩展回复仍可发送。迟到确认只应用一次，不重放操作。取消不会覆盖草稿；断开连接提示用户恢复会话。
- 内存中的草稿和未发送的新位置不承诺跨重启恢复；持久化和再次打开时的位置沿用 Pi 自身行为。

## 架构与关键路径

| 层 | 路径 | 职责 |
| --- | --- | --- |
| 原生能力桥 | `assets/backend/gui_history.mjs` | `ctx.navigateTree`、`pi.setLabel`、`ctx.sessionManager.getEntry`；身份、空闲与过期校验；图片/文字回填 |
| 多会话路由 | `assets/backend/workspace_manager.mjs` | 会话通道白名单明确放行五个 `gui_history_*` 命令，交所属适配器处理；control 和未知历史命令仍拒绝 |
| Node 适配 | `assets/backend/workspace_rpc.mjs` | `WorkspaceAdapter.handleHistory` 互斥、官方 fork/clone；`PiChild.history` 查命令来源、分发公开扩展命令；`routePiOutput` 解包内部回应 |
| 发布 | `lib/core/rpc/pi_workspace_transport.dart`、`pubspec.yaml` | 第七个后端 asset `gui_history.mjs`，每个 PiChild 显式 `--extension` 加载 |
| 强类型协议与服务 | `lib/core/rpc/pi_history_types.dart` | `PiHistorySnapshot/Entry/Result`、`PiHistoryGateway/Service`，仅 UI 投影，不构建 LLM 上下文 |
| RPC 安全 | `lib/core/rpc/pi_rpc_client.dart` | `get_entries`、历史写确认验证、超时屏障、迟到结果事件 |
| 状态机 | `lib/ui/features/home/controllers/history_controller.dart` | 每会话加载、预览竞态、过滤折叠、操作、取消、迟到确认 |
| 所有权与草稿 | `lib/ui/features/home/controllers/workbench_controller.dart` | 每会话 HistoryController、草稿恢复、回读聊天/模型、重开原历史、关闭/休眠保护 |
| 窗口 | `lib/ui/features/home/widgets/history_dialog.dart` | 历史树、预览、摘要选项、确认与标签编辑 |
| 入口 | `home_chat_panel.dart`、`chat_message_view.dart` | 标题栏、空态入口、用户消息菜单、回溯后滚动定位 |

复用 `AppDialog`、`AppTreeTile`、`AppSelect`、`AppMenuButton`、`AppTextField`、`AppActionButton`、`AppIconButton`、`AppCard`、`AppMarkdown`、`AppCodeBlock`、`AppImage`、`AppDisclosure`，不新造页面私有装饰组件。文案走中英 ARB，样式与动效沿用 Theme、Motion Tokens、减弱动态设置。

### 数据读取与资源边界

打开历史窗口才通过官方 `get_entries` 读取全部追加记录，包括压缩前内容和不再活动的分支；`leafId` 决定当前路径。窗口只保留文字/拓扑/标签投影，不长期保留每个节点的图片和原始工具详情。选中节点通过公开 `getEntry` 按需读取一份完整预览，迟到的旧预览不会覆盖新选择；关闭窗口释放投影与预览，无轮询或逐 token 全历史刷新。

当前官方 `get_entries` 仍是整包传输，不宣称已经后端分页或消除了超长历史的首次解码成本。树投影是迭代遍历，测试包含 6000 节点；损坏父链／孤立节点有界处理。

消息快捷入口只负责定位预览。会话消息没有原生 entryId，所以仅在当前路径上正文/角色/时间戳的候选唯一时选中预览；歧义时要求手动选节点。真正写操作始终携带 Pi 返回的稳定 `entryId`，从不把界面索引或时间戳当作写入目标。

`get_messages` 仍负责活动聊天，回溯成功后必须权威回读。`PiChatMessage` 同时解析 `branchSummary/compactionSummary.summary`，防止摘要变成空消息。

## 协议

以下 `gui_history_*` 是 **GUI 适配层命令**，都发往所属会话通道，不发到 `control`：

```json
{"type":"get_entries"}
{"type":"gui_history_entry","sessionId":"session-id","entryId":"entry-id"}
{"type":"gui_history_navigate","sessionId":"session-id","leafId":"old-leaf","entryId":"target","summarize":true,"customInstructions":"保留调查结论","replaceInstructions":false}
{"type":"gui_history_label","sessionId":"session-id","leafId":"old-leaf","entryId":"target","label":"已验证"}
{"type":"gui_history_fork","sessionId":"session-id","leafId":"old-leaf","entryId":"user-entry"}
{"type":"gui_history_clone","sessionId":"session-id","leafId":"old-leaf"}
```

操作回应示例：

```json
{"type":"response","id":"gui-1","command":"gui_history_navigate","success":true,"data":{"cancelled":false,"unchanged":false,"editorText":"原提问","images":[{"type":"image","data":"base64...","mimeType":"image/png"}]}}
```

`success:true,cancelled:true` 不是已完成回溯，不能清输入或换本地时间线。

### 公开扩展命令桥

0.86 的 `get_fork_messages` 与实际 `AgentSessionRuntime.fork` 允许任意分支的用户节点（RPC 文档中“活动分支”的描述较窄）；这里以真实接口和探针为准，不人为限制为当前路径。

原生 RPC 有 `get_entries/fork/clone`，但没有 `navigate_tree/set_label` 命令，不能向 `prompt` 直接发送内置 TUI `/tree`。

1. GUI 启动时显式加载 `gui_history.mjs`，注册 `pi-gui-history` 命令。
2. `PiChild.history` 先用官方 `get_commands` 按 **扩展来源路径**查实际命令名，支持名字冲突后的数字后缀。0.86 实际返回 `sourceInfo.path`，也兼容旧 `path`。找不到则拒绝，不让未知斜杠命令掉进 LLM。
3. 通过原生 `prompt` 调用该扩展命令；命令只调用公开上下文 API，不进入 Agent 对话、不生成用户消息。
4. **Pi 0.86 接管 stdout**，扩展不能靠 `process.stdout.write` 发送协议结果。此处用公开 `ctx.ui.setStatus` 携带内部回应，保留键为 `pi-gui-history:adapter-history-N`；`routePiOutput` 在进入普通 UI 路由前按待处理 ID 消费这一专用通道，不显示成徽章。不引入 Pi 私有 output-guard 导入或新的运行时补丁。
5. `session_shutdown` 的 fork/new/resume 在同一保留通道发 reset，转为 `gui_history_session_reset`，清掉旧扩展槽后再接收新运行时的组件。树导航不清掉仍存活的扩展状态。
6. 普通扩展的 setStatus、问答、通知保持原路径。保留通道的损坏回应不能证明写入失败，等待原结果／前端超时屏障；不重发。

## 生产场景修复（1.0.1）

- **构建期通知**：历史弹窗和背后的聊天页面共同订阅同一个 HistoryController。在弹窗 `initState` 同步 `open → refresh → notifyListeners` 会要求正在构建的其他子树重建。现在在首帧结束后、确认仍 mounted 才开始加载，不把这个问题用吞异常掩盖。
- **桥接失败 / 右侧空白**：原版单会话适配器支持历史命令，但生产 `--gui-multiplex` 的 WorkspaceManager 白名单遗漏了它们，返回 `UNKNOWN_COMMAND`；原生 `get_entries` 不经过该限制，所以左树能显示、右预览失败。现在精确放行 entry/navigate/label/fork/clone 五项，不开放任意 `gui_*` 命令。
- 预览失败不再渲染空白，提供本地化说明和重试按钮；开始重试清理旧失败提示，成功后正常显示节点。
- 原独立视觉夹具没有背后聊天的订阅者，原真实探针只走单会话 WorkspaceAdapter，因此未覆盖这两个生产组合。现在 `test/history_lifecycle_test.dart` 专门覆盖父页面订阅、路由挂载和预览失败恢复；它是生命周期/状态回归，不是样式快照。`tool/check_history_rpc.mjs` 默认复制全部七个发布脚本，启动真实 `workspace_rpc.mjs --gui-multiplex`，再从会话逻辑通道走完整历史操作，不再绕过生产路由。

## 验证与启动

```bash
flutter analyze --no-pub
flutter test --no-pub test/history_lifecycle_test.dart test/history_test.dart test/pi_rpc_client_test.dart test/chat_rpc_test.dart test/parallel_session_test.dart
node --test test/history_backend.test.mjs test/workspace_backend.test.mjs test/workspace_manager.test.mjs
node tool/check_history_rpc.mjs
```

- 1.0.1 修复后 `flutter analyze --no-pub` 无问题，Flutter 全套 139 项、相关 Node 21 项通过；复制七个 assets 后的真实 multiplex + Pi 探针通过。未重启或替换活动 GUI。
- 初版曾在临时项目副本以正式 `lib/main.dart` 构建 Windows Release，七个 backend assets 的 SHA-256 与源码一致；该记录仅证明当时构建成功，不代表覆盖了上述生产组合。
- 单元回归聚焦图投影、标签与清除、压缩摘要映射、长直线/孤立节点、预览竞态、取消保留草稿、超时/迟到确认、RPC 写屏障，以及 fork 后原通道和原历史的唯一所有权、旁路会话与新草稿保护。
- 真实 Pi 探针用公开 SessionManager 创建隔离历史与扩展夹具，经发布脚本复制 → multiplex → 所属会话通道 → Pi/扩展，验证节点预览、旧分支、压缩前历史、标签、过期拒绝、扩展取消、自定义摘要、根节点、图片回填、原生 fork/clone、原文件重开、旁路会话不变、replacement 后桥重新加载；**不读用户历史，不调用外部模型**。
- 独立 Windows Debug 应用完整启动后，以 Flutter 指针实际点击过滤、标签编辑、回溯确认与取消，并通过应用内平台键盘事件验证树的方向键选择；走查深浅主题、窄窗和 125% UI 缩放、正文预览，8 张应用自身图层截图，运行时错误为 0。临时夹具仅在临时项目副本，不进入生产代码，不新增纯样式测试。

**新增后端与跨文件注册需正常重启更新后的 GUI 生效，不能只热重载。验证使用独立实例，未关闭或重启承载当前 Agent 的活动窗口。**
