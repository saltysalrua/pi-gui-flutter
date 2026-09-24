---
title: "Pi 设置页：更新检查与更新日志"
version: "1.0.0"
status: "implemented"
type: "feature"
tags: [flutter, settings, npm, pi-backend]
---

# Pi 设置页：更新检查与更新日志

## 使用方法

点击主界面左下角 **设置**，在左侧分类选择 **pi**（窄窗口下用左上角下拉框切换页面）。

- **当前版本**：本机 npm 全局安装的 Pi 包版本，行下方小字是安装目录。
- **最新版本**：应用启动时就会在后台查好；之后每 30 分钟自动静默重查，打开设置页直接看到结果。也可点击 **检查更新** 手动重查。查询失败会在行下方提示，重试即可。
- **刷新数据**：手动重新读取本地版本与更新日志并联网检查最新版本；平时无需手动点，后台会定期自动刷新。
- **发现新版本**时，页面会显示提示卡片和 **立即更新** 按钮：卡片内直接展开 **新版本更新说明**（从 npm 上已发布版本的包内在线获取 CHANGELOG，本地安装的日志只覆盖到当前版本）；点击 **立即更新** 后直接在本页运行 `pi update --self`，实时输出显示在 **更新输出** 折叠块里，成功后自动刷新版本与更新日志，无需打开终端。正在运行的会话继续用当前版本，之后新开的会话自动使用新版本。更新失败时下方显示原因，也可展开 **手动更新命令** 复制 `npm install -g @earendil-works/pi-coding-agent@latest` 到终端执行。在线说明获取失败时会提示改看 npm 页面。
- **npm 页面**：在浏览器打开该包的 npm 介绍页。
- **更新日志**：来自已安装包内的 `CHANGELOG.md`，按版本折叠展示，当前安装的版本右侧有“当前”标签。默认只显示最近 30 个版本，点击 **显示更多版本** 继续加载。设置页顶部的搜索框可以按版本号、日期或内容过滤。

更新命令会替换磁盘上的安装文件，不碰正在运行的进程：Pi 子进程已把旧代码读进内存继续工作，新 Pi 在之后新开的会话里生效。插件市场与插件管理另见 [插件页文档](plugin_packages.md)。

## 实现要点

- **应用级共享缓存**：`PiUpdateController.instance` 是全应用唯一实例（私庅 `_shared` 构造），`HomeView` 启动时 `load()` 预热一次；实例内部挂 30 分钟 `Timer.periodic` 调用静默 `refresh()`——只在有新快照时替换数据，失败时保留旧缓存，不把页面打成加载/失败态。设置页每次打开/切换只渲染缓存，绝不重新拉取；**刷新数据** 按钮（`controller.load()`）与失败卡片的重试是仅有的可见重拉入口。
- 更新查询走 `npm view @earendil-works/pi-coding-agent dist-tags.latest`，安装信息走 `npm root -g` + 直接读取包内 `package.json` / `CHANGELOG.md`。复用 npm CLI 意味着用户 `.npmrc` 里的镜像源和代理设置自动生效。
- **新版本更新说明**：检查到 available 后，按 `_latestVersion` 在线拉取已发布包内的 `CHANGELOG.md`（先 `unpkg.com`，失败回退 `cdn.jsdelivr.net`），用 `filterUpcomingEntries` 纯函数筛出比本地新的版本条目；同一目标版本的结果会缓存，`runSelfUpdate` 成功后清空。任一 CDN 都失败时只显示提示，不阻塞更新。
- **不使用 Pi RPC**：本页不创建 Pi 进程、不碰正在运行的会话，与首页 `PiChannelHub` 完全无关。
- npm 子进程带 30 秒超时；超时后用 `taskkill /PID <pid> /T /F`（Windows）或 `SIGKILL` 清理整棵进程树，避免残留 node 进程。在线 CHANGELOG 拉取每段 15 秒超时，仅本进程内 HttpClient。
- 版本比较只按数字段（忽略预发布后缀），`parseChangelog` / `compareVersions` / `filterUpcomingEntries` 为纯函数并有单元测试。
- 更新日志分页 + `AppDisclosure` 折叠，避免一次性构建数百个 Markdown 块；条目展开状态经 `PageStorage` 按版本号持久。

## 关键代码路径

| 路径 | 职责 |
| --- | --- |
| `lib/ui/features/settings/controllers/pi_update_controller.dart` | `PiUpdateController`：应用级单例（`instance`）、30 分钟静默刷新、npm 定位/查询、CHANGELOG 解析、在线新版本说明（unpkg → jsdelivr）、版本比较与状态机 |
| `lib/ui/features/settings/views/pi_settings_view.dart` | `PiSettingsContent`：更新检查分组、手动刷新行、提示卡片（含 `_buildUpcomingNotes` 新版本说明）、`_ChangelogSection` 分页日志 |
| `lib/ui/features/settings/views/settings_view.dart` | `SettingsView` 外壳：外观 / pi 页签，复用共享控制器不随弹窗销毁、搜索共享、窄窗 `AppSelect` 切页 |
| `lib/ui/features/home/views/home_view.dart` | 启动预热：`initState` 里 `PiUpdateController.instance.load()`（另见插件页文档的 packages 预热） |
| `test/pi_update_controller_test.dart` | CHANGELOG 解析、版本比较与新版本说明筛选的纯函数单测 |

## 不涉及 RPC 命令或事件

本页纯本地 + npm CLI 查询，不产生任何 Pi RPC 交互；i18n 词条位于 `lib/l10n/app_zh.arb` / `app_en.arb` 的 `pi*` 前缀组。
