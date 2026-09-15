import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';
import 'app_dialog.dart';
import 'app_icon_button.dart';

Future<void> showAppImageLightbox(
  BuildContext context,
  Uint8List bytes, {
  String? label,
}) => showAppDialog<void>(
  context,
  (_) => AppImageLightbox(bytes: bytes, label: label),
  barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.92),
);

/// App-window lightbox: one matrix writer, centre-anchored wheel zoom, free pan.
/// Inspired by Novelai-harness ImageLightboxDialog, with shared motion/theme tokens.
class AppImageLightbox extends StatefulWidget {
  const AppImageLightbox({super.key, required this.bytes, this.label});
  final Uint8List bytes;
  final String? label;
  @override
  State<AppImageLightbox> createState() => _AppImageLightboxState();
}

class _AppImageLightboxState extends State<AppImageLightbox>
    with SingleTickerProviderStateMixin {
  static const _minScale = 0.2, _maxScale = 10.0;
  final _transform = TransformationController();
  final _pictureKey = GlobalKey();
  late final AnimationController _zoom;
  Matrix4Tween? _tween;
  double? _wheelTarget;
  double _wheelDirection = 0, _lastScale = 1;
  int _pointers = 0;
  Offset _lastFocal = Offset.zero;
  Size? _viewport;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(vsync: this, duration: AppDurations.quick)
      ..addListener(() {
        if (_tween case final tween?) {
          _transform.value = tween.transform(
            AppCurves.smoothOut.transform(_zoom.value),
          );
        }
      });
  }

  // Z stays 1: getMaxScaleOnAxis would incorrectly report 1 below 100% zoom.
  double get _scale => _transform.value.entry(0, 0);

  Matrix4 _around(double target, Offset anchor, {Offset? destination}) {
    final scene = _transform.toScene(anchor);
    final to = destination ?? anchor;
    final scale = target.clamp(_minScale, _maxScale);
    return Matrix4.diagonal3Values(
      scale,
      scale,
      1,
    )..setTranslationRaw(to.dx - scene.dx * scale, to.dy - scene.dy * scale, 0);
  }

  void _animate(Matrix4 target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _stop();
      _transform.value = target;
      return;
    }
    _tween = Matrix4Tween(begin: _transform.value.clone(), end: target);
    _zoom.forward(from: 0);
  }

  void _stop() {
    _zoom.stop();
    _tween = null;
    _wheelTarget = null;
    _wheelDirection = 0;
  }

  void _signal(PointerSignalEvent event, Size size) {
    if (event is PointerScrollEvent) {
      final dy = event.scrollDelta.dy;
      if (!dy.isFinite || dy == 0) return;
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        final base = _zoom.isAnimating && _wheelDirection == dy.sign
            ? _wheelTarget ?? _scale
            : _scale;
        final target = (base * math.exp(-dy / 300).clamp(0.5, 2.0)).clamp(
          _minScale,
          _maxScale,
        );
        _wheelTarget = target;
        _wheelDirection = dy.sign;
        _animate(_around(target, size.center(Offset.zero)));
      });
    } else if (event is PointerScaleEvent &&
        event.scale.isFinite &&
        event.scale > 0) {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        _stop();
        _transform.value = _around(_scale * event.scale, event.localPosition);
      });
    }
  }

  void _doubleTap(Size size) {
    _stop();
    _animate(
      (_scale - 1).abs() > 0.01
          ? Matrix4.identity()
          : _around(2, size.center(Offset.zero)),
    );
  }

  void _tap(TapUpDetails details) {
    final box = _pictureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null &&
        !(Offset.zero & box.size).contains(
          box.globalToLocal(details.globalPosition),
        )) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (_viewport != null && _viewport != size) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _stop();
              _transform.value = Matrix4.identity();
            });
          }
          _viewport = size;
          return Stack(
            fit: StackFit.expand,
            children: [
              Listener(
                onPointerDown: (_) => _stop(),
                onPointerPanZoomStart: (_) => _stop(),
                onPointerSignal: (event) => _signal(event, size),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _tap,
                  onDoubleTap: () => _doubleTap(size),
                  onScaleStart: (details) {
                    _stop();
                    _lastFocal = details.localFocalPoint;
                    _lastScale = 1;
                    _pointers = details.pointerCount;
                  },
                  onScaleUpdate: (details) {
                    if (!details.scale.isFinite || details.scale <= 0) return;
                    _stop();
                    if (_pointers == details.pointerCount) {
                      _transform.value = _around(
                        _scale * details.scale / _lastScale,
                        _lastFocal,
                        destination: details.localFocalPoint,
                      );
                    }
                    _lastFocal = details.localFocalPoint;
                    _lastScale = details.scale;
                    _pointers = details.pointerCount;
                  },
                  child: Semantics(
                    label: context.l10n.chatLightboxHint,
                    child: ClipRect(
                      child: ValueListenableBuilder<Matrix4>(
                        valueListenable: _transform,
                        builder: (_, matrix, child) =>
                            Transform(transform: matrix, child: child),
                        child: RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Center(
                              child: Image(
                                key: _pictureKey,
                                image: ResizeImage(
                                  MemoryImage(widget.bytes),
                                  width: 4096,
                                  allowUpscaling: false,
                                ),
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                                semanticLabel:
                                    widget.label ?? context.l10n.chatImage,
                                errorBuilder: (context, _, _) => Text(
                                  context.l10n.chatImageUnavailable,
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    color: context.colors.lightboxForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: AppIconButton(
                  icon: Icons.close_rounded,
                  tooltip: context.l10n.chatLightboxClose,
                  size: 42,
                  iconSize: 26,
                  isCircular: true,
                  color: context.colors.lightboxForeground,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  @override
  void dispose() {
    _zoom.dispose();
    _transform.dispose();
    super.dispose();
  }
}
