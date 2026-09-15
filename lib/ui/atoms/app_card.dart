import 'package:flutter/material.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

/// 统一卡片容器 (AppCard)
///
/// 遵循全局 AppRadius、AppSpacing 与语义边框/背景规范。
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  /// Per-corner radii, when supplied, take precedence over [borderRadius].
  final BorderRadiusGeometry? borderRadiusGeometry;
  final bool showBorder;
  final Clip clipBehavior;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppRadius.lg,
    this.borderRadiusGeometry,
    this.showBorder = true,
    this.clipBehavior = Clip.none,
    this.backgroundColor,
    this.borderColor,
    this.shadows,
    this.width,
    this.height,
  });

  /// 居中悬浮输入大卡片
  const AppCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppRadius.xl,
    this.borderRadiusGeometry,
    this.showBorder = true,
    this.clipBehavior = Clip.none,
    this.backgroundColor,
    this.borderColor,
    this.shadows,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveBg = backgroundColor ?? colors.cardBackground;
    final effectiveBorder = borderColor ?? colors.borderDefault;

    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius:
            borderRadiusGeometry ?? BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(color: effectiveBorder, width: 1.0)
            : null,
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}
