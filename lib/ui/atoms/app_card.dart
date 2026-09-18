import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pi_gui/core/services/window_material_service.dart';
import 'package:pi_gui/ui/core/window_material_scope.dart';
import 'package:pi_gui/ui/core/theme/app_card_theme.dart';
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

  /// Follow the shared card material. Fully transparent shells always opt out.
  final bool glass;
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
    this.glass = true,
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
    this.glass = true,
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
    final background = backgroundColor ?? colors.cardBackground;
    final material =
        Theme.of(context).extension<AppCardTheme>() ?? const AppCardTheme();
    final active =
        glass &&
        background.a > 0 &&
        material.opacity < 1 &&
        WindowMaterialScope.statusOf(context) == WindowMaterialStatus.active &&
        !MediaQuery.highContrastOf(context);
    final inheritedBlur = AppCardBackdropScope.of(context);
    final blur = active && material.blurSigma > 0 && !inheritedBlur;
    final effectiveBg = active
        ? background.withValues(alpha: background.a * material.opacity)
        : background;
    final effectiveBorder = borderColor ?? colors.borderDefault;
    final radius = borderRadiusGeometry ?? BorderRadius.circular(borderRadius);

    // Keep the child at the same Element path when toggling material or policy:
    // editors, selection, scroll positions and focus must not be recreated.
    // Only the backdrop is clipped/filtered; text and controls stay untouched.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                enabled: blur,
                filter: ImageFilter.blur(
                  sigmaX: material.blurSigma,
                  sigmaY: material.blurSigma,
                ),
                // Replace, rather than composite a second copy of the already
                // translucent desktop tint (also correct inside route fades).
                blendMode: BlendMode.src,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Container(
            width: width,
            height: height,
            padding: padding ?? const EdgeInsets.all(AppSpacing.md),
            clipBehavior: clipBehavior,
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: radius,
              border: showBorder
                  ? Border.all(color: effectiveBorder, width: 1.0)
                  : null,
            ),
            child: AppCardBackdropScope(
              active: inheritedBlur || blur,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nested surfaces keep their tint but do not blur the same background
/// repeatedly. Public so other glass consumers (e.g. AppTextField) can opt
/// out of a second blur when already inside a blurred card.
class AppCardBackdropScope extends InheritedWidget {
  const AppCardBackdropScope({
    super.key,
    required super.child,
    required this.active,
  });
  final bool active;
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppCardBackdropScope>()
          ?.active ??
      false;
  @override
  bool updateShouldNotify(AppCardBackdropScope oldWidget) =>
      active != oldWidget.active;
}
