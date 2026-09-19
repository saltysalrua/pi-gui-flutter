import 'package:flutter/widgets.dart';

import '../core/app_frame_policy.dart';

/// A locally isolated decorative loop, paced by the shared demand-driven clock.
/// TickerMode, reduced motion and unmounting all release its subscription.
class AppContinuousAnimation extends StatefulWidget {
  const AppContinuousAnimation({
    super.key,
    required this.period,
    required this.builder,
    this.active = true,
    this.child,
  });
  final Duration period;
  final bool active;
  final Widget? child;
  final Widget Function(BuildContext, double phase, Widget? child) builder;

  @override
  State<AppContinuousAnimation> createState() => _AppContinuousAnimationState();
}

class _AppContinuousAnimationState extends State<AppContinuousAnimation> {
  bool _listening = false;
  AppAnimationClock get _clock => AppAnimationClock.instance;

  void _tick() {
    if (mounted) setState(() {});
  }

  void _sync() {
    final next =
        widget.active &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (next == _listening) return;
    _listening = next;
    if (next) {
      _clock.addListener(_tick);
    } else {
      _clock.removeListener(_tick);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AppContinuousAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    if (_listening) _clock.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: widget.builder(
      context,
      _listening ? _clock.phase(widget.period) : 0,
      widget.child,
    ),
  );
}
