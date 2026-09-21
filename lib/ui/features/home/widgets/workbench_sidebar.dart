import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pi_gui/core/rpc/pi_catalog_types.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_menu_button.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/atoms/app_scroll_edge_fade.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/atoms/app_tree_tile.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

import '../controllers/workbench_controller.dart';
import '../workspace_labels.dart';
import 'quota_sidebar_button.dart';

enum _ProjectAction { forget }

class WorkbenchSidebar extends StatefulWidget {
  const WorkbenchSidebar({
    super.key,
    required this.controller,
    required this.onAddProject,
    required this.onCreateWorktree,
    required this.onRemoveWorktree,
    required this.onForgetProject,
    required this.onCloseSession,
    required this.onSettings,
    required this.onQuota,
  });
  final WorkbenchController controller;
  final VoidCallback onAddProject, onSettings, onQuota;
  final ValueChanged<PiCatalogProject> onCreateWorktree, onForgetProject;
  final void Function(PiCatalogProject project, PiCatalogWorktree worktree)
  onRemoveWorktree;
  final ValueChanged<WorkbenchSession> onCloseSession;
  @override
  State<WorkbenchSidebar> createState() => _WorkbenchSidebarState();
}

class _WorkbenchSidebarState extends State<WorkbenchSidebar> {
  final _search = TextEditingController();
  String _query = '';
  WorkbenchController get controller => widget.controller;
  bool _matches(String text) => text.toLowerCase().contains(_query);
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _session(WorkbenchSession session) {
    final l10n = context.l10n;
    final waiting = session.extensions.needsAttention;
    final status = waiting
        ? l10n.workbenchWaiting
        : session.chat.isRunning
        ? l10n.workbenchRunning
        : session.unread
        ? l10n.workbenchUnread
        : l10n.chatReady;
    final title = session.chat.title.isEmpty
        ? l10n.newConversation
        : session.chat.title;
    return Tooltip(
      message: '$title\n$status\n${session.workspace}',
      child: AppTreeTile(
        title: title,
        depth: 2,
        selected: controller.tabs.selected.sessionId == session.id,
        color: waiting ? context.colors.warning : null,
        icon: waiting
            ? Icons.notifications_active_outlined
            : session.chat.isRunning
            ? Icons.timelapse
            : session.unread
            ? Icons.mark_chat_unread_outlined
            : Icons.chat_bubble_outline,
        trailing: AppIconButton.subtle(
          icon: Icons.close,
          size: 22,
          tooltip: l10n.workbenchCloseSession,
          onPressed: () => widget.onCloseSession(session),
        ),
        onTap: () => controller.tabs.activate(session.document),
      ),
    );
  }

