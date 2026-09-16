import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/models/appearance_preferences.dart';
import '../../../../core/services/appearance_store.dart';

/// UI state only. System colors are re-read on focus and platform-theme changes.
class AppearanceController extends ChangeNotifier
    with WidgetsBindingObserver, WindowListener {
  AppearanceController({
    AppearanceStore? store,
    Future<Color?> Function()? readAccent,
  }) : _store = store ?? FileAppearanceStore(),
       _readAccent = readAccent ?? DynamicColorPlugin.getAccentColor;
  static final instance = AppearanceController();
  final AppearanceStore _store;
  final Future<Color?> Function() _readAccent;
  AppearancePreferences _preferences = AppearancePreferences();
  AppearancePreferences get preferences => _preferences;
  Color? systemAccent;
  bool systemColorBusy = false;
  bool loadFailed = false, saveFailed = false, isSaving = false;
  bool _disposed = false, _observing = false;
  int _revision = 0;
  Future<void> _writes = Future.value();
  Future<void> get settled => _writes;

  Future<void> initialize({bool observeSystem = true}) async {
    try {
      _preferences = await _store.load();
    } catch (_) {
      loadFailed = true;
    }
    if (_disposed) return;
    if (observeSystem && !_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
      windowManager.addListener(this);
    }
    await refreshSystemColor();
  }

  void update(AppearancePreferences next) {
    if (_disposed) return;
    // Also sanitize programmatic callers, not just persisted input.
    _preferences = AppearancePreferences.fromJson(next.toJson());
    final snapshot = _preferences;
    final revision = ++_revision;
    isSaving = true;
    saveFailed = false;
    loadFailed = false;
    notifyListeners();
    _writes = _writes.then((_) async {
      // Coalesce rapid slider changes before starting an older write.
      if (revision != _revision) return;
      try {
        await _store.save(snapshot);
        if (revision == _revision) saveFailed = false;
      } catch (_) {
        if (revision == _revision) saveFailed = true;
      }
      if (revision == _revision) {
        isSaving = false;
        if (!_disposed) notifyListeners();
      }
    });
  }

  void retrySave() => update(_preferences);
  void reset() => update(AppearancePreferences());

  Future<void> refreshSystemColor() async {
    if (_disposed || systemColorBusy) return;
    systemColorBusy = true;
    notifyListeners();
    try {
      systemAccent = (await _readAccent())?.withValues(alpha: 1);
    } catch (_) {
      systemAccent = null;
    }
    systemColorBusy = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void onWindowFocus() => unawaited(refreshSystemColor());
  @override
  void didChangePlatformBrightness() => unawaited(refreshSystemColor());
  @override
  void dispose() {
    _disposed = true;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppearanceController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()!.notifier!;
  static AppearanceController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}
