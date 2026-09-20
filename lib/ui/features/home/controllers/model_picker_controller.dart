import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

enum ModelPickerFailure { load, changeModel, changeThinking, disconnected }

/// 只管理交互状态；模型能力与实际选择完全以 Pi 返回值为准。
class ModelPickerController extends ChangeNotifier {
  ModelPickerController(
    this._pi, {
    this.reconnectDelay = const Duration(seconds: 1),
    this.lateReadDelay = const Duration(seconds: 18),
  }) {
    _subscription = _pi.events.listen((event) {
      if (event is PiRpcWorkspaceChanged) {
        isReady = false;
        state = null;
        _resetLateReadEpoch();
        _notify();
      } else if (event is PiRpcDisconnected) {
        isReady = false;
        _connectionLost = true;
        failure = ModelPickerFailure.disconnected;
        _resetLateReadEpoch();
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

  /// Pi 0.85.1 RPC 启动后有一个后台目录刷新窗口（先清空扩展目录再逐 provider
  /// 补回，最长约 15 秒），期间 get_available_models 会返回残缺列表。首次成功
  /// 读取后按此延迟静默补读一次，躲过窗口且不触碰 isBusy。
  final Duration lateReadDelay;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _connectionLost = false;
  bool _refreshAfterOperation = false;
  Timer? _lateReadTimer;
  int _lateReadEpoch = 0;
  bool _lateReadDoneForEpoch = false;
  int _lateReadRetries = 0;

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
      _armLateRead();
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

  /// 每个 Pi 进程周期只补读一次：断线/换工作区重置，下次成功读取重新武装。
  void _armLateRead() {
    if (_disposed || _lateReadDoneForEpoch) return;
    _lateReadDoneForEpoch = true;
    _lateReadRetries = 0;
    _lateReadTimer?.cancel();
    _lateReadTimer = Timer(lateReadDelay, _onLateRead);
  }

  void _resetLateReadEpoch() {
    _lateReadEpoch++;
    _lateReadDoneForEpoch = false;
    _lateReadTimer?.cancel();
    _lateReadTimer = null;
  }

  /// 静默补读：不置 isBusy、不弹 failure，仅在可见内容变化时通知。
  /// Pi 启动后的后台目录刷新会先清空扩展 provider 的回放目录、网络阶段才补回，
  /// 首次读取可能落在窗口内缓存到残缺列表，这里在窗口结束后读一次修正。
  Future<void> _onLateRead() async {
    _lateReadTimer = null;
    if (_disposed) return;
    if (isBusy) {
      // 有操作在飞：稍后再试，有界重试，避免与在途写入交错。
      if (_lateReadRetries++ < 3) {
        _lateReadTimer = Timer(const Duration(seconds: 3), _onLateRead);
      }
      return;
    }
    final epoch = _lateReadEpoch;
    try {
      final previousModels = models;
      final previousState = state;
      final previousLevels = thinkingLevels;
      final previousLevelsUnavailable = thinkingLevelsUnavailable;
      final nextModels = await _pi.getAvailableModels();
      await _readSelection();
      if (_disposed || epoch != _lateReadEpoch) return;
      final modelsChanged = !_modelsVisuallyEqual(previousModels, nextModels);
      final selectionChanged = !_stateVisuallyEqual(
        previousState,
        previousLevels,
        previousLevelsUnavailable,
      );
      // 先原子替换再按需通知，避免异步间隙出现新模型配旧档位。
      models = nextModels;
      if (modelsChanged || selectionChanged) _notify();
    } catch (_) {
      // 静默放弃：连接已由事件路径负责恢复，下次事件刷新仍会重读。
    }
  }

  static bool _modelsVisuallyEqual(List<PiModel> a, List<PiModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!a[i].sameIdentity(b[i]) ||
          a[i].name != b[i].name ||
          a[i].reasoning != b[i].reasoning) {
        return false;
      }
    }
    return true;
  }

  bool _stateVisuallyEqual(
    PiSessionState? previousState,
    List<PiThinkingLevel> previousLevels,
    bool previousLevelsUnavailable,
  ) {
    if (thinkingLevelsUnavailable != previousLevelsUnavailable) return false;
    if (thinkingLevels.length != previousLevels.length) return false;
    for (var i = 0; i < thinkingLevels.length; i++) {
      if (thinkingLevels[i] != previousLevels[i]) return false;
    }
    final currentModel = state?.model;
    final previousModel = previousState?.model;
    if (currentModel == null && previousModel != null) return false;
    if (currentModel != null && !currentModel.sameIdentity(previousModel)) {
      return false;
    }
    return state?.thinkingLevel == previousState?.thinkingLevel;
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
    _resetLateReadEpoch();
    _reconnectTimer?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
