import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/ui/core/frame_pacer.dart';

class _PendingTimer implements Timer {
  _PendingTimer(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;
  void fire() {
    if (!isActive) return;
    isActive = false;
    tick++;
    callback();
  }

  @override
  void cancel() => isActive = false;
}

void main() {
  test(
    'caps complete frame pairs, coalesces wakeups and never polls while idle',
    () {
      final delivered = <String>[];
      final timers = <_PendingTimer>[];
      var requests = 0;
      final pacer = FramePacer(
        frameRate: 120,
        onBeginFrame: (_) => delivered.add('begin'),
        onDrawFrame: () => delivered.add('draw'),
        requestFrame: () => requests++,
        createTimer: (d, f) {
          final t = _PendingTimer(d, f);
          timers.add(t);
          return t;
        },
      );
      addTearDown(pacer.dispose);
      void frame(int us) {
        pacer.beginFrame(Duration(microseconds: us));
        pacer.drawFrame();
      }

      frame(0);
      expect(delivered, ['begin', 'draw']);
      expect(timers, isEmpty);
      frame(3000);
      frame(6000);
      expect(delivered.length, 2);
      expect(timers.length, 1);
      expect(timers.single.delay.inMicroseconds, 5334);
      timers.single.fire();
      expect(requests, 1);
      frame(9000);
      expect(delivered, ['begin', 'draw', 'begin', 'draw']);
      expect(timers.where((t) => t.isActive), isEmpty);
    },
  );

  test(
    'changing a limit releases a deferred frame; disposal cancels its wakeup',
    () {
      _PendingTimer? timer;
      var requests = 0, draws = 0;
      final pacer = FramePacer(
        frameRate: 30,
        onBeginFrame: (_) {},
        onDrawFrame: () => draws++,
        requestFrame: () => requests++,
        createTimer: (d, f) => timer = _PendingTimer(d, f),
      );
      pacer.beginFrame(Duration.zero);
      pacer.drawFrame();
      pacer.beginFrame(const Duration(milliseconds: 1));
      pacer.drawFrame();
      expect(draws, 1);
      pacer.frameRate = 0;
      expect(requests, 1);
      expect(timer!.isActive, false);
      for (var i = 2; i < 6; i++) {
        pacer.beginFrame(Duration(milliseconds: i));
        pacer.drawFrame();
      }
      expect(draws, 5);
      pacer.frameRate = 60;
      pacer.beginFrame(const Duration(milliseconds: 6));
      pacer.drawFrame();
      pacer.beginFrame(const Duration(milliseconds: 7));
      pacer.drawFrame();
      expect(timer!.isActive, true);
      pacer.dispose();
      timer!.fire();
      expect(requests, 1);
    },
  );
}
