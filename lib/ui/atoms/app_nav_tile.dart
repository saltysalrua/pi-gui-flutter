import 'package:flutter/material.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

/// 导航/选择条目：支持双行说明、键盘激活、Focus、Hover 与 Disabled。
class AppNavTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool isSelected;
  final bool isFolder;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double height;
  final Color? foregroundColor;

  const AppNavTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.isSelected = false,
    this.isFolder = false,
    this.onTap,
    this.padding,
    this.height = 32.0,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final textColor = onTap == null
        ? colors.textMuted
        : foregroundColor != null
        ? foregroundColor!
        : isSelected
        ? colors.primary
        : isFolder
        ? colors.textSecondary
        : colors.textPrimary;
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected
            ? colors.hoverBackground
            : colors.cardBackground.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          hoverColor: colors.hoverBackground,
          focusColor: colors.primaryTint,
          splashColor: colors.primaryTint,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding:
                  padding ??
                  const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    IconTheme(
                      data: IconThemeData(size: 16, color: textColor),
                      child: leading!,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
