import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_action_button.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';

class AppSelectOption<T> {
  const AppSelectOption(this.value, this.label);
  final T value;
  final String label;
}

/// Compact labelled selection button, sharing action states and menu motion.
class AppSelect<T> extends StatefulWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.label,
    this.isBusy = false,
  });
  final T value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String label;
  final bool isBusy;
  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  final _menu = GlobalKey<PopupMenuButtonState<T>>();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.textTheme.bodyMedium!;
    final textHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) *
        (style.height ?? 1.4);
    final enabled = widget.onChanged != null && !widget.isBusy;
    return PopupMenuButton<T>(
      key: _menu,
      initialValue: widget.value,
      enabled: enabled,
      tooltip: widget.label,
      onSelected: widget.onChanged,
      position: PopupMenuPosition.under,
      color: colors.elevatedBackground,
      surfaceTintColor: colors.elevatedBackground,
      menuPadding: const EdgeInsets.all(AppSpacing.xs),
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
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
      itemBuilder: (context) => [
        for (final option in widget.options)
          PopupMenuItem<T>(
            value: option.value,
            height: math.max(36, textHeight + AppSpacing.lg),
            child: Row(
              children: [
                Expanded(child: Text(option.label, style: style)),
                if (widget.value == option.value) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.check_rounded, size: 16, color: colors.primary),
                ],
              ],
            ),
          ),
      ],
      child: AppActionButton(
        label:
            widget.options
                .where((o) => o.value == widget.value)
                .firstOrNull
                ?.label ??
            widget.label,
        variant: AppButtonVariant.secondary,
        trailing: const Icon(Icons.expand_more_rounded),
        isLoading: widget.isBusy,
        onPressed: enabled ? () => _menu.currentState?.showButtonMenu() : null,
      ),
    );
  }
}
