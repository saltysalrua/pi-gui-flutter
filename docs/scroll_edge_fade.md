---
title: "固定底栏上方的渐变边缘"
version: "1.0.1"
status: "implemented"
type: "ui-detail"
tags: [flutter, scroll, sidebar, chat, glass]
---

# 固定底栏上方的渐变边缘

## 界面效果

- 左侧项目 / 会话列表靠近底部「账号额度」区域时，文字在最后 24 个逻辑像素内渐渐淡出。
- 聊天记录靠近底部输入区时，在最后 32 个逻辑像素内使用相同效果。
- 滚到最底部时，渐变带随剩余滚动距离缩短并消失，让最后一行完整可读；仍有溢出内容时最下缘始终完全透明，避免半透明文字被硬切。内容不足一屏时不淡出。聊天的倒序列表也按屏幕下边缘计算。
- 开始对话后，输入区不再保留原先的 8px 顶部空白，时间线延伸到输入区上沿，消除渐变与输入区之间的空缝；输入框本身的位置和空态布局不变。
- 不增加分隔线、阴影或实色遮罩；深浅主题、自选背景和桌面毛玻璃仍使用原来的背景。账号额度、设置、输入框及「回到最新消息」按钮不参与淡出，点击、文本选择与滚轮操作不变。

参考 [shadcn/ui scroll-fade](https://ui.shadcn.com/docs/utils/scroll-fade) 的透明度遮罩与滚动边界行为，不添加依赖或新的设置。

## Agent 入口与边界

| 路径 | 职责 |
| --- | --- |
| `lib/ui/atoms/app_scroll_edge_fade.dart` | 公共 `AppScrollEdgeFade(child, extent)`，默认 `AppSpacing.xxl`，只淡出垂直滚动区域的物理下边缘 |
| `lib/ui/features/home/widgets/workbench_sidebar.dart` | 包住项目列表，不包住底部账号额度与设置入口 |
| `lib/ui/features/home/widgets/home_chat_panel.dart` | 包住时间线 ListView，使用 `AppSpacing.xxxl`；回到最新按钮保留在外层 Stack |

`AppComposerLayout` 的测量、空态居中 / 开始后沉底、输入扩展槽位及 PageStorage 滚动锚点不变。本功能是纯 UI，无 Controller / Service 改动，不增加或修改 Pi RPC 命令、事件、存储结构。

内部接收 `ScrollNotification` 和 `ScrollMetricsNotification`，后者覆盖初始布局、窗口尺寸变化和列表增减。仅处理 `depth == 0` 的垂直通知，忽略工具输出 / 代码块内层滚动，不吞掉通知。普通列表采用 `extentAfter`，倒序列表采用 `extentBefore`，值夹在 `0..extent`，作为下边缘渐变带高度；到达下边缘时变为 0。渐变带大于 0 时从不透明渐变到完全透明，不能用剩余距离抬高末端 alpha，否则临近底部会出现硬边。

`ShaderMask` 使用 `BlendMode.dstIn`，只改变内容 alpha；取主题色作为遮罩 RGB，不绘制第二层背景。遮罩子树保持挂载，不能通过到边缘时移除包装来重建滚动体。`ValueListenableBuilder.child` 保留列表子树，不因渐变带高度更新重新构建全部列表。不增加计时器、Ticker 或延迟动效；减弱动态模式同样直接跟随滚动位置。

## 验证

三个变更 Dart 文件通过定向 LSP 检查，并已在运行中的 Windows 应用热重载。读取真实实例确认侧栏为 24px 淡出，跟随最新消息时聊天下边缘渐变带高度为 0；通过 Flutter inspector 定向截取侧栏确认底部文字渐隐。不热重启、不重发 Prompt、不替换活动聊天。

视觉复查：长列表滚动到中段与底部、短列表、聊天上翻与回到最新、窗口高度变化、深浅主题 / 毛玻璃，以及输入区和底栏按钮仍可正常操作。纯展示效果不新增永久 Widget 测试。
