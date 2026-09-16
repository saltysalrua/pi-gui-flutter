import 'package:flutter/material.dart';

import 'app_card.dart';
import 'app_resize_divider.dart';
import 'custom_title_bar.dart';
import '../core/theme/app_tokens.dart';

/// Shared desktop shell. Both regions are painted once, side by side, not as
/// translucent cards over an opaque Scaffold or over each other's tint.
class AppDesktopScaffold extends StatelessWidget {
  const AppDesktopScaffold({
    super.key,
    required this.sidebarBackground,
    required this.contentBackground,
    required this.child,
    this.sidebar,
    this.sidebarWidth = 0,
    this.onSidebarResize,
    this.onSidebarReset,
    this.animate = true,
    this.contentAnimation,
  });
  final Color sidebarBackground, contentBackground;
  final Widget? sidebar;
  final double sidebarWidth;
  final ValueChanged<double>? onSidebarResize;
  final VoidCallback? onSidebarReset;
  final bool animate;

  /// Optional page entry/exit motion. Backgrounds, title bar and divider stay
  /// fixed, and content opacity is never changed (safe for Acrylic/backdrops).
  final Animation<double>? contentAnimation;
  final Widget child;
  static const _dividerWidth = 10.0;
  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(AppRadius.xl),
  );

  @override
  Widget build(BuildContext context) {
    const title = CustomTitleBar(backgroundColor: Colors.transparent);
    final left = sidebar == null ? 0.0 : sidebarWidth + _dividerWidth;
    final duration = !animate || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDurations.fast;
    Widget movingContent(Widget content, {bool clip = false}) {
      final animation = contentAnimation;
      // Leave existing pages' subtree paths untouched unless they opt in.
      if (animation == null) return content;
      final moving = AnimatedBuilder(
        animation: animation,
        child: content,
        builder: (context, child) {
          final progress = MediaQuery.disableAnimationsOf(context)
              ? 1.0
              : AppCurves.smoothOut.transform(animation.value);
          return Transform.translate(
            offset: Offset(AppSpacing.sm * (1 - progress), 0),
            child: child,
          );
        },
      );
      return clip ? ClipRect(child: moving) : moving;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: sidebarBackground),
        duration: duration,
        curve: AppCurves.smoothOut,
        builder: (context, side, child) => TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: contentBackground),
          duration: duration,
          curve: AppCurves.smoothOut,
          builder: (context, main, child) => CustomPaint(
            painter: _RegionPainter(
              side!,
              main!,
              left,
              title.preferredSize.height,
            ),
            child: child,
          ),
          child: child,
        ),
        child: Column(
          children: [
            title,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sidebar != null) ...[
                    SizedBox(
                      width: sidebarWidth,
                      child: movingContent(sidebar!, clip: true),
                    ),
                    AppResizeDivider(
                      hitWidth: _dividerWidth,
                      showIdleIndicator: false,
                      leftColor: Colors.transparent,
                      rightColor: Colors.transparent,
                      onDelta: onSidebarResize ?? (_) {},
                      onReset: onSidebarReset,
                    ),
                  ],
                  Expanded(
                    child: AppCard(
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      showBorder: false,
                      borderRadiusGeometry: _radius,
                      clipBehavior: Clip.antiAlias,
                      child: movingContent(child),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionPainter extends CustomPainter {
  const _RegionPainter(this.sidebar, this.content, this.left, this.top);
  final Color sidebar, content;
  final double left, top;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final main = Path()
      ..addRRect(
        AppDesktopScaffold._radius.toRRect(
          Rect.fromLTRB(left, top, size.width, size.height),
        ),
      );
    final rest = Path.combine(
      PathOperation.difference,
      Path()..addRect(bounds),
      main,
    );
    canvas.drawPath(rest, Paint()..color = sidebar);
    canvas.drawPath(main, Paint()..color = content);
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      sidebar != oldDelegate.sidebar ||
      content != oldDelegate.content ||
      left != oldDelegate.left ||
      top != oldDelegate.top;
}
