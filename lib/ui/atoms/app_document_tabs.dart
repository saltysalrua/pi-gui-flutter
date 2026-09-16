import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';
import 'app_icon_button.dart';

class AppDocumentTab<T extends Object> {
  const AppDocumentTab({
    required this.id,
    required this.label,
    required this.icon,
    this.tooltip,
    this.closable = true,
    this.busy = false,
  });
  final T id;
  final String label;
  final String? tooltip;
  final IconData icon;
  final bool closable, busy;
}

class AppTabDrag<T extends Object> {
  const AppTabDrag(this.scope, this.tab);
  final Object scope;
  final T tab;
}

/// Scrollable desktop tabs. A scope prevents drops between unrelated hosts.
class AppDocumentTabs<T extends Object> extends StatefulWidget {
  const AppDocumentTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.dragScope,
    required this.onSelected,
    required this.onClose,
    required this.onDrop,
    this.enabled = true,
  });
  final List<AppDocumentTab<T>> tabs;
  final T selected;
  final Object dragScope;
  final ValueChanged<T> onSelected, onClose;
  final void Function(T tab, int index) onDrop;
  final bool enabled;

  static double heightOf(BuildContext context) {
    final style = context.textTheme.labelMedium!;
    return math.max(
      36,
      MediaQuery.textScalerOf(context).scale(style.fontSize!) *
              (style.height ?? 1.4) +
          AppSpacing.lg,
    );
  }

  @override
  State<AppDocumentTabs<T>> createState() => _AppDocumentTabsState<T>();
}

class _AppDocumentTabsState<T extends Object>
    extends State<AppDocumentTabs<T>> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'Document tabs');
  final _keys = <T, GlobalKey>{};
  int? _insertion;
  double? _viewportWidth;

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(covariant AppDocumentTabs<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _keys.removeWhere((id, _) => !widget.tabs.any((tab) => tab.id == id));
    if (oldWidget.selected != widget.selected ||
        oldWidget.tabs.length != widget.tabs.length ||
        oldWidget.tabs.indexWhere((tab) => tab.id == widget.selected) !=
            widget.tabs.indexWhere((tab) => tab.id == widget.selected)) {
      _reveal();
    }
  }

  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !_scroll.hasClients) return;
    final render = _keys[widget.selected]?.currentContext?.findRenderObject();
    if (render == null || !render.attached) return;
    _scroll.position.ensureVisible(
      render,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDurations.fast,
      curve: AppCurves.smoothOut,
      alignment: 0,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  });

  void _step(int delta) {
    if (!widget.enabled || widget.tabs.isEmpty) return;
    final index = widget.tabs.indexWhere((tab) => tab.id == widget.selected);
    widget.onSelected(widget.tabs[(index + delta) % widget.tabs.length].id);
  }

  void _wheel(PointerSignalEvent signal) {
    if (signal is! PointerScrollEvent ||
        !_scroll.hasClients ||
        _scroll.position.maxScrollExtent == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(signal, (_) {
      final delta = signal.scrollDelta.dx == 0
          ? signal.scrollDelta.dy
          : signal.scrollDelta.dx;
      _scroll.jumpTo(
        (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (_viewportWidth != constraints.maxWidth) {
        _viewportWidth = constraints.maxWidth;
        _reveal();
      }
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
        },
        child: Focus(
          focusNode: _focus,
          child: Listener(
            onPointerSignal: _wheel,
            child: DragTarget<AppTabDrag<T>>(
              onWillAcceptWithDetails: (details) =>
                  widget.enabled &&
                  identical(details.data.scope, widget.dragScope),
              onAcceptWithDetails: (details) =>
                  widget.onDrop(details.data.tab, widget.tabs.length),
              builder: (context, candidates, _) => AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppDurations.quick,
                color: candidates.isEmpty
                    ? Colors.transparent
                    : context.colors.primaryTint,
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        _target(context, widget.tabs[i], i),
                      const SizedBox(width: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _target(BuildContext context, AppDocumentTab<T> tab, int index) =>
      DragTarget<AppTabDrag<T>>(
        onWillAcceptWithDetails: (details) =>
            widget.enabled && identical(details.data.scope, widget.dragScope),
        onMove: (details) {
          final box =
              _keys[tab.id]?.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          final after =
              box.globalToLocal(details.offset).dx >= box.size.width / 2;
          final insertion = index + (after ? 1 : 0);
          if (_insertion != insertion) setState(() => _insertion = insertion);
        },
        onLeave: (_) => setState(() => _insertion = null),
        onAcceptWithDetails: (details) {
          widget.onDrop(details.data.tab, _insertion ?? index);
          setState(() => _insertion = null);
        },
        builder: (context, candidates, _) => Stack(
          children: [
            SizedBox(
              key: _keys.putIfAbsent(tab.id, GlobalKey.new),
              width: tab.closable ? 174 : 110,
              height: AppDocumentTabs.heightOf(context),
              child: tab.closable && widget.enabled
                  ? Draggable<AppTabDrag<T>>(
                      data: AppTabDrag(widget.dragScope, tab.id),
                      // Keep target offsets at the pointer, not at the dragged
                      // header's origin, so before/after insertion is accurate.
                      dragAnchorStrategy: pointerDragAnchorStrategy,
                      maxSimultaneousDrags: 1,
                      feedback: Material(
                        color: context.colors.elevatedBackground,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        elevation: 4,
                        child: SizedBox(
                          width: 174,
                          height: AppDocumentTabs.heightOf(context),
                          child: _tab(context, tab, feedback: true),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _tab(context, tab),
                      ),
                      child: _tab(context, tab),
                    )
                  : _tab(context, tab),
            ),
            if (candidates.isNotEmpty)
              Positioned(
                top: AppSpacing.xs,
                bottom: AppSpacing.xs,
                left: _insertion == index + 1 ? null : 0,
                right: _insertion == index + 1 ? 0 : null,
                width: AppSpacing.xxs,
                child: ColoredBox(color: context.colors.primary),
              ),
          ],
        ),
      );

  Widget _tab(
    BuildContext context,
    AppDocumentTab<T> tab, {
    bool feedback = false,
  }) {
    final selected = tab.id == widget.selected;
    final colors = context.colors;
    final foreground = widget.enabled
        ? (selected ? colors.textPrimary : colors.textSecondary)
        : colors.textMuted;
    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: tab.tooltip ?? tab.label,
        child: Listener(
          onPointerDown: (event) {
            if (widget.enabled &&
                !feedback &&
                tab.closable &&
                event.buttons == kMiddleMouseButton) {
              widget.onClose(tab.id);
            }
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: !widget.enabled || feedback
                  ? null
                  : () {
                      _focus.requestFocus();
                      widget.onSelected(tab.id);
                    },
              hoverColor: colors.hoverBackground,
              focusColor: colors.primaryTint,
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppDurations.quick,
                decoration: BoxDecoration(
                  color: selected ? colors.hoverBackground : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      width: AppSpacing.xxs,
                      color: selected ? colors.primary : Colors.transparent,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    if (tab.busy)
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    else
                      Icon(tab.icon, size: 15, color: foreground),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                    if (tab.closable) ...[
                      const SizedBox(width: AppSpacing.xs),
                      AppIconButton.subtle(
                        icon: Icons.close,
                        size: 24,
                        tooltip: context.l10n.tabsClose,
                        onPressed: !widget.enabled || feedback
                            ? null
                            : () => widget.onClose(tab.id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
