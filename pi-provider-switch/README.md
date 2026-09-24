# pi-provider-switch

把 `~/.pi/agent/provider-profiles.json` 里的每个配置注册成 pi 的普通 provider（和手写的中转站扩展一样），**不修改 `models.json`、不替你选模型**。

## 2.0 相对 1.x 的变化

- 加载时就注册全部配置，模型直接出现在 `/model` 和 Pi GUI 模型选择器里。
- 不再有“当前/默认配置”：1.x 每次会话启动都会强制切到默认配置的默认模型，恢复旧会话时会顶掉原来的模型。2.0 完全交给 pi 自己的会话恢复和 `defaultModel` 逻辑。旧文件里的 `active`、`defaultModel` 会被忽略。
- 模型列表从 `GET {baseUrl}/models` 实时获取，缓存到 `~/.pi/agent/.cache/provider-switch/`，后台刷新不再改写配置文件。
- 推理/图片输入/上下文/输出上限/思考档位从 [models.dev](https://models.dev) 自动推断（中转站装饰前缀如 `∞【xx】claude-opus-4-5` 也能匹配），离线启动用磁盘缓存。
- 配置文件改动会被运行中的会话自动发现，不用重启。
- 移除 `/switch`、`/provider-thinking`。

## 安装

```bash
pi install /path/to/pi-provider-switch
```

## 命令

| 命令 | 作用 |
|---|---|
| `/providers` | 列出全部配置 |
| `/provider-refresh [name]` | 立即重新获取模型列表与 models.dev 目录（默认全部） |
| `/provider-add` | 交互式新建配置 |
| `/provider-remove [name]` | 删除配置 |

## 配置格式

```jsonc
{
  "profiles": {
    "my-gateway": {
      "baseUrl": "https://api.example.com/v1",
      "api": "openai-responses",          // openai-completions | openai-responses | anthropic-messages | google-generative-ai
      "apiKey": "$MY_KEY",                // 字面值、"$ENV_VAR" 或 "!shell 命令"；本地服务可省略
      "headers": { "X-Custom": "1" },     // 可选
      "syncModels": true,                 // 默认 true；false = 不请求 /models，只用手动模型
      "reasoning": false,                 // 可选：models.dev 查不到时的思考默认值
      "modelRules": [                     // 按模型 id 关键字匹配，第一条命中生效
        { "match": ["claude"], "transform": "claude-responses", "reasoning": true }
      ],
      "models": [                         // 只放你想固定的设置
        { "id": "gpt-5", "contextWindow": 400000 },   // 覆盖自动推断的字段
        { "id": "internal-alias", "manual": true },   // /models 不返回的手动模型
        { "id": "embedding-x", "disabled": true }     // 在模型选择器中隐藏
      ]
    }
  }
}
```

能力优先级：模型条目 > 命中的 modelRule > 图片探测缓存 / pi 内置目录 > models.dev > 配置 `reasoning` > 默认值。模型和规则都可以覆盖 `api` / `baseUrl` / `compat` / `thinkingLevelMap`。

`transform: "claude-responses"` 用于只把 Responses 请求转成 Claude 请求的网关：改写 tools 为 chat 包装形式，并把 `reasoning.effort` 映射为 Anthropic adaptive thinking。

## 图片输入识别

默认不发送任何付费探测。只有在配置顶层设置 `"imageProbeEnabled": true` 时，选中无法判定的模型才发送一张生成的 16 色块 PNG 验证一次，结果缓存 30 天。详见 `extensions/provider-switch/README.md`。

## 可选：子代理只读注册

`provider-profiles-subagent.ts` 位于扩展目录外，供子进程用 `-e` 显式加载：只按缓存注册 provider，不联网、不写文件、不选模型。

## License

MIT
