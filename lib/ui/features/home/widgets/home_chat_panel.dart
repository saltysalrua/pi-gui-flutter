import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pi_gui/core/services/file_attachments.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_activity_label.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_composer_layout.dart';
import 'package:pi_gui/ui/atoms/app_disclosure.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_split_panel.dart';
import 'package:pi_gui/ui/atoms/app_document_tabs.dart';
import 'package:pi_gui/ui/atoms/app_tab_workspace.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

import '../controllers/chat_controller.dart';
import '../controllers/model_picker_controller.dart';
import '../controllers/image_attachment_controller.dart';
import '../controllers/workspace_browser_controller.dart';
import '../controllers/workspace_tabs_controller.dart';
import 'workspace_browser_panel.dart';
import 'workspace_document_view.dart';
import 'chat_message_view.dart';
import 'home_starter_panel.dart';
import 'tool_card_registry.dart';

class HomeChatPanel extends StatefulWidget {
  const HomeChatPanel({
    super.key,
    required this.chat,
    required this.modelPicker,
    required this.input,
    required this.attachments,
    required this.project,
    required this.registry,
    required this.browser,
    required this.tabs,
    required this.contentBackground,
    required this.panelBackground,
    this.animateMaterial = true,
  });
  final ChatController chat;
  final ModelPickerController modelPicker;
  final TextEditingController input;
  final ImageAttachmentController attachments;
  final String project;
  final ToolCardRegistry registry;
  final WorkspaceBrowserController browser;
  final WorkspaceTabsController tabs;
  final Color contentBackground, panelBackground;
  final bool animateMaterial;
  @override
  State<HomeChatPanel> createState() => _HomeChatPanelState();
}

class _HomeChatPanelState extends State<HomeChatPanel> {
  final _scroll = ScrollController();
  bool _following = true;
  String? _session;
  @override
  void initState() {
    super.initState();
    widget.chat.addListener(_updated);
    _scroll.addListener(_scrolled);
  }

  void _scrolled() {
    final follow = _scroll.position.pixels < 80;
    if (follow != _following && mounted) setState(() => _following = follow);
  }

