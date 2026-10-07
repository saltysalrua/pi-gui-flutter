import 'dart:async';
import 'dart:developer' as developer;

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
    if (_hasNativeMaterial) _channel.setMethodCallHandler(_onMethod);
  }
  static const _channel = MethodChannel('pi_gui/window_material');
  bool get _hasNativeMaterial =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
  final _changes = StreamController<WindowMaterialStatus>.broadcast();
  static WindowMaterialStatus _parse(Object? value) {
    final status = WindowMaterialStatus.values
        .where((s) => s.name == value)
        .firstOrNull;
    if (status != null) return status;
    developer.log(
      'Unrecognized native window material status',
      name: 'pi_gui.window_material',
      error: <String, Object?>{'status': value},
    );
    return WindowMaterialStatus.unavailable;
  }

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
    if (!_hasNativeMaterial) return WindowMaterialStatus.unsupported;
    final method = defaultTargetPlatform == TargetPlatform.linux
        ? 'setBlur'
        : 'setAcrylic';
    try {
      return _parse(
        await _channel.invokeMethod<String>(method, {
          'enabled': enabled,
          'dark': dark,
        }),
      );
    } on MissingPluginException catch (error, stackTrace) {
      // Hot reload cannot register a new native channel in an older runner.
      developer.log(
        'Native window material channel is missing',
        name: 'pi_gui.window_material',
        error: <String, Object?>{
          'method': method,
          'enabled': enabled,
          'dark': dark,
          'message': error.message,
        },
        stackTrace: stackTrace,
      );
      return WindowMaterialStatus.unavailable;
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Native window material request failed',
        name: 'pi_gui.window_material',
        error: <String, Object?>{
          'method': method,
          'enabled': enabled,
          'dark': dark,
          'code': error.code,
          'message': error.message,
          'details': error.details,
        },
        stackTrace: stackTrace,
      );
      return WindowMaterialStatus.unavailable;
    }
  }

  @override
  void dispose() {
    if (_hasNativeMaterial) _channel.setMethodCallHandler(null);
    unawaited(_changes.close());
  }
}
