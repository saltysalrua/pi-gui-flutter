---
title: "模型选择器：Pi RPC 接入与搜索"
version: "1.2.2"
status: "implemented"
type: "feature"
tags: [flutter, pi-rpc, model-picker]
---

# 模型选择器：Pi RPC 接入与搜索

## 用途与操作

首页输入框右下角显示 **Pi 当前模型 · 当前思考等级**，不再使用演示模型。

1. 启动 GUI，应用通过 PATH 中的 `pi --mode rpc` 建立一个长期存活的子进程。
2. 点击模型按钮查看当前等级；点击浮层标题右侧箭头进入模型列表。浮层打开时调整窗口大小、最大化或还原，它会继续跟随模型按钮，当前页面和搜索内容不会重置。
3. 在搜索框输入模型名称、模型 ID 或提供商。忽略大小写，空格分隔的多个词需要同时匹配。例如 `ollama-cloud glm-5.3`。
4. 每项用紧凑的单行显示名称和提供商，悬停可查看完整 `provider/modelId`，搜索仍匹配完整 ID。长列表可以滚动；搜索只有一个结果时可按 Enter 选择。
5. 选择模型后，等待 Pi 确认，再返回思考等级页。滑块档位完全来自该模型的 RPC 返回值；拖动松手后才提交一次，避免连续发送写请求。Tab 聚焦滑块后可用左右方向键调整。
6. 右上角刷新按钮重新读取 Pi 当前状态和列表；**不是重置成固定的 High**。正常重新打开浮层直接显示上次确认的状态，不重复读取或短暂锁住侧边栏；首次加载、错误恢复和后端变更事件仍会读取。

没有可用模型时，会提示先在 Pi 配置提供商。真实连接中断后，应用最多自动尝试重连三次（间隔 1/2/4 秒），只重新读取状态，不重放模型/等级写入；自动恢复失败或无法启动 Pi 时，可用刷新重试。老版本 Pi 若不认识思考等级查询命令，会保留模型选择功能，并提示升级；前端不会根据模型名猜测等级。

> `get_available_models` 返回 Pi 认为当前可用的配置模型，不等于逐个验证远端服务可达。刷新读取当前 RPC 进程的模型注册表，不会擅自重载或修改 Pi 的配置文件。

## 组件与架构

