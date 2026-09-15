import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pi_gui/core/services/file_attachments.dart';
import 'package:pi_gui/ui/atoms/app_file_tile.dart';
import 'package:pi_gui/ui/core/chat_resource_scope.dart';
import 'package:pi_gui/core/models/chat_timeline.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/utils/terminal_text.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_activity_label.dart';
import 'package:pi_gui/ui/atoms/app_code_block.dart';
import 'package:pi_gui/ui/atoms/app_copy_button.dart';
import 'package:pi_gui/ui/atoms/app_disclosure.dart';
import 'package:pi_gui/ui/atoms/app_markdown.dart';
import 'package:pi_gui/ui/atoms/app_image.dart';
import 'package:pi_gui/ui/atoms/app_step_group.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import 'tool_card_registry.dart';

class ChatMessageView extends StatelessWidget {
  const ChatMessageView({
    super.key,
    required this.message,
    required this.assistantNumber,
    required this.tools,
    required this.registry,
    required this.onShowChanges,
    this.thinkingIndex,
  });
  final PiChatMessage message;
  final int? assistantNumber, thinkingIndex;
  final Map<String, ChatToolCall> tools;
  final ToolCardRegistry registry;
  final ValueChanged<String> onShowChanges;

  Widget _userText(BuildContext context, String text) {
    final parsed = FileAttachmentPrompt.parse(text);
    final visible = parsed?.text ?? text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visible.isNotEmpty)
          SelectionArea(
            child: Text(visible, style: context.textTheme.bodyLarge),
          ),
        if (parsed != null) ...[
          if (visible.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final file in parsed.files)
                SizedBox(
                  height: AppImage.compactHeight(context),
                  child: AppFileTile(
                    name: file.name,
                    detail: context.l10n.chatAttachmentSize(
                      NumberFormat(
                        '0.##',
                        context.l10n.localeName,
                      ).format(file.size / (1024 * 1024)),
                    ),
                    tooltip: file.path,
                    onOpen: () => ChatResourceScope.open(
                      context,
                      Uri.file(file.path).toString(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = message.role == 'user';
    final children = <Widget>[];
    final steps = <Widget>[];
    var groupStart = 0;
    void flushSteps() {
      if (steps.isEmpty) return;
      children.add(
        AppStepGroup(
          key: ValueKey('steps-$groupStart'),
          children: List.of(steps),
        ),
      );
      steps.clear();
    }

    for (var i = 0; i < message.content.length; i++) {
      final block = message.content[i];
      // Empty streaming text must not split a chain or add a blank gap.
      if (block.kind == PiContentKind.text && block.text.isEmpty) continue;
      final step =
          block.kind == PiContentKind.thinking ||
          block.kind == PiContentKind.toolCall;
      if (!step) flushSteps();
      final child = switch (block.kind) {
        PiContentKind.text =>
          block.text.isEmpty
              ? const SizedBox.shrink()
              : user
              ? _userText(context, block.text)
              : message.role == 'bashExecution'
              ? AppCodeBlock(code: block.text, label: l10n.chatBash)
              : AppMarkdown(data: block.text),
        PiContentKind.thinking => AppDisclosure(
          key: PageStorageKey('thinking-${message.timestamp}-$i'),
          title: l10n.chatThinking,
          framed: false,
          titleContent: AppActivityLabel(
            text: l10n.chatThinking,
            active: message.isStreaming && thinkingIndex == i,
            maxLines: 1,
            style: context.textTheme.labelLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          builder: (_) => ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              primary: false,
              child: AppMarkdown(data: stripTerminalControls(block.text)),
            ),
          ),
        ),
        PiContentKind.toolCall => registry.build(
          context,
          tools[block.id] ??
              ChatToolCall(
                id: block.id,
                name: block.name,
                arguments: block.arguments,
              ),
          showChanges: tools[block.id]?.isFileChange == true
              ? () => onShowChanges(tools[block.id]!.path!)
              : null,
        ),
        PiContentKind.image => AppImage(image: block.image),
        PiContentKind.unknown => Text(
          l10n.chatUnsupportedContent,
          style: context.textTheme.bodySmall,
        ),
      };
      if (step) {
        if (steps.isEmpty) groupStart = i;
        steps.add(child);
      } else {
        children.add(KeyedSubtree(key: ValueKey('block-$i'), child: child));
      }
    }
    flushSteps();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              user ? Icons.person_outline : Icons.auto_awesome_outlined,
              size: 16,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                user
                    ? l10n.chatYou
                    : message.role == 'assistant' && assistantNumber != null
                    ? l10n.chatAssistantNumber(assistantNumber!)
                    : message.role == 'bashExecution'
                    ? l10n.chatBash
                    : l10n.chatOutput,
                style: context.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (message.text.isNotEmpty && !message.isStreaming)
              AppCopyButton(text: message.text),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: children,
        ),
        if (message.stopReason == 'aborted' ||
            message.stopReason == 'length' ||
            message.stopReason == 'error') ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            message.stopReason == 'aborted'
                ? l10n.chatAborted
                : message.stopReason == 'length'
                ? l10n.chatLengthLimit
                : l10n.chatReplyFailed,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.warning,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: user
          ? AppCard(
              backgroundColor: context.colors.userMessageBackground,
              child: content,
            )
          : content,
    );
  }
}
