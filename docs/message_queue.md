---
title: "原生消息队列"
version: "1.0.0"
status: "implemented"
type: "feature"
tags: [flutter, pi-rpc, chat, queue]
---

# 原生消息队列

## 用途与操作

Pi 工作时可以继续发送要求，不必先停止。处理时机与 Pi 原生交互模式一致：

| 操作 | 效果 |
| --- | --- |
| Enter / 向上箭头按钮 | **本轮补充**（steering）：当前 AI 回合的工具执行完后、下一次模型请求前交给 Pi |
| Alt+Enter / 发送按钮左侧菜单 → 完成后处理 | **完成后处理**（follow-up）：等当前任务没有剩余工具调用和补充指令后再处理 |
| Alt+↑ / 队列右侧编辑按钮 | 取回全部排队文字，**不停止**当前任务 |
| Esc / 方形停止按钮 | 先取回队列，再停止当前任务 |
| Shift+Enter | 换行，保持原有输入习惯 |

额外兼容原生 Windows 快捷键：**Ctrl+Q** 对应 follow-up，**Alt+Q** 对应取回队列。键盘操作在输入框聚焦时生效；输入法正在组合文字时不拦截这些快捷键。

空闲时 Enter 和 Alt+Enter 都直接开始新一轮，不把消息留在无人消费的队列中。运行时停止按钮与发送按钮同时保留，不需要靠停止按钮猜测如何排队。

输入框上方显示等待数量，分别预览第一条“本轮补充”和“完成后处理”；点击标题查看全部原文。长队列的展开内容可滚动，不会无限挤压输入框。取回的文字按 **steering → follow-up → 当前草稿** 合并，保留取回期间的新输入。排队本身不会提前在聊天时间线伪造一条用户消息；实际送入上下文后由 Pi 的消息事件显示。

### 与原生一致的边界

- 每个会话使用自己的 Pi 队列。切换标签不清队列、不中断后台任务，不把消息送给另一个会话。
- 发送仍需 Pi 接受确认；确认前禁止重复提交。明确拒绝时保留文字和附件，未知结果不自动重发。
- 图片和文件附件沿用普通发送通路。**Pi 的 `queue_update` / `clear_queue` 只返回文字，不返回图片**，所以取回后图片需要重新添加；编辑/停止按钮的提示会说明。文件引用仍在返回的文字里。
- 使用原生 `steeringMode` / `followUpMode` 设置，默认 `one-at-a-time`，也兼容已经配置的 `all`。GUI 不自行拆批、不修改 Pi 设置文件，也没有另一套消息调度器。
- 原生 RPC 在压缩过程中拒绝 `prompt`；GUI 在压缩、重试等待、停止及发送确认期间暂时禁用提交，保留草稿。没有照搬 TUI 私有的“压缩期间本地暂存队列”。
- 排队消息保存在 Pi 进程内，不是已落盘的会话历史。进程断开后清除过时的显示快照，不自动重放结果不明的消息。普通标签切换不会断开进程。
- 取回暂不支持单条删除、拖动排序或单条改写；与原生 `clear_queue` 一样，统一取回全部文字再编辑。

## 架构与代码入口

交互参考本机 Pi 0.86.0 的官方 `README.md` → Message Queue、`docs/keybindings.md`、`docs/rpc.md`，并核对 `dist/core/agent-session.js` 与原生 RPC 行为。不是 Flutter 维护一个待发列表后逐条调用模型。

| 层 | 路径 | 职责 |
| --- | --- | --- |
| 强类型协议 | `lib/core/rpc/pi_chat_types.dart` | `PiStreamingBehavior`、不可变 `PiPromptQueue`、`queue_update` 解析 |
| RPC 客户端 | `lib/core/rpc/pi_rpc_client.dart` | `prompt.streamingBehavior` 序列化；`clear_queue` 的写确认屏障和严格响应校验 |
| 会话状态 | `lib/ui/features/home/controllers/chat_controller.dart` | `canSubmit` 与 idle-only `canSend/canSwitch` 分离；`send/takeQueue/stop`；权威队列快照 |
| 草稿与显示 | `lib/ui/features/home/widgets/home_chat_panel.dart` | 队列预览、全部文字取回；异步确认绑定原会话草稿，不依赖标签视图是否仍挂载 |
| 输入 | `lib/ui/features/home/widgets/home_starter_panel.dart` | Enter / Alt+Enter / Alt+↑ / Esc、Windows 别名、IME 保护、鼠标菜单与独立停止按钮 |
| 会话生命周期 | `lib/ui/features/home/controllers/workbench_controller.dart` | 队列和取回操作计入 busy，避免仍有排队消息时自动休眠或进行历史改写 |

