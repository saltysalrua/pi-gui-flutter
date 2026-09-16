import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/core/slots/slot_manager.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_badge.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
import 'package:pi_gui/ui/atoms/app_notification_toast.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

// 扩展可能使用终端 ANSI 颜色与超链接；Flutter 使用主题，剥除控制序列并完整保留正文。
String _plainText(String text) => text.replaceAll(
  RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)'),
  '',
);

/// 从连接建立前开始订阅，避免扩展在启动/模型切换时请求 UI 而悬挂。
class PiExtensionUiBridge {
  PiExtensionUiBridge(
    this._client,
    this._editor, {
    SlotManager? slots,
    this.onAttentionChanged,
    this._foreground = true,
  }) : _slots = slots ?? SlotManager.instance {
    _subscription = _client.events.listen((event) {
      if (event is PiExtensionUiRequest) _route(event);
      if (event is PiRpcDisconnected || event is PiRpcWorkspaceReset) {
        _clear();
      }
      if (event is PiRpcDiagnostic &&
          event.kind == PiRpcDiagnosticKind.invalidEvent) {
        _notify(null, invalidRequest: true);
      }
    });
  }
  final PiRpcClient _client;
  final TextEditingController _editor;
  late final StreamSubscription<PiRpcEvent> _subscription;
  final SlotManager _slots;
  final VoidCallback? onAttentionChanged;
  bool _foreground;
  String? _title;
  bool get needsAttention => _dialogs.isNotEmpty;
  bool get hasNotifications => _notifications.isNotEmpty;
  final _notifications = <({String? message, bool invalid})>[];
  final _dialogInputs = <String, TextEditingController>{};

  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (value) {
      _showDialog();
      _showNotification();
      if (_title case final title?) {
        unawaited(windowManager.setTitle(title).catchError((Object _) {}));
      }
    } else {
      SlotManager.instance.clearSlot(ExtensibleSlotId.dialogOverlay);
      SlotManager.instance.clearSlot(ExtensibleSlotId.notificationToast);
    }
  }

  final _widgets = <String, ({ExtensibleSlotId slot, Widget child})>{};
  final _statuses = <String, Widget>{};
  final _dialogs = <PiExtensionUiRequest>[];
  final _timers = <String, Timer>{};

  void _route(PiExtensionUiRequest request) {
    switch (request.method) {
      case 'setWidget':
        final key = request.widgetKey;
        if (key == null) return;
        _widgets.remove(key);
        if (request.widgetLines case final lines?) {
          final hasContent = lines.any((l) => _plainText(l).trim().isNotEmpty);
          if (hasContent) {
            final isBelowEditor = request.widgetPlacement == 'belowEditor';
            _widgets[key] = (
              slot: isBelowEditor
                  ? ExtensibleSlotId.belowEditor
                  : ExtensibleSlotId.aboveEditor,
              child: _ExtensionWidgetView(
                key: ValueKey(key),
                widgetKey: key,
                lines: lines,
                isBelowEditor: isBelowEditor,
              ),
            );
          }
        }
        for (final slot in [
          ExtensibleSlotId.aboveEditor,
          ExtensibleSlotId.belowEditor,
        ]) {
          _slots.setSlotWidgets(
            slot,
            _widgets.values
                .where((item) => item.slot == slot)
                .map((item) => item.child)
                .toList(),
          );
        }
      case 'setStatus':
        final key = request.statusKey;
        if (key == null) return;
        _statuses.remove(key);
        if (request.statusText case final text?) {
          final trimmed = _plainText(text).trim();
          if (trimmed.isNotEmpty) {
            _statuses[key] = AppBadge(
              label: trimmed,
              variant: AppBadgeVariant.neutral,
            );
          }
        }
        _slots.setSlotWidgets(
          ExtensibleSlotId.statusBar,
          _statuses.values.toList(),
        );
      case 'set_editor_text':
        _editor.text = request.text ?? '';
      case 'setTitle':
        _title = request.title;
        if (_foreground && request.title != null) {
          unawaited(
            windowManager.setTitle(request.title!).catchError((Object _) {}),
          );
        }
      case 'notify':
        _notify(request.message);
      case 'select':
      case 'confirm':
      case 'input':
      case 'editor':
        _dialogs.add(request);
        _dialogInputs[request.id] = TextEditingController(
          text: request.prefill,
        );
        if (request.timeout case final timeout?) {
          _timers[request.id] = Timer(
            Duration(milliseconds: timeout),
            () => _finish(request, cancelled: true),
          );
        }
        _showDialog();
      default:
        // 未知方法也明确提示，不能静默吞掉。
        _notify(null);
    }
  }

  void _notify(String? message, {bool invalidRequest = false}) {
    _notifications.add((message: message, invalid: invalidRequest));
    onAttentionChanged?.call();
    _showNotification();
  }

  void _showNotification() {
    if (!_foreground) return;
    final notice = _notifications.firstOrNull;
    SlotManager.instance.setSlotWidgets(ExtensibleSlotId.notificationToast, [
      if (notice != null)
        AppNotificationToast(
          key: ValueKey((this, notice)),
          message: notice.message,
          invalidRequest: notice.invalid,
          onDismiss: () {
            if (_notifications.isNotEmpty) _notifications.removeAt(0);
            onAttentionChanged?.call();
            _showNotification();
          },
        ),
    ]);
  }

  void _showDialog() {
    onAttentionChanged?.call();
    if (!_foreground) return;
    final request = _dialogs.firstOrNull;
    SlotManager.instance.setSlotWidgets(ExtensibleSlotId.dialogOverlay, [
      if (request != null)
        _ExtensionDialog(
          key: ValueKey((this, request.id)),
          request: request,
          input: _dialogInputs[request.id],
          anchorKey: _slots.editorAnchor,
          onDone: (value, confirmed, cancelled) => _finish(
            request,
            value: value,
            confirmed: confirmed,
            cancelled: cancelled,
          ),
        ),
    ]);
  }

  void _finish(
    PiExtensionUiRequest request, {
    String? value,
    bool? confirmed,
    bool cancelled = false,
  }) {
    if (!_dialogs.remove(request)) return;
    _timers.remove(request.id)?.cancel();
    unawaited(
      _client.respondToExtension(
        request.id,
        value: value,
        confirmed: confirmed,
        cancelled: cancelled,
      ),
    );
    _showDialog();
    final input = _dialogInputs.remove(request.id);
    WidgetsBinding.instance.addPostFrameCallback((_) => input?.dispose());
  }

  void _clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _dialogs.clear();
    _notifications.clear();
    final inputs = _dialogInputs.values.toList();
    _dialogInputs.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final input in inputs) {
        input.dispose();
      }
    });
    _widgets.clear();
    _statuses.clear();
    if (_foreground) {
      SlotManager.instance.clearSlot(ExtensibleSlotId.dialogOverlay);
      SlotManager.instance.clearSlot(ExtensibleSlotId.notificationToast);
    }
    onAttentionChanged?.call();
    for (final slot in [
      ExtensibleSlotId.aboveEditor,
      ExtensibleSlotId.belowEditor,
      ExtensibleSlotId.statusBar,
      ExtensibleSlotId.dialogOverlay,
      ExtensibleSlotId.notificationToast,
    ]) {
      _slots.clearSlot(slot);
    }
  }

  void dispose() {
    unawaited(_subscription.cancel());
    _clear();
  }
}

