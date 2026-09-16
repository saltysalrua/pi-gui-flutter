import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Card material tokens, animated by the app's existing Theme transition.
/// These are targets only: AppCard still checks native/accessibility policy.
@immutable
class AppCardTheme extends ThemeExtension<AppCardTheme> {
  const AppCardTheme({this.opacity = 1, this.blurSigma = 0});

  final double opacity;
  final double blurSigma;

  @override
  AppCardTheme copyWith({double? opacity, double? blurSigma}) => AppCardTheme(
    opacity: opacity ?? this.opacity,
    blurSigma: blurSigma ?? this.blurSigma,
  );

  @override
  AppCardTheme lerp(covariant AppCardTheme? other, double t) => other == null
      ? this
      : AppCardTheme(
          opacity: lerpDouble(opacity, other.opacity, t)!,
          blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
        );
}
