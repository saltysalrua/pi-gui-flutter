import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/core/rpc/pi_workspace_types.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import '../controllers/workspace_controller.dart';
import '../workspace_labels.dart';

enum WorkspaceDialogPage {
  choose,
  create,
  worktrees,
  createWorktree,
  removeWorktree,
}

class WorkspaceDialog extends StatefulWidget {
  const WorkspaceDialog({
    super.key,
    required this.controller,
    this.initialPage = WorkspaceDialogPage.choose,
  });
  final WorkspaceController controller;
  final WorkspaceDialogPage initialPage;
  @override
  State<WorkspaceDialog> createState() => _WorkspaceDialogState();
}

class _WorkspaceDialogState extends State<WorkspaceDialog> {
  late var _page = widget.initialPage;
  final _name = TextEditingController();
  final _branch = TextEditingController();
  String? _parent, _pickerError;
  String _base = 'HEAD';
  PiWorktree? _removing;
  bool _picking = false;
  WorkspaceController get controller => widget.controller;

  @override
  void dispose() {
    _name.dispose();
    _branch.dispose();
    super.dispose();
  }

  Future<void> _pick({bool parent = false}) async {
    setState(() {
      _picking = true;
      _pickerError = null;
    });
    try {
      final path = await getDirectoryPath(
        initialDirectory: controller.snapshot?.current.path,
        confirmButtonText: parent
            ? context.l10n.workspaceParent
            : context.l10n.workspaceOpen,
      );
      if (!mounted || path == null) return;
      if (parent) {
        setState(() => _parent = path);
      } else {
        await _open(path);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pickerError = context.l10n.workspacePathFailed);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _open(String path) async {
    if (await controller.open(path) && mounted) Navigator.of(context).pop();
  }

  Future<void> _create() async {
    final done = _page == WorkspaceDialogPage.create
        ? await controller.create(_parent!, _name.text.trim())
        : await controller.createWorktree(_branch.text.trim(), _base);
    if (done && mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    if (_removing == null) return;
    if (await controller.removeWorktree(_removing!.path) && mounted) {
      _go(WorkspaceDialogPage.worktrees);
    }
  }

  void _go(WorkspaceDialogPage page) {
    controller.dismissFailure();
    setState(() {
      _page = page;
      _pickerError = null;
    });
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = controller.snapshot;
    final git = snapshot?.git;
    final enabled = controller.canSwitch && !_picking;
    final gap = const SizedBox(height: AppSpacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_page == WorkspaceDialogPage.choose) ...[
          AppNavTile(
            title: l10n.workspaceOpen,
            leading: const Icon(Icons.folder_open_outlined),
            onTap: enabled ? _pick : null,
          ),
          AppNavTile(
            title: l10n.workspaceCreate,
            leading: const Icon(Icons.create_new_folder_outlined),
            onTap: enabled ? () => _go(WorkspaceDialogPage.create) : null,
          ),
          gap,
          Text(l10n.workspaceRecent, style: context.textTheme.labelMedium),
          for (final workspace in snapshot?.recent ?? [])
            Tooltip(
              message: workspace.path,
              child: AppNavTile(
                title: workspace.name,
                subtitle: workspace.path,
                isSelected: workspace.path == snapshot?.current.path,
                leading: const Icon(Icons.folder_outlined),
                onTap: enabled ? () => _open(workspace.path) : null,
              ),
            ),
        ],
        if (_page == WorkspaceDialogPage.create) ...[
          Text(l10n.workspaceCreateHint, style: context.textTheme.bodySmall),
          gap,
          AppActionButton.subtle(
            label: l10n.workspaceParent,
            subtitle: _parent,
            leading: const Icon(Icons.folder_open_outlined),
            isExpanded: true,
            onPressed: enabled ? () => _pick(parent: true) : null,
          ),
          gap,
          Text(l10n.workspaceName, style: context.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _name,
            hintText: l10n.workspaceName,
            enabled: enabled,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          if (_parent != null && _name.text.trim().isNotEmpty) ...[
            gap,
            SelectableText(
              p.join(_parent!, _name.text.trim()),
              style: context.textTheme.bodySmall,
            ),
          ],
        ],
        if (_page == WorkspaceDialogPage.worktrees) ...[
          if (snapshot?.gitWarning case final warning?)
            Text(
              workspaceFailureLabel(l10n, warning),
              style: context.textTheme.bodySmall,
            )
          else if (git == null)
            Text(l10n.worktreeNotGit, style: context.textTheme.bodySmall)
          else ...[
            for (final worktree in git.worktrees.where((w) => !w.bare))
              Tooltip(
                message: worktree.path,
                child: AppNavTile(
                  title: worktree.branch ?? l10n.worktreeDetached,
                  subtitle: worktree.path,
                  isSelected: p.equals(worktree.path, snapshot!.current.path),
                  leading: Icon(
                    worktree.locked
                        ? Icons.lock_outline
                        : Icons.account_tree_outlined,
                  ),
                  trailing: worktree.prunable
                      ? Tooltip(
                          message: l10n.worktreeUnavailable,
                          child: const Icon(Icons.warning_amber_rounded),
                        )
                      : AppIconButton.subtle(
                          icon: Icons.delete_outline,
                          tooltip: l10n.worktreeRemove,
                          onPressed:
                              enabled &&
                                  !worktree.locked &&
                                  !p.equals(worktree.path, git.root) &&
                                  !p.equals(
                                    worktree.path,
                                    git.worktrees.first.path,
                                  )
                              ? () {
                                  _removing = worktree;
                                  _go(WorkspaceDialogPage.removeWorktree);
                                }
                              : null,
                        ),
                  onTap: enabled && !worktree.prunable
                      ? () => _open(worktree.path)
                      : null,
                ),
              ),
            gap,
            if (!git.hasHead)
              Text(l10n.worktreeNoCommit, style: context.textTheme.bodySmall),
            AppActionButton.subtle(
              label: l10n.worktreeCreate,
              leading: const Icon(Icons.add),
              isExpanded: true,
              onPressed: enabled && git.hasHead
                  ? () => _go(WorkspaceDialogPage.createWorktree)
                  : null,
            ),
          ],
        ],
        if (_page == WorkspaceDialogPage.createWorktree && git != null) ...[
          Text(l10n.worktreeCreateHint, style: context.textTheme.bodySmall),
          gap,
          if (git.dirty) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              borderColor: context.colors.warning.withValues(alpha: 0.4),
              child: Text(
                l10n.worktreeDirty,
                style: context.textTheme.bodySmall,
              ),
            ),
            gap,
          ],
          Text(l10n.worktreeBranch, style: context.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _branch,
            hintText: l10n.worktreeBranch,
            enabled: enabled,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          gap,
          Text(l10n.worktreeBase, style: context.textTheme.labelMedium),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 170),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final branch in ['HEAD', ...git.branches])
                  AppNavTile(
                    title: branch == 'HEAD' ? l10n.worktreeHead : branch,
                    isSelected: _base == branch,
                    leading: Icon(
                      _base == branch
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    onTap: enabled
                        ? () => setState(() => _base = branch)
                        : null,
                  ),
              ],
            ),
          ),
          gap,
          Text(l10n.worktreeLocation, style: context.textTheme.labelMedium),
          SelectableText(
            git.worktreeParent,
            style: context.textTheme.bodySmall,
          ),
        ],
        if (_page == WorkspaceDialogPage.removeWorktree &&
            _removing != null) ...[
          Text(l10n.worktreeRemoveConfirm, style: context.textTheme.bodyMedium),
          gap,
          SelectableText(_removing!.path, style: context.textTheme.bodyMedium),
        ],
        if (controller.failureCode != null || _pickerError != null) ...[
          gap,
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            borderColor: context.colors.warning.withValues(alpha: 0.4),
            child: Text(
              _pickerError ??
                  workspaceFailureLabel(l10n, controller.failureCode!),
              style: context.textTheme.bodySmall,
            ),
          ),
        ],
        if (controller.createdPath case final path?) ...[
          gap,
          Text(l10n.workspaceCreatedKept, style: context.textTheme.bodySmall),
          SelectableText(path, style: context.textTheme.bodySmall),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      controller,
      controller.chat,
      controller.models,
    ]),
    builder: (context, _) {
      final l10n = context.l10n;
      final creating =
          _page == WorkspaceDialogPage.create ||
          _page == WorkspaceDialogPage.createWorktree;
      final canSubmit =
          controller.canSwitch &&
          !_picking &&
          (_page == WorkspaceDialogPage.create
              ? _parent != null && _name.text.trim().isNotEmpty
              : _branch.text.trim().isNotEmpty);
      return PopScope(
        canPop: !controller.isBusy && !_picking,
        child: AppDialog(
          title: switch (_page) {
            WorkspaceDialogPage.choose => l10n.workspaceChoose,
            WorkspaceDialogPage.create => l10n.workspaceCreate,
            WorkspaceDialogPage.worktrees => l10n.worktreeManage,
            WorkspaceDialogPage.createWorktree => l10n.worktreeCreate,
            WorkspaceDialogPage.removeWorktree => l10n.worktreeRemove,
          },
          actions: [
            if (creating || _page == WorkspaceDialogPage.removeWorktree)
              AppActionButton.subtle(
                label: l10n.back,
                onPressed: controller.isBusy || _picking
                    ? null
                    : () => _go(
                        _page == WorkspaceDialogPage.create
                            ? WorkspaceDialogPage.choose
                            : WorkspaceDialogPage.worktrees,
                      ),
              ),
            AppActionButton.subtle(
              label: l10n.close,
              onPressed: controller.isBusy || _picking
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
            if (creating)
              AppActionButton(
                label: l10n.workspaceCreateOpen,
                isLoading: controller.isBusy,
                onPressed: canSubmit ? _create : null,
              ),
            if (_page == WorkspaceDialogPage.removeWorktree)
              AppActionButton(
                label: l10n.worktreeRemove,
                isLoading: controller.isBusy,
                onPressed: controller.canSwitch ? _remove : null,
              ),
          ],
          child: _body(context),
        ),
      );
    },
  );
}
