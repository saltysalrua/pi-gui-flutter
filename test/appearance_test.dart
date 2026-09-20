import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/models/appearance_preferences.dart';
import 'package:pi_gui/core/services/appearance_store.dart';
import 'package:pi_gui/ui/core/theme/app_colors_extension.dart';
import 'package:pi_gui/ui/core/theme/app_card_theme.dart';
import 'package:pi_gui/ui/core/theme/app_theme.dart';
import 'package:pi_gui/ui/core/theme/appearance_palette.dart';
import 'package:pi_gui/ui/features/settings/controllers/appearance_controller.dart';

class _Store implements AppearanceStore {
  AppearancePreferences value = AppearancePreferences();
  bool failLoad = false, failSave = false;
  Completer<void>? block;
  final saved = <double>[];
  @override
  Future<AppearancePreferences> load() async {
    if (failLoad) throw const FormatException();
    return value;
  }

  @override
  Future<void> save(AppearancePreferences preferences) async {
    final gate = block;
    block = null;
    if (gate != null) await gate.future;
    if (failSave) throw const FileSystemException();
    value = preferences;
    saved.add(value.baseFontSize);
  }
}

void main() {
  test('theme snapshots invalidate only their actual inputs', () {
    final cache = AppThemeCache();
    final p = AppearancePreferences(source: PaletteSource.system);
    const accent = Color(0xff126789);
    ThemeData resolve(
      AppearancePreferences value, [
      Brightness b = Brightness.light,
    ]) => cache.resolve(b, preferences: value, systemAccent: accent);
    final light = resolve(p);
    final dark = resolve(p, Brightness.dark);
    final nonTheme = p.copyWith(
      mode: AppearanceMode.dark,
      uiScale: 1.25,
      frameRate: 60,
      animationFrameRate: 60,
      sessionIdleMinutes: 15,
      toolDisplay: ToolDisplayMode.expanded,
      slotVisibility: {'aboveEditor': false},
      sidebarGlass: const GlassPreferences(enabled: true, opacity: .3),
      canvasGlass: const GlassPreferences(enabled: true, opacity: .4),
    );
    expect(identical(resolve(nonTheme), light), isTrue);
    expect(identical(resolve(nonTheme, Brightness.dark), dark), isTrue);
    // Serialization copies maps; equal values must still hit the cache.
    expect(
      identical(resolve(AppearancePreferences.fromJson(p.toJson())), light),
      isTrue,
    );
    final glass = p.copyWith(
      cardGlass: const GlassPreferences(enabled: true, opacity: .4),
    );
    final material = resolve(glass);
    expect(material.extension<AppCardTheme>()!.opacity, .4);
    expect(material.colorScheme, light.colorScheme);
    expect(material.textTheme, light.textTheme);
    expect(
      identical(
        material.extension<AppColorsExtension>(),
        light.extension<AppColorsExtension>(),
      ),
      isTrue,
    );
    expect(identical(resolve(glass), material), isTrue);
    expect(
      material,
      AppTheme.build(
        Brightness.light,
        preferences: glass,
        systemAccent: accent,
      ),
    );
    final overridden = glass.withColor(
      AppearanceColor.canvas,
      0xff123456,
      dark: true,
    );
    expect(identical(resolve(overridden), material), isTrue);
    expect(
      resolve(overridden, Brightness.dark).scaffoldBackgroundColor,
      const Color(0xff123456),
    );
    expect(
      resolve(p.copyWith(baseFontSize: 16)).textTheme.bodyMedium!.fontSize,
      16,
    );
    final custom = p.copyWith(source: PaletteSource.custom, seed: 0xff873312);
    expect(
      resolve(custom),
      AppTheme.build(Brightness.light, preferences: custom),
    );
    final changedAccent = cache.resolve(
      Brightness.light,
      preferences: p,
      systemAccent: const Color(0xff00aa22),
    );
    expect(changedAccent, isNot(light));
    final fallback = cache.resolve(Brightness.light, preferences: p);
    expect(fallback, AppTheme.build(Brightness.light, preferences: p));
    final original = p.copyWith(source: PaletteSource.original);
    final originalTheme = resolve(original);
    expect(
      identical(
        cache.resolve(
          Brightness.light,
          preferences: original,
          systemAccent: null,
        ),
        originalTheme,
      ),
      isTrue,
    );
    expect(AppColorsExtension.light.copyWith(), AppColorsExtension.light);
    expect(
      AppColorsExtension.light.copyWith().hashCode,
      AppColorsExtension.light.hashCode,
    );
    expect(const AppCardTheme(opacity: .4), const AppCardTheme(opacity: .4));
  });

  test(
    'save status and unchanged accent do not broadcast global appearance',
    () async {
      final store = _Store();
      Color? accent = const Color(0xff123456);
      final c = AppearanceController(
        store: store,
        readAccent: () async => accent,
      );
      addTearDown(c.dispose);
      await c.initialize(observeSystem: false);
      var globalChanges = 0, statusChanges = 0;
      c.appearanceChanges.addListener(() => globalChanges++);
      Listenable.merge([c, c.statusChanges]).addListener(() => statusChanges++);
      c.update(c.preferences.copyWith(slotVisibility: {'aboveEditor': false}));
      expect(globalChanges, 1);
      await c.settled;
      expect(globalChanges, 1);
      expect(statusChanges, 2);
      await c.refreshSystemColor();
      expect(globalChanges, 1);
      expect(statusChanges, 4);
      accent = const Color(0xff987654);
      await c.refreshSystemColor();
      expect(globalChanges, 2);
      store.failSave = true;
      c.update(c.preferences.copyWith(uiScale: 1.25));
      await c.settled;
      expect(globalChanges, 3);
      expect(c.saveFailed, isTrue);
      store.failSave = false;
      c.retrySave();
      await c.settled;
      expect(c.saveFailed, isFalse);
      expect(globalChanges, 4);
    },
  );

  test(
    'independent frame caps default, round trip and reject invalid values',
    () {
      final defaults = AppearancePreferences.fromJson({'version': 1});
      expect(defaults.frameRate, 120);
      expect(defaults.animationFrameRate, 30);
      final configured = defaults.copyWith(
        frameRate: 60,
        animationFrameRate: 0,
      );
      final loaded = AppearancePreferences.fromJson(configured.toJson());
      expect(loaded.frameRate, 60);
      expect(loaded.animationFrameRate, 0);
      for (final invalid in [-1, 1, 60.5, '120', double.infinity]) {
        final value = AppearancePreferences.fromJson({
          'version': 1,
          'frameRate': invalid,
          'animationFrameRate': invalid,
        });
        expect(value.frameRate, 120);
        expect(value.animationFrameRate, 30);
      }
    },
  );

  test('versioned preferences tolerate bad fields and isolate brightness overrides', () {
    final p = AppearancePreferences.fromJson({
      'version': 1,
      'mode': 'unknown',
      'source': 'custom',
      'seed': '#123ABC',
      'baseFontSize': 99,
      'uiScale': -3,
      'lightColors': {
        'canvas': '#fF0000',
        'unknown': '#123456',
        'sidebar': 'oops',
      },
      'darkColors': {'composer': '#334455'},
    });
    expect(p.mode, AppearanceMode.system);
    expect(p.source, PaletteSource.custom);
    expect(p.baseFontSize, 18);
    expect(p.uiScale, 0.8);
    expect(p.seed, 0xff123abc);
    expect(p.lightColors, {AppearanceColor.canvas: 0xffff0000});
    expect(AppearancePreferences.fromJson(p.toJson()).toJson(), p.toJson());
    final reset = p.withColor(AppearanceColor.canvas, null, dark: false);
    expect(reset.lightColors, isEmpty);
    expect(reset.darkColors, p.darkColors);
    expect(
      () => AppearancePreferences.fromJson({'version': 2}),
      throwsFormatException,
    );
    expect(parseHexRgb('#12345678'), isNull);
    expect(parseHexRgb('#fff'), isNull);
  });

  test('tool display tier and extension slot switches persist and tolerate bad data', () {
    // 缺省：简略挡位、全部槽位可见
    final d = AppearancePreferences.fromJson({'version': 1});
    expect(d.toolDisplay, ToolDisplayMode.compact);
    expect(d.isSlotVisible('aboveEditor'), isTrue);
    expect(d.isSlotVisible('notificationToast'), isTrue);

    // 持久化往返：只保存被关闭的槽位，非法挡位/类型回退默认
    final p = AppearancePreferences.fromJson({
      'version': 1,
      'toolDisplay': 'expanded',
      'slotVisibility': {
        'aboveEditor': false,
        'statusBar': true,
        'weird': false,
      },
    });
    expect(p.toolDisplay, ToolDisplayMode.expanded);
    expect(p.isSlotVisible('aboveEditor'), isFalse);
    expect(p.isSlotVisible('statusBar'), isTrue);
    expect(p.toJson()['slotVisibility'], {
      'aboveEditor': false,
      'weird': false,
    });
    expect(AppearancePreferences.fromJson(p.toJson()).slotVisibility, {
      'aboveEditor': false,
      'weird': false,
    });
    final roundTrip = AppearancePreferences.fromJson(p.toJson());
    for (final slot in ['aboveEditor', 'statusBar', 'belowEditor']) {
      expect(roundTrip.isSlotVisible(slot), p.isSlotVisible(slot));
    }
    final bad = AppearancePreferences.fromJson({
      'version': 1,
      'toolDisplay': 'nope',
      'slotVisibility': 'x',
    });
    expect(bad.toolDisplay, ToolDisplayMode.compact);
    expect(bad.slotVisibility, isEmpty);
  });

  test(
    'actual file replacement round trips and rejects damaged data',
    () async {
      final directory = await Directory.systemTemp.createTemp('pi-appearance-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/appearance.json');
      final store = FileAppearanceStore(resolveFile: () async => file);
      expect((await store.load()).baseFontSize, 13);
      await store.save(AppearancePreferences(baseFontSize: 14));
      await store.save(
        AppearancePreferences(
          baseFontSize: 17,
          uiScale: 1.25,
          cardGlass: const GlassPreferences(enabled: true, opacity: 0.4),
        ),
      );
      final loaded = await store.load();
      expect(loaded.baseFontSize, 17);
      expect(loaded.uiScale, 1.25);
      expect(loaded.cardGlass.toJson(), {'enabled': true, 'opacity': 0.4});
      expect(loaded.canvasGlass.enabled, false);
      final controller = AppearanceController(
        store: store,
        readAccent: () async => null,
      );
      addTearDown(controller.dispose);
      await controller.initialize(observeSystem: false);
      controller.reset();
      await controller.settled;
      expect((await store.load()).cardGlass.toJson(), {
        'enabled': false,
        'opacity': 0.75,
      });
      await file.writeAsString('{broken');
      await expectLater(store.load(), throwsFormatException);
    },
  );

  test(
    'system M3 seed, fallback and explicit overrides resolve independently',
    () {
      final settings = AppearancePreferences(source: PaletteSource.system)
          .withColor(AppearanceColor.composer, 0xff123456, dark: false)
          .withColor(AppearanceColor.primary, 0xffeeee22, dark: true);
      final light = AppearancePalette.resolve(
        Brightness.light,
        settings,
        const Color(0xff008844),
      );
      final generated = ColorScheme.fromSeed(
        seedColor: const Color(0xff008844),
      );
      expect(light.primary, generated.primary);
      expect(light.composerBackground, const Color(0xff123456));
      expect(light.cardBackground, generated.surfaceContainerLowest);
      final dark = AppTheme.build(
        Brightness.dark,
        preferences: settings,
        systemAccent: const Color(0xff008844),
      );
      expect(dark.colorScheme.primary, const Color(0xffeeee22));
      expect(
        AppearancePalette.contrast(
          dark.colorScheme.primary,
          dark.colorScheme.onPrimary,
        ),
        greaterThan(4.5),
      );
      final fallback = AppearancePalette.resolve(
        Brightness.light,
        settings,
        null,
      );
      expect(
        fallback.primary,
        ColorScheme.fromSeed(
          seedColor: const Color(AppearancePreferences.defaultSeed),
        ).primary,
      );
      expect(fallback.composerBackground, const Color(0xff123456));
    },
  );

  test(
    'base font and UI scale do not double-scale typography or reset colors',
    () {
      final p = AppearancePreferences(baseFontSize: 16, uiScale: 1.5);
      final theme = AppTheme.build(Brightness.light, preferences: p);
      expect(theme.textTheme.bodyMedium!.fontSize, 16);
      expect(
        theme.textTheme.bodyLarge!.fontSize,
        closeTo(14 * 16 / 13, 0.0001),
      );
      expect(
        theme.extension<AppColorsExtension>()!.canvasBackground,
        AppColorsExtension.light.canvasBackground,
      );
      expect(
        AppTheme.build(
          Brightness.light,
          preferences: p.copyWith(uiScale: 0.8),
        ).textTheme,
        theme.textTheme,
      );
    },
  );

  test(
    'in-flight writes serialize and rapid changes persist the newest snapshot',
    () async {
      final store = _Store();
      final c = AppearanceController(
        store: store,
        readAccent: () async => null,
      );
      addTearDown(c.dispose);
      await c.initialize(observeSystem: false);
      final gate = Completer<void>();
      store.block = gate;
      c.update(c.preferences.copyWith(baseFontSize: 14));
      await Future<void>.delayed(Duration.zero);
      c.update(c.preferences.copyWith(baseFontSize: 15));
      c.update(c.preferences.copyWith(baseFontSize: 18));
      expect(c.preferences.baseFontSize, 18);
      gate.complete();
      await c.settled;
      expect(store.saved, [14, 18]);
      expect(store.value.baseFontSize, 18);
      expect(c.isSaving, false);
    },
  );

  test('save failure keeps live preferences and can be retried', () async {
    final store = _Store()..failLoad = true;
    final c = AppearanceController(
      store: store,
      readAccent: () async => throw StateError('unavailable'),
    );
    addTearDown(c.dispose);
    await c.initialize(observeSystem: false);
    expect(c.loadFailed, true);
    expect(c.systemAccent, isNull);
    store.failSave = true;
    c.update(c.preferences.copyWith(uiScale: 1.25));
    await c.settled;
    expect(c.saveFailed, true);
    expect(c.preferences.uiScale, 1.25);
    store.failSave = false;
    c.retrySave();
    await c.settled;
    expect(c.saveFailed, false);
    expect(store.value.uiScale, 1.25);
  });

  test(
    'system refresh changes seed without overwriting user settings',
    () async {
      Color? accent = const Color(0xff123456);
      final c = AppearanceController(
        store: _Store(),
        readAccent: () async => accent,
      );
      await c.initialize(observeSystem: false);
      c.update(
        c.preferences.withColor(
          AppearanceColor.sidebar,
          0xff654321,
          dark: false,
        ),
      );
      final saved = c.preferences.toJson();
      accent = const Color(0xffabcdef);
      await c.refreshSystemColor();
      expect(c.systemAccent, accent);
      expect(c.preferences.toJson(), saved);
      await c.settled;
      c.dispose();
    },
  );
}
