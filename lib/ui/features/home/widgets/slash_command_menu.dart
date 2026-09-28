import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pi_gui/ui/atoms/app_badge.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/atoms/app_progress_indicator.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import 'package:pi_gui/ui/features/home/controllers/slash_command_controller.dart';
import 'package:pi_gui/ui/features/home/slash_commands.dart';

/// 斜杠命令菜单内容。锚定、宽度和选择状态由 HomeStarterPanel 提供；
/// 这里只负责渲染条目与加载/空/失败三种状态。
class SlashCommandMenu extends StatefulWidget {
  const SlashCommandMenu({
    super.key,
    required this.controller,
    required this.entries,
    required this.selectedIndex,
    required this.onSelected,
    required this.width,
    this.maxHeight = 320,
  });

  final SlashCommandController controller;
  final List<SlashMenuEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double width;

  /// 菜单总高上限；父级用它把浮窗限制在输入卡片上方的窗口空间里。
  final double maxHeight;

  @override
  State<SlashCommandMenu> createState() => _SlashCommandMenuState();
}

class _SlashCommandMenuState extends State<SlashCommandMenu> {
  final _scroll = ScrollController();
  bool _revealPending = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _revealPending = true;
  }

  @override
  void didUpdateWidget(covariant SlashCommandMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.entries.length != widget.entries.length ||
        oldWidget.maxHeight != widget.maxHeight) {
      _revealPending = true;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealSelected(double rowHeight) {
    if (!_revealPending) return;
    _revealPending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || widget.entries.isEmpty) return;
      final position = _scroll.position;
      final top = widget.selectedIndex * rowHeight;
      final bottom = top + rowHeight;
      final offset = top < position.pixels
          ? top
          : bottom > position.pixels + position.viewportDimension
          ? bottom - position.viewportDimension
          : position.pixels;
      final target = offset.clamp(0.0, position.maxScrollExtent);
      // 键盘连续移动不排队动画，选中项始终留在视口里。
      if (target != position.pixels) _scroll.jumpTo(target);
    });
  }

  Widget _status(BuildContext context) {
    final controller = widget.controller;
    final entries = widget.entries;
    final l10n = context.l10n;
    final colors = context.colors;
    if (controller.isBusy && entries.isEmpty && !controller.isReady) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: AppProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(l10n.slashMenuLoading, style: context.textTheme.bodySmall),
        ],
      );
    }
    if (controller.failure != null && entries.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              l10n.slashMenuFailed,
              style: context.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          AppIconButton.subtle(
            icon: Icons.refresh_rounded,
            tooltip: l10n.chatRefresh,
            size: 24,
            iconSize: 14,
            onPressed: () => controller.ensureLoaded(),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        l10n.slashMenuEmpty,
        style: context.textTheme.bodySmall?.copyWith(color: colors.textMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final scaler = MediaQuery.textScalerOf(context);
    // Paragraph 行框会取整；向上取整避免固定行高少掉小数像素而溢出。
    double lineHeight(TextStyle style) =>
        (scaler.scale(style.fontSize!) * (style.height ?? 1.4)).ceilToDouble();
    final rowHeight = math.max(
      40.0,
      lineHeight(context.textTheme.bodyMedium!) +
          lineHeight(context.textTheme.bodySmall!) +
          AppSpacing.xs * 2,
    );
    _revealSelected(rowHeight);
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: AppCard(
            width: widget.width,
            backgroundColor: colors.elevatedBackground,
            padding: const EdgeInsets.all(AppSpacing.xs),
            clipBehavior: Clip.antiAlias,
            shadows: AppShadows.dialog(
              Theme.of(context).colorScheme.shadow,
              brightness: Theme.of(context).brightness,
            ),
            child: widget.entries.isEmpty
                ? SingleChildScrollView(child: _status(context))
                : Scrollbar(
                    controller: _scroll,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: ListView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        primary: false,
                        padding: EdgeInsets.zero,
                        itemExtent: rowHeight,
                        itemCount: widget.entries.length,
                        itemBuilder: (context, index) {
                          final entry = widget.entries[index];
                          return AppNavTile(
                            title: '/${entry.name}',
                            subtitle: entry.description.isEmpty
                                ? null
                                : entry.description,
                            height: rowHeight,
                            isSelected: index == widget.selectedIndex,
                            trailing: AppBadge(
                              label: switch (entry.kind) {
                                SlashEntryKind.builtin =>
                                  l10n.slashSourceBuiltin,
                                SlashEntryKind.terminal =>
                                  l10n.slashSourceTerminal,
                                SlashEntryKind.extension =>
                                  l10n.slashSourceExtension,
                                SlashEntryKind.prompt => l10n.slashSourcePrompt,
                                SlashEntryKind.skill => l10n.slashSourceSkill,
                              },
                              leading: Icon(switch (entry.kind) {
                                SlashEntryKind.builtin =>
                                  Icons.terminal_rounded,
                                SlashEntryKind.terminal =>
                                  Icons.terminal_outlined,
                                SlashEntryKind.extension =>
                                  Icons.extension_rounded,
                                SlashEntryKind.prompt =>
                                  Icons.description_outlined,
                                SlashEntryKind.skill => Icons.school_outlined,
                              }, size: 12),
                            ),
                            onTap: () => widget.onSelected(index),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
