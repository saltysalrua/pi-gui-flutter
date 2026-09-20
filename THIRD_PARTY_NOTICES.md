---
title: "第三方组件与资源声明"
type: "legal-notices"
status: "maintained"
---

# 第三方组件与资源声明

Pi GUI 使用下列第三方软件、字体与图标。版权属于各自权利人，各组件适用各自的许可证；本声明不会将它们改为 Pi GUI 的许可，也不表示权利人为本项目背书。

本清单按 **Pi GUI 1.0.6+7** 的 `pubspec.lock`、**Flutter 3.47.4 / Dart 3.13.3** 与实际资源核对。它是许可索引，不替代完整许可原文，也不是“已完成全部合规审核”的保证。原生 Rust 依赖、品牌图稿来源和高亮语法来源尚有待核对项，见文末。

## 1. 随发布包保留的许可文件

Windows ZIP 与 Linux tar.gz 均保留：

| 发布目录内的路径 | 内容 |
| --- | --- |
| `LICENSE` | Pi GUI 原创代码的 MIT 许可证 |
| `THIRD_PARTY_NOTICES.md` | 本声明与组件索引 |
| `licenses/MiSans-LICENSE.pdf` | MiSans 官方许可原文 |
| `licenses/MaterialIcons-LICENSE.txt` | 当前 Flutter SDK 所附 Material Icons 许可原文 |
| `data/flutter_assets/NOTICES.Z` | Flutter 构建生成的 SDK、引擎及 Pub 包许可汇总 |
| `licenses/Flutter-Pub-NOTICES.txt` | 上述 `NOTICES.Z` 的原样解压文本，方便直接阅读 |

请完整分发应用目录，不能只复制 EXE、主程序或动态库而丢弃许可与资源。下列 Pub 链接是源码查阅入口，不能代替随包保留的版权及许可文本。平台相关内容以对应版本的实际构建产物为准。

## 2. 字体与图标

### MiSans

本软件使用小米的 **MiSans** 字体，包含原始 Regular、Medium、Demibold、Bold 字重，未修改字体文件。字体及相关知识产权归 Xiaomi Inc.（小米科技有限责任公司）及相应权利人所有。

MiSans 按《MiSans 字体知识产权许可协议》使用，不适用本项目其他代码或依赖的许可。字体随本应用分发，不作为独立字体产品提供；不得将其误标为 OFL、MIT 或其他开源字体许可。

- 官方来源：<https://hyperos.mi.com/font/>
- 官方许可原文：<https://hyperos.mi.com/font-download/MiSans%E5%AD%97%E4%BD%93%E7%9F%A5%E8%AF%86%E4%BA%A7%E6%9D%83%E8%AE%B8%E5%8F%AF%E5%8D%8F%E8%AE%AE.pdf>
- 仓库中的原文副本：`assets/fonts/MiSans/LICENSE.pdf`
- 发布包中的原文副本：`licenses/MiSans-LICENSE.pdf`

使用、复制或分发时请保留字体内原有版权信息和完整许可协议，具体权利与限制以原文为准。

### Material Icons

界面通过 Flutter 的 `Icons` 使用 **Google Material Design Icons**。当前固定 SDK 附带的 `materialicons_license.txt` 为 **Creative Commons Attribution 4.0 International（CC BY 4.0）**；这里按实际随 SDK 提供的字体许可记录，不用其他版本网站上的许可标签覆盖它。

- 来源：<https://github.com/google/material-design-icons>；本项目取用 Flutter SDK 随附字体。
- 许可说明：<https://creativecommons.org/licenses/by/4.0/>
- 原始文件：Flutter SDK 的 `bin/cache/artifacts/material_fonts/materialicons_license.txt`。
- 仓库和发布包中的原文副本：`licenses/MaterialIcons-LICENSE.txt`。
- 本项目未自行修改图标字形；Flutter Release 构建会按所用图标裁剪字体（tree shaking / 子集化），界面可能调整显示尺寸与颜色。

### Cupertino Icons

