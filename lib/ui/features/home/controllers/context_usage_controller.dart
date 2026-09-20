import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

/// Read-only, event-driven context telemetry for one mounted session pane.
/// No polling, token estimation, history reads or changes to chat busy state.
class ContextUsageController extends ChangeNotifier {
  ContextUsageController(this._pi) {
    _subscription = _pi.events.listen(_onEvent);
  }
  final PiContextGateway _pi;
  late final StreamSubscription<PiRpcEvent> _subscription;
  PiContextUsage? usage;
  bool _disposed = false, _reading = false, _readAgain = false, _paused = false;
  int _epoch = 0;

  Future<void> refresh() async {
    if (_disposed || _paused) return;
    if (_reading) {
      _readAgain = true;
      return;
    }
    _reading = true;
    final epoch = _epoch;
    PiContextUsage? next;
    try {
      next = await _pi.getContextUsage();
    } catch (_) {
      // Optional telemetry never disconnects Pi or disables the composer.
    } finally {
      _reading = false;
      if (!_disposed && epoch == _epoch) {
        usage = next;
        notifyListeners();
      }
      if (_readAgain) {
        _readAgain = false;
        unawaited(refresh());
      }
    }
  }

  void _invalidate({bool paused = false}) {
    _epoch++;
    _paused = paused;
    usage = null;
    notifyListeners();
    if (!paused) unawaited(refresh());
  }

  void _onEvent(PiRpcEvent event) {
    if (_disposed) return;
    if (event is PiRpcDisconnected || event is PiRpcWorkspaceReset) {
      _invalidate(paused: true);
    } else if (event is PiContextUsageInvalidated ||
        event is PiRpcSessionChanged ||
        event is PiRpcWorkspaceChanged) {
      _invalidate();
    } else if (event is PiRpcConnected) {
      final wasPaused = _paused;
      _paused = false;
      if (!_reading || wasPaused) unawaited(refresh());
    } else if (event is PiRpcConversationSettled ||
        event is PiAgentEvent &&
            const {
              'agent_start',
              'turn_end',
              'agent_settled',
              'compaction_end',
            }.contains(event.type)) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
