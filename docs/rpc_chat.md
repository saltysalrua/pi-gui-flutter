---
title: "RPC 对话、Markdown 与文件改动"
version: "1.4.0"
status: "implemented"
type: "feature"
tags: [flutter, pi-rpc, chat, markdown, diff]
---

# RPC 对话、Markdown 与文件改动

## 用途与操作

首页现在可以向真实 Pi 发送消息，实时查看回复、思考过程、工具执行和文件编辑记录。

### 两种布局（必须保持）

- **空会话**：保留原来的居中启动卡片，项目名称在卡片上方。不是底部固定输入，也不额外增加欢迎大标题。
- **开始发送后**：同一个输入组件平滑移到底部，上方显示对话时间线。发送被拒且没有产生消息时回到居中。
- **新建空会话**：Pi 确认 `new_session` 成功后，清空当前投影、恢复居中。扩展取消切换时保留原对话。

输入框在布局移动时不重建，其焦点、输入法编辑态和草稿仍由同一组件持有。空态面板最大宽度 760，开始后的面板最大宽度 868（含外边距）；模型浮层继续保持原先 280 宽的紧凑设计。

### 发送与停止

1. 在模型选择器选好 Pi 的模型和思考等级。
2. 输入文字，按 **Enter** 或点击发送。**Shift+Enter** 换行。输入法正在组合文字时不抢走 Enter。
3. 回复过程中可继续写下一条草稿，但不能重复发送。停止按钮代替发送按钮。
4. 点击停止：先通过 `clear_queue` 清掉待执行消息，再 `abort` 等 Pi 停止；清掉的消息追加回草稿，不覆盖用户新输入。
5. 发送明确被拒时保留草稿。确认超时或确认帧损坏时，暂停再次发送，避免重复执行；不会把超时当成进程断线，也不会自动重放 Prompt。
6. 从较早的消息向上查看时不强制跳回底部，可点击“回到最新消息”。

### Markdown 与工具卡片

- Markdown 支持标题、粗体、列表、任务清单、引用、表格、链接、行内代码及 fenced code block。
- 代码块支持语言标签、高亮、横向/纵向滚动和复制。未知语言或较大代码块退回纯文字；复制使用完整源码，不受预览限制。
- 思考过程与工具调用统一为**无外框、无卡片底色的内联折叠行**，使用当前界面背景；思考仍默认折叠，展开后可滚动阅读、选择复制。不显示工具参数 JSON，也不重复显示“已完成”。
- 同一条 AI 消息里，连续的思考与工具步骤用左侧细竖线串起，步骤间距更紧凑；展开后的正文、输出与 Diff 也在同一条线旁。遇到普通正文、图片或消息边界就断开，不重排内容。空的流式文字块不制造多余间隔。
- 思考中的终端颜色码（如 `ESC[38;2;…m`）、OSC 控制序列只在显示时剥除，中文、Markdown 和真实正文保留。未收完整的控制序列暂不显示，下一次累计更新再解析；不修改 RPC 原文或后端历史，也不执行思考中的文字。
- AI 发言标题由模型名改成当前会话中的 **#1、#2、#3…**，按每条 AI 消息递增，包含工具前后的独立发言；不是一轮问答共用一个号。用户消息、工具结果和终端执行不计数，新会话从 #1 开始。模型选择器及后端模型字段不变。
- 标题保留 Pi 的工具名：`read docs/file.md:1-2000`、`edit lib/file.dart`、`write lib/file.dart (行数 · 大小)`；终端使用 `$ 命令`。路径与读取范围用主题色区分，长标题单行省略，悬停查看标题（最多 1,000 字符），完整命令仍在展开区。
- 成功 `read` 默认只有一行；终端和其他工具最多预览 6 行，失败最多预览 3 行；`edit/write` 最多预览 8 行 Diff。仅截短的多行结果显示“展开内容”，短结果不加重复提示。
- 点击标题或“展开内容”切换展开，支持键盘 Enter/Space。展开后可滚动、选择、复制完整输出，并使用文件打开/改动面板图标；文件、工具图片输出仍保留。
- 执行中只在标题旁显示轻量状态，失败/中断用图标和 Tooltip 标记。未知工具走相同的简洁样式，标题提取路径、查询词、URL 等必要信息，不会丢弃结果。
- 输入栏左上角的处理状态、工具的“执行中”和正在生成的“思考过程”统一使用工具原有的文字微光扫描。动画只扫文字，不扫整行；思考收起时也能看到。思考结束或开始输出正文/工具参数时立刻停止，旧思考不动；减弱动态模式全部显示静态文字。
- 内容可以选择复制。网页与本地文件链接只有点击后才通过系统默认程序打开；Markdown 本地/内嵌图片、RPC 图片块可以预览，网络图片需点击后加载。选图、限制与路径规则见 [图片附件与文件链接](images_and_links.md)。

