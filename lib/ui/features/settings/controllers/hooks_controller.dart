import 'package:flutter/foundation.dart';

import '../../../../core/rpc/pi_hooks_types.dart';
import '../../../../core/rpc/pi_rpc_client.dart';
import '../../../../core/rpc/pi_rpc_types.dart';

enum HooksStatus { loading, ready, failed }

/// Backs the settings "hooks" page: lists the GUI's built-in runtime hooks
/// and applies enable/disable/remove/restore changes over the shared control
/// channel. Pure state holder; rendering lives in [HooksSettingsContent].
///
/// State changes are honored by Pi processes started afterwards — running
/// sessions keep the hooks they launched with, and nothing here restarts a
/// live Agent.
class HooksController extends ChangeNotifier {
  HooksController(this.client) : _service = PiHooksService(client);

  final PiRpcClient client;
  final PiHooksService _service;
  final _pending = <String>{};
  bool _disposed = false;

  HooksStatus status = HooksStatus.loading;
  PiHooksState? state;
  String? failure, actionError;

  bool isPending(String id) => _pending.contains(id);
  bool get busy => _pending.isNotEmpty;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (status != HooksStatus.loading && state != null) return;
    try {
      state = await _service.state();
      failure = null;
      status = HooksStatus.ready;
    } catch (error) {
      failure = _code(error);
      status = HooksStatus.failed;
    }
    _notify();
  }

  /// Applies one state change: enable (restore), off (switch), removed
  /// (uninstall = permanently not injected until restored).
  Future<void> setHook(PiHookItem hook, PiHookState next) async {
    if (hook.state == next || _pending.contains(hook.id)) return;
    _pending.add(hook.id);
    _notify();
    try {
      state = await _service.set(hook.id, next);
      actionError = null;
    } catch (error) {
      actionError = _code(error);
    } finally {
      _pending.remove(hook.id);
      _notify();
    }
  }

  // Surface the real cause (RPC error code vs. local exception) instead of
  // collapsing everything into a bare "failed".
  static String _code(Object error) {
    if (error is PiRpcException) {
      return error.outcomeUnknown ? 'OUTCOME_UNKNOWN' : error.message;
    }
    final detail = error.toString().split('\n').first;
    return detail.length > 160 ? detail.substring(0, 160) : detail;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}