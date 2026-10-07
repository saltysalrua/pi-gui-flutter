import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pi_gui/core/rpc/pi_catalog_types.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
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

enum _ProjectAction { forget, worktree, manageWorktrees, move }

enum _SectionAction { rename, up, down, delete }

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
  final ValueChanged<String?> onAddProject;
  final VoidCallback onSettings, onQuota;
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
  bool _unassignedCollapsed = false;
  WorkbenchController get controller => widget.controller;
  bool get _organizing =>
      controller.organizing || controller.hasWorkspaceOperation;
  bool _matches(String text) => text.toLowerCase().contains(_query);
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _nameSection([PiCatalogSection? section]) async {
    final name = await showAppDialog<String>(
      context,
      (_) => _SectionNameDialog(section: section),
    );
    if (!mounted || name == null) return;
    if (section == null) {
      await controller.createSection(name);
    } else {
      await controller.updateSection(section.id, name: name);
    }
  }

  Future<void> _sectionAction(
    PiCatalogSection section,
    _SectionAction action,
  ) async {
    switch (action) {
      case _SectionAction.rename:
        await _nameSection(section);
      case _SectionAction.up:
        await controller.updateSection(section.id, direction: 'up');
      case _SectionAction.down:
        await controller.updateSection(section.id, direction: 'down');
      case _SectionAction.delete:
        final confirmed = await showAppDialog<bool>(
          context,
          (context) => AppDialog(
            title: context.l10n.sectionDelete,
            actions: [
              AppActionButton.subtle(
                label: context.l10n.cancel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              AppActionButton(
                label: context.l10n.sectionDelete,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
            child: Text(
              context.l10n.sectionDeleteDescription,
              style: context.textTheme.bodyMedium,
            ),
          ),
        );
        if (mounted && confirmed == true) {
          await controller.deleteSection(section.id);
        }
    }
  }

  Future<void> _moveProject(PiCatalogProject project) async {
    // Empty string represents the built-in, non-persisted unassigned section.
    final target = await showAppDialog<String>(
      context,
      (context) => AppDialog(
        title: context.l10n.sectionMoveProject,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppNavTile(
              title: context.l10n.sectionUnassigned,
              leading: const Icon(Icons.layers_outlined),
              isSelected: project.sectionId == null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            for (final section
                in controller.catalog?.sections ?? <PiCatalogSection>[])
              AppNavTile(
                title: section.name,
                leading: const Icon(Icons.layers_outlined),
                isSelected: project.sectionId == section.id,
                onTap: () => Navigator.of(context).pop(section.id),
              ),
          ],
        ),
      ),
    );
    if (mounted && target != null) {
      await controller.moveProject(
        project.path,
        target.isEmpty ? null : target,
      );
    }
  }

  Widget _session(WorkbenchSession session, int depth) {
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
        depth: depth,
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

  Iterable<Widget> _sessions(String path, int depth, bool matchAll) sync* {
    final l10n = context.l10n;
    final live = controller.sessionsFor(path);
    final opened = live.map((s) => s.chat.sessionFile ?? s.historyPath).toSet();
    for (final session in live) {
      if (matchAll || _matches(session.chat.title)) {
        yield _session(session, depth);
      }
    }
    for (final session in controller.history[path] ?? []) {
      if (opened.contains(session.path) ||
          (!matchAll && !_matches(session.title))) {
        continue;
      }
      yield Tooltip(
        message:
            '${session.title}\n$path\n${DateFormat.yMd().add_Hm().format(session.modified.toLocal())}',
        child: AppTreeTile(
          title: session.title.isEmpty ? l10n.newConversation : session.title,
          icon: Icons.history,
          depth: depth,
          onTap: controller.opening
              ? null
              : () => controller.openSession(path, sessionPath: session.path),
        ),
      );
    }
    if (controller.loadingHistory.contains(path)) {
      yield AppTreeTile(
        title: l10n.sessionHistoryLoading,
        icon: Icons.history,
        depth: depth,
        loading: true,
      );
    }
    if (controller.historyErrors.contains(path)) {
      yield AppTreeTile(
        title: l10n.sessionHistoryFailed,
        icon: Icons.refresh,
        depth: depth,
        onTap: () => controller.loadHistory(path, force: true),
      );
    }
  }

  Future<void> _hideUnassigned() async {
    final confirmed = await showAppDialog<bool>(
      context,
      (context) => AppDialog(
        title: context.l10n.sectionDelete,
        actions: [
          AppActionButton.subtle(
            label: context.l10n.cancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppActionButton(
            label: context.l10n.sectionDelete,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
        child: Text(
          context.l10n.sectionRemoveUnassignedHint,
          style: context.textTheme.bodyMedium,
        ),
      ),
    );
    if (mounted && confirmed == true) await controller.hideUnassigned();
  }

  Future<void> _manageWorktrees(PiCatalogProject project) =>
      showAppDialog<void>(
        context,
        (context) => AppDialog(
          title: context.l10n.worktreeManage,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tree in project.worktrees.where(
                (w) => !w.main && !w.folder,
              ))
                AppNavTile(
                  title: tree.name,
                  subtitle: tree.path,
                  leading: const Icon(Icons.account_tree_outlined),
                  trailing: AppIconButton.subtle(
                    icon: Icons.delete_outline,
                    tooltip: context.l10n.worktreeRemove,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onRemoveWorktree(project, tree);
                    },
                  ),
                  onTap: tree.unavailable || controller.opening
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          controller.selectWorktree(tree.path);
                        },
                ),
            ],
          ),
        ),
      );

  Widget _project(
    PiCatalogProject project,
    bool sectionMatches, {
    int depth = 1,
  }) {
    final l10n = context.l10n;
    final matchAll =
        _query.isEmpty ||
        sectionMatches ||
        _matches('${project.name} ${project.path}');
    final workspaces = controller.workspacesForProject(project).toList();
    final hasMatch = workspaces.any(
      (path) =>
          controller
              .sessionsFor(path)
              .any((session) => _matches(session.chat.title)) ||
          (controller.history[path] ?? []).any(
            (session) => _matches(session.title),
          ),
    );
    if (!matchAll && !hasMatch) return const SizedBox.shrink();
    final expanded =
        _query.isNotEmpty || controller.expandedProjects.contains(project.path);
    final unavailable =
        project.worktrees
            .where((w) => p.equals(w.path, project.path))
            .firstOrNull
            ?.unavailable ==
        true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: project.path,
          child: AppTreeTile(
            title: project.name,
            icon: Icons.folder_open_outlined,
            depth: depth,
            expanded: expanded,
            onTap: () => controller.toggleProject(project.path),
            onExpand: !expanded
                ? () => controller.toggleProject(project.path)
                : null,
            onCollapse: expanded
                ? () => controller.toggleProject(project.path)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconButton.subtle(
                  icon: Icons.add,
                  size: 24,
                  tooltip: l10n.newConversation,
                  onPressed: unavailable || controller.opening
                      ? null
                      : () => controller.openSession(project.path),
                ),
                AppMenuButton<_ProjectAction>(
                  icon: Icons.more_horiz,
                  tooltip: project.name,
                  options: [
                    AppMenuOption(
                      value: _ProjectAction.move,
                      label: l10n.sectionMoveProject,
                      icon: Icons.drive_file_move_outlined,
                    ),
                    if (project.worktrees.any((w) => !w.main && !w.folder))
                      AppMenuOption(
                        value: _ProjectAction.manageWorktrees,
                        label: l10n.worktreeManage,
                        icon: Icons.account_tree_outlined,
                      ),
                    if (project.git && project.hasHead)
                      AppMenuOption(
                        value: _ProjectAction.worktree,
                        label: l10n.worktreeCreate,
                        icon: Icons.account_tree_outlined,
                      ),
                    AppMenuOption(
                      value: _ProjectAction.forget,
                      label: l10n.workbenchForgetProject,
                      icon: Icons.folder_off_outlined,
                    ),
                  ],
                  onSelected: _organizing
                      ? null
                      : (action) {
                          switch (action) {
                            case _ProjectAction.move:
                              _moveProject(project);
                            case _ProjectAction.manageWorktrees:
                              _manageWorktrees(project);
                            case _ProjectAction.worktree:
                              widget.onCreateWorktree(project);
                            case _ProjectAction.forget:
                              widget.onForgetProject(project);
                          }
                        },
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          for (final path in workspaces)
            ..._sessions(path, depth + 1, matchAll),
          for (final job
              in controller.catalog?.jobs.where(
                    (j) =>
                        p.equals(j.project, project.path) && j.status != 'done',
                  ) ??
                  <PiWorkspaceJob>[])
            AppTreeTile(
              title: job.status == 'failed'
                  ? workspaceFailureLabel(l10n, job.error ?? '')
                  : job.name,
              depth: depth + 1,
              icon: job.status == 'failed'
                  ? Icons.error_outline
                  : Icons.hourglass_top,
              loading: job.status == 'working',
              onTap: () => controller.refresh(),
            ),
        ],
      ],
    );
  }

  Widget _section(PiCatalogSection? section) {
    final l10n = context.l10n;
    final name = section?.name ?? l10n.sectionUnassigned;
    final projects =
        controller.catalog?.projects
            .where((p) => p.sectionId == section?.id)
            .toList() ??
        [];
    final expanded =
        _query.isNotEmpty || !(section?.collapsed ?? _unassignedCollapsed);
    void toggle() {
      if (section == null) {
        setState(() => _unassignedCollapsed = !_unassignedCollapsed);
      } else {
        controller.updateSection(section.id, collapsed: !section.collapsed);
      }
    }

    final sections = controller.catalog?.sections ?? <PiCatalogSection>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        AppTreeTile(
          title: name,
          icon: Icons.layers_outlined,
          expanded: expanded,
          onTap: _organizing ? null : toggle,
          onExpand: !expanded && !_organizing ? toggle : null,
          onCollapse: expanded && !_organizing ? toggle : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconButton.subtle(
                icon: Icons.create_new_folder_outlined,
                size: 24,
                tooltip: l10n.workbenchAddProject,
                onPressed: _organizing
                    ? null
                    : () => widget.onAddProject(section?.id),
              ),
              if (section == null)
                AppMenuButton<String>(
                  icon: Icons.more_horiz,
                  tooltip: l10n.sectionManage,
                  options: [
                    AppMenuOption(
                      value: 'remove',
                      label: l10n.sectionDelete,
                      icon: Icons.delete_outline,
                    ),
                  ],
                  onSelected: _organizing ? null : (_) => _hideUnassigned(),
                ),
              if (section != null)
                AppMenuButton<_SectionAction>(
                  icon: Icons.more_horiz,
                  tooltip: l10n.sectionManage,
                  options: [
                    AppMenuOption(
                      value: _SectionAction.rename,
                      label: l10n.sectionRename,
                      icon: Icons.edit_outlined,
                    ),
                    if (sections.first.id != section.id)
                      AppMenuOption(
                        value: _SectionAction.up,
                        label: l10n.sectionMoveUp,
                        icon: Icons.arrow_upward,
                      ),
                    if (sections.last.id != section.id)
                      AppMenuOption(
                        value: _SectionAction.down,
                        label: l10n.sectionMoveDown,
                        icon: Icons.arrow_downward,
                      ),
                    AppMenuOption(
                      value: _SectionAction.delete,
                      label: l10n.sectionDelete,
                      icon: Icons.delete_outline,
                    ),
                  ],
                  onSelected: _organizing
                      ? null
                      : (action) => _sectionAction(section, action),
                ),
            ],
          ),
        ),
        if (expanded) ...[
          for (final project in projects)
            _project(project, _query.isNotEmpty && _matches(name)),
          if (projects.isEmpty && _query.isEmpty)
            AppTreeTile(
              title: l10n.sectionEmpty,
              icon: Icons.add,
              depth: 1,
              onTap: _organizing
                  ? null
                  : () => widget.onAddProject(section?.id),
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
                onPressed: controller.loading ? null : controller.refreshTree,
              ),
              AppIconButton.subtle(
                icon: Icons.create_new_folder_outlined,
                tooltip: l10n.workbenchAddProject,
                onPressed: _organizing ? null : () => widget.onAddProject(null),
              ),
              AppIconButton.subtle(
                tooltip: l10n.sectionCreate,
                icon: Icons.playlist_add,
                onPressed: _organizing ? null : () => _nameSection(),
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
                for (final section
                    in controller.catalog?.sections ?? <PiCatalogSection>[])
                  _section(section),
                if (controller.catalog?.unassignedHidden == true)
                  for (final project
                      in controller.catalog?.projects.where(
                            (p) => p.sectionId == null,
                          ) ??
                          <PiCatalogProject>[])
                    _project(project, false, depth: 0)
                else if (controller.catalog?.projects.any(
                      (p) => p.sectionId == null,
                    ) ==
                    true)
                  _section(null),
                if (controller.catalog?.projects.isEmpty == true &&
                    controller.catalog?.sections.isEmpty == true)
                  AppNavTile(
                    title: l10n.workbenchAddProject,
                    leading: const Icon(Icons.create_new_folder_outlined),
                    onTap: () => widget.onAddProject(null),
                  ),
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

class _SectionNameDialog extends StatefulWidget {
  const _SectionNameDialog({this.section});
  final PiCatalogSection? section;
  @override
  State<_SectionNameDialog> createState() => _SectionNameDialogState();
}

class _SectionNameDialogState extends State<_SectionNameDialog> {
  late final _name = TextEditingController(text: widget.section?.name ?? '');
  bool get valid => _name.text.trim().isNotEmpty && _name.text.length <= 160;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.section == null
        ? context.l10n.sectionCreate
        : context.l10n.sectionRename,
    actions: [
      AppActionButton.subtle(
        label: context.l10n.cancel,
        onPressed: () => Navigator.of(context).pop(),
      ),
      AppActionButton(
        label: context.l10n.confirm,
        onPressed: valid
            ? () => Navigator.of(context).pop(_name.text.trim())
            : null,
      ),
    ],
    child: AppTextField(
      controller: _name,
      autofocus: true,
      labelText: context.l10n.sectionName,
      onChanged: (_) => setState(() {}),
      errorText: _name.text.length > 160
          ? context.l10n.workspaceNameInvalid
          : null,
      onSubmitted: (_) {
        if (valid) Navigator.of(context).pop(_name.text.trim());
      },
    ),
  );
}
