import 'package:flutter/material.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

/// 可拖拽分割调节条组件 (AppResizeDivider)
///
/// 遵循 transitions.dev 动效规范，支持左右拖拽调节侧边栏宽度、双击复位、
/// 以及鼠标悬停时高质感指示条加长高亮反馈。
class AppResizeDivider extends StatefulWidget {
  final ValueChanged<double> onDelta;
  final VoidCallback? onReset;
  final double hitWidth;
  final double defaultHandleHeight;
  final double expandedHandleHeight;
  final double handleThickness;

  /// Hide the separator and resting handle for a seamless surface boundary.
  /// Hover/drag feedback and the full hit area remain available.
  final bool showIdleIndicator;
  final Color? leftColor;
  final Color? rightColor;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const AppResizeDivider({
    super.key,
    required this.onDelta,
    this.onReset,
    this.hitWidth = 10.0,
    this.defaultHandleHeight = 28.0,
    this.expandedHandleHeight = 44.0,
    this.handleThickness = 3.0,
    this.showIdleIndicator = true,
    this.leftColor,
    this.rightColor,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  State<AppResizeDivider> createState() => _AppResizeDividerState();
}

class _AppResizeDividerState extends State<AppResizeDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final isActive = _isHovered || _isDragging;
    final handleHeight = isActive
        ? widget.expandedHandleHeight
        : widget.defaultHandleHeight;

    final handleColor = _isDragging
        ? colors.primary
        : (_isHovered
              ? colors.primary.withValues(alpha: 0.7)
              : colors.borderDefault);

    final duration = reduceMotion ? Duration.zero : AppDurations.quick;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onReset,
        onHorizontalDragStart: (_) {
          widget.onDragStart?.call();
          setState(() => _isDragging = true);
        },
        onHorizontalDragUpdate: (details) => widget.onDelta(details.delta.dx),
        onHorizontalDragEnd: (_) {
          widget.onDragEnd?.call();
          setState(() => _isDragging = false);
        },
        onHorizontalDragCancel: () {
          widget.onDragEnd?.call();
          setState(() => _isDragging = false);
        },
        child: SizedBox(
          width: widget.hitWidth,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 左半侧与右半侧无缝贴合各自容器背景底色
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        color: widget.leftColor ?? colors.sidebarBackground,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: widget.rightColor ?? colors.canvasBackground,
                      ),
                    ),
                  ],
                ),
              ),

              // 无缝模式不绘制常驻分隔线，其他面板保持原有样式。
              if (widget.showIdleIndicator)
                Positioned.fill(
                  child: Center(
                    child: Container(width: 1.0, color: colors.borderDefault),
                  ),
                ),

              // 居中自适应胶囊手柄 (Hover / 拖拽动态反馈)
              AnimatedOpacity(
                opacity: widget.showIdleIndicator || isActive ? 1 : 0,
                duration: duration,
                curve: AppCurves.smoothOut,
                child: AnimatedContainer(
                  duration: duration,
                  curve: AppCurves.smoothOut,
                  width: widget.handleThickness,
                  height: handleHeight,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
