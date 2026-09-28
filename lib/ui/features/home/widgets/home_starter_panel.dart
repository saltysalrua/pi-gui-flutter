import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pi_gui/core/services/file_attachments.dart';
import 'package:pi_gui/ui/atoms/app_file_tile.dart';
import 'package:pi_gui/ui/atoms/app_menu_button.dart';
import 'package:pi_gui/ui/core/chat_resource_scope.dart';
import 'package:pi_gui/core/services/chat_resources.dart';
import 'package:pi_gui/ui/atoms/app_image.dart';

import '../controllers/image_attachment_controller.dart';
import '../controllers/slash_command_controller.dart';
import '../slash_commands.dart';
import 'slash_command_menu.dart';

import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

import 'context_usage_indicator.dart';

import 'package:pi_gui/core/slots/slot_manager.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/atoms/slot_container.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import 'package:pi_gui/ui/features/home/widgets/model_thinking_popover.dart';
import 'package:pi_gui/ui/features/home/controllers/model_picker_controller.dart';
import 'package:pi_gui/ui/features/home/model_picker_labels.dart';

/// Shared composer in both the empty and active conversation layouts.
class HomeStarterPanel extends StatefulWidget {
  const HomeStarterPanel({
    super.key,
    required this.modelPicker,
    required this.inputController,
    required this.attachments,
    required this.canSend,
    required this.isRunning,
    required this.onSendPrompt,
    required this.onStop,
    this.isStopping = false,
    this.onFollowUp,
    this.onRestoreQueue,
    this.minLines = 2,
    this.contextGateway,
    this.commands,
    this.onSlashBuiltin,
  });
  final PiContextGateway? contextGateway;
  final SlashCommandController? commands;

  /// GUI 分发内置斜杠命令（compact/new/name/历史动作）。返回 true 表示已处理。
  final Future<bool> Function(SlashBuiltinAction action, String args)?
  onSlashBuiltin;
  final ModelPickerController modelPicker;
  final TextEditingController inputController;
  final ImageAttachmentController attachments;
  final bool canSend, isRunning, isStopping;
  final int minLines;
  final VoidCallback onSendPrompt, onStop;
  final VoidCallback? onFollowUp, onRestoreQueue;
  @override
  State<HomeStarterPanel> createState() => _HomeStarterPanelState();
}

class _HomeStarterPanelState extends State<HomeStarterPanel> {
  late final FocusNode _focusNode;
  final GlobalKey _modelButtonKey = GlobalKey();
  final _slashPortal = OverlayPortalController();
  int _slashIndex = 0;
  String? _slashDismissed;
  String? _slashHint;
  String? _lastSlashQuery;
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final composing = widget.inputController.value.composing;
        if (composing.isValid && !composing.isCollapsed) {
          return KeyEventResult.ignored;
        }
        final keyboard = HardwareKeyboard.instance;
        if (keyboard.isShiftPressed || keyboard.isMetaPressed) {
          return KeyEventResult.ignored;
        }
        final alt = keyboard.isAltPressed;
        final ctrl = keyboard.isControlPressed;
        final key = event.logicalKey;
        if (!alt && !ctrl && _handleSlashKey(key)) {
          return KeyEventResult.handled;
        }
        if (!alt &&
            !ctrl &&
            key == LogicalKeyboardKey.escape &&
            widget.isRunning &&
            !widget.isStopping) {
          widget.onStop();
          return KeyEventResult.handled;
        }
        if (alt &&
            !ctrl &&
            (key == LogicalKeyboardKey.arrowUp ||
                key == LogicalKeyboardKey.keyQ)) {
          widget.onRestoreQueue?.call();
          return KeyEventResult.handled;
        }
        final followUp =
            alt && !ctrl && key == LogicalKeyboardKey.enter ||
            ctrl && !alt && key == LogicalKeyboardKey.keyQ;
        if (followUp && widget.onFollowUp != null) {
          if (_canSend) widget.onFollowUp!();
          return KeyEventResult.handled;
        }
        if (!alt && !ctrl && key == LogicalKeyboardKey.enter) {
          if (_canSend) unawaited(_sendPrompt());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
    _focusNode.addListener(_changed);
    widget.inputController.addListener(_changed);
    widget.attachments.addListener(_changed);
    widget.modelPicker.addListener(_changed);
  }

