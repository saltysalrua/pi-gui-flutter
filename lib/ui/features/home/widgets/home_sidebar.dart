import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pi_gui/core/rpc/pi_workspace_types.dart';
import 'package:pi_gui/core/slots/slot_manager.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/atoms/slot_container.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import '../controllers/workspace_controller.dart';
import '../workspace_labels.dart';

/// Real per-directory history. Selection and filesystem operations belong to RPC.
class HomeSidebar extends StatefulWidget {
  const HomeSidebar({
    super.key,
    this.width = 260,
    this.backgroundColor,
    required this.workspace,
    this.selectedSessionId,
    this.onSessionSelected,
    this.onNewConversation,
    required this.onChooseWorkspace,
    required this.onChooseWorktree,
    this.onSettingsPressed,
  });
  final double width;
  final Color? backgroundColor;
  final WorkspaceController workspace;
  final String? selectedSessionId;
  final ValueChanged<String>? onSessionSelected;
  final VoidCallback? onNewConversation, onSettingsPressed;
  final VoidCallback onChooseWorkspace, onChooseWorktree;
  @override
  State<HomeSidebar> createState() => _HomeSidebarState();
}

class _HomeSidebarState extends State<HomeSidebar> {
  final _search = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _session(BuildContext context, PiSessionSummary session) {
    final locale = Localizations.localeOf(context).toString();
    final updated = DateFormat.yMd(
      locale,
    ).add_Hm().format(session.modified.toLocal());
    final title = session.title.isEmpty
        ? context.l10n.newConversation
        : session.title;
    return Tooltip(
      message:
          '$title\n$updated · ${context.l10n.sessionMessageCount(session.messageCount)}\n${session.path}',
      child: AppNavTile(
        title: title,
        isSelected: widget.selectedSessionId == session.path,
        onTap: widget.workspace.canSwitch
            ? () => widget.onSessionSelected?.call(session.path)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final snapshot = workspace.snapshot;
    final l10n = context.l10n;
    final colors = context.colors;
    final matches = workspace.sessions
        .where(
          (s) =>
              '${s.title} ${s.id}'.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return SizedBox(
      width: widget.width,
      child: ColoredBox(
        color: widget.backgroundColor ?? colors.sidebarBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppActionButton.subtle(
                label: l10n.newConversation,
                leading: const Icon(Icons.add_rounded),
                height: 40,
                isExpanded: true,
                mainAxisAlignment: MainAxisAlignment.start,
                onPressed: workspace.canSwitch
                    ? widget.onNewConversation
                    : null,
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
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  AppIconButton.subtle(
                    icon: Icons.refresh,
                    tooltip: l10n.workspaceRefresh,
                    onPressed: workspace.isBusy
                        ? null
                        : () => workspace.refresh(loadConversation: false),
                  ),
                  AppIconButton.subtle(
                    icon: Icons.add,
                    tooltip: l10n.workspaceChoose,
                    onPressed: workspace.canSwitch
                        ? widget.onChooseWorkspace
                        : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Tooltip(
                message: snapshot?.current.path ?? l10n.workspaceChoose,
                child: AppNavTile(
                  title: snapshot?.current.name ?? l10n.workspaceChoose,
                  isFolder: true,
                  leading: const Icon(Icons.folder_open_outlined),
                  trailing: const Icon(Icons.unfold_more_rounded, size: 16),
                  onTap: workspace.canSwitch ? widget.onChooseWorkspace : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: AppActionButton.subtle(
                label:
                    snapshot?.git?.branch ??
                    (snapshot?.git == null
                        ? l10n.worktreeManage
                        : l10n.worktreeDetached),
                leading: const Icon(Icons.account_tree_outlined),
                isExpanded: true,
                mainAxisAlignment: MainAxisAlignment.start,
                height: 30,
                padding: const EdgeInsets.all(AppSpacing.xs),
                onPressed: workspace.canSwitch ? widget.onChooseWorktree : null,
              ),
            ),
            if (workspace.failureCode case final code?)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    workspaceFailureLabel(l10n, code),
                    style: context.textTheme.bodySmall,
                  ),
                ),
              ),
            if (snapshot?.persistenceWarning == true)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  l10n.workspacePersistenceFailed,
                  style: context.textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppTextField(
                controller: _search,
                hintText: l10n.sessionSearch,
                isCompact: true,
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => _query = value.trim()),
                trailing: _query.isEmpty
                    ? null
                    : AppIconButton.subtle(
                        icon: Icons.close,
                        tooltip: l10n.clearSearch,
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
            if (workspace.isBusy || workspace.isLoadingSessions)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  workspace.isLoadingSessions
                      ? l10n.sessionHistoryLoading
                      : l10n.workspaceLoading,
                  style: context.textTheme.labelSmall,
                ),
              ),
            if (workspace.sessionsFailure != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  l10n.sessionHistoryFailed,
                  style: context.textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppDurations.quick,
                child: matches.isEmpty
                    ? Align(
                        key: ValueKey(_query.isEmpty),
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            _query.isEmpty
                                ? l10n.noSessions
                                : l10n.sessionNoMatch,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        key: ValueKey(snapshot?.current.path),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        itemCount: matches.length,
                        itemBuilder: (context, index) =>
                            _session(context, matches[index]),
                      ),
              ),
            ),
            const SlotContainer(
              slotId: ExtensibleSlotId.sidebarPanel,
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: AppNavTile(
                title: l10n.settings,
                leading: const Icon(Icons.settings_outlined),
                onTap: widget.onSettingsPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
