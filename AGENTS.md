# 项目规范与 Agent 准则 (AGENTS.md)

```yaml
version: "1.0.0"
project:
  name: "pi-gui"
  type: "desktop-gui"
  frontend: "Flutter"
  backend: "Pi RPC (pi --mode rpc)"
  architecture: "前后端彻底分离 (Decoupled Frontend & Backend)"

rules:
  # 1. 基础架构
  architecture:
    summary: "Flutter 负责纯界面与交互，Pi RPC 负责底层能力与逻辑，彻底解耦"
    roles:
      frontend: "Flutter (桌面 UI、动效、用户交互状态管理)"
      backend: "Pi RPC (pi --mode rpc 启动的子进程，负责模型调度与工具执行)"
    how_to:
      - "Flutter 界面只负责向 Pi RPC 发出命令，并监听事件流刷新界面"
      - "通过标准输入输出 (stdin/stdout) 走 strict JSONL 协议 (单行以 \n 分隔)"
      - "在 Flutter 内部建立强类型 RPC 客户端服务层 (Service/Repository)，将 JSON 解析为强类型 Dart 实体"
    when_to:
      - "凡涉及读取/管理会话、发送 Prompt、监听工具执行 (bash/edit/read 等)、文件变更、切换模型，一律调用 Pi RPC"
    forbidden:
      - "绝不在 Flutter 端重写 Agent 逻辑或直接调用 LLM API"
      - "绝不让 UI Widget 直接操作原始子进程句柄或拼接原始 JSON 字符串"
      - "绝不越权篡改 Pi 后端私有内部文件"

  # 2. UI 组件规范
  ui_components:
    summary: "原子组件优先，高复用，杜绝重复造轮子"
    directory: "lib/components/ 或 lib/ui/atoms/"
    how_to:
      - "先做零件再拼整车：复杂页面前必须先做齐最小原子组件 (通用按钮、输入框、卡片、头像、标签、模态外壳等)"
      - "原子组件必须健全支持所有交互状态 (默认、Hover、Focus、Disabled、Loading 等)"
      - "所有业务页面必须由这些原子组件拼接而成"
    when_to:
      - "接到任何 UI 需求时，第一步必须先检索公共原子组件库，看是否有现成组件或参数可复用"
      - "只有在现有组件库彻底无法覆盖需求且经确认后，才允许新建原子组件并放入公共库"
    forbidden:
      - "绝不在具体页面里随手手写带有私有装饰样式的裸 Container、裸 ElevatedButton 等"
      - "绝不为相同功能反复造私有小组件"
      - "绝不写绑死具体业务数据、无法复用的一次性组件"

  # 3. 样式与文案规范
  styling_and_i18n:
    summary: "零硬编码：文字全量走 i18n，颜色字号全量走主题系统，支持动态取色与毛玻璃"
    how_to:
      - "i18n：所有界面文字必须写入多语言资源 (如 .arb 或 JSON)，通过 context.l10n 获取"
      - "色彩自适应：颜色全部绑定 Theme 语义 Token (primary, surface 等)，支持从系统/壁纸提取自适应调色板与自定义配置"
      - "视觉质感：预留透明度与毛玻璃磨砂效果 (BackdropFilter 材质)"
      - "排版层级：字号统一从全局 TextTheme 获取，禁止写死像素大小"
    when_to:
      - "编写每一行 UI 代码的当下严格执行，绝不留“先写死后补”的技术债"
    forbidden:
      - "绝在代码中出现裸中英文字符串 (如 Text('保存')、Text('Settings'))"
      - "绝在组件里写死色值 (如 Color(0xFF2196F3)、Colors.blue)"
      - "绝在组件里写死字号 (如 TextStyle(fontSize: 14))"

  # 4. 需求实现流程
  workflow:
    summary: "先找参考与确认，禁止闭门造车"
    how_to:
      - "遇到新功能或新布局，先检索成熟优秀的同类产品 (如 VSCode, Claude Code, Codex, Cursor 等)"
      - "需求有不明确、有分歧或多种方向时，停下来直接向人类提问确认，不要自己猜"
      - "方案明确后，列出用到的原子组件与 RPC 接口交互，再动手写代码"
    when_to:
      - "接到任何新模块、重构设计、新交互页面或改变用户操作习惯前"
    forbidden:
      - "绝不凭空脑补奇奇怪怪的操作逻辑和页面结构"
      - "绝在核心交互不明确时闷头盲写难以修改的死代码"

  # 5. 界面文案与提示
  copywriting:
    summary: "大白话、真诚克制，禁止晦涩概念与夸张吹嘘"
    tone: "大白话、清晰自然、直截了当、平实真诚"
    how_to:
      - "用大白话写提示：按钮文案直观明了，状态和说明告诉用户当前发生了什么、下一步点哪里"
      - "报错信息说明人话与解决办法，而非抛出晦涩代码"
      - "允许保留必要的行业标准名词 (如 Git Worktree, Diff, Token, RPC, Model, Session)，但辅助说明必须是大白话"
    when_to:
      - "编写任何界面标题、按钮标签、输入占位符、Tooltip、空状态与错误弹窗时"
    forbidden:
      - "绝在界面里塞普通用户看不懂的生硬学术黑话"
      - "绝使用夸张吹嘘词汇 (如“革命性”、“遥遥领先”、“无与伦比”、“极致颠覆”)"
      - "绝直接把未经转换的底层系统内部异常堆栈糊在用户脸上"

  # 6. 文档与记录规范
  documentation:
    summary: "新功能必写 Docs，人与 Agent 双向友好"
    directory: "docs/ 或各模块内 README.md"
    how_to:
      - "人类视角：大白话讲清功能用途、界面入口、操作步骤与预期效果"
      - "Agent 视角：明确标出关键代码路径 (Widget / Controller / Service)、关联的 Pi RPC 命令与事件 (如 session.prompt, tool_call)，提供清晰的数据结构示例，方便后续 Agent 秒速接手"
      - "统一以 Markdown + YAML Frontmatter 结构化保存于 docs 目录"
    when_to:
      - "任何新功能或重大改动自测完成后，文档与代码必须同步提交"
      - "业务逻辑变更时原文档必须同步更新，杜绝信息滞后"
    forbidden:
      - "绝只写代码不写 docs"
      - "绝写通篇吹嘘的宣传稿"
      - "绝写脱离具体代码路径与数据结构的抽象假文档"
      - "绝遗留过时的死文档"

  # 7. 测试规范
  testing:
    summary: "减少不必要测试，拒绝测试形式主义与虚荣指标"
    strategy: "把精力集中在真正高风险的核心上，坚决砍掉低价值、脆弱且浪费时间的测试"
    how_to:
      - "轻量聚焦核心：仅对关键数据解析编解码 (如 RPC JSONL 强类型映射)、复杂计算、易出错的状态机流转编写少量精简单元测试"
      - "UI 验证走人机肉眼校验：UI 组件以 Flutter 热重载 (Hot Reload) 实时预览、交互走查为主，无需给纯展示型界面写脆弱的测试"
      - "保证测试秒级运行，不给日常开发和构建引入沉重包袱"
    when_to:
      - "仅在编写高复杂度逻辑转换、RPC 协议序列化/反序列化、核心状态转换时才编写测试"
    forbidden:
      - "绝不搞测试刷量：禁止为简单 UI 渲染、纯展示 Widget、纯 getter/setter 编写毫无意义的形式主义测试"
      - "绝不写脆弱易碎的测试：禁止写样式稍作调整就频繁挂掉的低价值测试"
      - "绝不为了盲目追求覆盖率数字而增加庞大维护负担"

  # 8. 扩展槽位规范 (Extensible Slots)
  extensible_slots:
    summary: "对齐 Pi 官方 extension_ui 机制，在 GUI 核心布局中预留标准动态扩展槽位"
    slots:
      above_editor: "输入框上方插槽 (对应 setWidget: aboveEditor，用于任务进度、待办卡片等)"
      below_editor: "输入框下方插槽 (对应 setWidget: belowEditor，用于快捷建议、辅助提示)"
      status_bar: "底部状态栏动态徽章区 (对应 setStatus: statusKey，用于分支、Token、插件状态)"
      dialog_overlay: "全局阻断交互模态槽 (对接 select, confirm, input, editor 等 RPC 弹窗)"
      notification_toast: "全局通知浮层 (对接 notify: info/warning/error)"
      tool_card_registry: "时间线工具卡片注册表 (支持自定义工具渲染器，开放第三方扩展)"
      sidebar_panel: "侧边抽屉扩展槽 (支持挂载 Diff 查看器、文件树、插件管理面板)"
    how_to:
      - "布局中预留 SlotContainer：在输入框上下、状态栏、全局遮罩层放置标准的槽位容器"
      - "由 RPC 事件驱动分发：监听 Pi RPC 输出的 extension_ui_request，自动路由至对应槽位刷新"
      - "工具卡片解耦：通过 Map 注册表管理 ToolCardBuilder，第三方工具即插即用"
    when_to:
      - "设计并实现主界面骨架、输入框区域、底部状态栏、全局弹窗系统和时间线消息渲染器时严格执行"
    forbidden:
      - "绝在主页面布局中把结构写死而不预留动态挂载槽位"
      - "绝把扩展逻辑与主界面核心视图硬编码揉杂在一起"
      - "绝忽略或吞掉 Pi RPC 派发上来的 extension_ui_request 事件"
```
