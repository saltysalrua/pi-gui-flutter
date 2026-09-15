import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面窗口控制状态基类
///
/// 提供窗口最小化、最大化/还原、关闭以及拖拽移动区域。
abstract class WindowControlsState<T extends StatefulWidget> extends State<T>
    with WindowListener {
  bool _windowIsMaximized = false;

  /// 当前窗口是否已最大化
  bool get windowIsMaximized => _windowIsMaximized;

  /// 是否为桌面环境
  bool get isDesktopWindow =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    if (isDesktopWindow) {
      windowManager.addListener(this);
      _syncWindowMaximized();
    }
  }

  @override
  void dispose() {
    if (isDesktopWindow) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _syncWindowMaximized() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted) setState(() => _windowIsMaximized = maximized);
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _windowIsMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _windowIsMaximized = false);
  }

  /// 最小化窗口
  Future<void> minimizeWindow() async {
    if (!isDesktopWindow) return;
    try {
      await windowManager.minimize();
    } catch (_) {}
  }

  /// 最大化 / 还原
  Future<void> toggleMaximizeWindow() async {
    if (!isDesktopWindow) return;
    try {
      final maximized = await windowManager.isMaximized();
      if (maximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  /// 关闭应用窗口
  Future<void> closeAppWindow() async {
    if (!isDesktopWindow) return;
    try {
      await windowManager.close();
    } catch (_) {}
  }

  /// 窗口拖拽区域（双击最大化/还原）
  Widget buildWindowDragArea({required Widget child}) {
    if (!isDesktopWindow) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: toggleMaximizeWindow,
      child: DragToMoveArea(child: child),
    );
  }
}
