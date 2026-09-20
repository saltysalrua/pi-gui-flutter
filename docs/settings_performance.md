---
title: "设置页性能审计与更新边界"
version: "1.0.0"
status: "implemented"
type: "performance-audit"
tags: [flutter, settings, performance, theme]
---

# 设置页性能审计

## 用户可见变化

设置入口、选项、开关与保存方式不变。进入设置不再一次性布局屏幕外的全部外观选项；切换扩展显示等非配色选项，不再让全应用执行一轮没有视觉变化的主题动画。真正的配色、卡片材质和卡片高度变化仍保留原有动效，并继续遵循减弱动态设置。

没有修改用户偏好、Windows 透明设置、Pi RPC、会话生命周期或帧率上限，也没有用关掉毛玻璃来换取测试数字。

## 定位到的问题

1. `PiGuiApp` 原来监听 `AppearanceController` 的所有通知：修改偏好、保存完成、系统色读取开始/结束都会重新构造两套 `ThemeData`，包含 Material 3 调色板计算。
2. `AppColorsExtension` / `AppCardTheme` 原来按对象身份比较。两次构造的颜色即使完全相同，`ThemeData` 仍判定不同，使普通开关触发约 250ms 的全局 `AnimatedTheme`。主题依赖者随后逐帧重建，而不只是被操作的卡片。
3. `SingleChildScrollView + Column` 会在入场首帧挂载和布局外观页的全部分组，包括屏幕外的颜色列表和代码预览；它们也会参加后续主题重建。
4. 保存状态和系统色忙碌状态通过全局 `AppearanceScope` 传播，连不关心保存进度的首页、工具卡和插槽也收到通知。

## 实现

| 路径 | 更新边界 |
| --- | --- |
| `lib/ui/features/settings/controllers/appearance_controller.dart` | Controller / `appearanceChanges` 只在偏好或系统强调色值变化时通知；`statusChanges` 单独通知保存/读取状态，页面合并监听两者，错误提示和重试不丢失 |
| `lib/main.dart` | `AppearanceScope` 与应用层监听 `appearanceChanges`；在监听 builder 外创建 `AppThemeCache`，不会因保存进度重建应用配置 |
| `lib/ui/core/theme/app_theme.dart` | 按明暗各缓存一个基础主题和一个当前材质版本；只有有效种子色、对应明暗颜色覆盖、基准字号变化时重算色板 |
| `lib/ui/core/theme/app_colors_extension.dart` | 全部语义色参与值相等与 hashCode，等值主题不再被判成变化 |
| `lib/ui/core/theme/app_card_theme.dart` | 不透明度和模糊 sigma 参与值相等与 hashCode |
| `lib/ui/features/settings/views/appearance_settings_view.dart` | `ListView.builder` 按可见分组挂载；每组仍复用 AppSettingsGroup / AppSettingRow，保持 880px 最大宽度与原有间距 |
| `lib/ui/features/settings/views/settings_view.dart` | 页签在视口内淡切；进出页各自持有滚动控制器和 BackdropGroup，退出页卸载时释放旧控制器 |

缓存不包含 `mode`、UI 比例、帧率、工具挡位、闲置分钟数、槽位可见性或两区玻璃参数，因为这些不参与主题色板生成；它们仍通过原本的应用配置或偏好订阅即时生效。卡片材质单独替换主题扩展，复用已有色板和文字样式。颜色覆盖按值比较，不依赖从 JSON 读回后 Map 的对象身份。

缓存属于 `PiGuiApp.build` 创建的闭包，不是进程级静态缓存：Controller 通知只运行内部 builder，保留缓存；正常重建或热重载会自然重建缓存，不留下旧主题代码。Navigator / HomeView 不新增随偏好变化的 Key。

`AppearanceScope` 保持原 `InheritedNotifier<AppearanceController>` 类型和 Controller 身份，只把非外观通知移到 `statusChanges`。不能为了分流直接改成 `InheritedNotifier<Listenable>`：运行中的 `_InheritedNotifierElement<AppearanceController>` 无法热重载成另一个泛型实例，会报 `newWidget` 类型错误。审计中发现过这一旧状态兼容问题，已恢复原类型并重新热重载确认无运行时错误；没有用重启当前会话来绕过。

