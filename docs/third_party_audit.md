---
title: "第三方声明核对与维护"
version: "1.0.0"
status: "partial-audit"
type: "developer-guide"
tags: [licenses, dependencies, assets, release]
---

# 第三方声明核对与维护

## 这份记录做什么

用户可在根目录 `THIRD_PARTY_NOTICES.md` 查看组件、来源、许可和未完成项。Windows ZIP 与 Linux tar.gz 的根目录均包含这份声明，`licenses/` 内提供可直接阅读的许可原文。这里记录核对方法，避免下次升级只改版本号、遗漏实际二进制或字体的许可。

本次基线为 Pi GUI `1.0.6+7`、Flutter `3.47.4 / stable`、Dart `3.13.3`。这是工程核对记录，不是对所有来源或法律合规的认证。

## 已核对和补充的内容

| 范围 | 证据与处理 |
| --- | --- |
| Pub 解析树 | 逐一比对 `pubspec.lock` 的 104 个包条目与 `.dart_tool/package_config.json` 指向的安装目录；读取该版本根目录的 `LICENSE`，在声明中列出直接应用、直接开发和其他解析依赖。SDK 包使用 Flutter SDK 许可，其中 `sky_engine` 含多种第三方许可，不能统一标为 BSD。 |
| 不同许可 | `dynamic_color`、`material_color_utilities`、`clock`、`fake_async` 为 Apache-2.0；`flutter_svg`、剪贴板相关包等为 MIT；`file_selector_android` 的原文同时含 BSD-3-Clause 与 Apache-2.0。其余以表中各包原文链接为准。 |
| MiSans | 保留四个原始字重的现有声明、官方链接及 `assets/fonts/MiSans/LICENSE.pdf`；两平台均分发 PDF，不改成 OFL 或 MIT。 |
| Material Icons | 实际 Flutter SDK 的 `bin/cache/artifacts/material_fonts/materialicons_license.txt` 是 CC BY 4.0。本地 Windows Release 的 `NOTICES.Z` 不含该许可文本，新增其原样副本 `licenses/MaterialIcons-LICENSE.txt`，并单列来源、署名与 Release 字体裁剪说明。 |
| Cupertino Icons | 锁定包 `1.0.9` 的 LICENSE 为 MIT，署名 Vladimir Kharlampidi；不将锁文件存在误当成所有字形均已打包。 |
| Flutter 引擎 | SDK 的 `license.windows_flutter.md` 指向 `sky_engine/LICENSE`；后者是引擎第三方声明汇总。检查的 Windows `NOTICES.Z` 已包含 SDK/引擎和 Pub 许可。Linux 必须使用其自身构建生成的文件，不复制 Windows 汇总冒充。 |
| 许可可读性 | `tool/ci_release.py` 在两种打包路径中保留 `NOTICES.Z`，另提供原样解压的 `licenses/Flutter-Pub-NOTICES.txt`。缺失、损坏、空文本或非 UTF-8 时拒绝打包，不创建“完整许可已齐”的假象。 |
| 开发工具及外部程序 | 明确 Pi、Node.js、Git、resvg-py 与构建工具的分发边界；它们不作为独立工具随官方包分发。原生编译进产物的部分仍须单独核对。 |

完整依赖列表覆盖解析树，包括测试、构建和其他平台包；不是精确到链接结果的 SBOM。具体许可原文和版权不能被表格里的简写替代。

## 未完成项：不能写成已经解决

### 原生剪贴板的 Rust 依赖

`super_native_extensions 0.9.1` 的 `rust/Cargo.lock` 含 206 个包条目，包括多平台、构建和开发依赖；检查的 Windows 自动许可汇总没有包含完整 Cargo 依赖声明。仅保留外层 Pub 包的 MIT 不够证明原生依赖许可齐全。

还需：

