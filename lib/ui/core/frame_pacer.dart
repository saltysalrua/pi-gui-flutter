import 'dart:async';

/// Limits delivered begin/draw PAIRS, not animation time. A deferred request is
/// released by one timer; an idle application never starts a periodic frame loop.
/// Kept independent of Flutter so pending-frame races can be tested cheaply.
class FramePacer {
  FramePacer({
    required this.onBeginFrame,
    required this.onDrawFrame,
    required this.requestFrame,
    required this._frameRate,
    Timer Function(Duration, void Function())? createTimer,
  }) : _createTimer = createTimer ?? Timer.new;

  final Timer Function(Duration, void Function()) _createTimer;
  final void Function(Duration) onBeginFrame;
  final void Function() onDrawFrame, requestFrame;
  int _frameRate;
  Duration? _lastFrame;
  Timer? _pending;
  bool _skipDraw = false, _disposed = false;

  set frameRate(int value) {
    if (_frameRate == value || _disposed) return;
    _frameRate = value;
    _lastFrame = null;
    // Do not strand SchedulerBinding.hasScheduledFrame when changing limits.
    if (_pending != null) {
      _pending!.cancel();
      _pending = null;
      requestFrame();
    }
  }

  void beginFrame(Duration timestamp) {
    if (_disposed) return;
    final previous = _lastFrame;
    final interval = _frameRate <= 0
        ? Duration.zero
        : Duration(microseconds: (1000000 / _frameRate).ceil());
    final elapsed = previous == null ? interval : timestamp - previous;
    if (elapsed >= Duration.zero && elapsed < interval) {
      _skipDraw = true;
      _pending ??= _createTimer(interval - elapsed, () {
        _pending = null;
        if (!_disposed) requestFrame();
      });
      return;
    }
    _pending?.cancel();
    _pending = null;
    _skipDraw = false;
    _lastFrame = timestamp;
    onBeginFrame(timestamp);
  }

  void drawFrame() {
    if (!_disposed && !_skipDraw) onDrawFrame();
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _pending = null;
  }
}