快速反复切页时，淡出的旧页与新页不能共用 ScrollController，否则 Scrollbar 可能遇到多个 ScrollPosition。旧控制器登记为退出中，由 `onDetach` 释放，设置路由关闭时清理剩余实例。每个进出页的模糊组键也独立，避免交叉淡化期间重叠区域共用一个 BackdropKey。外观组内的高度动画不变。

**没有新增 Pi RPC 命令或事件。** 持久化数据结构仍是原 `appearance.json` version 1，保存串行、合并旧快照、失败重试逻辑不变。

## 对照结果与边界

同一台 Windows 机器、独立的 **Profile** 构建窗口，1200×800、默认字号和 UI 比例、系统配色、顶部/主界面玻璃开启，保留 120/30 帧率配置。使用内存偏好与无 RPC 的占位首页，自动调用正式设置入口及控件回调；通过 `addTimingsCallback` 采样，不开启逐 Widget profiling。

| 项目 | 修改前 | 修改后 |
| --- | --- | --- |
| 首次进入 UI 帧峰值 | 41.6ms | 20.4ms |
| 后两轮进入 UI 帧峰值 | 8.2–8.7ms | 约 4.1ms |
| 首屏挂载设置行 | 27 | 8 |
| 非配色槽位偏好更新，三轮帧数 | 34 / 34 / 32 | 1 / 1 / 1 |
| 两次构造同值 ThemeData | 不相等 | 相等 |

真实卡片毛玻璃开关仍保留材质/高度动画。最终 12 次开关采样的 UI P95 从约 5.8–9.1ms 变为 3.0–5.6ms。首次优化复测曾为 5.7–8.1ms；这些范围也说明采样会受机器负载影响。光栅化耗时没有一致下降，不能据此宣称 GPU 性能已全面改善。首次入场仍可能超过 16.7ms，也不承诺 Debug 或复杂聊天后台与此数字相同。这里验证的是具体的无效重建和首屏布局开销，不是全应用性能跑分或实际鼠标端到端延迟。

验证材料保存在本机忽略目录 `.dart_tool/settings_perf.dart`、`settings_perf_baseline.json`、`settings_perf_after.json`、`settings_perf_final.json`。独立构建使用 `.dart_tool/glass_qa/app`（共享正式组件、单独 build 目录与临时入口），不覆盖活动 GUI 可执行文件；测试窗口记录 PID 并自行退出，禁止按同名进程批量结束。

## 回归验证

- `test/appearance_test.dart` 新增两项核心测试：主题缓存输入/明暗覆盖/有效种子色/卡片材质的失效边界；全局外观通知与保存/系统色忙碌状态的分离。原来的文件保存、坏值容错、异步串行与重试测试保留，没有增加纯展示 Widget 测试。
- 外观、原生材质与帧配对相关 **19 项测试通过**；8 个修改后的 Dart 文件定向分析无错误。
- 独立新 Debug 窗口验证 12 次快速切换“插件（无通道）/外观”、搜索命中/无结果/清空、4 次卡片玻璃开关，以及 920×600、18 字号、150% UI、深色下滚动访问玻璃设置。无运行时错误，返回后占位首页始终只构建一次。
- 截图仅使用 QA 自身的 `RenderRepaintBoundary`，确认大字号窄窗口下可滚动到对应控件，没有读取当前聊天或其他应用窗口。
- 正式 GUI 在修正上述泛型兼容问题后再次热重载成功，运行时错误回读为空；没有执行热重启或结束 GUI / Pi 的操作。涉及滚动子树的变化另外使用全新 QA 进程验证，而非只依赖热重载旧 State。

```bash
flutter test --no-pub test/appearance_test.dart test/window_material_test.dart test/frame_pacer_test.dart
```

外观操作、原生材质策略与存储格式见 [外观设置](appearance_settings.md)；全局限帧和持续动画时钟见 [帧率设置](frame_rate_performance.md)。
