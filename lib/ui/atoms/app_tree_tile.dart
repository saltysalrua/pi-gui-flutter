import 'package:pi_gui/ui/atoms/app_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_tokens.dart';
import 'app_nav_tile.dart';

/// Compact tree navigation built on the shared row. Data and expansion stay
/// with the caller; Left/Right collapse/expand and Enter activates the row.
class AppTreeTile extends StatelessWidget {
  const AppTreeTile({
    super.key,
    required this.title,
    required this.icon,
    this.depth = 0,
    this.expanded,
    this.loading = false,
    this.selected = false,
    this.color,
    this.trailing,
    this.onTap,
    this.onExpand,
    this.onCollapse,
  });
  final String title;
  final IconData icon;
  final int depth;
  final bool? expanded;
  final bool loading, selected;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap, onExpand, onCollapse;
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowRight): ?onExpand,
      const SingleActivator(LogicalKeyboardKey.arrowLeft): ?onCollapse,
    },
    child: Semantics(
      expanded: expanded,
      child: AppNavTile(
        title: title,
        height: 28,
        isSelected: selected,
        foregroundColor: color,
        padding: EdgeInsetsDirectional.only(
          start: AppSpacing.xs + depth.clamp(0, 12) * AppSpacing.md,
          end: AppSpacing.sm,
          top: AppSpacing.xxs,
          bottom: AppSpacing.xxs,
        ),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxs),
                      child: AppProgressIndicator(strokeWidth: 1.5),
                    )
                  : expanded == null
                  ? null
                  : AnimatedRotation(
                      turns: expanded! ? 0.25 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : AppDurations.quick,
                      curve: AppCurves.smoothOut,
                      child: const Icon(Icons.chevron_right),
                    ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(icon),
          ],
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    ),
  );
}
