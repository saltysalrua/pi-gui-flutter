import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

import '../controllers/workbench_controller.dart';
import '../workspace_labels.dart';

/// Project selection is a navigation action. Existing conversations retain
/// their own cwd, drafts and Pi processes; creation goes through control RPC.
class ProjectPickerDialog extends StatefulWidget {
  const ProjectPickerDialog({
    super.key,
    required this.controller,
    this.current,
  });
  final WorkbenchController controller;
  final String? current;
  @override
  State<ProjectPickerDialog> createState() => _ProjectPickerDialogState();
}

class _ProjectPickerDialogState extends State<ProjectPickerDialog> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  String? _parent, _error;
  bool _creating = false, _busy = false;
  String get _query => _search.text.trim().toLowerCase();
  bool get _enabled =>
      !_busy &&
      !widget.controller.opening &&
      !widget.controller.hasWorkspaceOperation;
  String? get _sectionId => widget.current == null
      ? null
      : widget.controller.projectForWorkspace(widget.current!)?.sectionId;

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick({bool parent = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = await getDirectoryPath(
        initialDirectory: widget.current,
        confirmButtonText: parent
            ? context.l10n.workspaceParent
            : context.l10n.workspaceOpen,
      );
      if (!mounted || path == null) return;
      if (parent) {
        setState(() => _parent = path);
      } else {
        final done = await widget.controller.addProject(
          path,
          sectionId: widget.controller.projectForWorkspace(path) == null
              ? _sectionId
              : null,
        );
        if (!mounted) return;
        if (done) {
          Navigator.of(context).pop();
        } else {
          setState(() => _error = widget.controller.failure);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'DIRECTORY_UNAVAILABLE');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(String path) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.controller.dismissFailure();
    try {
      await widget.controller.selectWorktree(path);
      if (!mounted) return;
      if (widget.controller.failure == null) {
        Navigator.of(context).pop();
      } else {
        setState(() => _error = widget.controller.failure);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final done = await widget.controller.createProject(
        _parent!,
        _name.text.trim(),
        sectionId: _sectionId,
      );
      if (!mounted) return;
      if (done) {
        Navigator.of(context).pop();
      } else {
        setState(() => _error = widget.controller.failure);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = context.l10n;
      return PopScope(
        canPop: !_busy,
        child: AppDialog(
          title: _creating ? l10n.projectCreateFolder : l10n.projectQuickChoose,
          maxWidth: 460,
          actions: [
            if (_creating)
              AppActionButton.subtle(
                label: l10n.back,
                onPressed: _enabled
                    ? () => setState(() {
                        _creating = false;
                        _error = null;
                      })
                    : null,
              ),
            AppActionButton.subtle(
              label: l10n.close,
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
            if (_creating)
              AppActionButton(
                label: l10n.workspaceCreateOpen,
                isLoading: _busy,
                onPressed:
                    _enabled && _parent != null && _name.text.trim().isNotEmpty
                    ? _create
                    : null,
              ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_creating) ...[
                Text(l10n.projectQuickHint, style: context.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                AppNavTile(
                  title: l10n.workspaceOpen,
                  leading: const Icon(Icons.folder_open_outlined),
                  onTap: _enabled ? _pick : null,
                ),
                AppNavTile(
                  title: l10n.projectCreateFolder,
                  leading: const Icon(Icons.create_new_folder_outlined),
                  onTap: _enabled
                      ? () => setState(() {
                          _creating = true;
                          _error = null;
                        })
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _search,
                  hintText: l10n.projectQuickSearch,
                  leading: const Icon(Icons.search),
                  isCompact: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final project in widget.controller.catalog?.projects ?? [])
                  if ('${project.name} ${project.path}'.toLowerCase().contains(
                    _query,
                  ))
                    AppNavTile(
                      title: project.name,
                      subtitle: project.path,
                      leading: const Icon(Icons.folder_outlined),
                      isSelected:
                          widget.current != null &&
                          p.equals(project.path, widget.current!),
                      onTap: _enabled ? () => _select(project.path) : null,
                    ),
              ] else ...[
                Text(
                  l10n.workspaceCreateHint,
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppActionButton.subtle(
                  label: l10n.workspaceParent,
                  subtitle: _parent,
                  leading: const Icon(Icons.folder_open_outlined),
                  isExpanded: true,
                  onPressed: _enabled ? () => _pick(parent: true) : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _name,
                  labelText: l10n.workspaceName,
                  autofocus: true,
                  enabled: _enabled,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (_enabled &&
                        _parent != null &&
                        _name.text.trim().isNotEmpty) {
                      _create();
                    }
                  },
                ),
                if (_parent != null && _name.text.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(
                    p.join(_parent!, _name.text.trim()),
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  workspaceFailureLabel(l10n, _error!),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