  void _updated() {
    if (_session != widget.chat.sessionFile) {
      _session = widget.chat.sessionFile;
      _following = true;
    }
    if (_following) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients && _following) _scroll.jumpTo(0);
      });
    }
  }

  Future<void> _send() async {
    final draft = widget.input.value;
    final attachments = widget.attachments.items;
    final files = widget.attachments.files;
    if (widget.attachments.isPicking ||
        attachments.isNotEmpty &&
            widget.modelPicker.selectedModel?.supportsImages == false) {
      return;
    }
    final accepted = await widget.chat.send(
      FileAttachmentPrompt.compose(draft.text, files),
      images: attachments.map((a) => a.image).toList(),
    );
    if (!mounted) return;
    // Preserve subsequent typing and set_editor_text extension updates.
    if (accepted) {
      if (widget.input.value == draft) widget.input.clear();
      widget.attachments.accept(attachments, files: files);
    }
  }

  Future<void> _stop() async {
    final restored = await widget.chat.stop();
    if (!mounted || restored.isEmpty) return;
    widget.input.text = [
      widget.input.text,
      ...restored,
    ].where((s) => s.isNotEmpty).join('\n\n');
  }

  @override
  void dispose() {
    widget.chat.removeListener(_updated);
    _scroll.dispose();
    super.dispose();
  }

  Widget _header(BuildContext context) {
    final chat = widget.chat;
    final l10n = context.l10n;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, color: colors.textSecondary, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Tooltip(
              message: chat.title.isEmpty ? widget.project : chat.title,
              child: Text(
                chat.title.isEmpty ? widget.project : chat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleSmall,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppIconButton.subtle(
            icon: Icons.refresh,
            tooltip: l10n.chatRefresh,
            onPressed: chat.isLoading || chat.isSending ? null : chat.refresh,
          ),
        ],
      ),
    );
  }

  Widget _browserButton(BuildContext context) => AppIconButton(
    icon: Icons.snippet_folder_outlined,
    tooltip: context.l10n.browserTitle,
    color: widget.browser.isOpen ? context.colors.primary : null,
    onPressed: widget.browser.toggle,
  );

  Widget _timeline(BuildContext context) {
    final chat = widget.chat;
    final assistantNumbers = chat.timeline.assistantNumbers;
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.sm,
          ),
          itemCount: chat.timeline.messages.length,
          itemBuilder: (context, reverseIndex) {
            final index = chat.timeline.messages.length - 1 - reverseIndex;
            final message = chat.timeline.messages[index];
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ChatMessageView(
                  key: ValueKey('${message.timestamp}-$index'),
                  message: message,
                  assistantNumber: assistantNumbers[index],
                  thinkingIndex: chat.timeline.thinkingIndexFor(index),
                  tools: chat.timeline.tools,
                  registry: widget.registry,
                  onShowChanges: (path) => widget.browser.showFiles(path),
                ),
              ),
            );
          },
        ),
        if (!_following)
          Positioned(
            bottom: AppSpacing.sm,
            right: AppSpacing.xxl,
            child: AppActionButton.pill(
              label: context.l10n.chatLatest,
              leading: const Icon(Icons.arrow_downward),
              onPressed: () {
                setState(() => _following = true);
                if (!_scroll.hasClients) return;
                if (MediaQuery.disableAnimationsOf(context)) {
                  _scroll.jumpTo(0);
                } else {
                  unawaited(
                    _scroll.animateTo(
                      0,
                      duration: AppDurations.fast,
                      curve: AppCurves.smoothOut,
                    ),
                  );
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _editor(BuildContext context, bool started) {
    final chat = widget.chat;
    final l10n = context.l10n;
    final failureText = switch (chat.failure) {
      ChatFailure.load => l10n.chatLoadFailed,
      ChatFailure.send => l10n.chatSendFailed,
      ChatFailure.reply => l10n.chatReplyFailed,
      ChatFailure.disconnected => l10n.piDisconnected,
      ChatFailure.uncertain => l10n.chatUncertain,
      ChatFailure.stop => l10n.chatStopFailed,
      ChatFailure.cancelled => l10n.chatSessionCancelled,
      ChatFailure.invalidEvent => l10n.chatInvalidEvent,
      null => null,
    };
    final activityText = chat.isLoading
        ? l10n.chatLoading
        : chat.isSending
        ? l10n.modelUpdating
        : switch (chat.activity) {
            ChatActivity.idle =>
              chat.isReady ? l10n.chatReady : l10n.piNotConnected,
            ChatActivity.working => l10n.chatWorking,
            ChatActivity.retrying => l10n.chatRetrying,
            ChatActivity.compacting => l10n.chatCompacting,
            ChatActivity.stopping => l10n.chatStopping,
          };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!started)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 15,
                    color: context.colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    widget.project,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          if (failureText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                borderColor: context.colors.warning.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        failureText,
                        style: context.textTheme.bodySmall,
                      ),
                    ),
                    AppIconButton.subtle(
                      icon: Icons.refresh,
                      tooltip: l10n.chatRefresh,
                      onPressed: chat.isLoading || chat.isSending
                          ? null
                          : chat.refresh,
                    ),
                    AppIconButton.subtle(
                      icon: Icons.close,
                      tooltip: l10n.close,
                      onPressed: chat.dismissFailure,
                    ),
                  ],
                ),
              ),
            ),
          if (chat.queue.all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppDisclosure(
                title: l10n.chatQueued,
                builder: (_) => Text(
                  chat.queue.all.join('\n\n'),
                  style: context.textTheme.bodySmall,
                ),
              ),
            ),
          if (((started && chat.activity != ChatActivity.idle) ||
                  chat.isLoading ||
                  !chat.isReady) &&
              activityText != l10n.chatReady)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppActivityLabel(
                text: activityText,
                active: chat.isRunning || chat.isLoading || chat.isSending,
              ),
            ),
          HomeStarterPanel(
            modelPicker: widget.modelPicker,
            inputController: widget.input,
            attachments: widget.attachments,
            canSend: chat.canSend,
            isRunning: chat.isRunning,
            isStopping: chat.activity == ChatActivity.stopping,
            onSendPrompt: _send,
            onStop: _stop,
            minLines: started ? 2 : 4,
          ),
        ],
      ),
    );
  }

  AppDocumentTab<WorkspaceDocument> _describeTab(
    BuildContext context,
    WorkspaceDocument doc,
  ) {
    final l10n = context.l10n;
    if (doc.kind == WorkspaceDocumentKind.chat) {
      return AppDocumentTab(
        id: doc,
        label: l10n.tabsChat,
        tooltip: widget.chat.title.isEmpty ? l10n.tabsChat : widget.chat.title,
        icon: Icons.chat_bubble_outline,
        closable: false,
        busy: widget.chat.isRunning,
      );
    }
    final short = doc.commit?.substring(0, 7);
    if (doc.kind == WorkspaceDocumentKind.commit) {
      return AppDocumentTab(
        id: doc,
        label: '${l10n.browserCommitDetails} · $short',
        tooltip: '${l10n.browserCommitDetails}\n${doc.commit}',
        icon: Icons.commit,
      );
    }
    final parts = doc.path!.split('/');
    var label = parts.last;
    if (parts.length > 1 &&
        widget.tabs.tabs.any(
          (other) =>
              other.path != null &&
              other.path != doc.path &&
              other.path!.split('/').last == parts.last,
        )) {
      label = parts.skip(parts.length - 2).join('/');
    }
    return AppDocumentTab(
      id: doc,
      label: short == null ? label : '$label · $short',
      tooltip: [doc.path!, if (doc.commit != null) doc.commit!].join('\n'),
      icon: doc.commit == null
          ? Icons.description_outlined
          : Icons.difference_outlined,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.chat, widget.browser]),
    builder: (context, _) {
      final chat = widget.chat;
      // Keep the original centered empty composer. Only an accepted/submitting
      // first prompt enters the bottom-docked conversation layout.
      final started =
          chat.timeline.messages.isNotEmpty || chat.isSending || chat.isRunning;
      final conversation = AppComposerLayout(
        started: started,
        content: Column(
          children: [
            _header(context),
            Expanded(child: _timeline(context)),
          ],
        ),
        editor: _editor(context, started),
      );
      return AppSplitPanel(
        isOpen: widget.browser.isOpen,
        onDismiss: widget.browser.toggle,
        contentBackground: widget.contentBackground,
        panelBackground: widget.panelBackground,
        animateMaterial: widget.animateMaterial,
        panel: WorkspaceBrowserPanel(
          controller: widget.browser,
          onOpenFile: widget.tabs.openFile,
          onOpenCommit: widget.tabs.openCommit,
        ),
        child: AppTabWorkspace<WorkspaceDocument>(
          controller: widget.tabs,
          describeTab: (doc) => _describeTab(context, doc),
          trailing: _browserButton(context),
          builder: (context, doc) => doc.kind == WorkspaceDocumentKind.chat
              ? conversation
              : WorkspaceDocumentView(document: doc, tabs: widget.tabs),
        ),
      );
    },
  );
}
