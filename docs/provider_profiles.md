---
title: "Provider 配置与可选插件安装"
version: "2.0.0"
status: "implemented"
type: "feature"
tags: [flutter, pi-rpc, extensions, provider]
---

# Provider 配置

入口：**设置 → 插件 → Provider 配置**。左边是配置列表，右边直接编辑选中的配置（参考 Cherry Studio 的模型服务页），不再弹窗。

每个配置保存后就是 Pi 里的一个普通 Provider（和手写的猫饭 / yuukarin 中转扩展一样），它的模型直接出现在模型选择器里。**没有“使用此配置 / 默认配置”这一步**：选哪个模型完全由模型选择器和 Pi 自己的会话恢复决定。

## 使用步骤

1. 点「添加配置」，填名称（就是模型选择器里的 Provider 名，可用中文）、API 地址、Key，选接口类型。
2. 点「获取模型列表」或直接「保存」（没有模型时保存会先获取一次）。列表会显示每个模型的推理 / 图片 / 上下文长度标签，这些来自 models.dev 公共目录。
3. 勾选框控制模型是否出现在模型选择器里；模型多时可筛选、全部显示/隐藏。服务商不返回的模型可在下方手动添加（带「手动」标签，可移除）。
4. 「自动同步模型列表」默认开：插件会定期请求 `/models`，服务商新增的模型自动出现，下架的自动消失。服务商没有列表接口时关掉，改为手动添加。
5. 保存后，运行中的会话约 1 秒内自动更新模型列表（插件监听配置文件），**不会切换任何会话当前的模型**，也不需要重启。改名称 = 改名：保存时把配置和发现缓存一起搬到新名字，旧名字的 Provider 从模型选择器消失，同样约 1 秒内生效；已在用旧 Provider 的会话请重新选一次模型。

切换配置时有未保存修改会先确认；「放弃更改」可恢复。窄窗（<640px）列表与详情上下排列。

## 插件 2.0（修复“重启后模型被顶掉”）

1.x 插件在每次 `session_start`（包括恢复旧会话、重启 GUI）都会 `pi.setModel()` 到“默认配置”的默认模型，而且 Provider 只在 session_start 才注册，Pi 恢复会话时找不到原模型。2.0：

- 扩展加载时就用 `pi.registerProvider()` 注册全部配置，带 `refreshModels` 钩子，Pi 自己的离线/后台目录刷新会调用它。
- 从不调用 `setModel`；旧配置里的 `active`、`defaultModel` 被忽略，GUI 保存时会删掉。
- 已发现的模型 ID 缓存到 `<agentDir>/.cache/provider-switch/discovered-<name>.json`（按 `api + baseUrl` 区分），models.dev 精简目录缓存到同目录 `models-dev.json`（24 小时刷新）。后台刷新不改写配置文件，多个 Pi 进程也不会互相覆盖配置。
- 新增/改地址的配置没有缓存时，插件后台立即请求一次 `/models` 再注册（Pi 只刷新已注册的 Provider）。
- 能力优先级：模型条目 > 命中的 modelRule > 图片探测缓存 / Pi 内置目录 > models.dev（中转装饰前缀如 `∞【xx】claude-opus-4-5` 会被剥离匹配）> 配置 `reasoning` > 默认值。
- 移除 `/switch`、`/provider-thinking`；保留 `/providers`、`/provider-refresh`、`/provider-add`、`/provider-remove`。

**升级入口**：检测到已装的是随应用打包的旧版本（安装路径含 `pi-provider-switch/<版本>/` 且不等于当前 `ProviderPluginInstaller.version`），页面顶部出现「更新 Provider 插件」。确认后先安装新版本目录，再移除旧登记。已打开的会话继续跑旧插件，新会话加载新版。**不重启承载 Agent 的 Pi。** 手动安装的插件不提示。

安装仍然只在用户点击并确认后进行，打开页面、读取、保存不会自动安装。

## 配置文件格式（2.0）

```jsonc
{
  "profiles": {
    "猫饭": {
      "baseUrl": "https://example.test/v1",
      "api": "openai-completions",
      "apiKey": "$MY_KEY",
      "syncModels": false,                // 省略 = true
      "models": [                         // 只存用户固定的内容
        { "id": "alias", "manual": true },
        { "id": "embed", "disabled": true },
        { "id": "gpt-5", "contextWindow": 400000 }
      ],
      "modelRules": [], "headers": {}     // 高级字段，GUI 原样保留
    }
  }
}
```

1.x 的普通 `{id}` 条目在该端点首次获取成功前会继续显示；获取成功后只保留 manual / disabled / 带自定义字段的条目。

## Key

编辑时已存 Key 不回显，留空保留；输入新 Key 替换，或选「移除已存 Key」。建议用 `$ENV_VAR`，配置文件可能含明文，**不要提交**。改 API 地址或接口类型后必须重新输入 Key 或移除（`PROFILE_KEY_ENDPOINT_CHANGED`），不会把旧 Key 发给别的服务；补齐 `/v1` 不算改地址。列表请求不跟随重定向，Google Key 只放请求头。Key 为空时插件注册占位 Key `none`，本地无鉴权服务也能在模型选择器中可用。

## 接线（Agent 视角）

