---
title: "Pi GUI 首个界面设计与实现 (启动主页与设计系统)"
version: "1.3.0"
date: "2026-09-14"
status: "implemented"
type: "architecture-and-ui"
tags:
  - "flutter"
  - "antigravity-layout"
  - "misans"
  - "design-tokens"
  - "extensible-slots"
---

# Pi GUI 首个界面设计与实现 (启动主页与设计系统)

本文档记录本项目首个核心界面的设计决策、视觉系统、组件架构、数据模型以及面向后续 Agent 协作的对接指引。

---

## 1. 人类视角：界面功能与视觉导览

### 1.1 功能用途与布局

本界面为客户端启动后的默认入口视图（初始会话/快速开始工作台），布局参考 Antigravity 双栏设计，整体视觉参考 Novelai-harness 的 Notion 风格暖纸本/冷黑调色体系与 MiSans 屏显字体：

1. **沉浸式无边框标题栏 (`CustomTitleBar`)**：
   - 移除左上角多余的 4 个按钮与右上角 `OPEN IDE`。
   - 保留整条无缝拖拽区（支持双击最大化/还原）与 Windows 标准三键（最小化、最大化/还原、关闭），窗口按钮 Hover 配备 transitions.dev 平滑动效。
2. **左侧极简边栏 (`HomeSidebar`)**：
   - 顶部提供 `+ 新对话` 轻量矩形按钮（配备按压与悬停动效），通过 Pi RPC 新建会话。
   - 项目分组列表 (`Projects`)：以文件夹形式按项目归类会话（当前工作区 `pi-gui`），未产生历史会话时真诚展示空状态提示（`暂无历史对话`），支持文件夹顺滑折叠（带 90 度旋转与高度展开动效）。
   - 底部常驻 `Settings`（设置）入口，现已提供配色、基准字号和 UI 比例，见 [外观设置](appearance_settings.md)。
   - **遵循真诚克制原则**：彻底砍掉未开发的虚假导航（无计划任务、无假历史数据）。
3. **右侧主交互区 (`HomeStarterPanel`)**：
   - 空会话保持居中大卡片式启动台；开始发送后，同一输入组件移到底部，上方显示时间线。新建空会话回到居中。
   - 顶部提供当前活动工作区指示器（`📁 pi-gui`）。
   - 核心大输入框卡片：支持多行自适应输入与聚焦发光动效。模型选择器现已读取 Pi 的真实模型、思考等级并支持搜索，详见 [模型选择器 RPC 接入](model_picker_rpc.md)。发送箭头已接入真实 Prompt、流式回复、Markdown 与文件 Diff，详见 [RPC 对话界面](rpc_chat.md)。
   - **遵循真诚克制原则**：移除无后台支持的语音输入麦克风和无意义假下拉箭头，真诚显示运行环境与 Agent 状态。

### 1.2 零硬编码与语言支持

全量文案录入 `lib/l10n/app_zh.arb` 与 `lib/l10n/app_en.arb`，通过 `context.l10n` 动态取词，支持中英文即时切换。全量色彩与字号均基于语义令牌 `context.colors` 与 `context.textTheme`。默认保留原有亮暗配色，也可由 Windows 强调色或自选种子色生成 Material 3 色板，再叠加明暗独立的分区覆盖；`AppScale` 统一缩放路由和浮层。详见 [外观设置](appearance_settings.md)。

---

## 2. Agent 视角：模块结构与技术实现

### 2.1 关键代码路径与职责

