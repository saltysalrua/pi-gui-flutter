---
title: "RPC 对话、Markdown 与文件改动"
version: "1.9.0"
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
- **新建空会话**：并行工作区通过 `gui_open_channel` 创建独立 Pi 会话，显示居中输入；旧会话和草稿保留。单会话兼容客户端仍支持原有 `new_session` / `switch_session`。

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
- 成功 `read` 默认只有一行；终端和其他工具最多预览 6 行，失败最多预览 3 行；`edit/write` 最多预览 8 行 Diff。仅截短的多行结果显示“展开内容”，短结果不加重复提示。在 **设置 → 外观 → 工具显示** 可切换全局挡位：**收起**（只留标题一行）/ **简略**（上述默认预览，全局默认）/ **展开**（直接平铺完整命令、输出与 Diff）；挡位存于 `appearance.json` 的 `toolDisplay`，切换后立即生效并重置单张卡片的局部展开记忆，详见 [外观设置](appearance_settings.md)。
- 点击标题或“展开内容”切换展开，支持键盘 Enter/Space。展开后可滚动、选择、复制完整输出，并使用文件打开/改动面板图标；文件、工具图片输出仍保留。
- 执行中只在标题旁显示轻量状态，失败/中断用图标和 Tooltip 标记。未知工具走相同的简洁样式，标题提取路径、查询词、URL 等必要信息，不会丢弃结果。
- 输入栏左上角的处理状态、工具的“执行中”和正在生成的“思考过程”统一使用工具原有的文字微光扫描。动画只扫文字，不扫整行；思考收起时也能看到。思考结束或开始输出正文/工具参数时立刻停止，旧思考不动；减弱动态模式全部显示静态文字。
- 内容可以选择复制。网页与本地文件链接只有点击后才通过系统默认程序打开；Markdown 本地/内嵌图片、RPC 图片块可以预览，网络图片需点击后加载。选图、限制与路径规则见 [图片附件与文件链接](images_and_links.md)。

### 右栏与工具 Diff

右上角入口现为 **文件与 Git**，以“文件 / Git graph”两个图标页签替代原来的会话编辑记录汇总；空会话也可打开。右栏读取当前工作区的真实目录、Git 状态和提交历史，支持只读文件 / Diff / 提交详情，并沿用侧边栏毛玻璃。操作、限制、只读 RPC 与绘制边界见 [右侧工作区浏览](workspace_browser.md)。

时间线中的工具 Diff 不被 Git 替代：

- 每次编辑仍优先显示 Pi 返回的 `details.patch`，兼容旧式 `details.diff`。
- `write` 由随 GUI 启动的观察扩展补充真实前后 Diff，新建文件显示“新建文件”。无基线 / 冲突 / 旧历史时仍显示中性写入内容，不伪造新增行。
- 工具上的右栏图标打开文件页并展开目标文件的祖先；每次调用的原始编辑记录继续在工具展开区查看。
- 右栏现在是 Git 工作区快照，包含终端或外部编辑器的变化；不能把它与某一次工具调用的 Diff 混为一谈。两者都没有接受、回滚、提交等写按钮。

### 会话与恢复

生产侧栏通过管理通道的 `gui_workspace_history` 读取各目录的官方历史摘要，`gui_open_channel(sessionPath)` 在独立 Pi 进程中恢复历史；同一历史只允许一个运行实例。切换标签纯属 UI，不发送 `switch_session`。Flutter 不自行扫描 Pi 私有会话目录。

每个通道有独立 ChatController / ModelPickerController 和写确认屏障。单会话断连不影响其他通道，不自动重放消息；已退出会话可关闭标签后从历史重开。单会话兼容传输的有界重连 / 恢复逻辑仍用于原有探针。完整生命周期见 [工作区与并行会话](workspaces_sessions.md)。

## 架构与代码入口

工具行参考用户给出的 Pi 原版截图及 Pi 0.85.1 的工具 renderer：工具名与目标同一行、简短预览、按需展开；只保留内容，不搬运 TUI 的整块背景和外框。原改动面板参考 VS Code 的改动查看；当前双页签右栏见 [工作区浏览](workspace_browser.md)，不实现检查点或仓库写操作。协议按本机 Pi 0.85.1 官方 `docs/rpc.md`、`docs/extensions.md` 与工具返回值核对。

