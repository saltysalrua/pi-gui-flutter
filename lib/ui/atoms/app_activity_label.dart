import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';

/// Non-blocking shimmer for active work, static text when reduced motion is on.
class AppActivityLabel extends StatefulWidget {
  const AppActivityLabel({
    super.key,
    required this.text,
    this.active = false,
    this.style,
    this.maxLines = 2,
  });
  final String text;
  final bool active;
  final TextStyle? style;
  final int maxLines;
  @override
  State<AppActivityLabel> createState() => _AppActivityLabelState();
}

class _AppActivityLabelState extends State<AppActivityLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: AppDurations.verySlow * 3,
  );
  void _sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      // Streaming rebuilds must not replace an already running simulation.
      if (!_animation.isAnimating) _animation.repeat();
    } else {
      _animation.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AppActivityLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(
      widget.text,
      style: widget.style ?? context.textTheme.bodySmall,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
    );
    final animate = widget.active && !MediaQuery.disableAnimationsOf(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      // Keep the shader tight around the glyphs even in a stretched Column.
      // Composer status, tool rows and thinking then have the same sweep.
      child: !animate
          ? label
          : AnimatedBuilder(
              animation: _animation,
              child: label,
              builder: (context, child) => ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(-3 + _animation.value * 4, 0),
                  end: Alignment(-1 + _animation.value * 4, 0),
                  colors: [
                    context.colors.textMuted,
                    context.colors.textPrimary,
                    context.colors.textMuted,
                  ],
                  stops: const [0, 0.5, 1],
                ).createShader(bounds),
                child: child,
              ),
            ),
    );
  }
}
