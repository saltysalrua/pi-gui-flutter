import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/services/window_material_service.dart';

/// Serializes native transitions. Opacity is painted in Flutter and never sent
/// here, so dragging a tint slider cannot repeatedly reset the DWM backdrop.
class WindowMaterialController extends ChangeNotifier {
  WindowMaterialController(this._backend) {
    _events = _backend.changes.listen((status) {
      if (_disposed || _desired?.$1 != true) return;
      // A system-policy event can overtake an in-flight platform response.
      // Re-read once rather than let the older reply restore transparency.
      if (_running) _refreshAfterApply = true;
      _publish(status);
    });
  }
  final WindowMaterialBackend _backend;
  late final StreamSubscription<WindowMaterialStatus> _events;
  (bool, bool)? _desired, _applied;
  bool _running = false, _disposed = false, _refreshAfterApply = false;
  WindowMaterialStatus status = WindowMaterialStatus.disabled;
  Future<void> _pending = Future.value();
  Future<void> get settled => _pending;

  void configure({required bool enabled, required bool dark}) {
    final next = (enabled, dark);
    if (_disposed || next == _desired) return;
    _desired = next;
    if (!_running) _pending = _drain();
  }

  Future<void> _drain() async {
    _running = true;
    while (!_disposed && _applied != _desired) {
      final request = _desired!;
      WindowMaterialStatus result;
      try {
        result = await _backend.apply(enabled: request.$1, dark: request.$2);
      } catch (_) {
        result = WindowMaterialStatus.unavailable;
      }
      if (_disposed) break;
      _applied = _refreshAfterApply ? null : request;
      if (!_refreshAfterApply && request == _desired) _publish(result);
      _refreshAfterApply = false;
    }
    _running = false;
  }

  void _publish(WindowMaterialStatus value) {
    if (status == value) return;
    status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_events.cancel());
    _backend.dispose();
    super.dispose();
  }
}