  /// 键盘驱动的斜杠菜单控制：Esc 关闭、↑↓ 选择、Tab/非精确 Enter 补全。
  /// 返回 true 表示已消费；非命令输入或精确匹配的 Enter 回落到正常发送。
  bool _handleSlashKey(LogicalKeyboardKey key) {
    final query = _slashQuery();
    if (query == null || !_slashPortal.isShowing) return false;
    if (key == LogicalKeyboardKey.escape) {
      _dismissSlash();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final entries = _slashEntries;
      if (entries.isEmpty) return false;
      final delta = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      final next = (entries.length + _slashIndex + delta) % entries.length;
      setState(() => _slashIndex = next);
      return true;
    }
    if (key == LogicalKeyboardKey.tab) {
      if (_slashEntries.isEmpty) return false;
      _completeSlash();
      return true;
    }
    if (key == LogicalKeyboardKey.enter) {
      final entries = _slashEntries;
      if (entries.isEmpty || hasExactSlashEntry(entries, query)) {
        return false;
      }
      _completeSlash();
      return true;
    }
    return false;
  }

  bool get _imageModelBlocked =>
      widget.attachments.items.isNotEmpty &&
      widget.modelPicker.selectedModel?.supportsImages == false;
  bool get _canSend =>
      widget.canSend &&
      !widget.attachments.isPicking &&
      !_imageModelBlocked &&
      (widget.inputController.text.trim().isNotEmpty ||
          widget.attachments.hasAttachments);
  void _changed() {
    if (!mounted) return;
    _syncSlashMenu();
    setState(() {});
  }

  /// 菜单可见性：行首是 / 命令且光标仍在首个 token 内，未被 Esc 关闭。
  String? _slashQuery() {
    final controller = widget.commands;
    if (controller == null) return null;
    final value = widget.inputController.value;
    if (!value.selection.isCollapsed) return null;
    return slashMenuQuery(value.text, value.selection.baseOffset);
  }

  List<SlashMenuEntry> get _slashEntries {
    final controller = widget.commands;
    final query = _slashQuery();
    if (controller == null || query == null) return const [];
    return filterSlashEntries(
      mergeSlashEntries(builtinSlashEntries(context.l10n), controller.commands),
      query,
    );
  }

  void _syncSlashMenu() {
    final query = _slashQuery();
    if (query != _lastSlashQuery) {
      _lastSlashQuery = query;
      _slashIndex = 0;
      _slashHint = null;
      _slashDismissed = null;
    }
    final visible =
        _focusNode.hasFocus && query != null && query != _slashDismissed;
    if (visible) {
      unawaited(widget.commands!.ensureLoaded());
      _showPortal();
    } else if (_slashPortal.isShowing) {
      _slashPortal.hide();
    }
  }

  void _showPortal() {
    // 在 Overlay 首帧前调用会断言；静默忽略后由下一个文本事件重试。
    try {
      _slashPortal.show();
    } on AssertionError {
      /* 尚未挂载，忽略。 */
    }
  }

  void _dismissSlash() {
    _slashDismissed = _slashQuery() ?? '';
    if (_slashPortal.isShowing) _slashPortal.hide();
    setState(() {});
  }

