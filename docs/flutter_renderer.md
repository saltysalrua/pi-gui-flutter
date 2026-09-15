---
title: "Flutter 版本与 Windows 渲染器"
version: "1.0.0"
status: "verified"
type: "developer-guide"
tags: [flutter, windows, impeller, sdk]
---

# Flutter 版本与 Windows 渲染器

## 当前选择

项目从 Flutter **3.44.0-0.3.pre / beta** 升级到 **3.47.4 / stable**，配套 **Dart 3.13.3**。版本于 2026-09-15 对照官方 Windows 发布清单和 Git 标签核实。

Flutter 3.47 起在 Windows 默认使用 **Impeller**。本项目沿用引擎默认配置，不需要替换 Widget、改写 Canvas，也不需要给正常启动命令额外加渲染参数。`windows/runner/main.cpp` 的 `flutter::DartProject` 没有关闭 Impeller。

Impeller 是渲染器，不等于固定使用 Vulkan。本机新 SDK 的真实 Windows 窗口日志显示：

```text
Using the Impeller rendering backend (OpenGLESSDF).
```

同时只读 VM 服务 `ext.ui.window.impellerEnabled` 返回 `enabled: true`。不要把 OpenGLES 字样误判成仍在用 Skia，也不要未经测试强制切换图形 API 或 GPU。减少着色器相关卡顿是升级的目标之一，但本次没有做 FPS、帧耗时或功耗对比，不能据此承诺具体性能提升。

## 开发与启动

先确认命令实际指向 Flutter 3.47.4 / Dart 3.13.3，再运行：

```powershell
flutter --version
flutter pub get --enforce-lockfile
powershell -NoProfile -ExecutionPolicy Bypass -File tool/fix_cargokit_windows.ps1
flutter run -d windows
```

**更换 Flutter 引擎必须完整构建并启动新进程，热重载无法把正在运行的 Skia 换成 Impeller。** 如果旧 GUI 承载当前 Agent，会话结束前不要关闭它、热重启、执行 `flutter clean`，也不要就地覆盖它正在使用的 SDK。

本次采用并排安装：新 SDK 位于 `D:/Code/SDKs/flutter-3.47.4`，旧 SDK `D:/Code/SDKs/flutter` 保留；用户 PATH 已更新，新终端使用新 SDK。验证在独立工作副本进行，没有改动活动 GUI 的 `.dart_tool`、Windows ephemeral 文件或 Debug 产物。已打开的终端仍可能继承旧 PATH；需要时使用新 SDK 的完整路径：

```powershell
& D:/Code/SDKs/flutter-3.47.4/bin/flutter.bat run -d windows
```

路径是本机安装位置，不是其他开发者必须采用的目录。

## 版本约束与变更范围

| 路径 | 职责 |
| --- | --- |
| `pubspec.yaml` | Dart `^3.13.0`，Flutter 最低 `3.47.4`；应用版本保持不变 |
| `.github/workflows/release.yml` | 固定 `3.47.4 / stable`，不跟随浮动 stable/beta |
| `pubspec.lock` | 记录新 SDK 约束下的依赖解析 |
| `windows/runner/main.cpp` | 保留默认 Impeller，说明临时回退入口 |
| `analysis_options.yaml` | 接受 Flutter 自动迁移：Dart 分析排除 `build/**`、`windows/**`；不关闭原生 C++ 检查 |
| `lib/l10n/app_localizations_{en,zh}.dart` | 新版生成器增加导入分组空行，无文案变化 |

只更新新 SDK 要求的依赖：`intl 0.20.3`、`matcher 0.12.20`、`meta 1.19.0`、`test_api 0.7.12`、`vector_math 2.4.2`。`window_manager`、`super_clipboard`、`dynamic_color`、`flutter_svg` 等保持原有锁定版本，没有执行全量 `pub upgrade`。

`.metadata` 中的 beta 和旧 revision 是项目创建/迁移历史，不是当前 SDK 选择器，不手改这些历史字段。也没有顺带迁移到独立 Material/Cupertino 包、删除已有原生兼容修复或调整聊天布局。

无新增原子组件，无 Widget / Controller / Service 业务改动，无 Pi RPC 命令、事件或 JSONL 数据结构变化。发布流水线仍只做版本检测、构建、打包、发布，未增加测试或 Pi 依赖。

## 如何确认实际渲染器

Debug 窗口的启动日志应包含 `Using the Impeller rendering backend`。也可以对该窗口自己的 VM 服务调用：

```text
ext.ui.window.impellerEnabled(isolateId: <main isolate id>)
```

响应示例：

```json
{"type":"Success","enabled":true}
```

以运行中进程的结果为准，而不是只看 PATH、Flutter 版本号或文档。升级验证时旧活动窗口仍返回 `false`，新 SDK 的隔离窗口返回 `true`，两者并不矛盾。

## 遇到渲染问题时临时回退

先保留复现步骤和截图，使用同一个 SDK 对比：

```powershell
flutter run -d windows --no-enable-impeller
```

如果必须在打包版本中临时回退，在 `windows/runner/main.cpp` 创建 `DartProject` 后加入官方开关，再完整构建：

```cpp
flutter::DartProject project(L"data");
project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
```

此行**未加入正式代码**；不要把它当成迁移所需设置。引擎选择是启动时配置，不在外观设置中增加会误导用户的即时切换按钮。官方说明将来可能移除 Skia 回退，因此它只用于诊断或临时兼容。

## 已完成的验证与边界

- Flutter 3.47.4 的 `flutter pub get --enforce-lockfile`、`flutter analyze --no-pub` 通过。
- 现有 63 项 Flutter 测试通过；未增加纯展示测试或把测试塞入发布 workflow。
- 正式入口 `lib/main.dart` 的 Windows x64 Release 完整构建通过，原生插件与 Acrylic Runner 一起编译。
- 独立 Debug QA 入口只复用 `PiGuiApp` 与 `AppearanceSettingsView`，使用临时外观文件，不创建 `HomeView` / Pi 子进程，不读取或覆盖用户会话。
- 新窗口实际返回 `enabled: true`；浅色、深色、SVG 标志、中文字体和 110% UI 比例均完成应用自身图层截图走查，没有 Flutter 异常日志。
- 毛玻璃关闭时原生状态为 `disabled`、底色 alpha 为 255；开启到 20% 时原生状态为 `active`、空白分区 alpha 为 51。此次确认了原生通道与透明图层，**没有将图层截图当成 DWM 最终桌面模糊的证明**，也未读取用户其他窗口画面。既有最终合成验证见 [外观设置](appearance_settings.md)。
- QA 入口不进入正式资产或 Release；验证结束后关闭临时窗口并清理隔离工作副本。旧 GUI / Pi 会话未重启。
- 本地新便携包及 SHA-256 放在 `dist/flutter-3.47.4/`，没有覆盖旧构建目录，也没有增加应用版本号、推送或触发 GitHub Release。完整解压后才能运行，不能只移动 EXE。

## 官方依据

- [Impeller 各平台支持与回退开关](https://docs.flutter.dev/perf/impeller)
- [Flutter 3.47 发布说明](https://flutter.dev/blog/whats-new-in-flutter-3-47)
- [Windows SDK 发布清单](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json)
- [Flutter 3.47.4 源码标签](https://github.com/flutter/flutter/tree/3.47.4)

相关操作见 [Windows 构建](windows_build.md) 和 [GitHub 自动发布](github_release.md)。
