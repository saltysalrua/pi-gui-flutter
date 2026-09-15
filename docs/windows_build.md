---
title: "Windows 构建与原生检查"
version: "1.2.0"
status: "verified"
type: "troubleshooting"
tags: [windows, flutter, clipboard, cargokit]
---

# Windows 构建与原生检查

当前使用 Flutter **3.47.4 / stable**、Dart **3.13.3**，Windows 默认渲染器为 **Impeller**。SDK 升级需要完整构建并启动新进程；不要覆盖承载当前会话的旧 SDK 或运行产物。版本约束、隔离升级验证和 Skia 临时回退见 [Flutter 版本与渲染器](flutter_renderer.md)。

## Cargokit 隐藏目录警告：现象与原因

`flutter run -d windows` 构建剪贴板依赖时可能打印：

```text
Get-Item : Could not find item C:\Users\<user>\AppData.
Get-Item : Could not find item C:\Users\<user>\AppData\Local.
```

并非目录不存在。`super_clipboard 0.9.1` 间接依赖的 `super_native_extensions 0.9.1` 包含 Cargokit 路径解析脚本；它逐级调用 `Get-Item`，却没有允许读取隐藏目录。Windows 的 `AppData`、`Local` 可以带隐藏属性，因而产生非终止错误；原脚本仍可能继续构建成功。

## 修复

