import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

/// One mounted editor moves from the empty-state center to the conversation footer.
/// Measuring it in the same layout pass keeps the timeline clear of multiline input.
class AppComposerLayout extends StatelessWidget {
  const AppComposerLayout({
    super.key,
    required this.started,
    required this.content,
    required this.editor,
    this.emptyMaxWidth = 760,
    this.activeMaxWidth = 868,
  });
  final bool started;
  final Widget content, editor;
  final double emptyMaxWidth, activeMaxWidth;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: started ? 1 : 0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDurations.fast,
    curve: AppCurves.smoothOut,
    builder: (context, progress, _) => CustomMultiChildLayout(
      delegate: _ComposerLayoutDelegate(
        progress,
        emptyMaxWidth,
        activeMaxWidth,
      ),
      children: [
        LayoutId(
          id: _Part.content,
          child: IgnorePointer(
            ignoring: !started,
            child: ExcludeFocus(
              excluding: !started,
              child: Opacity(opacity: progress, child: content),
            ),
          ),
        ),
        LayoutId(
          id: _Part.editor,
          child: SingleChildScrollView(primary: false, child: editor),
        ),
      ],
    ),
  );
}

enum _Part { content, editor }

class _ComposerLayoutDelegate extends MultiChildLayoutDelegate {
  _ComposerLayoutDelegate(
    this.progress,
    this.emptyMaxWidth,
    this.activeMaxWidth,
  );
  final double progress, emptyMaxWidth, activeMaxWidth;
  @override
  void performLayout(Size size) {
    final width = lerpDouble(
      emptyMaxWidth,
      activeMaxWidth,
      progress,
    )!.clamp(0.0, size.width);
    final editor = layoutChild(
      _Part.editor,
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: size.height),
    );
    final remaining = (size.height - editor.height).clamp(0.0, size.height);
    layoutChild(
      _Part.content,
      BoxConstraints.tight(Size(size.width, remaining)),
    );
    positionChild(_Part.content, Offset.zero);
    positionChild(
      _Part.editor,
      Offset(
        (size.width - width) / 2,
        lerpDouble(remaining / 2, remaining, progress)!,
      ),
    );
  }

  @override
  bool shouldRelayout(_ComposerLayoutDelegate oldDelegate) =>
      progress != oldDelegate.progress ||
      emptyMaxWidth != oldDelegate.emptyMaxWidth ||
      activeMaxWidth != oldDelegate.activeMaxWidth;
}
