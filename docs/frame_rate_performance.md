---
title: "帧率设置与聊天绘制开销"
version: "1.0.0"
status: "implemented"
type: "feature-and-audit"
tags: [flutter, performance, settings, rendering]
---

# 帧率设置与聊天绘制开销

## 使用方法

进入 **设置 → 外观 → 帧率与性能**，或搜索“帧率”：

- **全局帧率上限**：30 / 60 / 120 / 跟随屏幕，默认 **120 FPS**。包括文字更新、滚动、拖拽和动画。
- **持续动画帧率**：相同四档，默认 **30 FPS**。只影响文字微光、加载转圈，同时受全局上限限制。例如全局 30、持续动画 120 时，持续动画也不会超过 30。
- 设置立即生效、自动保存，不重新启动 Pi、不切换会话、不改变系统显示刷新率。恢复默认外观会恢复 120 / 30。
- 这是**上限，不是保证达到的帧率**。屏幕 vsync、窗口是否激活、机器负载及帧处理耗时会使实际帧率低于选项。没有任何变化时不持续绘制。
- 系统减弱动态时微光静止、转圈显示静态圆弧；隐藏标签、后台路由和最小化窗口不维持这些装饰动画的计时器。非选中会话标签保留忙碌圆弧，但不旋转。

毛玻璃、颜色、不透明度和聊天空态/开始态布局均保留。不是用关闭材质掩盖性能问题。

## 实现边界

没有新增 Pi RPC 命令或事件，没有改 Flutter SDK、原生 Runner 或 GPU 驱动配置。

| 路径 | 职责 |
| --- | --- |
| `lib/core/models/appearance_preferences.dart` | `frameRate` / `animationFrameRate` 校验及 version 1 兼容；0 表示跟随屏幕 |
| `lib/ui/features/settings/views/appearance_settings_view.dart` | 复用 AppSettingsGroup、AppSettingRow、AppSelect；中英文走 ARB |
| `lib/main.dart` | 原有偏好监听里应用帧率，不替换 Navigator/HomeView/WidgetsBinding |
| `lib/ui/core/frame_pacer.dart` | 纯 Dart 帧配对状态机，过早到达的 begin/draw 成对跳过，由一个单次 Timer 释放待处理帧 |
| `lib/ui/core/app_frame_policy.dart` | 包装公开 PlatformDispatcher 帧回调，并原样保留 Flutter 原始回调及 warm-up 处理；共享按需动画时钟 |
| `lib/ui/atoms/app_continuous_animation.dart` | 局部 RepaintBoundary、TickerMode/减弱动态门控和订阅释放 |
| `lib/ui/atoms/app_activity_label.dart` | 保留原渐变与 1.5 秒周期；共享时钟更新 controller.value，不再 repeat 驱动屏幕频率的 Ticker |
| `lib/ui/atoms/app_progress_indicator.dart` | 公共忙碌圆弧，复用 Material 圆弧但不启动其内部无限 Ticker |
| `lib/ui/features/home/controllers/chat_controller.dart` | 内容通知与会话状态通知分开，长草稿合并更新，最终状态取消待发批次并立即刷新 |
| `lib/ui/features/home/widgets/chat_message_view.dart` | 仅当前挂载消息的子树复用；按不可变消息、工具引用、renderer 注册和上下文变化失效 |
| `lib/ui/atoms/app_markdown.dart` | 未改变的兄弟 Markdown 块复用渲染子树，卸载后释放 |

全局限帧不丢 RPC 事件：数据照常进入 Controller，只推迟下一次显示。跳过 engine 帧时不能调用一半的 framework 回调，也不能让 `hasScheduledFrame` 卡住；更改上限会释放已有待处理请求。空闲时不轮询帧。Flutter 启动/热重载的 warm-up 帧不受限帧器延迟，它们不是常态动画。

持续动画由**一个共享 Timer**驱动，只有存在可见、未被减弱动态禁用的订阅者时运行。只筛掉高频 Ticker 的通知不能省掉请求帧的开销，因此不能改回“仍然 repeat，但偶尔更新 UI”。周期决定动画速度，帧率决定采样次数，两者独立。

`appearance.json` 新增字段示例：

```json
{"version": 1, "frameRate": 120, "animationFrameRate": 30}
```

缺失/非法字段分别回退 120 / 30；旧字段不迁移、不覆盖。可空后背字段兼容热重载前已存在的偏好实例。存储与失败重试沿用 [外观设置](appearance_settings.md)。

流式文本仍完整保存、最终消息仍由 Pi 权威替换；没有按空行硬拆 Markdown，避免破坏代码围栏、表格和跨段引用。详情见 [RPC 对话](rpc_chat.md#界面绘制与流式更新)。

## 审计证据与验证范围

修复前在 320Hz Windows 屏、Debug 窗口的运行等待阶段，实测约 267–294 FPS；可恢复对照中只绕过卡片模糊，帧率基本相近，GUI 3D 引擎占用从 14%–17% 降到 7%–8%，恢复后回到 14%–18%。另一组约 66 FPS 条件下，静默两处微光及一个转圈的 Ticker 后，5 秒为 0 帧、GPU 计数器为 0%，恢复后约 66 FPS / 3%–4%。两组运行条件不同，不能横向计算百分比。

修复后安全热重载到同一 Debug 进程，默认 120 / 30、保留材质时，一段 5 秒等待采样为 **149 帧（约 29.8 FPS）**，另三次 GPU 3D 采样为 **3% / 3% / 2%**。这是当前机器当前场景，不是所有会话/显卡的性能承诺，也不是长文本解析峰值或 Release 基准。

运行时只改限帧策略、不写用户偏好的对照：全局 30/60/120、持续动画 120 时，分别约 26.7/48.3/90.0 FPS；全局跟随屏幕、持续动画 30 时约 29.2 FPS，均未越过设置上限。结束后恢复当时用户偏好，不替用户重置选项。

验证命令：

```bash
flutter analyze --no-pub
flutter test --no-pub test/frame_pacer_test.dart test/appearance_test.dart test/chat_rpc_test.dart test/workbench_browser_test.dart
```

39 项相关测试通过。新增核心用例覆盖帧回调配对、唤醒合并、待处理帧切换/销毁、独立偏好往返/坏值、流批次不刷新会话状态及最终状态不留迟到批次。没有增加纯样式快照测试。

性能取样注意：VM Extension 流订阅时可能重放旧 `Flutter.Frame`，必须按帧 `startTime` 过滤当前采样窗口；不能直接用收到的事件总数算 FPS。详细 timeline 的环形缓存也可能只保留窗口末尾，应报告实际覆盖范围。临时探针位于系统临时目录，不作为产品入口或常驻采样器。
