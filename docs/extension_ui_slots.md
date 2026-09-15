---
title: "扩展槽位与 Extension UI 动态挂载机制"
version: "1.0.0"
status: "implemented"
type: "architecture"
tags: [flutter, pi-rpc, extension-ui, slots, pi-lens, todos]
---

# 扩展槽位与 Extension UI 动态挂载机制

## 用途与入口

为了对齐 Pi 官方丰富的插件生态（如任务跟踪 `todo` / `xtodo`、语言诊断 `pi-lens`、底层状态徽章等），pi-gui 在主界面中实现了符合 `AGENTS.md` 规范的**标准动态扩展槽位架构 (Extensible Slots)**。

所有插件无需修改自身代码、无需与 GUI 硬编码绑定，即可在与原生终端相同的相对位置无缝渲染。

### 核心布局位置对应

1. **输入框上方 (`aboveEditor`)**：
   - **典型插件**：任务卡片（如 `xtodo`、计划卡片、任务进度清单）。
   - **位置**：紧贴居中/底部输入卡片正上方。
   - **表现**：折叠/展开卡片，带有流畅的 150ms 自然减速过渡与图标状态提示。
2. **输入框下方 (`belowEditor`)**：
   - **典型插件**：代码与工作区诊断监控（如 `pi-lens` 的诊断列表、智能建议）。
   - **位置**：紧贴输入卡片正下方、在快捷键提示文本之上。
   - **表现**：自适应展开折叠卡片，支持警告/错误符号高亮（`!`、`⚠`、`✗`）。无活动内容时自动收缩为 0 高度，不占任何空间。
3. **底部状态栏 (`statusBar`)**：
   - **典型插件**：语言服务状态（如 `pi-lens-lsp`）、Token 统计、Git 分支信息。
   - **位置**：输入框下方的微型徽章区。
   - **表现**：圆角微标签 (`AppBadge`) 优雅横向排列。
4. **全局遮罩与弹窗 (`dialogOverlay`)**：
   - **典型插件**：插件主动发起的交互弹窗（如 `select`、`confirm`、`input`、`editor`）。
5. **全局通知 (`notificationToast`)**：
   - **典型插件**：插件发起的非阻塞通知 (`notify`)。

---

## 核心实现机制 (Agent 视角)

### 1. Pi RPC 组件工厂模式无缝拦截桥

Pi 官方扩展系统采用动态组件工厂函数机制：
```javascript
ui.setWidget("pi-lens", (tui, theme) => ({
  render: (width) => [ ...lines ]
}), { placement: "belowEditor" });
```
在原生 `pi --mode rpc` 模式下，官方后端会因为不是 TUI 而跳过函数型组件，导致 `pi-lens` 或类似插件默认被静默抑制。

pi-gui 在 `assets/backend/workspace_rpc.mjs` 中注入轻量发射拦截器：
- 注入 `AgentSession.prototype.bindExtensions`，对外传递 `options.mode = "tui"`，通知插件当前宿主环境具备完整的可视化交互插槽能力。
- 拦截 `uiContext.setWidget`：当传入函数时，自动构造 `mockTui` 实例并执行初始渲染与注册 `requestRender()` 监听。
- 当插件调用 `tui.requestRender()` 时，重新调用 `render(80)`，并以标准单行 JSONL `extension_ui_request` (method: `setWidget`) 派发至 Flutter 前端。

### 2. 前端事件路由与动态渲染

- **桥接控制器**：[`lib/ui/features/home/controllers/pi_extension_ui_bridge.dart`](../lib/ui/features/home/controllers/pi_extension_ui_bridge.dart)
  - 监听所有 `extension_ui_request` 事件。
  - 根据 `widgetPlacement` 路由至 `ExtensibleSlotId.aboveEditor` 或 `ExtensibleSlotId.belowEditor`。
  - 内容为空（如 `pi-lens` 在无警告且静默时派发的 `widgetLines: []`）时，自动从插槽注销，保证无任何空白 padding 冗余。
  - 内容包含文本时，自动挂载 `_ExtensionWidgetView`，并通过识别 key 及行前缀自动赋予语义化图标与颜色（如错误、警告、进度、完成）。
- **插槽原子组件**：[`lib/ui/atoms/slot_container.dart`](../lib/ui/atoms/slot_container.dart)
  - 仅在有活动 Widget 时渲染，遵循零硬编码与语义 Token 规范。
- **界面组装**：[`lib/ui/features/home/widgets/home_starter_panel.dart`](../lib/ui/features/home/widgets/home_starter_panel.dart)
  - 统一在输入卡片上下方挂载对应 `SlotContainer`。
