---
title: "右侧文件树、Git graph 与毛玻璃"
version: "1.1.0"
status: "implemented"
type: "feature-and-architecture"
tags: [flutter, workspace, git, graph, diff, acrylic, rpc]
---

# 右侧文件与 Git

## 入口与操作

点击主内容标签栏右侧的 **文件与 Git** 文件夹图标，展开右栏。空会话也有这个入口，输入卡片仍保持居中；发送第一条消息后才移到底部。右栏替代原来的“本会话文件改动汇总”，只有 **文件**、**Git graph** 两个图标页签，不增加提交、暂存、切分支等写操作。

- 默认宽 **300 逻辑像素**，左边缘可拖拽，双击恢复默认。普通窗口最小 240、最大 640，并至少给聊天保留约 360px。聊天区域不足 640px 时改为覆盖式右栏，点击左侧遮罩关闭；不重置原来记住的宽度。
- 两个页签及关闭 / 重开保留已读取的数据和展开目录。切换工作区会清空旧目录、提交列表和选中项；切换同一工作区的聊天会话不清空工作区浏览状态。
- 右上角刷新只读取文件和 Git，不同步聊天、不发送 Prompt，也不切换模型。文件工具执行完和 Agent 停稳后合并刷新，窗口重新获得焦点时也刷新已打开的右栏。关闭右栏不做后台轮询；外部程序的改动可点刷新确认。
- 参考用户提供的紧凑文件树截图与 [VS Code Git Graph](https://marketplace.visualstudio.com/items?itemName=mhutchie.git-graph) 的提交连线、引用标记和按需查看详情，不照搬其仓库写操作。

### 文件页

显示当前工作区真实目录，文件夹排在文件前面。点击文件夹展开，按需读取下一层，不递归扫描磁盘。隐藏文件和 Git 忽略文件仍可见，`.git` 管理目录 / 文件不显示。文件夹箭头支持键盘左右键，文件行沿用公共导航行的键盘激活、Hover 与 Focus。

| 标记 | 含义 |
| --- | --- |
| 低调的勾 | 已提交且无改动 |
| `M` | 修改；悬停区分暂存区和工作目录 |
| `A` | 新增；是否暂存看悬停说明 |
| `D` | 删除，仍保留可选条目以查看 Diff |
| `R` | 重命名 |
| `?` | 未跟踪 |
| `−` | Git 忽略 |
| `U` 或冲突代码 | 存在冲突 |
| `·` | 没有 Git 状态，例如普通非仓库文件夹 |

`MM` 等双字母保留 Git 的暂存区 / 工作目录两列信息。目录状态汇总其后代，冲突和删除优先；干净文件不因界面选中而假装发生修改。删除整个已跟踪目录时，仍可展开查看其中被删文件；稀疏检出中刻意不落盘的干净文件不伪装成删除。

点击文件在主内容区打开只读**标签页**，不再弹出阻断式窗口；**文件内容 / Diff** 两页可切换。同一文件重复点击会定位已有标签。多个标签可以拖动排序、分组并排查看、拖回同一组或一键合并；详见 [文档标签页](document_tabs.md)。Diff 将已暂存、未暂存分别列出，避免两者抵消后误报“没有改动”；重命名使用已确认的旧 / 新路径。二进制变更、只改文件权限或纯重命名没有文本 hunk 时显示 Git 元数据，而不是空白 Diff。时间线中每次工具调用的原始 Diff 仍留在工具展开区；工具上的右栏入口会展开目标文件的祖先目录。

从仓库子目录作为工作区启动时，文件树限制在该子目录。展开子模块或嵌套仓库后，内部文件读取自己的 Git 索引与状态，不误标成外层仓库的未跟踪文件。Git graph 始终针对**当前工作区所在仓库**，不会把所有嵌套仓库混成一张图。

### Git graph 页

按 Git 拓扑顺序显示提交，包含本地分支、远程跟踪引用和标签；不联网 fetch。当前 HEAD 的圆点带外圈，标题使用强调色；提交行显示说明、引用 / 作者、短 hash 和日期，悬停查看完整内容。分叉和合并依据真实 `parents` 绘制，不根据提交时间猜连线。

点击提交打开详情标签，查看完整 hash、作者、时间、提交说明与文件列表；点击其中的文件打开对应提交的 Diff 标签。工作目录版本和不同提交分别保留，不会互相覆盖。合并提交与**第一个父提交**比较，首次提交与空内容比较，界面明确说明这一点。工作区是仓库子目录时，图仍显示整个仓库历史，但详情只列工作区内的文件。跨工作区边界的重命名分别视作移入新增或移出删除，不暴露工作区外的文件预览。

无 Git、未安装 Git、空仓库、权限失败和旧后端都有对应的人话提示。Git 不可用时仍能浏览普通文件；错误不会被显示成“所有文件都已提交”。

## 毛玻璃与布局

右栏跟随 **设置 → 外观 → 桌面毛玻璃 → 顶部与侧边栏** 的开关、颜色和底色不透明度，不增加第三个桌面材质通道，也不会代开用户的毛玻璃选项。

- `HomeView` 的 `AppDesktopScaffold.contentBackground` 为透明；主页内的 `AppSplitPanel` 单次绘制互不重叠的主区 / 右栏矩形。标题栏和左栏仍由原外壳绘制，设置页不改动。
- 右栏和 10px 拖拽条本身透明，没有纯色 `ColoredBox` 或卡片叠在主背景上。覆盖式窄栏还会裁掉右栏后方的聊天内容，防止输入框或消息透到栏内。
- `WindowMaterialScope.tint` 只在原生材质 `active` 且非高对比度时允许透明；否则各区立即回退纯色。沿用已有 Windows Acrylic，不修改原生 C++、系统透明设置或用户外观偏好。
- 普通停靠栏展开 / 收起使用 slow 400ms / medium 350ms；窄窗阻断浮层使用 fast 250ms / quick 150ms。拖拽即时更新，切页 quick 150ms；减弱动态时立即完成。尺寸动画驱动同一份布局与背景边界，不产生重叠 tint。
- `HomeChatPanel` 的空态 / 会话态始终使用同一个 `AppComposerLayout`。外层 `AppTabWorkspace` 把聊天与文档正文放在同一扁平 Stack 下，切页、排序与跨组移动不会重新挂载编辑器；右栏入口位于当前活动组的标签栏。

材质原理、系统回退与独立卡片毛玻璃见 [外观设置](appearance_settings.md)。

## 后端与数据边界

复用 HomeView 唯一的 `PiRpcClient`。新增命令属于 GUI 本地 JSONL 适配层，不是捏造的 Pi 官方命令；不创建第二个 Agent，也不让 Flutter 调用 `Process` 或扫描工作区。

```text
HomeView ─ 唯一 PiRpcClient
  ├─ ChatController / ModelPickerController / WorkspaceController / PiExtensionUiBridge
  └─ WorkspaceBrowserController
       │ strict JSONL
       ▼
workspace_rpc.mjs ─ WorkspaceBrowser（workspace_browser.mjs）
       ├─ 只读目录 / Git 查询
       └─ 原有唯一 pi --mode rpc 子进程保持不变
```

| 命令 | 主要请求字段 | 返回实体 |
| --- | --- | --- |
| `gui_list_files` | `workspace`, `path`, `force?`, `limit?` | `PiDirectoryListing`、`PiFileEntry` |
| `gui_get_git_graph` | `workspace`, `force?`, `limit?` | `PiGitGraph`、`PiGitCommit` |
| `gui_get_git_commit` | `workspace`, `commit` | `PiCommitDetails`、`PiCommitFile` |
| `gui_get_file_preview` | `workspace`, `path`, `commit?` | `PiFilePreview` |

所有请求携带已确认的绝对 `workspace`。后端先与当前目录核对，返回值也携带工作区；前端用工作区 generation、刷新 revision 和请求身份隔离迟到结果。旧目录响应 / 预览不能覆盖新目录；刷新重入会合并并执行一次强制尾随读取。错误保留上一份已确认列表并提示失败，不声称它已经刷新成功。目录切换互斥期间拒绝读取，Agent 正常运行期间允许只读查询，不占聊天操作锁。

```json
{"id":"gui-1","type":"gui_list_files","workspace":"D:\\project","path":"lib","force":true,"limit":500}
{"type":"response","id":"gui-1","command":"gui_list_files","success":true,"data":{"workspace":"D:\\project","path":"lib","branch":"main","git":true,"gitWarning":null,"hasMore":false,"entries":[{"name":"main.dart","path":"lib/main.dart","directory":false,"symlink":false,"missing":false,"status":"modified","indexStatus":"M","worktreeStatus":"M"}]}}
{"id":"gui-2","type":"gui_get_git_graph","workspace":"D:\\project","limit":100}
{"id":"gui-3","type":"gui_get_git_commit","workspace":"D:\\project","commit":"0123456789012345678901234567890123456789"}
{"id":"gui-4","type":"gui_get_file_preview","workspace":"D:\\project","path":"lib/main.dart"}
```

### 只读、路径与大小限制

- Git 由 Node `execFile` 传递参数，不拼 shell；开启 `--literal-pathspecs`、关闭可选索引锁与 fsmonitor，Diff 禁止 external diff / textconv。所有分支、提交与内容查询都不做提交、暂存、checkout、reset、清理或网络操作。
- 文件路径只能是工作区内的相对路径，拒绝绝对路径、`..`、空字节和 `.git`。Windows 额外拒绝设备名、数据流、结尾点 / 空格等别名；目录逐段检查，符号链接 / junction 不展开或读取。预览使用有界文件句柄读取，并复核实际路径。
- Git 状态使用 NUL 分隔的 porcelain，重命名按目标 / 来源顺序解析；不按空格或换行切文件名。提交 hash 只接受完整 40 / 64 位十六进制，不能注入 revision 表达式或选项。
- 工作区 Git 快照内存缓存 5 秒，同目录同 revision 的并发读合并。工具结束、停稳、启动 / 切换和显式刷新使其失效，不写缓存数据库。
- 每个文件夹先显示 500 项，可逐次加载至 5,000 项；每次仍只读一层。提交先读 100 条，可增至 1,000 条；详情最多列 2,000 个文件。到上限明确提示，不把截断列表当成完整历史。
- 文本预览最多 **256 KiB UTF-8**；非 UTF-8 / 二进制 / 特殊文件显示原因。单份 Diff 上限 256 KiB，超过后提示，不截断成伪完整补丁。其他 Git 输出最大 16 MiB，每次 Git 命令超时 15 秒。
- 此处是文件系统和 Git 的只读快照，不是跨进程事务；其他程序同时编辑时可能需要再次刷新。不实现自动磁盘 watcher、仓库搜索、多提交比较或编辑审批。

`PiWorkspaceTransport` 现在同时解包三个资源：`workspace_rpc.mjs`、`workspace_browser.mjs`、`gui_tool_diff.mjs`。**新后端在下次正常启动更新后的应用时装载**，热重载不能替换已运行的 Node 模块。旧后端收到未知命令时右栏给出更新提示，不中断聊天。

## 关键路径

| 路径 | 职责 |
| --- | --- |
| `assets/backend/workspace_browser.mjs` | 目录 / Git 状态、缓存、提交 / 文件预览、安全边界 |
| `assets/backend/workspace_rpc.mjs` | 路由只读命令、生命周期与事件失效 |
| `lib/core/rpc/pi_browser_types.dart` | 强类型实体、枚举和 `PiBrowserGateway` |
| `lib/core/rpc/pi_rpc_client.dart` | 共用 JSONL 请求关联，不增加写屏障 |
| `lib/ui/features/home/controllers/workspace_browser_controller.dart` | 页签、懒加载、刷新合并、展开、选择、工作区隔离 |
| `lib/core/models/commit_graph.dart` | 无 Flutter / RPC 依赖的 DAG frontier 布局；真实 parent 连线 |
| `lib/ui/atoms/app_split_panel.dart` | 通用双区域绘制、拖拽、窄窗覆盖与动效 |
| `lib/ui/atoms/app_tree_tile.dart` | 复用 `AppNavTile` 的缩进、箭头、加载和左右键 |
| `lib/ui/atoms/app_icon_tabs.dart` | 图标页签、Tooltip、选中语义与滑动下划线 |
| `lib/ui/atoms/app_graph_track.dart` | 使用主题色绘制单行节点 / 连线，随实际行高拉伸 |
| `lib/ui/features/home/widgets/workspace_browser_panel.dart` | 透明文件 / graph 内容，保留 `sidebarPanel` 扩展插槽 |
| `lib/ui/features/home/widgets/workspace_document_view.dart` | 非模态文件内容 / 分区 Diff、提交详情；复用 AppCodeBlock / AppDiffView，提供单预览刷新 |
| `lib/ui/features/home/controllers/workspace_tabs_controller.dart` | 工作区 / 文件 / 提交的标签身份、打开去重与工作区切换清理 |
| `lib/ui/features/home/browser_labels.dart` | 状态、错误码到中英文本和语义颜色 |

原 `workspace_browser_dialog.dart` 已被非模态文档正文替代。原 `chat_changes_panel.dart` 已移除，聊天 Controller 不再保存右栏开关或选择路径；原有工具结果、Diff 证据和成功文件记录投影保留。

## 验证

以下为右栏首次实现的验证记录；后续标签页改造的验证见 [文档标签页](document_tabs.md)。

```bash
flutter analyze --no-pub
flutter test --no-pub
node --test test/workspace_browser_backend.test.mjs test/workspace_backend.test.mjs
flutter build windows --release --no-pub -t lib/main.dart
```

- 最终 `flutter analyze --no-pub` 无问题；全套 Flutter **72 项通过**，工作区相关 Node **15 项通过**（其中本功能 5 项）。Windows Release 构建成功，已核对三个打包后端资源与源码 SHA-256 一致；临时 QA 文件和旧面板已移除。
- Node 核心回归使用真实临时 Git 仓库：NUL / 重命名方向、暂存 / 未暂存、删除目录、忽略目录、Unicode、子目录与嵌套仓库、首次 / 合并提交、标签、真实重命名 Diff、二进制 / 大文件、路径越界 / 链接、索引不写入，以及 Agent 忙碌时的适配层只读路由。
- Dart 核心回归验证强类型 JSONL、仅发只读命令、目录请求合并、强制尾随读取、迟到工作区 / 预览隔离、失败保留快照，以及多父提交 / 共享祖先 / 独立根 / 未加载父节点的连线；不增加纯展示 Widget 测试。
- 独立视觉预览使用临时仓库生成的真实数据，走查紧凑文件树展开、19 条提交与合并连线、浅 / 深色、610px 窄窗口 + 150% 文字。直接读取预览自己的 `RenderRepaintBoundary`，不是桌面全屏截图。
- 30% 透明时，主区、右栏、标题栏背景 alpha 均为 **76 / 255**；窄窗右栏仍是 76，左侧遮罩区域为 98。确认右栏没有主背景或被覆盖输入框的二次叠色；此结果验证 Flutter 图层，不用于冒充 Windows 最终桌面合成像素。
- 临时预览曾因复用 `HomeStarterPanel` 的全局 editorAnchor 发生重复 GlobalKey，已关闭并改为隔离的公共布局 / 输入零件后重验；没有为此修改生产扩展槽位或清空活动聊天。预览代码与入口已移除。今后不要在同一进程再挂载第二个完整输入框来做 QA。