### 文件改动面板与抽屉交互

对话顶部的“文件改动”与“同步对话”按钮靠右对齐。文件改动按钮采用精致纯图标形式（`AppIconButton`），去除长文本标签；当存在改动文件时通过右上角数字角标（`Badge.count`）提示变更数量，悬停展示完整 Tooltip。也可以从时间线中已完成的文件工具卡片直接点击进入。

- **侧边栏式可拖拽抽屉**：展开后采用全高抽屉面板样式（`ColoredBox` 与主题侧边栏底色一致），左侧接入 `AppResizeDivider`，支持左右拖拽调节宽度、双击复位（默认 360px）。
- **流畅动效**：遵循 transitions.dev 动效体系（展开 slow 400ms，收起 medium 350ms，配合 `AppCurves.smoothOut` 减速曲线，拖拽时 60fps 无延迟即时响应）。在极窄屏幕下自适应切换为右侧滑入浮层。
- **改动汇总**：按路径汇总**当前会话成功文件工具调用的编辑记录**，同一文件多次编辑按发生顺序显示。
- 优先显示 Pi 返回的 `details.patch`，支持旧式带行号的 `details.diff`。显示旧/新行号、增删符号和主题适配的背景色。
- `write` 现在由随 GUI 启动的 Pi 扩展补充写入前后 Diff，新建文件显示“新建文件”，覆盖写显示实际增删。时间线和面板复用同一份后端证据。
- 旧历史、取不到基线、文件过大或并发修改无法确认时，显示“没有旧内容”，并复用 Diff 视图展示**中性行号的写入内容**；不伪造新增文件、`+` 行或增删统计。
- 面板不是 Git 工作区扫描，也不是从基线到当前的净 Diff。终端命令产生的文件变化不自动纳入，没有提交、接受、回滚或检查点按钮。

### 会话与恢复

侧栏通过工作区后端的 `gui_list_sessions` 读取当前工作目录的 Pi 历史会话，切换使用 RPC 的 `switch_session`。Flutter 不自行扫描 Pi 私有会话目录。

同一个 Pi 连接中断后，沿用模型控制器的有界重连。聊天控制器恢复有消息的已保存会话，再读取内容，**不重放消息**。尚未落盘的空会话不尝试恢复不存在的文件。读取或恢复失败后仍允许用户明确点击“新对话”开始新的会话；未经确认的写操作尚未结束时除外。

## 架构与代码入口

