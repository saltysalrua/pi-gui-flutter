---
title: "外观设置：动态配色、分区毛玻璃与缩放"
version: "1.5.0"
status: "implemented"
type: "feature-and-architecture"
tags: [flutter, settings, material3, windows, theme]
---

# 外观设置

## 使用方法

点击主界面左下角 **设置**，进入 **外观**。布局参考 Codex 设置界面：左侧返回、搜索与分类，右侧分组设置。当前只列出已经实现的外观分类。

- **显示模式**：跟随系统、浅色、深色。
- **配色来源**：默认配色、Windows 强调色、自选种子色。首次启动仍使用原有默认配色。
- **基准字号**：12–18，默认 13。只改变文字，标题、正文和代码字号一起按比例变化。
- **UI 比例**：80%、90%、100%、110%、125%、150%，默认 100%。整体缩放文字、按钮、图标、间距和浮层，不更改 Windows 的显示缩放。
- **桌面毛玻璃**：顶部与侧边栏、主界面、卡片分别开关和调节底色不透明度，默认关闭。
- **分区颜色**：强调色、主背景、顶部与侧边栏、输入框、卡片、代码区、用户消息。
- **工具显示**：agent 工具卡片默认密度，收起 / 简略 / 展开三挡，默认简略。
- **扩展显示位置**：输入框上方、输入框下方、状态栏徽章、侧边栏面板、通知浮层各自开关；扩展弹窗提问始终显示。
- **高级颜色**：浮层与菜单、三层文字、边框、成功 / Diff 新增、警告、错误 / Diff 删除。默认折叠；搜索匹配其中的项目时自动展开。

点击色块打开取色器，可拖动颜色面板、调整 HSV 滑块，或输入 `#RRGGBB`。点击“应用颜色”才提交，取消或 Esc 不修改原值。取色器不支持 Alpha 通道或屏幕吸管；分区毛玻璃的不透明度在单独的设置组调整。文字与背景对比度过低时提示，但允许保留用户选择。

所有设置立即生效并自动保存在本机。每个颜色右侧的重置按钮恢复自动生成值；“重置此模式的颜色”只清除当前明暗模式的覆盖；“恢复默认外观”需确认，会重置两套覆盖、来源、模式、字号、比例，并关闭两区及卡片毛玻璃、恢复其默认不透明度。

### 顶部与侧边栏的统一底色

顶部标题栏、首页左右侧栏与拖拽调宽区共用 `sidebarBackground`，不再显示顶部底边框和侧栏右侧的常驻分隔线。外观里的“顶部与侧边栏”会同时改变标题栏及左右侧栏，不增加颜色键或迁移已有偏好。

首页与设置页的右侧主内容区均使用 `canvasBackground`，仅左上角采用 `AppRadius.xl`（16 逻辑像素）圆角；其余三个角保持直角，没有额外描边或阴影。两页内容区都紧贴标题栏下沿、窗口右边与底边；设置页不再使用四角圆角矩形，也不再保留右侧 / 底部的 8px 外边距。圆角外露出统一底色，子内容也会裁切，滚动不会盖住圆角。设置页与首页的侧栏共享宽度，主内容左边缘也保持一致；设置页窄窗口响应式布局不变，首页空会话输入居中、有消息后输入到底部的两态逻辑不变。

- `HomeView` 与 `AppearanceSettingsView` 共用 `AppDesktopScaffold`，由同一背景画布分别绘制顶部/侧栏区域与主内容区域。主内容仍由内部透明 `AppCard` 用单角圆角、无描边、`Clip.antiAlias` 裁切；其他卡片默认行为不变。
- 公共外壳内的 `CustomTitleBar`、`HomeSidebar` 和分隔条使用透明背景，由外壳统一提供底色；不能再盖一层纯色或重复叠加半透明颜色。独立使用这些组件时原默认背景不变。窗口拖拽、双击最大化及控制按钮不变。
- `AppResizeDivider(showIdleIndicator: false)` 隐藏静止时的线和手柄；悬停或拖动时淡入手柄，10px 命中区、左右拖拽和双击复位保留。外壳中的左右半侧透出统一侧栏底色，避免圆角旁出现实色竖条。文件 / Git 右栏的分隔条同样隐藏静止指示线，并使用透明底色。
- 动效沿用 `AppDurations.quick` / `AppCurves.smoothOut`，减弱动态时立即切换。没有新增 RPC 命令或事件。

### 设置页进出动效

打开设置时，侧栏控件与右侧内容从右侧 **8 逻辑像素** 滑回原位；返回时反向轻移。顶部标题栏、拖拽分隔条及两区背景不参与位移，整页不再淡入淡出。颜色与毛玻璃不透明度仍由用户设置决定，不会为了切页临时变浅、变深或变成纯色。