| 层次 | 关键文件路径 | 核心类 / 职责说明 |
| :--- | :--- | :--- |
| **入口** | `lib/main.dart` | 桌面 `window_manager` 初始化、主题模式绑定、`MaterialApp` 路由根节点 |
| **设计系统** | `lib/ui/core/theme/app_tokens.dart` | 间距 `AppSpacing`、圆角 `AppRadius`、阴影 `AppShadows`、动效标尺 `AppDurations` / `AppCurves` / `AppMotionScales` (transitions.dev) |
| | `lib/ui/core/theme/app_colors_extension.dart` | Notion 暖纸本亮暗语义色板 `AppColorsExtension` |
| | `lib/ui/core/theme/app_theme.dart` | `ThemeData` 构建工厂、MiSans 字体绑定、全局 `TextTheme` 标尺 |
| | `lib/ui/core/theme/theme_context_extensions.dart` | 便捷语法糖 `context.colors`, `context.textTheme` |
| | `lib/ui/core/context_l10n.dart` | 便捷语法糖 `context.l10n` 强类型多语言代理 |
| **原子组件** | `lib/ui/atoms/app_action_button.dart` | 通用操作按钮（支持 primary, secondary, subtle, pill，内建 loading/hover/focus 态） |
| | `lib/ui/atoms/app_icon_button.dart` | 图标按钮（支持微质感 hover 反馈、点击回弹、圆形发送变体） |
| | `lib/ui/atoms/app_card.dart` | 卡片容器（支持 elevated 阴影、语义边框与圆角） |
| | `lib/ui/atoms/app_badge.dart` | 微型时间/状态指示徽章（中性、主色、成功色） |
| | `lib/ui/atoms/app_nav_tile.dart` | 侧栏条目与会话列表项原子组件（支持文件夹箭头、选中高亮、hover 动效） |
| | `lib/ui/atoms/custom_title_bar.dart` | 沉浸式标题栏（双击最大化、桌面拖拽区、三键） |
| | `lib/ui/atoms/window_controls.dart` | 桌面窗口控制复用状态机 `WindowControlsState` |
| | `lib/ui/atoms/slot_container.dart` | 标准动态插槽渲染容器，对齐 AGENTS.md 扩展规范 |
| **数据与插槽** | `lib/core/slots/slot_manager.dart` | `SlotManager` 单例，管理 6 大 extension_ui 插槽分发 |
| | `lib/core/models/chat_timeline.dart` | 聊天时间线与工具结果投影，RPC 事件关联 |
| **业务界面** | `lib/ui/features/home/views/home_view.dart` | 首页骨架，整合侧边栏、主工作区与全局遮罩插槽 |
| | `lib/ui/features/home/widgets/home_sidebar.dart` | 左侧功能与项目会话树状侧栏 |
| | `lib/ui/features/home/widgets/home_starter_panel.dart` | 两种布局共用的输入卡片 |
| | `lib/ui/features/home/widgets/home_chat_panel.dart` | 居中/底部布局切换、时间线与改动面板 |
| | `lib/ui/features/home/controllers/chat_controller.dart` | Prompt、停止、会话恢复与本次启动期间的会话书签 |

### 2.2 扩展槽位 (Extensible Slots) 映射机制

对齐 `AGENTS.md` 扩展槽位规范，当前已挂载预留的标准槽位容器包括：

1. `ExtensibleSlotId.aboveEditor`：挂载于输入框上方，用于后续 Pi RPC 派发任务待办、计划进度等小部件。
2. `ExtensibleSlotId.belowEditor`：挂载于卡片下方状态行中央，用于快捷建议与辅助提示。
3. `ExtensibleSlotId.statusBar`：挂载于窗口底部，显示 Pi 扩展派发的状态文字。
4. `ExtensibleSlotId.dialogOverlay`：以 `Positioned.fill` 放在 `MaterialApp.builder` 的全局 Overlay 中，位于普通路由（包括设置页）上方，用于对接 Pi RPC `select`, `confirm`, `input` 等全局阻断弹窗。
5. `ExtensibleSlotId.notificationToast`：悬浮于右上角，用于对接 `notify: info/warning/error` 全局消息。
6. `ExtensibleSlotId.sidebarPanel`：文件改动面板中的扩展区域。时间线另有 `ToolCardRegistry` 工具渲染注册表。

#### 注册与派发示例代码

```dart
// 向输入框上方挂载一个待办提示卡片
SlotManager.instance.setSlotWidgets(ExtensibleSlotId.aboveEditor, [
  MyTodoWidget(taskTitle: "Analyzing repository..."),
]);

// 派发完成后清空该槽位
SlotManager.instance.clearSlot(ExtensibleSlotId.aboveEditor);
```

### 2.3 当前 Pi RPC 接入范围

`HomeView` 已持有长期存活的 `PiRpcClient`。模型、等级和扩展 UI 的接口、生命周期及验证方式见 [模型选择器 RPC 接入](model_picker_rpc.md)。

后续功能必须复用这个客户端，并遵守 Pi 的 `type` 命令协议，不是 JSON-RPC 的 `method/params`：

- **发送 Prompt（已接入）**：`HomeStarterPanel.onSendPrompt` 经 `ChatController` 调用共享 RPC 客户端：

  ```json
  {"id":"req-1","type":"prompt","message":"用户输入的提示词"}
  ```

- **当前会话内容（已接入）**：使用 `get_messages` 与实时事件，会话切换使用 `switch_session`。侧栏历史列表由随 GUI 装载的公共后端扩展提供，Flutter 不直接读取 Pi 私有会话目录。
- **项目切换（已接入）**：通过共享工作区服务和 GUI 后端扩展完成，Pi 进程目录以服务层确认为准。协议与限制见 [工作区、历史会话与 Git Worktree](workspaces_sessions.md)。