工具行参考用户给出的 Pi 原版截图及 Pi 0.85.1 的工具 renderer：工具名与目标同一行、简短预览、按需展开；只保留内容，不搬运 TUI 的整块背景和外框。改动面板参考 [VS Code 的改动查看](https://code.visualstudio.com/docs/copilot/chat/review-code-edits)，不照搬其 Git / 检查点后端。协议按本机 Pi 0.85.1 官方 `docs/rpc.md`、`docs/extensions.md` 与工具返回值核对。

| 层 | 路径 | 职责 |
| --- | --- | --- |
| 生命周期 | `lib/ui/features/home/views/home_view.dart` | 唯一 `PiRpcClient`，共享模型控制器、聊天控制器及扩展桥 |
| RPC 服务 | `lib/core/rpc/pi_rpc_client.dart` | JSONL 帧、关联响应、类型映射、写确认屏障、真实断线 |
| 聊天协议 | `lib/core/rpc/pi_chat_types.dart` | `PiChatGateway`、`PiChatMessage`、`PiContent`、`PiContentDelta`、`PiChatEvent`、工具结果及队列 |
| 通用状态 | `lib/core/rpc/pi_rpc_types.dart` | 扩充 `PiSessionState`，连接、会话切换及迟到确认事件 |
| 时间线投影 | `lib/core/models/chat_timeline.dart` | 按内容索引拼接、最终消息替换、toolCallId 关联、历史重建；`assistantNumbers` 按正序生成与消息列表对齐的编号 |
| Diff 解析 | `lib/core/models/diff_document.dart` | patch/带行号 Diff、中性写入后视图；隐藏重复文件头但保留真实内容，无文件 I/O、无补丁执行 |
| write Diff 后端 | `assets/backend/gui_tool_diff.mjs` | 公共 `tool_call/tool_result` 中间件，有限快照、冲突降级、补充结果 details，不接管工具执行 |
| 扩展装载 | `lib/core/rpc/pi_workspace_transport.dart`、`assets/backend/workspace_rpc.mjs` | 发布两个 assets，`PiChild` 以 `--extension` 装载 Diff 观察扩展 |
| 交互状态 | `lib/ui/features/home/controllers/chat_controller.dart` | 发送互斥、停止、恢复、会话书签、改动分组与选择 |
| 主工作区 | `lib/ui/features/home/widgets/home_chat_panel.dart` | 两态布局、时间线、草稿、回到最新、响应式改动面板 |
| 输入组件 | `lib/ui/features/home/widgets/home_starter_panel.dart` | 共用输入卡片、键盘/IME、紧凑模型入口 |
| 消息 | `lib/ui/features/home/widgets/chat_message_view.dart` | 角色/发言编号、Markdown、思考和工具块的有序渲染，连续步骤分组 |
| 显示文本 | `lib/core/utils/terminal_text.dart` | `stripTerminalControls` 线性扫描 CSI/OSC/控制字符串，兼容流式半截序列，仅在思考显示入口使用 |
| 工具注册表 | `lib/ui/features/home/widgets/tool_card_registry.dart` | `ToolCardRegistry.register` / `unregister`，默认回退与共享 `ToolChangeDetails` |
| 改动面板 | `lib/ui/features/home/widgets/chat_changes_panel.dart` | 按文件选择编辑记录、展示 Diff/写入内容 |

连续步骤参考 [Vercel AI Elements 的 Chain of Thought](https://elements.ai-sdk.dev/components/chain-of-thought)：内联折叠步骤加左侧竖线；不增加新的交互层级，也不接管工具注册表。

公共原子库新增：

- `AppComposerLayout`：同一布局过程测量输入区高度并移动位置，时间线不会被多行输入覆盖。
- `AppMarkdown`、`AppCodeBlock`、`AppDiffView`：主题化的 Markdown、代码及 Diff。后两者提供 `framed: false` / `previewLines`，预览没有嵌套卡片和滚动；完整内容按需构建。`AppDiffView(written: true)` 模式只显示本次写入和新行号，不能当成 Diff 统计。
- `AppDisclosure`：`framed: false`、`titleContent`、`trailing`、`previewBuilder/previewHint` 支持内联折叠；展开仍延迟构建，旋转箭头与尺寸变化复用 Motion Tokens。使用带类型的独立 PageStorage 标识，**不能把 bool 写进 ScrollPosition 的默认 double 存储位置**。
- `AppStepGroup`（`lib/ui/atoms/app_step_group.dart`）：只接收 Widget 列表，绘制主题边框色的细竖线及紧凑间距；不依赖聊天/RPC，不添加背景，不拦截点击，线高随折叠内容真实布局变化。第三方工具 renderer 原样放入，不丢注册能力。
- `AppDisclosure` 在减弱动态模式直接绘制正文，不使用零时长 `AnimatedSize`；避免 Flutter beta 在改变宽度时发生布局期间重入，折叠状态仍由原 State/PageStorage 保存。
- `AppActionButton.labelContent`：复用原有 Hover、Focus、Disabled 和键盘状态，允许富文本标题；纯文本 `label` 保留无障碍名称。
- `AppCopyButton`：复制反馈。
- `AppActivityLabel`（`lib/ui/atoms/app_activity_label.dart`）：三处共用的非阻断文字微光，保持工具原有渐变与 `AppDurations.verySlow * 3` 线性周期。内部 Align 松开父布局的最小宽度，让 ShaderMask 始终贴合文字，避免输入栏的 stretch Column 拉长扫描范围。`style/maxLines` 允许标题保留原排版；流式重建不重复启动已运行的 AnimationController，停止/减弱动态时不创建 ShaderMask。

继续复用 `AppCard`、`AppTextField`、`AppActionButton`、`AppIconButton`、`AppNavTile`、`SlotContainer`。`AppTextField` 增加 focusNode/minLines/多行及无边框模式；图标按钮补齐键盘触发和焦点边框；通用操作按钮的高度改为下限以适配系统字号。代码字体由 `AppTheme.codeStyle` 提供。

动画使用 Motion Tokens，并检测 `MediaQuery.disableAnimationsOf(context)`。流事件以 stagger 时间窗合并通知，最终状态立即刷新。工具输出预览上限 60,000 字符；小于等于 12,000 字符且明确指定语言的代码才尝试高亮，避免对大量终端输出做语言猜测。Diff 行列表按需构建。

## RPC 命令与数据

### 命令

```json
{"id":"gui-1","type":"get_state"}
{"id":"gui-2","type":"get_messages"}
{"id":"gui-3","type":"prompt","message":"请检查这个项目"}
{"id":"gui-4","type":"clear_queue"}
{"id":"gui-5","type":"abort"}
{"id":"gui-6","type":"new_session"}
{"id":"gui-7","type":"switch_session","sessionPath":"/path/from/pi/session.jsonl"}
```

`prompt` 的成功响应仅表示**接受/处理**，不是回复结束。扩展命令可能没有 Agent 回复，因此接受后若没有运行中的 Agent，会读取状态同步。

### 流式消息

```json
{"type":"message_start","message":{"role":"assistant","content":[],"timestamp":1}}
{"type":"message_update","assistantMessageEvent":{"type":"text_delta","contentIndex":0,"delta":"## 结果\n"}}
{"type":"message_update","assistantMessageEvent":{"type":"text_delta","contentIndex":0,"delta":"已经完成。"}}
{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"## 结果\n已经完成。"}],"timestamp":1,"stopReason":"stop"}}
{"type":"agent_end","willRetry":false}
{"type":"agent_settled"}
```

- 0.85.1 的 `message_update` 没有累计 `message`，按 `contentIndex` 拼装文字、thinking 与 toolcall；`message_end.message` 才是最终权威内容。
- `agent_end` 可能后接重试、压缩或续跑。只有 `agent_settled` 或已确认的 `abort` 才解除运行锁。
- `auto_retry_start/end`、`compaction_start/end` 及摘要重试有独立状态。手动压缩结束后可通过状态查询回到空闲。
- `get_messages` 与实时事件竞态时，不能覆盖更晚的流式内容；运行中保留本地投影，settled 后重新同步历史。
- 历史工具结果按 toolCallId 合并，不额外制造重复消息。没有前置工具调用的历史结果仍有可见的回退卡片。

### 思考动画的启停

这是现有 RPC 事件的 UI 状态投影，不增加 RPC 命令或修改后端。`ChatTimeline.thinkingIndexFor(messageIndex)` 仅返回当前消息正在生成的思考块索引，由 `HomeChatPanel` 传入 `ChatMessageView.thinkingIndex`；标题复用 `AppActivityLabel`，不能只看 `message.isStreaming` 让整条消息中的旧思考一直播放。

| 事件 | 思考动画 |
| --- | --- |
| `message_update` 的 `thinking_start/thinking_delta` | 开启对应 contentIndex；缺少 message_start 时也沿用原消息回退投影 |
| `thinking_end` | 关闭相同索引；旧块的迟到 end 不关闭新块 |
| `text_start/delta/end` 或 `toolcall_start/delta/end` | 停止；缺少 thinking_end 时也不会一直播放 |
| `message_start/message_end`、`agent_settled`、历史 load | 清空当前指示；停止/报错的最终消息与旧历史都不播放 |

`message.isStreaming` 继续作为消息级保护，`agent_settled` 解除操作锁的规则不变。工具“执行中”的启停仍由 `ToolPhase` 控制，输入栏仍由原有 ChatController 运行/读取/发送状态控制。

### 发言编号与显示投影

编号是 GUI 显示值，不是 Pi 的持久消息 ID。`HomeChatPanel` 在创建倒序 ListView 前读取一次 `ChatTimeline.assistantNumbers`，通过正序索引传给 `ChatMessageView.assistantNumber`；不能在惰性 `itemBuilder` 中递增计数。`message_update` / `message_end` 不增加号，历史内容不变时重新读取编号不变。若压缩/分支切换改变了可见历史，则按 Pi 返回的当前历史重新编号。

```text
messages.role:     toolResult, user, assistant, assistant, user, assistant
assistantNumbers: null,       null, 1,         2,         null, 3
```

没有前置调用的工具结果仍回退为可见工具块，但投影保持 `role: toolResult`，不冒充 AI 发言挤占编号。思考样例 `"\u001b[38;2;138;190;183mThinking:\u001b[39m content"` 显示为 `Thinking: content`，控制码不会参与 Markdown 解析。

### 工具结果与 Diff

```json
{
  "type":"tool_execution_end",
  "toolCallId":"call-1",
  "toolName":"edit",
  "isError":false,
  "result":{
    "content":[{"type":"text","text":"Successfully replaced 1 block(s)."}],
    "details":{
      "patch":"--- sample.txt\n+++ sample.txt\n@@ -1 +1 @@\n-before\n+after\n",
      "diff":"-1 before\n+1 after",
      "firstChangedLine":1
    }
  }
}
```

`tool_execution_start.args` 提供文件路径/命令参数。`tool_execution_update.partialResult` 是**累计输出**，必须整体替换，不能追加成重复文本。

### write Diff 的后端边界

原生 Pi `write` 只返回成功文字，没有旧内容。`gui_tool_diff.mjs` 通过公开扩展事件在 `tool_call` 记录目标文件，在成功 `tool_result` 确认磁盘内容与实际写入参数一致后，用 Pi 自带的 jsdiff 生成 patch：

```json
{"content":[{"type":"text","text":"Successfully wrote to note.txt"}],"details":{"patch":"--- note.txt\n+++ note.txt\n@@ -1 +1 @@\n-before\n+after\n","guiWrite":{"kind":"modified"}}}
```

- `guiWrite.kind` 为 `created/modified/unchanged`，由 `PiToolResult.writeKind` 映射为 `PiWriteKind`。Widget 不解析这段原始 Map。
- **不注册同名工具、不覆盖权限扩展、不修改参数或输出文字**；已有 `details.patch/diff` 优先，其他 details 字段保留。Diff 随 Pi 自己的工具结果持久化，历史仍从 `get_messages` 读取。
- 每份文件最多 256 KiB，只接受普通 UTF-8 文本；累计旧内容最多 4 MiB、patch 最多 512 KiB、Diff 计算预算 100ms。拒绝二进制、设备/共享路径/数据流；采集或解析失败不影响真正的写入结果。
- 同批同路径（含可解析别名）的 write/edit，或同时出现 shell/未知非只读工具时，放弃不可靠的对比。写入参数被其他扩展改动、写后内容不符、失败/中断、会话已切换时同样不补 Diff。快照在执行结束、`agent_settled` 和 `session_shutdown` 清理。
- 这是一次工具调用前后**观察到的文件内容**，不是文件锁、Git 基线或跨进程修改追踪；其他程序的并发写入无法保证归因。不为旧历史事后读取当前磁盘来冒充旧内容。
- 扩展与适配脚本在 GUI 启动时解包。开发时 UI 可热重载，但新后端采集器要等下次启动 GUI 才会装载；不要为了视觉验证重启承载当前 Agent 会话的 Pi 进程。

### 故障边界

- 旁路 stdout、单条坏事件与超时均不主动杀 Pi，遵循已有传输层约束。
- `prompt/new_session/switch_session` 超时保留未确认屏障；损坏的聊天写确认同样按结果未知处理。新聊天写不能越过它，读取和停止仍可用。
- 迟到确认派发 `PiRpcConversationSettled`，只回读，不重新发送。会话切换确认派发 `PiRpcSessionChanged`，模型选择器重新读取模型/等级。
- `clear_queue/abort` 不等待模型选择写入屏障，停止路径不会被未确认的模型选择卡住。
- 顶层错误提示使用本地化的人话，不直接输出原始异常堆栈。原始工具返回仍可在明确展开的输出区域查看。

## 加载性能与验证方式

仍采用 Flutter/Dart → Node 适配层 → Pi RPC，不引入 Rust、不直接解析 Pi 私有历史，也不改变空会话居中 / 有消息底部输入的两态布局。

- **按数据块分帧**：`lib/core/rpc/pi_rpc_transport.dart` 的 `decodePiJsonl` 只扫描当前 UTF-8 解码块，把未结束的一行放入 `StringBuffer`；遇到 LF 才合并。`assets/backend/workspace_rpc.mjs` 的 `lines` 同样用片段数组处理，避免大 `get_messages` 每收到一块就复制、重扫整个前缀。LF/CRLF、跨块 UTF-8、U+2028/U+2029、空行行为不变；Dart 保留原来的 EOF 尾行读取行为，Node 仍只派发完整 LF 帧。
- **Node 只解码一次**：`routePiOutput` 把解析结果一并交给 `WorkspaceAdapter` 做响应关联和运行状态维护，公开输出仍转发原始 JSON 行，不二次解析或重新序列化。内部探测响应不外泄，未知事件、旁路文字和坏行继续交给 Dart 隔离，`agent_end` 仍不解除运行锁。
- **工具引用索引**：`lib/core/models/chat_timeline.dart` 用 `toolCallId → 可见引用数` 判断结果是否已有消息引用，避免每个工具结果都扫描全部前文。最终消息替换、内容块替换、历史重载会维护/清空引用数；不能使用只增不减的 Set，否则被最终消息删除的草稿工具会错误隐藏后续孤立结果。流式更新只维护变化的内容块，不反复登记整条消息的工具。孤立结果、编号、累计输出与 Diff 证据保持原行为。
- **摘要缓存与加载调度**：见 [工作区历史缓存](workspaces_sessions.md#历史缓存与加载顺序)。消息本身不做跨会话缓存，不绕过 Pi 的当前分支/压缩投影。

用纯合成数据运行分段探针，不启动 Pi、不读用户历史、不消耗模型额度：

```bash
dart run tool/check_session_performance.dart
# 可选：指定每组工具调用数；默认 1000 和 5000
dart run tool/check_session_performance.dart 1000 5000
```

探针分别记录 JSONL 分帧、`jsonDecode`、强类型映射与时间线重建；预热后取 5 次中位数，不设置易波动的耗时测试阈值。对比前版本 `1685e2f` 与本次代码时，在独立临时目录放置相同探针和对应的纯 Dart 文件，本机 Dart JIT 的一轮结果如下：

| 合成数据 | 阶段 | 修改前 | 修改后 |
| --- | --- | --- | --- |
| 5,000 次工具调用 / 10,000 条记录，约 3.75 MiB | Dart JSONL 分帧（64 KiB 块） | 200.1 ms | 14.8 ms |
| 同上 | 时间线重建 | 437.5 ms | 3.8 ms |

这不是 GUI 首帧或整个会话切换耗时。另一次通过官方 SDK **只读**测量本项目 23 个会话，强制扫描约 179–231 ms，适配层缓存命中约 0.01 ms；此值不含 SDK 导入、IPC 和界面渲染。

本次未改变 SDK 冷启动、`get_messages` 整包传输、Dart 主 isolate 的整包 JSON 解码或 Markdown 渲染。上述大样本的 `jsonDecode` 仍约 57 ms；若继续优化超长会话，应针对真实 GUI 的分段/帧耗时评估后台 isolate 或官方分页接口，不能把合成测试结果宣传成整个页面“瞬间加载”。

回归集中在 `test/pi_rpc_client_test.dart` 的大帧/UTF-8/尾行与协议隔离，`test/chat_rpc_test.dart` 的草稿/最终引用替换、重复引用、孤立结果与重载，以及工作区文档列出的缓存状态机。验证全程不热重启或切换当前活动聊天，新后端资源在下次正常启动更新后的 GUI 时装载。

## 扩展槽位

`aboveEditor/belowEditor` 跟随同一个输入组件；`statusBar` 占据布局底部，不再覆盖输入；`dialogOverlay/notificationToast` 继续使用原扩展桥。改动面板保留 `sidebarPanel` 插槽。时间线通过工具注册表分派，未知工具走通用渲染器。

## 验证

```bash
flutter analyze
flutter test
# 真实 RPC，无模型请求：新建隔离空会话、读状态/消息、清队列与停止
dart run tool/check_chat_rpc.dart
# 原生 Pi write + 扩展事件回归：临时文件、无模型请求
node tool/check_tool_diff.mjs
# 可选端到端：真实 Pi RPC + 本地固定 SSE 响应，不访问外部模型
node tool/check_tool_diff.mjs --rpc
# 真实适配层/会话生命周期，包含随 GUI 装载的扩展
node tool/check_workspace_rpc.mjs
# 显式允许一次模型请求：只编辑临时目录里的 sample.txt，验证流事件与真实 Diff
dart run tool/check_chat_rpc.dart --with-model
```

`--with-model` 会消耗少量模型额度。探针使用独立的无持久化会话、关闭扩展/技能，临时目录在 finally 中清理；不编辑项目文件，也不改变 GUI 进程的模型选择。无参数运行不调用模型。

核心测试在 `test/chat_rpc_test.dart`：内容块拼接、最终替换、工具累计输出、Diff 行号/统计、write patch/元数据的实时和历史映射、无基线行号（含空文本/CRLF）、坏事件隔离、写确认未知、停止优先级、重试状态、历史竞态、恢复与取消切换。`tool/check_tool_diff.mjs` 使用真实原生 write 验证新建/覆盖写、patch 往返、空文件/BOM/CRLF、保留扩展 details、并发 write/edit/shell、失败/参数改动/写后不符/会话清理、大小和二进制降级。加 `--rpc` 使用仅绑定 127.0.0.1 的固定 SSE 响应驱动真实 Pi：并行新建/覆盖写、CLI 扩展装载、实时 patch、切换会话后持久历史恢复；Pi 配置与会话完全隔离在临时目录，不访问外部模型、不消耗模型额度。无纯展示 Widget 测试。

编号回归包含实时起始/增量/结束、工具结果关联、孤立工具结果、历史重载和新会话归零。`test/terminal_text_test.dart` 验证用户提供的 true-color 样例、OSC 超链接、C1 控制码、逐字符拆开的流式序列，以及中文/emoji/Markdown/字面转义文本不丢失；与聊天核心测试合计 19 项通过。新增思考状态回归覆盖块开始/增量/结束、转正文/工具、多块/跨消息、最终停止/报错、settled 与历史重载。

思考与连接线本次真机走查覆盖浅色 820px/110% 字号、深色 370px/150% 字号、思考展开收起、工具/Diff 预览、正文断线和 #1/#2。窄宽度同时开启减弱动态，修复零时长 `AnimatedSize` 断言后重复展开收起，运行时无异常。使用独立 Dialog 和其 `RenderRepaintBoundary.toImage` 截图，不覆盖活动时间线、不重启 Pi；预览代码结束后移除并热重载。

统一动画的独立真机预览同时渲染 stretch Column 状态、工具状态与实时/历史思考。实测相同“执行中”文字两处 ShaderMask 与文字宽度均为约 43.85，连续两帧可见相同扫描效果；thinking_end 后消息仍 streaming，但思考 ShaderMask 已移除，历史思考始终静止；减弱动态时所有 ShaderMask 移除，运行时无异常。预览代码已清理并热重载，不修改活动会话。

桌面验证采用真实 Windows 应用：空态/开始态、新建会话、Enter/Shift+Enter、Markdown 表格/代码、工具折叠、改动覆盖/停靠布局与亮暗主题。展示内容用运行时临时预览注入；不混入生产代码或 Pi 持久历史。另有一次真实 GUI 无工具回复及真实模型临时文件编辑探针。

内联工具的真机视觉走查覆盖亮/暗主题、868px 与 370px 宽度、110%/150% 字号、read/write 展开收起、失败/执行中、无旧内容和减弱动态。预览使用临时独立 Dialog，不覆盖当前聊天；截图通过 VM inspector 定向获取，预览代码结束后移除。

## 当前边界

暂不包含 LaTeX/Mermaid、Git 净改动扫描、编辑审批/回滚及执行中的插队发送。图片上传/预览与文件链接已接入，见 [图片附件与文件链接](images_and_links.md)；历史会话列表由工作区后端提供。已有扩展弹窗仍由 Pi 的 extension_ui 机制处理，不由 Flutter 重写权限或 Agent 逻辑。
