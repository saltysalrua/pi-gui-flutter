import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum WindowMaterialStatus {
  active,
  disabled,
  unsupported,
  systemDisabled,
  unavailable,
}

/// GUI-owned platform channel, entirely separate from Pi RPC.
abstract interface class WindowMaterialBackend {
  Future<WindowMaterialStatus> apply({
    required bool enabled,
    required bool dark,
  });
  Stream<WindowMaterialStatus> get changes;
  void dispose();
}

class WindowMaterialService implements WindowMaterialBackend {
  WindowMaterialService() {
    if (_isWindows) _channel.setMethodCallHandler(_onMethod);
  }
  static const _channel = MethodChannel('pi_gui/window_material');
  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  final _changes = StreamController<WindowMaterialStatus>.broadcast();
  static WindowMaterialStatus _parse(Object? value) =>
      WindowMaterialStatus.values.where((s) => s.name == value).firstOrNull ??
      WindowMaterialStatus.unavailable;

  Future<void> _onMethod(MethodCall call) async {
    if (call.method == 'statusChanged' && !_changes.isClosed) {
      _changes.add(_parse(call.arguments));
    }
  }

  @override
  Stream<WindowMaterialStatus> get changes => _changes.stream;

  @override
  Future<WindowMaterialStatus> apply({
    required bool enabled,
    required bool dark,
  }) async {
    if (!_isWindows) return WindowMaterialStatus.unsupported;
    try {
      return _parse(
        await _channel.invokeMethod<String>('setAcrylic', {
          'enabled': enabled,
          'dark': dark,
        }),
      );
    } on MissingPluginException {
      // Hot reload cannot register a new native channel in an older runner.
      return WindowMaterialStatus.unavailable;
    } on PlatformException {
      return WindowMaterialStatus.unavailable;
    }
  }

  @override
  void dispose() {
    if (_isWindows) _channel.setMethodCallHandler(null);
    unawaited(_changes.close());
  }
}
