import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import 'app_continuous_animation.dart';

/// Shared busy indicator. A determinate arc avoids Material's internal repeating
/// Ticker; only the local rotation is animated at the decorative frame limit.
class AppProgressIndicator extends StatelessWidget {
  const AppProgressIndicator({
    super.key,
    this.color,
    this.strokeWidth = 2,
    this.semanticsLabel,
    bool this._active = true,
  });
  final bool? _active;
  bool get active => _active ?? true;
  final Color? color;
  final double strokeWidth;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    child: AppContinuousAnimation(
      active: active,
      period: AppDurations.verySlow * 3,
      child: ExcludeSemantics(
        child: CircularProgressIndicator(
          value: 0.75,
          strokeWidth: strokeWidth,
          color: color,
        ),
      ),
      builder: (context, phase, child) =>
          Transform.rotate(angle: phase * math.pi * 2, child: child),
    ),
  );
}
