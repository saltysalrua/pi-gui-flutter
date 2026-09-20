import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_history_types.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';

import '../controllers/workbench_controller.dart';
import 'history_dialog.dart';

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
import 'package:pi_gui/ui/core/chat_tool_output_scope.dart';
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
    this.conversationOnly = false,
    this.sharedDirectoryWarning = false,
    this.hibernating = false,
    this.waking = false,
    this.onWake,
    this.session,
  });
  final ChatController chat;
  final WorkbenchSession? session;
  final ModelPickerController modelPicker;
  final TextEditingController input;
  final ImageAttachmentController attachments;
  final String project;
  final ToolCardRegistry registry;
  final WorkspaceBrowserController browser;
  final WorkspaceTabsController tabs;
  final Color contentBackground, panelBackground;
  final bool animateMaterial, conversationOnly, sharedDirectoryWarning;

  /// The session's Pi process was hibernated to free memory; the editor shows
  /// a wake card instead of the stale connection failure.
  final bool hibernating, waking;
  final VoidCallback? onWake;
  @override
  State<HomeChatPanel> createState() => _HomeChatPanelState();
}

class _HomeChatPanelState extends State<HomeChatPanel> {
  final _scroll = ScrollController();
  static const _followThreshold = 80.0;
  bool _following = true;
  bool _restored = false;
  String? _session;
  int _historyRevision = 0;
  @override
  void initState() {
    super.initState();
    // Tab bodies unmount while inactive. A remount is not a conversation
    // switch, so the follow flag must come from the restored scroll anchor
    // instead of resetting to the latest message.
    _session = widget.chat.sessionFile;
    widget.chat.addListener(_updated);
    _scroll.addListener(_scrolled);
    _scheduleRestore();
  }