- 参考 [Windows 页面切换](https://learn.microsoft.com/en-us/windows/apps/develop/motion/page-transitions) 的内容位移方式，但不采用整页透明度动画。打开使用 `AppDurations.fast`（250ms），返回使用 `AppDurations.quick`（150ms），曲线为 `AppCurves.smoothOut`，距离复用 `AppSpacing.sm`。开启“减弱动态”时直接切换。
- `showSettings` 使用公共 `AppDesktopPageRoute<void>`。通过 Flutter 的 `delegatedTransition` 在**整个过渡期间**让前一页 Offstage，抑制默认的退出淡化 / 缩放；首页仍保持挂载，RPC、聊天、输入草稿和会话不因切页重建。
- 仅删除 `FadeTransition` 不够：普通 opaque 路由在入场完成前仍会绘制前一页，两个半透明外壳会叠色。新路由在返回的最后一帧也停止绘制自身，确保首页恢复绘制时不会再叠一层设置背景。不要改回整页 Fade / Slide，也不要用不透明遮罩来掩盖问题。
- `AppDesktopScaffold.contentAnimation` 只变换子内容，侧栏和正文分别裁切到各自区域。该参数默认空，不给首页插入新的动画包装，不改变现有首页布局或子树路径。设置页弹出的菜单、取色器和确认框仍保留下面的设置页面，沿用自身公共动效。
- 设置分组 `AppSettingsGroup` 在减弱动态时直接显示内容，与 `AppDisclosure` 一致；不再运行零时长 `AnimatedSize`，避免 Flutter beta 在布局过程中同步重新标脏的断言。

### 分区桌面毛玻璃

在 **设置 → 外观 → 桌面毛玻璃** 中操作，也可搜索“毛玻璃”：

1. 开启“顶部与侧边栏毛玻璃”或“主界面毛玻璃”。两区各自生效，不要求一起开启。
2. 开启后出现对应的“底色不透明度”滑块，范围 20%–100%，每步 5%。默认侧栏 65%、主界面 85%；越低越能透出背景，100% 显示纯色。看不清文字时调高一些。
3. 关闭某一区域只恢复该区纯色，保留它的滑块数值；重新开启继续使用原值。标题栏和文件 / Git 右栏始终跟随侧边栏，聊天和设置页的主背景使用同一项主界面设置。
4. 不透明度以外的底色仍在“分区颜色”修改。两区的开关和不透明度在明暗模式间共用，颜色覆盖仍按明暗模式分别保存。

这是 **Windows 原生桌面 Acrylic**，模糊窗口背后的桌面或其他窗口，不是给文字加模糊，也不是应用内的渐变仿制。Windows 控制模糊半径，本设置只独立控制每区的底色覆盖程度；不提供无法兑现的分区原生模糊半径。文字和按钮不会随背景一起降低透明度。输入卡片、其他卡片、带框代码块与 Diff 的底色由下方的“卡片毛玻璃”独立控制，主界面开关不会替用户开启卡片效果。

**需要 Windows 11 22H2 或更新版本，并重新构建、启动新版本。** 仅热重载不能注册新增的原生通道。旧 Windows、非 Windows、旧 Runner 缺少通道、调用失败时保留纯色并显示原因；不会把窗口降级成未经模糊的全透明窗口。关闭 Windows“透明效果”、启用对比度主题或节电模式时也会回退纯色，不改写保存的选项。系统设置/主题/强调色/DWM 合成/电源广播及窗口激活会触发回读，系统本身也可能在窗口失焦时调整材质。未修改用户的 Windows 设置。

背景按两个互不覆盖的路径分别绘制，主内容圆角外的部分属于侧栏区，避免在主背景下面铺满侧栏颜色而造成透明度串联。原有空会话居中输入、发送后底部输入、共享侧栏宽度、设置路由与 Pi 会话生命周期均不改变。

开关和底色变化复用 `AppDurations.fast` / `AppCurves.smoothOut`；减弱动态时立即切换。原生能力不可用时立即回退不透明背景，优先保证可读性。滑块复用 `AppSteppedSlider(showTicks: false)`，模型思考档位的默认刻度显示不变。

### 文件 / Git 右栏

新的右栏沿用侧边栏颜色和 `sidebarGlass`。首页的主区 / 右栏由 `AppSplitPanel` 以互不重叠的矩形单次绘制，外层 `AppDesktopScaffold` 在首页的主内容路径上保持透明；标题栏 / 左栏以及设置页原来的双区域绘制不变。右栏本身和拖拽条不再铺实色，窄窗覆盖时还会裁掉后方聊天内容，避免主区 tint、输入框和右栏重复合成。

不增加外观存储键、原生通道或全窗口透明度。30% 的独立预览图层取样中，右栏、主区和标题栏均为 76 / 255 alpha；开启左侧遮罩也不改变右栏 alpha。详细布局、响应式行为与代码路径见 [右侧工作区浏览](workspace_browser.md)。

### 卡片毛玻璃

在 **设置 → 外观 → 桌面毛玻璃 → 卡片毛玻璃** 选择“开启”，也可搜索“卡片毛玻璃”：

- 开启后出现“卡片毛玻璃底色不透明度”，默认 **75%**，范围 **20%–100%**，每步 5%。数值越低越透，100% 恢复纯色且不执行模糊；关闭保留滑块值，重新开启继续使用。
- 输入卡片、设置分组、模型浮层、弹窗、通知，以及其他使用 `AppCard` 的有底色卡片一起跟随，包括用户消息和带框代码 / Diff；首页 / 工作台 / 设置侧栏的搜索条以及其他非无边框 `AppTextField` 输入框也使用同一材质，透出侧栏或主背景。原有背景颜色、圆角、描边、阴影、尺寸和布局不变；正文、代码、图片和操作控件不被模糊或整体淡化。
- 成功 read 等 `framed: false` 的透明工具行没有新增背景或边框。桌面外壳内部全透明的 `AppCard` 也不参与，不会把主内容区变成第三层半透明底色。
- 卡片使用 **应用内背景模糊**，不直接采集桌面。主界面不透明时，卡片透出的是应用背景；纯色上的模糊本来就不明显。要看到桌面透色，需要同时开启主界面毛玻璃。卡片底色叠在主背景之上，最终透出程度同时取决于这两项，不会自动降低主背景的不透明度。
- 明暗模式共用开关与不透明度，仍各自使用对应的语义背景色。旧偏好文件默认不开启卡片效果，“恢复默认外观”会同时关闭它并恢复 75%。

实现复用 `AppCard`，没有新增业务专用卡片或 Pi RPC：

1. `AppearancePreferences.cardGlass` 沿用 `GlassPreferences` 的校验、序列化与保存流程。`wantsGlass` 包含卡片开关，让只开启卡片时也经过现有原生能力和系统透明策略检查；不会代开侧栏或主背景。
2. `AppTheme.build` 将目标不透明度和 `AppGlass.cardBlurSigma`（16 逻辑像素 sigma）注入 `AppCardTheme`。原子组件只读主题与 `WindowMaterialScope`，不依赖设置 Controller。材质插值使用原有全局主题过渡 `AppDurations.fast` / `AppCurves.smoothOut`，减弱动态时立即切换。
3. `AppCard` 只对圆角范围内的背景执行 `BackdropFilter`，内容继续走原有 Container 的布局、内边距与裁切。使用 `BlendMode.src` 替换滤后的背景，避免将已经半透明的主背景重复合成；阴影在外层保留。开关变化不重建子树路径，不丢编辑器、焦点或滚动状态。
4. 嵌套卡片通过公开的 `AppCardBackdropScope` 复用祖先模糊，只绘制自身底色，避免反复采样同一背景；`AppTextField` 同样读取它，位于已模糊卡片内的输入框不再叠加第二层模糊。无材质、100% 或回退状态下 `BackdropFilter.enabled` 为 false；完全透明的背景和 `glass: false` 显式退出材质，但保留原本的透明语义。
5. `AppTextField`（非 `borderless`）沿用与 `AppCard` 相同的 `AppCardTheme` + `WindowMaterialScope` 规则：开启时底色乘以不透明度、圆角范围内背后铺 `BackdropFilter(BlendMode.src)`，无边框 / 禁用 / 高对比度 / 原生不可用时回退纯色。树结构在开关变化时保持恒定，不重建 TextField 元素路径，不丢焦点和编辑状态；`onPaste` 动作仍包在最外层。
6. 只有原生状态为 `active` 且没有高对比度时才启用卡片效果。系统关闭透明、节电、缺失通道或平台不支持时立即恢复原本实色，保存的选项不变。没有修改原生 C++，已具备毛玻璃通道的 GUI 可热重载使用；旧 Runner 仍需下次启动新版本。

### 两页共用可拖拽侧栏

鼠标放到侧栏右边缘时显示手柄，左右拖动即可调宽，双击恢复默认 260 逻辑像素。首页调宽后打开设置、设置调宽后返回首页，侧栏与主内容左边缘都不会换成另一套宽度；两页使用同一个 10px 拖拽区，不再让设置页固定为 230px。

- 共享状态位于 `lib/ui/core/sidebar_layout_controller.dart` 的 `SidebarLayoutController.instance`，由应用进程持有，两页通过 `ListenableBuilder` 订阅。页面不各存一份宽度，也不相互调用 `setState`。
- 默认 260px，最小 180px，最大为 480px 与当前逻辑视口宽度一半中的较小值（沿用首页限制）。`widthFor(viewportWidth)` 统一计算显示宽度，`resizeBy(delta, viewportWidth: ...)` 从实际显示边缘开始拖动，避免窗口变窄后反向拖动出现空行程；`reset()` 恢复默认。
- 窗口缩小只临时限制显示宽度，未继续拖动时放大可恢复之前的宽度。UI 比例变化仍使用缩放后的逻辑视口计算，两页上限一致。
- 设置页逻辑视口不足 760px 时继续隐藏侧栏及拖拽区，将返回和搜索移到顶部；不重置共享宽度，恢复宽窗口后继续使用原值。
- 宽度仅保存在本次 GUI 运行期间，重新启动恢复默认；不写入 `appearance.json`，不触发配色保存或 Pi RPC，也不改聊天会话。

### Windows 动态配色的含义

使用 `dynamic_color` 的桌面 `getAccentColor()` 读取 Windows 强调色，再通过 Flutter `ColorScheme.fromSeed` 生成 Material 3 明暗调色板。这不是直接抓取壁纸，也不保证生成后的主色与 Windows 原始强调色完全相同——Material 会调整明度、彩度和对比度。

Windows 设置中开启“从背景自动选取强调色”后，应用可间接随壁纸变化。启动、窗口重新获得焦点、系统明暗变化、点击“重新读取”时刷新。不轮询、不修改系统设置，也不承诺在应用始终持有焦点时实时捕获其他程序对强调色的更改。

读取失败时使用默认种子色，并在设置页明确提示；自定义覆盖不会丢失。新增原生插件后需要重新构建并启动应用，仅热重载不能把插件装入旧进程。

### 工具显示与扩展显示位置

**工具显示**在 **设置 → 外观 → 工具显示** 选择挡位（可搜索“工具”）：

- **收起**：只保留一行工具标题（工具名＋路径/命令/行号），最省空间；点击仍可展开看详情。
- **简略**（默认）：一直是本项目的默认样式——成功 read 一行、普通输出预览 6 行、失败 3 行、文件改动 Diff 预览 8 行，截短时显示“展开”提示。
- **展开**：直接平铺完整命令、输出、Diff 和图片，不再需要逐个点开；最直观但占空间。

实现位于 `lib/ui/features/home/widgets/tool_card_registry.dart`：默认渲染器通过 `AppearanceScope.maybeOf(context).preferences.toolDisplay` 读挡位，随偏好全局响应式刷新。挡位名参与每张卡片的 `PageStorageKey`，切换挡位会重置单张卡片的局部展开记忆，避免“收起”下残留旧展开状态。自定义工具渲染器（`ToolCardRegistry.register`）不受影响，不接入挡位逻辑。

**扩展显示位置**在 **设置 → 外观 → 扩展显示位置**（可搜索“扩展”）：输入框上方、输入框下方、状态栏徽章、侧边栏扩展面板、通知浮层各自开关，关闭后该槽位不渲染任何扩展内容。扩展的弹窗提问（select / confirm / input / editor）是必答交互，始终显示、不做开关。关闭只隐藏界面展示，不拒绝或丢弃 Pi 的 `extension_ui_request` 事件；重新开启后插槽内容立即恢复。实现：`lib/ui/atoms/slot_container.dart` 在 build 时按 `preferences.isSlotVisible(slotId.name)` 拦截，见 [扩展槽位](extension_ui_slots.md)。

### 明暗模式、字号和缩放的关系

- 浅色、深色的颜色覆盖分别保存。想改另一套，先切换显示模式；“跟随系统”编辑当前实际显示的那套。
- 切换配色来源保留覆盖；因此手动覆盖的分区不再跟随种子色变化，点该项重置可恢复自动。
- 基准字号以 `TextTheme.bodyMedium` 的 13 为基准；聊天正文 `bodyLarge` 默认 14，按相同比例变化，不是所有文字都变成同一个字号。
- 系统文字缩放仍然有效。最终视觉大小由主题字号、系统文字缩放、应用 UI 比例和 Windows 显示缩放共同决定。
- 小窗口或高比例下，设置页收起侧栏，把返回和搜索移到顶部；设置行空间不够时上下排列，可滚动访问其余设置。

## 代码结构与边界

**无 Pi RPC 命令或事件。** 外观是 GUI 本地偏好，不读取、编辑 Pi 私有配置或会话。原有全局 `dialogOverlay` / `notificationToast` 插槽仍位于普通路由上方，并一同缩放。

| 路径 | 职责 |
| --- | --- |
| `lib/core/models/appearance_preferences.dart` | 版本化数据、枚举、HEX 校验、数值边界、明暗独立覆盖 |
| `lib/core/services/window_material_service.dart` | GUI 原生 MethodChannel；强类型材质状态、事件和旧 Runner 容错 |
| `lib/ui/core/window_material_controller.dart` | 原生请求串行、合并最新开关/明暗状态、防止迟到响应覆盖系统回退 |
| `lib/ui/core/window_material_scope.dart` | Navigator 上方的唯一材质驱动；仅原生确认 active 后允许透明，保留高对比度保护 |
| `lib/ui/atoms/app_desktop_scaffold.dart` | 共用桌面外壳、两区背景路径、单角圆角、透明标题栏/侧栏与拖拽条；可选的仅内容位移 |
| `lib/ui/core/app_desktop_page_route.dart` | 设置页的无淡化路由、过渡期间遮停前页绘制并保留其状态 |
| `lib/ui/atoms/app_split_panel.dart` | 首页主区 / 文件与 Git 右栏的独立 tint、透明拖拽条与窄窗覆盖裁切 |
| `lib/ui/atoms/app_card.dart` | 有底色卡片的统一背景模糊、圆角范围、嵌套复用和无状态丢失的开关 |
| `lib/ui/core/theme/app_card_theme.dart` | 卡片目标不透明度与模糊 sigma 的主题插值；不改变语义颜色 |
| `windows/runner/window_material.h/.cpp` | DWM Acrylic、系统透明/高对比度/节电检查，原生状态回传 |
| `windows/runner/flutter_window.cpp` | 原生生命周期/消息路由；补全隐藏标题栏的 NC 激活默认处理，避免 DWM 卡在未激活灰底 |
| `lib/core/services/appearance_store.dart` | GUI 自有 JSON 文件读写，临时文件 flush 后 rename 替换 |
| `lib/ui/features/settings/controllers/appearance_controller.dart` | 即时状态、顺序保存/合并等待中的写入、失败重试、系统强调色观察 |
| `lib/ui/features/settings/views/settings_view.dart` | 设置路由、侧栏页签（外观 / pi）、搜索、窄窗口页选择器与内容淡切 |
| `lib/ui/features/settings/views/appearance_settings_view.dart` | 外观页内容：分组设置、取色/恢复确认及预览 |
| `lib/ui/features/settings/views/pi_settings_view.dart` | pi 页内容：更新检查卡片与分页更新日志 |
| `lib/ui/features/settings/appearance_labels.dart` | 颜色枚举到 i18n 文案的映射 |
| `lib/ui/core/sidebar_layout_controller.dart` | 首页 / 设置共用的侧栏宽度、视口限制、拖拽和复位；纯内存状态 |
| `lib/ui/core/theme/appearance_palette.dart` | 默认 / M3 色板到语义 Token 的映射，再叠加覆盖；对比度与前景色选择 |
| `lib/ui/core/theme/app_theme.dart` | 构建明暗 `ThemeData`，统一缩放 TextTheme，配置选择高亮与 Tooltip |
| `lib/ui/core/theme/app_colors_extension.dart` | 含输入框、代码区、用户消息和中性滑块手柄的语义色 |
| `lib/ui/atoms/app_setting.dart` | 可复用分组卡片、响应式标签/控件行 |
| `lib/ui/atoms/app_select.dart` | 复用操作按钮的带文字选择框，键盘与菜单动效 |
| `lib/ui/atoms/app_color_picker.dart` | 色块、颜色按钮与局部草稿式 HEX/HSV 取色弹窗 |
| `lib/ui/atoms/app_scale.dart` | 整个逻辑视口与 Overlay 的布局/绘制/命中缩放 |
| `lib/main.dart` | 启动先读偏好，AppearanceScope + ListenableBuilder 绑定主题 |
| `lib/ui/features/home/views/home_view.dart` | 设置入口；正常关闭窗口等待偏好保存完毕 |

复用 `AppCard`、`AppActionButton`、`AppIconButton`、`AppNavTile`、`AppTextField`、`AppSteppedSlider`、`AppDisclosure`、`AppDialog`、`AppCodeBlock`；不在页面里另写私有装饰控件。文案位于 `lib/l10n/app_zh.arb` / `app_en.arb`。

折叠栏的标题与说明统一左对齐，说明长度变化不会推移标题。`AppActionButton` 的双行文字跟随 `mainAxisAlignment` 对齐；新增 `expandLabel`（默认 `false`）允许文字区占满剩余宽度。`AppDisclosure` 仅在 `framed: true` 时启用它，让箭头靠边框右侧；透明工具行保留紧凑的文字 / 状态间距，模型选择器保留原有居中布局。

### 原生材质通道（不是 Pi RPC）

`WindowMaterialHost` 在 `MaterialApp.builder` 中包住 Navigator 与扩展 Overlay，仍位于 `AppScale` 内。它持有一个 `WindowMaterialController` / `WindowMaterialService`，不因打开设置或修改不透明度重建。后台只接收“两区或卡片任一开启”和实际明暗模式，不接收卡片或两个区域的布局坐标、不透明度或应用内模糊半径。

通道 `pi_gui/window_material`：

```json
{"method": "setAcrylic", "arguments": {"enabled": true, "dark": false}}
```

返回字符串 `active` / `disabled` / `unsupported` / `systemDisabled` / `unavailable`；系统策略变化通过 `statusChanged` 方法回传同样的字符串。缺失或未知响应一律视为不可用。原生同步使用 `DwmSetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE, DWMSBT_TRANSIENTWINDOW)` 和 `DwmExtendFrameIntoClientArea`；关闭时显式恢复 `DWMSBT_NONE`。只清除 `window_manager` 留下的旧 accent gradient，避免与系统 backdrop 冲突，不安装额外插件。

原生请求串行执行，中间的过时配置可合并；迟到响应不能把刚关闭的透明背景重新开启。系统策略事件若与请求并发，确认回读后才接受结果。拖动不透明度只更新 Flutter 的分区底色和本地偏好，不重复设置 DWM，不经过 Pi。

### 启动后第一次开玻璃自动补一轮“关 → 开”

现象：重启应用后毛玻璃不生效，到设置里手动关一次再开一次就恢复。原因是 **DWM 对已经等于目标值的 backdrop 属性不会再重绘**：启动时窗口先由 `window_manager` 提前 `show()`，玻璃的首次 `setAcrylic` 紧跟着第一次帧应用，此时 DWM 可能已把 backdrop 置为“已设置但未绘制”的状态；后续任何同值重设（包括窗口激活时的重应用）都不会触发重绘，只有先设回 `DWMSBT_NONE` / 空 margins 再重新启用才会重画——这正是手动开关有效的原理。且启动时唯一的 `WM_ACTIVATE` 发生在 `AppearanceController.initialize()` 之前的提前 `show()` 阶段，`enabled_` 尚未置位，激活路径不会补救。

修复在 `WindowMaterialController._drain()`（纯 Dart，`lib/ui/core/window_material_controller.dart`）：当本次应用是**从关到开的首次启用**、返回 `active`、没有系统策略事件并发（`_refreshAfterApply` 未置位）、且期望值未被更新覆盖时，自动再执行一次 `apply(false)` + `apply(true)`，即把用户验证过的手动恢复路径自动化。仅明暗切换（同开不变）不触发循环；事件并发或过时配置按原有合并逻辑重排；关闭→重新开启同样补一轮。回归见 `test/window_material_test.dart`。原生 Runner 无需改动，不需要重建 C++ 部分。

### 隐藏标题栏不能丢掉 Windows 激活状态

`window_manager 0.5.2` 的 `windows/window_manager_plugin.cpp` 在隐藏标题栏时，会为 `WM_NCACTIVATE` 发出 Dart focus/blur 事件后直接返回 `1`。这会跳过 `DefWindowProc` 对 Windows 自身“活动标题栏”状态的更新。结果可能是：应用已在前台、Flutter 背景 alpha 正常、材质通道返回 `active`、DWM 类型也是 `3`，但 `GetWindowInfo().dwWindowStatus & WS_ACTIVECAPTION` 仍为 0，Acrylic 一直显示未激活状态的灰色回退层。

修复在 `FlutterWindow::MessageHandler` 的插件已处理分支：若消息为 `WM_NCACTIVATE` 且插件返回 `TRUE`，额外调用 `DefWindowProc(hwnd, message, wparam, -1)`，之后仍保留插件原有返回值和材质事件处理。`lParam = -1` 只阻止原生非客户区重绘，不阻止激活状态更新，因而不会重新画出系统标题栏；不吞掉 focus/blur 事件，也不把窗口永久置顶或永久伪装为激活状态。此处理不应仅限于毛玻璃开启时，否则在开启前就可能留下错误状态。

`active` 和 DWM 类型 3 **只说明原生配置已成功设置，不是最终像素的证明**。遇到“只有灰色、没有背景颜色”时，先在未最小化且确实位于前台的窗口上核对 NC 激活状态，再用受控背景对照。不要仅凭 API 返回值归咎于不透明度或 Windows 全局设置，也不要只凭任务栏正常就认定所有窗口的状态都正常。失焦时 Windows 正常切换成不透明回退层不属于这个缺陷；切回前台后应恢复背景材质。

### 最大化时消除 DWM 原生幽灵按钮

现象：仅当“顶部与侧边栏”毛玻璃开启且窗口**最大化**时，右上角会在自绘三键旁多出一组灰色按钮，悬停关闭键会变红，属于 Windows 原生 DWM 窗口按钮透到了标题栏后面。玻璃关闭时它们被不透明像素遮住，所以看不见。

根因（本机实测）：Windows 11 只要窗口处于最大化且带有 `WS_CAPTION`，就会把原生 min/max/close 按钮合成到窗口帧图层，位置与自定义标题栏重叠；`WM_NCCALCSIZE` 怎么改客户区都拦不住。毛玻璃 60% 透明度让它们以 40% 亮度透出来（像素级对比可见大而淡的矩形字形）。另外，最大化**动画期间** DWM 会用剥除前的样式快照合成幽灵层，这个层能活过剥除样式本身的帧重算，只有动画结束后的一次样式变化才会让 DWM 重新评估并丢弃它。

修复在 `windows/runner/win32_window.cpp` 的 `Win32Window`：

- `UpdateMaximizedCaptionStyle()`（`WM_SIZE` 调用，以 `IsZoomed` 为准）：最大化时从窗口样式中**仅剥除 `WS_CAPTION`**，还原时加回。保留 `WS_SYSMENU`、`WS_MINIMIZEBOX`、`WS_MAXIMIZEBOX`、`WS_THICKFRAME`，因此 Alt+Space、Win+方向键吸附、Win+Up/Down、拖拽缩放全部不受影响；窗口态的阴影/圆角也不变。
- 动画后补帧：最大化后用定时器（首拍 500ms、后续 400ms、共 6 拍）**翻转 `WS_MINIMIZEBOX`** 若干次，每拍带 `SWP_FRAMECHANGED`。`WS_CAPTION` 缺席时任何样式重评估都得出“无按钮”，因此翻转在两个方向上都不产生任何可见变化，却能把动画期间合成的幽灵层悄悄丢掉。`StopCaptionRefresh()` 保证被打断时不会把 MINBOX 留在翻转态。

**不要**用“加回 WS_CAPTION 再剥除”的方式补帧：加回的瞬间 DWM 会画出完整的原生标题栏（用户可见的闪烁，玻璃还会被实心栏盖住），本机已实测确认此方案不可接受。

实测验证：最大化后客户区几何不变、Flutter 视口铺满工作区、样式如预期剥除/恢复；幽灵字形在像素级差分中从 ~136px 降到基线（与窗口态一致）；最小化→还原始终干净。脚本验证时注意：同屏若有另一个旧构建实例（仍带幽灵），屏幕截屏会被污染，需以前台窗口身份断言后再取样。

### 不让系统强调色覆盖自定义标题栏

Windows 的“在标题栏和窗口边框上显示强调色”与应用里的“配色来源”是两个独立设置。原生窗口恢复正常激活后，DWM 默认配色可能在透明的自定义标题栏上画出实色色带；本机确认是 8px 标题栏色带加 1px 系统强调色边框。

`windows/runner/window_material.cpp` 的 `ConfigureCustomChrome` 对本窗口设置 `DWMWA_CAPTION_COLOR` / `DWMWA_BORDER_COLOR` 为 `DWMWA_COLOR_NONE`（API 哨兵值 `0xFFFFFFFE`，不是硬编码的 UI 颜色）。在原生对象创建、材质应用及相关系统消息时维护，毛玻璃关闭时也保留此策略；不改 Windows 全局设置或应用配色来源。旧 Windows 不支持这些外观属性时不阻断启动。

不改 `WM_NCCALCSIZE`、客户区尺寸或窗口样式，也不覆盖刚补全的 `WM_NCACTIVATE` 处理，因此保留拖拽缩放、系统圆角与阴影。独立新构建验证了浅/深色、毛玻璃开/关、重新激活、主题/强调色消息和最大化还原：原色带行与标题栏正文空白处的 RGB 差为 0；开启毛玻璃时，边缘能分别透出受控红/蓝背景，不再绘制系统强调色实线。左右/底部/顶部的原生缩放命中分别保持 `HTLEFT` / `HTRIGHT` / `HTBOTTOM` / `HTTOP`。测试没有修改用户的配色或 Windows 设置，也未重启活动 GUI / Pi。

### 生命周期与缩放注意事项

设置通过 `AppDesktopPageRoute`（继承 `PageRouteBuilder`）正常 push，保留下面的 `HomeView`，仅在过渡期间额外停止前页绘制；不能通过替换首页或新建 RPC 客户端打开设置。修改主题时保持 `MaterialApp` / Navigator 的 Element 身份，不能给它们加上随主题改变的 Key。

`AppScale` 把内容布局在 `窗口逻辑尺寸 / 比例` 的视口内，由 `FittedBox` 同时变换绘制与命中测试。内部 `MediaQuery` 同步调整 size、DPR、insets，但保留系统 TextScaler。Navigator、应用扩展 Overlay 都在同一个变换下，不能只 Transform 页面而让菜单留在未缩放的 Overlay 中。

输入框居中/底部的两态布局仍由原有 `AppComposerLayout` 管理。成功 read 等透明工具行继续透明；代码背景覆盖只影响有背景的代码块和行内代码，不给工具调用重新加框。

主题过渡和缩放使用 `AppDurations` / `AppCurves`。`disableAnimations` 时降级为即时切换；选择框、弹窗、折叠区沿用公共动效。滑块手柄使用独立 `controlThumb`，不能复用 M3 深色主题可能为深色的 `onPrimary`。

### 持久化

文件位于 `path_provider.getApplicationSupportDirectory()/appearance.json`，不是工作区，也不是 Pi 配置目录。Windows 的具体上级目录由应用的 company/product 元数据决定，不硬编码用户名。文件无凭据、会话或工作区数据。

```json
{
  "version": 1,
  "mode": "system",
  "source": "system",
  "seed": "#0075DE",
  "baseFontSize": 14.0,
  "uiScale": 1.1,
  "toolDisplay": "compact",
  "slotVisibility": {"aboveEditor": false},
  "sidebarGlass": {"enabled": true, "opacity": 0.65},
  "canvasGlass": {"enabled": false, "opacity": 0.85},
  "cardGlass": {"enabled": true, "opacity": 0.75},
  "lightColors": {
    "composer": "#F1F7F5"
  },
  "darkColors": {
    "sidebar": "#151B19"
  }
}
```

- 未知枚举回退默认值，非法颜色忽略，字号与比例限制在支持范围；未知文件版本或损坏文件报告加载失败，暂用默认值。
- 只有用户修改后才写入新的偏好，不因加载失败立即覆盖原文件。
- 正在执行的写入先完成，后续等待中的旧快照可以合并，最终最新设置胜出。
- 保存失败保留已经生效的内存值，显示人话提示与重试入口；不能悄悄声称已持久化。
- 自定义颜色仍以不透明六位 HEX 存储。`sidebarGlass` / `canvasGlass` / `cardGlass` 只保存各区底色不透明度，不调用全窗口 `setOpacity`。旧 version 1 文件缺少相应字段时该项默认关闭；非法开关回退默认、有限数值限制到 0.2–1.0、非有限数值恢复该项默认值。
- `cardGlass` 使用可空私有字段与默认值 getter，使热重载前已存在的长期偏好对象能安全读取新增字段，不要求重启承载 Pi 的 GUI。
- `toolDisplay` 存 `collapsed` / `compact` / `expanded`，缺省 `compact`；`slotVisibility` 只保存被关闭的槽位键（`ExtensibleSlotId.name`），缺省一律开启，未知枚举回退默认。

## 设置页动效验证

- 使用安全热重载装载临时独立 QA 弹窗与嵌套 Navigator，前页是带生命周期计数的公共外壳，后页是正式 `AppearanceSettingsView`。偏好仅存内存，没有创建 Pi、改写用户偏好或覆盖活动聊天。
- 对入场 / 返回的首段、中段、末段及完成态逐帧取样，共 69 个状态，包含浅 / 深色 30% 毛玻璃、高饱和紫色侧栏与绿色主背景、100% 纯色、减弱动态、650px 窄视口 + 150% 文字。相同背景区域的 RGBA 在进出前后及中途保持一致，30% 的 alpha 为 76/255、纯色为 255/255，没有过渡叠色。采样只读取 QA 自身 `RenderRepaintBoundary`，不用于宣称 Windows 最终桌面合成像素。
- 设置页上方再打开 / 关闭透明测试弹窗，设置背景仍可见。六轮返回后前页仍只有一次挂载、零次销毁；减弱动态的 `AnimatedSize` 问题修复后重复走查无运行时错误。截图确认浅 / 深色与窄窗口内容、圆角和固定标题栏正常。
- 临时 QA 入口和文件已移除，并热重载回正式代码。静态分析通过；未新增永久展示 Widget 测试，也未重启 GUI / Pi。

## 卡片毛玻璃验证

- `flutter analyze --no-pub` 无问题；外观与材质相关 12 项核心测试通过，全套 `flutter test --no-pub` **63 项通过**。扩展原有测试覆盖旧文件缺少 cardGlass、错误类型 / 非有限数值 / 上下界、三项独立、仅卡片请求材质、真实文件保存回读和恢复默认，不增加永久展示 Widget 测试。
- 使用安全热重载装入独立临时 QA 弹窗与内存偏好，受控条纹背景配合 `RenderRepaintBoundary.toImage` 验证浅 / 深色 40%、关闭、100%、系统回退、高对比度、减弱动态及窄宽度大文字。只读取自建 QA 图层，不采集其他窗口或活动聊天；原生状态回读为 active。
- 40% 时卡片下条纹边缘被模糊，文字和子控件保持清晰；透明对照区的条纹保持锐利。两张顶层卡片只有两处启用的 filter，嵌套卡片不额外模糊。关闭、100%、模拟系统回退和高对比度均为 0 个启用 filter。
- 在半透明受控背景上取样，浅色 40% 卡片底色 alpha 为约 163–165 / 255，关闭 / 100% / 回退为 255 / 255，确认没有将 Flutter 背景重复合成。此截图验证应用内滤镜与 alpha，不用于证明 Windows 最终桌面合成效果。
- 调用真实设置控件的开关 / 滑块回调验证 20% / 100% 端点；不是全局模拟键鼠。搜索“卡片毛玻璃”时开关与对应滑块均可找到；650px + 150% 文字下滚动可访问滑块。各状态中测试输入框保持焦点、光标位置 5，没有运行时错误。
- 临时 QA 弹窗、Dart 文件与入口已关闭 / 移除，并热重载回生产代码。没有重启 GUI / Pi、修改用户偏好、替换活动聊天或修改 Windows 设置。
- 最终 `flutter build windows --release --no-pub -t lib/main.dart` 成功，交付目录只含正式 `pi_gui.exe`，`lib/main.dart` 无 QA 差异；生产热重载后无运行时错误。

## 毛玻璃激活状态修复验证

- 在原问题窗口、不改用户的两区 30% 不透明度时，最内/最外 Flutter 图层的背景 alpha 均约为 30%，排除了 Flutter 不透明底层覆盖。窗口在前台但 NC 激活位为 0；受控红/蓝双色背景下，标题栏两个空白采样点都为 `(221,221,220)`。一次性校正 NC 激活后，两点分别为 `(244,176,162)` / `(171,183,243)`，确认根因在窗口激活状态而不是 Windows 的透明开关。此临时诊断不是永久修复方式。
- 对新编译的独立 Profile QA 窗口（临时偏好、不创建 Pi、普通非置顶窗口）验证：先刻意置为 NC 未激活，再通过正常 `SendMessage(WM_NCACTIVATE)` 经过插件和 Runner 路由恢复，而非由探针直接调用默认过程恢复，确认修复来自正式 Runner 的消息处理；激活位和红/蓝背景透色均恢复。
- 浅色、深色分别通过 3 轮激活/失活消息、最小化后还原、最大化后还原；另走查一次真实窗口前后台切换。浅色两个采样点最大通道差为 81，深色为 152，均不是灰色平层。关闭两区后返回 `disabled`，再开启及切换深色后返回 `active` 并继续正确透色。
- 仅采样已确认 PID 的 QA/目标窗口空白标题栏点，背景由自建不透明窗口提供，不保存或读取聊天截图。采样前需确认窗口未最小化、点在屏幕内、目标在前台；`GetPixel == 0xFFFFFFFF` 是 `CLR_INVALID`，不能当作白色。临时还原/置顶实验结束后恢复原窗口状态。
- 临时 Dart 像素探针通过安全热重载装入和移除，生产 Dart 文件恢复原样；活动会话、GUI 和 Pi 未重启，无运行时错误。独立 QA 窗口及参照背景已关闭。没有修改用户的外观参数、Windows 设置、Pub 插件或 Flutter SDK。
- 本次 `flutter analyze --no-pub` 无问题，全套 **57 项测试通过**；新 Profile 和生产入口 Release 构建成功。修复是 C++ Runner 改动，持续修复须下次启动新构建，不能靠热重载替换旧进程里的原生代码。

## 初版毛玻璃验证（历史记录）

- `flutter analyze --no-pub` 无问题；全套 **57 项测试通过**，正式 `flutter build windows --release -t lib/main.dart` 成功。
- 新增 `test/window_material_test.dart` 的 5 项核心测试：旧偏好迁移/坏值/区域独立、请求串行和过时响应、系统策略与响应竞态、处理中销毁、原生通道编码/缺失/未知响应。原有 7 项外观测试继续通过，不新增纯样式 Widget 测试。
- 独立 Windows Profile QA 窗口使用临时偏好文件，直接装载生产设置页/公共外壳，不创建 Pi。真实指针打开两组选项、选择开关、拖动 20%/100% 端点；另一项的值不变，恢复默认确认可关闭两区并恢复 65%/85%。
- 原生 DWM 属性回读：开启时为 3（Acrylic），两区关闭后为 1（None）。Flutter 图层取样：侧栏单独 20% 时两区 alpha 为 51/255，两区 20% 为 51/51，侧栏 100% + 主界面 20% 为 255/51，确认没有透明度叠加。
- 使用自建不透明彩条窗口作为 QA 背景，在核实两个 PID、背景覆盖范围和前台 QA 窗口后，仅截取 QA 窗口范围检查最终系统合成效果：模糊彩条可见、底色互不干扰、圆角与正文清晰。普通 Flutter 图层截图不含 DWM 背景；`PrintWindow` 在透明处可能显示黑色，不能据此判定原生效果失败。没有抓取其他应用内容。
- 深色主题、最大化/还原、920×600 + 18 字号 + 150% UI 已走查；滚动后两区设置均可访问，150% 下实际滑块拖拽仍可到 20%/100%。重开独立 QA 窗口后恢复之前的两区值并返回 active。系统策略回退使用核心状态机测试覆盖，未为测试修改系统全局透明、高对比度或节电选项。
- 临时 QA 入口已移除，QA 窗口和自建背景窗口已关闭。未热重启、关闭或覆盖承载当前 Agent 的 GUI / Pi / 时间线；原生效果须下次启动新构建后使用。

## 历史验证记录

顶部 / 侧栏一体化调整已通过 `flutter analyze`，并热重载到当前 Windows GUI。使用 Flutter inspector 截图确认两区底色一致、顶部横线与侧栏竖线消失，主内容左上角圆弧正常，未重启 GUI / Pi 或切换活动会话。随后同步设置页的单角圆角、无描边和贴边布局，`flutter analyze --no-pub` 通过并完成热重载；当时设置路由未打开，未取得设置页截图。这些是纯展示调整，不新增 Widget 测试，也未重新运行下述历史全套构建验证。

共享拖拽侧栏通过当前 Windows GUI 的真实 Flutter 指针事件走查：设置页从 260 拖到 350px 后返回首页仍为 350px；首页再拖到 290px，重新打开设置仍为 290px。两页拖拽条与主内容左边缘的实际 RenderBox 坐标逐项一致。继续验证 180 / 480px 边界和复位回调返回 260px；700px 逻辑视口下宽度上限为 350px。已取得设置页 inspector 截图，确认圆角、贴边和统一底色正常，检查无运行时错误。验证结束恢复原宽度和原页面，移除临时 QA helper，不关闭或重启 GUI / Pi。

```bash
flutter analyze
flutter test test/appearance_test.dart
flutter test
flutter build windows --release
```

`test/appearance_test.dart` 聚焦 7 项高风险逻辑：坏值/版本容错、真实文件替换、M3/覆盖优先级与前景对比、字号和 UI 比例独立、异步保存顺序、失败重试、系统色刷新不覆盖用户设置。纯展示 Widget 不增加截图断言测试。

折叠栏对齐修复通过独立临时弹窗热重载走查：448 逻辑像素宽下分别显示短 / 长说明，标题与说明的左边缘一致、箭头位置一致；248 宽 + 150% 文字缩放下长说明正常省略，不推移标题或箭头；展开内容后水平对齐保持不变。两处原子组件的静态分析通过。临时 QA 代码与弹窗验证后移除，不重启或改写当前聊天。

动态配色首次实现时使用独立 Windows QA 副本和独立偏好文件验证：真实系统强调色、明暗/种子色切换、HEX 非法禁用与合法提交、搜索高级颜色、恢复确认、920×600 下 18 字号 + 150% UI、缩放后的菜单实际命中和返回保留底层页面。另用离线聊天组件验证空会话居中、有消息后底部输入、高字号 / 高比例与输入框颜色覆盖。截图仅使用 Flutter inspector，不抓取其他应用。没有热重启或关闭承载当前 Agent 的 GUI/Pi。

动态配色首次实现时 `flutter analyze` 无问题、全套 52 项测试通过，Windows Release 构建成功。可执行文件为 `build/windows/x64/runner/Release/pi_gui.exe`；当前已经运行的旧 Debug 窗口不会被自动替换。

参考：[dynamic_color 官方包说明](https://pub.dev/packages/dynamic_color/versions/1.8.1)、[VS Code 分区主题色参考](https://code.visualstudio.com/api/references/theme-color)（标题栏 / 侧栏背景与边框分开管理）。

毛玻璃参考：[WM_NCACTIVATE 与 lParam=-1](https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-ncactivate)、[Windows Acrylic 材质](https://learn.microsoft.com/en-us/windows/apps/design/style/acrylic)、[DWM_SYSTEMBACKDROP_TYPE](https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwm_systembackdrop_type)。原生构建与 C++ 检查见 [Windows 构建说明](windows_build.md)。
