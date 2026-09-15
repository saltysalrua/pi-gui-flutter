import 'package:flutter/foundation.dart';

/// App-lifetime sidebar geometry shared by the home and settings routes.
/// This is transient GUI state, separate from theme persistence and Pi RPC.
class SidebarLayoutController extends ChangeNotifier {
  static final instance = SidebarLayoutController();

  static const defaultWidth = 260.0;
  static const minWidth = 180.0;
  static const maxWidth = 480.0;

  double _preferredWidth = defaultWidth;

  double _maximumFor(double viewportWidth) =>
      (viewportWidth * 0.5).clamp(minWidth, maxWidth);

  /// Shrinking the window only constrains the rendered width, not the preference.
  double widthFor(double viewportWidth) =>
      _preferredWidth.clamp(minWidth, _maximumFor(viewportWidth));

  void resizeBy(double delta, {required double viewportWidth}) {
    // Start at the visible edge so a clamped sidebar responds on the first drag.
    _setWidth(
      (widthFor(viewportWidth) + delta).clamp(
        minWidth,
        _maximumFor(viewportWidth),
      ),
    );
  }

  void reset() => _setWidth(defaultWidth);

  void _setWidth(double width) {
    if (width == _preferredWidth) return;
    _preferredWidth = width;
    notifyListeners();
  }
}
