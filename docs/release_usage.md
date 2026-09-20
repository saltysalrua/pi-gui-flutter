---
title: "Pi GUI 便携版使用说明"
type: "user-guide"
status: "maintained"
---

# Pi GUI 便携版使用说明

## Windows x64

1. 下载本次 Release 的 `pi-gui-flutter-<版本>-windows-x64.zip`，解压到有写入权限的目录。
2. 保留整个目录，包括 DLL、`data/` 和许可文件；运行 `pi_gui.exe`，不要只复制这个 EXE。
3. 运行环境需要 Windows x64、PATH 中可用的 Node.js，以及已安装并配置好模型的 Pi：

   ```powershell
   npm install -g @earendil-works/pi-coding-agent
   pi
   ```

   在 Pi 中完成模型和凭据配置后，再打开 GUI。项目当前验证的 Pi 版本为 `0.85.1`；包内不包含 Node.js、Pi、模型凭据或开发者配置。

4. 如果提示缺少 `VCRUNTIME140.dll` / `MSVCP140.dll`，从微软安装 [Visual C++ 2015–2022 x64 运行库](https://aka.ms/vs/17/release/vc_redist.x64.exe)。
5. 在 GUI 中选中要处理的项目目录后再发任务。Pi 工具会在选中目录内执行操作，可能修改文件或运行命令。

桌面毛玻璃需要 Windows 11 22H2+ 并开启系统透明效果；条件不满足时使用纯色背景，不影响其他功能。

## Linux x64

1. 下载本次 Release 的 `pi-gui-flutter-<版本>-linux-x64.tar.gz`，解压到有写入权限的目录。

   ```bash
   tar -xzf pi-gui-flutter-<版本>-linux-x64.tar.gz
   ./pi_gui
   ```

2. 保留整个目录，包括 `pi_gui`、`lib/`、`data/` 和许可文件；不要把可执行文件单独拷到别处。
3. 运行环境需要 GTK 3 运行库（Ubuntu / Debian 桌面通常自带，缺失时 `sudo apt install libgtk-3-0`）、PATH 中可用的 Node.js，以及已安装并配置好模型的 Pi：

   ```bash
   npm install -g @earendil-works/pi-coding-agent
   pi
   ```

   在 Pi 中完成模型和凭据配置后，再打开 GUI。包内不包含 Node.js、Pi、模型凭据或开发者配置。Linux 版未做桌面毛玻璃，窗口使用纯色背景，不影响其他功能。

## 文件校验

压缩包旁的 `.zip.sha256` / `.tar.gz.sha256` 记录 SHA-256。下载后可运行：

```powershell
Get-FileHash -Algorithm SHA256 .\pi-gui-flutter-<版本>-windows-x64.zip
```

```bash
sha256sum --check pi-gui-flutter-<版本>-linux-x64.tar.gz.sha256
```

将结果与 `.sha256` 文件中的哈希比较。当前发布包**没有代码签名**；哈希只能检查下载完整性，不能替代代码签名。Windows 可能显示未知发布者提示，请先核实下载来源。

## 更新与数据

关闭旧版后，将新包解压到新的目录再运行，不要覆盖正在运行的程序。应用外观配置与附件缓存使用 GUI 自有的系统应用数据目录，Pi 会话与模型配置由 Pi 管理；“便携版”仅表示无需安装器，并不表示用户数据全部写在解压目录。

项目原创代码采用 MIT 许可证，原文随包保存在 `LICENSE`；第三方代码、字体和图标仍适用各自许可，未确认授权来源的品牌图稿不在项目 MIT 授权范围内。

随包附有 `THIRD_PARTY_NOTICES.md`、`licenses/MiSans-LICENSE.pdf` 和 `licenses/MaterialIcons-LICENSE.txt`。Flutter / Pub 依赖许可保留在 `data/flutter_assets/NOTICES.Z` 中，并提供可直接阅读的 `licenses/Flutter-Pub-NOTICES.txt`。
