---
title: "扩展槽位与 Extension UI 动态挂载机制"
version: "2.0.0"
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

## 并行会话作用域

`WorkbenchSession` 为每个会话持有独立 `SlotManager`、输入控制器和 `PiExtensionUiBridge`。`SlotScope` 放在会话正文之上，`SlotContainer` 和输入框通过 `SlotManager.of(context)` 读取本会话的插槽 / editorAnchor；不能复制全局单例的 GlobalKey。单例只作为兼容默认值及全局浮层宿主。

- 后台 `setWidget` / `setStatus` 更新所属会话，`set_editor_text` 只更新其草稿。
- 后台问答排队并在侧栏显示“等待回答”，不抢占当前会话；切到所属会话后才投射到全局 `dialogOverlay`。
- 问答输入控制器按请求保存，切换前后台不丢未提交输入；不同会话相同请求 ID 使用不同 Widget key。
- 通知保留在所属会话的队列，切到前台后显示；后台通知不被静默丢弃。
- 前台切换先撤下旧会话浮层，再挂新会话；关闭 / 断开后台会话不能清空其他会话的全局浮层。
- 回复仍是原生 `extension_ui_response`，只在外层 `gui_channel` 中标注所属通道。超时取消的语义不变；没有重写扩展工具。

生命周期和协议见 [工作区与并行会话](workspaces_sessions.md)。

## 问答小卡片

Agent / 扩展通过 `select`、`confirm`、`input`、`editor` 向用户提问时，显示靠近聊天输入框的小卡片，不再统一居中：

- 默认放在输入卡片右上方，右边缘对齐、间隔 8px。上方放不下时尝试下方；长内容优先在可用空间内滚动，不盖住输入区。无可见输入框（例如正在设置页）时回退到窗口右下角。
- 最大宽度 **420px**、高度 **480px**，短问答按内容收缩；窗口边缘至少留 16px。长说明和选项在卡片内部滚动，选项左对齐并允许换行，不把重要文字省略掉；底部“取消 / 确认”始终独立于滚动区。
- 遮罩为主题 scrim 的 12%，减轻整屏被盖住的感觉，但仍阻止点击背后页面。点击选项提交原始值，取消或 Esc 返回取消；输入草稿不会因窗口缩放而重建。Tab 在问答焦点域内循环。
- 排队、超时、断连清理和 `extension_ui_response` 的语义不变。没有新增问卷协议或在 Flutter 中重写 `ask_user_question` 工具；本次覆盖的是已通过这些标准请求呈现的问答，外部工具自己的浏览器 / TUI 界面不受这个组件控制。

### 代码与协议

- `lib/core/slots/slot_manager.dart`：每会话 `editorAnchor` 只保存该输入框的 UI 锚点，`SlotScope` 提供组件作用域。
- `lib/ui/features/home/widgets/home_starter_panel.dart`：在实际输入 `AppCard.elevated` 上挂载锚点，空会话居中 / 有消息后到底部仍只有一个输入组件。
- `lib/ui/features/home/controllers/pi_extension_ui_bridge.dart`：`_ExtensionDialog` 复用 `AppDialog`、`AppActionButton`、`AppTextField`，通过 `anchorKey` 接收输入区位置；仍经 `dialogOverlay` 挂在普通路由上方。
- `lib/ui/atoms/app_dialog.dart`：统一锚点定位、避边、可用空间与滚动边界；布局后核对坐标以适应窗口缩放和同帧出现的入口，使用原有 `AppDurations` / `AppCurves` / `AppShadows`。

```json
{"type":"extension_ui_request","id":"question-1","method":"select","title":"这次采用哪种布局？","options":["靠近入口的小卡片","保持现在的布局"]}
{"type":"extension_ui_response","id":"question-1","value":"靠近入口的小卡片"}
```

安全热重载的独立 QA 验证了浅 / 深色、正常 / 窄视口、150% 文字、长说明与 30 个选项、编辑框、取消以及焦点链上的 Esc 回调。正常短问答实际为 **420×242**，输入框上方间隔 8px；560×400 下长问答限制为 **420×256**，末尾选项可滚动到达，取消按钮仍可见。测试只截图自建 QA 图层，不抓取其他窗口或活动聊天；临时代码已清理。

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