在项目根目录运行一次（本机已执行）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/fix_cargokit_windows.ps1
```

脚本通过 `.dart_tool/package_config.json` 找到当前实际使用的依赖，将 `cargokit/cmake/resolve_symlinks.ps1` 中的一行改为：

```powershell
$item = Get-Item -LiteralPath $realPath -Force -ErrorAction Stop
```

- `-Force` 允许读取隐藏目录，不改变目录属性或权限。
- `-LiteralPath` 避免方括号等路径字符被当成通配符。
- `-ErrorAction Stop` 保留真实路径错误，不通过吞掉 stderr 掩盖问题。

这是对 **本机 Pub 依赖缓存** 的小范围修复，也会作用于共用该版本缓存的其他项目；不修改 Flutter 自动生成的插件注册文件、不更改 PowerShell 全局策略、不碰 Pi 文件。重复运行不会重复修改。清理/重新下载 Pub 缓存或升级依赖后，可能需要再次运行；如果上游脚本已经改版，脚本会停下要求检查，不盲目替换。

## 验证与代码位置

- 修复入口：`tool/fix_cargokit_windows.ps1`。
- 依赖入口：`super_native_extensions/windows/CMakeLists.txt` → `cargokit/cmake/cargokit.cmake` → `resolve_symlinks.ps1`。
- 已分别用真实 Pub 缓存路径、Flutter 插件链接路径执行修复后的解析脚本：退出码均为 0，stderr 为空，输出目录存在；重复运行修复脚本确认幂等。
- 仅做脚本级验证，未重新构建或重启活动 GUI。
- 用户已重新构建并确认图片粘贴可用；这类构建警告与旧 GUI 进程未加载新插件是两个不同问题。
- 无 Pi RPC 协议或聊天行为变更。

## 应用图标

Windows 图标由 `assets/images/pi_logo_dark.svg` 生成到 `windows/runner/resources/app_icon.ico`，再由 `Runner.rc` 嵌入 EXE。更新 SVG 后先运行图标生成器再构建；标题栏 SVG 可以热重载，已经运行的原生窗口 / EXE 图标需下次启动新构建才会使用。生成命令、尺寸与验证方式见 [品牌与图标说明](branding.md)。

## Release 交付与 QA 残留

正式入口是 `lib/main.dart`，正式可执行文件是 `build/windows/x64/runner/Release/pi_gui.exe`。`windows/CMakeLists.txt` 的 `BINARY_NAME` 只有 `pi_gui`，`pubspec.yaml` 未打包临时 QA 入口。

Flutter Windows 增量构建会更新已知产物、重拷贝 `data/flutter_assets`，但不会清空 Runner 输出目录中的额外 EXE。曾经把附件测试程序改名为 `pi_gui_attachment_qa.exe` 留在 Release，导致重新构建正式程序后旧文件仍在；该残留已删除，不是正式依赖。

交付前：

1. 显式使用生产入口构建：`flutter build windows --release -t lib/main.dart`。
2. 检查 Release 顶层的 EXE，当前项目应只有 `pi_gui.exe`：

   ```powershell
   Get-ChildItem -LiteralPath build/windows/x64/runner/Release -Filter *.exe
   ```

3. 发现多余文件时先确认来源及是否运行，只清理已确认的 QA 残留，不按通配符删除 DLL、`data/` 或用户附件。发布时仍需要正式 EXE 旁的运行库与资源。

QA 可执行文件应保存在隔离的临时输出位置或非交付配置中，验证结束后清理；只改名不算清理。不要为了消除残留执行 `flutter clean`、终止活动 GUI 或删除当前运行程序所在目录。

## 桌面毛玻璃与 C++ 检查

`windows/runner/window_material.h/.cpp` 通过 GUI 自有 MethodChannel 接入 Windows 11 22H2+ 的 DWM Acrylic；`flutter_window.cpp` 负责创建/销毁它并转发系统变化消息，`CMakeLists.txt` 将实现加入 Runner，复用已有 `dwmapi.lib`。没有新增 Flutter 插件。用户入口、数据与回退规则见 [外观设置](appearance_settings.md)。

原生实现新增或变更后需要完整构建并启动新 EXE，热重载不能替换 C++。如果当前 GUI 承载 Agent，不要为验证终止它；用不创建 Pi、使用临时偏好文件的独立 QA 入口和另一个构建配置验证，结束后移除 QA 入口，最终明确使用生产入口构建：

```powershell
flutter build windows --release -t lib/main.dart
```

`windows/runner/compile_flags.txt` 为 clangd 提供 C++17、显式 C++ 头文件模式、Unicode/NOMINMAX 和 Flutter 生成头文件的相对搜索路径。首次构建生成 `windows/flutter/ephemeral` 后可用，不包含开发机绝对路径，也不改变 CMake / MSVC 的正式构建参数。缺少这些参数时，编辑器可能将 `.h` 当成 C、误报找不到 `flutter/dart_project.h`，继而产生一串无关的 `flutter` / `std::optional` 未定义错误；应先核实编译参数，不要删除正确的原生代码。补齐参数后本次四个改动的 C++ 文件均通过主动编辑器检查，Profile 与 Release 构建通过。

## Acrylic 显示灰色，但透明开关和 DWM 类型都正常

先检查窗口状态，不要直接重装驱动或重启 DWM。`window_manager 0.5.2` 隐藏标题栏时会消费 `WM_NCACTIVATE` 而不执行 Windows 默认处理，可能造成“前台窗口 / NC 未激活”不一致，DWM 于是持续使用未激活灰底。

`windows/runner/flutter_window.cpp` 的 `FlutterWindow::MessageHandler` 已在该插件返回 `TRUE` 时补调 `DefWindowProc(hwnd, message, wparam, -1)`：更新系统激活状态但不重画系统标题栏，保持插件原 focus/blur 事件和返回值。不要把这一段删成普通的 `return *result`，也不要以永久置顶、强制永远激活或修改用户系统透明设置代替它。

验证时应同时看实际非最小化前台状态、`GetWindowInfo().dwWindowStatus & WS_ACTIVECAPTION` 和受控双色背景的最终像素；`DwmGetWindowAttribute(38)==3` / Dart `active` 本身不够。新构建已验证插件消息分发、切出切回、明暗模式、最小化/最大化还原。详细证据及无会话干扰的验证边界见 [外观设置](appearance_settings.md)。

## 顶部出现系统强调色实线/色带

这是 DWM 的原生 caption/border 配色，不代表 Flutter 外观设置使用了 Windows 种子色。`WindowMaterial` 的 `ConfigureCustomChrome` 用窗口级 `DWMWA_CAPTION_COLOR` / `DWMWA_BORDER_COLOR = DWMWA_COLOR_NONE` 去除实色覆盖，创建时、材质应用时及相关系统消息后均维护，关闭毛玻璃时不恢复系统强调色。不要让用户关掉全局强调色，不要用 Flutter 色块遮盖，不要删掉 NC 激活修复或改动缩放边框几何。详见 [外观设置](appearance_settings.md)。这是原生改动，需启动重新构建的 EXE。
