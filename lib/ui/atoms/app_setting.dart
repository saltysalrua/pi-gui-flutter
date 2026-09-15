import 'package:flutter/material.dart';
import 'app_card.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';

/// Shared settings section and responsive label/control row. No business data.
class AppSettingsGroup extends StatelessWidget {
  const AppSettingsGroup({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });
  final String title;
  final String? description;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: context.textTheme.titleMedium),
      if (description != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(description!, style: context.textTheme.bodySmall),
      ],
      const SizedBox(height: AppSpacing.md),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        borderRadius: AppRadius.xl,
        child: AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppDurations.fast,
          curve: AppCurves.smoothOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(),
                children[i],
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class AppSettingRow extends StatelessWidget {
  const AppSettingRow({
    super.key,
    required this.title,
    this.description,
    required this.control,
  });
  final String title;
  final String? description;
  final Widget control;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.textTheme.bodyLarge),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(description!, style: context.textTheme.bodySmall),
            ],
          ],
        );
        final narrow =
            constraints.maxWidth < 520 ||
            MediaQuery.textScalerOf(
                  context,
                ).scale(context.textTheme.bodyMedium!.fontSize!) >
                20;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label,
              const SizedBox(height: AppSpacing.md),
              Align(alignment: Alignment.centerLeft, child: control),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: AppSpacing.xxl),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: control,
            ),
          ],
        );
      },
    ),
  );
}
