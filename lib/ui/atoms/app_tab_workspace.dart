import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_tabs_controller.dart';
import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';
import 'app_document_tabs.dart';
import 'app_icon_button.dart';
import 'app_menu_button.dart';
import 'app_resize_divider.dart';

enum _TabAction { split, merge, closeOthers }

/// Reusable document host. ALL document bodies remain siblings in one Stack:
/// reorder/split/merge never reparents or duplicates an editor's Element.
/// Hidden panes drop their heavy body (bounded retention) and rebuild it from
/// the owning controller on activation; scroll anchors survive in PageStorage.
/// Background is deliberately transparent; the surrounding scaffold paints it.
class AppTabWorkspace<T extends Object> extends StatefulWidget {
  const AppTabWorkspace({
    super.key,
    required this.controller,
    required this.describeTab,
    required this.builder,
    this.trailing,
  });
  final AppTabsController<T> controller;
  final AppDocumentTab<T> Function(T tab) describeTab;
  final Widget Function(BuildContext context, T tab) builder;
  final Widget? trailing;

  @override
  State<AppTabWorkspace<T>> createState() => _AppTabWorkspaceState<T>();
}

class _AppTabWorkspaceState<T extends Object>
    extends State<AppTabWorkspace<T>> {
  final _weights = <int, double>{};
  static const _minimumPane = 300.0, _divider = 10.0;
  AppTabsController<T> get controller => widget.controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () =>
            controller.close(controller.selected),
        const SingleActivator(LogicalKeyboardKey.f4, control: true): () =>
            controller.close(controller.selected),
        const SingleActivator(LogicalKeyboardKey.tab, control: true): () =>
            controller.cycle(1),
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): () =>
            controller.cycle(-1),
        const SingleActivator(LogicalKeyboardKey.pageDown, control: true): () =>
            controller.cycle(1),
        const SingleActivator(LogicalKeyboardKey.pageUp, control: true): () =>
            controller.cycle(-1),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final groups = controller.groups;
            _weights.removeWhere(
              (id, _) => !groups.any((group) => group.id == id),
            );
            for (final group in groups) {
              _weights.putIfAbsent(group.id, () => 1);
            }
            // Do not squeeze multiple editors into unusable slivers. All tabs
            // remain reachable from the menu, and the original layout returns.
            final compact =
                constraints.maxWidth <
                groups.length * _minimumPane + (groups.length - 1) * _divider;
            final visible = compact ? [controller.activeGroup] : groups;
            final usable = math.max(
              0.0,
              constraints.maxWidth - (visible.length - 1) * _divider,
            );
            final total = visible.fold<double>(
              0,
              (sum, group) => sum + _weights[group.id]!,
            );
            final spare = math.max(0.0, usable - visible.length * _minimumPane);
            final widths = <int, double>{
              for (final group in visible)
                group.id: compact || visible.length == 1
                    ? usable
                    : _minimumPane + spare * _weights[group.id]! / total,
            };
            final lefts = <int, double>{};
            var left = 0.0;
            for (final group in visible) {
              lefts[group.id] = left;
              left += widths[group.id]! + _divider;
            }
            final header = AppDocumentTabs.heightOf(context);
            return Stack(
              children: [
                // Stable order and keys even when a tab moves between groups.
                for (final tab in controller.tabs)
                  _body(tab, lefts, widths, header, constraints),
                for (final group in visible)
                  Positioned(
                    key: ValueKey(('header', group.id)),
                    left: lefts[group.id],
                    width: widths[group.id],
                    top: 0,
                    height: header,
                    child: _header(context, group),
                  ),
                for (var i = 0; i < visible.length - 1; i++)
                  Positioned(
                    key: ValueKey(('divider', visible[i].id)),
                    left: lefts[visible[i].id]! + widths[visible[i].id]!,
                    top: 0,
                    bottom: 0,
                    width: _divider,
                    child: AppResizeDivider(
                      showIdleIndicator: false,
                      leftColor: Colors.transparent,
                      rightColor: Colors.transparent,
                      onReset: () => setState(() {
                        for (final group in groups) {
                          _weights[group.id] = 1;
                        }
                      }),
                      onDelta: (dx) {
                        if (spare <= 0) return;
                        final a = visible[i].id, b = visible[i + 1].id;
                        final pair = widths[a]! + widths[b]!;
                        final next = (widths[a]! + dx).clamp(
                          _minimumPane,
                          pair - _minimumPane,
                        );
                        setState(() {
                          _weights[a] = (next - _minimumPane) * total / spare;
                          _weights[b] =
                              (pair - next - _minimumPane) * total / spare;
                        });
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _body(
    T tab,
    Map<int, double> lefts,
    Map<int, double> widths,
    double header,
    BoxConstraints constraints,
  ) {
    final group = controller.groupOf(tab)!;
    final visible = widths.containsKey(group.id) && group.selected == tab;
    return Positioned(
      key: ValueKey(('document', tab)),
      left: lefts[group.id] ?? 0,
      top: header,
      width: widths[group.id] ?? constraints.maxWidth,
      height: math.max(0, constraints.maxHeight - header),
      child: _DocumentPane(
        visible: visible,
        onActivate: () => controller.activate(tab),
        child: widget.builder(context, tab),
      ),
    );
  }

  Widget _header(BuildContext context, AppTabGroup<T> group) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: AppDocumentTabs<T>(
            tabs: group.tabs.map(widget.describeTab).toList(),
            selected: group.selected,
            dragScope: controller,
            onSelected: controller.activate,
            onClose: controller.close,
            onDrop: (tab, index) =>
                controller.move(tab, group.id, index: index),
          ),
        ),
        AppMenuButton<T>(
          icon: Icons.keyboard_arrow_down,
          tooltip: l10n.tabsAll,
          options: [
            for (final tab in controller.tabs)
              AppMenuOption(
                value: tab,
                label:
                    widget.describeTab(tab).tooltip ??
                    widget.describeTab(tab).label,
                icon: widget.describeTab(tab).icon,
              ),
          ],
          onSelected: controller.activate,
        ),
        AppMenuButton<_TabAction>(
          icon: Icons.more_horiz,
          tooltip: l10n.tabsActions,
          options: [
            if (controller.canSplit(group.selected))
              AppMenuOption(
                value: _TabAction.split,
                label: l10n.tabsSplit,
                icon: Icons.vertical_split_outlined,
              ),
            if (controller.groups.length > 1)
              AppMenuOption(
                value: _TabAction.merge,
                label: l10n.tabsMerge,
                icon: Icons.tab_outlined,
              ),
            if (controller.tabs.any(
              (tab) => tab != controller.home && tab != group.selected,
            ))
              AppMenuOption(
                value: _TabAction.closeOthers,
                label: l10n.tabsCloseOthers,
                icon: Icons.close,
              ),
          ],
          onSelected: (action) {
            controller.activate(group.selected);
            switch (action) {
              case _TabAction.split:
                controller.split(group.selected);
              case _TabAction.merge:
                controller.mergeAll();
              case _TabAction.closeOthers:
                for (final tab in controller.tabs.toList()) {
                  if (tab != group.selected) controller.close(tab);
                }
            }
          },
        ),
        if (controller.canSplit(group.selected))
          AppIconButton.subtle(
            icon: Icons.vertical_split_outlined,
            tooltip: l10n.tabsSplit,
            onPressed: () => controller.split(group.selected),
          ),
        if (widget.trailing != null && group.id == controller.activeGroup.id)
          widget.trailing!,
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

class _DocumentPane extends StatefulWidget {
  const _DocumentPane({
    required this.visible,
    required this.onActivate,
    required this.child,
  });
  final bool visible;
  final VoidCallback onActivate;
  final Widget child;
  @override
  State<_DocumentPane> createState() => _DocumentPaneState();
}

/// Bounded retention: only on-screen panes keep their heavy body (markdown,
/// code blocks, diffs, images). Hidden panes keep this thin state, their
/// PageStorage bucket and therefore their scroll anchors, while session
/// controllers, drafts and attachments live outside and are never dropped.
class _DocumentPaneState extends State<_DocumentPane>
    with SingleTickerProviderStateMixin {
  final _storage = PageStorageBucket();
  late final _fade = AnimationController(
    vsync: this,
    duration: AppDurations.quick,
    value: 1,
  );
  @override
  void didUpdateWidget(_DocumentPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _fade.value = 1;
      } else {
        _fade.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !widget.visible,
    child: ExcludeFocus(
      excluding: !widget.visible,
      child: TickerMode(
        enabled: widget.visible,
        child: ClipRect(
          child: FadeTransition(
            opacity: _fade,
            child: Listener(
              onPointerDown: (_) => widget.onActivate(),
              child: Focus(
                onFocusChange: (focused) {
                  if (focused) widget.onActivate();
                },
                // The bucket survives body swaps, so a remounted scrollable
                // restores its offset on attach instead of starting at zero.
                child: PageStorage(
                  bucket: _storage,
                  child: widget.visible
                      ? widget.child
                      : const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
