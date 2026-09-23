---
title: "Provider 配置与可选插件安装"
version: "1.1.0"
status: "implemented"
type: "feature"
tags: [flutter, pi-rpc, extensions, provider]
---

# Provider 配置

入口：**设置 → 插件 → Provider 配置**。可添加、编辑、删除配置，设置默认配置，以及切换当前会话。未安装或停用插件时仍可先管理配置；使用配置前需安装/启用插件。

## 添加与获取模型

1. 点击「添加配置」，填写名称、API 地址、接口类型和可选 API Key。名称限 1–64 个字母、数字、点、横线或下划线，以字母或数字开头；不能覆盖已有同名配置。
2. **模型 ID 不必先填**：点击「获取模型列表」，或直接把模型留空保存，都会经 Node 控制通道请求服务商的 `/models`。不会发送聊天/图片探测请求。
3. 获取成功后填入模型列表，并可选择默认模型。不另选时使用列表第一项。缺少 `/v1` 的 OpenAI/Anthropic 兼容地址会尝试补齐，表单回显实际成功的地址。
4. 服务商不提供列表接口时，可以手填模型 ID（每行一个或逗号分隔）。获取失败保留草稿，不写入半成品配置。刷新只补充模型，不移除手动 ID，也不改变仍有效的默认模型。
5. 保存后点击「使用此配置」。当前会话确实加载插件且空闲时立即切换；未加载时只保存默认配置，供新会话/下次启动使用。会话正在输出、压缩或有排队消息时拒绝切换，不打断工作。

表单有常驻字段标签、Key 显隐（仅显示本次输入）、获取中/失败反馈。请求期间锁定表单，防止迟到结果覆盖后续输入；提交未完成时不能关闭弹窗。表单内部可滚动，底部操作保持可见。配置卡显示接口、模型数量、默认模型和 Key 状态；设置搜索也会筛选名称、地址、接口与模型 ID，窄窗插件 Tab 自动换行。

