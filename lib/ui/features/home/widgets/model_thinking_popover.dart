import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/atoms/app_stepped_slider.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import 'package:pi_gui/ui/features/home/controllers/model_picker_controller.dart';
import 'package:pi_gui/ui/features/home/model_picker_labels.dart';

/// 保留原来的 280px 紧凑浮层；状态与档位来自共享 Controller。
class ModelThinkingPopover extends StatefulWidget {
  const ModelThinkingPopover({super.key, required this.controller});
  final ModelPickerController controller;
  @override
  State<ModelThinkingPopover> createState() => _ModelThinkingPopoverState();
}

class _ModelThinkingPopoverState extends State<ModelThinkingPopover> {
  final _search = TextEditingController();
  late bool _showModels;
  PiThinkingLevel? _draftLevel;
  Timer? _busyIndicatorTimer;
  bool _showBusyIndicator = false;
  ModelPickerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _showModels = controller.selectedModel == null;
    controller.addListener(_busyChanged);
    _busyChanged();
  }

  @override
  void didUpdateWidget(covariant ModelThinkingPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_busyChanged);
      controller.addListener(_busyChanged);
      _busyChanged();
    }
  }

  void _busyChanged() {
    if (!controller.isBusy && !controller.isReconnecting) {
      _busyIndicatorTimer?.cancel();
      _busyIndicatorTimer = null;
      if (_showBusyIndicator) setState(() => _showBusyIndicator = false);
    } else if (_busyIndicatorTimer == null && !_showBusyIndicator) {
      // 短 RPC 不闪一下转圈；真正较慢的读取/提交才显示进度。
      _busyIndicatorTimer = Timer(AppDurations.fast, () {
        _busyIndicatorTimer = null;
        if (mounted) setState(() => _showBusyIndicator = true);
      });
    }
  }

  @override
  void dispose() {
    controller.removeListener(_busyChanged);
    _busyIndicatorTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _select(PiModel model) async {
    final success = await controller.selectModel(model);
    if (mounted && success) {
      setState(() {
        _showModels = false;
        _draftLevel = null;
      });
    }
  }

  Future<void> _commitLevel(PiThinkingLevel level) async {
    await controller.selectThinkingLevel(level);
    if (mounted) setState(() => _draftLevel = null);
  }

  Widget _refreshControl(BuildContext context) {
    final busy = controller.isBusy || controller.isReconnecting;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 28,
      height: 28,
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : AppDurations.quick,
        child: _showBusyIndicator
            ? Tooltip(
                key: const ValueKey('loading'),
                message: controller.isReconnecting
                    ? context.l10n.piReconnecting
                    : context.l10n.modelUpdating,
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      value: reduceMotion ? 0.5 : null,
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              )
            : ExcludeFocus(
                key: const ValueKey('refresh'),
                excluding: busy,
                child: IgnorePointer(
                  ignoring: busy,
                  child: AppIconButton.subtle(
                    icon: Icons.refresh_rounded,
                    tooltip: context.l10n.modelRefresh,
                    onPressed: () => unawaited(controller.refresh()),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _header(BuildContext context, PiThinkingLevel? level, int count) {
    final l10n = context.l10n;
    final colors = context.colors;
    if (_showModels) {
      return Row(
        children: [
          AppIconButton.subtle(
            icon: Icons.chevron_left_rounded,
            tooltip: l10n.back,
            onPressed: controller.selectedModel == null
                ? null
                : () => setState(() => _showModels = false),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.selectModel,
              style: context.textTheme.labelMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          Tooltip(
            message: l10n.availableModelCount(count),
            child: Text(
              '$count',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _refreshControl(context),
        ],
      );
    }
    final model = controller.selectedModel;
    return Row(
      children: [
        const SizedBox(width: 28, height: 28),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Tooltip(
            message: model == null
                ? l10n.selectModel
                : '${model.provider}/${model.id}',
            child: AppActionButton.subtle(
              leading: const SizedBox(width: 16),
              label: level == null
                  ? l10n.selectModel
                  : thinkingLevelLabel(l10n, level),
              subtitle: model?.name,
              trailing: const Icon(Icons.chevron_right_rounded),
              iconSize: 16,
              labelStyle: context.textTheme.titleSmall?.copyWith(
                color: colors.textSecondary,
              ),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              onPressed: () => setState(() => _showModels = true),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _refreshControl(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final colors = context.colors;
      final models = controller.search(_search.text);
      final levels = controller.thinkingLevels;
      final level = _draftLevel ?? controller.thinkingLevel;
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      return Material(
        type: MaterialType.transparency,
        child: AppCard(
          backgroundColor: colors.elevatedBackground,
          width: 280,
          shadows: AppShadows.dialog(
            Theme.of(context).colorScheme.shadow,
            brightness: Theme.of(context).brightness,
          ),
          child: AnimatedSize(
            duration: reduceMotion ? Duration.zero : AppDurations.fast,
            curve: AppCurves.smoothOut,
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, level, models.length),
                if (controller.failure != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    controller.isReconnecting
                        ? l10n.piReconnecting
                        : modelPickerFailureLabel(l10n, controller.failure!),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: controller.isReconnecting
                          ? colors.textMuted
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                SizedBox(height: _showModels ? AppSpacing.sm : AppSpacing.md),
                if (_showModels) ...[
                  AppTextField(
                    controller: _search,
                    hintText: l10n.modelSearchHint,
                    isCompact: true,
                    leading: const Icon(Icons.search_rounded),
                    trailing: _search.text.isEmpty
                        ? null
                        : AppIconButton.subtle(
                            icon: Icons.close_rounded,
                            tooltip: l10n.clearSearch,
                            size: 24,
                            iconSize: 14,
                            onPressed: () => setState(_search.clear),
                          ),
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (models.length == 1 && controller.canChangeModel) {
                        unawaited(_select(models.single));
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (models.isEmpty && controller.failure == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        controller.isBusy
                            ? l10n.modelsLoading
                            : controller.models.isEmpty
                            ? l10n.modelsEmpty
                            : l10n.modelSearchEmpty,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  if (models.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: models.length,
                        itemBuilder: (context, index) {
                          final model = models[index];
                          final selected = model.sameIdentity(
                            controller.selectedModel,
                          );
                          return Tooltip(
                            message: '${model.provider}/${model.id}',
                            child: AppNavTile(
                              title: model.name,
                              height: 36,
                              isSelected: selected,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 72,
                                    ),
                                    child: Text(
                                      model.provider,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textTheme.bodySmall
                                          ?.copyWith(color: colors.textMuted),
                                    ),
                                  ),
                                  if (selected) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: colors.textSecondary,
                                    ),
                                  ],
                                ],
                              ),
                              onTap: controller.canChangeModel
                                  ? () => unawaited(_select(model))
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                ] else if (levels.length > 1 && levels.contains(level))
                  AppSteppedSlider(
                    steps: levels.length,
                    value: levels.indexOf(level!),
                    semanticLabel: l10n.thinkingIntensity,
                    valueLabel: thinkingLevelLabel(l10n, level),
                    isBusy:
                        controller.isBusy &&
                        controller.isReady &&
                        !controller.workspaceLocked,
                    onChanged: controller.canChangeThinking
                        ? (index) => setState(() => _draftLevel = levels[index])
                        : null,
                    onChangeEnd: (index) =>
                        unawaited(_commitLevel(levels[index])),
                  )
                else if (!controller.isBusy && controller.failure == null)
                  Text(
                    levels.length == 1 && levels.single == PiThinkingLevel.off
                        ? l10n.thinkingNotSupported
                        : l10n.thinkingUnavailable,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showModelThinkingPopover({
  required BuildContext context,
  required GlobalKey anchorKey,
  required ModelPickerController controller,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay?.context.findRenderObject();
  final button = anchorKey.currentContext?.findRenderObject();
  if (overlay is! RenderBox || button is! RenderBox) return;

  Rect? readAnchor() {
    // 只缓存 RenderBox，不缓存坐标；退场时不再查找已失活的 Element。
    if (!button.attached || !button.hasSize || !overlay.attached) return null;
    return Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
  }

  final initialAnchor = readAnchor();
  if (initialAnchor == null) return;
  var anchor = initialAnchor;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  unawaited(controller.ensureLoaded());
  await navigator.push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: context.l10n.modelPickerDismiss,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0),
      transitionDuration: reduceMotion ? Duration.zero : AppDurations.fast,
      reverseTransitionDuration: reduceMotion
          ? Duration.zero
          : AppDurations.quick,
      pageBuilder: (context, _, _) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 与 Flutter PopupMenu 的 positionBuilder 一样，在布局阶段读取。
            // 窗口缩放/最大化后跟随按钮；按钮卸载时保留最后位置完成退场。
            anchor = readAnchor() ?? anchor;
            return CustomSingleChildLayout(
              delegate: _PopoverLayout(anchor),
              child: ModelThinkingPopover(controller: controller),
            );
          },
        ),
      ),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          alignment: Alignment.bottomRight,
          scale: Tween(begin: AppMotionScales.dropdown, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: AppCurves.smoothOut),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout(this.anchor);
  final Rect anchor;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(
          280,
          math.max(0, constraints.maxWidth - AppSpacing.xxl),
        ),
        maxHeight: math.min(
          360,
          math.max(0, constraints.maxHeight - AppSpacing.xxl),
        ),
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (anchor.right - childSize.width).clamp(
      AppSpacing.md,
      math.max(AppSpacing.md, size.width - childSize.width - AppSpacing.md),
    ),
    (anchor.top - childSize.height - AppSpacing.sm).clamp(
      AppSpacing.md,
      math.max(AppSpacing.md, size.height - childSize.height - AppSpacing.md),
    ),
  );
  @override
  bool shouldRelayout(_PopoverLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}
