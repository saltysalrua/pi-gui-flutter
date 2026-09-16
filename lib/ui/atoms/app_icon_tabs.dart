import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';
import 'app_icon_button.dart';

class AppIconTab<T> {
  const AppIconTab(this.value, this.icon, this.label);
  final T value;
  final IconData icon;
  final String label;
}

/// Small icon-only tab strip with tooltips, selection semantics and a sliding
/// indicator. Each tab reuses the standard focus/hover/disabled button states.
class AppIconTabs<T> extends StatelessWidget {
  const AppIconTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });
  final List<AppIconTab<T>> tabs;
  final T selected;
  final ValueChanged<T>? onSelected;
  static const _extent = 36.0;
  @override
  Widget build(BuildContext context) {
    final index = tabs.indexWhere((tab) => tab.value == selected);
    return SizedBox(
      width: tabs.length * _extent,
      height: _extent + AppSpacing.xs,
      child: Stack(
        children: [
          Row(
            children: [
              for (final tab in tabs)
                Semantics(
                  selected: tab.value == selected,
                  child: AppIconButton(
                    icon: tab.icon,
                    size: _extent,
                    tooltip: tab.label,
                    color: tab.value == selected
                        ? context.colors.textPrimary
                        : context.colors.textMuted,
                    onPressed: onSelected == null
                        ? null
                        : () => onSelected!(tab.value),
                  ),
                ),
            ],
          ),
          if (index >= 0)
            AnimatedPositioned(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppDurations.fast,
              curve: AppCurves.smoothOut,
              left: index * _extent + AppSpacing.sm,
              bottom: 0,
              width: _extent - AppSpacing.lg,
              height: AppSpacing.xxs,
              child: ColoredBox(color: context.colors.primary),
            ),
        ],
      ),
    );
  }
}
