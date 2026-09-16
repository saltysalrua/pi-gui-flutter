import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pi_gui/core/models/commit_graph.dart';
import 'package:pi_gui/core/rpc/pi_browser_types.dart';
import 'package:pi_gui/core/slots/slot_manager.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_activity_label.dart';
import 'package:pi_gui/ui/atoms/app_graph_track.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_icon_tabs.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/atoms/app_tree_tile.dart';
import 'package:pi_gui/ui/atoms/slot_container.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

import '../browser_labels.dart';
import '../controllers/workspace_browser_controller.dart';

/// Transparent content only. AppSplitPanel owns the single sidebar tint.
class WorkspaceBrowserPanel extends StatefulWidget {
  const WorkspaceBrowserPanel({
    super.key,
    required this.controller,
    required this.onOpenFile,
    required this.onOpenCommit,
  });
  final WorkspaceBrowserController controller;
  final ValueChanged<String> onOpenFile, onOpenCommit;
  @override
  State<WorkspaceBrowserPanel> createState() => _WorkspaceBrowserPanelState();
}

class _WorkspaceBrowserPanelState extends State<WorkspaceBrowserPanel> {
  PiGitGraph? _lastGraph;
  CommitGraphLayout? _layout;
  WorkspaceBrowserController get controller => widget.controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final files = controller.tab == WorkspaceBrowserTab.files;
      final root = controller.directories[''];
      final workspace = controller.workspace;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                AppIconTabs<WorkspaceBrowserTab>(
                  tabs: [
                    AppIconTab(
                      WorkspaceBrowserTab.files,
                      Icons.file_copy_outlined,
                      l10n.browserFiles,
                    ),
                    AppIconTab(
                      WorkspaceBrowserTab.graph,
                      Icons.account_tree_outlined,
                      l10n.browserGraph,
                    ),
                  ],
                  selected: controller.tab,
                  onSelected: controller.selectTab,
                ),
                const Spacer(),
                if (files)
                  AppIconButton.subtle(
                    icon: Icons.unfold_less,
                    tooltip: l10n.browserCollapse,
                    onPressed: controller.expanded.isEmpty
                        ? null
                        : controller.collapseAll,
                  ),
                AppIconButton.subtle(
                  icon: Icons.refresh,
                  tooltip: l10n.browserRefresh,
                  onPressed: workspace == null || controller.refreshing
                      ? null
                      : controller.refresh,
                ),
                AppIconButton.subtle(
                  icon: Icons.close,
                  tooltip: l10n.close,
                  onPressed: controller.toggle,
                ),
              ],
            ),
          ),
          SizedBox(
            height: AppSpacing.xxs,
            child: controller.refreshing
                ? const LinearProgressIndicator()
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  files ? Icons.folder_outlined : Icons.account_tree_outlined,
                  size: 15,
                  color: context.colors.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Tooltip(
                    message: workspace ?? l10n.workspaceLoading,
                    child: Text(
                      files
                          ? workspace?.replaceAll('\\', '/').split('/').last ??
                                l10n.browserFiles
                          : controller.graph?.branch ??
                                root?.branch ??
                                l10n.browserGraph,
                      style: context.textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Tooltip(
                  message: files
                      ? l10n.browserFileScope
                      : l10n.browserGraphScope,
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppDurations.quick,
              child: KeyedSubtree(
                key: ValueKey(controller.tab),
                child: files ? _files(context) : _graph(context),
              ),
            ),
          ),
          const SlotContainer(slotId: ExtensibleSlotId.sidebarPanel),
        ],
      );
    },
  );

  Widget _note(BuildContext context, String text, {VoidCallback? retry}) =>
      Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            if (retry != null)
              AppActionButton.subtle(
                label: context.l10n.browserRetry,
                onPressed: retry,
              ),
          ],
        ),
      );
  Widget _loading(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: AppActivityLabel(text: context.l10n.browserLoading, active: true),
  );

  Iterable<_TreeItem> _tree(String folder, int depth) sync* {
    final listing = controller.directories[folder];
    if (controller.directoryErrors.containsKey(folder)) {
      yield _TreeItem(folder, depth, kind: _TreeKind.error);
    }
    if (listing == null) {
      if (controller.loadingDirectory(folder)) {
        yield _TreeItem(folder, depth, kind: _TreeKind.loading);
      }
      return;
    }
    if (listing.entries.isEmpty) {
      yield _TreeItem(folder, depth, kind: _TreeKind.empty);
    }
    for (final entry in listing.entries) {
      yield _TreeItem(folder, depth, entry: entry);
      if (entry.directory && controller.expanded.contains(entry.path)) {
        yield* _tree(entry.path, depth + 1);
      }
    }
    if (listing.hasMore) yield _TreeItem(folder, depth, kind: _TreeKind.more);
  }

  Widget _files(BuildContext context) {
    if (controller.workspace == null) return _loading(context);
    final root = controller.directories[''];
    final items = _tree('', 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (root?.gitWarning case final code?)
          _note(context, browserError(context, code)),
        if (root != null && !root.git && root.gitWarning == null)
          _note(context, context.l10n.browserNoGit),
        Expanded(
          child: ListView.builder(
            key: PageStorageKey('workspace-files-${controller.workspace}'),
            primary: false,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index], entry = items[index].entry;
              if (entry == null) {
                return switch (item.kind) {
                  _TreeKind.error => _note(
                    context,
                    browserError(
                      context,
                      controller.directoryErrors[item.folder]!,
                    ),
                    retry: () =>
                        controller.loadDirectory(item.folder, force: true),
                  ),
                  _TreeKind.loading => _loading(context),
                  _TreeKind.more =>
                    controller.directoryLimit(item.folder) >= 5000
                        ? _note(context, context.l10n.browserLimit)
                        : AppActionButton.subtle(
                            label: context.l10n.browserMore,
                            isLoading: controller.loadingDirectory(item.folder),
                            onPressed: () => controller.loadDirectory(
                              item.folder,
                              more: true,
                            ),
                          ),
                  _ => Padding(
                    padding: EdgeInsetsDirectional.only(
                      start:
                          AppSpacing.xxxl +
                          item.depth.clamp(0, 12) * AppSpacing.md,
                      top: AppSpacing.xs,
                      bottom: AppSpacing.xs,
                    ),
                    child: Text(
                      context.l10n.browserEmptyFolder,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                  ),
                };
              }
              final expanded = entry.directory
                  ? controller.expanded.contains(entry.path)
                  : null;
              final statusText = [
                fileStatusLabel(context, entry.status),
                if (entry.indexStatus.trim().isNotEmpty ||
                    entry.worktreeStatus.trim().isNotEmpty) ...[
                  context.l10n.browserIndexStatus(
                    gitCodeLabel(context, entry.indexStatus),
                  ),
                  context.l10n.browserWorktreeStatus(
                    gitCodeLabel(context, entry.worktreeStatus),
                  ),
                ],
                if (entry.symlink) context.l10n.browserSymlink,
              ].join('\n');
              return Tooltip(
                message: '${entry.path}\n$statusText',
                child: AppTreeTile(
                  key: ValueKey(entry.path),
                  title: entry.name,
                  depth: item.depth,
                  icon: entry.symlink
                      ? Icons.link
                      : entry.directory
                      ? expanded!
                            ? Icons.folder_open_outlined
                            : Icons.folder_outlined
                      : Icons.insert_drive_file_outlined,
                  expanded: expanded,
                  loading: controller.loadingDirectory(entry.path),
                  selected: controller.selectedPath == entry.path,
                  color: entry.status == PiFileStatus.clean
                      ? context.colors.textPrimary
                      : fileStatusColor(context, entry.status),
                  trailing: Semantics(
                    label: statusText,
                    child: _status(context, entry),
                  ),
                  onTap: () => entry.directory
                      ? controller.toggleDirectory(entry.path)
                      : widget.onOpenFile(entry.path),
                  onExpand: expanded == false
                      ? () => controller.toggleDirectory(entry.path)
                      : null,
                  onCollapse: expanded == true
                      ? () => controller.toggleDirectory(entry.path)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _status(BuildContext context, PiFileEntry entry) {
    final color = fileStatusColor(context, entry.status);
    if (entry.status == PiFileStatus.clean) {
      return Icon(Icons.check, size: 12, color: context.colors.textMuted);
    }
    final raw = '${entry.indexStatus}${entry.worktreeStatus}'.trim();
    final marker = switch (entry.status) {
      PiFileStatus.ignored => '−',
      PiFileStatus.none => '·',
      PiFileStatus.untracked => '?',
      _ =>
        raw.isNotEmpty
            ? raw
            : switch (entry.status) {
                PiFileStatus.modified => 'M',
                PiFileStatus.staged => 'S',
                PiFileStatus.added => 'A',
                PiFileStatus.deleted => 'D',
                PiFileStatus.renamed => 'R',
                PiFileStatus.conflict => 'U',
                _ => '',
              },
    };
    return Text(
      marker,
      style: context.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _graph(BuildContext context) {
    final graph = controller.graph;
    if (graph == null) {
      if (controller.graphError case final code?) {
        return SingleChildScrollView(
          child: _note(
            context,
            browserError(context, code),
            retry: code == 'NOT_GIT' ? null : controller.refresh,
          ),
        );
      }
      return _loading(context);
    }
    if (!identical(graph, _lastGraph)) {
      _lastGraph = graph;
      _layout = CommitGraphLayout(
        graph.commits.map(
          (commit) => CommitGraphNode(commit.hash, commit.parents),
        ),
      );
    }
    if (graph.commits.isEmpty) {
      return _note(context, context.l10n.browserNoCommits);
    }
    final layout = _layout!;
    final formatter = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Column(
      children: [
        if (controller.graphError case final code?)
          _note(
            context,
            browserError(context, code),
            retry: controller.refresh,
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              primary: false,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(
                  constraints.maxWidth,
                  (layout.columns + 1) * AppGraphTrack.laneWidth + 210,
                ),
                child: ListView.builder(
                  key: PageStorageKey(
                    'workspace-graph-${controller.workspace}',
                  ),
                  primary: false,
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  itemCount: graph.commits.length + (graph.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == graph.commits.length) {
                      return controller.graphLimit >= 1000
                          ? _note(context, context.l10n.browserLimit)
                          : AppActionButton.subtle(
                              label: context.l10n.browserMore,
                              isLoading: controller.graphLoading,
                              onPressed: () => controller.loadGraph(more: true),
                            );
                    }
                    final commit = graph.commits[index];
                    final refs = commit.refs.map(shortRef).join(', ');
                    final date = formatter.format(commit.date.toLocal());
                    final head = commit.hash == graph.head;
                    return Tooltip(
                      message: [
                        commit.subject,
                        commit.hash,
                        '${commit.author} · $date',
                        ...commit.refs,
                        if (head) context.l10n.worktreeHead,
                      ].join('\n'),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppGraphTrack(
                              row: layout.rows[index],
                              columns: layout.columns,
                              highlighted: head,
                            ),
                            Expanded(
                              child: AppNavTile(
                                title: commit.subject,
                                subtitle: [
                                  if (refs.isNotEmpty) refs else commit.author,
                                  commit.shortHash,
                                  date,
                                ].join(' · '),
                                isSelected:
                                    controller.selectedCommit == commit.hash,
                                foregroundColor: head
                                    ? context.colors.primary
                                    : null,
                                onTap: () => widget.onOpenCommit(commit.hash),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _TreeKind { entry, empty, error, loading, more }

class _TreeItem {
  const _TreeItem(
    this.folder,
    this.depth, {
    this.entry,
    this.kind = _TreeKind.entry,
  });
  final String folder;
  final int depth;
  final PiFileEntry? entry;
  final _TreeKind kind;
}
