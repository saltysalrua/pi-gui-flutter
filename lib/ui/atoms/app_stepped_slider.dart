import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

/// 全局原子步进滑块组件 (AppSteppedSlider)
///
/// 遵循 transitions.dev 动效规范与原子设计准则。
/// 专用于离散等级选择（如思考强度），支持拖拽、点击、刻度圆点高亮与顺滑补间动效。
class AppSteppedSlider extends StatefulWidget {
  final int steps;
  final int value;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeEnd;

  /// 短暂提交期间拦截操作，但保留正常外观与键盘焦点，不闪成禁用态。
  final bool isBusy;
  final bool showTicks;
  final double height;
  final double thumbSize;
  final String? semanticLabel;
  final String? valueLabel;

  const AppSteppedSlider({
    super.key,
    required this.steps,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.isBusy = false,
    this.showTicks = true,
    this.semanticLabel,
    this.valueLabel,
    this.height = 28.0,
    this.thumbSize = 30.0,
  }) : assert(steps > 1, 'steps must be greater than 1');

  @override
  State<AppSteppedSlider> createState() => _AppSteppedSliderState();
}

class _AppSteppedSliderState extends State<AppSteppedSlider> {
  bool _isDragging = false;
  double? _dragFraction;
  bool _focused = false;

  void _move(int delta) {
    if (widget.onChanged == null || widget.isBusy) return;
    final next = (widget.value + delta).clamp(0, widget.steps - 1);
    widget.onChanged?.call(next);
    widget.onChangeEnd?.call(next);
  }

  void _updateFromPosition(double localX, double totalWidth) {
    if (widget.onChanged == null || widget.isBusy) return;
    final trackRadius = widget.height / 2;
    final availableWidth = totalWidth - widget.height;
    if (availableWidth <= 0) return;

    final clampedX = (localX - trackRadius).clamp(0.0, availableWidth);
    final fraction = clampedX / availableWidth;
    final step = (fraction * (widget.steps - 1)).round().clamp(
      0,
      widget.steps - 1,
    );

    setState(() {
      _dragFraction = fraction;
    });

    if (step != widget.value) {
      widget.onChanged?.call(step);
    }
  }

  void _commit() {
    if (widget.onChanged == null || widget.isBusy) return;
    final fraction = _dragFraction;
    if (fraction != null) {
      final step = (fraction * (widget.steps - 1)).round().clamp(
        0,
        widget.steps - 1,
      );
      widget.onChangeEnd?.call(step);
    } else {
      widget.onChangeEnd?.call(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onChanged != null || widget.isBusy;
    final interactive = enabled && !widget.isBusy;

    return Semantics(
      label: widget.semanticLabel,
      value: widget.valueLabel,
      slider: true,
      enabled: interactive,
      onIncrease: interactive ? () => _move(1) : null,
      onDecrease: interactive ? () => _move(-1) : null,
      child: Focus(
        canRequestFocus: enabled,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent || !enabled) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _move(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _move(-1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(
              color: _focused
                  ? colors.borderFocus
                  : colors.borderFocus.withValues(alpha: 0),
            ),
          ),
          child: AbsorbPointer(
            absorbing: !interactive,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.45,
              duration: reduceMotion ? Duration.zero : AppDurations.quick,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final trackRadius = widget.height / 2;
                  final thumbRadius = widget.thumbSize / 2;
                  final availableWidth = totalWidth - widget.height;

                  final currentStepFraction =
                      (widget.value / (widget.steps - 1)).clamp(0.0, 1.0);
                  final targetFraction = _isDragging && _dragFraction != null
                      ? _dragFraction!.clamp(0.0, 1.0)
                      : currentStepFraction;

                  return MouseRegion(
                    cursor: widget.isBusy
                        ? SystemMouseCursors.progress
                        : enabled
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        _updateFromPosition(
                          details.localPosition.dx,
                          totalWidth,
                        );
                        _commit();
                        setState(() {
                          _isDragging = false;
                          _dragFraction = null;
                        });
                      },
                      onHorizontalDragStart: (details) {
                        setState(() => _isDragging = true);
                        _updateFromPosition(
                          details.localPosition.dx,
                          totalWidth,
                        );
                      },
                      onHorizontalDragUpdate: (details) {
                        _updateFromPosition(
                          details.localPosition.dx,
                          totalWidth,
                        );
                      },
                      onHorizontalDragEnd: (_) {
                        _commit();
                        setState(() {
                          _isDragging = false;
                          _dragFraction = null;
                        });
                      },
                      onHorizontalDragCancel: () {
                        setState(() {
                          _isDragging = false;
                          _dragFraction = null;
                        });
                      },
                      child: SizedBox(
                        width: totalWidth,
                        height: widget.height,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: targetFraction),
                          duration: _isDragging || reduceMotion
                              ? Duration.zero
                              : AppDurations.fast,
                          curve: AppCurves.smoothOut,
                          builder: (context, fraction, _) {
                            final thumbCenter =
                                trackRadius + fraction * availableWidth;
                            final thumbLeft = thumbCenter - thumbRadius;
                            final activeTrackWidth = thumbCenter;

                            return Stack(
                              alignment: Alignment.centerLeft,
                              clipBehavior: Clip.none,
                              children: [
                                // 1. 底层完整胶囊轨道 (含未激活背景与高亮激活进度)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    widget.height / 2,
                                  ),
                                  child: SizedBox(
                                    width: totalWidth,
                                    height: widget.height,
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        // 1.1 未激活完整背景
                                        Container(
                                          width: totalWidth,
                                          height: widget.height,
                                          color: colors.hoverBackground,
                                        ),

                                        // 1.2 激活高亮轨道 (严格随 fraction 动画，不脱节)
                                        Container(
                                          width: activeTrackWidth,
                                          height: widget.height,
                                          color: colors.primary,
                                        ),

                                        // 1.3 各步进刻度指示点 (Dots)
                                        if (widget.showTicks)
                                          for (
                                            int i = 0;
                                            i < widget.steps;
                                            i++
                                          ) ...[
                                            Builder(
                                              builder: (context) {
                                                final dotCenter =
                                                    trackRadius +
                                                    (i / (widget.steps - 1)) *
                                                        availableWidth;
                                                final isDotActive =
                                                    dotCenter <=
                                                    activeTrackWidth;

                                                return Positioned(
                                                  left: dotCenter - 2.5,
                                                  top:
                                                      (widget.height - 5.0) / 2,
                                                  child: IgnorePointer(
                                                    child: Container(
                                                      width: 5.0,
                                                      height: 5.0,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isDotActive
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary
                                                                  .withValues(
                                                                    alpha: 0.85,
                                                                  )
                                                            : colors.textMuted
                                                                  .withValues(
                                                                    alpha: 0.45,
                                                                  ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                      ],
                                    ),
                                  ),
                                ),

                                // 2. 白色圆形滑块手柄 (Thumb)，置于 ClipRRect 外部以保持柔和投影
                                Positioned(
                                  left: thumbLeft,
                                  top: (widget.height - widget.thumbSize) / 2,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: widget.thumbSize,
                                      height: widget.thumbSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.controlThumb,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .shadow
                                                .withValues(alpha: 0.16),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