复用现有 `AppDisclosure(framed: false)`、`AppIconButton`、`AppMenuButton`、`AppTextField` 和 `AppActionButton`；没有新增原子组件或后端扩展。输入框上下及状态栏的扩展槽不变。文字由两份 ARB 生成，颜色/字号走主题；队列尺寸与运行中按钮组使用 Motion Tokens，支持减弱动态。

## RPC 数据与状态规则

```json
{"id":"gui-1","type":"prompt","message":"先检查错误处理","streamingBehavior":"steer"}
{"id":"gui-2","type":"prompt","message":"最后总结修改","streamingBehavior":"followUp"}
{"type":"queue_update","steering":["先检查错误处理"],"followUp":["最后总结修改"]}
{"id":"gui-3","type":"clear_queue"}
{"type":"queue_update","steering":[],"followUp":[]}
{"type":"response","id":"gui-3","command":"clear_queue","success":true,"data":{"steering":["先检查错误处理"],"followUp":["最后总结修改"]}}
{"id":"gui-4","type":"abort"}
```

- 统一使用 `prompt`，不改成先查询 `isStreaming` 再分别调用 `steer/follow_up`。即便 GUI 显示空闲也附上策略，让 Pi 处理“发送时刚好开始/结束”的竞态；扩展斜杠命令仍可由 Pi 即时处理，模板/技能仍由 Pi 展开。
- `queue_update` 是全量替换，保留重复文字和各自顺序；不按文本去重、不从用户消息事件猜测消费数量、不乐观追加 UI 队列。
- 缺字段/错误类型的队列事件只记录坏事件，不能误清空之前有效的队列。
- `clear_queue` 返回 Pi 真正移除的文字，不根据点击前的显示列表恢复，避免取回已经消费的消息。调用期间若收到更晚的队列事件，较旧的 clear 响应不能覆盖新快照。
- 取回期间互斥发送、重复取回和停止。`agent_settled` 与取回确认竞争时，状态回读推迟到确认之后，防止把“写入未确认”误留成永久禁用状态。
- 停止使用独立的操作锁；即使在 clear/abort 之间收到 `agent_start` 或 `agent_settled`，也不能重新开放提交。`agent_end` 仍不解除运行锁。
- `clear_queue` 是破坏性写入：超时或畸形确认保留未确认屏障。读取、停止路径仍可用，但不自动重试清队列或发送消息。清队列明确失败时不继续 abort，以免 Pi 自动消费本应取回的后续消息。
- 正常队列消费没有新的 Flutter 调度动作。暂停、重试、工具回合、顺序与模型调用全部由 Pi 执行。

## 验证

```bash
flutter test test/message_queue_test.dart test/chat_rpc_test.dart test/pi_rpc_client_test.dart test/workbench_browser_test.dart
node tool/check_message_queue.mjs
```

针对性 Flutter 回归 45 项通过，包含策略/图片序列化、事件全量替换与坏事件隔离、运行中发送互斥、无乐观用户消息、取回/停止顺序、迟到确认屏障、队列更新竞争、停止期间续跑竞争、取回与 settled 竞争、多会话隔离及断开不重放。

原生探针使用临时独立配置与只绑定 `127.0.0.1` 的受控 SSE 服务：验证两条 steering 先于两条 follow-up、逐条交付、tool turn 后消费、只在最后 settled、空闲时 follow-up 正常开始、取回不停止、clear 后 abort。共 6 次本地请求，**不读取用户配置、不访问外部模型、不消耗模型额度**。

Windows 界面验证使用隔离 QA 可执行文件和内存假 RPC，未重启承载 Agent 的 GUI：浅色 868px/110% 字号、深色 370px/150% 字号及减弱动态均无布局异常；检查 IME Enter、steering/follow-up 键盘处理、鼠标菜单、取回与 Esc、确认后清草稿，以及标签视图卸载后确认仍处理原会话草稿。临时预览与截图放在忽略的 `.dart_tool/`，不混入交付目录。
