---
title: "斜杠命令：菜单、补全与内置命令 GUI 适配"
version: "1.0.1"
status: "implemented"
type: "feature-and-architecture"
tags: [flutter, pi-rpc, slash-commands, composer]
---

# 斜杠命令：菜单、补全与内置命令 GUI 适配

## 给人看的功能说明

聊天输入框里输入 `/` 会弹出命令菜单，继续输入可以按名称/说明过滤：

- **↑ ↓** 在候选之间移动，**Tab** 把选中命令补全进输入框，**Esc** 关闭菜单。
- 单独输入一个 `/` 就会展示全部命令；继续输入可以按名称/说明过滤。
- 补全后光标停在命令名后的空格处，直接输入参数即可；**Enter** 发送。
- 菜单与输入卡片等宽，靠近窗口左右边缘时自动限位；总高（含边框和内边距）不超过上方可用空间，最高 320，超出部分在菜单内滚动。缩放窗口时同步跟随，不会因最低高度顶出窗口。
- 用 **↑ ↓** 移动时，选中项会自动滚到可见位置；鼠标点选或 Tab 补全后收起菜单、保留输入焦点。输入框失焦时也会收起菜单。
- 菜单里既有 Pi 返回的命令（扩展、提示模板、技能），也有 GUI 自己适配的内置命令（`/new`、`/compact`、`/name`、`/model`、`/resume`、`/tree`、`/fork`、`/clone`），每项右侧有来源徽章。

一个重要行为：**Pi 的终端专用命令（如 `/settings`、`/reload`、`/quit`）经 RPC `prompt` 发送时会被当作普通文本喂给模型**（实测 Pi 0.87.1，agent_start 后原样进入上下文）。GUI 在发送前拦截这类命令，在输入框上方提示"只在 pi 终端里生效"，不会发给模型。

## 内置命令的 GUI 映射

| 命令 | GUI 行为 | 底层 |
|---|---|---|
| `/new` | 新建会话 | `ChatController.changeSession` → RPC `new_session` |
| `/compact [说明]` | 压缩当前上下文，可带自定义说明 | `ChatController.compact` → RPC `compact` (`customInstructions`) |
| `/name [名称]` | 带参数直接改名；无参数弹改名对话框 | `ChatController.rename` → RPC `set_session_name` |
| `/model` | 打开模型/思考档浮层 | `showModelThinkingPopover`（纯 UI） |
| `/resume`、`/tree` | 打开历史对话框 | `HistoryController`（`gui_history` 桥） |
| `/fork` | 历史对话框-分叉动作 | 同上，`PiHistoryAction.fork` |
| `/clone` | 历史对话框-复制动作 | 同上，`PiHistoryAction.clone` |

其余终端命令（`settings`、`thinking`、`scoped-models`、`login`、`logout`、`llama`、`session`、`import`、`copy`、`export`、`share`、`bug`、`trust`、`reload`、`hotkeys`、`changelog`、`quit`）没有 GUI 等价物：菜单中带"终端"徽章展示，发送时拦截并提示。

## 给 Agent 看的实现路径

### 关键代码

| 职责 | 文件 |
|---|---|
| RPC 类型与网关接口 | `lib/core/rpc/pi_chat_types.dart`（`PiSlashCommand`、`PiCommandGateway`、`PiChatGateway.compact/setSessionName`） |
| RPC 调用 | `lib/core/rpc/pi_rpc_client.dart`（`get_commands` / `compact` / `set_session_name`；`compact` 计入 conversation-mutation 写屏障） |
| 命令数据源 | `lib/ui/features/home/controllers/slash_command_controller.dart` |
| 纯逻辑（解析/过滤/映射） | `lib/ui/features/home/slash_commands.dart` |
| 菜单浮层 | `lib/ui/features/home/widgets/slash_command_menu.dart` |
| 输入框接入（键盘/补全/分发） | `lib/ui/features/home/widgets/home_starter_panel.dart` |
| 动作接线（compact/rename/历史） | `lib/ui/features/home/widgets/home_chat_panel.dart`、`ChatController` |
| 会话级实例 | `WorkbenchSession.commands`（`workbench_controller.dart`） |

### RPC 与数据结构

`get_commands` 响应（实测 Pi 0.87.1，51 条命令）：