  List<Widget> _worktree(PiCatalogProject project, PiCatalogWorktree worktree) {
    final l10n = context.l10n;
    final live = controller.sessionsFor(worktree.path);
    final openedPaths = live
        .map((s) => s.chat.sessionFile ?? s.historyPath)
        .toSet();
    final history = (controller.history[worktree.path] ?? [])
        .where((s) => !openedPaths.contains(s.path))
        .toList();
    final matchAll =
        _query.isEmpty ||
        _matches('${project.name} ${worktree.name} ${worktree.branch ?? ''}');
    final matchingLive = live
        .where((s) => matchAll || _matches(s.chat.title))
        .toList();
    final matchingHistory = history
        .where((s) => matchAll || _matches(s.title))
        .toList();
    if (!matchAll && matchingLive.isEmpty && matchingHistory.isEmpty) return [];
    final expanded =
        _query.isNotEmpty ||
        controller.expandedWorktrees.contains(worktree.path);
    return [
      Tooltip(
        message: '${worktree.branch ?? worktree.name}\n${worktree.path}',
        child: AppTreeTile(
          title: worktree.name,
          depth: 1,
          expanded: expanded,
          icon: worktree.folder
              ? Icons.folder_outlined
              : Icons.account_tree_outlined,
          color: worktree.unavailable ? context.colors.textMuted : null,
          onExpand: () {
            if (!expanded) controller.toggleWorktree(worktree.path);
          },
          onCollapse: () {
            if (expanded) controller.toggleWorktree(worktree.path);
          },
          onTap: () => controller.toggleWorktree(worktree.path),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (worktree.main)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    l10n.workbenchMain,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              AppIconButton.subtle(
                icon: Icons.add,
                size: 24,
                tooltip: l10n.newConversation,
                onPressed: worktree.unavailable || controller.opening
                    ? null
                    : () => controller.openSession(worktree.path),
              ),
              if (!worktree.main && !worktree.folder)
                AppMenuButton<String>(
                  icon: Icons.more_horiz,
                  tooltip: l10n.worktreeManage,
                  options: [
                    AppMenuOption(
                      value: 'remove',
                      label: l10n.worktreeRemove,
                      icon: Icons.delete_outline,
                    ),
                  ],
                  onSelected: (_) => widget.onRemoveWorktree(project, worktree),
                ),
            ],
          ),
        ),
      ),
      if (expanded) ...[
        for (final session in matchingLive) _session(session),
        if (matchingHistory.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.xl,
              top: AppSpacing.xs,
            ),
            child: Text(
              l10n.workbenchHistory,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
        for (final session in matchingHistory)
          Tooltip(
            message:
                '${session.title}\n${DateFormat.yMd().add_Hm().format(session.modified.toLocal())}',
            child: AppTreeTile(
              title: session.title.isEmpty
                  ? l10n.newConversation
                  : session.title,
              icon: Icons.history,
              depth: 2,
              onTap: controller.opening
                  ? null
                  : () => controller.openSession(
                      worktree.path,
                      sessionPath: session.path,
                    ),
            ),
          ),
        if (controller.loadingHistory.contains(worktree.path))
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.xl),
            child: Text(
              l10n.sessionHistoryLoading,
              style: context.textTheme.labelSmall,
            ),
          ),
        if (controller.historyErrors.contains(worktree.path))
          AppNavTile(
            title: l10n.sessionHistoryFailed,
            leading: const Icon(Icons.refresh),
            onTap: () => controller.loadHistory(worktree.path, force: true),
          ),
        if (live.isEmpty &&
            history.isEmpty &&
            !controller.loadingHistory.contains(worktree.path))
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.xl),
            child: AppActionButton.subtle(
              label: l10n.newConversation,
              leading: const Icon(Icons.add),
              onPressed: worktree.unavailable || controller.opening
                  ? null
                  : () => controller.openSession(worktree.path),
            ),
          ),
      ],
    ];
  }

  Widget _project(PiCatalogProject project) {
    final l10n = context.l10n;
    final children = project.worktrees
        .expand((w) => _worktree(project, w))
        .toList();
    if (_query.isNotEmpty && children.isEmpty) return const SizedBox.shrink();
    final expanded =
        _query.isNotEmpty || controller.expandedProjects.contains(project.path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        AppTreeTile(
          title: project.name,
          icon: Icons.folder_open_outlined,
          expanded: expanded,
          onTap: () => controller.toggleProject(project.path),
          onExpand: () {
            if (!expanded) controller.toggleProject(project.path);
          },
          onCollapse: () {
            if (expanded) controller.toggleProject(project.path);
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (project.git)
                AppIconButton.subtle(
                  icon: Icons.add,
                  size: 24,
                  tooltip: l10n.worktreeCreate,
                  onPressed: project.hasHead
                      ? () => widget.onCreateWorktree(project)
                      : null,
                ),
              AppMenuButton<_ProjectAction>(
                icon: Icons.more_horiz,
                tooltip: project.name,
                options: [
                  AppMenuOption(
                    value: _ProjectAction.forget,
                    label: l10n.workbenchForgetProject,
                    icon: Icons.folder_off_outlined,
                  ),
                ],
                onSelected: (_) => widget.onForgetProject(project),
              ),
            ],
          ),
        ),
        if (expanded) ...[
          ...children,
          for (final job
              in controller.catalog?.jobs.where(
                    (j) => j.project == project.path && j.status != 'done',
                  ) ??
                  <PiWorkspaceJob>[])
            Tooltip(
              message: job.error == null
                  ? job.name
                  : workspaceFailureLabel(l10n, job.error!),
              child: AppNavTile(
                title: job.name,
                subtitle: job.status == 'failed'
                    ? workspaceFailureLabel(l10n, job.error ?? '')
                    : l10n.workbenchCreating,
                leading: Icon(
                  job.status == 'failed'
                      ? Icons.error_outline
                      : Icons.hourglass_top,
                ),
                onTap: () => controller.refresh(),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppTextField(
            controller: _search,
            hintText: l10n.workbenchSearch,
            isCompact: true,
            leading: const Icon(Icons.search),
            onChanged: (text) {
              setState(() => _query = text.trim().toLowerCase());
              if (_query.isNotEmpty) controller.searchHistory();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.projects,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
              ),
              AppIconButton.subtle(
                icon: Icons.refresh,
                tooltip: l10n.workspaceRefresh,
                onPressed: controller.loading
                    ? null
                    : () {
                        controller.refresh();
                        for (final path in controller.expandedWorktrees) {
                          controller.loadHistory(path, force: true);
                        }
                      },
              ),
              AppIconButton.subtle(
                icon: Icons.create_new_folder_outlined,
                tooltip: l10n.workbenchAddProject,
                onPressed: widget.onAddProject,
              ),
            ],
          ),
        ),
        if ((controller.failure ?? controller.catalogFailure) case final code?)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              code == 'OUTCOME_UNKNOWN'
                  ? l10n.workbenchOperationUnknown
                  : workspaceFailureLabel(l10n, code),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.warning,
              ),
            ),
          ),
        if (controller.catalog?.persistenceWarning == true)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              l10n.workspacePersistenceFailed,
              style: context.textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: AppScrollEdgeFade(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                for (final project
                    in controller.catalog?.projects ?? <PiCatalogProject>[])
                  _project(project),
                if (controller.loading && controller.catalog == null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      l10n.workspaceLoading,
                      style: context.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QuotaSidebarButton(onOpenQuota: widget.onQuota),
              const SizedBox(height: AppSpacing.xs),
              AppNavTile(
                title: l10n.settings,
                leading: const Icon(Icons.settings_outlined),
                onTap: widget.onSettings,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
