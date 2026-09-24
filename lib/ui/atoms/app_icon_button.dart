import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

/// 图标按钮样式变体
enum AppIconButtonVariant {
  /// 默认透明，悬停时出现微背景
  subtle,

  /// 实心强调色圆形（例如发送按钮）
  filledPrimary,
}

/// 全局标准原子图标按钮 (AppIconButton)
///
/// 遵循 transitions.dev 动效规范，支持微交互反馈、弹性回弹与减弱动态无障碍适配。
class AppIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final AppIconButtonVariant variant;
  final Color? color;
  final bool isCircular;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 32.0,
    this.iconSize = 16.0,
    this.variant = AppIconButtonVariant.subtle,
    this.color,
    this.isCircular = false,
  });

  /// 快速构建轻量悬浮图标按钮 (默认透明，悬停微高亮)
  const AppIconButton.subtle({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 28.0,
    this.iconSize = 16.0,
    this.color,
    this.isCircular = false,
  }) : variant = AppIconButtonVariant.subtle;

  /// 快速构建实心主要操作圆钮 (例如发送按钮)
  const AppIconButton.primaryCircle({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 32.0,
    this.iconSize = 16.0,
    this.color,
  }) : variant = AppIconButtonVariant.filledPrimary,
       isCircular = true;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  bool get _isEnabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Color backgroundColor;
    Color iconColor;

    switch (widget.variant) {
      case AppIconButtonVariant.subtle:
        backgroundColor = _isHovered
            ? colors.hoverBackground
            : Colors.transparent;
        iconColor = _isEnabled
            ? (widget.color ??
                  (_isHovered ? colors.textPrimary : colors.textSecondary))
            : colors.textMuted;
        break;

      case AppIconButtonVariant.filledPrimary:
        backgroundColor = _isEnabled
            ? (_isHovered ? colors.primaryLight : colors.primary)
            : colors.mutedBackground;
        iconColor = _isEnabled
            ? Theme.of(context).colorScheme.onPrimary
            : colors.textMuted;
        break;
    }

    final side = _isFocused
        ? BorderSide(color: colors.borderFocus)
        : BorderSide.none;
    final shape = widget.isCircular
        ? CircleBorder(side: side)
        : RoundedRectangleBorder(
            side: side,
            borderRadius: BorderRadius.circular(AppRadius.md),
          );

    final duration = reduceMotion ? Duration.zero : AppDurations.quick;
    final scaleDuration = reduceMotion ? Duration.zero : AppDurations.micro;

    Widget button = FocusableActionDetector(
      enabled: _isEnabled,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (_isEnabled) widget.onPressed?.call();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (value) => setState(() => _isFocused = value),
      onShowHoverHighlight: (v) => setState(() => _isHovered = v),
      mouseCursor: _isEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? AppMotionScales.press : 1.0,
          duration: scaleDuration,
          curve: AppCurves.smoothOut,
          child: AnimatedContainer(
            duration: duration,
            curve: AppCurves.smoothOut,
            width: widget.size,
            height: widget.size,
            decoration: ShapeDecoration(color: backgroundColor, shape: shape),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && Overlay.maybeOf(context) != null) {
      button = Tooltip(
        message: widget.tooltip!,
        excludeFromSemantics: true,
        waitDuration: AppDurations.verySlow,
        child: button,
      );
    }

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.tooltip,
      child: button,
    );
  }
}
