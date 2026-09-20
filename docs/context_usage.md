---
title: "输入框上下文圆环"
version: "1.0.0"
status: "implemented"
type: "feature"
tags: [flutter, pi-rpc, composer, context]
---

# 输入框上下文圆环

## 用途与操作

输入框底部、模型选择器左侧有一个小圆环，表示**当前模型上下文窗口已用比例**。不占用常驻文字空间，也不改变模型选择浮层。

- 鼠标悬停：显示已用百分比、已用 / 总 Token；这是 Pi 提供的估算，不是账单累计消耗。
- 低于 75% 使用次要文字色，75% 起使用警告色，90% 起使用错误色。全部沿用主题语义颜色。
- 暂时没有数据时显示灰色空环，不转圈、不伪装成 0%。压缩后若 Pi 尚未确定用量，提示模型上限并等待下一次更新。
- 超过窗口上限时圆环最多画满，提示仍显示真实百分比。
- 进入会话、每轮结束、压缩结束、模型/历史变更后自动更新。输入草稿不在前端自行估算。

参考 Cursor 的轻量上下文用量提示方式，按本项目要求放到模型选择器左侧；只提供只读提示，不新增压缩或清空会话的操作。

## 代码与组件

| 路径 | 职责 |
| --- | --- |
| `lib/ui/atoms/app_progress_indicator.dart` | 复用公共圆环，新增 `value`/`backgroundColor`；传入数值为确定进度，原有忙碌动画保持不变 |
| `lib/ui/features/home/widgets/context_usage_indicator.dart` | 28px 区域内绘制 18px 圆环，组合 Tooltip、本地化数字及主题色 |
| `lib/ui/features/home/widgets/home_starter_panel.dart` | 紧凑 Row 放置圆环与模型按钮；模型按钮仍可收缩省略 |
| `lib/ui/features/home/widgets/home_chat_panel.dart` | 传入当前 `WorkbenchSession.client`；休眠时不传客户端，不主动唤醒 Pi |
| `lib/ui/features/home/controllers/context_usage_controller.dart` | 只读、事件驱动、单请求合并与过期结果隔离；不改变聊天或模型选择器的忙碌状态 |
| `lib/core/rpc/pi_rpc_types.dart` | `PiContextUsage`、`PiContextGateway`、`PiContextUsageInvalidated` |
| `lib/core/rpc/pi_rpc_client.dart` | 原生 `get_session_stats` 强类型读取及成功模型/历史操作后的失效通知 |
| `lib/l10n/app_en.arb`、`lib/l10n/app_zh.arb` | 用量、未知及不可用提示 |

圆环变化使用 `AppDurations.fast` + `AppCurves.smoothOut`；开启减弱动态时立即切换。Tooltip 同时提供可访问性说明。没有新增私有绘图样式或额外 Pi 进程。

## RPC 数据与生命周期

```json
{"id":"gui-42","type":"get_session_stats"}
{"id":"gui-42","type":"response","command":"get_session_stats","success":true,"data":{"sessionId":"session-a","tokens":{"total":900000},"contextUsage":{"tokens":12000,"contextWindow":200000,"percent":6}}}
```

只读取 `data.contextUsage`，绝不能使用 `data.tokens.total` 作为上下文占用。`sessionId` 保留在强类型快照中。旧版本省略 `contextUsage` 或没有当前模型时，返回空快照；`tokens`/`percent` 为 `null`（例如刚压缩）仍保留窗口上限。畸形统计、请求失败只让圆环降级，不禁用发送、不清空会话、不触发重连。

- 圆环挂载时读取；卸载取消订阅。后台未挂载的标签不轮询，重新挂载读取当前值。
- `agent_start`、`turn_end`、`agent_settled`、`compaction_end` 驱动读取，不对逐字 `message_update` 发请求。
- `set_model` / `cycle_model`、手动 `compact`、原生 fork/clone 和 GUI 历史导航/fork/clone 成功后，由客户端发出 `PiContextUsageInvalidated`；取消的操作不作变更确认。
- `PiRpcSessionChanged` / `PiRpcWorkspaceChanged` 清空旧值并回读；断线或进程替换先暂停读取，连接恢复后继续。
- 同时最多一个查询；期间多个刷新信号合并为一次后续查询。模型/会话/连接变化增加世代号，旧响应不能覆盖新状态。每个已挂载会话面板拥有独立 Controller。
- 所有数据通过已有 Pi RPC 逻辑通道获取；无需安装 GUI 扩展或重新启动后端。

## 验证

```bash
flutter test test/context_usage_test.dart test/model_picker_controller_test.dart test/chat_rpc_test.dart test/pi_rpc_client_test.dart
node tool/check_history_rpc.mjs
```

精简测试覆盖原生统计与累计 Token 的区分、旧版本和压缩未知值、非法数值、超上限、请求合并、逐字事件零请求、跨会话隔离及旧响应失效。

真实探针使用隔离目录、虚构本地 API Key 仅启用模型元数据，禁止联网调用模型；通过生产多通道适配器验证压缩后未知、回退历史后恢复为最近一次 3,100 Token（不是历史累计值）、兄弟会话隔离。

已在运行中的 Windows GUI 热重载验证：圆环位于模型选择器左侧，真实会话返回上下文百分比与 Token 上限；使用 Flutter inspector 截取输入框确认布局，未重启 GUI/Pi、未切换活动会话或发送测试 Prompt。
