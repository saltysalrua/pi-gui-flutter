import 'package:flutter/material.dart';
import 'package:pi_gui/ui/atoms/app_logo.dart';
import 'package:pi_gui/ui/atoms/window_controls.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

/// 自定义沉浸式桌面标题栏 (CustomTitleBar)
///
/// 遵循用户指定：移除左上角四个按钮与右上角 OPEN IDE，
/// 保留全窗口自由拖拽、双击缩放与标准桌面控制三键。
class CustomTitleBar extends StatefulWidget implements PreferredSizeWidget {
  const CustomTitleBar({super.key, this.backgroundColor});
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(38.0);

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends WindowControlsState<CustomTitleBar> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Container(
      height: 38.0,
      color: widget.backgroundColor ?? colors.sidebarBackground,
      child: Row(
        children: [
          // 左侧：主题自适应 SVG 标记，保留整个区域的窗口拖拽能力。
          buildWindowDragArea(
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: AppLogo(),
            ),
          ),

          // 中间：占据全部剩余空间的窗口拖拽区域（支持双击最大化/向下还原）
          Expanded(child: buildWindowDragArea(child: const SizedBox.expand())),

          // 右侧：窗口控制三键 (最小化、最大化/向下还原、关闭)
          if (isDesktopWindow) ...[
            _WindowButton(
              icon: Icons.remove,
              iconSize: 14,
              tooltip: l10n.windowMinimize,
              onPressed: minimizeWindow,
            ),
            _WindowButton(
              icon: windowIsMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              iconSize: windowIsMaximized ? 11 : 13,
              tooltip: windowIsMaximized
                  ? l10n.windowRestore
                  : l10n.windowMaximize,
              onPressed: toggleMaximizeWindow,
            ),
            _WindowButton(
              icon: Icons.close_rounded,
              iconSize: 15,
              tooltip: l10n.windowClose,
              isClose: true,
              onPressed: closeAppWindow,
            ),
          ],
        ],
      ),
    );
  }
}

/// 窗口控制按钮组件 (基于 transitions.dev 动效规范)
class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final bool isClose;
  final VoidCallback onPressed;

  const _WindowButton({
    required this.icon,
    required this.iconSize,
    required this.tooltip,
    this.isClose = false,
    required this.onPressed,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Color backgroundColor = Colors.transparent;
    Color iconColor = colors.textSecondary;

    if (_isHovered) {
      if (widget.isClose) {
        backgroundColor = const Color(0xFFE81123);
        iconColor = Colors.white;
      } else {
        backgroundColor = colors.hoverBackground;
        iconColor = colors.textPrimary;
      }
    }

    final duration = reduceMotion ? Duration.zero : AppDurations.quick;

    return Tooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: duration,
            curve: AppCurves.smoothOut,
            width: 44,
            height: 38,
            color: backgroundColor,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}
