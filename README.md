---
title: "Pi GUI"
status: "in-development"
type: "project"
---

# Pi GUI

[![Windows release](https://github.com/saltysalrua/pi-gui-flutter/actions/workflows/release.yml/badge.svg)](https://github.com/saltysalrua/pi-gui-flutter/actions/workflows/release.yml)

基于 Flutter 的桌面 Pi RPC 客户端。Flutter 负责界面与交互，独立的 `pi --mode rpc` 进程负责模型、会话和工具执行。

## 下载

在 [GitHub Releases](https://github.com/saltysalrua/pi-gui-flutter/releases) 下载 Windows x64 便携 ZIP，完整解压后运行 `pi_gui.exe`。需要已安装并配置的 Node.js 和 Pi；ZIP 不含模型凭据，也未做代码签名。详细要求见 [便携版使用说明](docs/release_usage.md)。

## 从源码运行

需要 Windows 桌面 Flutter 开发环境（当前固定 Flutter **3.44.0-0.3.pre / beta**）、PATH 中的 Node.js，以及 npm 安装的 `@earendil-works/pi-coding-agent`。先在 Pi 中配置模型和凭据；本项目不直接调用模型 API。

```bash
flutter pub get
flutter run -d windows
```

Pi 在当前选择的工作区目录执行任务；GUI 优先恢复上次打开的目录，首次启动使用启动目录。发送代码任务可能让 Pi 在此目录执行工具或修改文件，请按实际开发任务使用。

## 已接入

- 空会话居中输入，开始发送后输入框移到底部；新建会话回到居中。
- 真实模型/思考等级选择与搜索，保留紧凑浮层。
- RPC 消息发送、流式回复、停止、会话切换与连接恢复。
- Markdown、代码高亮/复制、折叠思考及无边框工具调用：紧凑标题、少量预览、按需展开，不显示参数区。
- edit/write 对话内 Diff 和独立文件改动面板；没有旧内容时显示中性行号的写入内容。
- 当前工作区的真实历史会话、目录切换和 Git Worktree 管理。
- 图片附件、图片预览及网页/文件链接。
- Pi 扩展通知、状态、输入区组件和交互弹窗。
- 外观设置：Windows / Material 3 动态配色、明暗独立分区取色、基准字号和 UI 比例，自动保存。

改动面板展示当前会话的文件工具编辑记录，不是 Git 净改动，也不提供回滚。write Diff 来自后端对写入前后内容的有限观察；旧历史、无法确认基线或并发冲突时不编造对比。

## 开发与验证

```bash
flutter analyze
flutter test
# 无模型请求的真实 RPC 检查
dart run tool/check_pi_rpc.dart
dart run tool/check_chat_rpc.dart
node tool/check_tool_diff.mjs
node tool/check_workspace_rpc.mjs
# 真实 RPC + 固定本地 SSE 响应，验证 write Diff，不调用外部模型
node tool/check_tool_diff.mjs --rpc
# 可选：调用一次模型，在隔离临时目录验证编辑和真实 Diff，会消耗模型额度
dart run tool/check_chat_rpc.dart --with-model
```

开发优先热重载。需要热重启时先关闭旧 RPC 客户端，避免 Flutter 热重启跳过 dispose 而留下 Pi 子进程。

## 自动发布

修改 `pubspec.yaml` 的 `version` 并推送到 `master`，GitHub Actions 会在版本实际变化时构建，并自动创建带 ZIP / SHA-256 的 Release；仅修改依赖或普通源码不会触发 Windows 构建。首次推送也会构建，可在 Actions 手动重跑。见 [GitHub 自动构建与发布](docs/github_release.md)。

## 文档

- [GitHub 自动构建与发布](docs/github_release.md)
- [Windows 构建与原生检查](docs/windows_build.md)
- [第三方资源声明与 MiSans 许可](THIRD_PARTY_NOTICES.md)
- [RPC 对话、Markdown 与文件改动](docs/rpc_chat.md)
- [模型选择器与 RPC 连接](docs/model_picker_rpc.md)
- [工作区、历史会话与 Git Worktree](docs/workspaces_sessions.md)
- [图片附件与文件链接](docs/images_and_links.md)
- [外观设置与动态配色](docs/appearance_settings.md)
- [启动界面与设计系统](docs/first_interface_design.md)
- [项目规范](AGENTS.md)
