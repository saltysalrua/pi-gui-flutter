# pi-provider-switch

pi 的多 provider 管理扩展（cc-switch 风格）。所有 provider 配置放在一个文件里，运行时用 `pi.registerProvider()` 注册并切换，**不修改 `models.json`**。

## 安装

```bash
# 本地目录
pi install /path/to/pi-provider-switch

# 或从 git
pi install git:github.com/<user>/pi-provider-switch
```

安装后建立配置文件 `~/.pi/agent/provider-profiles.json`，可从 `provider-profiles.example.json` 复制修改。

## 命令

| 命令 | 作用 |
|---|---|
| `/switch [name]` | 切换 profile，不带参数弹出选择器 |
| `/providers` | 列出全部 profile 并选择激活 |
| `/provider-add` | 交互向导新建 profile，自动从 `/models` 拉取模型列表（支持 OpenAI / Anthropic / Google 三种返回格式） |
| `/provider-remove [name]` | 删除 profile |
| `/provider-thinking [name] [on\|off]` | 设置 profile 默认是否启用 thinking |
| `/provider-refresh [name]` | 立即重新拉取模型列表（默认当前 profile） |

每次 `/switch` 和会话启动都会先套用缓存的模型列表，然后后台重新拉取 `/models`：新增 id 追加；上游已消失且没有自定义配置、也不是 `defaultModel` 的 id 才会被删除；拉取失败保留缓存。

## 配置格式

```jsonc
{
  "active": "profile-name",
  "profiles": {
    "profile-name": {
      "baseUrl": "https://api.example.com/v1",
      "api": "openai-responses",          // openai-completions | openai-responses | anthropic-messages | google-generative-ai
      "apiKey": "$MY_KEY",                // 字面值、"$ENV_VAR" 或 "!shell 命令"
      "headers": { "X-Custom": "1" },     // 可选
      "reasoning": false,                 // profile 默认 thinking 开关
      "modelRules": [                     // 按模型 id 关键字匹配，第一条命中生效
        { "match": ["claude"], "transform": "claude-responses", "reasoning": true }
      ],
      "models": [
        { "id": "gpt-5", "name": "GPT-5", "reasoning": true, "contextWindow": 400000, "maxTokens": 128000, "input": ["text", "image"] }
      ],
      "defaultModel": "gpt-5"             // 可选，默认第一个模型
    }
  }
}
```

优先级：模型自身字段 > 命中的 modelRule > profile 默认值。模型、规则都可以覆盖传输层字段 `api` / `baseUrl` / `compat` / `thinkingLevelMap`。

`transform: "claude-responses"` 用于只会把 Responses 请求转成 Claude 请求的网关：把 Responses 格式的 tools 改写成 chat 包装形式，并把 `reasoning.effort` 映射为 Anthropic 的 adaptive thinking 字段。

## 图片输入识别

模型是否支持图片输入按以下顺序判定：模型上显式的 `input` > 缓存的探测结果 > pi 内置模型目录。**默认不进行付费图片探测**，无法判定的模型按纯文本处理。只有用户主动在 `provider-profiles.json` 顶层设置 `"imageProbeEnabled": true`，首次选中未知模型时才会发送生成的 16 色块 PNG（一次小额计费请求），成功结果缓存 30 天于 `~/.pi/agent/.cache/provider-inputs/`。细节见 `extensions/provider-switch/README.md`。

## 可选：子代理只读注册

`provider-profiles-subagent.ts` 放在扩展目录**之外**，供 pi-subagents / magic-context 等子进程用 `-e` 显式加载：只注册 provider，不改选中模型、不装命令。使用时把它与 `extensions/` 一起放在同一个目录，或按需修改其中的相对导入路径。

## 要求

- pi coding agent（`@earendil-works/pi-coding-agent`），扩展使用 `pi.registerProvider`、`pi.setModel`、`before_provider_request` 钩子。
- 配置文件里可能含 API key，请勿提交到仓库；建议用 `$ENV_VAR` 或 `!cmd` 形式。

## License

MIT