```json
{
  "commands": [
    {
      "name": "fix-tests",
      "description": "Fix failing tests",
      "source": "extension" | "prompt" | "skill",
      "sourceInfo": { "path": "...", "source": "...", "scope": "..." }
    }
  ]
}
```

- 解析在 `PiSlashCommand.fromJson`；单条畸形条目被 `piSlashCommands` 跳过，不拖垮整个列表。
- `source` 保留原始字符串，未知来源按"扩展"徽章渲染。
- 注意：**内置 TUI 命令不在 `get_commands` 里**，需经 `prompt` 才会执行的只有扩展/模板/技能命令。

### 分发规则（`_sendPrompt` in HomeStarterPanel）

发送前按首个 `/` token 分流，顺序固定：

1. `ensureLoaded()` 拿权威命令表（缓存未就绪时绝不拦截，避免误杀远端命令）；
2. 命令名命中 `get_commands` 结果 → 正常走 `prompt`（保留扩展斜杠语义与排队行为）；
3. 命中 `slashBuiltins` 映射 → 本地执行（`onSlashBuiltin` 回调返回 true 后清空输入框；`/model` 由输入面板直接处理）；
4. 命中 `terminalOnlySlashCommands` → 拦截，输入框上方显示 `slashCommandUnsupported` 提示；
5. 其他未知 `/xxx` → 照常 `prompt`（不破坏 Pi 的扩展命令直通语义）。

同名冲突时远端命令优先（`mergeSlashEntries`）。

### 缓存与失效

`SlashCommandController` 懒加载：菜单首次可见才调用 `get_commands`。监听 `client.events`，在 `agent_settled`（如 `/reload` 类扩展命令可能改命令表）、`PiRpcSessionChanged`、`PiRpcWorkspaceChanged/Reset`、`PiRpcDisconnected` 后仅标记 stale，下次打开菜单重读；失败保留旧列表可用，不置空。

### 键盘与浮层

- 浮层用 `OverlayPortal.overlayChildLayoutBuilder` 直接包裹输入卡片 `AppCard.elevated`，在布局阶段通过 `OverlayChildLayoutInfo` 取得卡片和 Overlay 的本帧坐标/尺寸；不入 root navigator，不阻塞其他交互。保留 `SlotManager.of(context).editorAnchor`，输入框上下的扩展槽位不计入菜单锚点。
- **限位**：`Positioned` 显式设置菜单宽度、左边界和底边锚点，解除 Overlay 默认的全屏 tight 约束。最大高度取卡片上方剩余空间与 320 的较小值，扣除间隙/安全边距，无强制最低高度；`ConstrainedBox` 必须在 `AppCard` 外，确保边框、内边距都计入总高。窗口缩放或输入框增高后同帧重新布局，不能在 build 阶段读上一帧 RenderBox 尺寸。
- **滚动与焦点**：`SlashCommandMenu` 持有独立 `ScrollController`，行高按主题字体与文字缩放计算，选择变化后把目标行滚入视口。使用 `TextFieldTapRegion` + `ExcludeFocus`，点选/拖动滚动条不抢输入焦点；补全会写入命令名后的空格，自然关闭菜单。Esc 关闭后不再拦截方向键/Tab；失焦收起浮层。
- **单独 `/`**：`slashMenuQuery` 与 `parseSlashToken` 是两个函数——前者允许空命令名（返回空串→菜单展示全量），后者发送分发仍拒绝空名。别再把两者合并。
- 入场动效：scale `AppMotionScales.dropdown`(0.97)→1.0 + fade，`AppDurations.fast`(250ms) + `smoothOut`；`disableAnimations` 时瞬时。
- 键盘拦截在 `FocusNode.onKeyEvent`（IME composing 期间让路）：Esc 关菜单（优先于"停止"）、↑↓ 循环选择、Tab/非精确 Enter 补全；精确匹配的 Enter 正常发送走分发。

### i18n 与测试

- 文案全部在 `lib/l10n/app_zh.arb` / `app_en.arb`（`slash*` 前缀 + `chatCompactFailed`/`chatRenameFailed`），生成物经 `flutter gen-l10n`。
- `test/slash_command_test.dart`：JSON 解析、光标语义、过滤排序、远端优先合并、控制器失效重读、`ChatController.compact` 的忙会话守卫与 `rename` 投影。
- `test/chat_rpc_test.dart` 的 `FakeChatGateway` 随接口扩展了 `compact` / `setSessionName`。