锁定依赖 `cupertino_icons 1.0.9` 的许可为 **MIT**，包内版权为 **Copyright (c) 2016 Vladimir Kharlampidi**。是否保留字形由实际构建与引用情况决定；这里保留依赖声明，不把它误写成 Apple 专有字体或 Material Icons 的许可。完整原文在包的 `LICENSE` 及随包的 Flutter/Pub 许可汇总中。

## 3. Flutter、Dart 与 Pub 包

Flutter framework 与 Dart SDK 的主要许可为 **BSD-3-Clause**，但引擎及其第三方库并非全是这一种许可。Flutter 通过 `sky_engine` 汇总引擎依赖声明，其中包括 ICU、HarfBuzz、图像编解码等组件；必须保留汇总内每一项原始版权与许可，不能只写一句“Flutter 使用 BSD”。

- Flutter：<https://github.com/flutter/flutter>。
- Dart：<https://github.com/dart-lang/sdk>。
- 当前 SDK 的引擎发行说明指向 `sky_engine/LICENSE`；它已纳入构建的 `NOTICES.Z`。
- 下表版本取自 `pubspec.lock`，许可取自该版本包内 `LICENSE`，而非只查看最新版本的网页。
- `+` 表示同一包的不同部分包含不同许可，不是可以任意选一个。双许可是否可选，应以组件原文为准。

### 直接应用依赖