class _ExtensionDialog extends StatefulWidget {
  const _ExtensionDialog({
    super.key,
    required this.request,
    required this.anchorKey,
    required this.onDone,
    this.input,
  });
  final TextEditingController? input;
  final PiExtensionUiRequest request;
  final GlobalKey anchorKey;
  final void Function(String? value, bool? confirmed, bool cancelled) onDone;
  @override
  State<_ExtensionDialog> createState() => _ExtensionDialogState();
}

class _ExtensionDialogState extends State<_ExtensionDialog> {
  late final _input =
      widget.input ?? TextEditingController(text: widget.request.prefill);
  final _focusScope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  @override
  void dispose() {
    _focusScope.dispose();
    if (widget.input == null) _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final l10n = context.l10n;
    return Stack(
      children: [
        ModalBarrier(
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.12),
          dismissible: false,
        ),
        SafeArea(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  widget.onDone(null, null, true),
            },
            child: FocusScope(
              node: _focusScope,
              autofocus: true,
              child: AppDialog(
                title: _plainText(request.title ?? ''),
                maxWidth: 420,
                maxHeight: 480,
                anchorKey: widget.anchorKey,
                placement: AppDialogPlacement.above,
                fallbackAlignment: Alignment.bottomRight,
                actions: [
                  AppActionButton.subtle(
                    label: l10n.cancel,
                    onPressed: () => widget.onDone(null, null, true),
                  ),
                  if (request.method != 'select')
                    AppActionButton(
                      label: l10n.confirm,
                      onPressed: () => widget.onDone(
                        request.method == 'confirm' ? null : _input.text,
                        request.method == 'confirm' ? true : null,
                        false,
                      ),
                    ),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (request.message case final message?) ...[
                      Text(
                        _plainText(message),
                        style: context.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (request.method == 'input' || request.method == 'editor')
                      AppTextField(
                        controller: _input,
                        hintText: request.placeholder ?? '',
                        autofocus: true,
                        maxLines: request.method == 'editor' ? 6 : 1,
                      ),
                    for (final option in request.options ?? <String>[])
                      AppActionButton.subtle(
                        label: _plainText(option),
                        labelContent: Text(
                          _plainText(option),
                          style: context.textTheme.labelLarge,
                        ),
                        isExpanded: true,
                        mainAxisAlignment: MainAxisAlignment.start,
                        onPressed: () => widget.onDone(option, null, false),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionWidgetView extends StatefulWidget {
  const _ExtensionWidgetView({
    super.key,
    required this.widgetKey,
    required this.lines,
    this.isBelowEditor = false,
  });
  final String widgetKey;
  final List<String> lines;
  final bool isBelowEditor;
  @override
  State<_ExtensionWidgetView> createState() => _ExtensionWidgetViewState();
}

class _ExtensionWidgetViewState extends State<_ExtensionWidgetView> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final cleanLines = widget.lines
        .map(_plainText)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (cleanLines.isEmpty) return const SizedBox.shrink();

    if (cleanLines.length == 1) {
      if (widget.isBelowEditor) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Text(
            cleanLines.first,
            style: textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
        );
      }
      return AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          cleanLines.first,
          style: textTheme.bodySmall?.copyWith(color: colors.textPrimary),
        ),
      );
    }

    final title = cleanLines.first
        .replaceFirst(RegExp(r'^[●○•\s]+'), '')
        .trim();
    final items = cleanLines.skip(1).toList();

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final keyLower = widget.widgetKey.toLowerCase();
    final headerIcon =
        keyLower.contains('lens') ||
            keyLower.contains('diag') ||
            keyLower.contains('lint')
        ? Icons.troubleshoot_rounded
        : keyLower.contains('todo') ||
              keyLower.contains('task') ||
              keyLower.contains('plan')
        ? Icons.checklist_rounded
        : Icons.widgets_outlined;

    final innerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isBelowEditor ? AppSpacing.xxs : AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  headerIcon,
                  size: widget.isBelowEditor ? 14 : 16,
                  color: widget.isBelowEditor
                      ? colors.textSecondary
                      : colors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  title,
                  style:
                      (widget.isBelowEditor
                              ? textTheme.labelSmall
                              : textTheme.labelMedium)
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: widget.isBelowEditor
                                ? colors.textSecondary
                                : colors.textPrimary,
                          ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: _expanded ? 0 : 0.5,
                  duration: reduceMotion ? Duration.zero : AppDurations.quick,
                  curve: AppCurves.smoothOut,
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 14,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: reduceMotion ? Duration.zero : AppDurations.quick,
          curve: AppCurves.smoothOut,
          alignment: Alignment.topLeft,
          clipBehavior: Clip.hardEdge,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in items)
                            _buildItemRow(context, item),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );

    if (widget.isBelowEditor) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: innerContent,
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: innerContent,
    );
  }

  Widget _buildItemRow(BuildContext context, String rawLine) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final line = rawLine.replaceFirst(RegExp(r'^[├└─│↳\s]+'), '').trim();
    if (line.isEmpty) return const SizedBox.shrink();
    if (line.startsWith('─') || line.startsWith('───')) {
      return Divider(height: AppSpacing.sm, color: colors.borderSubtle);
    }

    // 通用状态符号识别：不与特定插件或特定 todo 结构绑死
    final isCompleted =
        line.startsWith('✓') ||
        line.startsWith('✔') ||
        line.startsWith('[x]') ||
        line.startsWith('[X]');
    final isInProgress =
        line.startsWith('◐') ||
        line.startsWith('◒') ||
        line.startsWith('◓') ||
        line.startsWith('◔') ||
        line.startsWith('[-]');
    final isFailed =
        line.startsWith('✗') || line.startsWith('✘') || line.startsWith('[!]');
    final isWarning =
        line.startsWith('!') ||
        line.startsWith('⚠') ||
        line.startsWith('[w]') ||
        line.startsWith('[W]');
    final isBullet =
        line.startsWith('○') ||
        line.startsWith('•') ||
        line.startsWith('- ') ||
        line.startsWith('* ') ||
        line.startsWith('[ ]');

    final IconData? icon;
    final Color iconColor;
    if (isCompleted) {
      icon = Icons.check_circle_rounded;
      iconColor = colors.success;
    } else if (isInProgress) {
      icon = Icons.timelapse_rounded;
      iconColor = colors.primary;
    } else if (isFailed) {
      icon = Icons.cancel_outlined;
      iconColor = colors.error;
    } else if (isWarning) {
      icon = Icons.warning_amber_rounded;
      iconColor = colors.warning;
    } else if (isBullet) {
      icon = Icons.radio_button_unchecked;
      iconColor = colors.textMuted;
    } else {
      icon = null;
      iconColor = colors.textSecondary;
    }

    final displayText = line
        .replaceFirst(RegExp(r'^[✓✔◐◒◓◔✗✘○•\-*!⚠]\s*'), '')
        .replaceFirst(RegExp(r'^\[(x|X|\-|\!|w|W|\s)\]\s*'), '');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            SizedBox(
              width: widget.isBelowEditor ? AppSpacing.xs : AppSpacing.sm,
            ),
          ],
          Expanded(
            child: Text(
              displayText.isEmpty ? line : displayText,
              style:
                  (widget.isBelowEditor
                          ? textTheme.labelSmall
                          : textTheme.bodySmall)
                      ?.copyWith(
                        color: isCompleted
                            ? colors.textMuted
                            : (widget.isBelowEditor
                                  ? colors.textSecondary
                                  : colors.textPrimary),
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