1. 核实 Windows / Linux 构建使用 Cargokit 预编译产物还是源码构建，以及对应版本、目标、启用功能与实际链接库。
2. 收集原生依赖的原始版权、LICENSE/NOTICE，以及 vendored 子组件的许可；不能只读取 Cargo.toml 的 SPDX 标签。
3. 对 Git 依赖按锁定提交核对。例如 `mime_guess 2.0.4` 来自 `knopp/mime_guess`，提交 `8c9abd38a5845db2d8a91a02fee16b226c364874`。
4. 注意部分源码包不自带完整许可文本，需要回到对应提交核对，不能给同名包套一份通用模板。
5. 将核实后的文本纳入两个发布包。当前文档**没有**声称此项已经完成。

未安装新的 Rust 工具链、未重建或重启活动 GUI。本次网络取证不足以完成原生全量核对，不引入未验证的自动许可证生成器。

### 品牌图稿的授权来源

`assets/images/pi_logo.svg`、`pi_logo_dark.svg` 与派生 `windows/runner/resources/app_icon.ico` 已确认是现有项目资源，但没有可核实的作者、原始来源或授权记录。需要图稿提供者确认。项目原创代码现已按维护者授权采用 MIT，但这不覆盖尚未确认来源的品牌图稿，也不替代第三方许可核对。

### highlight 的上游语法来源

已核实 `highlight 0.7.0` 包内 MIT 文本，但该包的 `test/highlight_test.dart` 引用了 `../vendor/highlight.js/test`。这只是进一步核对来源的线索，不足以判定具体移植版本或许可证。需要找到生成源码对应上游版本，核实语法来源并补充必要版权与许可文本；不能把从任意版本下载的 highlight.js LICENSE 当成已经对上版本的证据。

## 维护入口

| 路径 | 职责 |
| --- | --- |
| `LICENSE` | 项目原创代码的 MIT 原文，版权署名为 2026 saltysalrua，随两平台发布包分发 |
| `THIRD_PARTY_NOTICES.md` | 用户可读声明、104 项依赖索引、来源边界及明确的未完成项 |
| `pubspec.yaml` / `pubspec.lock` | 直接依赖、锁定解析树与资源声明 |
| `.dart_tool/package_config.json` | 找到本次解析后的实际包目录；只读取，不修改 Pub 缓存许可 |
| `licenses/MaterialIcons-LICENSE.txt` | 当前 SDK 的字体许可原文副本 |
| `assets/fonts/MiSans/LICENSE.pdf` | MiSans 官方原文 |
| `tool/ci_release.py` | `SHARED_FILES` 收录项目 MIT 原文、第三方声明与字体/图标许可；`flutter_notices` 校验并解压本平台生成的许可汇总 |
| `tool/test_ci_release.py` | 许可文件缺失、坏压缩数据、非法/空文本、原文保留及两种发布包回归 |

没有 Widget / Controller / Service 或 Pi RPC 命令、事件变更。`.github/workflows/release.yml` 无需额外装包或联网核对许可证，仍由已有打包步骤加入原文。

## 升级后的检查步骤

1. `flutter pub get --enforce-lockfile` 后按实际锁定包读取原文，更新声明中的版本和许可；不能只查 pub.dev 最新版。
2. 更新 Flutter 后比对 SDK 的图标原文与 `licenses/MaterialIcons-LICENSE.txt`，并保留当前平台的新引擎汇总。
3. 升级原生插件或调整构建功能时，重新核对原生库与 Cargo 锁文件；不能仅更新 Pub 表格。
4. 新增字体、图标、复制代码或素材时记录作者、来源、修改情况和许可副本；无法证实则明确列为未完成。
5. 运行轻量打包回归：

   ```bash
   python -m unittest discover -s tool -p 'test_ci_release.py' -v
   ```

6. 检查打包输出同时含项目 `LICENSE`、第三方声明、MiSans PDF、Material Icons 原文、`NOTICES.Z` 和对应的可读文本。现有 Release 不会被本地文档修改追溯补全，需要另行发新版本。

参考：[第三方声明](../THIRD_PARTY_NOTICES.md)、[发布流程](github_release.md)、[品牌资源](branding.md)。
