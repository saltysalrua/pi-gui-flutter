import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/models/appearance_preferences.dart';
import 'package:pi_gui/core/services/window_material_service.dart';
import 'package:pi_gui/ui/core/window_material_controller.dart';

class _Backend implements WindowMaterialBackend {
  final events = StreamController<WindowMaterialStatus>.broadcast(sync: true);
  final requests = <(bool, bool)>[];
  final results = <Completer<WindowMaterialStatus>>[];
  @override
  Stream<WindowMaterialStatus> get changes => events.stream;
  @override
  Future<WindowMaterialStatus> apply({
    required bool enabled,
    required bool dark,
  }) {
    requests.add((enabled, dark));
    final result = Completer<WindowMaterialStatus>();
    results.add(result);
    return result.future;
  }

  @override
  void dispose() => unawaited(events.close());
}

void main() {
  test(
    'glass fields migrate safely, clamp malformed input and stay independent',
    () {
      final old = AppearancePreferences.fromJson({'version': 1});
      expect(old.wantsGlass, false);
      final parsed = AppearancePreferences.fromJson({
        'version': 1,
        'sidebarGlass': {'enabled': true, 'opacity': -10},
        'canvasGlass': {'enabled': 'true', 'opacity': double.nan},
      });
      expect(parsed.sidebarGlass.enabled, true);
      expect(parsed.sidebarGlass.opacity, GlassPreferences.minOpacity);
      expect(parsed.canvasGlass.enabled, false);
      expect(
        parsed.canvasGlass.opacity,
        AppearancePreferences.defaultCanvasGlass.opacity,
      );
      final next = parsed.copyWith(
        canvasGlass: const GlassPreferences(enabled: true, opacity: 4),
      );
      final roundTrip = AppearancePreferences.fromJson(next.toJson());
      expect(roundTrip.sidebarGlass.toJson(), parsed.sidebarGlass.toJson());
      expect(roundTrip.canvasGlass.opacity, 1);
      final disabled = roundTrip.copyWith(
        sidebarGlass: roundTrip.sidebarGlass.copyWith(enabled: false),
      );
      expect(disabled.sidebarGlass.opacity, parsed.sidebarGlass.opacity);
      expect(disabled.canvasGlass.toJson(), roundTrip.canvasGlass.toJson());
    },
  );

  test(
    'native requests serialize, coalesce and cannot apply a stale result',
    () async {
      final backend = _Backend();
      final controller = WindowMaterialController(backend);
      addTearDown(controller.dispose);
      controller.configure(enabled: true, dark: false);
      controller.configure(enabled: true, dark: true);
      controller.configure(enabled: false, dark: true);
      expect(backend.requests, [(true, false)]);
      backend.results[0].complete(WindowMaterialStatus.active);
      await Future<void>.delayed(Duration.zero);
      expect(controller.status, WindowMaterialStatus.disabled);
      expect(backend.requests, [(true, false), (false, true)]);
      backend.results[1].complete(WindowMaterialStatus.disabled);
      await controller.settled;
      controller.configure(enabled: false, dark: true);
      expect(backend.requests.length, 2);
    },
  );

  test(
    'system policy overrides and response races remain fail-closed',
    () async {
      final backend = _Backend();
      final controller = WindowMaterialController(backend);
      addTearDown(controller.dispose);
      controller.configure(enabled: true, dark: false);
      backend.events.add(WindowMaterialStatus.systemDisabled);
      backend.results[0].complete(WindowMaterialStatus.active);
      await Future<void>.delayed(Duration.zero);
      expect(controller.status, WindowMaterialStatus.systemDisabled);
      expect(backend.requests.length, 2);
      backend.results[1].complete(WindowMaterialStatus.systemDisabled);
      await controller.settled;
      backend.events.add(WindowMaterialStatus.active);
      expect(controller.status, WindowMaterialStatus.active);
      controller.configure(enabled: true, dark: true);
      backend.results[2].completeError(StateError('native failure'));
      await controller.settled;
      expect(controller.status, WindowMaterialStatus.unavailable);
    },
  );

  test(
    'disposing during apply does not publish or start another request',
    () async {
      final backend = _Backend();
      final controller = WindowMaterialController(backend);
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.configure(enabled: true, dark: false);
      controller.configure(enabled: false, dark: false);
      controller.dispose();
      backend.results[0].complete(WindowMaterialStatus.active);
      await controller.settled;
      expect(notifications, 0);
      expect(backend.requests.length, 1);
    },
  );

  test(
    'platform channel encodes flags and handles missing or unknown native implementations',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const channel = MethodChannel('pi_gui/window_material');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final service = WindowMaterialService();
      addTearDown(() {
        service.dispose();
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'setAcrylic');
        expect(call.arguments, {'enabled': true, 'dark': false});
        return 'active';
      });
      expect(
        await service.apply(enabled: true, dark: false),
        WindowMaterialStatus.active,
      );
      messenger.setMockMethodCallHandler(channel, (_) async => 'future-status');
      expect(
        await service.apply(enabled: true, dark: false),
        WindowMaterialStatus.unavailable,
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw MissingPluginException(),
      );
      expect(
        await service.apply(enabled: true, dark: false),
        WindowMaterialStatus.unavailable,
      );
    },
  );
}
