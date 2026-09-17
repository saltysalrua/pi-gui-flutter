---
title: "图片附件、图片预览与文件链接"
version: "1.4.0"
status: "implemented"
type: "feature"
tags: [flutter, pi-rpc, images, attachments, links]
---

# 图片附件、图片预览与文件链接

## 怎么用

- 输入框左下角点 **＋**，菜单内可选择 **添加图片** 或 **添加文件**。图片支持 PNG、JPEG、GIF 或 WebP。
- 输入框内 Ctrl+V（macOS 为 Cmd+V）优先粘贴剪贴板图片/文件列表；纯文字仍使用 Flutter 原有粘贴，保留选区替换与撤销。
- 剪贴板接入 `super_clipboard` 原生插件，旧进程仅热重载不能加载插件，需要重新构建并启动 GUI。用户已重新构建并确认图片粘贴可用，不应将未更新窗口的附件读取失败误判为图片损坏。
- 图片先进入草稿：点击缩略图可放大、缩放查看，点右侧叉号移除。发送前不会把图片交给模型。
- 可以附带文字，也可以只发图片。图片随同一条 `prompt` 交给 Pi，不是把本机路径作为文字发送。
- 点击发送后，GUI 后端调用 Pi 的图片处理函数，将上传图缩到最长边 2000px、单张 base64 小于 4.5 MiB；已经符合要求的小图保持原字节。草稿预览仍用原图，不修改原文件；发送后的时间线和历史显示模型收到的处理版。
- 任一图片处理失败或整批处理超时，整条消息都不发送，草稿与附件保留，并提示重试或减少图片。不会偷偷用未缩放的大图继续发送。
- **更新后须正常重新启动 GUI 才会加载新的 Node 后端**；热重载不生效。不要为验证重启承载当前 Agent 的窗口。
- 每条消息最多 8 张，每张最多 10 MiB，总共最多 20 MiB；单张分辨率不超过 4000 万像素。模型服务可能另有限制。
- 如果 Pi 明确返回模型不支持图片，输入框会提示切换模型或移除图片，不猜测模型名称。
- 明确拒绝发送时，文字与附件都保留。确认超时时继续沿用聊天写入屏障，不自动重发。回复过程中可以准备下一条图片草稿。
- 每个并行会话独立保留附件草稿；切换会话或 Worktree 不清空其他会话的附件。新建会话从空草稿开始，有草稿时关闭会话须确认。取消选择不会清空原来的图片。

## 图片显示

- 用户、助手及工具结果中的 RPC 图片块会显示缩略图；历史消息重新读取后也能显示。
- Markdown 中的本地图片和 base64 图片可以预览，例如 `![结果](output/result.png)`。
- 本地相对路径以 **该会话 / 文档所属的 Pi 工作区** 为基准，不使用当前选中标签的另一个目录或 GUI 启动目录。工作区外的本地绝对路径也可查看。
- 网络图片先显示 **点击加载网络图片**，悬停可看到完整地址。只有点击后才发起 HTTP(S) 请求，避免模型回复自动联网追踪。不会附带 Pi 密钥或聊天内容。
- 点击图片打开铺满应用窗口的暗色 Lightbox：滚轮以视口中心缩放、拖动平移，双击放大或恢复适应窗口；右上角关闭按钮、Esc 和点击图片外空白均可退出。由公共组件 `lib/ui/atoms/app_image_lightbox.dart` 实现，复用项目主题与动效 Token。
- 显示侧最多读取 20 MiB、4000 万像素，限制解码预览尺寸。损坏、缺失、超限或非支持格式只显示本地化提示，不中断对话。

## 普通文件附件

- 普通文件选择或粘贴后，复制到 `getApplicationSupportDirectory()/attachments/batch-*/`，保留文件名，不修改原文件。每条最多 8 个文件，每个最多 20 MiB，文件合计最多 50 MiB。不支持文件夹和网络共享。
- Pi 的公开 `prompt` 仅提供 `message` 和 `images`，没有通用文件上传字段。`FileAttachmentPrompt.compose` 在消息末尾附上 `<attached_files>` JSON 清单（`name/path/size`），Pi 使用自身工具按需读取本地副本。GUI 不自动解析或执行文件；PDF、Office 等文档能否读取取决于后端可用工具。
- 聊天历史识别完整清单并显示文件卡片；不完整或不合法清单仍保留为原文字。
- 缓存副本会跨发送和重启保留，当前不自动删除，避免超时发送或历史消息引用失效。需要时可在关闭 GUI 后手动清理此目录；清理后旧附件不能再读取。删除草稿卡片只移除引用。

