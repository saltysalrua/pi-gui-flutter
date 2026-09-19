import 'package:pi_gui/ui/atoms/app_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

/// 操作按钮变体类型
enum AppButtonVariant {
  /// 实心强调色主按钮
  primary,

  /// 次要边框按钮
  secondary,

  /// 弱化幽灵按钮
  ghost,

  /// 微妙文本按钮
  subtle,

  /// 胶囊药丸按钮 (如 "+ New Conversation")
  pill,
}

/// 全局标准原子操作按钮 (AppActionButton)
///
/// 遵循 transitions.dev 动效规范，支持 Hover 平滑渐变、按下缩放回弹与减弱动态无障碍适配。
class AppActionButton extends StatefulWidget {
  final String label;

  /// Optional rich label; [label] still describes the action for accessibility.
  final Widget? labelContent;
  final String? subtitle;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final bool isExpanded;

  /// Fill the available label width, keeping trailing content at the far edge.
  /// Leave false for compact actions whose icons should sit beside the label.
  final bool expandLabel;
  final MainAxisAlignment mainAxisAlignment;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? iconSize;
  final TextStyle? labelStyle;
  final double? borderRadius;

  const AppActionButton({
    super.key,
    required this.label,
    this.labelContent,
    this.subtitle,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.isExpanded = false,
    this.expandLabel = false,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.padding,
    this.height,
    this.iconSize,
    this.labelStyle,
    this.borderRadius,
  });

  /// 药丸圆角按钮
  const AppActionButton.pill({
    super.key,
    required this.label,
    this.labelContent,
    this.subtitle,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.isExpanded = false,
    this.expandLabel = false,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.padding,
    this.height = 36.0,
    this.iconSize,
    this.labelStyle,
    this.borderRadius,
  }) : variant = AppButtonVariant.pill;

  /// 圆角矩形轻量按钮 (Subtle / 默认透明无边框，悬浮平滑高亮)
  const AppActionButton.subtle({
    super.key,
    required this.label,
    this.labelContent,
    this.subtitle,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.isExpanded = false,
    this.expandLabel = false,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.padding,
    this.height = 36.0,
    this.iconSize,
    this.labelStyle,
    this.borderRadius,
  }) : variant = AppButtonVariant.subtle;

  @override
  State<AppActionButton> createState() => _AppActionButtonState();
}

class _AppActionButtonState extends State<AppActionButton> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // 依变体与当前交互状态解析颜色与装饰
    Color backgroundColor;
    Color textColor;
    Border? border;
    double borderRadius;
    List<BoxShadow>? shadows;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        backgroundColor = _isEnabled
            ? (_isHovered ? colors.primaryLight : colors.primary)
            : colors.mutedBackground;
        textColor = _isEnabled
            ? Theme.of(context).colorScheme.onPrimary
            : colors.textMuted;
        border = null;
        borderRadius = AppRadius.md;
        shadows = _isEnabled && _isHovered
            ? AppShadows.subtle(
                colors.primary,
                brightness: Theme.of(context).brightness,
              )
            : null;
        break;

      case AppButtonVariant.secondary:
        backgroundColor = _isHovered
            ? colors.hoverBackground
            : Colors.transparent;
        textColor = _isEnabled ? colors.textPrimary : colors.textMuted;
        border = Border.all(
          color: _isFocused
              ? colors.borderFocus
              : (_isHovered ? colors.borderHover : colors.borderDefault),
        );
        borderRadius = AppRadius.md;
        break;

      case AppButtonVariant.ghost:
        backgroundColor = _isHovered
            ? colors.primaryTint
            : colors.mutedBackground;
        textColor = _isEnabled ? colors.primary : colors.textMuted;
        border = null;
        borderRadius = AppRadius.md;
        break;

      case AppButtonVariant.subtle:
        backgroundColor = _isHovered
            ? colors.hoverBackground
            : Colors.transparent;
        textColor = _isEnabled ? colors.textPrimary : colors.textMuted;
        border = null;
        borderRadius = AppRadius.md;
        break;

      case AppButtonVariant.pill:
        // 遵循极简克制：默认与所在背景同色 (透明融合)，仅带细微精致边框，悬停时平滑显现浅色高亮
        backgroundColor = _isHovered
            ? colors.hoverBackground
            : Colors.transparent;
        textColor = _isEnabled ? colors.textPrimary : colors.textMuted;
        border = Border.all(
          color: _isHovered ? colors.borderHover : colors.borderDefault,
        );
        borderRadius = AppRadius.pill;
        shadows = null;
        break;
    }

    final effectivePadding =
        widget.padding ??
        EdgeInsets.symmetric(
          horizontal: widget.variant == AppButtonVariant.pill
              ? AppSpacing.lg
              : AppSpacing.md,
          vertical: AppSpacing.sm,
        );

    final effectiveBorderRadius = widget.borderRadius ?? borderRadius;
    if (_isFocused && _isEnabled) {
      border = Border.all(color: colors.borderFocus);
    }

    Widget content = Row(
      mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: widget.mainAxisAlignment,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: 14,
            height: 14,
            child: AppProgressIndicator(
              strokeWidth: 2,
              color: textColor,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (widget.leading != null) ...[
          IconTheme(
            data: IconThemeData(size: widget.iconSize ?? 16, color: textColor),
            child: widget.leading!,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          fit: widget.expandLabel ? FlexFit.tight : FlexFit.loose,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Start/end-aligned actions must not center a short title over a
            // longer subtitle. Centered actions retain their compact layout.
            crossAxisAlignment: switch (widget.mainAxisAlignment) {
              MainAxisAlignment.start => CrossAxisAlignment.start,
              MainAxisAlignment.end => CrossAxisAlignment.end,
              _ => CrossAxisAlignment.center,
            },
            children: [
              widget.labelContent != null
                  ? Semantics(
                      label: widget.label,
                      child: ExcludeSemantics(child: widget.labelContent!),
                    )
                  : Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: (widget.labelStyle ?? textTheme.labelLarge)
                          ?.copyWith(
                            color: _isEnabled
                                ? (widget.labelStyle?.color ?? textColor)
                                : textColor,
                            fontWeight:
                                widget.labelStyle?.fontWeight ??
                                (widget.variant == AppButtonVariant.pill
                                    ? FontWeight.w600
                                    : FontWeight.w500),
                          ),
                    ),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
            ],
          ),
        ),
        if (widget.trailing != null && !widget.isLoading) ...[
          const SizedBox(width: AppSpacing.sm),
          IconTheme(
            data: IconThemeData(size: widget.iconSize ?? 16, color: textColor),
            child: widget.trailing!,
          ),
        ],
      ],
    );

    final duration = reduceMotion ? Duration.zero : AppDurations.fast;
    final scaleDuration = reduceMotion ? Duration.zero : AppDurations.micro;

    return FocusableActionDetector(
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
      onShowFocusHighlight: (v) => setState(() => _isFocused = v),
      onShowHoverHighlight: (v) => setState(() => _isHovered = v),
      mouseCursor: _isEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _isEnabled ? widget.onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: scaleDuration,
          curve: AppCurves.smoothOut,
          child: AnimatedContainer(
            duration: duration,
            curve: AppCurves.smoothOut,
            // Height is a minimum for every variant, including single-line labels.
            // System text scaling must not clip a short tool/disclosure header.
            constraints: BoxConstraints(minHeight: widget.height ?? 0),
            padding: effectivePadding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              border: border,
              boxShadow: shadows,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