交互参考：[Cherry Studio 模型服务配置](https://cherryai.com.cn/docs/zh-cn/pre-basic/providers/)的「地址/Key → 获取列表 → 选择模型」流程，保留项目已有紧凑公共组件。

## Key 与安装

编辑时已存 Key 不回显，留空保留；输入新 Key 可替换，也可明确选择「移除已存 Key」。建议用 `$ENV_VAR`。配置文件 `~/.pi/agent/provider-profiles.json` 可能保存明文密钥，**不要提交此文件**。改 API 地址或接口类型后，必须重新输入 Key 或明确移除；不会将原 Key 自动发送给另一个服务。补齐同地址的 `/v1` 不要求重复输入。列表请求不跟随重定向，Google Key 只放请求头、不拼 URL。

仅用户点击「安装 Provider 插件」并确认权限后才安装。已安装但停用时提供「启用插件」，复用插件管理的资源开关。打开页面、读取配置、保存草稿均不自动安装，不修改 Pi 的 `models.json`。

安装源位于应用支持目录的版本化 `pi-provider-switch/1.0.0/`，通过既有 `PackagesController.installSource` / `gui_packages_install` 让 Pi PackageManager 登记到全局配置。**不要从 GUI 退出后会被删除的后端临时目录安装**。卸载仍在设置 → 插件 → 管理。不会强制重启/重载正在运行的 Pi；新安装的扩展在新会话/下次启动加载。

图片能力的自动付费探测默认关闭。只有手动在扩展配置顶层设置 `"imageProbeEnabled": true` 才启用；显式 `input` 和 Pi 内置目录提供的能力无需探测。

## 接线（Agent 视角）

- `lib/ui/features/settings/views/packages_settings_view.dart` 第三 Tab → `provider_profiles_view.dart`：复用 AppCard、AppActionButton、AppDialog、AppTextField、AppSettingRow、AppSelect、AppBadge。错误码在 View 映射为 i18n 提示，未知错误不直接显示堆栈/密钥。
- `lib/core/services/provider_plugin_installer.dart`：用户确认后准备持久安装源；Widget 不自行操作文件。
- `lib/ui/features/settings/controllers/provider_profiles_controller.dart` / `lib/core/rpc/pi_provider_profiles_types.dart`：强类型 RPC 映射；当前会话由 `HomeView` → `showSettings(activeSessionClient:)` 动态提供，不使用控制通道发送 `/switch`。
- `PiRpcClient.hasProviderSwitchCommand` 核实 `get_commands` 中的命令来源，避免未知 `/switch` 被当成普通问题发送给模型。切换后回读会话 provider/model ID 和配置 active，而非仅收到 prompt 回执就报成功。
- Provider 写请求超时保持待确认屏障：`gui_provider_profiles_save/remove/activate` 未返回时，后续 Provider 读写须等原请求确认，不重放写操作，不阻塞其他功能的 RPC，不杀 Pi。
- `assets/backend/gui_provider_profiles.mjs` 经 `workspace_manager.mjs` 的 control 路由；使用 Pi SDK `getAgentDir()` 找到扩展自有 `provider-profiles.json`。每次操作重读、单进程写串行化、原子写、出站密钥仅返回 `hasApiKey`。不碰 Pi 私有模型/会话文件。
- `pi-provider-switch/extensions/provider-switch.ts` 负责实际 provider 注册、`/switch`、后台目录刷新等；GUI 不重写 Agent 请求逻辑。
- 后端脚本在 `pi_workspace_transport.dart` / `pubspec.yaml` 打包。**旧运行中 Node 不会随 Flutter 热重载更新**；若提示不支持命令，等任务完成后重启 GUI。不要为了验证重启承载 Agent 的应用。

### Control RPC

| 命令 | 请求字段 | 返回 |
| --- | --- | --- |
| `gui_provider_profiles_state` | 无 | `{active,profiles:[{name,baseUrl,api,reasoning,models:[id],defaultModel,hasApiKey}]}` |
| `gui_provider_profiles_models` | `{name?,baseUrl,api,apiKey?,clearApiKey?}` | `{baseUrl,models:[id]}` |
| `gui_provider_profiles_save` | `{name,createOnly?,profile:{baseUrl,api,reasoning,models,defaultModel,apiKey?,clearApiKey?}}` | 新的脱敏 state |
| `gui_provider_profiles_activate/remove` | `{name}` | 新的脱敏 state |

获取列表不要求名称和模型 ID；编辑时 `name` 用于在后端复用原 Key。`clearApiKey: true` 不得与非空新 Key 同时提交。新增表单发送 `createOnly: true`，后端重读后再次防止重名覆盖。界面的空模型自动保存流程是 **models → save** 两步；save 本身仍严格要求至少一个模型与有效默认模型。

```json
{"type":"gui_provider_profiles_models","baseUrl":"https://example.test/v1","api":"openai-responses","apiKey":"$TEAM_KEY"}
{"type":"gui_provider_profiles_save","name":"team","createOnly":true,"profile":{"baseUrl":"https://example.test/v1","api":"openai-responses","reasoning":false,"models":["model-a"],"defaultModel":"model-a","apiKey":"$TEAM_KEY"}}
```

输入错误：`PROFILE_INVALID` / `PROFILE_NAME_INVALID` / `PROFILE_EXISTS`；文件损坏：`PROFILES_INVALID`；配置不存在：`PROFILE_NOT_FOUND`；Key 路由变化：`PROFILE_KEY_ENDPOINT_CHANGED`。列表失败使用 `MODELS_UNREACHABLE/UNAUTHORIZED/HTTP_ERROR/NOT_JSON/EMPTY/KEY_ENV_MISSING/KEY_COMMAND_FAILED`，不回传远端响应正文。

## 验证与尚未覆盖的功能

- `node tool/check_provider_profiles.mjs`：隔离 `PI_CODING_AGENT_DIR`；本地回环 HTTP 验证三种列表格式、`/v1` 补齐、密钥不回显/不跨地址复用、不跟随跳转、清除 Key、重名防护以及高级字段保留。不安装扩展、不访问外部模型。
- `flutter test test/provider_profiles_test.dart test/pi_rpc_client_test.dart`：强类型编解码、命令来源、忙碌/成功/失败切换，以及超时写屏障。
- UI 使用临时离线 Controller 弹窗热重载走查：常规尺寸、420px/150% 文字缩放、获取失败保留草稿、模型留空自动获取后保存并关闭。截图仅来自应用 RenderRepaintBoundary；检查后删除 QA helper 并热重载，无生产测试入口。

当前边界：
- 高级 `headers/modelRules`、单模型 transport/图片能力/上下文上限仍需编辑扩展配置文件；GUI 会保留未移除模型和 profile 的额外字段，但列表请求暂不使用自定义 headers。
- 列表读取当前响应，最多 500 个 ID；未处理厂商专有分页或 Azure/Bedrock 等特殊认证，可手动补充 ID。
- 插件自己的 `/provider-add` 与多个 GUI 进程写同一 JSON 尚无跨进程锁。
- 全局默认影响之后启动的会话；不会强制切换其他已打开会话。保存配置也不自动重新注册当前会话，须明确点击「使用此配置」。
- 发布时需包含 `pi-provider-switch/package.json`、`extensions/provider-switch.ts`、`extensions/provider-switch/inputs.ts` 三个打包资源；已安装版本不会在打开设置时被悄悄覆盖。