- 插件源码：`pi-provider-switch/`（`package.json` 版本 2.0.0）。
  - `extensions/provider-switch.ts`：注册 / refreshModels / 文件监听 / 图片探测 / payload 改写 / 命令。
  - `extensions/provider-switch/catalog.mjs`：纯 ESM，`discoverModelIds`、`ModelsDevCatalog`、`profileModelEntries`、`resolveModel`、发现缓存读写。**插件和 GUI 后端共用同一文件**：`PiWorkspaceTransport` 把它复制为后端临时目录的 `provider_catalog.mjs`；开发脚本直接从 `assets/backend` 回退导入仓库源码。
  - `extensions/provider-switch/inputs.ts`：图片探测（默认关闭）。
  - pubspec 打包上述 4 个文件；`ProviderPluginInstaller.prepareSource()` 写入 `<应用支持目录>/pi-provider-switch/2.0.0/`，内容不同才覆盖。
- GUI 后端：`assets/backend/gui_provider_profiles.mjs`（control 通道，`workspace_manager.mjs` 路由）。
- Flutter：`lib/core/rpc/pi_provider_profiles_types.dart`（`PiProviderModel/Profile/State/ModelList`、服务）、`lib/ui/features/settings/controllers/provider_profiles_controller.dart`（`selected`、`changed`）、`lib/ui/features/settings/views/provider_profiles_view.dart`（`_ProfileList`、`_ProfileEditor`、`_ModelRow`，复用 AppCard / AppNavTile / AppTextField / AppSelect / AppSettingRow / AppBadge / AppActionButton / AppIconButton / AppDialog）。
- 模型选择器刷新：`showSettings(onProvidersChanged:)` ← `HomeView._refreshModelLists`，保存/删除后延迟 900ms 对每个会话 `ModelPickerController.refresh()`（只重读，不 set_model）。
- Provider 写请求（save/remove）超时保持待确认屏障，不重放、不杀 Pi（`PiRpcClient.isProviderMutation`）。

### Control RPC

| 命令 | 请求 | 返回 |
| --- | --- | --- |
| `gui_provider_profiles_state` | 无 | `{profiles:[{name,baseUrl,api,hasApiKey,syncModels,syncedAt,models:[{id,reasoning,image,contextWindow,enabled,manual,discovered,custom}]}]}` |
| `gui_provider_profiles_models` | `{name?,baseUrl,api,apiKey?,clearApiKey?}` | `{baseUrl,models:[{id,reasoning,image,contextWindow}]}` |
| `gui_provider_profiles_save` | `{name,createOnly?,renameFrom?,profile:{baseUrl,api,syncModels,manual:[id],disabled:[id],listed:[id],discovered?:[id],apiKey?,clearApiKey?}}` | 新 state（`renameFrom` ≠ `name` 时为改名：条目+发现缓存一次性搬到新名字，新名字已占用报 `PROFILE_EXISTS`，旧名字不存在报 `PROFILE_NOT_FOUND`） |
| `gui_provider_profiles_remove` | `{name}` | 新 state（同时删发现缓存） |

`gui_provider_profiles_activate` 已删除（返回 `UNKNOWN_COMMAND`）。`discovered` 是本次编辑中获取到的列表，写入发现缓存而非配置；`listed` 是编辑器显示的全部 ID，用于在首次获取前保留 1.x 条目。保存后必须至少一个模型可见，否则 `PROFILE_NO_MODELS`。其余错误码：`PROFILE_INVALID/NAME_INVALID/EXISTS/NOT_FOUND/KEY_ENDPOINT_CHANGED`、`PROFILES_INVALID`、`MODELS_UNREACHABLE/UNAUTHORIZED/HTTP_ERROR/NOT_JSON/EMPTY/KEY_ENV_MISSING/KEY_COMMAND_FAILED`，不回传远端正文。models 列表请求最多等 models.dev 首次下载 6 秒，超时就先返回不带标签的结果。

## 验证

- `node tool/check_provider_switch_rpc.mjs`：隔离 `PI_CODING_AGENT_DIR` + 回环 `/models`，启动真实 `pi --mode rpc --extension`：加载即注册、decorated ID 匹配 models.dev、disabled 隐藏、manual 保留、无 Key 本地配置可用；**恢复一个记录了非默认模型的会话，模型保持不变**；运行中改配置文件新增 Provider 自动出现且不切模型。不调用模型。
- `node tool/check_provider_profiles.mjs`：后端适配器（保存/编辑/改名/删除、旧字段清理、发现缓存随改名迁移、标签、Key 不回显、不跟随重定向）。
- `flutter test test/provider_profiles_test.dart`：强类型映射、保存请求字段、改名请求字段、版本解析、超时写屏障。
- UI 用 `.dart_tool/glass_qa/app/lib/provider_qa.dart` 离线夹具（假 control transport）构建独立 exe 截图检查，不碰生产 GUI。

## 边界

- 单模型的高级字段（transport、上下文上限覆盖、`modelRules`、`headers`）仍需编辑配置文件；GUI 原样保留。
- models.dev 标签仅供参考；匹配不到的模型按纯文本、不推理、128K 处理。
- 列表最多 500 个 ID，不处理厂商分页与特殊认证。
- 多 GUI 进程同时写配置无跨进程锁；插件后台只写缓存文件，不写配置。
