import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Dissolves a vertical scroller's physical bottom edge into any background.
/// Keep fixed footers/actions outside this widget. No tint or hit-test overlay.
class AppScrollEdgeFade extends StatefulWidget {
  const AppScrollEdgeFade({
    super.key,
    required this.child,
    this.extent = AppSpacing.xxl,
  }) : assert(extent > 0);

  final Widget child;
  final double extent;

  @override
  State<AppScrollEdgeFade> createState() => _AppScrollEdgeFadeState();
}

class _AppScrollEdgeFadeState extends State<AppScrollEdgeFade> {
  final _bottomDistance = ValueNotifier<double>(0);

  void _update(ScrollMetrics metrics, int depth) {
    // Inner code blocks/tool previews must not change the outer list's fade.
    if (depth != 0 || metrics.axis != Axis.vertical) return;
    final distance = metrics.axisDirection == AxisDirection.up
        ? metrics.extentBefore
        : metrics.extentAfter;
    _bottomDistance.value = distance.clamp(0.0, widget.extent);
  }

  @override
  void dispose() {
    _bottomDistance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // dstIn uses alpha only; the theme supplies RGB, never a painted backdrop.
    final opaque = Theme.of(context).colorScheme.surface.withValues(alpha: 1);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _update(notification.metrics, notification.depth);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _update(notification.metrics, notification.depth);
          return false;
        },
        child: ValueListenableBuilder<double>(
          valueListenable: _bottomDistance,
          child: widget.child,
          builder: (context, distance, child) => ShaderMask(
            // Keep the same subtree at the end: removing the mask would
            // remount the scrollable and lose selection/scroll/focus state.
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              // Shrink the fade band near the end, rather than leaving a
              // partially opaque edge that the viewport would visibly cut.
              final fadeExtent = distance.clamp(0.0, widget.extent);
              final start = bounds.height > 0
                  ? (1 - fadeExtent / bounds.height).clamp(0.0, 1.0)
                  : 1.0;
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  opaque,
                  opaque,
                  opaque.withValues(alpha: fadeExtent > 0 ? 0 : 1),
                ],
                stops: [0, start, 1],
              ).createShader(bounds);
            },
            child: child,
          ),
        ),
      ),
    );
  }
}