  /// 把选中条目写回输入：替换首个 token，保留已输入参数，光标留在空格后。
  void _completeSlash() {
    final entries = _slashEntries;
    if (entries.isEmpty) return;
    final index = _slashIndex < entries.length ? _slashIndex : 0;
    final entry = entries[index];
    final input = widget.inputController;
    final text = input.text;
    final boundary = text.indexOf(RegExp(r'\s'));
    final args = boundary < 0 ? '' : text.substring(boundary).trim();
    final next = '/${entry.name} $args';
    input.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: entry.name.length + 2),
    );
    _focusNode.requestFocus();
  }

  void _showSlashHint(String name) {
    if (!mounted) return;
    setState(() => _slashHint = name);
  }

  void _showModelPicker() {
    if (!mounted) return;
    unawaited(
      showModelThinkingPopover(
        context: context,
        anchorKey: _modelButtonKey,
        controller: widget.modelPicker,
      ),
    );
  }

  /// 发送前分发：远端命令（get_commands 实测存在）照常走 prompt；GUI 有
  /// 等价操作的内置命令本地执行；终端专用命令拦截并提示，绝不喂给模型。
  Future<void> _sendPrompt() async {
    final controller = widget.commands;
    final input = widget.inputController;
    if (controller != null) {
      final token = parseSlashToken(input.text);
      if (token != null) {
        // 拦截前先拿到权威列表；缓存未加载时绝不能误拦远端命令。
        await controller.ensureLoaded();
        if (controller.isReady &&
            controller.commands.any((c) => c.name == token.name)) {
          widget.onSendPrompt();
          return;
        }
        final action = slashBuiltinActionFor(token.name);
        if (action == SlashBuiltinAction.model) {
          input.clear();
          _showModelPicker();
          return;
        }
        if (action != null) {
          final handled =
              await widget.onSlashBuiltin?.call(action, token.args) ?? false;
          if (handled &&
              mounted &&
              parseSlashToken(input.text)?.name == token.name) {
            input.clear();
          }
          return;
        }
        if (controller.isReady && isTerminalOnlySlashCommand(token.name)) {
          _showSlashHint(token.name);
          return;
        }
      }
    }
    widget.onSendPrompt();
  }

  @override
  void dispose() {
    widget.inputController.removeListener(_changed);
    widget.attachments.removeListener(_changed);
    widget.modelPicker.removeListener(_changed);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlotContainer(
          slotId: ExtensibleSlotId.aboveEditor,
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        OverlayPortal.overlayChildLayoutBuilder(
          controller: _slashPortal,
          overlayChildBuilder: _buildSlashOverlay,
          child: AppCard.elevated(
            key: SlotManager.of(context).editorAnchor,
            backgroundColor: context.colors.composerBackground,
            borderColor: _focusNode.hasFocus
                ? context.colors.borderFocus
                : null,
            child: _editorCard(context),
          ),
        ),
        const SlotContainer(
          slotId: ExtensibleSlotId.belowEditor,
          padding: EdgeInsets.only(top: AppSpacing.xs),
        ),
        const SlotContainer(
          slotId: ExtensibleSlotId.statusBar,
          direction: Axis.horizontal,
          alignment: WrapAlignment.start,
          padding: EdgeInsets.only(top: AppSpacing.xs),
        ),
      ],
    );
  }

  /// 输入卡片内容：附件行、失败/斜杠提示、文本框与操作行。
  Widget _editorCard(BuildContext context) {
    final l10n = context.l10n;
    final attachments = widget.attachments;
    final imageFailure = _imageModelBlocked
        ? l10n.chatImageModel
        : switch (attachments.failure) {
            ImageFailure.unreadable => l10n.chatImagePickFailed,
            ImageFailure.format => l10n.chatImageFormat,
            ImageFailure.tooLarge => l10n.chatImageTooLarge,
            ImageFailure.tooMany => l10n.chatImageTooMany,
            null => null,
          };
    final fileFailure = switch (attachments.fileFailure) {
      FileAttachmentFailure.unreadable => l10n.chatFilePickFailed,
      FileAttachmentFailure.tooLarge => l10n.chatFileTooLarge,
      FileAttachmentFailure.tooMany => l10n.chatFileTooMany,
      null => attachments.pasteFailed ? l10n.chatPasteFailed : null,
    };
    final failure = imageFailure ?? fileFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppDurations.fast,
          curve: AppCurves.smoothOut,
          alignment: Alignment.topLeft,
          child: !attachments.hasAttachments
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SizedBox(
                    height: AppImage.compactHeight(context),
                    child: ListView.separated(
                      primary: false,
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          attachments.items.length + attachments.files.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        if (index >= attachments.items.length) {
                          final file = attachments
                              .files[index - attachments.items.length];
                          return AppFileTile(
                            key: ObjectKey(file),
                            name: file.name,
                            detail: l10n.chatAttachmentSize(
                              NumberFormat(
                                '0.##',
                                l10n.localeName,
                              ).format(file.size / (1024 * 1024)),
                            ),
                            tooltip:
                                '${file.name}\n${l10n.chatFileAttachmentHint}',
                            onOpen: () => ChatResourceScope.open(
                              context,
                              Uri.file(file.path).toString(),
                            ),
                            onRemove: () => attachments.removeFile(file),
                          );
                        }
                        final attachment = attachments.items[index];
                        return SizedBox(
                          width: AppImage.compactWidth,
                          child: AppImage(
                            key: ObjectKey(attachment),
                            bytes: attachment.bytes,
                            label: attachment.name,
                            compact: true,
                            onRemove: () => attachments.remove(attachment),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
        if (failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              failure,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.warning,
              ),
            ),
          ),
        if (_slashHint case final blocked?)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              context.l10n.slashCommandUnsupported(blocked),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.warning,
              ),
            ),
          ),
        AppTextField(
          controller: widget.inputController,
          focusNode: _focusNode,
          hintText: widget.isRunning
              ? l10n.chatQueuePlaceholder
              : l10n.inputPlaceholder,
          minLines: widget.minLines,
          maxLines: 7,
          borderless: true,
          onPaste: () => attachments.paste(l10n.chatPasteImage),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            AppMenuButton<bool>(
              icon: Icons.add_rounded,
              tooltip: l10n.chatAddAttachment,
              isBusy: attachments.isPicking,
              options: [
                AppMenuOption(
                  value: true,
                  label: l10n.chatAddImages,
                  icon: Icons.image_outlined,
                ),
                AppMenuOption(
                  value: false,
                  label: l10n.chatAddFiles,
                  icon: Icons.attach_file_rounded,
                ),
              ],
              onSelected: (images) async {
                if (images) {
                  await attachments.choose(l10n.chatImage);
                } else {
                  await attachments.chooseFiles();
                }
                if (mounted) _focusNode.requestFocus();
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: ListenableBuilder(
                  listenable: widget.modelPicker,
                  builder: (context, _) {
                    final picker = widget.modelPicker;
                    final model = picker.selectedModel;
                    final level = picker.thinkingLevel;
                    final label = picker.failure != null
                        ? (picker.isReconnecting
                              ? l10n.piReconnecting
                              : l10n.modelRefresh)
                        : model == null
                        ? picker.isBusy
                              ? l10n.modelsLoading
                              : l10n.modelNoSelection
                        : level == null
                        ? model.name
                        : l10n.modelAndThinking(
                            model.name,
                            thinkingLevelLabel(l10n, level),
                          );
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ContextUsageIndicator(gateway: widget.contextGateway),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: AppActionButton.subtle(
                            key: _modelButtonKey,
                            label: label,
                            labelStyle: context.textTheme.labelMedium,
                            height: 28,
                            iconSize: 14,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            trailing: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                            ),
                            onPressed: widget.isRunning
                                ? null
                                : () => showModelThinkingPopover(
                                    context: context,
                                    anchorKey: _modelButtonKey,
                                    controller: picker,
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppDurations.fast,
              reverseDuration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppDurations.quick,
              switchInCurve: AppCurves.smoothOut,
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                axis: Axis.horizontal,
                alignment: Alignment.centerRight,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: !widget.isRunning
                  ? const SizedBox.shrink(key: ValueKey(false))
                  : Row(
                      key: const ValueKey(true),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIconButton.subtle(
                          icon: Icons.stop_rounded,
                          tooltip: l10n.chatQueueStop,
                          onPressed: widget.isStopping ? null : widget.onStop,
                        ),
                        if (widget.onFollowUp != null)
                          AppMenuButton<bool>(
                            icon: Icons.keyboard_arrow_down_rounded,
                            tooltip: l10n.chatQueueSendOptions,
                            options: [
                              AppMenuOption(
                                value: false,
                                label: l10n.chatQueueSteerAction,
                                icon: Icons.subdirectory_arrow_right,
                              ),
                              AppMenuOption(
                                value: true,
                                label: l10n.chatQueueFollowUpAction,
                                icon: Icons.playlist_add,
                              ),
                            ],
                            onSelected: !_canSend
                                ? null
                                : (followUp) {
                                    // Recheck after the menu closes; state may have
                                    // changed while the popup route was open.
                                    if (!_canSend) return;
                                    if (followUp) {
                                      widget.onFollowUp!();
                                    } else {
                                      unawaited(_sendPrompt());
                                    }
                                  },
                          ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                    ),
            ),
            AppIconButton.primaryCircle(
              icon: Icons.arrow_upward_rounded,
              tooltip: widget.isRunning
                  ? l10n.chatQueueSteerAction
                  : l10n.sendMessage,
              onPressed: _canSend ? () => unawaited(_sendPrompt()) : null,
            ),
          ],
        ),
      ],
    );
  }

  /// 布局阶段读取卡片坐标，窗口缩放/输入框增高时同帧重新限位。
  Widget _buildSlashOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final query = _slashQuery();
    if (!_focusNode.hasFocus || query == null || query == _slashDismissed) {
      return const SizedBox.shrink();
    }
    final anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    final safe = MediaQuery.paddingOf(context);
    final leftEdge = safe.left + AppSpacing.md;
    final rightEdge = info.overlaySize.width - safe.right - AppSpacing.md;
    final width = math.min(anchor.width, rightEdge - leftEdge);
    final maxHeight = math.min(
      320.0,
      anchor.top - AppSpacing.sm - safe.top - AppSpacing.md,
    );
    // 没有可绘制的空间就不展示，不能用最低高度反向撑出窗口。
    if (width <= 0 || maxHeight <= AppSpacing.md) {
      return const SizedBox.shrink();
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Positioned 解除 Overlay 的全屏 tight 约束；宽高必须约束整张菜单卡片。
    return Positioned(
      left: anchor.left.clamp(leftEdge, rightEdge - width),
      bottom: info.overlaySize.height - anchor.top + AppSpacing.sm,
      width: width,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: reduceMotion ? Duration.zero : AppDurations.fast,
        curve: AppCurves.smoothOut,
        builder: (context, progress, child) => Opacity(
          opacity: progress,
          child: Transform.scale(
            scale:
                AppMotionScales.dropdown +
                (1 - AppMotionScales.dropdown) * progress,
            alignment: Alignment.bottomLeft,
            child: child,
          ),
        ),
        child: ListenableBuilder(
          listenable: widget.commands!,
          builder: (context, _) {
            // 命令列表加载完成时在这里重算，避免闭包里的旧条目。
            final entries = _slashEntries;
            return SlashCommandMenu(
              controller: widget.commands!,
              entries: entries,
              selectedIndex: _slashIndex < entries.length ? _slashIndex : 0,
              onSelected: (index) {
                setState(() => _slashIndex = index);
                _completeSlash();
              },
              width: width,
              maxHeight: maxHeight,
            );
          },
        ),
      ),
    );
  }
}