新增关键路径：

| 路径 | 职责 |
| --- | --- |
| `lib/core/services/clipboard_attachments.dart` | 显式粘贴时读取剪贴板，图片校验、文件列表分流；不监听剪贴板 |
| `lib/core/services/file_attachments.dart` | 有界文件副本、失败批次回滚、消息附件清单编码/解析 |
| `lib/ui/atoms/app_text_field.dart` | 可覆盖 `PasteTextIntent`；无附件时委托原文字 Action |
| `lib/ui/atoms/app_menu_button.dart` | 加号所用公共菜单按钮，键盘与主题状态 |
| `lib/ui/atoms/app_file_tile.dart` | 草稿和历史共用文件卡片 |
| `lib/ui/atoms/app_image_lightbox.dart` | 公共全窗口图片查看器 |

图片和文件由每个 `WorkbenchSession` 自己的 `ImageAttachmentController` 管理；控制器内部的异步代次隔离和确认发送快照清理不变，不再以全局工作区切换清空其他会话。见 [工作区与并行会话](workspaces_sessions.md)。

## 打开文件链接

助手回复中的 Markdown 链接可以打开本地文件或网页：

```markdown
[说明](docs/rpc_chat.md)
[带行号的源码](lib/main.dart:12:3)
[绝对路径](D:/Projects/example/README.md)
[文件 URI](file:///D:/Projects/example/README.md#L12)
[包含空格](docs/example%20file.md)
[网页](https://example.com)
```

点击后用系统默认程序打开。行号与列号只是提示，会从文件目标中去掉；**不承诺编辑器跳到指定行**。普通代码块和裸文本不会自动变成文件链接。工具卡片中有文件路径时，展开后也提供“用系统默认程序打开”。

只接受 HTTP(S)、本地 `file:` 及普通文件路径，不执行 shell 字符串。拒绝网络共享/UNC、设备路径、Windows 数据流及特殊协议；可执行文件、脚本、快捷方式等不会通过关联程序执行。文件不存在或没有默认程序时提示检查，不直接显示底层异常。

## 代码与数据

