import 'dart:async';

import 'package:flutter/widgets.dart';

import 'frame_pacer.dart';

/// GUI-only pacing, installed around the public engine callbacks without
/// replacing WidgetsBinding or restarting the RPC-owning application. Original
/// begin/draw callbacks (including Flutter's warm-up guards) remain paired.
class AppFramePolicy {
  AppFramePolicy._();
  static final instance = AppFramePolicy._();
  FramePacer? _pacer;

  void configure({required int frameRate, required int animationFrameRate}) {
    final binding = WidgetsBinding.instance;
    if (_pacer == null) {
      // scheduleFrame registers the framework callbacks when startup's warm-up
      // frame precedes the first engine frame. Never call handle*Frame ourselves.
      binding.scheduleFrame();
      final dispatcher = binding.platformDispatcher;
      final begin = dispatcher.onBeginFrame;
      final draw = dispatcher.onDrawFrame;
      if (begin != null && draw != null) {
        final pacer = FramePacer(
          onBeginFrame: begin,
          onDrawFrame: draw,
          requestFrame: dispatcher.scheduleFrame,
          frameRate: frameRate,
        );
        _pacer = pacer;
        dispatcher.onBeginFrame = pacer.beginFrame;
        dispatcher.onDrawFrame = pacer.drawFrame;
      }
    }
    _pacer?.frameRate = frameRate;
    AppAnimationClock.instance.configure(frameRate, animationFrameRate);
  }
}

/// One demand-driven clock for all decorative loops. Filtering an ordinary
/// Ticker's notifications would still request frames at the display rate, so
/// this clock only wakes the framework at the selected cadence instead.
class AppAnimationClock extends ChangeNotifier with WidgetsBindingObserver {
  AppAnimationClock._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final instance = AppAnimationClock._();
  final _elapsed = Stopwatch()..start();
  Timer? _timer;
  int _globalRate = 120, _animationRate = 30;
  Duration? _interval;

  double phase(Duration period) =>
      (_elapsed.elapsedMicroseconds % period.inMicroseconds) /
      period.inMicroseconds;

  void configure(int globalRate, int animationRate) {
    if (_globalRate == globalRate && _animationRate == animationRate) return;
    _globalRate = globalRate;
    _animationRate = animationRate;
    _sync();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  @override
  void didChangeMetrics() => _sync();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  void _sync() {
    final binding = WidgetsBinding.instance;
    final visible = switch (binding.lifecycleState) {
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => false,
      _ => true,
    };
    final refresh =
        binding.platformDispatcher.implicitView?.display.refreshRate;
    var rate = refresh != null && refresh.isFinite && refresh > 0
        ? refresh
        : 60.0;
    if (_globalRate > 0 && _globalRate < rate) rate = _globalRate.toDouble();
    if (_animationRate > 0 && _animationRate < rate) {
      rate = _animationRate.toDouble();
    }
    final next = Duration(microseconds: (1000000 / rate).ceil());
    if (!hasListeners || !visible) {
      _timer?.cancel();
      _timer = null;
    } else if (_timer == null || _interval != next) {
      _timer?.cancel();
      _timer = Timer.periodic(next, (_) => notifyListeners());
    }
    _interval = next;
  }
}
