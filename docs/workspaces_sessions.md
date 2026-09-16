---
title: "工作区、历史会话与 Git Worktree"
version: "1.2.0"
status: "implemented"
type: "feature"
tags: [flutter, pi-rpc, session, workspace, git-worktree]
---

# 工作区、历史会话与 Git Worktree

## 用途与入口

侧栏现在读取**当前执行目录的真实 Pi 历史**，不再只记住本次 GUI 启动打开过的会话。点击历史项，使用 Pi RPC 打开并读取消息；列表支持按标题或会话 ID 搜索，悬停查看时间、消息数和文件路径。

- **切换工作区**：点击侧栏项目名或项目列表右侧的 `+`，打开已有文件夹，或选择最近使用的目录。
- **新建工作区**：在选择工作区窗口点击“新建工作区”，选择父目录并输入文件夹名称，再点“创建并打开”。只创建一个空文件夹，不自动初始化 Git，也不覆盖已有文件夹。
- **选择 Worktree**：点击项目名下面的分支行，查看当前仓库已有的 Worktree。点击一项后，Pi 的实际工作目录也会随之切换。
- **创建 Worktree**：在 Worktree 窗口点击“新建 Worktree”，填写新分支名并选择 HEAD 或本地分支作为基线。仓库必须至少有一次提交。
- **移除 Worktree**：点击条目右侧的移除按钮，核对确认页中的完整目录路径后确认。只移除工作目录，保留 Git 分支和 Pi 历史。
- **刷新**：项目列表右侧刷新按钮重新读取工作区、Git 信息和历史；不会发送 Prompt。

切换工作目录后从空会话开始，旧会话仍可在原目录的历史列表中打开。最近使用的目录与当前目录会保存，重启 GUI 优先打开上次的目录；目录已移动或删除时退回启动目录。尚未落盘的空会话不会伪装成历史记录。

空会话仍使用居中输入卡片，有消息后才进入底部输入布局。目录间切换保留本次运行的各目录草稿，不自动发送；模型选择器继续采用原有的 280px 紧凑布局。

## 贴近入口的小卡片

项目与 Worktree 现在使用局部浮窗，不占满窗口，也不固定弹到屏幕中央：

- 点击项目名、项目旁的 `+` 或分支行，卡片优先紧贴**实际点击的入口右侧**，间隔 8 逻辑像素；右侧不足时尝试左侧，再选择上方或下方并避开窗口边缘。
- 卡片最大宽度 **400px**、高度 **480px**，短内容自然收缩。小窗口会进一步限制到入口上下的可用空间，四周至少留 16px；极矮视口优先保留可操作空间。
- 新建、Worktree 列表和移除确认在同一张卡片内切换，继续使用最初入口作为锚点。长列表 / 表单内部滚动，底部关闭、返回与确认按钮保留；目录路径仍可通过 Tooltip 或确认页查看。
- 遮罩减淡为主题 scrim 的 12%，仍是模态交互，不允许点穿操作底下的聊天。目录选择继续使用系统文件夹窗口，忙碌期间的关闭保护不变。
- 窗口缩放或 UI 比例变化时重新测量入口，不重建表单。布局结束后再核对一次位置，处理入口比浮窗更晚布局的情况；无可见入口时回退至左上角，而不是误用隐藏页面的坐标。

实现复用 `AppDialog(anchorKey, placement: AppDialogPlacement.beside)`。`HomeSidebar` 分别给三个入口保存 `GlobalKey`，经 `HomeView._chooseWorkspace` 传给 `WorkspaceDialog`；`showAppDialog(anchored: true)` 只做路由淡入淡出，卡片在自身位置轻微缩放，避免从整屏中心飞入。位置、尺寸和阴影都属于 UI，不增加 RPC，也不更改创建 / 切换 / 删除行为。

