import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

enum SlashCommandFailure { load }

/// 输入框斜杠菜单的命令数据源。get_commands 是会话资源读取：打开菜单时
/// 懒加载，运行结束/换目录/断线只标记失效，下次打开再重读。
class SlashCommandController extends ChangeNotifier {
  SlashCommandController(this._pi) {
    _subscription = _pi.events.listen((event) {
      if (event is PiRpcWorkspaceChanged ||
          event is PiRpcWorkspaceReset ||
          event is PiRpcDisconnected ||
          event is PiRpcSessionChanged ||
          (event is PiAgentEvent && event.type == 'agent_settled')) {
        _stale = true;
      }
    });
  }

  final PiCommandGateway _pi;
  late final StreamSubscription<PiRpcEvent> _subscription;
  bool _disposed = false;
  bool _stale = true;

  /// Commands from the last successful read. Kept usable after a failed refresh.
  List<PiSlashCommand> commands = const [];
  bool isBusy = false, isReady = false;
  SlashCommandFailure? failure;

  /// Reload when stale; keep showing the cached list until a read succeeds.
  Future<void> ensureLoaded() async {
    if (_disposed || isBusy || isReady && !_stale) return;
    isBusy = true;
    failure = null;
    _notify();
    try {
      final next = await _pi.getCommands();
      if (_disposed) return;
      commands = next;
      isReady = true;
      _stale = false;
    } catch (_) {
      if (!_disposed) failure = SlashCommandFailure.load;
    } finally {
      isBusy = false;
      if (!_disposed) _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
