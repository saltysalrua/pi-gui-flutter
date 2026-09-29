// Settings "hooks" page: the GUI's built-in runtime hooks (write-diff
// observer, history bridge) with enable/disable/uninstall/restore controls.
// Backend registry lives in assets/backend/gui_hooks.mjs; see
// docs/builtin_hooks.md.
import 'package:flutter/material.dart';

import '../../../atoms/app_action_button.dart';
import '../../../atoms/app_badge.dart';
import '../../../atoms/app_card.dart';
import '../../../atoms/app_menu_button.dart';
import '../../../atoms/app_progress_indicator.dart';
import '../../../atoms/app_setting.dart';
import '../../../core/context_l10n.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_context_extensions.dart';
import '../../../../core/rpc/pi_hooks_types.dart';
import '../controllers/hooks_controller.dart';

/// Settings page "hooks": lists the GUI's built-in runtime hooks and applies
/// enable/disable/uninstall/restore changes. Pure rendering; all logic lives
/// in [HooksController].
class HooksSettingsContent extends StatelessWidget {
  const HooksSettingsContent({
    super.key,
    required this.controller,
    this.query = '',
  });
  final HooksController controller;
  final String query;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hooks = controller.state?.hooks ?? const <PiHookItem>[];
        final live = hooks
            .where((hook) => hook.state != PiHookState.removed)
            .where(_matches)
            .toList(growable: false);
        final removed = hooks
            .where((hook) => hook.state == PiHookState.removed)
            .where(_matches)
            .toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.hooksPageTitle, style: context.textTheme.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.hooksPageSubtitle,
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            switch (controller.status) {
              HooksStatus.loading => AppCard(
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: AppProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(l.hooksLoading)),
                  ],
                ),
              ),
              HooksStatus.failed => AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.hooksLoadFailed),
                    if (controller.failure != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        controller.failure!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppActionButton.subtle(
                        label: l.hooksRetry,
                        leading: const Icon(Icons.refresh_rounded),
                        onPressed: controller.load,
                      ),
                    ),
                  ],
                ),
              ),
              HooksStatus.ready => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (live.isNotEmpty)
                    AppSettingsGroup(
                      title: l.hooksGroupTitle,
                      description: controller.state?.persistenceWarning == true
                          ? l.hooksPersistenceWarning
                          : null,
                      children: [
                        for (final hook in live)
                          _HookRow(hook: hook, controller: controller),
                      ],
                    ),
                  if (removed.isNotEmpty) ...[
                    if (live.isNotEmpty)
                      const SizedBox(height: AppSpacing.xxxl),
                    AppSettingsGroup(
                      title: l.hooksRemovedGroupTitle,
                      description: l.hooksRemovedGroupDescription,
                      children: [
                        for (final hook in removed)
                          _HookRow(
                            hook: hook,
                            controller: controller,
                            removed: true,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxxl),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.hooksHintTitle),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l.hooksHintBody,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        if (controller.actionError != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l.hooksActionFailed(controller.actionError!),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            },
          ],
        );
      },
    );
  }

  /// Client-side filter against the settings search; matches the localized
  /// name is impossible before l10n resolution, so it matches the stable
  /// id and the bundled file name, never mutating any request.
  bool _matches(PiHookItem hook) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return hook.file.toLowerCase().contains(needle) ||
        hook.id.toLowerCase().contains(needle);
  }
}

/// One hook row: name, description (plus the bundled file), state badge and
/// the state menu. "Removed" hooks render with a restore action instead.
class _HookRow extends StatelessWidget {
  const _HookRow({required this.hook, required this.controller, this.removed = false});
  final PiHookItem hook;
  final HooksController controller;
  final bool removed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pending = controller.isPending(hook.id);
    final (name, description) = switch (hook.id) {
      'tool_diff' => (l.hooksToolDiffName, l.hooksToolDiffDesc),
      'history' => (l.hooksHistoryName, l.hooksHistoryDesc),
      _ => (hook.id, hook.file),
    };
    final (stateLabel, variant) = switch (hook.state) {
      PiHookState.active => (l.hooksStateActive, AppBadgeVariant.success),
      PiHookState.off => (l.hooksStateOff, AppBadgeVariant.neutral),
      PiHookState.removed => (l.hooksStateRemoved, AppBadgeVariant.neutral),
    };
    // The menu only offers transitions, so the current state never appears
    // as an option; restore is a dedicated action on removed rows.
    final options = <AppMenuOption<PiHookState>>[
      if (hook.state != PiHookState.active)
        AppMenuOption(
          value: PiHookState.active,
          label: l.hooksActionEnable,
          icon: Icons.check_circle_outline_outlined,
        ),
      if (hook.state != PiHookState.off)
        AppMenuOption(
          value: PiHookState.off,
          label: l.hooksActionDisable,
          icon: Icons.pause_circle_outline_outlined,
        ),
      if (!removed)
        AppMenuOption(
          value: PiHookState.removed,
          label: l.hooksActionUninstall,
          icon: Icons.delete_outline_outlined,
        ),
    ];
    return AppSettingRow(
      title: name,
      description: '$description\n${hook.file}',
      control: removed
          ? AppActionButton.subtle(
              label: l.hooksActionRestore,
              leading: const Icon(Icons.restore_rounded),
              isLoading: pending,
              onPressed: pending
                  ? null
                  : () => controller.setHook(hook, PiHookState.active),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBadge(label: stateLabel, variant: variant),
                const SizedBox(width: AppSpacing.sm),
                AppMenuButton(
                  icon: Icons.more_vert_rounded,
                  tooltip: l.hooksMenuTooltip,
                  options: options,
                  isBusy: pending,
                  onSelected: (next) => controller.setHook(hook, next),
                ),
              ],
            ),
    );
  }
}