  /// Re-reads the follow flag from the PageStorage-restored offset once the
  /// timeline has clients; retries on the next chat notification otherwise.
  void _scheduleRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final follow = _scroll.position.pixels < _followThreshold;
      _restored = true;
      if (follow != _following) setState(() => _following = follow);
    });
  }

  void _scrolled() {
    final follow = _scroll.position.pixels < _followThreshold;
    if (follow != _following && mounted) setState(() => _following = follow);
  }

  void _updated() {
    if (_session != widget.chat.sessionFile ||
        _historyRevision != (widget.session?.historyRevision ?? 0)) {
      _session = widget.chat.sessionFile;
      _historyRevision = widget.session?.historyRevision ?? 0;
      _following = true;
    }
    if (!_restored) _scheduleRestore();
    if (_following) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scroll.hasClients &&
            _following &&
            _scroll.offset != 0) {
          _scroll.jumpTo(0);
        }
      });
    }
  }

  Future<void> _showHistory([
    PiChatMessage? message,
    PiHistoryAction action = PiHistoryAction.navigate,
  ]) async {
    final session = widget.session;
    if (session == null || session.history.isOpen || session.hibernating) {
      return;
    }
    await showAppDialog<void>(
      context,
      (_) => HistoryDialog(
        controller: session.history,
        hasDraft: () => session.hasDraft,
        message: message,
        initialAction: action,
        onAbort: session.client.abort,
      ),
    );
  }

  Future<void> _restoreHistoryDraft() async {
    final session = widget.session;
    if (session == null) return;
    final confirmed =
        !session.hasDraft ||
        await showAppDialog<bool>(
              context,
              (context) => AppDialog(
                title: context.l10n.historyRestoreDraft,
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
                child: Text(
                  context.l10n.historyDraftWarning,
                  style: context.textTheme.bodyMedium,
                ),
              ),
            ) ==
            true;
    if (confirmed && mounted) setState(session.restoreHistoryDraft);
  }

  Widget _historyButton(BuildContext context) => AppIconButton.subtle(
    icon: Icons.history,
    tooltip: context.l10n.historyTitle,
    onPressed: widget.session == null || widget.hibernating
        ? null
        : () => _showHistory(),
  );

  Future<void> _send([
    PiStreamingBehavior behavior = PiStreamingBehavior.steer,
  ]) async {
    final owner = widget.session;
    final input = widget.input;
    final attachmentController = widget.attachments;
    final draft = input.value;
    final attachments = attachmentController.items;
    final files = attachmentController.files;
    if (widget.attachments.isPicking ||
        attachments.isNotEmpty &&
            widget.modelPicker.selectedModel?.supportsImages == false) {
      return;
    }
    final accepted = await widget.chat.send(
      FileAttachmentPrompt.compose(draft.text, files),
      images: attachments.map((a) => a.image).toList(),
      streamingBehavior: behavior,
    );
    if (owner?.disposed == true || owner == null && !mounted) return;
    // The pane may have unmounted during a tab switch. Complete against the
    // captured session draft, preserving new typing and extension updates.
    if (accepted) {
      if (input.value == draft) input.clear();
      attachmentController.accept(attachments, files: files);
    }
  }

  Future<void> _restoreQueue({bool stop = false}) async {
    final owner = widget.session;
    final input = widget.input;
    final restored = await (stop
        ? widget.chat.stop()
        : widget.chat.takeQueue());
    if (owner?.disposed == true ||
        owner == null && !mounted ||
        restored.isEmpty) {
      return;
    }
    final text = [
      ...restored,
      input.text,
    ].where((s) => s.isNotEmpty).join('\n\n');
    input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
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
          if (widget.session != null) _historyButton(context),
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

  Widget _timeline(BuildContext context) => ListenableBuilder(
    listenable: widget.chat.timelineChanges,
    builder: (context, _) {
      _updated();
      return _timelineBody(context);
    },
  );

  Widget _timelineBody(BuildContext context) {
    final chat = widget.chat;
    final assistantNumbers = chat.timeline.assistantNumbers;
    // Tool rows pin expanded outputs against the session byte budget and can
    // ask for a history re-read after an old output was released.
    return ChatToolOutputScope(
      reload: chat.reloadToolOutput,
      setPinned: chat.pinToolOutput,
      child: Stack(
        children: [
          ListView.builder(
            // Explicit anchor: ScrollPosition only persists when a
            // PageStorageKey exists between the scrollable and the pane bucket,
            // so the timeline survives tab-body unmounts with its offset.
            key: const PageStorageKey('chat-timeline'),
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
                    onHistory: widget.session == null ? null : _showHistory,
                    historyEnabled:
                        !widget.hibernating &&
                        widget.session?.history.busy != true,
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
      ),
    );
  }

  Widget _editor(BuildContext context, bool started) {
    final chat = widget.chat;
    final l10n = context.l10n;
    final failureText = switch (chat.failure) {
      ChatFailure.load => l10n.chatLoadFailed,
      ChatFailure.send => l10n.chatSendFailed,
      // Upload preparation fails before Pi; changing models is not the remedy.
      ChatFailure.imageProcessing => l10n.chatImageProcessingFailed,
      ChatFailure.reply => l10n.chatReplyFailed,
      ChatFailure.disconnected => l10n.piDisconnected,
      ChatFailure.uncertain => l10n.chatUncertain,
      ChatFailure.stop => l10n.chatStopFailed,
      ChatFailure.queue => l10n.chatQueueFailed,
      ChatFailure.cancelled => l10n.chatSessionCancelled,
      ChatFailure.invalidEvent => l10n.chatInvalidEvent,
      null => null,
    };
    final activityText = widget.hibernating
        ? l10n.chatWaking
        : chat.isLoading
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
                  Expanded(
                    child: Text(
                      widget.project,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  if (widget.session != null) _historyButton(context),
                ],
              ),
            ),
          if (widget.hibernating)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                borderColor: context.colors.primary.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.chatHibernated,
                        style: context.textTheme.bodySmall,
                      ),
                    ),
                    if (widget.onWake != null)
                      AppActionButton.subtle(
                        label: l10n.chatWake,
                        leading: const Icon(Icons.power_settings_new),
                        onPressed: widget.waking ? null : widget.onWake,
                      ),
                  ],
                ),
              ),
            )
          else if (failureText != null)
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
          _queuePreview(context),
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
          if (widget.session?.pendingHistoryDraft != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                children: [
                  Text(
                    l10n.historyPendingDraft,
                    style: context.textTheme.bodySmall,
                  ),
                  AppActionButton.subtle(
                    label: l10n.historyRestoreDraft,
                    onPressed: _restoreHistoryDraft,
                  ),
                ],
              ),
            ),
          if (widget.sharedDirectoryWarning)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.workbenchSharedDirectory,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.warning,
                ),
              ),
            ),
          HomeStarterPanel(
            modelPicker: widget.modelPicker,
            inputController: widget.input,
            attachments: widget.attachments,
            canSend: chat.canSubmit,
            isRunning: chat.isRunning,
            isStopping: !chat.canStop,
            onSendPrompt: _send,
            onFollowUp: () => _send(PiStreamingBehavior.followUp),
            onRestoreQueue: chat.canTakeQueue ? () => _restoreQueue() : null,
            onStop: () => _restoreQueue(stop: true),
            minLines: started ? 2 : 4,
          ),
        ],
      ),
    );
  }

  Widget _queuePreview(BuildContext context) {
    final chat = widget.chat;
    final l10n = context.l10n;
    final queue = chat.queue;
    final entries = [
      for (final text in queue.steering) (l10n.chatQueueSteering, text),
      for (final text in queue.followUp) (l10n.chatQueueFollowUp, text),
    ];
    final previewEntries = [
      if (queue.steering.isNotEmpty)
        (l10n.chatQueueSteering, queue.steering.first),
      if (queue.followUp.isNotEmpty)
        (l10n.chatQueueFollowUp, queue.followUp.first),
    ];
    Widget contents(BuildContext context, {bool preview = false}) =>
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 144),
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (label, text) in preview ? previewEntries : entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      l10n.chatQueueEntry(
                        label,
                        text.isEmpty ? l10n.chatImage : text,
                      ),
                      maxLines: preview ? 1 : null,
                      overflow: preview ? TextOverflow.ellipsis : null,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
    final body = queue.isEmpty
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppDisclosure(
                    framed: false,
                    title: l10n.chatQueuedCount(queue.length),
                    previewBuilder: (context) =>
                        contents(context, preview: true),
                    builder: contents,
                  ),
                ),
                AppIconButton.subtle(
                  icon: Icons.edit_outlined,
                  tooltip: l10n.chatQueueRestore,
                  onPressed: chat.canTakeQueue ? () => _restoreQueue() : null,
                ),
              ],
            ),
          );
    if (MediaQuery.disableAnimationsOf(context)) return body;
    return AnimatedSize(
      duration: AppDurations.fast,
      curve: AppCurves.smoothOut,
      alignment: Alignment.bottomCenter,
      child: body,
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
    listenable: Listenable.merge([
      widget.chat,
      widget.browser,
      if (widget.session != null) widget.session!.history,
    ]),
    builder: (context, _) {
      final chat = widget.chat;
      // Keep the original centered empty composer. Only an accepted/submitting
      // first prompt enters the bottom-docked conversation layout.
      final started =
          chat.timeline.messages.isNotEmpty || chat.isSending || chat.isRunning;
      // One shared backdrop pass for every glass card in this conversation
      // (timeline bubbles, tool cards, starter panel, composer). Cards never
      // overlap here; popups and dialogs render in the global overlay outside
      // this subtree, so they never share the group key.
      final conversation = BackdropGroup(
        child: AppComposerLayout(
          started: started,
          content: Column(
            children: [
              _header(context),
              Expanded(child: _timeline(context)),
            ],
          ),
          editor: _editor(context, started),
        ),
      );
      if (widget.conversationOnly) return conversation;
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
