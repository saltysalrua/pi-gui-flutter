import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

enum ModelPickerFailure { load, changeModel, changeThinking, disconnected }

/// 只管理交互状态；模型能力与实际选择完全以 Pi 返回值为准。
class ModelPickerController extends ChangeNotifier {
  ModelPickerController(
    this._pi, {
    this.reconnectDelay = const Duration(seconds: 1),
  }) {
    _subscription = _pi.events.listen((event) {
      if (event is PiRpcWorkspaceChanged) {
        isReady = false;
        state = null;
        _notify();
      } else if (event is PiRpcDisconnected) {
        isReady = false;
        _connectionLost = true;
        failure = ModelPickerFailure.disconnected;
        _scheduleReconnect();
        _notify();
      } else if (event is PiRpcSelectionSettled ||
          event is PiRpcSessionChanged ||
          (event is PiAgentEvent && event.type == 'agent_settled')) {
        if (isBusy) {
          _refreshAfterOperation = true;
        } else {
          unawaited(refresh());
        }
      }
    });
  }

  final PiModelGateway _pi;
  final Duration reconnectDelay;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _connectionLost = false;
  bool _refreshAfterOperation = false;

  bool get isReconnecting =>
      _reconnectTimer != null || (_connectionLost && isBusy);

  void _scheduleReconnect() {
    if (_disposed ||
        !_connectionLost ||
        _reconnectAttempts >= 3 ||
        _reconnectTimer != null) {
      return;
    }
    _reconnectTimer = Timer(reconnectDelay * (1 << _reconnectAttempts), () {
      _reconnectTimer = null;
      if (_disposed) return;
      if (isBusy) {
        _scheduleReconnect();
        return;
      }
      _reconnectAttempts++;
      unawaited(refresh()); // 仅重读，不重放用户的 set_model / set_thinking_level。
    });
  }

  late final StreamSubscription<PiRpcEvent> _subscription;
  bool _disposed = false;
  bool isBusy = false;
  bool workspaceLocked = false;

  void setWorkspaceLocked(bool locked) {
    workspaceLocked = locked;
    _notify();
  }

  bool isReady = false;
  bool thinkingLevelsUnavailable = false;
  ModelPickerFailure? failure;
  List<PiModel> models = const [];
  List<PiThinkingLevel> thinkingLevels = const [];
  PiSessionState? state;

  PiModel? get selectedModel => state?.model;
  PiThinkingLevel? get thinkingLevel => state?.thinkingLevel;
  bool get canChangeModel => isReady && !isBusy && !workspaceLocked;
  bool get canChangeThinking =>
      canChangeModel &&
      selectedModel != null &&
      thinkingLevels.length > 1 &&
      thinkingLevels.contains(thinkingLevel);

  List<PiModel> search(String query) {
    final terms = query.toLowerCase().trim().split(RegExp(r'\s+'));
    return models
        .where((model) {
          final text = '${model.name} ${model.provider}/${model.id}'
              .toLowerCase();
          return terms.every(text.contains);
        })
        .toList(growable: false);
  }

  Future<void> _readSelection() async {
    final nextState = await _pi.getState();
    var nextLevels = const <PiThinkingLevel>[];
    var nextLevelsUnavailable = false;
    try {
      nextLevels = await _pi.getAvailableThinkingLevels();
    } on PiRpcException catch (error) {
      // 旧版 Pi 不支持此命令时，模型仍可切换；绝不猜测可用档位。
      if (error.command != 'get_available_thinking_levels' ||
          !error.message.toLowerCase().contains('unknown command')) {
        rethrow;
      }
      nextLevelsUnavailable = true;
    }
    if (_disposed) return;
    // 原子替换已确认快照，异步间隙的重建不能看到新模型配旧/空档位。
    state = nextState;
    thinkingLevels = nextLevels;
    thinkingLevelsUnavailable = nextLevelsUnavailable;
  }

  Future<bool> _run(
    ModelPickerFailure failureKind,
    Future<void> Function() action,
  ) async {
    if (_disposed || isBusy || workspaceLocked) return false;
    isBusy = true;
    failure = null;
    _notify();
    try {
      await action();
      if (_disposed) return false;
      isReady = true;
      _connectionLost = false;
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      return true;
    } catch (_) {
      // 不做乐观提交。刷新后才允许继续写入，防止 UI 与后端不一致。
      isReady = false;
      failure ??= failureKind;
      return false;
    } finally {
      isBusy = false;
      _scheduleReconnect();
      _notify();
      if (_refreshAfterOperation && !_disposed) {
        _refreshAfterOperation = false;
        scheduleMicrotask(refresh);
      }
    }
  }

  /// 普通打开复用已确认状态；变更事件和显式刷新负责更新。
  Future<void> ensureLoaded() async {
    if (!isReady) await refresh();
  }

  Future<void> refresh() async {
    await _run(ModelPickerFailure.load, () async {
      await _pi.connect();
      models = await _pi.getAvailableModels();
      await _readSelection();
    });
  }

  Future<bool> selectModel(PiModel model) async {
    if (!canChangeModel || !models.any(model.sameIdentity)) return false;
    if (model.sameIdentity(selectedModel)) return true;
    return _run(ModelPickerFailure.changeModel, () async {
      await _pi.setModel(model);
      // set_model 会裁剪旧思考等级，不能沿用之前的滑块索引。
      await _readSelection();
    });
  }

  Future<bool> selectThinkingLevel(PiThinkingLevel level) async {
    if (!canChangeThinking || !thinkingLevels.contains(level)) return false;
    if (level == thinkingLevel) return true;
    return _run(ModelPickerFailure.changeThinking, () async {
      await _pi.setThinkingLevel(level);
      await _readSelection();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
