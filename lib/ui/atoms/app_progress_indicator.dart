import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';
import 'app_continuous_animation.dart';

/// Shared ring: a finite [value] displays progress without a repeating ticker.
/// Null keeps the existing busy animation at the decorative frame limit.
class AppProgressIndicator extends StatelessWidget {
  const AppProgressIndicator({
    super.key,
    this.color,
    this.strokeWidth = 2,
    this.semanticsLabel,
    this.value,
    this.backgroundColor,
    bool this._active = true,
  });
  final bool? _active;
  bool get active => _active ?? true;
  final Color? color;
  final double strokeWidth;
  final String? semanticsLabel;
  final double? value;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (value case final target?) {
      return TweenAnimationBuilder<double>(
        tween: Tween(end: target.clamp(0.0, 1.0)),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppDurations.fast,
        curve: AppCurves.smoothOut,
        builder: (context, progress, _) => CircularProgressIndicator(
          value: progress,
          strokeWidth: strokeWidth,
          strokeCap: StrokeCap.round,
          trackGap: 0,
          padding: EdgeInsets.zero,
          color: color ?? context.colors.textSecondary,
          backgroundColor: backgroundColor ?? context.colors.borderDefault,
          semanticsLabel: semanticsLabel,
        ),
      );
    }
    return Semantics(
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
}
