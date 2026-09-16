import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pi_gui/core/rpc/pi_browser_types.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_activity_label.dart';
import 'package:pi_gui/ui/atoms/app_code_block.dart';
import 'package:pi_gui/ui/atoms/app_copy_button.dart';
import 'package:pi_gui/ui/atoms/app_diff_view.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_icon_tabs.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

import '../browser_labels.dart';
import '../controllers/workspace_browser_controller.dart';
import '../controllers/workspace_tabs_controller.dart';

/// A non-modal, read-only document body. The tab host preserves this State
/// across selection and group moves; closing it releases the preview snapshot.
class WorkspaceDocumentView extends StatefulWidget {
  const WorkspaceDocumentView({
    super.key,
    required this.document,
    required this.tabs,
    this.onOpenFile,
  });
  final WorkspaceDocument document;
  final WorkspaceTabsController tabs;
  final void Function(String path, {String? commit})? onOpenFile;
  @override
  State<WorkspaceDocumentView> createState() => _WorkspaceDocumentViewState();
}

class _WorkspaceDocumentViewState extends State<WorkspaceDocumentView> {
  late Future<Object> _future = _load();
  bool? _showDiff;
  WorkspaceBrowserController get browser => widget.tabs.browser;
  Future<Object> _load() => widget.document.kind == WorkspaceDocumentKind.commit
      ? browser.details(widget.document.commit!)
      : browser.preview(widget.document.path!, commit: widget.document.commit);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<Object>(
    future: _future,
    builder: (context, snapshot) {
      final doc = widget.document;
      final busy = snapshot.connectionState != ConnectionState.done;
      final file = snapshot.data is PiFilePreview
          ? snapshot.data as PiFilePreview
          : null;
      final diff =
          _showDiff ?? (doc.commit != null || (file?.hasDiff ?? false));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (doc.kind == WorkspaceDocumentKind.file &&
                    doc.commit == null) ...[
                  AppIconTabs<bool>(
                    tabs: [
                      AppIconTab(
                        false,
                        Icons.description_outlined,
                        context.l10n.browserContent,
                      ),
                      AppIconTab(
                        true,
                        Icons.difference_outlined,
                        context.l10n.chatDiff,
                      ),
                    ],
                    selected: diff,
                    onSelected: (value) => setState(() => _showDiff = value),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Tooltip(
                    message: [
                      if (doc.path != null) doc.path!,
                      if (doc.commit != null) doc.commit!,
                    ].join('\n'),
                    child: Text(
                      doc.path ?? context.l10n.browserCommitDetails,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelMedium,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: context.l10n.tabsReadOnly,
                  child: Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: context.colors.textMuted,
                  ),
                ),
                AppIconButton.subtle(
                  icon: Icons.refresh,
                  tooltip: context.l10n.tabsRefresh,
                  onPressed: busy ? null : _reload,
                ),
              ],
            ),
          ),
          SizedBox(
            height: AppSpacing.xxs,
            child: busy && snapshot.hasData
                ? const LinearProgressIndicator()
                : null,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (doc.workspace != browser.workspace) {
                  return _note(context, context.l10n.browserWorkspaceChanged);
                }
                if (snapshot.hasError) {
                  return SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          browserError(
                            context,
                            WorkspaceBrowserController.errorCode(
                              snapshot.error!,
                            ),
                          ),
                          style: context.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppActionButton.subtle(
                          label: context.l10n.browserRetry,
                          onPressed: _reload,
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: AppActivityLabel(
                        text: context.l10n.browserLoading,
                        active: true,
                      ),
                    ),
                  );
                }
                if (snapshot.data case final PiCommitDetails details) {
                  return _commit(context, details);
                }
                if (file == null) return const SizedBox.shrink();
                final maxHeight = math.max(
                  80.0,
                  constraints.maxHeight - AppSpacing.xxxl * 2,
                );
                // Preserve the independent Content / Diff scroll offsets as well.
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Offstage(
                        offstage: diff,
                        child: SingleChildScrollView(
                          key: const PageStorageKey('content'),
                          primary: false,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: _content(context, file, maxHeight),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Offstage(
                        offstage: !diff,
                        child: SingleChildScrollView(
                          key: const PageStorageKey('diff'),
                          primary: false,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (file.stagedDiff.isNotEmpty)
                                _diff(
                                  context,
                                  file.stagedDiff,
                                  context.l10n.browserStaged,
                                  maxHeight,
                                ),
                              if (file.workingDiff.isNotEmpty)
                                _diff(
                                  context,
                                  file.workingDiff,
                                  context.l10n.browserUnstaged,
                                  maxHeight,
                                ),
                              if (file.commitDiff.isNotEmpty)
                                _diff(
                                  context,
                                  file.commitDiff,
                                  context.l10n.browserCommitDiff,
                                  maxHeight,
                                ),
                              if (file.diffLimited)
                                Text(
                                  context.l10n.browserLimit,
                                  style: context.textTheme.bodySmall,
                                ),
                              if (!file.hasDiff)
                                Text(
                                  context.l10n.chatNoChanges,
                                  style: context.textTheme.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    },
  );

  Widget _note(BuildContext context, String text) => SingleChildScrollView(
    primary: false,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Text(text, style: context.textTheme.bodyMedium),
  );

  Widget _content(BuildContext context, PiFilePreview data, double maxHeight) {
    if (data.content case final text?) {
      return text.isEmpty
          ? Text(context.l10n.chatEmptyFile)
          : AppCodeBlock(
              code: text,
              label: widget.document.path,
              framed: false,
              maxHeight: maxHeight,
              language: widget.document.path!.split('.').last,
            );
    }
    return Text(switch (data.kind) {
      PiPreviewKind.binary => context.l10n.browserBinary,
      PiPreviewKind.tooLarge => context.l10n.browserLargeFile,
      PiPreviewKind.missing => context.l10n.browserMissingFile,
      PiPreviewKind.symlink => context.l10n.browserSymlink,
      _ => context.l10n.browserUnsupported,
    }, style: context.textTheme.bodyMedium);
  }

  Widget _diff(
    BuildContext context,
    String source,
    String label,
    double maxHeight,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    // Preserve metadata for binary, permission-only and rename-only changes.
    child: source.contains(RegExp(r'^@@ ', multiLine: true))
        ? AppDiffView(
            source: source,
            label: label,
            framed: false,
            maxHeight: maxHeight,
          )
        : AppCodeBlock(
            code: source,
            label: label,
            framed: false,
            maxHeight: maxHeight,
          ),
  );

  Widget _commit(
    BuildContext context,
    PiCommitDetails data,
  ) => SingleChildScrollView(
    primary: false,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SelectableText(
                data.hash,
                style: context.textTheme.bodySmall,
              ),
            ),
            AppCopyButton(text: data.hash),
          ],
        ),
        Text(
          '${data.author} · ${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(data.date.toLocal())}',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SelectableText(data.message, style: context.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.l10n.browserCommitDiff,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (data.files.isEmpty)
          Text(
            context.l10n.browserCommitFilesEmpty,
            style: context.textTheme.bodySmall,
          ),
        for (final file in data.files)
          Tooltip(
            message: [
              file.path,
              if (file.original != null) file.original!,
              gitCodeLabel(context, file.status),
            ].join('\n'),
            child: AppNavTile(
              title: file.path,
              subtitle: file.original,
              leading: const Icon(Icons.description_outlined),
              trailing: Text(file.status, style: context.textTheme.labelSmall),
              onTap: () => (widget.onOpenFile ?? widget.tabs.openFile)(
                file.path,
                commit: data.hash,
              ),
            ),
          ),
        if (data.limited)
          Text(context.l10n.browserLimit, style: context.textTheme.bodySmall),
      ],
    ),
  );
}
