import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
          builder: (context, distance, child) => _EdgeFadeMask(
            // Keep the same subtree at the end: removing the mask would
            // remount the scrollable and lose selection/scroll/focus state.
            fadeExtent: distance.clamp(0.0, widget.extent),
            color: opaque,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// ShaderMask that only composites while a fade is visible. A plain ShaderMask
/// renders the whole scroller offscreen even at the end (fade extent 0), which
/// is exactly where a streaming chat spends its time.
class _EdgeFadeMask extends SingleChildRenderObjectWidget {
  const _EdgeFadeMask({
    required this.fadeExtent,
    required this.color,
    super.child,
  });
  final double fadeExtent;
  final Color color;

  @override
  _RenderEdgeFadeMask createRenderObject(BuildContext context) =>
      _RenderEdgeFadeMask(fadeExtent, color);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEdgeFadeMask renderObject,
  ) {
    renderObject
      ..fadeExtent = fadeExtent
      ..color = color;
  }
}

class _RenderEdgeFadeMask extends RenderProxyBox {
  _RenderEdgeFadeMask(this._fadeExtent, this._color);

  double _fadeExtent;
  set fadeExtent(double value) {
    if (value == _fadeExtent) return;
    final wasActive = _fadeExtent > 0;
    _fadeExtent = value;
    if (wasActive != value > 0) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null && _fadeExtent > 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      layer = null;
      return;
    }
    if (_fadeExtent <= 0 || size.height <= 0) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    // Shrink the fade band near the end, rather than leaving a partially
    // opaque edge that the viewport would visibly cut.
    final start = (1 - _fadeExtent / size.height).clamp(0.0, 1.0);
    final bounds = Offset.zero & size;
    layer ??= ShaderMaskLayer();
    layer!
      // dstIn uses alpha only; the theme supplies RGB, never a painted backdrop.
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_color, _color, _color.withValues(alpha: 0)],
        stops: [0, start, 1],
      ).createShader(bounds)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(layer!, super.paint, offset);
  }
}
