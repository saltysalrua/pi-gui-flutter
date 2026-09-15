import 'package:flutter/material.dart';
import '../../core/models/appearance_preferences.dart';
import '../../core/services/window_material_service.dart';
import 'window_material_controller.dart';

/// Owns one native material driver above the Navigator, never a Pi process.
class WindowMaterialHost extends StatefulWidget {
  const WindowMaterialHost({
    super.key,
    required this.enabled,
    required this.dark,
    required this.child,
  });
  final bool enabled, dark;
  final Widget child;
  @override
  State<WindowMaterialHost> createState() => _WindowMaterialHostState();
}

class _WindowMaterialHostState extends State<WindowMaterialHost> {
  late final _controller = WindowMaterialController(WindowMaterialService());
  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(WindowMaterialHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
  }

  void _configure() =>
      _controller.configure(enabled: widget.enabled, dark: widget.dark);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) =>
        WindowMaterialScope(status: _controller.status, child: widget.child),
  );
}

class WindowMaterialScope extends InheritedWidget {
  const WindowMaterialScope({
    super.key,
    required this.status,
    required super.child,
  });
  final WindowMaterialStatus status;
  static WindowMaterialStatus statusOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WindowMaterialScope>()
          ?.status ??
      WindowMaterialStatus.unavailable;

  /// Do not expose a clear window until native blur is confirmed. High contrast
  /// and unsupported runners remain opaque without changing saved preferences.
  static Color tint(
    BuildContext context,
    Color color,
    GlassPreferences glass,
  ) => color.withValues(
    alpha:
        glass.enabled &&
            statusOf(context) == WindowMaterialStatus.active &&
            !MediaQuery.highContrastOf(context)
        ? glass.opacity
        : 1,
  );

  @override
  bool updateShouldNotify(WindowMaterialScope oldWidget) =>
      status != oldWidget.status;
}
