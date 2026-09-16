---
title: "文档标签页与并排分组"
version: "2.0.0"
status: "implemented"
type: "feature-and-architecture"
tags: [flutter, tabs, workspace, diff, layout]
---

# 文档标签页

## 使用方法

主内容区采用 [VS Code 标签页与编辑器分组](https://code.visualstudio.com/docs/editing/getting-started/userinterface#_tabs) 的方式：多个文档在同一个应用窗口里打开，不再为每个文件弹出阻断式 Diff 弹窗。这是**主内容区标签页**，不是浮动面板，也不是操作系统多窗口。

- **聊天**支持多个独立会话标签，可以关闭、排序和移到其他分组。切到文件或另一会话不会停止 Agent；每个会话保留自己的草稿、附件、时间线和输入状态。空对话输入居中，发送第一条消息后才移到底部。并行运行和关闭确认见 [工作区与会话](workspaces_sessions.md)。
- 点击标签栏右侧的 **文件与 Git** 文件夹图标打开原来的右栏。文件树、Git graph 和扩展侧栏插槽保持原样；点击文件、提交或提交里的文件，分别打开文件预览、提交详情或提交 Diff 标签。
- 每次打开新文档都会保留标签，不采用“单击覆盖上一个临时预览”的模式。同一工作区、路径、提交版本的文档只保留一份，再次点击会定位它；工作目录与不同提交是不同标签。
- 文件标签显示简短文件名，提交版本补短 hash。悬停查看完整工作区、相对路径和完整 hash，同名文件可据此区分。正文保留只读标记，**文件内容 / Diff** 图标切换与原来的已暂存 / 未暂存区分不变。
- 点标签上的 **×** 或鼠标中键关闭；关闭当前标签后选择邻近标签。运行中或有草稿的会话先确认；文件直接关闭。最后一个标签关闭后保留新建会话入口，不关闭应用。
- 标签栏可水平滚动，鼠标滚轮也能横向浏览；下拉箭头打开 **所有标签页**，可从其他分组或被挤出可见区域的标签中直接选择。选择后自动滚到该标签。

### 排序、并排与合并

1. 在同一标签栏拖动标签调整顺序；目标前后有插入位置提示。
2. 选中会话或文件标签，点 **移到右侧新分组** 图标，或在 **标签页操作** 菜单中选择同名操作。文档会移动到右侧分组，可以与其他会话 / 文件并排查看；移动不复制正文，也不额外启动 Agent。新建会话才创建独立运行通道。
3. 拖动两个分组之间的 10px 区域调整宽度，双击恢复等分。静止时不显示分隔线，悬停 / 拖动时才显示手柄。
4. 把标签拖到另一个分组的标签栏，就会移入该组。原分组的最后一个标签移走或关闭后，空分组自动消失。
5. **标签页操作 → 合并所有标签页** 将所有分组合并，保留当前选中文档；**关闭其他标签页** 按同样的关闭确认规则逐项处理，保留当前文档。

同一组只有一个文档时，不提供无意义的继续拆分。可建立多个横向分组；每组至少留 300 逻辑像素。可用宽度不够时只显示当前活动组，其余文档仍可从“所有标签页”访问；放大后恢复原分组和宽度比例，不自动关闭文档。不实现上下分组或窗口外拖出。

### 键盘

焦点位于文档区或标签栏时：

| 操作 | 快捷键 |
| --- | --- |
| 关闭当前文件标签 | Ctrl+W / Ctrl+F4 |
| 当前组下一个标签 | Ctrl+Tab / Ctrl+PageDown |
| 当前组上一个标签 | Ctrl+Shift+Tab / Ctrl+PageUp |
| 标签栏内切换 | 左 / 右方向键 |

会话标签同样响应关闭命令，但运行 / 草稿确认不能被快捷键绕过。所有菜单和按钮沿用公共组件的键盘 Focus / Hover / Disabled 状态。标签栏高度跟随主题字号与系统文字缩放，选中反馈及正文渐显使用 Motion Tokens；减弱动态时直接切换。

## 状态与刷新边界

- 标签和分组是**本次应用运行期间的 UI 状态**，不写入 `appearance.json`、Pi 会话或其他后端私有文件；重启后从空会话开始。
- 跨项目切换也保留已打开文档。每份文档身份包含工作目录；每目录独立浏览 Controller，不把前一个目录的数据错误套到另一个目录。右栏跟随当前活动文档的目录。
- 文档第一次打开时读取一次。普通切页、拖拽、拆分、合并不会重新读取，也不占用聊天操作锁。关闭文档会释放预览快照。
- 已打开文档是只读快照，不是实时编辑器。正文右上角 **重新读取此预览** 只刷新该文档；右栏“刷新文件与 Git”仍只刷新目录 / Git 列表。失败显示原有的人话错误提示和重试按钮；不把旧快照说成最新结果。
- 每个文档有独立的滚动存储，内容 / Diff 两页保持挂载；隐藏文档不接收焦点，停用内部 Ticker。每个会话仅挂载一次，使用自己独立的 SlotManager / editorAnchor；前台问答投射到全局遮罩。

## 代码结构

| 路径 | 职责 |
| --- | --- |
| `lib/ui/core/app_tabs_controller.dart` | 泛型标签 / 分组状态机：去重、激活、关闭、排序、跨组移动、拆分、合并与固定首页 |
| `lib/ui/atoms/app_document_tabs.dart` | 通用横向标签栏、选中 / 悬停 / 焦点、关闭、拖拽目标、滚动与自动可见性 |
| `lib/ui/atoms/app_tab_workspace.dart` | 通用文档宿主、横向分组、窄窗单组、分组菜单 / 快捷键、状态与正文布局 |
| `lib/ui/features/home/controllers/workspace_tabs_controller.dart` | `WorkspaceDocument` 身份与工作区隔离；关联已有浏览 Controller |
| `lib/ui/features/home/widgets/workspace_document_view.dart` | 文件 / 提交的只读正文与异步快照；复用 AppCodeBlock / AppDiffView / AppIconTabs / AppNavTile |
| `lib/ui/features/home/widgets/workspace_browser_panel.dart` | 通过 `onOpenFile` / `onOpenCommit` 回调打开标签，不自行操作 Navigator |
| `lib/ui/features/home/widgets/home_chat_panel.dart` | 每会话两态输入与时间线；生产使用 conversationOnly 模式，由 HomeView 统一装配标签与右栏 |
| `lib/ui/features/home/views/home_view.dart` | 装配全局标签宿主与每会话 SlotScope，串行关闭确认 |
| `lib/ui/features/home/controllers/workbench_controller.dart` | WorkbenchTabs / WorkbenchSession、多个会话和每目录浏览 Controller；唯一物理连接由 PiChannelHub 持有 |
| `test/app_tabs_controller_test.dart` | 标签 / 分组不变量与工作区迟到响应回归 |

### 不重新挂载正文

`AppTabWorkspace` 不为每组各创建一个 IndexedStack，也不用随激活项换 key 的 AnimatedSwitcher。所有文档的正文始终是**同一扁平 Stack 的带身份 key 的兄弟节点**：分组仅改变 Positioned 的位置、宽度和可见性。

- 标签全局插入顺序与各组显示顺序分开保存；拖动只改变组内顺序，正文节点顺序稳定。
- 隐藏正文使用 Offstage / ExcludeFocus / TickerMode，恢复时仅渐显，不重复构造编辑器 State。
- 每个正文宿主持有独立 `PageStorageBucket`，避免不同文件的同名内容 / Diff 滚动 key 串页。
- 分组背景透明，仍由原来的 AppSplitPanel 单次绘制主区和右栏，不覆盖半透明底色；没有改原生材质通道。

### 扩展新文档类型

公共 Controller 和原子组件对 RPC、文件系统、聊天、Git 都无依赖。新的业务类型只需提供稳定且可比较的文档身份、`AppDocumentTab` 元数据与正文 builder。

当前业务描述示意（内存身份，不是新增 RPC 或持久化格式；聊天加入 sessionId）：

```json
[
  {"kind":"chat","sessionId":"session-a","workspace":"D:\\project"},
  {"kind":"chat","sessionId":"session-b","workspace":"D:\\project"},
  {"kind":"file","workspace":"D:\\project","path":"lib/main.dart","commit":null},
  {"kind":"file","workspace":"D:\\project","path":"lib/main.dart","commit":"0123456789012345678901234567890123456789"},
  {"kind":"commit","workspace":"D:\\project","commit":"0123456789012345678901234567890123456789"}
]
```

`AppTabsController.move(tab, groupId, index: ...)` 的 index 是**移动之前**目标列表的插入边界；同组向右移动会扣除原位置。默认仍保护固定首页，WorkbenchTabs 使用 `pinHome: false`，并在关闭旧首页前转移 fallback 身份，避免出现空分组。DragTarget 只接受同一个 Controller 的拖拽 payload，不接收另一宿主或外部文件拖放。

### RPC

文档查看本身不增加 Agent 进程；多会话的通道管理见 [工作区与会话](workspaces_sessions.md)。每目录通过自己的 `WorkspaceBrowserController` 和共用管理通道使用：

- `gui_get_file_preview`：`workspace`、`path`、可选完整 `commit`，返回 `PiFilePreview`。
- `gui_get_git_commit`：`workspace`、完整 `commit`，返回 `PiCommitDetails`。
- 原有 `gui_list_files` / `gui_get_git_graph` 只供右栏读取。

沿用浏览 Controller 的 generation 和工作区返回值检查。关闭页面后的 FutureBuilder 会丢弃迟到快照；切换工作区的旧请求不会落进新文档。只读限制、256 KiB 预览上限、符号链接 / 路径防护、首次 / 合并提交 Diff 语义均见 [工作区浏览](workspace_browser.md)。

## 验证

```bash
flutter analyze --no-pub
flutter test --no-pub test/app_tabs_controller_test.dart test/workspace_browser_test.dart
flutter test --no-pub
flutter build windows --release --no-pub -t lib/main.dart
```

核心回归覆盖全局去重、前后插入索引、固定聊天、跨组移动 / 最后标签关闭、相邻选择、合并顺序、循环快捷切换，以及 500 次确定性混合操作的不变量；另验证工作区 / 提交身份与迟到预览隔离，不增加永久纯展示 Widget 测试。

界面验证采用安全热重载下的独立临时预览，复用生产标签栏 / 分组宿主 / 右栏 / 文档正文；预览数据为明确的测试夹具，不启动 Agent、不修改活动聊天或工作区。截图只读取 QA 自身 RenderRepaintBoundary，不采集其他窗口。

- 最终 `flutter analyze --no-pub` 无问题；标签 / 浏览核心 **9 项通过**，全套 Flutter **77 项通过**，Windows Release 构建成功。
- 真实 Flutter 指针事件走查文件树打开与重复定位、左右排序、拆分按钮、跨组拖回合并、中键关闭、分组调宽，以及溢出菜单选择；实际键盘分发验证 Ctrl+W。自动滚动在返回最左侧聊天标签时也正常，不再只向末尾滚动。
- 浅 / 深色、480px + 150% 文字、300px + 150% 文字的提交 Diff，以及减弱动态均无运行时异常；窄窗只显示活动组，放大恢复原分组。长 Diff 标题可换行省略，不挤出计数 / 复制按钮。
- 切页、排序、合并和分组过程中，隔离输入编辑器始终 **1 次挂载、0 次销毁**，草稿保持不变；居中 / 底部两态的布局位置也完成检查。同一普通文件重复打开只读取一次；另一个提交版本会单独读取。
- 临时预览、入口和旧 `workspace_browser_dialog.dart` 已移除，`lib/main.dart` 没有 QA 差异，正式代码已热重载回当前窗口。没有 hot restart、关闭 GUI / Pi 或改变活动会话。

QA 注意：本机 Flutter beta 的 FocusManager 仍从 `KeyMessage` 接收键盘分发。仅调用 `HardwareKeyboard.handleKeyEvent` 不等于事件已送达 Focus 树；需沿当前 SDK 的键盘分发链验证，不能据此误判快捷键失败。