| 组件 | 锁定版本 | 包内许可 |
| --- | --- | --- |
| [cupertino_icons](https://pub.dev/packages/cupertino_icons/versions/1.0.9/license) | 1.0.9 | MIT |
| [dynamic_color](https://pub.dev/packages/dynamic_color/versions/1.8.1/license) | 1.8.1 | Apache-2.0 |
| [file_selector](https://pub.dev/packages/file_selector/versions/1.1.0/license) | 1.1.0 | BSD-3-Clause |
| `flutter` | Flutter 3.47.4 | BSD-3-Clause（Flutter SDK） |
| `flutter_localizations` | Flutter 3.47.4 | BSD-3-Clause（Flutter SDK） |
| [flutter_markdown_plus](https://pub.dev/packages/flutter_markdown_plus/versions/1.0.12/license) | 1.0.12 | BSD-3-Clause |
| [flutter_svg](https://pub.dev/packages/flutter_svg/versions/2.3.0/license) | 2.3.0 | MIT |
| [highlight](https://pub.dev/packages/highlight/versions/0.7.0/license) | 0.7.0 | MIT |
| [intl](https://pub.dev/packages/intl/versions/0.20.3/license) | 0.20.3 | BSD-3-Clause |
| [markdown](https://pub.dev/packages/markdown/versions/7.3.1/license) | 7.3.1 | BSD-3-Clause |
| [path](https://pub.dev/packages/path/versions/1.9.1/license) | 1.9.1 | BSD-3-Clause |
| [path_provider](https://pub.dev/packages/path_provider/versions/2.1.6/license) | 2.1.6 | BSD-3-Clause |
| [super_clipboard](https://pub.dev/packages/super_clipboard/versions/0.9.1/license) | 0.9.1 | MIT |
| [url_launcher](https://pub.dev/packages/url_launcher/versions/6.3.2/license) | 6.3.2 | BSD-3-Clause |
| [window_manager](https://pub.dev/packages/window_manager/versions/0.5.2/license) | 0.5.2 | MIT |

### 直接开发依赖

| 组件 | 锁定版本 | 包内许可 |
| --- | --- | --- |
| [flutter_lints](https://pub.dev/packages/flutter_lints/versions/6.0.0/license) | 6.0.0 | BSD-3-Clause |
| `flutter_test` | Flutter 3.47.4 | BSD-3-Clause（Flutter SDK） |

### 其他解析依赖

下表涵盖锁定解析树中的其他包，包含传递依赖、构建或测试工具，以及 Android、iOS、macOS、Web 等平台实现。列在锁文件中不等于一定链接进 Windows 或 Linux 可执行文件，不能把这张表当成某个平台的精确二进制 SBOM。

<details>
<summary>展开其他依赖及其许可证</summary>

| 组件 | 锁定版本 | 包内许可 |
| --- | --- | --- |
| [args](https://pub.dev/packages/args/versions/2.7.0/license) | 2.7.0 | BSD-3-Clause |
| [async](https://pub.dev/packages/async/versions/2.13.1/license) | 2.13.1 | BSD-3-Clause |
| [boolean_selector](https://pub.dev/packages/boolean_selector/versions/2.1.2/license) | 2.1.2 | BSD-3-Clause |
| [characters](https://pub.dev/packages/characters/versions/1.4.1/license) | 1.4.1 | BSD-3-Clause |
| [clock](https://pub.dev/packages/clock/versions/1.1.2/license) | 1.1.2 | Apache-2.0 |
| [code_assets](https://pub.dev/packages/code_assets/versions/1.2.1/license) | 1.2.1 | BSD-3-Clause |
| [collection](https://pub.dev/packages/collection/versions/1.19.1/license) | 1.19.1 | BSD-3-Clause |
| [cross_file](https://pub.dev/packages/cross_file/versions/0.3.5+5/license) | 0.3.5+5 | BSD-3-Clause |
| [crypto](https://pub.dev/packages/crypto/versions/3.0.7/license) | 3.0.7 | BSD-3-Clause |
| [device_info_plus](https://pub.dev/packages/device_info_plus/versions/11.5.0/license) | 11.5.0 | BSD-3-Clause |
| [device_info_plus_platform_interface](https://pub.dev/packages/device_info_plus_platform_interface/versions/7.0.3/license) | 7.0.3 | BSD-3-Clause |
| [fake_async](https://pub.dev/packages/fake_async/versions/1.3.3/license) | 1.3.3 | Apache-2.0 |
| [ffi](https://pub.dev/packages/ffi/versions/2.2.0/license) | 2.2.0 | BSD-3-Clause |
| [file](https://pub.dev/packages/file/versions/7.0.1/license) | 7.0.1 | BSD-3-Clause |
| [file_selector_android](https://pub.dev/packages/file_selector_android/versions/0.5.2+6/license) | 0.5.2+6 | Apache-2.0 + BSD-3-Clause |
| [file_selector_ios](https://pub.dev/packages/file_selector_ios/versions/0.5.3+6/license) | 0.5.3+6 | BSD-3-Clause |
| [file_selector_linux](https://pub.dev/packages/file_selector_linux/versions/0.9.4+1/license) | 0.9.4+1 | BSD-3-Clause |
| [file_selector_macos](https://pub.dev/packages/file_selector_macos/versions/0.9.5+1/license) | 0.9.5+1 | BSD-3-Clause |
| [file_selector_platform_interface](https://pub.dev/packages/file_selector_platform_interface/versions/2.7.0/license) | 2.7.0 | BSD-3-Clause |
| [file_selector_web](https://pub.dev/packages/file_selector_web/versions/0.9.5/license) | 0.9.5 | BSD-3-Clause |
| [file_selector_windows](https://pub.dev/packages/file_selector_windows/versions/0.9.3+6/license) | 0.9.3+6 | BSD-3-Clause |
| [fixnum](https://pub.dev/packages/fixnum/versions/1.1.1/license) | 1.1.1 | BSD-3-Clause |
| `flutter_web_plugins` | Flutter 3.47.4 | BSD-3-Clause（Flutter SDK） |
| [hooks](https://pub.dev/packages/hooks/versions/2.0.2/license) | 2.0.2 | BSD-3-Clause |
| [http](https://pub.dev/packages/http/versions/1.6.0/license) | 1.6.0 | BSD-3-Clause |
| [http_parser](https://pub.dev/packages/http_parser/versions/4.1.2/license) | 4.1.2 | BSD-3-Clause |
| [irondash_engine_context](https://pub.dev/packages/irondash_engine_context/versions/0.5.5/license) | 0.5.5 | MIT |
| [irondash_message_channel](https://pub.dev/packages/irondash_message_channel/versions/0.7.0/license) | 0.7.0 | MIT |
| [jni](https://pub.dev/packages/jni/versions/1.0.3/license) | 1.0.3 | BSD-3-Clause |
| [jni_flutter](https://pub.dev/packages/jni_flutter/versions/1.0.3/license) | 1.0.3 | BSD-3-Clause |
| [jni_util](https://pub.dev/packages/jni_util/versions/1.0.0/license) | 1.0.0 | BSD-3-Clause |
| [json_annotation](https://pub.dev/packages/json_annotation/versions/4.12.0/license) | 4.12.0 | BSD-3-Clause |
| [leak_tracker](https://pub.dev/packages/leak_tracker/versions/11.0.2/license) | 11.0.2 | BSD-3-Clause |
| [leak_tracker_flutter_testing](https://pub.dev/packages/leak_tracker_flutter_testing/versions/3.0.10/license) | 3.0.10 | BSD-3-Clause |
| [leak_tracker_testing](https://pub.dev/packages/leak_tracker_testing/versions/3.0.2/license) | 3.0.2 | BSD-3-Clause |
| [lints](https://pub.dev/packages/lints/versions/6.1.0/license) | 6.1.0 | BSD-3-Clause |
| [logging](https://pub.dev/packages/logging/versions/1.3.0/license) | 1.3.0 | BSD-3-Clause |
| [matcher](https://pub.dev/packages/matcher/versions/0.12.20/license) | 0.12.20 | BSD-3-Clause |
| [material_color_utilities](https://pub.dev/packages/material_color_utilities/versions/0.13.0/license) | 0.13.0 | Apache-2.0 |
| [meta](https://pub.dev/packages/meta/versions/1.19.0/license) | 1.19.0 | BSD-3-Clause |
| [objective_c](https://pub.dev/packages/objective_c/versions/9.5.0/license) | 9.5.0 | BSD-3-Clause |
| [package_config](https://pub.dev/packages/package_config/versions/3.0.0/license) | 3.0.0 | BSD-3-Clause |
| [path_parsing](https://pub.dev/packages/path_parsing/versions/1.1.0/license) | 1.1.0 | MIT |
| [path_provider_android](https://pub.dev/packages/path_provider_android/versions/2.3.1/license) | 2.3.1 | BSD-3-Clause |
| [path_provider_foundation](https://pub.dev/packages/path_provider_foundation/versions/2.6.0/license) | 2.6.0 | BSD-3-Clause |
| [path_provider_linux](https://pub.dev/packages/path_provider_linux/versions/2.2.2/license) | 2.2.2 | BSD-3-Clause |
| [path_provider_platform_interface](https://pub.dev/packages/path_provider_platform_interface/versions/2.1.3/license) | 2.1.3 | BSD-3-Clause |
| [path_provider_windows](https://pub.dev/packages/path_provider_windows/versions/2.3.0/license) | 2.3.0 | BSD-3-Clause |
| [petitparser](https://pub.dev/packages/petitparser/versions/7.0.2/license) | 7.0.2 | MIT |
| [pixel_snap](https://pub.dev/packages/pixel_snap/versions/0.1.5/license) | 0.1.5 | MIT |
| [platform](https://pub.dev/packages/platform/versions/3.2.0/license) | 3.2.0 | BSD-3-Clause |
| [plugin_platform_interface](https://pub.dev/packages/plugin_platform_interface/versions/2.1.8/license) | 2.1.8 | BSD-3-Clause |
| [pub_semver](https://pub.dev/packages/pub_semver/versions/2.2.1/license) | 2.2.1 | BSD-3-Clause |
| [record_use](https://pub.dev/packages/record_use/versions/0.6.0/license) | 0.6.0 | BSD-3-Clause |
| [screen_retriever](https://pub.dev/packages/screen_retriever/versions/0.2.2/license) | 0.2.2 | MIT |
| [screen_retriever_linux](https://pub.dev/packages/screen_retriever_linux/versions/0.2.2/license) | 0.2.2 | MIT |
| [screen_retriever_macos](https://pub.dev/packages/screen_retriever_macos/versions/0.2.2/license) | 0.2.2 | MIT |
| [screen_retriever_platform_interface](https://pub.dev/packages/screen_retriever_platform_interface/versions/0.2.2/license) | 0.2.2 | MIT |
| [screen_retriever_windows](https://pub.dev/packages/screen_retriever_windows/versions/0.2.2/license) | 0.2.2 | MIT |
| `sky_engine` | Flutter 3.47.4 | 引擎及第三方许可汇总，多种许可 |
| [source_span](https://pub.dev/packages/source_span/versions/1.10.2/license) | 1.10.2 | BSD-3-Clause |
| [stack_trace](https://pub.dev/packages/stack_trace/versions/1.12.1/license) | 1.12.1 | BSD-3-Clause |
| [stream_channel](https://pub.dev/packages/stream_channel/versions/2.1.4/license) | 2.1.4 | BSD-3-Clause |
| [string_scanner](https://pub.dev/packages/string_scanner/versions/1.4.1/license) | 1.4.1 | BSD-3-Clause |
| [super_native_extensions](https://pub.dev/packages/super_native_extensions/versions/0.9.1/license) | 0.9.1 | MIT |
| [term_glyph](https://pub.dev/packages/term_glyph/versions/1.2.2/license) | 1.2.2 | BSD-3-Clause |
| [test_api](https://pub.dev/packages/test_api/versions/0.7.12/license) | 0.7.12 | BSD-3-Clause |
| [typed_data](https://pub.dev/packages/typed_data/versions/1.4.0/license) | 1.4.0 | BSD-3-Clause |
| [url_launcher_android](https://pub.dev/packages/url_launcher_android/versions/6.3.30/license) | 6.3.30 | BSD-3-Clause |
| [url_launcher_ios](https://pub.dev/packages/url_launcher_ios/versions/6.4.2/license) | 6.4.2 | BSD-3-Clause |
| [url_launcher_linux](https://pub.dev/packages/url_launcher_linux/versions/3.2.3/license) | 3.2.3 | BSD-3-Clause |
| [url_launcher_macos](https://pub.dev/packages/url_launcher_macos/versions/3.2.6/license) | 3.2.6 | BSD-3-Clause |
| [url_launcher_platform_interface](https://pub.dev/packages/url_launcher_platform_interface/versions/2.3.2/license) | 2.3.2 | BSD-3-Clause |
| [url_launcher_web](https://pub.dev/packages/url_launcher_web/versions/2.4.3/license) | 2.4.3 | BSD-3-Clause |
| [url_launcher_windows](https://pub.dev/packages/url_launcher_windows/versions/3.1.6/license) | 3.1.6 | BSD-3-Clause |
| [uuid](https://pub.dev/packages/uuid/versions/4.6.0/license) | 4.6.0 | MIT |
| [vector_graphics](https://pub.dev/packages/vector_graphics/versions/1.2.3/license) | 1.2.3 | BSD-3-Clause |
| [vector_graphics_codec](https://pub.dev/packages/vector_graphics_codec/versions/1.1.13/license) | 1.1.13 | BSD-3-Clause |
| [vector_graphics_compiler](https://pub.dev/packages/vector_graphics_compiler/versions/1.3.0/license) | 1.3.0 | BSD-3-Clause |
| [vector_math](https://pub.dev/packages/vector_math/versions/2.4.2/license) | 2.4.2 | BSD-3-Clause |
| [vm_service](https://pub.dev/packages/vm_service/versions/15.3.0/license) | 15.3.0 | BSD-3-Clause |
| [web](https://pub.dev/packages/web/versions/1.1.1/license) | 1.1.1 | BSD-3-Clause |
| [win32](https://pub.dev/packages/win32/versions/5.15.0/license) | 5.15.0 | BSD-3-Clause |
| [win32_registry](https://pub.dev/packages/win32_registry/versions/2.1.0/license) | 2.1.0 | BSD-3-Clause |
| [xdg_directories](https://pub.dev/packages/xdg_directories/versions/1.1.0/license) | 1.1.0 | BSD-3-Clause |
| [xml](https://pub.dev/packages/xml/versions/7.0.1/license) | 7.0.1 | MIT |
| [yaml](https://pub.dev/packages/yaml/versions/3.1.4/license) | 3.1.4 | MIT |

</details>

## 4. 原生组件与系统库

`super_clipboard 0.9.1` / `super_native_extensions 0.9.1` 的外层包采用 **MIT**，版权为 **Copyright (c) 2022 Superlist, Matej Knopp and the contributors**。它们还通过原生代码使用 Rust crates；不能因此把内部全部依赖都标成 MIT，也不能认为 Pub 的 `LICENSE` 自动包含所有 crates 的声明。

- 原生锁文件：`super_native_extensions` Pub 包内的 `rust/Cargo.lock`，当前有 **206 个包条目**，覆盖多个平台及构建/开发依赖，并非 206 个全部随每个平台分发。
- 其中 `mime_guess 2.0.4` 来自 `knopp/mime_guess` 的 `super_native_extensions` 分支，锁定提交 `8c9abd38a5845db2d8a91a02fee16b226c364874`，不是 crates.io 同名版本的原样来源。
- `irondash_engine_context`、`irondash_message_channel` 等同时有 Dart/Pub 与 Rust 实现；上表只列 Pub 版本，不能用它代替原生依赖核对。
- Windows 使用系统 API 和 Microsoft Visual C++ 运行库。官方便携包不附 VC++ 安装器，系统运行库仍适用 Microsoft 自己的条款。
- Linux 使用 GTK/GLib 等系统库。当前发布流程不复制系统 GTK 安装包；系统库和 Rust 绑定是不同组件，实际附带的 `.so` 仍须按其来源核对。

**当前缺口：尚未完成 Windows / Linux 原生构建实际链接依赖的逐项许可原文收集。** 已检查的 Windows `NOTICES.Z` 没有覆盖完整 Cargo 依赖声明；请勿把它或本表当成原生许可已齐全的证明。正式再分发前应核对 Cargokit 所用的预编译库或源码构建结果，并补齐对应原始文本。

## 5. 外部程序与开发工具

以下项目用于运行或开发，但不随官方 GUI 压缩包捆绑分发：

| 项目 | 用途与许可边界 |
| --- | --- |
| Pi / `@earendil-works/pi-coding-agent` | 用户自行安装的 RPC 后端；所核对上游仓库为 MIT，Copyright (c) 2025 Mario Zechner。实际安装版本及其依赖仍以该安装包原文为准。GUI 不因此取得 Pi 品牌的授权或背书。 |
| Node.js | 运行用户安装的 Pi；Node.js 主体为 MIT，内含组件有各自许可。GUI 不打包 Node.js 运行时。 |
| Git | 访问用户工作区；Git 主体为 GPL-2.0，GUI 通过独立进程调用，不打包 Git。 |
| `resvg-py 0.5.0` | 仅用于从 SVG 生成 Windows ICO；绑定包为 MIT，Copyright (C) 2024, baseplate-admin。它及其 resvg 等依赖不随 GUI 发布；工具许可不替代输入图稿的权利。 |
| Flutter/Dart SDK、Cargokit、构建工具和 GitHub Actions | 开发及构建环境不作为工具链整体打包；编译进产物的代码仍按实际组件许可处理，不能仅因“构建工具”而排除。 |

Pi、Node.js、Git 的用户安装包、插件、模型服务、用户自己的文件和图片，都不由本声明重新授权。

## 6. 尚需确认的来源与维护要求

除上面明确标出的原生依赖缺口，还有两项不能凭猜测填许可证：

1. **品牌图稿**：`assets/images/pi_logo.svg`、`pi_logo_dark.svg` 及派生 ICO 尚未记录作者、原始来源和授权依据。不能仅因为名称含 Pi 或代码仓库公开，就认定图稿采用 MIT 或已取得商标授权；需要由图稿提供者确认。
2. **高亮语法来源**：`highlight 0.7.0` 的包级 MIT 原文已收录，但该包测试引用了 `vendor/highlight.js`。还需核对生成语法与上游 highlight.js 的具体版本、版权及许可，不能仅凭包级 MIT 就认定所有移植内容的权利已经确认。

维护时应同时核对：`pubspec.lock`、Flutter/Dart 版本、实际平台产物、原生锁文件与新增资源。升级依赖后应重新生成 Flutter 许可汇总，更新上表，并复核字体/图标原始许可。字体 PDF、图标许可与汇总文本应继续随 Windows 和 Linux 包分发。

Pi GUI 原创代码采用根目录 `LICENSE` 中的 MIT 许可证，Copyright (c) 2026 saltysalrua。该授权不覆盖第三方组件和资源，也不覆盖上述尚未确认授权来源的品牌图稿；不会消除本声明记录的待核对项。核对过程与维护步骤见源码仓库的 `docs/third_party_audit.md`。
