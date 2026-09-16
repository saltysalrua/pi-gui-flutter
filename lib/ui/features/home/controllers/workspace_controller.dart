import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/core/rpc/pi_workspace_types.dart';

import 'chat_controller.dart';
import 'model_picker_controller.dart';

/// Coordinates directory changes over the same RPC used by chat and the picker.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this._pi, this.chat, this.models) {
    _subscription = _pi.events.listen(_onEvent);
    chat.addListener(_chatUpdated);
  }
  final PiWorkspaceGateway _pi;
  final ChatController chat;
  final ModelPickerController models;
  late final StreamSubscription<PiRpcEvent> _subscription;
  PiWorkspaceSnapshot? snapshot;
  List<PiSessionSummary> sessions = const [];
  bool isBusy = false, isLoadingSessions = false;
  String? failureCode, sessionsFailure, createdPath;
  bool _disposed = false, _forceSessionsAgain = false;
  int _generation = 0, _sessionsRevision = 0;
  Future<void>? _sessionRefresh;
  String? _lastSession, _lastTitle;

  bool get canSwitch =>
      !isBusy &&
      chat.canSwitch &&
      !models.isBusy &&
      !_pi.hasUnsettledConversationMutation;
  bool get canCreateWorktree => canSwitch && snapshot?.git?.hasHead == true;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void dismissFailure() {
    failureCode = null;
    createdPath = null;
    _notify();
  }

  void _onEvent(PiRpcEvent event) {
    if (event is PiRpcWorkspaceChanged) {
      _generation++;
      _sessionsRevision++;
      sessions = const [];
      sessionsFailure = null;
      _lastSession = null;
      _lastTitle = null;
      _notify();
      // Also handles acknowledgements arriving after a request timeout.
      if (!isBusy) unawaited(refresh());
    } else if (event is PiRpcConversationSettled || event is PiRpcConnected) {
      _sessionsRevision++;
      if (!isBusy) unawaited(refresh());
    } else if (event is PiChatEvent &&
        const {'agent_settled', 'compaction_end'}.contains(event.type)) {
      // Refresh timestamps/counts even when the session path/title is unchanged.
      _sessionsRevision++;
      if (!chat.workspaceLocked) unawaited(refreshSessions());
    }
  }

  void _chatUpdated() {
    if (_disposed ||
        isBusy ||
        !chat.isReady ||
        chat.isRunning ||
        chat.isLoading) {
      return;
    }
    if (_lastSession != chat.sessionFile || _lastTitle != chat.title) {
      _lastSession = chat.sessionFile;
      _lastTitle = chat.title;
      _sessionsRevision++;
      unawaited(refreshSessions());
    }
  }

  Future<void> refreshSessions({bool force = false}) {
    if (_disposed) return Future.value();
    _forceSessionsAgain |= force;
    if (_sessionRefresh case final loading?) return loading;
    // Assign before notifying listeners so reentrant callers share this load.
    final completion = Completer<void>();
    _sessionRefresh = completion.future;
    unawaited(
      _loadSessions().then<void>(
        (_) => completion.complete(),
        onError: completion.completeError,
      ),
    );
    return completion.future;
  }

  Future<void> _loadSessions() async {
    isLoadingSessions = true;
    _notify();
    try {
      int revision;
      do {
        revision = _sessionsRevision;
        final generation = _generation;
        final force = _forceSessionsAgain;
        _forceSessionsAgain = false;
        try {
          final result = await _pi.listSessions(force: force);
          if (!_disposed &&
              !_forceSessionsAgain &&
              generation == _generation &&
              revision == _sessionsRevision) {
            sessions = result;
            sessionsFailure = null;
          }
        } catch (_) {
          if (!_disposed &&
              !_forceSessionsAgain &&
              generation == _generation &&
              revision == _sessionsRevision) {
            sessionsFailure = 'SESSIONS_UNAVAILABLE';
          }
        }
        // Duplicate readers share one request. A real change or explicit
        // refresh during that request gets one trailing read, awaited by all.
      } while (!_disposed &&
          (revision != _sessionsRevision || _forceSessionsAgain));
    } finally {
      _sessionRefresh = null;
      isLoadingSessions = false;
      _notify();
    }
  }

  Future<void> _refreshConversation() async {
    await chat.refresh();
    await models.refresh();
  }

  Future<void> refresh({
    bool loadConversation = true,
    bool forceSessions = false,
  }) async {
    if (_disposed || isBusy) return;
    isBusy = true;
    _notify();
    try {
      snapshot = await _pi.getWorkspace();
      failureCode = null;
      // Sidebar enumeration must not delay hydrating the active conversation.
      await Future.wait([
        refreshSessions(force: forceSessions),
        if (loadConversation) _refreshConversation(),
      ]);
    } catch (error) {
      failureCode = _errorCode(error);
    } finally {
      isBusy = false;
      _notify();
    }
  }

  String _errorCode(Object error) => error is PiRpcException
      ? error.outcomeUnknown
            ? 'OUTCOME_UNKNOWN'
            : error.message
      : 'WORKSPACE_FAILED';

  Future<bool> open(String path) => _change(() async => path);
  Future<bool> create(String parent, String name) => _change(() async {
    final path = await _pi.createWorkspace(parent, name);
    createdPath = path;
    return path;
  });
  Future<bool> createWorktree(String branch, String baseRef) =>
      _change(() async {
        final path = await _pi.createWorktree(branch, baseRef);
        createdPath = path;
        return path;
      });

  Future<bool> removeWorktree(String path) async {
    if (_disposed || !canSwitch) return false;
    isBusy = true;
    failureCode = null;
    chat.setWorkspaceLocked(true);
    models.setWorkspaceLocked(true);
    _notify();
    var removed = false;
    try {
      await _pi.removeWorktree(path);
      removed = true;
      snapshot = await _pi.getWorkspace();
    } catch (error) {
      failureCode = _errorCode(error);
    } finally {
      chat.setWorkspaceLocked(false);
      models.setWorkspaceLocked(false);
      isBusy = false;
      _notify();
    }
    return removed;
  }

  Future<bool> _change(Future<String> Function() destination) async {
    if (_disposed || !canSwitch) return false;
    isBusy = true;
    failureCode = null;
    createdPath = null;
    chat.setWorkspaceLocked(true);
    models.setWorkspaceLocked(true);
    _notify();
    var opened = false;
    try {
      final path = await destination();
      snapshot = await _pi.openWorkspace(path);
      opened = true;
      createdPath = null;
    } catch (error) {
      failureCode = _errorCode(error);
      // A created folder/worktree is never deleted if opening it fails.
      if (!_pi.hasUnsettledConversationMutation) {
        try {
          snapshot = await _pi.getWorkspace();
        } catch (_) {
          /* Keep last confirmed snapshot. */
        }
      }
    } finally {
      chat.setWorkspaceLocked(false);
      models.setWorkspaceLocked(false);
      if (!_disposed && !_pi.hasUnsettledConversationMutation) {
        await Future.wait([refreshSessions(), _refreshConversation()]);
      }
      isBusy = false;
      _notify();
    }
    return opened;
  }

  @override
  void dispose() {
    _disposed = true;
    chat.removeListener(_chatUpdated);
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
