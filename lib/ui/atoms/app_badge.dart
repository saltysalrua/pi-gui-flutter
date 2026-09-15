import 'package:flutter/material.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';


/// 徽章变体类型
enum AppBadgeVariant {
  /// 中性低对比度 (如相对时间 "3m")
  neutral,

  /// 强调主色徽章 (如激活状态)
  primary,

  /// 成功状态徽章 (如 Local 就绪)
  success,

  /// 边框徽章 (如模型药丸)
  outline,
}

/// 全局标准原子徽章组件 (AppBadge)
class AppBadge extends StatelessWidget {
  final String label;
  final Widget? leading;
  final Widget? trailing;
  final AppBadgeVariant variant;
  final VoidCallback? onTap;

  const AppBadge({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    this.variant = AppBadgeVariant.neutral,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    Color backgroundColor;
    Color textColor;
    Border? border;

    switch (variant) {
      case AppBadgeVariant.neutral:
        backgroundColor = Colors.transparent;
        textColor = colors.textMuted;
        border = null;
        break;

      case AppBadgeVariant.primary:
        backgroundColor = colors.primaryTint;
        textColor = colors.primary;
        border = null;
        break;

      case AppBadgeVariant.success:
        backgroundColor = colors.success.withValues(alpha: 0.12);
        textColor = colors.success;
        border = null;
        break;

      case AppBadgeVariant.outline:
        backgroundColor = Colors.transparent;
        textColor = colors.textSecondary;
        border = Border.all(color: colors.borderDefault);
        break;
    }

    Widget content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            IconTheme(
              data: IconThemeData(size: 12, color: textColor),
              child: leading!,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            IconTheme(
              data: IconThemeData(size: 12, color: textColor),
              child: trailing!,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return content;
  }
}
