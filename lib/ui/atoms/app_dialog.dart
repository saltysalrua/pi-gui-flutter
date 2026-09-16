import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderOffstage;
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';

import 'app_card.dart';
import '../core/theme/theme_context_extensions.dart';

/// Shared modal route: bounded scrolling, focus trap, Escape and motion tokens.
Future<T?> showAppDialog<T>(
  BuildContext context,
  WidgetBuilder builder, {
  Color? barrierColor,
  bool anchored = false,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push<T>(
    _AppDialogRoute<T>(
      builder: builder,
      barrierLabel: context.l10n.close,
      barrierColor:
          barrierColor ??
          Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
      reduced: reduced,
      anchored: anchored,
    ),
  );
}

class _AppDialogRoute<T> extends RawDialogRoute<T> {
  _AppDialogRoute({
    required WidgetBuilder builder,
    required String barrierLabel,
    required Color barrierColor,
    required this.reduced,
    required bool anchored,
  }) : super(
         barrierLabel: barrierLabel,
         barrierColor: barrierColor,
         transitionDuration: reduced ? Duration.zero : AppDurations.fast,
         pageBuilder: (context, _, _) => SafeArea(child: builder(context)),
         // Anchored cards scale locally; existing centred routes and the
         // image lightbox retain their original transition.
         transitionBuilder: (context, animation, _, child) => FadeTransition(
           opacity: animation,
           child: anchored
               ? child
               : ScaleTransition(
                   scale: Tween(begin: AppMotionScales.modal, end: 1.0).animate(
                     CurvedAnimation(
                       parent: animation,
                       curve: AppCurves.smoothOut,
                     ),
                   ),
                   child: child,
                 ),
         ),
       );
  final bool reduced;
  @override
  Duration get reverseTransitionDuration =>
      reduced ? Duration.zero : AppDurations.quick;
}

enum AppDialogPlacement { center, beside, above }

class AppDialog extends StatefulWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.maxWidth = 520,
    this.maxHeight = 680,
    this.anchorKey,
    this.placement = AppDialogPlacement.center,
    this.fallbackAlignment = Alignment.center,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth, maxHeight;
  final GlobalKey? anchorKey;
  final AppDialogPlacement placement;
  final Alignment fallbackAlignment;

  @override
  State<AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<AppDialog> {
  Rect? _lastAnchor;
  bool _anchorCheckScheduled = false;

  @override
  void didUpdateWidget(AppDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorKey != widget.anchorKey) {
      _lastAnchor = null;
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: MediaQuery.viewInsetsOf(context),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Resolve both boxes in the same coordinate system during layout. This
        // follows resizing / AppScale without caching an obsolete screen rect.
        final host = context.findRenderObject() as RenderBox;
        Rect? readAnchor() {
          final anchor = widget.anchorKey?.currentContext?.findRenderObject();
          for (RenderObject? node = anchor; node != null; node = node.parent) {
            if (node is RenderOffstage && node.offstage) return null;
          }
          if (anchor is! RenderBox || !anchor.attached || !anchor.hasSize) {
            return _lastAnchor;
          }
          return Rect.fromPoints(
            host.globalToLocal(anchor.localToGlobal(Offset.zero)),
            host.globalToLocal(
              anchor.localToGlobal(anchor.size.bottomRight(Offset.zero)),
            ),
          );
        }

        _lastAnchor = readAnchor();
        if (widget.anchorKey != null && !_anchorCheckScheduled) {
          // A sibling anchor can be laid out AFTER the overlay (also on resize).
          // Recheck after the frame, rebuilding only if its geometry changed.
          _anchorCheckScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _anchorCheckScheduled = false;
            if (!mounted || !host.attached) return;
            final next = readAnchor();
            if (next != _lastAnchor) setState(() => _lastAnchor = next);
          });
        }
        return CustomSingleChildLayout(
          delegate: _DialogLayout(
            anchor: _lastAnchor,
            placement: widget.placement,
            fallbackAlignment: widget.fallbackAlignment,
            maxWidth: widget.maxWidth,
            maxHeight: widget.maxHeight,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: widget.placement == AppDialogPlacement.center
                  ? 1.0
                  : AppMotionScales.dropdown,
              end: 1.0,
            ),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppDurations.fast,
            curve: AppCurves.smoothOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              alignment: switch (widget.placement) {
                AppDialogPlacement.beside => Alignment.topLeft,
                AppDialogPlacement.above => Alignment.bottomRight,
                AppDialogPlacement.center => Alignment.center,
              },
              child: child,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: AppCard(
                backgroundColor: context.colors.elevatedBackground,
                shadows: AppShadows.elevated(
                  Theme.of(context).shadowColor,
                  brightness: Theme.of(context).brightness,
                ),
                child: FocusTraversalGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                widget.title,
                                style: context.textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              widget.child,
                            ],
                          ),
                        ),
                      ),
                      if (widget.actions.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: widget.actions,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _DialogLayout extends SingleChildLayoutDelegate {
  _DialogLayout({
    required this.anchor,
    required this.placement,
    required this.fallbackAlignment,
    required this.maxWidth,
    required this.maxHeight,
  });
  final Rect? anchor;
  final AppDialogPlacement placement;
  final Alignment fallbackAlignment;
  final double maxWidth, maxHeight;
  static const _margin = AppSpacing.lg;
  static const _gap = AppSpacing.sm;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(
      maxWidth,
      math.max(0.0, constraints.maxWidth - 2 * _margin),
    );
    var height = math.min(
      maxHeight,
      math.max(0.0, constraints.maxHeight - 2 * _margin),
    );
    if (anchor case final source? when placement != AppDialogPlacement.center) {
      final fitsBeside =
          placement == AppDialogPlacement.beside &&
          (source.right + _gap + width <= constraints.maxWidth - _margin ||
              source.left - _gap - width >= _margin);
      if (!fitsBeside) {
        final room = math.max(
          source.top - _gap - _margin,
          constraints.maxHeight - source.bottom - _gap - _margin,
        );
        // Scroll in the free area instead of covering the source. In an
        // extremely short viewport, edge clamping keeps the actions usable.
        if (room >= 160) height = math.min(height, room);
      }
    }
    return BoxConstraints(maxWidth: width, maxHeight: height);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxX = math.max(_margin, size.width - childSize.width - _margin);
    final maxY = math.max(_margin, size.height - childSize.height - _margin);
    var position = fallbackAlignment.alongOffset(
      Offset(size.width - childSize.width, size.height - childSize.height),
    );
    if (anchor case final source? when placement != AppDialogPlacement.center) {
      if (placement == AppDialogPlacement.beside &&
          source.right + _gap <= maxX) {
        position = Offset(source.right + _gap, source.top);
      } else if (placement == AppDialogPlacement.beside &&
          source.left - _gap - childSize.width >= _margin) {
        position = Offset(source.left - _gap - childSize.width, source.top);
      } else {
        final above = source.top - _gap - childSize.height;
        final below = source.bottom + _gap;
        final preferAbove = placement == AppDialogPlacement.above;
        final y = preferAbove
            ? (above >= _margin || below > maxY ? above : below)
            : (below <= maxY || above < _margin ? below : above);
        position = Offset(
          preferAbove ? source.right - childSize.width : source.left,
          y,
        );
      }
    }
    return Offset(
      position.dx.clamp(_margin, maxX),
      position.dy.clamp(_margin, maxY),
    );
  }

  @override
  bool shouldRelayout(_DialogLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      placement != oldDelegate.placement ||
      fallbackAlignment != oldDelegate.fallbackAlignment ||
      maxWidth != oldDelegate.maxWidth ||
      maxHeight != oldDelegate.maxHeight;
}
