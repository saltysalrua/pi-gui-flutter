import 'package:pi_gui/ui/atoms/app_progress_indicator.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';

class AppMenuOption<T> {
  const AppMenuOption({
    required this.value,
    required this.label,
    required this.icon,
  });
  final T value;
  final String label;
  final IconData icon;
}

/// Compact, keyboard-accessible anchored menu; shared button and menu state styling.
class AppMenuButton<T> extends StatelessWidget {
  const AppMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.options,
    required this.onSelected,
    this.isBusy = false,
  });
  final IconData icon;
  final String tooltip;
  final List<AppMenuOption<T>> options;
  final ValueChanged<T>? onSelected;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.textTheme.bodyMedium!;
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) *
        (style.height ?? 1.4);
    return PopupMenuButton<T>(
      tooltip: tooltip,
      enabled: onSelected != null && !isBusy && options.isNotEmpty,
      onSelected: onSelected,
      position: PopupMenuPosition.over,
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
      menuPadding: const EdgeInsets.all(AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.xs),
      color: colors.elevatedBackground,
      surfaceTintColor: colors.elevatedBackground,
      shadowColor: Theme.of(context).colorScheme.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: colors.borderDefault),
      ),
      popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: AppDurations.fast,
              reverseDuration: AppDurations.quick,
              curve: AppCurves.smoothOut,
            ),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(28),
        maximumSize: const Size.square(28),
        padding: const EdgeInsets.all(AppSpacing.xs),
        foregroundColor: colors.textSecondary,
        disabledForegroundColor: colors.textMuted,
        hoverColor: colors.hoverBackground,
        focusColor: colors.primaryTint,
      ),
      icon: isBusy
          ? const SizedBox.square(
              dimension: 16,
              child: AppProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 20),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            height: math.max(36, line + AppSpacing.lg),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Icon(option.icon, size: 18, color: colors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: Text(option.label, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}
