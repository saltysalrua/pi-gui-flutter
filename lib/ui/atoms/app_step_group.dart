import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';

/// A quiet, continuous rail for related steps. Owns no business data or actions.
/// The line follows the actual child heights, including disclosure animations.
class AppStepGroup extends StatelessWidget {
  const AppStepGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [
        PositionedDirectional(
          start: AppSpacing.xs,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
          width: 1,
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: ColoredBox(color: context.colors.borderDefault),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.xs,
            children: children,
          ),
        ),
      ],
    );
  }
}
