import 'package:flutter/material.dart';

import '../../../atoms/app_action_button.dart';
import '../../../atoms/app_card.dart';
import '../../../atoms/app_code_block.dart';
import '../../../atoms/app_disclosure.dart';
import '../../../atoms/app_icon_button.dart';
import '../../../atoms/app_markdown.dart';
import '../../../atoms/app_setting.dart';
import '../../../core/chat_resource_scope.dart';
import '../../../core/context_l10n.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_context_extensions.dart';
import '../controllers/pi_update_controller.dart';

/// Settings page "pi": installed version, online update check, changelog.
///
/// All data comes from [PiUpdateController]; this widget only renders states.
class PiSettingsContent extends StatelessWidget {
  const PiSettingsContent({
    super.key,
    required this.controller,
    this.query = '',
  });
  final PiUpdateController controller;
  final String query;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.piPageTitle, style: context.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.piPageSubtitle,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          switch (controller.infoStatus) {
            PiInfoStatus.loading => AppCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l.piLoading,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PiInfoStatus.failed => AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.piLoadFailed, style: context.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  AppActionButton.subtle(
                    label: l.appearanceRetry,
                    leading: const Icon(Icons.refresh),
                    onPressed: controller.load,
                  ),
                ],
              ),
            ),
            PiInfoStatus.ready => _buildBody(context),
          },
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final checking = controller.checkStatus == PiCheckStatus.checking;
    final latestLabel = switch (controller.checkStatus) {
      PiCheckStatus.available => 'v${controller.latestVersion}',
      PiCheckStatus.upToDate => 'v${controller.latestVersion}',
      _ => '—',
    };
    final latestDescription = switch (controller.checkStatus) {
      PiCheckStatus.checking => l.piChecking,
      PiCheckStatus.failed => l.piCheckFailed,
      PiCheckStatus.upToDate => l.piUpToDate,
      PiCheckStatus.available => l.piUpdateAvailable(controller.latestVersion!),
      PiCheckStatus.idle => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSettingsGroup(
          title: l.piUpdates,
          children: [
            AppSettingRow(
              title: l.piCurrentVersion,
              description: controller.installPath,
              control: Text(
                'v${controller.currentVersion}',
                style: context.textTheme.labelLarge,
              ),
            ),
            AppSettingRow(
              title: l.piLatestVersion,
              description: latestDescription,
              control: Text(
                latestLabel,
                style: context.textTheme.labelLarge?.copyWith(
                  color: controller.checkStatus == PiCheckStatus.available
                      ? colors.primary
                      : null,
                  fontWeight: controller.checkStatus == PiCheckStatus.available
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ),
            AppSettingRow(
              title: l.piCheckUpdate,
              description: l.piCheckHint,
              control: AppActionButton.subtle(
                label: controller.checkStatus == PiCheckStatus.failed
                    ? l.appearanceRetry
                    : l.piCheckUpdate,
                leading: const Icon(Icons.refresh),
                isLoading: checking,
                onPressed: controller.checkForUpdate,
              ),
            ),
            AppSettingRow(
              title: l.piRegistryPage,
              description: l.piRegistryPageHint,
              control: AppIconButton.subtle(
                icon: Icons.open_in_new_rounded,
                tooltip: l.piOpenRegistry,
                onPressed: () => ChatResourceScope.open(
                  context,
                  PiUpdateController.registryPage,
                ),
              ),
            ),
          ],
        ),
        if (controller.checkStatus == PiCheckStatus.available) ...[
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.system_update,
                        size: 18,
                        color: colors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l.piUpdateAvailable(controller.latestVersion!),
                          style: context.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l.piUpdateHint,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  if (controller.selfUpdateStatus ==
                      PiSelfUpdateStatus.failed) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l.piUpdateFailedHint,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.warning,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppActionButton(
                    label: controller.isSelfUpdating
                        ? l.piUpdateRunning
                        : l.piUpdateNow,
                    leading: const Icon(Icons.download_rounded),
                    isLoading: controller.isSelfUpdating,
                    onPressed: controller.isSelfUpdating
                        ? null
                        : controller.runSelfUpdate,
                  ),
                  if (controller.selfUpdateLog.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppDisclosure(
                      framed: false,
                      initiallyExpanded: true,
                      title: l.piUpdateOutput,
                      builder: (_) => AppCodeBlock(
                        code: controller.selfUpdateLog
                            .skip(
                              (controller.selfUpdateLog.length - 200).clamp(
                                0,
                                controller.selfUpdateLog.length,
                              ),
                            )
                            .join('\n'),
                        label: 'pi update --self',
                        language: 'bash',
                        framed: false,
                      ),
                    ),
                  ],
                  if (controller.selfUpdateStatus ==
                      PiSelfUpdateStatus.idle) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppDisclosure(
                      framed: false,
                      title: l.piUpdateManualCommand,
                      builder: (_) => AppCodeBlock(
                        code: PiUpdateController.updateCommand,
                        label: 'npm',
                        language: 'bash',
                        framed: false,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxxl),
        _ChangelogSection(controller: controller, query: query),
      ],
    );
  }
}

/// Collapsible changelog entries with search filtering and paging so the
/// full history never builds at once.
class _ChangelogSection extends StatefulWidget {
  const _ChangelogSection({required this.controller, required this.query});
  final PiUpdateController controller;
  final String query;

  @override
  State<_ChangelogSection> createState() => _ChangelogSectionState();
}

class _ChangelogSectionState extends State<_ChangelogSection> {
  static const _pageSize = 30;
  int _visible = _pageSize;

  @override
  void didUpdateWidget(_ChangelogSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) _visible = _pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final filtered = widget.controller.entries
        .where((e) => e.matches(widget.query))
        .toList();
    if (filtered.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.piChangelog, style: context.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Text(l.piChangelogEmpty, style: context.textTheme.bodyMedium),
        ],
      );
    }
    final visible = widget.query.isEmpty ? filtered.take(_visible) : filtered;
    return AppSettingsGroup(
      title: l.piChangelog,
      children: [
        for (final entry in visible)
          AppDisclosure(
            key: ValueKey(entry.version),
            framed: false,
            initiallyExpanded:
                widget.query.isNotEmpty || identical(entry, filtered.first),
            title: entry.version,
            subtitle: entry.date.isEmpty ? null : entry.date,
            trailing: entry.version == widget.controller.currentVersion
                ? Text(
                    l.piCurrentTag,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                    ),
                  )
                : null,
            builder: (_) => AppMarkdown(data: entry.body),
          ),
        if (widget.query.isEmpty && _visible < filtered.length)
          Center(
            child: AppActionButton.subtle(
              label: l.piShowMore,
              leading: const Icon(Icons.expand_more_rounded),
              onPressed: () => setState(() => _visible = _visible + _pageSize),
            ),
          ),
      ],
    );
  }
}