| 层 | 路径 | 职责 |
| --- | --- | --- |
| 生命周期 | `lib/ui/features/home/controllers/workbench_controller.dart` | 唯一 PiChannelHub 物理连接，每个会话独立逻辑客户端、模型、聊天与扩展桥 |
| RPC 服务 | `lib/core/rpc/pi_rpc_client.dart` | JSONL 帧、关联响应、类型映射、写确认屏障、真实断线 |
| 聊天协议 | `lib/core/rpc/pi_chat_types.dart` | `PiChatGateway`、`PiChatMessage`、`PiContent`、`PiContentDelta`、`PiChatEvent`、工具结果及队列 |
| 通用状态 | `lib/core/rpc/pi_rpc_types.dart` | 扩充 `PiSessionState`，连接、会话切换及迟到确认事件 |
| 时间线投影 | `lib/core/models/chat_timeline.dart` | 按内容索引拼接、最终消息替换、toolCallId 关联、历史重建；`assistantNumbers` 按正序生成与消息列表对齐的编号 |
| Diff 解析 | `lib/core/models/diff_document.dart` | patch/带行号 Diff、中性写入后视图；隐藏重复文件头但保留真实内容，无文件 I/O、无补丁执行 |
| write Diff 后端 | `assets/backend/gui_tool_diff.mjs` | 公共 `tool_call/tool_result` 中间件，有限快照、冲突降级、补充结果 details，不接管工具执行 |
| 扩展装载 | `lib/core/rpc/pi_workspace_transport.dart`、`assets/backend/workspace_rpc.mjs` | 发布适配层、并行管理器、工作区浏览模块和 Diff 扩展四个 assets；`PiChild` 以 `--extension` 装载 Diff 观察扩展 |
| 交互状态 | `lib/ui/features/home/controllers/chat_controller.dart` | 发送互斥、停止、恢复、会话书签与成功文件记录投影 |
| 主工作区 | `lib/ui/features/home/widgets/home_chat_panel.dart` | 两态布局、时间线、草稿、回到最新、响应式文件 / Git 右栏 |
| 输入组件 | `lib/ui/features/home/widgets/home_starter_panel.dart` | 共用输入卡片、键盘/IME、紧凑模型入口 |
| 消息 | `lib/ui/features/home/widgets/chat_message_view.dart` | 角色/发言编号、Markdown、思考和工具块的有序渲染，连续步骤分组 |
| 显示文本 | `lib/core/utils/terminal_text.dart` | `stripTerminalControls` 线性扫描 CSI/OSC/控制字符串，兼容流式半截序列，仅在思考显示入口使用 |
| 工具注册表 | `lib/ui/features/home/widgets/tool_card_registry.dart` | `ToolCardRegistry.register` / `unregister`，默认回退与共享 `ToolChangeDetails` |
| 工作区右栏 | `lib/ui/features/home/widgets/workspace_browser_panel.dart` | 文件树、Git graph、只读预览；详见独立文档 |

