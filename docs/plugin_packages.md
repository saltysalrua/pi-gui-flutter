---
title: "插件页：Pi 一键更新、插件市场与插件管理"
version: "1.0.0"
status: "implemented"
type: "feature"
tags: [flutter, settings, packages, pi-backend, npm]
---

# 插件页：Pi 一键更新、插件市场与插件管理

设置页现在有三类入口：**外观**、**pi**、**插件**。本文覆盖三件事：

1. **pi 页一键更新**：发现新版本后直接在页面里完成更新，不用打开终端。
2. **插件市场**（插件页 → 市场 Tab）：浏览并安装 npm 上带 `pi-package` 关键词的公开包，数据与 [pi.dev/packages](https://pi.dev/packages) 同源。
3. **插件管理**（插件页 → 管理 Tab）：列出已安装的插件包与它们提供的扩展 / 技能 / 提示词 / 主题资源，逐项启用或停用，语义与终端里的 `pi config`（全局模式）完全一致；还可移除、更新插件。

## 使用方法（人类视角）

### pi 一键更新

- 打开 **设置 → pi**。页面会自动查询 npm 上的最新版本。
- 发现新版本时会出现提示卡片，点击 **立即更新** 即可。更新会运行 `pi update --self`，输出实时显示在 **更新输出** 折叠块里。
- 更新完成不需要重启本应用：正在运行的会话继续用当前版本，之后**新开的会话**自动使用新版本。
- 更新失败时下方会显示原因；也可以展开 **手动更新命令**，复制到终端执行。

### 插件市场

- 打开 **设置 → 插件 → 市场**。列表默认显示全部 `pi-package` 包；列表上方有**独立的搜索框**，输入后实时搜索 npm，顶部下拉可切换排序（**相关性 / 下载量 / 最近更新 / 名称**）。
- 设置页左侧的共享搜索框在本页仍然生效：它会即时过滤市场列表（包名/简介/关键词）与管理页的条目，不额外发网络请求。
- 每个条目显示包名、简介、作者、版本、更新时间、月下载量，以及「扩展」「技能」类型标签；点 **打开 npm 页面** / **打开仓库** 跳转对应页面。
- 点 **安装** 运行 `pi install npm:<包名>`，进度与输出显示在列表下方的 **操作输出** 卡片；完成后按钮变成 **已安装** 徽章。
- 市场加载失败时，失败卡片会显示具体错误码（如 `REGISTRY_HTTP_ERROR`、超时等）；管理页读取失败同理。上报问题时请附上该错误码。

### 插件管理

- 打开 **设置 → 插件 → 管理**。已配置的插件包逐个成卡：来源（如 `npm:pi-lens`）、安装目录、版本徽章与操作按钮（**更新** / **移除**，移除前有确认弹窗）。
- 卡片内按资源类型（扩展 / 技能 / 提示词 / 主题）列出该包提供的每项资源，右侧下拉切换 **启用 / 停用**——写入的配置与 `pi config` 逐字节一致（顶层资源写 `settings.json` 的 `+/-` 模式条目；包资源写进包条目的筛选数组）。
- **检查更新** 会联网比对每个 npm/git 插件的最新版本；发现可更新项后可用 **全部更新**（等价 `pi update --extensions`）或单包 **更新**。
- 本页只管理**全局**（`~/.pi/agent`）范围；项目级插件请在项目目录里用 `pi config -l` 管理（页面上有提示文案）。

## 架构（Agent 视角）

### 关键代码路径

| 路径 | 职责 |
| --- | --- |
| `assets/backend/gui_packages.mjs` | `GuiPackagesBridge`：复用 Pi SDK 的 `DefaultPackageManager` / `SettingsManager`（`dist/index.js`），提供 state / check_updates / install / remove / update / toggle 六个命令 |
| `assets/backend/workspace_manager.mjs` | `control()` 路由 `gui_packages_*` → `this.packages()`，惰性 import 桥接模块；`packageRoot` 经 `workspace_rpc.mjs` 的 `--gui-multiplex` main 传入 |
| `lib/core/rpc/pi_workspace_transport.dart` + `pubspec.yaml` | 解包六个后端 assets（新增 `gui_packages.mjs`） |
| `lib/core/rpc/pi_packages_types.dart` | `PiPackageEntry` / `PiResourceItem` / `PiPackagesState` / `PiPackagesProgress` / `PiPackagesFinished` 模型与 `PiPackagesService`（`requestGui` 封装） |
| `lib/ui/features/settings/controllers/packages_controller.dart` | `PackagesController`：状态机（load / run / toggle / searchGallery / setGallerySort）、npm registry 搜索（`npm config get registry` 优先，失败回退官方源）、`parseRegistrySearch` 纯函数、`sortGallery` 排序纯函数 |
| `lib/ui/features/settings/views/packages_settings_view.dart` | 插件页视图：市场/管理双 Tab、市场内搜索框＋排序下拉、共享搜索客户端过滤、条目渲染、确认弹窗、操作输出卡片 |
| `lib/ui/features/settings/controllers/pi_update_controller.dart` | 新增 `runSelfUpdate()`：流式运行 `pi update --self`，成功后重新 `load()` 刷新版本与更新日志 |
| `lib/ui/features/settings/views/settings_view.dart` | 设置外壳新增 `plugins` 页；`showSettings(context, control:)` 从 `HomeView` 接收首页 `WorkbenchController.control` |
| `tool/check_packages_rpc.mjs` | 无模型、无网络的 Node 探针：用一次性 `PI_CODING_AGENT_DIR` 验证状态枚举、启停写入 pattern、异步任务事件与参数校验 |
| `test/packages_controller_test.dart` | `parseRegistrySearch` 与 `sortGallery` 纯函数单测；`PiPackagesState.fromJson` 强类型映射回归（曾因 `Map.unmodifiable` 推断成 `List<dynamic>` 导致每次真实 state 都抛 TypeError、界面只显示笼统的 `PACKAGES_FAILED`） |

### 控制通道命令（channel: "control"）

| 命令 | 参数 | 返回 / 事件 |
| --- | --- | --- |
| `gui_packages_state` | 无 | `{version, agentDir, packages[], resources{extensions,skills,prompts,themes}[]}`（同步） |
| `gui_packages_toggle` | `{resourceType, path, enabled, origin, source, scope, baseDir}` | 新状态（同步；仅 `scope:"user"`，其余拒绝 `PACKAGE_SCOPE_READ_ONLY`） |
| `gui_packages_install` | `{operationId, source}` | 立即回 `{operationId}`；完成后 `gui_packages_finished` 携带新 state |
| `gui_packages_remove` | `{operationId, source}` | 同上；未配置返回 `PACKAGE_NOT_FOUND`（在 finished 事件里） |
| `gui_packages_update` | `{operationId, source?}` | 同上；无 `source` = 全部更新（等价 `pi update --extensions`） |
| `gui_packages_check_updates` | `{operationId}` | 立即回执；完成后 finished 事件 `data.updates[]` |

- 进度事件 `gui_packages_progress`：`{operationId, phase, action, source, message}`，来自 `DefaultPackageManager.setProgressCallback`。
- 完成事件 `gui_packages_finished`：`{operationId, kind, source, ok, data?, error?}`；`kind != check_updates` 时 `data` 是完整新 state。
- 长任务绝不阻塞请求通道：30 秒的 `requestTimeout` 只覆盖“立即回执”和 state/toggle。

### 数据结构示例

```jsonc
// gui_packages_state
{
  "version": 1,
  "agentDir": "C:\\Users\\Salty\\.pi\\agent",
  "packages": [
    { "source": "npm:pi-lens", "scope": "user", "filtered": false,
      "installedPath": "C:\\Users\\Salty\\.pi\\agent\\npm\\node_modules\\pi-lens" }
  ],
  "resources": {
    "extensions": [
      { "path": "C:\\Users\\Salty\\.pi\\agent\\npm\\node_modules\\pi-lens\\dist\\index.ts",
        "enabled": true, "source": "npm:pi-lens", "scope": "user",
        "origin": "package", "baseDir": "C:\\Users\\Salty\\.pi\\agent\\npm\\node_modules\\pi-lens" },
      { "path": "C:\\Users\\Salty\\.pi\\agent\\extensions\\qi-control.ts",
        "enabled": true, "source": "local", "scope": "user",
        "origin": "top-level", "baseDir": null }
    ]
    // skills / prompts / themes 同构
  }
}
```

### 实现要点与边界

- **不重复实现 pi 的发现逻辑**：资源枚举走 `DefaultPackageManager.resolve(onMissing→"skip")`，启停写入是从 `pi config`（`config-selector.js`）逐行移植的全局语义：顶层资源写 `settings.json` 的 `extensions/skills/prompts/themes` `+`/`-` 模式条目；包资源写进 `packages` 数组对应条目的筛选数组，空筛选折叠回字符串条目，重新启用会保留 `+pattern`（与 pi config 行为一致）。桥接层 `cwd = agentDir`，项目级资源不会泄入本页。
- **每次读前 `settingsManager.reload()`**，外部手改 `settings.json` 不会被内存旧值覆盖；写后 `flush()` 落盘。
- **市场搜索**：市场 Tab 自带搜索框，Dart `HttpClient` GET `<registry>/-/v1/search?text=keywords:pi-package <query>&size=250`；registry 先取 `npm config get registry`（尊重用户的镜像源与 .npmrc），异常或空结果时回退 `https://registry.npmjs.org/`。搜索框输入 350ms 防抖，旧请求带序号丢弃。**排序在客户端完成**（`sortGallery` 纯函数）：相关性按 registry 的 `searchScore`，其余按月下载量/更新时间/名称。左侧共享搜索框只做客户端过滤。npm 探测超时时只 `taskkill /PID <探针pid> /T /F` 杀掉自己那棵进程树，绝不会按镜像名杀全机 npm 进程。
- **pi 一键更新**：`Process.start('pi', ['update', '--self'])`，stdout/stderr 行流合并进 `selfUpdateLog`（上限 500 行），10 分钟超时杀树；成功后 `load()` 重读磁盘上的 package.json / CHANGELOG。npm 替换的是磁盘文件，运行中的 Node 进程持有旧代码继续工作，无需重启。
- **后端版本边界**：`gui_packages.mjs` 依赖 Pi SDK 导出的 `DefaultPackageManager`、`SettingsManager`、`getAgentDir`（pi 0.85.1 已具备）；新后端在**下次正常启动**更新后的应用时装载，热重载不能替换已运行的 Node 模块。
- **失败可诊断**：市场/管理页失败卡片显示具体错误码。非 RPC 异常（解析 TypeError、超时、OS 错误）不再折叠成笼统的 `PACKAGES_FAILED`，而是直接显示异常内容；RPC 错误显示后端错误码，未知结果超时显示 `OUTCOME_UNKNOWN`。
- i18n 词条：`lib/l10n/app_zh.arb` / `app_en.arb` 的 `piUpdate*` 与 `plugins*` 前缀组（排序：`pluginsSortLabel/Relevance/Downloads/Updated/Name`；失败详情：`pluginsGalleryFailedDetail` / `pluginsLoadFailedDetail`）。

## 不涉及的范围

- 项目级（`-l` / `.pi/settings.json`）启停与覆盖（`inherit/load/unload` 状态机）不在本页；仅展示项目徽章并提示用 `pi config -l`。
- 市场「月下载量」来自 registry 搜索 API；镜像源不提供时为空。
