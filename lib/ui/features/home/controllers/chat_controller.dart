import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pi_gui/core/models/chat_timeline.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/core/theme/app_motion.dart';

enum ChatActivity { idle, working, retrying, compacting, stopping }

enum ChatFailure {
  load,
  send,
  imageProcessing,
  reply,
  disconnected,
  uncertain,
  stop,
  cancelled,
  invalidEvent,
}

class ChatSessionBookmark {
  const ChatSessionBookmark(this.path, this.title);
  final String path, title;
}

/// One conversation projection over HomeView's shared RPC process. Never replays prompts.
class ChatController extends ChangeNotifier {
  ChatController(this._pi) {
    _subscription = _pi.events.listen(_onEvent);
  }
  final PiChatGateway _pi;
  final timeline = ChatTimeline();
  final sessions = <ChatSessionBookmark>[];
  late final StreamSubscription<PiRpcEvent> _subscription;
  Timer? _frame;
  bool _disposed = false,
      _lost = false,
      _resync = false,
      _awaitingSettled = false;
  bool isLoading = false, isSending = false, isReady = false;
  bool workspaceLocked = false;
  int _revision = 0;
  ChatActivity activity = ChatActivity.idle;
  ChatFailure? failure;
  PiSessionState? state;
  PiPromptQueue queue = const PiPromptQueue();

  bool get isRunning => activity != ChatActivity.idle;
  bool get canSend =>
      isReady &&
      !workspaceLocked &&
      !isLoading &&
      !isSending &&
      !isRunning &&
      !_pi.hasUnsettledConversationMutation;
  // A fresh session is an explicit recovery option even if the previous read/restore failed.
  bool get canSwitch =>
      !workspaceLocked &&
      !isLoading &&
      !isSending &&
      !isRunning &&
      !_pi.hasUnsettledConversationMutation;
  String? get sessionFile => state?.sessionFile;
  String get title =>
      state?.sessionName ??
      timeline.messages
          .where((m) => m.role == 'user')
          .map((m) => m.text.split('\n').first)
          .firstOrNull ??
      '';
  Map<String, List<ChatToolCall>> get changes {
    final result = <String, List<ChatToolCall>>{};
    for (final call in timeline.tools.values) {
      if (call.isFileChange) (result[call.path!] ??= []).add(call);
    }
    return result;
  }

  void setWorkspaceLocked(bool locked) {
    workspaceLocked = locked;
    _notify();
  }

  void dismissFailure() {
    failure = null;
    _notify();
  }

  void _remember() {
    final path = sessionFile;
    if (path == null || timeline.messages.isEmpty) return;
    final entry = ChatSessionBookmark(path, title);
    final index = sessions.indexWhere((s) => s.path == path);
    if (index < 0) {
      sessions.insert(0, entry);
    } else {
      sessions[index] = entry;
    }
  }

  Future<void> refresh() async {
    if (workspaceLocked) return;
    if (_disposed || isLoading || isSending) {
      _resync = true;
      return;
    }
    isLoading = true;
    _notify();
    try {
      await _pi.connect();
      if (_disposed) return;
      if (_lost && sessionFile != null && timeline.messages.isNotEmpty) {
        if (!await _pi.switchSession(sessionFile!)) {
          failure = ChatFailure.cancelled;
          isReady = false;
          return;
        }
      }
      _lost = false;
      final version = _revision;
      final next = await _pi.getState();
      final history = await _pi.getMessages();
      if (_disposed) return;
      state = next;
      // A snapshot racing a live delta cannot overwrite newer content. Re-read at settled.
      if (version == _revision) {
        // get_messages excludes the in-flight assistant. Keep the active projection intact.
        if (!_awaitingSettled || timeline.messages.isEmpty) {
          timeline.load(history);
        }
        if (!_awaitingSettled) {
          activity = next.isCompacting
              ? ChatActivity.compacting
              : next.isStreaming
              ? ChatActivity.working
              : ChatActivity.idle;
          _awaitingSettled = next.isStreaming;
        }
        if (!isRunning) timeline.settle();
      }
      isReady = !_pi.hasUnsettledConversationMutation;
      if (failure == ChatFailure.load ||
          failure == ChatFailure.disconnected ||
          failure == ChatFailure.uncertain) {
        failure = isReady ? null : ChatFailure.uncertain;
      }
      _remember();
    } catch (_) {
      isReady = false;
      failure = _lost ? ChatFailure.disconnected : ChatFailure.load;
    } finally {
      isLoading = false;
      _notify();
      _flushResync();
    }
  }

