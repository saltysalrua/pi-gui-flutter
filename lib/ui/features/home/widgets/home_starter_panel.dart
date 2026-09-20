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
  });
  final PiContextGateway? contextGateway;
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
          if (_canSend) widget.onSendPrompt();
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
    if (mounted) setState(() {});
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlotContainer(
          slotId: ExtensibleSlotId.aboveEditor,
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        AppCard.elevated(
          key: SlotManager.of(context).editorAnchor,
          backgroundColor: context.colors.composerBackground,
          borderColor: _focusNode.hasFocus ? context.colors.borderFocus : null,
          child: Column(
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
                                attachments.items.length +
                                attachments.files.length,
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
                                  onRemove: () =>
                                      attachments.remove(attachment),
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
                              ContextUsageIndicator(
                                gateway: widget.contextGateway,
                              ),
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
                                onPressed: widget.isStopping
                                    ? null
                                    : widget.onStop,
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
                                            widget.onSendPrompt();
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
                    onPressed: _canSend ? widget.onSendPrompt : null,
                  ),
                ],
              ),
            ],
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
}