交互参考 [Claude 的附件入口](https://support.claude.com/en/articles/8241126-upload-files-to-claude)：输入区选择图片、发送前预览与移除。复用已有原子组件，不另造业务弹窗。

| 路径 | 职责 |
| --- | --- |
| `lib/core/rpc/pi_chat_types.dart` | `PiImage`、有序 `PiContent.image`，消息/历史/工具结果共享解析 |
| `lib/core/rpc/pi_rpc_client.dart` | `prompt(text, images: ...)` 序列化；复用唯一 RPC 和既有写确认屏障 |
| `lib/core/rpc/pi_rpc_types.dart` | 读取模型 `input`；缺少字段时保留未知，不擅自判定能力 |
| `assets/backend/gui_image_upload.mjs` | 有界、顺序、整批图片预处理，复用 Pi 公开 `resizeImage`，校验结果与超时保护 |
| `assets/backend/workspace_rpc.mjs` | `WorkspaceAdapter.handle` 转发前处理 `prompt/steer/follow_up.images`；准备期间会话锁与停止代次保护 |
| `lib/ui/features/home/controllers/chat_controller.dart` | 将 `IMAGE_PREPROCESS_FAILED` 映射到本地化提示，返回未接受以保留发送快照 |
| `lib/core/services/chat_resources.dart` | 系统选图、字节/格式/尺寸校验、显示资源读取、路径解析与系统打开服务 |
| `lib/ui/features/home/controllers/image_attachment_controller.dart` | 附件草稿、数量/总量限制、异步选图代次隔离、仅移除已确认发送的附件 |
| `lib/ui/core/chat_resource_scope.dart` | 传递工作区目录，统一链接失败提示 |
| `lib/ui/atoms/app_image.dart` | 通用缩略图、加载/错误状态、显式网络加载、缩放预览与可选移除操作 |
| `lib/ui/atoms/app_markdown.dart` | Markdown 图片/链接接入资源组件与服务 |
| `lib/ui/features/home/widgets/home_starter_panel.dart` | 选图入口、横向缩略图栏、图片模型提示、仅图片发送条件 |
| `lib/ui/features/home/widgets/home_chat_panel.dart` | 发送时快照附件，成功后仅移除本次快照；保留用户后续新增内容 |
| `lib/ui/features/home/widgets/chat_message_view.dart` | 用户和助手图片块展示 |
| `lib/ui/features/home/widgets/tool_card_registry.dart` | 工具图片输出与文件打开入口 |
| `lib/ui/features/home/controllers/workbench_controller.dart` | 每会话长期附件控制器与关闭 / 草稿生命周期 |
| `lib/ui/features/home/views/home_view.dart` | 按文档目录装配 ChatResourceScope，保证并排会话的相对链接不串目录 |

图片只通过所属通道原有 RPC 的 `prompt.images` 发送，不为附件新增进程、不直连模型 API，不读写 Pi 私有会话文件。资源服务的本地 I/O 仅用于用户选择附件、显示图片及明确点击打开文件。

```json
{"id":"gui-1","type":"prompt","message":"看看这张图","images":[{"type":"image","data":"<base64 bytes>","mimeType":"image/png"}]}
```

同样的图片块出现在 `get_messages`、`message_start/message_end` 和 `tool_execution_update/end` 的 `content` 列表中。保留完整 `data/mimeType`，不再丢弃成占位块；工具 partialResult 仍按累计结果整体替换。停止仍以 `agent_settled` 为准。

### 上传预处理契约

`WorkspaceManager` 将启动时从已安装 Pi `dist/index.js` 取得的公开 `resizeImage` 注入每个 `WorkspaceAdapter`；旧单会话适配模式同样启用。处理发生在所属 Pi 子进程收到请求之前，不是一个新工具或扩展，不接管模型、权限和上下文。只有图片块的 `data/mimeType` 被处理，文本、附件清单、请求 ID 和 `streamingBehavior` 不变；转为 JPEG 时 MIME 随实际结果一起更新。

- 按输入顺序逐张调用 Pi 的 worker-backed 实现，不用路径或“上一张图”缓存；整个批次成功后才原子转发。无图消息不等待图片处理。
- 对齐前端的 8 张 / 单图 10 MiB / 总计 20 MiB 输入限制；输出显式限定 `maxWidth/maxHeight: 2000` 和 `maxBytes: 4.5 * 1024 * 1024`（Pi 的此参数指 **base64** 大小）。PNG/JPEG 编码选择、缩放、方向处理等复用 Pi，不复制算法。
- 这是 GUI 上传保护；不读写用户的 Pi 设置，不受用于原生工具的 `images.autoResize` 开关控制。不会清理旧会话图片，也不会给仅文字模型增添视觉能力。
- 整批 20 秒期限短于 GUI 默认 RPC 30 秒请求超时；缺少 SDK 函数、解码失败、超时或不合格结果均返回 `IMAGE_PREPROCESS_FAILED`，绝不回退到发送原大图。已超时任务不会开始下一张，迟到结果不会转发。
- 准备期间所属通道禁止新 prompt / steer / follow_up / 会话切换与普通关闭；`get_state`、扩展问答、`abort` 和其他会话不受阻。收到 abort 后即使 worker 稍后完成，也不会发送该批图片；已关闭 / 更换的 Pi 子进程不会收到迟到请求。
- Pi `resizeImage` 通常在 worker 里工作，其自身有 worker 不可用时的进程内降级；极端事件循环阻塞下 JS 定时器不保证精确 20 秒，GUI 原有未确认写屏障仍保留。

失败协议示例（没有对应的新 user 历史或模型请求）：

```json
{"type":"response","id":"gui-1","command":"prompt","success":false,"error":"IMAGE_PREPROCESS_FAILED"}
```

## 验证

```bash
flutter analyze
flutter test
# 可选：使用一张 PNG，向真实模型发起一次小请求；不读写项目文件
# 会消耗模型额度，默认运行探针不调用模型
dart run tool/check_chat_rpc.dart --with-image /path/to/sample.png
```

- `test/chat_rpc_test.dart`：图片 prompt JSONL、历史与工具图片映射、仅图片发送、拒绝与未确认写屏障；图片预处理拒绝后保留草稿并可重试。
- `node --test test/image_upload.test.mjs`：批次顺序和不可变输入、字节/尺寸限制、超时/失败原子性、三种图片命令、会话锁、abort 后迟到结果隔离和跨会话并行。
- `test/chat_resources_test.dart`：Windows/POSIX/编码路径及行号、安全边界、图片解码校验、工作区隔离、迟到选图、发送快照和数量限制。
- 桌面走查：真实 Windows 选择器返回图片，草稿缩略图与放大弹窗；临时预览完成后移除测试附件，不修改当前会话历史。
- 真实模型 RPC 探针使用原生 Pi 直连验证协议；它不经过 GUI 上传预处理。GUI 上传请使用下述回环探针，不把直连的原图回读当成 GUI 的缩放结果。

## 排查“看不到图片 / 描述成上一张”

先区分三件事：GUI 能显示图片、Pi 历史里保存了图片、模型服务真正收到图片，并不等价。

### 已验证的传输链路

```bash
node tool/check_image_rpc.mjs
```

探针使用临时配置、临时工作区、真正的 `workspace_rpc.mjs --gui-multiplex` 和原生 Pi 子进程。仅连接本机脚本化 SSE 服务，不调用外部模型，不加载用户扩展，不修改当前会话。它在服务端检查图片字节哈希，而不是依靠模型口头声称“看见了”：

- 连续上传 2400×1200 红图、蓝图：请求中的图片是 2000×1000，字节与 Pi SDK 独立处理结果一致；图片顺序及 `get_messages` 回读也一致。
- 同批大图 / 小图 / 高噪声大文件混发：小图原字节不变，高噪声图在不超 2000px 时仍按负载限制转为 JPEG，MIME 与内容对应，各图片保持顺序。
- 一批中的损坏图片：整条消息明确失败，不产生模型请求、不增加历史；随后重新发送正常图片成功。
- 另一会话只上传蓝图：不会带入前一会话的红图。
- 原生 `read` 连续读取同一路径、期间替换图片：第二次收到新图，不使用旧图缓存；大图经过 Pi 缩放。
- 模型注册为 `input: ["text"]`：图片在发往服务前被过滤，即使 RPC 历史仍有图片块。
- 本机服务返回越过阈值的 usage：收到成功的 `compaction_end(reason: threshold)`，证明 RPC 会执行自动上下文压缩。

这能排查协议/转发问题，不能替代真实模型视觉能力测试，也不能证明用户扩展或远端中转服务没有改写请求。

### 两种“压缩”不要混淆

以本机 Pi 0.85.1 实现为准：

| 项目 | 行为 |
| --- | --- |
| 聊天上下文压缩 | RPC `prompt` 调用 `AgentSession.prompt`，仍执行上下文压缩检查、扩展 input/context 钩子与工具流程，并非绕过 Agent |
| `read` / 工具结果图片处理 | Pi 的 `processImage` / `normalizeToolResultImages` 处理图片，默认最长边 2000px、base64 负载目标低于 4.5 MiB，受 `images.autoResize` 影响 |
| 原生 Pi RPC 上传 | 该版本 `prompt.images` 本身不调用图片缩放，直接接收传入的字节 |
| GUI 上传图片 | GUI Node 适配层先调用 Pi 公开 `resizeImage`（2000px / base64 小于 4.5 MiB），再将处理结果放入原生 `prompt.images`；Flutter 草稿仍保留原图 |

图片以结构化 image 块传输，不是把 base64 当普通正文塞给模型。视觉 token 数取决于模型与分辨率，不能拿 base64 字符数直接当 token 数；图片过多仍可能增加视觉 token、请求字节和延迟。缩小单图也不会自动删除历史里的其他图片。

### 具体会话的检查顺序

1. 用所属通道的 `get_state` 确认实际 `model.provider/id/input`，不要把默认模型当成该会话当前模型。没有 `image` 能力时，GUI 会阻止直接发送图片，但工具 `read` 仍可能显示图片结果，随后模型请求过滤图片。本机排查时 `pi-ollama-cloud` 的 `glm-5.3` 注册为仅文字，不能通过随意改成 `input: ["text", "image"]` 来获得视觉能力。
2. 检查 Pi 的 `images.blockImages`；它会把用户/工具图片替换为文字占位。此开关和 GUI 缩略图显示不是一回事。
3. 对照 `get_messages` 中本次 user 或 toolResult 图片与预期处理结果的哈希。大图已缩放，不能直接要求历史哈希与原文件相等；小图未转换时可直接比较。只见工具文字或 Markdown 文件链接，不等于模型获得了 image 块。相同输出路径被其他进程覆盖也要单独排查。
4. 检查加载的上下文扩展。本机安装的 Magic Context 默认接管并取消原生 compaction；其 `stripPiProcessedImages` 会在满足已回复、水位等条件时把旧图替换成文字占位。这不是 RPC 禁用了压缩，也不能仅凭安装了扩展就断定新图被误删。
5. 若原生隔离探针正常、特定真实会话异常，再对该会话的扩展/模型服务做对照。保留历史，不盲目删除会话、不重启承载 Agent 的 GUI、不把全部图片自动丢弃。

定位路径：GUI 发送快照在 `home_chat_panel.dart::_send`，`PiRpcClient.prompt` 编码 `images`，`PiChannelHub` 加通道外壳，`WorkspaceManager.handle` 路由通道，`WorkspaceAdapter.handle` 在转发图片命令前调用 `prepareImageUpload`。已安装 Pi 包下的 `dist/modes/rpc/rpc-mode.js`、`dist/core/agent-session.js`、`dist/core/sdk.js`、`dist/core/tools/read.js`、`dist/utils/tool-result-images.js` 分别对应 prompt 入口、会话压缩、图片禁用过滤、文件读图及工具图归一化。

## 当前边界

不包含拖拽、直接向模型上传任意文档、自动 PDF/Office 解析、SVG/HEIC 图片预览或图片编辑。不改变空态居中/开始后底部输入的两态布局、模型浮层尺寸及扩展槽位。

## 上传缩放验证状态

- `flutter analyze --no-pub` 全项目无问题；定向 Node 核心测试 20 项、Dart 聊天/RPC/工作区测试 32 项通过。
- `node tool/check_parallel_rpc.mjs` 解包五个后端脚本后通过真实并行探针，确认新增资源齐全、相同请求 ID / 历史去重 / 定向关闭不回归。
- 真实 GUI 多通道 + 原生 Pi + 回环 SSE 探针的 7 组检查通过（无外部模型调用），覆盖缩放、负载压缩、顺序/会话隔离、失败后重试和自动上下文压缩。
- 未重启当前 GUI / Pi，也未修改用户的 Pi 配置或历史；本改动只处理更新后新上传的图片。

## 既有附件验证记录

- 静态分析通过；43 项既有及附件核心测试通过；另新增 2 项 Ctrl+V 选区/撤销/迟到回退交互回归通过。
- 用户重新构建 Windows GUI 后已确认图片粘贴可用；本次消息中的 `package.json` 文件附件也已由 Agent 成功读取，内容与 66 字节清单一致。
- 此前独立 QA 的键盘注入走查未通过，不能据此否定用户已确认的实际粘贴结果；未继续重跑该 QA。Lightbox 的真实桌面截图走查仍未完成。构建时 Cargokit 的隐藏目录警告修复见 [Windows 构建说明](windows_build.md)。
- 临时 QA 源入口在忽略目录 `.dart_tool/attachment_qa/`，不属于正式打包资源。此前只把 Release 测试程序改名为 `pi_gui_attachment_qa.exe`，没有删除，导致它在后续增量构建后继续残留；现已从 Release 删除。删除前确认该 EXE 未运行，删除后其余 30 个发布文件的 SHA-256 均未变化，目录中仅剩正式 `pi_gui.exe`。活动 Debug GUI 与 Pi 会话未重启。
- 改名或移走 QA 源码不等于清理打包输出；Flutter 重建不会自动删除额外 EXE。QA 可执行文件不得留在交付目录，正式入口固定为 `lib/main.dart`，交付前检查见 [Windows 构建说明](windows_build.md)。
