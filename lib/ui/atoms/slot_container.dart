import 'package:flutter/material.dart';
import 'package:pi_gui/core/slots/slot_manager.dart';
import 'package:pi_gui/ui/features/settings/controllers/appearance_controller.dart';

/// 标准动态扩展槽位容器 (SlotContainer)
///
/// 遵循 AGENTS.md 扩展槽位规范，自动监听对应插槽事件。
/// 仅在有活动扩展部件时渲染，支持自定义排列方向与间隔。
class SlotContainer extends StatelessWidget {
  final ExtensibleSlotId slotId;
  final Axis direction;
  final double spacing;
  final EdgeInsetsGeometry? padding;
  final WrapAlignment alignment;
  final bool material;

  const SlotContainer({
    super.key,
    required this.slotId,
    this.direction = Axis.vertical,
    this.spacing = 8.0,
    this.padding,
    this.alignment = WrapAlignment.start,
    this.material = false,
  });

  @override
  Widget build(BuildContext context) {
    // 阻断式弹窗槽是 Pi 扩展的必答交互，只能由设置里暴露的开关控制，
    // 且设置页从不暴露它，因此这里统一读偏好即可（缺省开启）。
    final preferences = AppearanceScope.maybeOf(context)?.preferences;
    if (preferences != null && !preferences.isSlotVisible(slotId.name)) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<List<Widget>>(
      valueListenable: SlotManager.of(context).notifierFor(slotId),
      builder: (context, widgets, _) {
        if (widgets.isEmpty) {
          return const SizedBox.shrink();
        }

        Widget content;
        if (slotId == ExtensibleSlotId.dialogOverlay) {
          content = Stack(fit: StackFit.expand, children: widgets);
        } else if (direction == Axis.vertical) {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < widgets.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                widgets[i],
              ],
            ],
          );
        } else {
          content = Wrap(
            alignment: alignment,
            spacing: spacing,
            runSpacing: spacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: widgets,
          );
        }

        if (padding != null) {
          content = Padding(padding: padding!, child: content);
        }

        Widget result = material
            ? Material(type: MaterialType.transparency, child: content)
            : content;
        if (Overlay.maybeOf(context) == null) {
          result = Overlay.wrap(child: result);
        }
        return result;
      },
    );
  }
}
