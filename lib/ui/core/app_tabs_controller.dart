import 'package:flutter/foundation.dart';

/// A group owns ordering and selection, never document data or RPC clients.
class AppTabGroup<T extends Object> {
  AppTabGroup._(this.id, T first) : _tabs = [first], _selected = first;
  final int id;
  final List<T> _tabs;
  T _selected;
  List<T> get tabs => List.unmodifiable(_tabs);
  T get selected => _selected;
}

/// UI-only tab/group state. [home] is permanent and stays first in its group.
/// Document identity is supplied by T's equality; opening twice only activates.
class AppTabsController<T extends Object> extends ChangeNotifier {
  AppTabsController({required this.home}) {
    _tabs.add(home);
    _groups.add(AppTabGroup._(0, home));
  }
  final T home;
  final _tabs = <T>[];
  final _groups = <AppTabGroup<T>>[];
  int _nextGroup = 1, _activeGroup = 0;
  List<T> get tabs => List.unmodifiable(_tabs);
  List<AppTabGroup<T>> get groups => List.unmodifiable(_groups);
  AppTabGroup<T> get activeGroup =>
      _groups.firstWhere((g) => g.id == _activeGroup);
  T get selected => activeGroup.selected;

  AppTabGroup<T>? groupOf(T tab) {
    for (final group in _groups) {
      if (group._tabs.contains(tab)) return group;
    }
    return null;
  }

  void open(T tab) {
    if (_tabs.contains(tab)) {
      activate(tab);
      return;
    }
    _tabs.add(tab);
    activeGroup._tabs.add(tab);
    activeGroup._selected = tab;
    notifyListeners();
  }

  void activate(T tab) {
    final group = groupOf(tab);
    if (group == null || (group.id == _activeGroup && group.selected == tab)) {
      return;
    }
    _activeGroup = group.id;
    group._selected = tab;
    notifyListeners();
  }

  void close(T tab) {
    if (tab == home) return;
    final group = groupOf(tab);
    if (group == null) return;
    _removeFromGroup(group, tab);
    _tabs.remove(tab);
    notifyListeners();
  }

  void _removeFromGroup(AppTabGroup<T> group, T tab) {
    final index = group._tabs.indexOf(tab);
    group._tabs.removeAt(index);
    if (group._tabs.isEmpty) {
      final groupIndex = _groups.indexOf(group);
      _groups.remove(group);
      if (_activeGroup == group.id) {
        _activeGroup =
            _groups[(groupIndex - 1).clamp(0, _groups.length - 1)].id;
      }
    } else if (group.selected == tab) {
      group._selected = group._tabs[index.clamp(0, group._tabs.length - 1)];
    }
  }

  /// Index is an insertion boundary in the destination's pre-move order.
  void move(T tab, int groupId, {int? index}) {
    if (tab == home) return;
    final source = groupOf(tab);
    final matches = _groups.where((g) => g.id == groupId);
    if (source == null || matches.isEmpty) return;
    final target = matches.first;
    var insertion = (index ?? target._tabs.length).clamp(
      0,
      target._tabs.length,
    );
    if (identical(source, target)) {
      final old = source._tabs.indexOf(tab);
      if (old < insertion) insertion--;
      source._tabs.remove(tab);
    } else {
      _removeFromGroup(source, tab);
    }
    if (target._tabs.contains(home)) {
      insertion = insertion.clamp(1, target._tabs.length);
    }
    target._tabs.insert(insertion, tab);
    target._selected = tab;
    _activeGroup = target.id;
    notifyListeners();
  }

  bool canSplit(T tab) => tab != home && (groupOf(tab)?.tabs.length ?? 0) > 1;

  /// Move, do not clone: a document and especially the chat editor mount once.
  void split(T tab) {
    if (!canSplit(tab)) return;
    final source = groupOf(tab)!;
    final index = _groups.indexOf(source);
    _removeFromGroup(source, tab);
    final target = AppTabGroup<T>._(_nextGroup++, tab);
    _groups.insert(index + 1, target);
    _activeGroup = target.id;
    notifyListeners();
  }

  void mergeAll() {
    if (_groups.length == 1) return;
    final selectedTab = selected;
    final root = groupOf(home)!;
    for (final group in _groups) {
      if (!identical(group, root)) root._tabs.addAll(group._tabs);
    }
    root._selected = selectedTab;
    _groups.removeWhere((g) => !identical(g, root));
    _activeGroup = root.id;
    notifyListeners();
  }

  void cycle(int delta) {
    final group = activeGroup;
    final index = group._tabs.indexOf(group.selected);
    activate(group._tabs[(index + delta) % group._tabs.length]);
  }

  void reset() {
    final root = groupOf(home)!;
    root._tabs
      ..clear()
      ..add(home);
    root._selected = home;
    _groups
      ..clear()
      ..add(root);
    _tabs
      ..clear()
      ..add(home);
    _activeGroup = root.id;
    notifyListeners();
  }
}
