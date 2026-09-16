import 'package:flutter/material.dart';
import 'package:pi_gui/core/rpc/pi_catalog_types.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

class WorktreeDraft {
  const WorktreeDraft(this.name, this.branch, this.baseRef);
  final String name, branch, baseRef;
}

class WorktreeCreateDialog extends StatefulWidget {
  const WorktreeCreateDialog({super.key, required this.project});
  final PiCatalogProject project;
  @override
  State<WorktreeCreateDialog> createState() => _WorktreeCreateDialogState();
}

class _WorktreeCreateDialogState extends State<WorktreeCreateDialog> {
  final _name = TextEditingController(), _branch = TextEditingController();
  late final _base = TextEditingController(text: widget.project.baseRef);
  bool _branchEdited = false;
  @override
  void dispose() {
    _name.dispose();
    _branch.dispose();
    _base.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const gap = SizedBox(height: AppSpacing.md);
    return AppDialog(
      title: l10n.worktreeCreate,
      maxWidth: 400,
      maxHeight: 520,
      actions: [
        AppActionButton.subtle(
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppActionButton(
          label: l10n.workbenchCreateBackground,
          onPressed:
              _name.text.trim().isEmpty ||
                  _branch.text.trim().isEmpty ||
                  _base.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  WorktreeDraft(
                    _name.text.trim(),
                    _branch.text.trim(),
                    _base.text.trim(),
                  ),
                ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.project.name, style: context.textTheme.titleSmall),
          gap,
          Text(l10n.workbenchCreateHint, style: context.textTheme.bodySmall),
          gap,
          Text(l10n.workbenchName, style: context.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _name,
            hintText: l10n.workbenchName,
            autofocus: true,
            onChanged: (value) {
              if (!_branchEdited) {
                _branch.text = value
                    .trim()
                    .toLowerCase()
                    .replaceAll(
                      RegExp(r'[^\p{L}\p{N}._/-]+', unicode: true),
                      '-',
                    )
                    .replaceFirst(RegExp(r'^[./-]+'), '');
              }
              setState(() {});
            },
          ),
          gap,
          Text(l10n.worktreeBranch, style: context.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _branch,
            hintText: l10n.worktreeBranch,
            onChanged: (_) => setState(() => _branchEdited = true),
          ),
          gap,
          Text(l10n.worktreeBase, style: context.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _base,
            hintText: l10n.worktreeBase,
            onChanged: (_) => setState(() {}),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final ref in ['HEAD', ...widget.project.branches])
                  AppNavTile(
                    title: ref == 'HEAD' ? l10n.worktreeHead : ref,
                    isSelected: _base.text == ref,
                    leading: Icon(
                      _base.text == ref
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    onTap: () => setState(() => _base.text = ref),
                  ),
              ],
            ),
          ),
          if (widget.project.worktreeParent case final parent?) ...[
            gap,
            Text(l10n.worktreeLocation, style: context.textTheme.labelMedium),
            SelectableText(parent, style: context.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
