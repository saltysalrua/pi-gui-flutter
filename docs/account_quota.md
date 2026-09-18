---
title: 账号额度 (Account Quota)
feature: settings-quota
status: stable
updated: 2026-09-18
---

# 账号额度页 (Account Quota)

设置页新增"账号额度"导航项。目前只接入一个账号来源：读取 Pi 保存的
OpenAI Codex OAuth 登录，查询 ChatGPT 套餐的实时用量窗口（5 小时 / 7 天滑动窗口）。

## 人类视角

**入口**：设置 → 侧边栏（或窄窗口的页面下拉框）→ "账号额度"。

**会看到什么**：

- 账号信息：服务（OpenAI Codex）、邮箱、套餐类型、令牌有效期。
- 用量窗口：近 5 小时和近 7 天两个进度条，显示已用百分比、剩余百分比和重置时间。
  进度条颜色随用量变化：正常绿色 → ≥70% 黄色 → ≥90% 红色。
- 积分余额：按需付费积分，未开通时显示"无积分"。
- 顶部"刷新"按钮随时重新查询；达到限额时页面顶部显示黄色警告条。

**数据来源与安全性**：

- 登录令牌来自 Pi 自己的 `~/.pi/agent/auth.json`（即 `pi auth login` 流程保存的文件），本页只读，绝不修改。
- 额度来自 ChatGPT 官方的只读接口（与 Codex 桌面端右上角用量条同源），查询本身不消耗任何用量。

**常见问题**：

- "未找到 Codex 登录信息" → 先在 Pi 里完成 Codex 登录，再回本页刷新。
- "令牌已过期或失效" → 在终端运行 `pi auth check --provider openai-codex`
  刷新令牌，或在 Pi 中重新登录后重试。
- "无法连接 ChatGPT 服务" → 网络问题，检查后重试。

## Agent 视角

### 关键代码路径

| 角色 | 文件 |
|---|---|
| Controller | `lib/ui/features/settings/controllers/quota_controller.dart`（`QuotaController.shared` 为应用级共享实例） |
| 设置页视图 | `lib/ui/features/settings/views/quota_settings_view.dart` |
| 侧栏入口 + 悬停浮窗 | `lib/ui/features/home/widgets/quota_sidebar_button.dart` |
| 页面注册 | `lib/ui/features/settings/views/settings_view.dart`（公开枚举 `SettingsPage`，`showSettings(initialPage:)` 支持深链） |
| i18n | `lib/l10n/app_zh.arb` / `app_en.arb` 中的 `quota*` 词条（gen-l10n 生成 dart） |
| 测试 | `test/quota_controller_test.dart` |

### 数据流

```
~/.pi/agent/auth.json (openai-codex: access/accountId/expires)
        │ QuotaController.parseAuthEntry()
        ▼
GET https://chatgpt.com/backend-api/wham/usage
    Headers: Authorization: Bearer <access>
             ChatGPT-Account-Id: <accountId>
        │ QuotaController.parseUsage()
        ▼
CodexUsageSnapshot → QuotaSettingsContent 渲染
```

- `QuotaController.shared` 是应用级共享实例（侧栏悬停浮窗与设置页共用）：
  悬停触发 `ensureFresh()`——首次加载显示 loading，之后缓存超过 5 分钟才静默
  重取，静默刷新期间保留旧数据不闪转圈。
- auth.json 路径解析在 `QuotaController.authJsonPath`：优先 `PI_CODING_AGENT_DIR`
  环境变量，其次 `USERPROFILE`/`HOME` 下的 `.pi/agent/auth.json`，与 Pi 后端
  `getAuthPath()` 行为一致。
- 不经过 Pi RPC，不占用任何会话通道；Controller 短生命周期，随设置页关闭销毁。
- 状态机：`loading → ready | missing | failed`；失败细分为
  `network / unauthorized / parse`，401/403 视为令牌失效。

### 响应体结构（wham/usage，节选）

```json
{
  "email": "user@example.com",
  "plan_type": "plus",
  "rate_limit": {
    "allowed": true,
    "limit_reached": false,
    "primary_window": {
      "used_percent": 42,
      "limit_window_seconds": 18000,
      "reset_at": 1789756724
    },
    "secondary_window": { "used_percent": 79, "reset_at": 1789822318 }
  },
  "credits": { "has_credits": false, "balance": "0" }
}
```

`primary_window` 为 5 小时窗口，`secondary_window` 为 7 天窗口，`reset_at`
是 Unix 秒级时间戳。解析只保留本页实际渲染的字段，未知字段一律忽略，
后端新增字段不会破坏页面。

### 扩展更多账号

后续接入其他 provider 时：在 `quota_controller.dart` 中为各 provider 定义
各自的 snapshot 模型与 fetcher，视图侧把 `_AccountGroup`/`_UsageGroup`
按 provider 分组渲染即可；`QuotaStatus` 状态机可复用。