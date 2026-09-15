import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

/// Scale the entire logical viewport, including routes, overlays and hit testing.
/// Keep OS text scaling untouched; base typography is already resolved by Theme.
class AppScale extends StatelessWidget {
  const AppScale({super.key, required this.scale, required this.child});
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: scale),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDurations.quick,
    curve: AppCurves.smoothOut,
    child: child,
    builder: (context, value, content) => LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final size = Size(
          constraints.maxWidth / value,
          constraints.maxHeight / value,
        );
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: size,
              child: MediaQuery(
                data: media.copyWith(
                  size: size,
                  devicePixelRatio: media.devicePixelRatio * value,
                  padding: media.padding / value,
                  viewPadding: media.viewPadding / value,
                  viewInsets: media.viewInsets / value,
                  systemGestureInsets: media.systemGestureInsets / value,
                ),
                child: content!,
              ),
            ),
          ),
        );
      },
    ),
  );
}