参考 [VS Code 的模型选择与 Thinking Effort](https://code.visualstudio.com/docs/agent-customization/language-models)，保留本项目的两级浮层和离散滑块，不额外引入模型管理页面。

| 层次 | 路径 | 职责 |
| --- | --- | --- |
| 进程与帧解码 | `lib/core/rpc/pi_rpc_transport.dart` | 启动 Pi、UTF-8 分块解码、仅按 LF 分帧、关闭进程树 |
| RPC 服务 | `lib/core/rpc/pi_rpc_client.dart` | 请求 ID 关联、强类型公开方法、错误/超时/断连、事件流 |
| 协议实体 | `lib/core/rpc/pi_rpc_types.dart` | `PiModel`、`PiThinkingLevel`、`PiSessionState`、扩展事件、`PiModelGateway` |
| 交互状态 | `lib/ui/features/home/controllers/model_picker_controller.dart` | 加载与写入互斥、搜索、成功后回读、失败后阻止未经确认的继续写入 |
| 生命周期 | `lib/ui/features/home/views/home_view.dart` | 持有唯一客户端、Controller、扩展桥；正常关闭窗口时清理进程 |
| 入口 | `lib/ui/features/home/widgets/home_starter_panel.dart` | 订阅共享 Controller，展示真实模型和等级 |
| 浮层 | `lib/ui/features/home/widgets/model_thinking_popover.dart` | 搜索、列表、加载/空态/错误、动态档位与回读结果 |
| 文案映射 | `lib/ui/features/home/model_picker_labels.dart` | RPC 枚举与本地化提示的映射 |
| 扩展桥 | `lib/ui/features/home/controllers/pi_extension_ui_bridge.dart` | 从连接前开始监听 `extension_ui_request`，路由到标准插槽 |

复用 `AppCard`、`AppActionButton`、`AppIconButton`、`AppNavTile`、`AppSteppedSlider` 和 `SlotContainer`；公共库原先没有输入原子，新增 `AppTextField`，同时用于模型搜索与扩展输入。

- 浮层宽度恢复为 280，模型列表最大高度 360、行高 36。思考页合并等级/模型名，完整 ID 移入 Tooltip；加载图标占用右侧刷新按钮的固定位置，不插入进度条撑高面板。
- `showModelThinkingPopover` 参考 Flutter `PopupMenu.positionBuilder`，用 `LayoutBuilder` 在窗口约束变化时重新读取按钮相对于根 Overlay 的坐标，再交给 `_PopoverLayout` 做右侧对齐、上方间距和边缘避让；只缓存 RenderBox 与最后有效位置，不把打开瞬间的坐标永久固定。按钮卸载时不再查找失活 Element，保留最后有效位置用于退场。此过程不重建路由、不重置搜索、不增加 RPC 请求。
- `AppNavTile` 支持副标题与键盘焦点；选择器使用单行模式，提供商放右侧，不再使用模型选择器私有列表项。
- `AppTextField.isCompact` 复用紧凑搜索样式；`AppActionButton.subtitle` 提供二级文字。按钮高度作为下限，适配系统文字放大，避免单行或双行文字溢出。
- `AppSteppedSlider` 支持禁用、键盘/语义操作和 `onChangeEnd`，仍保留刻度外观。`isBusy` 区分短暂提交和真正禁用：等待确认时拦截鼠标、键盘与语义操作，但保留原来的亮度和焦点，避免快速调整等级时反复变灰。
- 浮层的加载图标延迟 `AppDurations.fast`（250ms）出现；短请求结束会取消计时，不闪一下转圈。等待期间刷新按钮仍不可重复触发；慢请求照常显示进度，卸载浮层时取消计时器。
- 模型标识使用 `(provider, id)`，不能使用显示名称或全局唯一 ID 假设。
- 等级协议值为 `off/minimal/low/medium/high/xhigh/max`，这只是可解析值集合，**不是每个模型的选项表**。
- 浮层与入口共享同一状态对象，关闭浮层不取消已发送的选择命令。
- 颜色/排版使用主题，静态文案使用 `app_en.arb` / `app_zh.arb`，浮层动效使用 Motion Tokens 并适配减弱动态。

## RPC 命令与回读

启动时/刷新时依次请求：

```json
{"id":"gui-1","type":"get_available_models"}
{"id":"gui-2","type":"get_state"}
{"id":"gui-3","type":"get_available_thinking_levels"}
```

典型返回（模型只示意本界面使用的字段，Pi 实际返回完整对象）：

```json
{"id":"gui-1","type":"response","command":"get_available_models","success":true,"data":{"models":[{"provider":"ollama-cloud","id":"glm-5.3","name":"glm-5.3","reasoning":true}]}}
{"id":"gui-2","type":"response","command":"get_state","success":true,"data":{"model":{"provider":"ollama-cloud","id":"glm-5.3","name":"glm-5.3","reasoning":true},"thinkingLevel":"high"}}
{"id":"gui-3","type":"response","command":"get_available_thinking_levels","success":true,"data":{"levels":["off","low","high","xhigh"]}}
```

切换模型和等级：

```json
{"id":"gui-4","type":"set_model","provider":"ollama-cloud","modelId":"glm-5.3"}
{"id":"gui-5","type":"set_thinking_level","level":"high"}
```

每次写成功后重新请求 `get_state` 和 `get_available_thinking_levels`。两次读取都完成后原子替换选择快照；异步等待期间保留上次已确认的模型和档位，不先清空滑块，也不提前显示部分回读结果。Pi 可能在换模型时裁剪旧等级，不能沿用旧滑块索引。非推理模型返回 `["off"]` 时显示说明而不构造只有一个档位的滑块。收到 `agent_settled` 或会话切换确认 `PiRpcSessionChanged` 时也刷新选择状态，确保聊天恢复/切换后显示正确模型。

普通打开只调用 `ModelPickerController.ensureLoaded()`：已就绪时不发请求、不触发 `isBusy`，因此不会经 `WorkspaceController.canSwitch` 让侧边栏变灰。显式刷新和真实写入仍保留原来的互斥锁，不能为消除视觉闪动放开并发写入。

### 启动窗口补读（lateRead）

Pi 0.85.1 RPC 进程在进入命令循环的同一刻才发起后台目录刷新（`main.js`，fire-and-forget，约 15 秒）：刷新开头的 `rebuildProviders()` 会先清空扩展 provider（如 yuukarin、猫饭）从 `models-store.json` 回放的动态目录，网络阶段逐 provider 补回。因此 RPC 就绪后头几秒 `get_available_models` 会返回残缺列表；GUI 首次读取（会话恢复事件触发）可能落在窗口内并缓存残缺快照。

处理方式：`ModelPickerController` 在每个 Pi 进程周期（断线 `PiRpcDisconnected` 或换工作区 `PiRpcWorkspaceChanged` 重置）的首次成功读取后，安排一次 `lateReadDelay`（默认 18 秒，晚于后台刷新的 15 秒上限）后的**静默补读**：

- 不置 `isBusy`、不弹 `failure`，侧边栏/滑块不闪；
- 补读时若有写入在飞，最多间隔 3 秒重试 3 次，不与在途写入交错；
- 仅当模型列表（身份/名称/推理标记）或选择快照（模型/档位/档位列表）可见变化时才 `notifyListeners`，列表内容不变则零通知；
- 补读失败静默放弃，交给事件驱动的正常刷新重试。

离线对照实验（`PI_OFFLINE=1`）确认无后台刷新时首次读取即全量，可区分窗口问题与连接问题。

### 错误与生命周期

- `success:false` 变为带命令名的 `PiRpcException`；UI 展示本地化解决提示，不直接展示异常堆栈。
- 写请求正在确认时，其他模型/等级写入被阻止。
- **请求错误不等于断线**：非 JSON 的旁路日志仅记诊断；无效响应只拒绝对应请求；无效扩展事件会提示，能识别的阻断对话会回取消。均不会主动杀掉健康的 Pi。
- 读请求超时只结束该次请求，忽略迟到响应，保留连接。写请求超时保留待确认屏障，后续查询/写入必须等原请求确认；收到迟到确认后发出 `PiRpcSelectionSettled`，Controller 自动回读，绝不盲目重发写入。
- 只有真实 stdout EOF / I/O 错误才触发 `PiRpcDisconnected`。事件携带 `processExited` / `transportError` 原因；Controller 有界自动重连。
- 每个流回调和 stdin 写入错误绑定其原始 transport；旧连接的迟到错误不能影响新连接。stdin 的 JSONL 命令与扩展回复按帧串行 flush。
- 如果写成功但回读失败，保留上次完整确认的快照作为只读展示，`isReady = false`；必须刷新后才能再次操作，不把旧值当成后端当前值。
- Windows 用 shell 的 PATHEXT 兼容 `pi.cmd` / `pi.exe`；退出时只清理本客户端启动的 PID 及其子进程。不会停止用户独立启动的 Pi。
- 严格 JSONL 分帧：只按 `\n` 切分，可剥离行尾 `\r`；不会把字符串中的 U+2028/U+2029 当成换行。stderr 单独排空，不拼进 stdout 或直接展示。对第三方扩展可能混入 stdout 的非协议行做容错，不把它误判成进程退出。
- 调试可读取 `PiRpcClient.isConnected`、`connectionCount`、`lastDisconnectReason` 和 `diagnostics`（最近 24 条）。诊断仅保存类别/命令，不保存原始日志或密钥。
- 关闭解码器时先发起取消、关闭数据源，再等待取消完成，避免 async* 等待 stdout 导致关闭死锁。
- 开发时尽量热重载；Flutter 热重启不会调用旧 State 的 dispose。重启前需先关闭旧客户端，避免遗留调试进程。

## 扩展槽位

启动 Pi 会加载其现有扩展，因此接模型选择器时不能丢弃扩展 UI 请求：

- `setWidget`：按 widgetKey 更新/清除 `aboveEditor` 或 `belowEditor`。
- `setStatus`：按 statusKey 更新/清除底部状态区，支持换行排布。
- `notify`：进入通知槽位，支持关闭。通知槽位有明确宽度，避免无界 Column 导致布局错误。
- `select/confirm/input/editor`：进入全局模态队列，按原始 id 发回 `extension_ui_response`；保留后端提供的超时与取消行为。
- `set_editor_text`：写入共享输入 Controller。
- `setTitle`：更新桌面窗口标题。
- 未知扩展 UI 方法明确提示；其他 Agent 事件保留载荷供后续订阅。

终端 ANSI 样式从展示文字中剥离，Flutter 仍使用自身主题；选项的 RPC 返回值保留原始字符串。

## 验证

```bash
flutter analyze
flutter test
# 只读探针，不发送 Prompt、不消耗模型 Token
dart run tool/check_pi_rpc.dart
# 写回当前模型/等级并回读验证，不改变选择
dart run tool/check_pi_rpc.dart --verify-write
# 用生产客户端持续读取两分钟，检查是否保持同一连接
dart run tool/check_pi_rpc.dart --watch-seconds=120
```

核心测试集中在 JSONL 分帧、请求乱序、扩展事件转发、错误/超时/进程退出、启动中关闭、模型身份、动态等级、写入互斥和失败恢复。移除原来的空页面 smoke test，不增加纯展示型 Widget 测试。

本机 Pi 0.85.1 的可用模型数量随配置变化，不在前端写死。真实 GUI 已走查搜索、空结果、非推理模型、切换回读，以及 110% 系统文字缩放下的紧凑浮层（思考页实测 280×104）。验证不发送 Prompt。

回归测试覆盖旁路 stdout、畸形扩展事件、读超时保活、超时写入延迟确认、旧连接 flush 错误隔离，以及自动重连次数上限。这些路径过去会被笼统地显示为断线，现在分别处理。

闪动回归在 `test/model_picker_controller_test.dart` 中覆盖：反复打开不查询/不发忙碌通知、档位读取延迟或失败时保持完整旧快照、快速提交仍互斥到回读结束，以及启动窗口补读修复残缺列表且每个周期只补读一次（`lateReadDelay: Duration.zero` 注入）。视觉验证通过运行中 GUI 的独立预览 Controller 模拟等待态（不提交真实模型变更），检查 280×104 尺寸和滑块亮度保持不变；仅热重载，不重启承载当前会话的 Pi。

窗口跟随通过运行中 Windows GUI 验证：保持浮层打开，依次缩小至 1200×760、放大至约 1750×980、最大化和还原，浮层右边缘始终与模型按钮对齐，上方间距保持 8；思考页维持 280×104。在模型列表输入 `gpt` 后还原窗口，仍停留在列表页并保留搜索内容。验证结束恢复原窗口位置和大小，不切换模型或会话；静态分析通过，纯布局修复不增加脆弱 Widget 测试。

## 当前范围

模型/思考等级与 RPC/扩展 UI 基础设施现已被 [RPC 对话、Markdown 与文件改动](rpc_chat.md) 复用。`HomeView` 仍持有唯一客户端；聊天控制器与模型选择器共享此连接，不能另起独立 Pi。空会话保持居中启动输入卡片，开始发送后才移到底部。
