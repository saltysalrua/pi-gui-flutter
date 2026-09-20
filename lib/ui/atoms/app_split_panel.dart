import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';
import 'app_resize_divider.dart';

/// Resizable end panel with disjoint translucent backgrounds. In overlay mode
/// the covered conversation is clipped, not painted underneath the glass.
class AppSplitPanel extends StatefulWidget {
  const AppSplitPanel({
    super.key,
    required this.child,
    required this.panel,
    required this.isOpen,
    required this.onDismiss,
    required this.contentBackground,
    required this.panelBackground,
    this.animateMaterial = true,
  });
  final Widget child, panel;
  final bool isOpen, animateMaterial;
  final VoidCallback onDismiss;
  final Color contentBackground, panelBackground;
  @override
  State<AppSplitPanel> createState() => _AppSplitPanelState();
}

class _AppSplitPanelState extends State<AppSplitPanel> {
  double _width = 300;
  bool _dragging = false;
  static const _divider = 10.0;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final overlay = constraints.maxWidth < 640;
      final maximum = math.max(
        0.0,
        math.min(
          640.0,
          overlay ? constraints.maxWidth * 0.85 : constraints.maxWidth - 370,
        ),
      );
      final minimum = math.min(240.0, maximum);
      final width = _width.clamp(minimum, maximum);
      final target = widget.isOpen ? width + _divider : 0.0;
      final reduced = MediaQuery.disableAnimationsOf(context);
      final duration = reduced || _dragging
          ? Duration.zero
          : overlay
          ? (widget.isOpen ? AppDurations.fast : AppDurations.quick)
          : (widget.isOpen ? AppDurations.slow : AppDurations.medium);
      final materialDuration = !widget.animateMaterial || reduced
          ? Duration.zero
          : AppDurations.fast;
      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: widget.contentBackground),
        duration: materialDuration,
        curve: AppCurves.smoothOut,
        builder: (context, contentColor, _) => TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: widget.panelBackground),
          duration: materialDuration,
          curve: AppCurves.smoothOut,
          builder: (context, panelColor, _) => TweenAnimationBuilder<double>(
            tween: Tween(end: target),
            duration: duration,
            curve: AppCurves.smoothOut,
            builder: (context, extent, _) {
              final leftWidth = math.max(0.0, constraints.maxWidth - extent);
              return CustomPaint(
                painter: _SplitBackground(contentColor!, panelColor!, extent),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: overlay ? constraints.maxWidth : leftWidth,
                      child: ClipRect(
                        clipper: overlay ? _VisibleContent(leftWidth) : null,
                        child: ExcludeFocus(
                          excluding: overlay && widget.isOpen,
                          child: widget.child,
                        ),
                      ),
                    ),
                    if (overlay && widget.isOpen)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: leftWidth,
                        child: ModalBarrier(
                          color: Theme.of(context).colorScheme.scrim
                              .withValues(alpha: 0.12),
                          onDismiss: widget.onDismiss,
                          semanticsLabel: context.l10n.close,
                          dismissible: true,
                        ),
                      ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: extent,
                      child: ClipRect(
                        child: OverflowBox(
                          minWidth: width + _divider,
                          maxWidth: width + _divider,
                          alignment: Alignment.centerRight,
                          child: IgnorePointer(
                            ignoring: !widget.isOpen,
                            child: ExcludeFocus(
                              excluding: !widget.isOpen,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppResizeDivider(
                                    hitWidth: _divider,
                                    showIdleIndicator: false,
                                    leftColor: Colors.transparent,
                                    rightColor: Colors.transparent,
                                    onDragStart: () =>
                                        setState(() => _dragging = true),
                                    onDragEnd: () =>
                                        setState(() => _dragging = false),
                                    onDelta: (dx) => setState(
                                      // Keep every update between frames; start
                                      // from the visible edge if window-clamped.
                                      () => _width =
                                          (_width.clamp(minimum, maximum) - dx)
                                              .clamp(minimum, maximum),
                                    ),
                                    onReset: () => setState(() => _width = 300),
                                  ),
                                  SizedBox(width: width, child: widget.panel),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class _VisibleContent extends CustomClipper<Rect> {
  const _VisibleContent(this.width);
  final double width;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);
  @override
  bool shouldReclip(_VisibleContent oldClipper) => width != oldClipper.width;
}

class _SplitBackground extends CustomPainter {
  const _SplitBackground(this.content, this.panel, this.extent);
  final Color content, panel;
  final double extent;
  @override
  void paint(Canvas canvas, Size size) {
    final left = math.max(0.0, size.width - extent);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, left, size.height),
      Paint()..color = content,
    );
    canvas.drawRect(
      Rect.fromLTRB(left, 0, size.width, size.height),
      Paint()..color = panel,
    );
  }

  @override
  bool shouldRepaint(_SplitBackground oldDelegate) =>
      content != oldDelegate.content ||
      panel != oldDelegate.panel ||
      extent != oldDelegate.extent;
}