连续步骤参考 [Vercel AI Elements 的 Chain of Thought](https://elements.ai-sdk.dev/components/chain-of-thought)：内联折叠步骤加左侧竖线；不增加新的交互层级，也不接管工具注册表。

公共原子库新增：

- `AppComposerLayout`：同一布局过程测量输入区高度并移动位置，时间线不会被多行输入覆盖。
- `AppMarkdown`、`AppCodeBlock`、`AppDiffView`：主题化的 Markdown、代码及 Diff。后两者提供 `framed: false` / `previewLines`，预览没有嵌套卡片和滚动；完整内容按需构建。`AppDiffView(written: true)` 模式只显示本次写入和新行号，不能当成 Diff 统计。
- `AppDisclosure`：`framed: false`、`titleContent`、`trailing`、`previewBuilder/previewHint` 支持内联折叠；展开仍延迟构建，旋转箭头与尺寸变化复用 Motion Tokens。使用带类型的独立 PageStorage 标识，**不能把 bool 写进 ScrollPosition 的默认 double 存储位置**。
- `AppStepGroup`（`lib/ui/atoms/app_step_group.dart`）：只接收 Widget 列表，绘制主题边框色的细竖线及紧凑间距；不依赖聊天/RPC，不添加背景，不拦截点击，线高随折叠内容真实布局变化。第三方工具 renderer 原样放入，不丢注册能力。
- `AppDisclosure` 在减弱动态模式直接绘制正文，不使用零时长 `AnimatedSize`；避免 Flutter beta 在改变宽度时发生布局期间重入，折叠状态仍由原 State/PageStorage 保存。
- `AppActionButton.labelContent`：复用原有 Hover、Focus、Disabled 和键盘状态，允许富文本标题；纯文本 `label` 保留无障碍名称。
- `AppCopyButton`：复制反馈。
- `AppActivityLabel`（`lib/ui/atoms/app_activity_label.dart`）：三处共用的非阻断文字微光，保持工具原有渐变与 `AppDurations.verySlow * 3` 线性周期。内部 Align 松开父布局的最小宽度，让 ShaderMask 始终贴合文字，避免输入栏的 stretch Column 拉长扫描范围。`style/maxLines` 允许标题保留原排版；共享 `AppAnimationClock` 按持续动画帧率更新 controller.value，不再 repeat。ShaderMask 有局部 RepaintBoundary，停止/减弱动态时不创建 ShaderMask。时钟在 TickerMode 禁用或卸载时释放订阅；帧率设置见 [帧率与性能](frame_rate_performance.md)。

继续复用 `AppCard`、`AppTextField`、`AppActionButton`、`AppIconButton`、`AppNavTile`、`SlotContainer`。`AppTextField` 增加 focusNode/minLines/多行及无边框模式；图标按钮补齐键盘触发和焦点边框；通用操作按钮的高度改为下限以适配系统字号。代码字体由 `AppTheme.codeStyle` 提供。

动画使用 Motion Tokens，并检测 `MediaQuery.disableAnimationsOf(context)`。流事件以 40ms 时间窗合并内容通知；当前消息文本超过 12,000 / 60,000 字符时分别使用 micro（80ms）/ quick（150ms），最终状态立即刷新并取消尚未发出的批次。工具输出预览上限 60,000 字符；小于等于 12,000 字符且明确指定语言的代码才尝试高亮，避免对大量终端输出做语言猜测。Diff 行列表按需构建。

## RPC 命令与数据

### 命令

下面是原生 Pi 命令格式。在并行 GUI 中由 PiChannelHub 封装 `gui_channel`；新建 / 选择会话用管理命令开通道，不在既有通道上替换另一个会话。

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
- `get_messages` 与实时事件竞态时，不能覆盖更晚的流式内容；运行中保留本地投影，需要校正时在 settled 后重新同步历史。普通完整回复只回读 `get_state`，不再每轮搬运全部历史；具体校正条件见下方“内存与重复处理”。
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
- **基础输出路由**：`routePiOutput` 把解析结果一并交给 `WorkspaceAdapter` 做响应关联和运行状态维护。兼容单会话输出保留原始 JSON 行；并行管理器额外封装通道身份。内部探测响应不外泄，未知事件、旁路文字和坏行在所属通道隔离，`agent_end` 仍不解除运行锁。
- **工具引用索引**：`lib/core/models/chat_timeline.dart` 用 `toolCallId → 可见引用数` 判断结果是否已有消息引用，避免每个工具结果都扫描全部前文。最终消息替换、内容块替换、历史重载会维护/清空引用数；不能使用只增不减的 Set，否则被最终消息删除的草稿工具会错误隐藏后续孤立结果。流式更新只维护变化的内容块，不反复登记整条消息的工具。孤立结果、编号、累计输出与 Diff 证据保持原行为。
- **摘要缓存与加载调度**：见 [工作区历史缓存](workspaces_sessions.md#后端结构)。消息本身不做跨会话缓存，不绕过 Pi 的当前分支/压缩投影。

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

首次加载或需要校正时，仍未改变 SDK 冷启动、`get_messages` 整包传输、Dart 主 isolate 的整包 JSON 解码或 Markdown 渲染。普通完整回复现在省略重复的整包读取，见下节。上述大样本的 `jsonDecode` 仍约 57 ms；若继续优化超长会话，应针对真实 GUI 的分段/帧耗时评估后台 isolate 或后端分页能力，不能把合成测试结果宣传成整个页面“瞬间加载”。

回归集中在 `test/pi_rpc_client_test.dart` 的大帧/UTF-8/尾行与协议隔离，`test/chat_rpc_test.dart` 的草稿/最终引用替换、重复引用、孤立结果与重载，以及工作区文档列出的缓存状态机。验证全程不热重启或切换当前活动聊天，新后端资源在下次正常启动更新后的 GUI 时装载。

### 界面绘制与流式更新

- `ChatController.timelineChanges` 是独立的内容 Listenable：合并的 `message_update` / `tool_execution_update` 只通知时间线。原 ChangeNotifier 留给加载、运行锁、错误、队列等会话状态；最终消息/工具结果立即同时刷新。缺少 message_start 的首条增量从空态建立消息时，仍刷新布局状态。
- `HomeChatPanel` 仅在时间线内部订阅内容通知，不再每个文字批次重建标题和输入卡片；倒序列表已经在 offset 0 时不重复 jumpTo。原有居中空态、跟随/查看旧消息及滚动恢复保持不变。
- `ChatMessageView` 仅复用当前挂载消息的子树，按消息对象、编号、当前思考索引、所引用工具对象和注册 renderer 变化失效；主题、本地化、资源上下文继续走 Inherited 依赖。工具集合会原地修改，因此不能只比较整个 tools Map 的身份。
- `AppMarkdown` 复用未改变内容块的已构建子树；主题等依赖变化正常失效，卸载即释放。没有跨会话无限缓存。正在增长的单块 Markdown 仍全量解析，通过上述长草稿合并频率减轻压力；不按空行硬拆，避免改变围栏/表格/引用语义。
- 微光及公共加载转圈共用限速时钟并局部隔离重绘，后台标签的忙碌圆弧静止。全局/持续动画两层设置、数据格式与实测见 [帧率与性能](frame_rate_performance.md)。不增加 RPC，不丢弃/重放数据事件，不替用户关闭毛玻璃。

## 内存与重复处理

本次不增加设置或改变操作：历史、工具输出、复制全文与 Diff 证据都保留；没有进程休眠、旧消息截断或毛玻璃调整。非活动标签的重型视图卸载见 [工作区与并行会话](workspaces_sessions.md#标签视图有界保留apptabworkspace)。

### 工具输出字节预算（旧输出按需重读）

历史正文与实时流式内容仍然全量保留在时间线里；只有**已结束的工具输出**受 `ChatTimeline.defaultOutputBudgetBytes`（8 MiB，按 UTF-16 码元×2 估算）约束：

- 预算触发点：完整历史装载后、`tool_execution_end`（单个长任务期间也会释放）与 `agent_settled`。释放顺序按会话可见顺序从最旧开始，正在执行/准备中的工具、被 pin 的行绝不释放。
- 释放内容：输出正文截到 2000 字符预览、丢弃图片块、write 的 `arguments.content`、`details.patch/diff`（Diff 证据随之降级）；保留标题身份（path/命令/行数信息）与 `guiWrite` 小字段，卡片标记 `evicted`。孤立 toolResult 消息自持的结果副本同步释放，否则压缩历史会绕过预算。
- 展开/收起 pin：工具行 AppDisclosure 通过 `ChatToolOutputScope`（lib/ui/core/chat_tool_output_scope.dart）上报展开态，展开 pin、收起解除；标签 pane 重挂载后恢复的展开态会重新上报。自定义工具渲染器不接入则无 pin，但也不受影响。
- 按需重读：`ChatController.reloadToolOutput(id)` pin 该行并发起一次权威 `get_messages` 全量刷新（当前后端无分页接口，只能整批回读），其余落在预算内的旧输出随刷新恢复、超出预算的下一批最旧行重新释放；绝不重发 Prompt。会话切换/工作区变化清空 pin。
- 回归：`test/chat_rpc_test.dart` 覆盖释放顺序/预览/孤立副本/运行中豁免/pin 保护、重读往返与 live 定结释放。验收标准是反复开关会话后的存活对象与长会话每轮分配量，不是任务管理器数字立即回落。

### 正常回复不重复搬运完整历史

`ChatController.refresh()` 仍是显式完整同步入口。内部 `_refresh()` 根据 `_needsHistory` 决定是否读取正文：

- 初次打开、显式刷新、重新连接、会话身份变化、迟到写确认和已确认停止，仍读取 `get_state` + `get_messages`。
- 从完整初始快照开始、收到完整实时消息和工具结果的普通回复，在 `agent_settled` 后只读 `get_state`，保留实时投影。会话标题、模型等状态和后端最近会话书签照常更新。
- 压缩、自动重试、坏聊天事件、缺少最终消息或工具结果会将历史标为待校正；不能把部分草稿当成最终记录。`ChatTimeline.hasUnsettledContent` 必须在 `settle()` 清除活动标记前检查。
- 完整快照与事件竞争时，`_revision` 阻止旧快照覆盖新内容，待校正标记保留到下次安全同步。在运行中首次加载，即使没有事件竞争，也要在 settled 后补读。
- Prompt 确认在 settled 之后才返回时，`_runRevision` 区分“完整 Agent 已运行完毕”和“扩展命令未启动 Agent”；只有后者主动请求完整同步。已排队的完整刷新不会被轻量状态读取降级。

不更改运行锁：`agent_end` 不能解锁；未知写入仍等待确认，读取超时不杀 Pi，也不重发 Prompt。`test/chat_rpc_test.dart` 覆盖普通轮次请求计数、确认晚于 settled、扩展命令、重试/压缩/坏事件/缺失结束、快照竞态及刷新合并。

### 工具 Diff 只保留当前工具行的一份解析

`ToolCardRegistry` 的默认工具行持有一个 `DiffDocumentMemo`，供展开提示、8 行预览和完整详情复用；`ToolChangeDetails.document` 将解析结果交给公共 `AppDiffView.document`。自定义 renderer 注册接口不变，不另建工具卡片样式。

- 单槽、延迟解析；同一输入重复读取返回同一文档，源文本/编号格式/中性写入模式改变时替换旧文档。
- 缓存只属于挂载的工具行，不放在 `ChatTimeline` 上，不建立跨会话或全局无限缓存；工具行回收后即可释放。
- `DiffDocument.added/removed` 统计按不可变文档只计算一次。仍保留完整行和原始 source，预览截短不影响复制全文；超大单份 Diff 本轮尚未改成增量解析。
- 解析与模式失效回归位于 `test/chat_rpc_test.dart`，不增加纯样式测试。

通道与目录缓存释放见 [工作区与并行会话](workspaces_sessions.md#前端资源释放)。上述自动测试没有测量生产进程的堆/显存下降；后续应在独立实例中比较重复开关会话后的存活对象和长会话每轮分配量，不能只看任务管理器是否立即回落。

## 扩展槽位

`aboveEditor/belowEditor` 跟随同一个输入组件；`statusBar` 占据布局底部，不再覆盖输入；`dialogOverlay/notificationToast` 继续使用原扩展桥。文件 / Git 右栏保留 `sidebarPanel` 插槽。时间线通过工具注册表分派，未知工具走通用渲染器。

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

暂不包含 LaTeX/Mermaid、编辑审批/回滚及执行中的插队发送。Git 状态、Diff 和提交图已接入只读工作区右栏。图片上传/预览与文件链接已接入，见 [图片附件与文件链接](images_and_links.md)；历史会话列表由工作区后端提供。已有扩展弹窗仍由 Pi 的 extension_ui 机制处理，不由 Flutter 重写权限或 Agent 逻辑。
