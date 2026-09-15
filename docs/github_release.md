---
title: "GitHub 自动构建与发布"
version: "1.0.0"
status: "implemented"
type: "developer-guide"
tags: [github-actions, windows, flutter, release]
---

# GitHub 自动构建与发布

仓库：<https://github.com/saltysalrua/pi-gui-flutter>。保留现有默认分支 `master`；Dart 包名仍为 `pi_gui`，Windows 程序仍为 `pi_gui.exe`，不因仓库名称变化修改导入或应用数据目录。

## 怎么发布

1. 修改根目录 `pubspec.yaml` 的 `version`，例如从 `1.0.0+1` 改为 `1.0.1+2`。
2. 将本次源码、版本号和文档提交并推送到 `master`。
3. 打开 GitHub → **Actions → Windows release** 查看进度。
4. 分析、测试和构建全部通过后，**Releases** 自动出现标签 `v1.0.1+2`，附完整 Windows x64 ZIP 和 `.zip.sha256`。

完整版本号是唯一来源：修改 `+` 后的构建号也会触发，预发布示例为 `1.1.0-beta.1+3`，会创建 GitHub Pre-release。Windows 的四段数值都限制为 0–65535；不支持用文字作为构建号。

每次 `master` push 都运行几秒的版本检查，但只有版本真的变化才使用 Windows Runner。比较的是 **push 前的提交与整个 push 最后的提交**，不是简单检查 `pubspec.yaml` 是否变动，也不是只看 `HEAD^`：

- 只改依赖、注释、工作流或普通源码：跳过构建和发布。
- 一次推送多个提交，版本在较早提交中变更：仍构建。
- 同一次 push 中先改版本又改回去：不构建。
- 首次推送分支，或之前没有 `pubspec.yaml`：构建当前版本。
- 无法取得旧提交时明确报错，不把未知状态当作版本变化。
- 不在 PR、其他分支或标签 push 中发布；若将来改默认分支，需要同步修改 workflow 的分支过滤和 `if`。

不需要手工打 Git 标签，也不需要配置个人 PAT 或模型 API Key。只有发布 Job 拥有 `contents: write`，使用仓库自带的 `GITHUB_TOKEN`。

## 失败后怎么处理

- 网络或 Runner 临时故障：在该次运行中点 **Re-run failed jobs** / **Re-run all jobs**。
- 版本未变但需要主动构建：在 `master` 上使用 **Run workflow**。
- 同一提交的 Release 已发布：重跑可再次构建，但不会替换已发布附件。
- 标签已经指向别的提交：发布明确失败；应增加版本号，不能强移旧标签或覆盖旧版本。
- 上传中途失败：Release 先保留为 Draft，同一提交重跑会补齐附件后公开。Draft 即使尚未创建标签，也校验目标提交，不能被另一提交接管。

不同提交不会相互取消正在构建的版本；同一版本的发布步骤串行执行。失败的分析/测试/构建不会产生公开 Release，成功构建的 ZIP 还会在 Actions Artifacts 中保存 30 天。

Windows Runner 的 `TEMP` 可能使用不同大小写或 8.3 短路径。`test/workspace_backend.test.mjs` 的临时仓库 fixture 必须先 `realpath`，与生产 `directory()` 一致，否则 `cwd === target` 的失败注入匹配不到，误报缺少 `WORKSPACE_START_FAILED`。首次云端运行发现此问题，已在本机通过小写 `TEMP` 复现并修正 fixture；不要跳过测试或改变生产路径规范化。

## 构建内容与边界

- Runner：`windows-2022` / x64；原生构建使用其 Visual Studio C++ 工具链。
- Flutter：固定 **3.44.0-0.3.pre / beta**，与本项目已验证环境一致。升级时显式更新 `.github/workflows/release.yml`，连同 Dart SDK 约束和 `pubspec.lock` 一起验证；不要使用会自动漂移的最新 beta。
- 依赖：提交 `pubspec.lock`，使用 `flutter pub get --enforce-lockfile`，随后执行已有 Cargokit 隐藏目录修复。
- 检查：`flutter analyze`、`flutter test`、Node 工作区核心测试、无模型 Diff 观察器检查。CI 固定 Node.js `24.19.0`，并安装 Pi `0.85.1` 到 Runner 的全局 npm 目录，通过 `PI_GUI_PI_PACKAGE_DIR` 显式传给探针；该检查调用真实 Pi write 工具，但不请求模型。Pi 仅为 CI 测试依赖，不进入 ZIP。
- 构建：`flutter build windows --release -t lib/main.dart`。CI 在全新目录构建，不接触开发机活动 GUI。
- 包装：完整 `build/windows/x64/runner/Release`，包括 EXE、DLL、`data/`、用户说明和第三方声明；缺少 AOT/资源或发现额外 QA EXE 时拒绝包装。
- 产物：`pi-gui-flutter-1.0.0+1-windows-x64.zip`、同名 `.zip.sha256`；发布前再次校验哈希。
- 不提供安装器、代码签名、macOS/Linux/ARM64 构建；不打包 Node.js、Pi、模型密钥或个人会话。

用户运行方式及 VC++ 运行库要求见 [便携版使用说明](release_usage.md)，原生构建问题见 [Windows 构建说明](windows_build.md)，字体许可见 [第三方声明](../THIRD_PARTY_NOTICES.md)。公开仓库本身不等于授予开源许可；本次未擅自为项目代码选择 MIT/Apache 等许可证。

## Agent 接手路径

| 路径 | 职责 |
| --- | --- |
| `.github/workflows/release.yml` | 三阶段版本检查 → Windows 构建 → 最小权限发布，Action 固定提交 SHA |
| `tool/ci_release.py` | `detect` 读取事件 / Git 旧版本并产生 Job 输出；`package` 校验产物边界、制作 ZIP / SHA-256 |
| `tool/test_ci_release.py` | 秒级临时 Git 仓库回归：首次推送、多提交、纯依赖、回退、构建号、手动触发与包装 |
| `pubspec.yaml` / `pubspec.lock` | 应用版本与确定的依赖解析 |
| `tool/fix_cargokit_windows.ps1` | 按实际 Pub 包路径修复上游已知问题 |
| `docs/release_usage.md` | Release 正文与 ZIP 内 README 的共同来源 |
| `THIRD_PARTY_NOTICES.md` / `assets/fonts/MiSans/LICENSE.pdf` | 随包分发的资源声明与字体原始许可 |

版本检查以 `GITHUB_EVENT_NAME`、`GITHUB_EVENT_PATH` 为输入，向 `GITHUB_OUTPUT` 输出，例如：

```text
changed=true
version=1.0.1+2
previous=1.0.0+1
tag=v1.0.1+2
prerelease=false
```

本次没有 Widget / Controller / Service 或 Pi RPC 命令、事件、运行期协议变更。

本地轻量验证：

```bash
python -m unittest discover -s tool -p 'test_ci_release.py' -v
# 已有完整 Release 时可仅打包，不会重编译或重启 GUI
python tool/ci_release.py package
# 安装 actionlint 后校验 Actions 语法
# actionlint .github/workflows/release.yml
```

参考 [Flutter Windows 发布与版本号](https://docs.flutter.dev/deployment/windows)、[GitHub Actions 事件](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push) 和 [GitHub CLI release](https://cli.github.com/manual/gh_release)。
