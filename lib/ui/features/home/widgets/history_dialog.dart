import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_history_types.dart';
import 'package:pi_gui/core/utils/terminal_text.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_activity_label.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_code_block.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
import 'package:pi_gui/ui/atoms/app_disclosure.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_image.dart';
import 'package:pi_gui/ui/atoms/app_markdown.dart';
import 'package:pi_gui/ui/atoms/app_select.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/atoms/app_tree_tile.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

import '../controllers/history_controller.dart';

class HistoryDialog extends StatefulWidget {
  const HistoryDialog({
    super.key,
    required this.controller,
    required this.hasDraft,
    required this.onAbort,
    this.message,
    this.initialAction = PiHistoryAction.navigate,
  });
  final HistoryController controller;
  final bool Function() hasDraft;
  final Future<void> Function() onAbort;
  final PiChatMessage? message;
  final PiHistoryAction initialAction;
  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  final _search = TextEditingController(),
      _instructions = TextEditingController();
  final _scroll = ScrollController();
  final _treeFocus = FocusNode();
  int _summary = 0;
  bool _replace = false, _timestamps = false;
  String? _lastSelected;
  HistoryController get history => widget.controller;
  @override
  void initState() {
    super.initState();
    history.addListener(_changed);
    // The chat behind this route subscribes to the same controller. Starting
    // synchronously in initState would notify that sibling during route build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(history.open(message: widget.message));
    });
  }

  void _changed() {
    if (!mounted) return;
    if (_lastSelected != history.selectedId) {
      _lastSelected = history.selectedId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final index = history.rows.indexWhere(
          (row) => row.entry.id == history.selectedId,
        );
        if (index >= 0) {
          _scroll.jumpTo(
            (index * 28.0).clamp(0.0, _scroll.position.maxScrollExtent),
          );
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    history.removeListener(_changed);
    history.close();
    _search.dispose();
    _instructions.dispose();
    _scroll.dispose();
    _treeFocus.dispose();
    super.dispose();
  }

  KeyEventResult _treeKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || history.busy) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed && key == LogicalKeyboardKey.keyO) {
      history.setFilter(
        PiHistoryFilter.values[(history.filter.index + 1) %
            PiHistoryFilter.values.length],
      );
    } else if (keyboard.isShiftPressed &&
        key == LogicalKeyboardKey.keyL &&
        history.canAct) {
      unawaited(_label());
    } else if (keyboard.isShiftPressed && key == LogicalKeyboardKey.keyT) {
      setState(() => _timestamps = !_timestamps);
    } else if (key == LogicalKeyboardKey.enter) {
      unawaited(_act(widget.initialAction));
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final id = history.selectedId;
      if (id != null &&
          (history.folded.contains(id) ==
              (key == LogicalKeyboardKey.arrowRight))) {
        history.toggle(id);
      }
    } else {
      final delta = key == LogicalKeyboardKey.arrowDown
          ? 1
          : key == LogicalKeyboardKey.arrowUp
          ? -1
          : key == LogicalKeyboardKey.pageDown
          ? 10
          : key == LogicalKeyboardKey.pageUp
          ? -10
          : 0;
      final rows = history.rows;
      if (delta == 0 || rows.isEmpty) return KeyEventResult.ignored;
      final current = rows.indexWhere((r) => r.entry.id == history.selectedId);
      unawaited(
        history.select(
          rows[(current + delta).clamp(0, rows.length - 1)].entry.id,
        ),
      );
    }
    return KeyEventResult.handled;
  }

  Future<bool> _confirm(String title, String text) async =>
      await showAppDialog<bool>(
        context,
        (context) => AppDialog(
          title: title,
          maxWidth: 440,
          actions: [
            AppActionButton.subtle(
              label: context.l10n.cancel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppActionButton(
              label: context.l10n.confirm,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
          child: Text(text, style: context.textTheme.bodyMedium),
        ),
      ) ==
      true;
  Future<void> _act(PiHistoryAction action) async {
    final l10n = context.l10n;
    // Confirmation is bound to the selected ID and leaf, not whichever row the
    // user might have selected while an asynchronous dialog was resolving.
    final source = history.snapshot, selected = history.selectedId;
    if (!history.canAct ||
        action != PiHistoryAction.clone && history.selected == null) {
      return;
    }
    if (action == PiHistoryAction.fork && !history.selected!.isUser) {
      return;
    }
    if (action == PiHistoryAction.navigate &&
        _summary == 2 &&
        _instructions.text.trim().isEmpty) {
      return;
    }
    final draftWarning = action != PiHistoryAction.clone && widget.hasDraft();
    if (!await _confirm(
      l10n.historyConfirm,
      '${l10n.historyConfirmHint}${draftWarning ? '\n\n${l10n.historyDraftWarning}' : ''}',
    )) {
      return;
    }
    if (!mounted ||
        !identical(source, history.snapshot) ||
        selected != history.selectedId) {
      return;
    }
    final success = await history.act(
      action,
      summarize: action == PiHistoryAction.navigate && _summary != 0,
      instructions: _summary == 2 ? _instructions.text : null,
      replaceInstructions: _replace,
    );
    if (success && mounted) Navigator.of(context).pop();
  }

  Future<void> _label() async {
    final selected = history.selectedId;
    if (selected == null) return;
    final input = TextEditingController(text: history.selected?.label ?? '');
    ModalRoute<dynamic>? dialogRoute;
    final value = await showAppDialog<String>(context, (context) {
      dialogRoute = ModalRoute.of(context);
      return AppDialog(
        title: context.l10n.historyLabel,
        maxWidth: 420,
        actions: [
          AppActionButton.subtle(
            label: context.l10n.cancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppActionButton(
            label: context.l10n.confirm,
            onPressed: () => Navigator.of(context).pop(input.text),
          ),
        ],
        child: AppTextField(
          controller: input,
          hintText: context.l10n.historyLabelHint,
          autofocus: true,
        ),
      );
    });
    // Keep the controller alive for the entire reverse transition.
    if (dialogRoute != null) await dialogRoute!.completed;
    input.dispose();
    if (mounted && value != null && selected == history.selectedId) {
      await history.setLabel(value);
    }
  }

  String _kind(PiHistoryEntry entry) {
    final l10n = context.l10n;
    return switch ((entry.type, entry.role)) {
      ('message', 'user') => l10n.chatYou,
      ('message', 'assistant') => l10n.agentMain,
      ('message', 'toolResult') => l10n.chatOutput,
      ('message', 'system') => l10n.historySystem,
      ('message', 'bashExecution') => l10n.chatBash,
      ('compaction', _) => l10n.historyCompaction,
      ('branch_summary', _) => l10n.historyBranchSummary,
      ('custom_message' || 'custom', _) => l10n.historyExtensionEntry,
      ('model_change', _) => l10n.selectModel,
      ('thinking_level_change', _) => l10n.thinkingIntensity,
      ('label', _) => l10n.historyLabel,
      ('session_info', _) => l10n.historySettingsEntry,
      _ => entry.type,
    };
  }

  String _failure(String code) {
    final l10n = context.l10n;
    return switch (code) {
      'HISTORY_STALE' || 'HISTORY_ENTRY_MISSING' => l10n.historyStale,
      'HISTORY_UNAVAILABLE' || 'UNKNOWN_COMMAND' => l10n.historyUnavailable,
      'HISTORY_BUSY' || 'WORKSPACE_BUSY' => l10n.historyBusy,
      'HISTORY_CANCELLED' => l10n.historyCancelled,
      'HISTORY_UNCERTAIN' => l10n.historyUncertain,
      'HISTORY_REFRESH_FAILED' => l10n.historyRefreshFailed,
      'HISTORY_DISCONNECTED' => l10n.piDisconnected,
      _ => l10n.historyFailed,
    };
  }

  Widget _tree() {
    final rows = history.rows;
    if (rows.isEmpty) {
      return Center(
        child: Text(
          context.l10n.historyEmpty,
          style: context.textTheme.bodyMedium,
        ),
      );
    }
    final snapshot = history.snapshot!;
    return ListView.builder(
      controller: _scroll,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index], entry = row.entry;
        final active = snapshot.leafId == entry.id;
        final path = snapshot.activePath.contains(entry.id);
        final label = entry.label == null
            ? ''
            : '${entry.label}${_timestamps ? ' · ${entry.labelTimestamp ?? ''}' : ''} · ';
        final text = stripTerminalControls(entry.preview);
        return Tooltip(
          message:
              '${_kind(entry)} · ${entry.id}\n${entry.timestamp}${path ? '\n${context.l10n.historyActivePath}' : ''}',
          child: AppTreeTile(
            title:
                '$label${_kind(entry)}: ${text.isEmpty && entry.imageCount > 0 ? context.l10n.historyImageOnly : text}',
            icon: active
                ? Icons.radio_button_checked
                : entry.isUser
                ? Icons.person_outline
                : Icons.account_tree_outlined,
            depth: row.depth,
            expanded: row.hasChildren
                ? !history.folded.contains(entry.id)
                : null,
            selected: history.selectedId == entry.id,
            color: active ? context.colors.primary : null,
            onTap: history.busy
                ? null
                : () {
                    _treeFocus.requestFocus();
                    unawaited(history.select(entry.id));
                  },
            onExpand: row.hasChildren && history.folded.contains(entry.id)
                ? () => history.toggle(entry.id)
                : null,
            onCollapse: row.hasChildren && !history.folded.contains(entry.id)
                ? () => history.toggle(entry.id)
                : null,
            trailing: row.hasChildren
                ? AppIconButton.subtle(
                    icon: history.folded.contains(entry.id)
                        ? Icons.unfold_more
                        : Icons.unfold_less,
                    tooltip: context.l10n.historyCollapse,
                    onPressed: history.busy
                        ? null
                        : () => history.toggle(entry.id),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _preview() {
    final entry = history.selected;
    final data = history.preview;
    final l10n = context.l10n;
    if (entry == null) {
      return Center(
        child: Text(l10n.historySelect, style: context.textTheme.bodyMedium),
      );
    }
    if (history.previewLoading) {
      return AppActivityLabel(text: l10n.chatLoading, active: true);
    }
    if (data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.historyPreviewFailed,
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppActionButton.subtle(
              label: l10n.chatRefresh,
              onPressed: history.busy ? null : () => history.select(entry.id),
            ),
          ],
        ),
      );
    }
    final message = data['message'] is Map
        ? Map<String, dynamic>.from(data['message'] as Map)
        : data;
    final content = piContent(message['content'] ?? data['summary']);
    return SingleChildScrollView(
      key: ValueKey(entry.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_kind(entry), style: context.textTheme.titleSmall),
          Text(
            '${entry.id} · ${entry.timestamp}',
            style: context.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final block in content) ...[
            switch (block.kind) {
              PiContentKind.image => AppImage(image: block.image),
              PiContentKind.text => AppMarkdown(
                data: stripTerminalControls(block.text),
              ),
              PiContentKind.thinking => AppDisclosure(
                title: l10n.chatThinking,
                framed: false,
                builder: (_) =>
                    AppMarkdown(data: stripTerminalControls(block.text)),
              ),
              PiContentKind.toolCall => AppDisclosure(
                title: block.name,
                framed: false,
                builder: (_) => AppCodeBlock(
                  code: formatToolArguments(block.arguments),
                  label: block.name,
                ),
              ),
              PiContentKind.unknown => Text(
                l10n.chatUnsupportedContent,
                style: context.textTheme.bodySmall,
              ),
            },
            const SizedBox(height: AppSpacing.sm),
          ],
          if (content.isEmpty)
            AppCodeBlock(
              code: const JsonEncoder.withIndent('  ').convert(data),
              label: entry.type,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = history.selected;
    final canFork = history.canAct && entry?.isUser == true;
    final primaryFork = widget.initialAction == PiHistoryAction.fork;
    final canNavigate = history.canAct && entry != null;
    final navigateLabel = entry?.restoresDraft == true
        ? l10n.historyEdit
        : l10n.historyNavigate;
    final height = (MediaQuery.sizeOf(context).height - 380).clamp(
      180.0,
      420.0,
    );
    return PopScope(
      canPop: !history.busy,
      child: AppDialog(
        title: l10n.historyTitle,
        maxWidth: 940,
        maxHeight: 900,
        actions: [
          if (history.busy)
            AppActionButton.subtle(
              label: l10n.historyStop,
              onPressed: () async {
                try {
                  await widget.onAbort();
                } catch (_) {}
              },
            ),
          AppActionButton.subtle(
            label: l10n.close,
            onPressed: history.busy ? null : () => Navigator.of(context).pop(),
          ),
          AppActionButton.subtle(
            label: l10n.historyClone,
            onPressed: history.canAct && history.snapshot?.leafId != null
                ? () => _act(PiHistoryAction.clone)
                : null,
          ),
          Tooltip(
            message: l10n.historyForkHint,
            child: AppActionButton(
              label: l10n.historyFork,
              variant: primaryFork
                  ? AppButtonVariant.primary
                  : AppButtonVariant.subtle,
              onPressed: canFork ? () => _act(PiHistoryAction.fork) : null,
            ),
          ),
          AppActionButton(
            label: navigateLabel,
            variant: primaryFork
                ? AppButtonVariant.subtle
                : AppButtonVariant.primary,
            onPressed:
                canNavigate &&
                    (_summary != 2 || _instructions.text.trim().isNotEmpty)
                ? () => _act(PiHistoryAction.navigate)
                : null,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.historyHint, style: context.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _search,
              hintText: l10n.historySearch,
              leading: const Icon(Icons.search),
              onChanged: history.search,
              isCompact: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppSelect<PiHistoryFilter>(
                  value: history.filter,
                  label: l10n.historyFilter,
                  options: [
                    AppSelectOption(
                      PiHistoryFilter.standard,
                      l10n.historyDefault,
                    ),
                    AppSelectOption(
                      PiHistoryFilter.noTools,
                      l10n.historyNoTools,
                    ),
                    AppSelectOption(
                      PiHistoryFilter.userOnly,
                      l10n.historyUserOnly,
                    ),
                    AppSelectOption(
                      PiHistoryFilter.labeledOnly,
                      l10n.historyLabeledOnly,
                    ),
                    AppSelectOption(PiHistoryFilter.all, l10n.historyAll),
                  ],
                  onChanged: history.setFilter,
                ),
                AppIconButton.subtle(
                  icon: Icons.my_location,
                  tooltip: l10n.historyCurrent,
                  onPressed: () {
                    _search.clear();
                    history.revealCurrent();
                  },
                ),
                AppIconButton.subtle(
                  icon: Icons.unfold_more,
                  tooltip: l10n.historyExpand,
                  onPressed: history.expandAll,
                ),
                AppIconButton.subtle(
                  icon: Icons.schedule,
                  tooltip: l10n.historyTimestamps,
                  onPressed: () => setState(() => _timestamps = !_timestamps),
                ),
                AppIconButton.subtle(
                  icon: Icons.label_outline,
                  tooltip: l10n.historyLabel,
                  onPressed: history.canAct && entry != null ? _label : null,
                ),
                AppIconButton.subtle(
                  icon: Icons.refresh,
                  tooltip: l10n.chatRefresh,
                  onPressed: history.loading || history.busy
                      ? null
                      : history.refresh,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (history.loading || history.busy)
              AppActivityLabel(
                text: history.busy ? l10n.historyWorking : l10n.chatLoading,
                active: true,
              ),
            if (history.failure case final failure?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  _failure(failure),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.warning,
                  ),
                ),
              ),
            if (!history.busy && !history.canMutate())
              Text(l10n.historyBusy, style: context.textTheme.bodySmall),
            LayoutBuilder(
              builder: (context, constraints) {
                final tree = SizedBox(
                  height: height,
                  child: Focus(
                    focusNode: _treeFocus,
                    onKeyEvent: _treeKey,
                    child: _tree(),
                  ),
                );
                final preview = SizedBox(
                  height: height,
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _preview(),
                  ),
                );
                return constraints.maxWidth >= 640
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: tree),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: preview),
                        ],
                      )
                    : Column(
                        children: [
                          tree,
                          const SizedBox(height: AppSpacing.sm),
                          preview,
                        ],
                      );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppSelect<int>(
                  value: _summary,
                  label: l10n.historySummary,
                  options: [
                    AppSelectOption(0, l10n.historySummaryNone),
                    AppSelectOption(1, l10n.historySummaryDefault),
                    AppSelectOption(2, l10n.historySummaryCustom),
                  ],
                  onChanged: history.busy
                      ? null
                      : (v) => setState(() => _summary = v),
                ),
                if (_summary == 2)
                  AppSelect<bool>(
                    value: _replace,
                    label: l10n.historyInstructionsMode,
                    options: [
                      AppSelectOption(false, l10n.historyAppendInstructions),
                      AppSelectOption(true, l10n.historyReplaceInstructions),
                    ],
                    onChanged: history.busy
                        ? null
                        : (v) => setState(() => _replace = v),
                  ),
              ],
            ),
            if (_summary == 2)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: AppTextField(
                  controller: _instructions,
                  hintText: l10n.historyInstructions,
                  maxLines: 3,
                  enabled: !history.busy,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            if (_summary != 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.historySummaryCost,
                  style: context.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
