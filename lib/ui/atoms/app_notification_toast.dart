import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

/// 全局通知浮层组件 (AppNotificationToast)
///
/// 遵循 transitions.dev 动效规范，支持定时自动消失、鼠标悬停暂停倒计时，
/// 并在右上角关闭按钮 (X) 外圈渲染自适应圆环倒计时进度动画。
class AppNotificationToast extends StatefulWidget {
  final String? message;
  final bool invalidRequest;
  final Duration duration;
  final VoidCallback onDismiss;

  const AppNotificationToast({
    super.key,
    this.message,
    this.invalidRequest = false,
    this.duration = const Duration(seconds: 5),
    required this.onDismiss,
  });

  @override
  State<AppNotificationToast> createState() => _AppNotificationToastState();
}

class _AppNotificationToastState extends State<AppNotificationToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHovered = false;
  bool _isClosing = false;

  static final _ansiRegex = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _dismiss();
      }
    });

    _controller.forward();
  }

  void _dismiss() {
    if (_isClosing || !mounted) return;
    setState(() => _isClosing = true);
    _controller.stop();

    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onDismiss();
      return;
    }

    Future.delayed(AppDurations.quick, () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  void _onMouseEnter() {
    setState(() => _isHovered = true);
    if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  void _onMouseExit() {
    setState(() => _isHovered = false);
    if (!_isClosing && mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _cleanText(BuildContext context) {
    final raw =
        widget.message ??
        (widget.invalidRequest
            ? context.l10n.piExtensionInvalidRequest
            : context.l10n.extensionUnsupported);
    return raw.replaceAll(_ansiRegex, '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final text = _cleanText(context);

    final toastCard = MouseRegion(
      onEnter: (_) => _onMouseEnter(),
      onExit: (_) => _onMouseExit(),
      child: AppCard(
        borderRadius: AppRadius.lg,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shadows: AppShadows.elevated(
          Theme.of(context).colorScheme.shadow,
          brightness: Theme.of(context).brightness,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                text,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _CountdownCloseButton(
              animation: _controller,
              reduceMotion: reduceMotion,
              isHovered: _isHovered,
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );

    if (reduceMotion) {
      return toastCard;
    }

    return AnimatedOpacity(
      duration: AppDurations.quick,
      curve: AppCurves.smoothOut,
      opacity: _isClosing ? 0.0 : 1.0,
      child: AnimatedScale(
        duration: AppDurations.quick,
        curve: AppCurves.smoothOut,
        scale: _isClosing ? 0.95 : 1.0,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: AppDurations.fast,
          curve: AppCurves.smoothOut,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, (1.0 - value) * -8.0),
            child: Opacity(opacity: value, child: child),
          ),
          child: toastCard,
        ),
      ),
    );
  }
}

class _CountdownCloseButton extends StatelessWidget {
  final Animation<double> animation;
  final bool reduceMotion;
  final bool isHovered;
  final VoidCallback onPressed;

  const _CountdownCloseButton({
    required this.animation,
    required this.reduceMotion,
    required this.isHovered,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (!reduceMotion)
          // Repaint only the ring on each tick: no widget rebuild, and the
          // rest of the toast (text, card, glass) stays in its cached layer.
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(28.0, 28.0),
              painter: _CountdownRingPainter(
                animation: animation,
                trackColor: colors.borderDefault.withValues(alpha: 0.35),
                progressColor: isHovered
                    ? colors.primary.withValues(alpha: 0.7)
                    : colors.primary,
                strokeWidth: 2.0,
              ),
            ),
          ),
        AppIconButton.subtle(
          icon: Icons.close_rounded,
          size: 24.0,
          iconSize: 13.0,
          tooltip: l10n.close,
          onPressed: onPressed,
        ),
      ],
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final Animation<double> animation; // elapsed 0.0 -> 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _CountdownRingPainter({
    required this.animation,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // 倒计时剩余比例从 1.0 递减至 0.0
    final progress = (1.0 - animation.value).clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // 绘制浅色背景底圈
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 绘制圆环倒计时进度条
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // 从正上方 12 点钟方向 (-pi / 2) 开始顺时针扫过
      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CountdownRingPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
