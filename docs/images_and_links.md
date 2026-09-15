---
title: "图片附件、图片预览与文件链接"
version: "1.1.1"
status: "implemented"
type: "feature"
tags: [flutter, pi-rpc, images, attachments, links]
---

# 图片附件、图片预览与文件链接

## 怎么用

- 输入框左下角点 **＋**，菜单内可选择 **添加图片** 或 **添加文件**。图片支持 PNG、JPEG、GIF 或 WebP。
- 输入框内 Ctrl+V（macOS 为 Cmd+V）优先粘贴剪贴板图片/文件列表；纯文字仍使用 Flutter 原有粘贴，保留选区替换与撤销。
- 剪贴板接入 `super_clipboard` 原生插件，旧进程仅热重载不能加载插件，需要重新构建并启动 GUI。当前原生端到端验证尚未完成，不应将旧窗口的附件读取失败误判为图片损坏。
- 图片先进入草稿：点击缩略图可放大、缩放查看，点右侧叉号移除。发送前不会把图片交给模型。
- 可以附带文字，也可以只发图片。图片随同一条 `prompt` 交给 Pi，不是把本机路径作为文字发送。
- 每条消息最多 8 张，每张最多 10 MiB，总共最多 20 MiB；单张分辨率不超过 4000 万像素。模型服务可能另有限制。
- 如果 Pi 明确返回模型不支持图片，输入框会提示切换模型或移除图片，不猜测模型名称。
- 明确拒绝发送时，文字与附件都保留。确认超时时继续沿用聊天写入屏障，不自动重发。回复过程中可以准备下一条图片草稿。
- 切换工作区时附件跟随该工作区草稿保存；成功新建或切换会话时清空附件。取消选择不会清空原来的图片。

## 图片显示

- 用户、助手及工具结果中的 RPC 图片块会显示缩略图；历史消息重新读取后也能显示。
- Markdown 中的本地图片和 base64 图片可以预览，例如 `![结果](output/result.png)`。
- 本地相对路径以 **当前 Pi 工作区** 为基准，不使用 GUI 启动目录。工作区外的本地绝对路径也可查看。
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

图片和文件仍由 HomeView 的同一附件控制器管理，工作区代次隔离、确认发送快照清理、会话切换清空规则不变。

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
| `lib/core/services/chat_resources.dart` | 系统选图、字节/格式/尺寸校验、显示资源读取、路径解析与系统打开服务 |
| `lib/ui/features/home/controllers/image_attachment_controller.dart` | 附件草稿、数量/总量限制、异步选图代次隔离、仅移除已确认发送的附件 |
| `lib/ui/core/chat_resource_scope.dart` | 传递工作区目录，统一链接失败提示 |
| `lib/ui/atoms/app_image.dart` | 通用缩略图、加载/错误状态、显式网络加载、缩放预览与可选移除操作 |
| `lib/ui/atoms/app_markdown.dart` | Markdown 图片/链接接入资源组件与服务 |
| `lib/ui/features/home/widgets/home_starter_panel.dart` | 选图入口、横向缩略图栏、图片模型提示、仅图片发送条件 |
| `lib/ui/features/home/widgets/home_chat_panel.dart` | 发送时快照附件，成功后仅移除本次快照；保留用户后续新增内容 |
| `lib/ui/features/home/widgets/chat_message_view.dart` | 用户和助手图片块展示 |
| `lib/ui/features/home/widgets/tool_card_registry.dart` | 工具图片输出与文件打开入口 |
| `lib/ui/features/home/views/home_view.dart` | 长期附件控制器、工作区/会话草稿生命周期 |

图片只通过原有 RPC 的 `prompt.images` 发送，不新增后端进程、不直连模型 API，不读写 Pi 私有会话文件。资源服务的本地 I/O 仅用于用户选择附件、显示图片及明确点击打开文件。

```json
{"id":"gui-1","type":"prompt","message":"看看这张图","images":[{"type":"image","data":"<base64 bytes>","mimeType":"image/png"}]}
```

同样的图片块出现在 `get_messages`、`message_start/message_end` 和 `tool_execution_update/end` 的 `content` 列表中。保留完整 `data/mimeType`，不再丢弃成占位块；工具 partialResult 仍按累计结果整体替换。停止仍以 `agent_settled` 为准。

## 验证

```bash
flutter analyze
flutter test
# 可选：使用一张 PNG，向真实模型发起一次小请求；不读写项目文件
# 会消耗模型额度，默认运行探针不调用模型
dart run tool/check_chat_rpc.dart --with-image /path/to/sample.png
```

- `test/chat_rpc_test.dart`：图片 prompt JSONL、历史与工具图片映射、仅图片发送、拒绝与未确认写屏障。
- `test/chat_resources_test.dart`：Windows/POSIX/编码路径及行号、安全边界、图片解码校验、工作区隔离、迟到选图、发送快照和数量限制。
- 桌面走查：真实 Windows 选择器返回图片，草稿缩略图与放大弹窗；临时预览完成后移除测试附件，不修改当前会话历史。
- 真实 RPC 图片探针：收到模型图片描述，回读保留原始图片数据，单连接、无文件改动、无协议诊断。

## 当前边界

不包含拖拽、直接向模型上传任意文档、自动 PDF/Office 解析、SVG/HEIC 图片预览或图片编辑。不改变空态居中/开始后底部输入的两态布局、模型浮层尺寸及扩展槽位。

## 本轮验证状态

- 静态分析通过；43 项既有及附件核心测试通过；另新增 2 项 Ctrl+V 选区/撤销/迟到回退交互回归通过。
- 用户重新构建 Windows GUI 后已确认图片粘贴可用；本次消息中的 `package.json` 文件附件也已由 Agent 成功读取，内容与 66 字节清单一致。
- 此前独立 QA 的键盘注入走查未通过，不能据此否定用户已确认的实际粘贴结果；未继续重跑该 QA。Lightbox 的真实桌面截图走查仍未完成。构建时 Cargokit 的隐藏目录警告修复见 [Windows 构建说明](windows_build.md)。
- 临时 QA 源入口在忽略目录 `.dart_tool/attachment_qa/`，不属于正式打包资源。此前只把 Release 测试程序改名为 `pi_gui_attachment_qa.exe`，没有删除，导致它在后续增量构建后继续残留；现已从 Release 删除。删除前确认该 EXE 未运行，删除后其余 30 个发布文件的 SHA-256 均未变化，目录中仅剩正式 `pi_gui.exe`。活动 Debug GUI 与 Pi 会话未重启。
- 改名或移走 QA 源码不等于清理打包输出；Flutter 重建不会自动删除额外 EXE。QA 可执行文件不得留在交付目录，正式入口固定为 `lib/main.dart`，交付前检查见 [Windows 构建说明](windows_build.md)。