  Future<bool> send(String text, {List<PiImage> images = const []}) async {
    if (!canSend || (text.trim().isEmpty && images.isEmpty)) return false;
    isSending = true;
    failure = null;
    _notify();
    try {
      await _pi.prompt(text.trim(), images: images);
      if (_disposed) return true;
      // Extension slash commands can be handled without starting an agent run.
      _resync = !isRunning;
      return true;
    } catch (error) {
      if (_disposed) return false;
      final uncertain = error is PiRpcException && error.outcomeUnknown;
      if (uncertain) isReady = false;
      failure = _lost
          ? ChatFailure.disconnected
          : uncertain
          ? ChatFailure.uncertain
          : error is PiRpcException &&
                error.message == 'IMAGE_PREPROCESS_FAILED'
          ? ChatFailure.imageProcessing
          : ChatFailure.send;
      return false;
    } finally {
      isSending = false;
      _notify();
      _flushResync();
    }
  }

  Future<List<String>> stop() async {
    if (_disposed || !isRunning || activity == ChatActivity.stopping) return [];
    activity = ChatActivity.stopping;
    _notify();
    var restored = <String>[];
    try {
      restored = (await _pi.clearQueue()).all;
      queue = const PiPromptQueue();
      await _pi.abort();
      if (!_disposed) {
        activity = ChatActivity.idle;
        _awaitingSettled = false;
        timeline.settle();
        unawaited(refresh());
      }
    } catch (_) {
      if (!_disposed) {
        failure = ChatFailure.stop;
        // Leave stop usable: a timeout is not evidence the operation has ended.
        activity = _lost ? ChatActivity.idle : ChatActivity.working;
      }
    }
    _notify();
    return restored;
  }

  Future<bool> changeSession({String? path}) async {
    if (!canSwitch) return false;
    isLoading = true;
    failure = null;
    _remember();
    _notify();
    var changed = false;
    try {
      changed = path == null
          ? await _pi.newSession()
          : await _pi.switchSession(path);
      if (_disposed) return false;
      if (changed) {
        _lost = false;
        _awaitingSettled = false;
        timeline.load([]);
        queue = const PiPromptQueue();
        state = null;
        isReady = false;
      } else {
        failure = ChatFailure.cancelled;
      }
    } catch (error) {
      isReady = false;
      failure = error is PiRpcException && error.outcomeUnknown
          ? ChatFailure.uncertain
          : ChatFailure.load;
    } finally {
      isLoading = false;
      _notify();
    }
    if (changed) await refresh();
    return changed;
  }

  void _onEvent(PiRpcEvent event) {
    if (_disposed) return;
    if (event is PiRpcWorkspaceChanged) {
      _revision++;
      _lost = false;
      _awaitingSettled = false;
      _resync = false;
      timeline.load([]);
      sessions.clear();
      state = null;
      queue = const PiPromptQueue();
      activity = ChatActivity.idle;
      isReady = false;
      failure = null;
      _notify();
      return;
    }
    if (event is PiRpcDisconnected) {
      _lost = true;
      _awaitingSettled = false;
      _revision++;
      isReady = false;
      activity = ChatActivity.idle;
      timeline.settle();
      failure = ChatFailure.disconnected;
      _notify();
      return;
    }
    if (event is PiRpcConversationSettled ||
        event is PiRpcConnected && _lost && !isLoading) {
      unawaited(refresh());
    }
    if (event is PiRpcDiagnostic &&
        event.kind == PiRpcDiagnosticKind.invalidEvent &&
        event.command != 'extension_ui_request') {
      failure = ChatFailure.invalidEvent;
      _notify();
    }
    if (event is! PiChatEvent) return;
    _revision++;
    timeline.apply(event);
    switch (event.type) {
      case 'agent_start':
        _awaitingSettled = true;
        activity = ChatActivity.working;
      case 'agent_settled':
        _awaitingSettled = false;
        activity = ChatActivity.idle;
        _remember();
        unawaited(refresh());
      case 'compaction_start':
        activity = ChatActivity.compacting;
      case 'auto_retry_start':
      case 'summarization_retry_scheduled':
        activity = ChatActivity.retrying;
      case 'summarization_retry_attempt_start':
        activity = ChatActivity.compacting;
      case 'auto_retry_end':
        activity = ChatActivity.working;
        if (event.failed) failure = ChatFailure.reply;
      case 'compaction_end':
        activity = _awaitingSettled ? ChatActivity.working : ChatActivity.idle;
        if (event.failed) failure = ChatFailure.reply;
        if (!_awaitingSettled) unawaited(refresh());
      case 'queue_update':
        queue = event.queued ?? const PiPromptQueue();
      case 'message_end':
        if (event.message?.stopReason == 'error') failure = ChatFailure.reply;
    }
    if (event.type == 'message_update' ||
        event.type == 'tool_execution_update') {
      _frame ??= Timer(AppDurations.stagger, () {
        _frame = null;
        _notify();
      });
    } else {
      _notify();
    }
  }

  void _flushResync() {
    if (_resync && !_disposed && !isLoading && !isSending) {
      _resync = false;
      scheduleMicrotask(refresh);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _frame?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
