import 'package:flutter/widgets.dart';

/// Pi RPC 官方 extension_ui 槽位标识
enum ExtensibleSlotId {
  /// 输入框上方插槽 (任务进度、待办卡片等)
  aboveEditor,

  /// 输入框下方插槽 (快捷建议、辅助提示)
  belowEditor,

  /// 底部状态栏动态徽章区 (分支、Token、插件状态)
  statusBar,

  /// 全局阻断交互模态槽 (对接 select, confirm, input, editor 弹窗)
  dialogOverlay,

  /// 全局通知浮层 (对接 notify: info/warning/error)
  notificationToast,

  /// 侧边抽屉扩展槽 (Diff 查看器、文件树、插件面板)
  sidebarPanel,
}

/// 扩展插槽管理器 (单例)
///
/// 遵循 AGENTS.md 规范，统一承接来自 Pi RPC 的 extension_ui_request
/// 并以响应式方式驱动 UI 上的 [SlotContainer] 刷新。
class SlotManager {
  SlotManager();
  static final SlotManager instance = SlotManager();

  static SlotManager of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SlotScope>()?.manager ??
      instance;

  void dispose() {
    for (final notifier in _slotNotifiers.values) {
      notifier.dispose();
    }
  }

  /// UI-only anchor for extension questions, shared by the two composer states.
  final editorAnchor = GlobalKey();

  final Map<ExtensibleSlotId, ValueNotifier<List<Widget>>> _slotNotifiers = {
    for (final id in ExtensibleSlotId.values)
      id: ValueNotifier<List<Widget>>([]),
  };

  /// 获取指定槽位的变更通知器
  ValueNotifier<List<Widget>> notifierFor(ExtensibleSlotId slotId) {
    return _slotNotifiers[slotId]!;
  }

  /// 向指定槽位注册或替换部件
  void setSlotWidgets(ExtensibleSlotId slotId, List<Widget> widgets) {
    _slotNotifiers[slotId]?.value = List.unmodifiable(widgets);
  }

  /// 追加部件到指定槽位
  void addSlotWidget(ExtensibleSlotId slotId, Widget widget) {
    final current = _slotNotifiers[slotId]?.value ?? [];
    _slotNotifiers[slotId]?.value = List.unmodifiable([...current, widget]);
  }

  /// 清空指定槽位
  void clearSlot(ExtensibleSlotId slotId) {
    _slotNotifiers[slotId]?.value = const [];
  }
}

/// Each parallel conversation owns its own editor anchor and extension slots.
class SlotScope extends InheritedWidget {
  const SlotScope({super.key, required this.manager, required super.child});
  final SlotManager manager;
  @override
  bool updateShouldNotify(SlotScope oldWidget) => manager != oldWidget.manager;
}
