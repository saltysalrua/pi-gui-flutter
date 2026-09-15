import 'dart:async';
import 'package:flutter/foundation.dart';
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
  bool _disposed = false, _refreshAgain = false;
  int _generation = 0;
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
      sessions = const [];
      sessionsFailure = null;
      _lastSession = null;
      _lastTitle = null;
      _notify();
      // Also handles acknowledgements arriving after a request timeout.
      if (!isBusy) unawaited(refresh());
    } else if (event is PiRpcConversationSettled || event is PiRpcConnected) {
      if (!isBusy) unawaited(refresh());
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
      unawaited(refreshSessions());
    }
  }

  Future<void> refreshSessions() async {
    if (_disposed) return;
    if (isLoadingSessions) {
      _refreshAgain = true;
      return;
    }
    isLoadingSessions = true;
    final generation = _generation;
    _notify();
    try {
      final result = await _pi.listSessions();
      if (!_disposed && generation == _generation) {
        sessions = result;
        sessionsFailure = null;
      }
    } catch (_) {
      if (generation == _generation) sessionsFailure = 'SESSIONS_UNAVAILABLE';
    } finally {
      isLoadingSessions = false;
      _notify();
      if (_refreshAgain && !_disposed) {
        _refreshAgain = false;
        unawaited(refreshSessions());
      }
    }
  }

  Future<void> refresh({bool loadConversation = true}) async {
    if (_disposed || isBusy) return;
    isBusy = true;
    _notify();
    try {
      snapshot = await _pi.getWorkspace();
      failureCode = null;
      await refreshSessions();
      if (loadConversation) {
        await chat.refresh();
        await models.refresh();
      }
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
        await chat.refresh();
        await models.refresh();
        await refreshSessions();
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
