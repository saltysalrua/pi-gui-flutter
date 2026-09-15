import 'package:flutter/material.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'app_card.dart';
import '../core/theme/theme_context_extensions.dart';

/// Shared modal route: bounded scrolling, focus trap, Escape and motion tokens.
Future<T?> showAppDialog<T>(
  BuildContext context,
  WidgetBuilder builder, {
  Color? barrierColor,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push<T>(
    _AppDialogRoute<T>(
      builder: builder,
      barrierLabel: context.l10n.close,
      barrierColor:
          barrierColor ??
          Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
      reduced: reduced,
    ),
  );
}

class _AppDialogRoute<T> extends RawDialogRoute<T> {
  _AppDialogRoute({
    required WidgetBuilder builder,
    required String barrierLabel,
    required Color barrierColor,
    required this.reduced,
  }) : super(
         barrierLabel: barrierLabel,
         barrierColor: barrierColor,
         transitionDuration: reduced ? Duration.zero : AppDurations.fast,
         pageBuilder: (context, _, _) => SafeArea(child: builder(context)),
         transitionBuilder: (context, animation, _, child) => FadeTransition(
           opacity: animation,
           child: ScaleTransition(
             scale: Tween(begin: AppMotionScales.modal, end: 1.0).animate(
               CurvedAnimation(parent: animation, curve: AppCurves.smoothOut),
             ),
             child: child,
           ),
         ),
       );
  final bool reduced;
  @override
  Duration get reverseTransitionDuration =>
      reduced ? Duration.zero : AppDurations.quick;
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.maxWidth = 520,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 680),
        child: Material(
          type: MaterialType.transparency,
          child: AppCard(
            backgroundColor: context.colors.elevatedBackground,
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  Flexible(child: SingleChildScrollView(child: child)),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
