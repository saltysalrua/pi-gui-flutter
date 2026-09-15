---
title: "品牌 SVG 与 Windows 应用图标"
version: "1.0.0"
status: "implemented"
type: "feature-and-architecture"
tags: [flutter, svg, windows, branding, assets]
---

# 品牌 SVG 与 Windows 应用图标

## 界面效果

首页和设置页共用的左上角标记直接显示 `assets/images/pi_logo.svg`，不再拼接蓝色圆点和 `Pi` 文字。SVG 保留原始几何形状与留白，默认占 32×32 逻辑像素；颜色跟随主题的主要文字色，浅色 / 深色 / 自定义配色都适用，UI 缩放后仍以矢量绘制。

标题栏继续保持 38px 高度、与侧栏同色。标记区域仍可拖动窗口、双击最大化 / 还原；窗口控制按钮不变。无需新增设置，也没有新增 RPC 命令或事件。

软件图标使用 `assets/images/pi_logo_dark.svg` 的深底白字图稿。Windows EXE、任务栏和快捷方式不能直接使用 SVG，因此保留 SVG 为源文件，生成系统支持的多尺寸 `.ico` 并嵌入 EXE。背景及字形颜色来自提供的图稿，不另画一份图形。

**标题栏可以热重载生效；EXE / 原生窗口图标必须重新构建并启动新程序。** 不为刷新图标而关闭承载当前 Agent 会话的 GUI。已经固定的旧快捷方式或 Windows 图标缓存可能继续显示旧图；先确认运行的是新构建，不自动清理系统图标缓存或重启资源管理器。

## 关键路径

| 路径 | 职责 |
| --- | --- |
| `assets/images/pi_logo.svg` | 透明背景、`currentColor` 的标题栏品牌源图 |
| `assets/images/pi_logo_dark.svg` | 深色底、白色字形的 Windows 图标源图 |
| `lib/ui/atoms/app_logo.dart` | 公共 `AppLogo(size: ...)`；用 `flutter_svg` 矢量渲染，`ColorFilter` 映射到 `context.colors.textPrimary`，语义标签取 `context.l10n.appName` |
| `lib/ui/atoms/custom_title_bar.dart` | 用 `AppLogo` 替换旧文字 / 圆点，保留原窗口拖拽包装 |
| `pubspec.yaml` / `pubspec.lock` | `flutter_svg 2.3.0` 与锁定依赖；原有 `assets/images/` 注册覆盖两份 SVG |
| `tool/generate_app_icon.py` | 从 SVG 独立栅格化每个尺寸，生成 ICO；`--check` 检查是否与源图一致 |
| `tool/icon_requirements.txt` | 仅开发时使用的 `resvg-py 0.5.0`，不随 GUI 打包 |
| `windows/runner/resources/app_icon.ico` | 生成的 Windows 图标，作为源码资源随项目保存 |
| `windows/runner/Runner.rc` | 将 `.ico` 编译为 `IDI_APP_ICON`（101） |
| `windows/runner/win32_window.cpp` | 沿用 `LoadIcon(... IDI_APP_ICON)`，从 EXE 图标资源创建原生窗口 |

`AppLogo` 只加载项目自带的受信任 SVG。聊天附件的 `AppImage` 不因此开放 SVG，也不改变网络图片手动加载等安全边界。

## 更新图标

修改对应 SVG 后，标题栏不需要生成 PNG。Windows 图标需要重新生成；不要只替换或重命名 SVG 为 `.ico`。

建议使用单独的 Python 3.10+ 工具环境（以下为 PowerShell 示例）：

```powershell
python -m venv "$env:TEMP\pi-gui-icon-tools"
& "$env:TEMP\pi-gui-icon-tools\Scripts\python.exe" -m pip install -r tool/icon_requirements.txt
& "$env:TEMP\pi-gui-icon-tools\Scripts\python.exe" tool/generate_app_icon.py
& "$env:TEMP\pi-gui-icon-tools\Scripts\python.exe" tool/generate_app_icon.py --check
flutter build windows --release
```

生成器相对自身路径定位项目根目录，不依赖当前工作目录。每个尺寸均直接从 SVG 渲染，不把小图放大，也不依赖系统字体。ICO 包含 16、20、24、32、40、48、64、128、256px 的 32-bit PNG 帧，适用于当前 Windows 10/11 桌面目标。生成前检查 PNG 尺寸，`--check` 不修改文件，内容不一致时返回非零退出码。

构建输出：`build/windows/x64/runner/Release/pi_gui.exe`。资源生成依赖只在开发工具环境里安装；正常构建已有 `.ico` 不需要 Python。其他 Windows 构建注意事项见 [Windows 构建说明](windows_build.md)。

## 验证与限制

- `flutter analyze --no-pub` 通过，当前 Debug GUI 已热重载标题栏标记。
- 在不修改用户外观偏好的独立预览中检查浅 / 深两种主题，字形与镂空正常；检查实际标题栏的尺寸、位置和背景融合。预览及临时 helper 已移除，没有重启 GUI / Pi 或切换聊天会话。
- 使用独立 ICO 解析器逐帧确认 9 个尺寸、深色背景、白色笔画与镂空像素；生成器 `--check` 通过。
- Windows Release 构建通过。以 `LoadLibraryEx(... LOAD_LIBRARY_AS_DATAFILE)` 读取新 EXE，确认 `IDI_APP_ICON` 的 9 个图标资源逐字节匹配生成的 PNG 帧；未执行或替换正在运行的 Debug 程序。
- 当前 Flutter beta 的 inspector 截图代理 `_MulticastCanvas` 没实现 `restoreToCount`，截取 `vector_graphics 1.2.3` 的矢量内容时会报错并产生不完整截图。这是截图路径问题，不通过修改 SVG、改成位图渲染或修改 Flutter SDK 来绕开。验证改用 VM helper 在帧结束后调用现有 `RenderRepaintBoundary.toImage()`，只读取应用自身的已绘制图层，不抓取其他窗口；正常绘制与替代截图流程没有运行时错误。

参考：[flutter_svg](https://pub.dev/packages/flutter_svg)、[Microsoft Windows 图标尺寸说明](https://learn.microsoft.com/en-us/windows/apps/design/iconography/app-icon-construction)。
