import 'package:flutter/material.dart';
import 'app_colors_extension.dart';

/// 便捷扩展：通过 [BuildContext] 快捷获取语义色彩与文本样式令牌
extension ThemeContextExtensions on BuildContext {
  /// 当前主题的语义调色板
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>() ?? AppColorsExtension.light;

  /// 当前主题的排版层级
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// 是否为暗色模式
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