本轮仅调整项目 / Worktree 与扩展问答。**设置保持整页，图片 lightbox 保持全屏**，模型选择器与 Diff 面板布局不变。问答卡片见 [扩展槽位](extension_ui_slots.md#问答小卡片)。参考 [VS Code Quick Picks](https://code.visualstudio.com/api/ux-guidelines/quick-picks) 的紧凑选择及多步输入方式。

## Worktree 的安全边界

参考 [Codex 的项目与 Worktree 工作方式](https://learn.chatgpt.com/codex/environments/git-worktrees)，采用明确创建、手动选择和确认移除，不实现自动 Handoff。

- 创建使用 `git worktree add -b`，从已校验的提交建立新分支，不使用 `--force`。
- 新目录默认位于当前 checkout 的同级目录 `<checkout 名称>.worktrees/<规范化分支名称>`。确认表单会显示存放位置；同名目录存在时拒绝，不覆盖。
- 原目录的未提交、未跟踪和忽略文件**不会复制**。新 Worktree 可能需要自行安装依赖或配置环境。
- 不在原目录执行 checkout/reset/stash，不自动提交、合并、推送或删除分支。
- 主 checkout、当前 Pi 使用的 checkout（包括从子目录启动的情况）、锁定或失效的 Worktree 不能移除。
- 移除前重新读取真实 Git 状态。未提交、未跟踪、**忽略文件**均阻止移除，避免把 `.env` 或本地数据一起删除。Git 本身拒绝的情况也不会强制处理。
- 创建成功但启动 Pi 失败时，新目录仍然保留，并提示从最近使用中重开；不通过自动删除“回滚”用户文件。
- Agent 运行、压缩、排队、聊天切换或模型写入期间不允许工作区写操作。后端也检查状态，不能仅靠按钮禁用。
- 请求超时不证明操作失败。写请求保留待确认屏障，不自动重试创建、切换或移除；迟到确认只触发回读。

## 架构与安装要求

Pi 0.85.1 的原生 RPC 有 `switch_session/get_messages`，但没有历史目录枚举、改变 cwd 或管理 Worktree 的命令，因此新增一个**本地 JSONL 适配层**，而非在 Flutter 重写 Agent。

```text
HomeView（唯一 PiRpcClient）
  ├─ ModelPickerController
  ├─ ChatController
  ├─ WorkspaceController
  └─ PiExtensionUiBridge
          │ stdin/stdout strict JSONL
          ▼
assets/backend/workspace_rpc.mjs（Node.js）
  ├─ 官方 SessionManager.list(cwd)：读取历史摘要
  ├─ 文件夹 / Git / GUI 自有最近使用列表
  └─ 唯一 pi --mode rpc 子进程：模型、会话内容、Agent、工具、扩展
```

需要 PATH 中的 **Node.js**，以及 npm 安装的 `@earendil-works/pi-coding-agent`。Worktree 另外需要 Git。适配层通过本地模块解析和 PATH 中的 npm 安装位置定位官方包；特殊安装位置可以设置 `PI_GUI_PI_PACKAGE_DIR` 指向该包目录。纯独立 Pi 二进制不提供所需的 JS SDK，当前不能代替 npm 包。

GUI 以 Flutter asset 携带 `workspace_rpc.mjs` 和 `gui_tool_diff.mjs`，启动时复制到同一独立临时目录，不依赖从源码仓库目录启动。`PiChild` 使用 `--extension` 装载 write Diff 观察扩展，并通过 `PI_GUI_PI_PACKAGE_ROOT` 告诉它当前 Pi 包位置以复用 jsdiff；扩展只补充工具结果证据，不替换用户工具。详见 [工具调用与 write Diff](rpc_chat.md#write-diff-的后端边界)。Windows 通过 Node 直接启动包的 CLI，不把路径或分支拼进 shell 命令。关闭窗口清理 GUI 自己启动的进程树和临时脚本，不影响用户独立启动的 Pi。

最近使用列表写入 **GUI 自有文件**：Windows `%APPDATA%/pi-gui/workspaces.json`；其他系统使用 `$XDG_CONFIG_HOME/pi-gui/workspaces.json` 或 `~/.config/pi-gui/workspaces.json`。可用 `PI_GUI_WORKSPACE_STORE` 覆盖，方便隔离验证。该文件不是 Pi 配置。保存失败会提示，不把已完成的文件操作误报为失败。

Flutter 不扫描、解析或改写 Pi 私有会话文件。适配层通过官方 SDK 读取摘要，会话内容仍使用官方 RPC；`get_messages` 返回 Pi 当前活动分支/压缩后的投影，不是自行拼接所有树分支的原始日志。

### 历史缓存与加载顺序

重复打开或刷新侧栏时，适配层会短暂复用**当前目录的官方会话摘要**，不再每次都重扫全部历史。缓存只存在于内存，不写新数据库，也不缓存消息正文或 SDK 的 `allMessagesText`。首次读取、失效或过期后的读取仍走 `SessionManager.list(cwd)`。

- `WorkspaceService.listSessions({force})`：只保留一份当前目录摘要，有效期 **5 秒**，从扫描完成时起算；同目录、同版本的并发请求共用扫描。该时间不是轮询间隔，不会每 5 秒自动读磁盘。
- `WorkspaceAdapter` 在 `message_end`、`agent_settled`、`compaction_end`、成功的非 `get_*` 转发命令确认后使缓存失效；新 Pi 启动（包括工作区切换及恢复）也失效。未知扩展写命令和迟到确认按同样规则处理，读状态/模型目录不会清缓存。
- 旧版本、旧工作区的扫描即使晚到，也不能覆盖新缓存；失败不缓存，也不能回退成“旧数据就是刷新成功”。
- 项目旁的**刷新按钮**通过 `WorkspaceController.refresh(forceSessions: true, loadConversation: false)` 强制读取，保留原来的 Git 刷新和“不发 Prompt”行为。外部终端改变历史时可用它立即回读；否则在下一次缓存过期后的读取中发现变化，不承诺后台自动同步。
- Flutter 的 `refreshSessions()` 合并同时到来的读请求；读取途中有目录/会话变化或手动刷新时，追加一次最新读取，所有等待者等到它结束，不显示已过期的中间结果。聊天结束后即使标题没变，也会更新列表时间和消息数。
- `WorkspaceController.refresh/_change` 在工作区已确认后并行读取侧栏摘要与当前对话，不再让摘要扫描挡住 `get_messages`。对话恢复和模型回读仍保持原先顺序；操作锁、迟到确认、取消切换与失败恢复逻辑不变。

协议仅给已有命令增加可选字段，省略时允许命中缓存：

```json
{"id":"gui-refresh","type":"gui_list_sessions","force":true}
```

代码入口：`assets/backend/workspace_rpc.mjs` 的 `WorkspaceService` / `WorkspaceAdapter`，`lib/core/rpc/pi_workspace_types.dart` 的 `PiWorkspaceGateway.listSessions({force})`，`lib/core/rpc/pi_rpc_client.dart`，以及 `lib/ui/features/home/controllers/workspace_controller.dart`。JSONL 分帧和时间线索引的优化见 [聊天加载性能](rpc_chat.md#加载性能与验证方式)。

这些后端修改随应用资源装载，需下次正常启动更新后的 GUI 才生效；不要为了验证而重启承载当前 Agent 的窗口。

### 切换生命周期

1. 前端锁住聊天与模型写入，后端检查运行、压缩和待执行状态。
2. 记住原目录和已保存会话引用，停止旧 Pi 并确认退出，才启动新 Pi。
3. 新 Pi 确认就绪后发送 `gui_workspace_changed`，前端清除旧投影并重新读取消息、模型与历史。
4. 新进程启动失败时尝试回到原目录及已保存会话，不重放 Prompt。恢复也失败则通过真实断开进入重连流程。
5. `gui_workspace_reset` 在新进程启动前清除旧扩展槽位；不能在新进程已经发布组件后清理。

扩展弹窗/通知槽位放在 `MaterialApp.builder`、Navigator 路由之上，因此启动扩展的确认不会被工作区弹窗挡住。适配层在启动阶段也接收 `extension_ui_response`；用户交互等待不因内部读超时而杀掉 Pi。

## 代码入口

| 层 | 路径 | 职责 |
| --- | --- | --- |
| 本地适配层 | `assets/backend/workspace_rpc.mjs` | `WorkspaceService`、`WorkspaceAdapter`、`PiChild`；SDK、Git、单进程切换 |
| Asset 传输 | `lib/core/rpc/pi_workspace_transport.dart` | 装载随应用发布的适配脚本和 Diff 扩展、启动及清理 |
| 强类型协议 | `lib/core/rpc/pi_workspace_types.dart` | 工作区快照、会话摘要、Git/Worktree 数据与 Gateway |
| RPC 服务 | `lib/core/rpc/pi_rpc_client.dart` | `gui_*` 请求关联与写确认屏障 |
| 协调状态 | `lib/ui/features/home/controllers/workspace_controller.dart` | 切换互斥、历史刷新、过期结果隔离、错误码 |
| 会话投影 | `lib/ui/features/home/controllers/chat_controller.dart` | 目录确认后清空旧投影，再通过 RPC 读取 |
| 侧栏 | `lib/ui/features/home/widgets/home_sidebar.dart` | 真实历史、搜索、工作区与 Worktree 入口 |
| 操作界面 | `lib/ui/features/home/widgets/workspace_dialog.dart` | 系统文件夹选择、创建表单、Worktree 列表、移除确认 |
| 公共模态 | `lib/ui/atoms/app_dialog.dart` | 滚动边界、焦点、开关过渡、减弱动态 |
| 本地化错误 | `lib/ui/features/home/workspace_labels.dart` | 后端错误码映射为可执行的人话提示 |
| 生命周期 | `lib/ui/features/home/views/home_view.dart` | 唯一客户端、共享 Controller、按目录保留草稿 |

复用 `AppCard/AppNavTile/AppTextField/AppActionButton/AppIconButton/SlotContainer`，新增的 `AppDialog` 是公共原子。新增文字在 `app_zh.arb/app_en.arb`，动效使用现有 Motion Tokens。

## 协议示例

```json
{"id":"gui-1","type":"gui_get_workspace"}
{"id":"gui-2","type":"gui_list_sessions"}
{"id":"gui-3","type":"gui_open_workspace","path":"D:/Code/project"}
{"id":"gui-4","type":"gui_create_workspace","parent":"D:/Code","name":"new-project"}
{"id":"gui-5","type":"gui_create_worktree","branch":"feature/ui","baseRef":"main"}
{"id":"gui-6","type":"gui_remove_worktree","path":"D:/Code/project.worktrees/feature-ui"}
```

创建只返回已创建的路径；前端确认后续 `gui_open_workspace`，让“创建成功但打开失败”有明确边界。移除返回已移除的路径，不切换会话。

```json
{"type":"response","id":"gui-2","command":"gui_list_sessions","success":true,"data":{"sessions":[{"path":".../session.jsonl","id":"session-id","cwd":"D:/Code/project","title":"检查项目","modified":"2026-01-01T12:00:00.000Z","messageCount":8}]}}
{"type":"gui_workspace_reset"}
{"type":"gui_workspace_changed","path":"D:/Code/project"}
{"type":"response","id":"gui-6","command":"gui_remove_worktree","success":false,"error":"WORKTREE_DIRTY"}
```

摘要按修改时间降序，不把 SDK 的 `allMessagesText` 或密钥发送到列表。Git Worktree 用 `--porcelain -z` 解析，保留带空格、引号、换行或 Unicode 的路径。读操作与目录切换发生竞态时，旧目录的响应不能覆盖新目录列表。

## 验证

```bash
flutter analyze
flutter test
node --test test/workspace_backend.test.mjs
node tool/check_workspace_rpc.mjs
```

- Dart 核心回归：类型映射、坏历史隔离、目录写超时屏障、切换互斥、确认前保留投影、失败后保留原目录。
- Node 核心回归：真实临时 Git 仓库中的创建、源目录未提交改动不变、Unicode/空格、错误基线/分支、未提交/忽略文件与锁定删除保护、保留分支、失败切换恢复。
- 真实 Pi 探针：在临时配置目录用官方 SDK 创建测试会话；RPC 发现、摘要缓存命中、通过 SDK 模拟外部改名后强制刷新、读取、切换空目录、执行只读 cwd 检查、恢复历史；同时只存在一个 Pi 子进程。**不发送模型请求，不改用户历史或当前项目。**
- 缓存/竞态回归：`test/workspace_backend.test.mjs` 覆盖合并扫描、时钟推进过期、强制刷新、失败重试、旧扫描晚到、工作区隔离及事件失效；`test/workspace_rpc_test.dart` 覆盖前端读合并、强制尾随读取、过期结果隔离、聊天不被侧栏读取阻塞，以及标题不变时的 settled 刷新。

UI 通过 Windows 真机启动与操作走查验证，不增加纯展示型 Widget 测试。

小卡片改动使用安全热重载与隔离 QA 浮层检查：1040×650 下 Worktree 长列表实际为 400×480，位于入口右侧 8px；560×400、150% 文字下新建 Worktree 卡片为 400×260，翻到入口下方，底部操作仍可见。使用生产 Widget 与离线 Controller，不执行真实创建、切换或移除，不接入活动聊天。临时 QA 入口验证后移除并热重载回生产代码；`flutter analyze --no-pub` 无问题，`workspace_rpc_test.dart` 与 `pi_rpc_client_test.dart` 共 11 项回归通过，生产热重载后无运行时错误。

## 当前不包含

跨目录聚合搜索、远程工作区、分支合并/推送、会话删除、自动搬运未提交文件、自动安装依赖、并行运行多个 Pi，以及跨应用实例的 Worktree 占用锁。外部终端或其他 GUI 实例正在使用的目录，无法只靠本 GUI 的运行状态判断，移除前应自行确认；Git 的锁定机制仍会被遵守。
