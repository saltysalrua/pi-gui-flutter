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
- **最新版本**：打开该页时自动从 npm 在线查询一次；也可点击 **检查更新** 手动重查。查询失败会在行下方提示，重试即可。
- **发现新版本**时，页面会显示提示卡片和更新命令 `npm install -g @earendil-works/pi-coding-agent@latest`（自带复制按钮）。更新前需要先完全退出本应用和正在运行的 Pi，再在终端里执行命令。
- **npm 页面**：在浏览器打开该包的 npm 介绍页。
- **更新日志**：来自已安装包内的 `CHANGELOG.md`，按版本折叠展示，当前安装的版本右侧有“当前”标签。默认只显示最近 30 个版本，点击 **显示更多版本** 继续加载。设置页顶部的搜索框可以按版本号、日期或内容过滤。

本页不自动安装或下载任何东西：所有更新操作都由用户在终端自行执行，GUI 只负责查询和展示。

## 实现要点

- 更新查询走 `npm view @earendil-works/pi-coding-agent dist-tags.latest`，安装信息走 `npm root -g` + 直接读取包内 `package.json` / `CHANGELOG.md`。复用 npm CLI 意味着用户 `.npmrc` 里的镜像源和代理设置自动生效。
- **不使用 Pi RPC**：本页不创建 Pi 进程、不碰正在运行的会话，与首页 `PiChannelHub` 完全无关。
- npm 子进程带 30 秒超时；超时后用 `taskkill /PID <pid> /T /F`（Windows）或 `SIGKILL` 清理整棵进程树，避免残留 node 进程。
- 版本比较只按数字段（忽略预发布后缀），`parseChangelog` / `compareVersions` 为纯函数并有单元测试。
- 更新日志分页 + `AppDisclosure` 折叠，避免一次性构建数百个 Markdown 块；条目展开状态经 `PageStorage` 按版本号持久。

## 关键代码路径

| 路径 | 职责 |
| --- | --- |
| `lib/ui/features/settings/controllers/pi_update_controller.dart` | `PiUpdateController`：npm 定位/查询、CHANGELOG 解析、版本比较与状态机 |
| `lib/ui/features/settings/views/pi_settings_view.dart` | `PiSettingsContent`：更新检查分组、提示卡片、`_ChangelogSection` 分页日志 |
| `lib/ui/features/settings/views/settings_view.dart` | `SettingsView` 外壳：外观 / pi 双页签、搜索共享、窄窗 `AppSelect` 切页 |
| `test/pi_update_controller_test.dart` | CHANGELOG 解析与版本比较的纯函数单测 |

## 不涉及 RPC 命令或事件

本页纯本地 + npm CLI 查询，不产生任何 Pi RPC 交互；i18n 词条位于 `lib/l10n/app_zh.arb` / `app_en.arb` 的 `pi*` 前缀组。
