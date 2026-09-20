import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_history_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

/// Per-session history browser and mutation state. Never trims the chat locally.
class HistoryController extends ChangeNotifier {
  HistoryController(
    this.api, {
    required Stream<PiRpcEvent> events,
    required this.canMutate,
    required this.onLock,
    required this.onCommitted,
  }) {
    _events = events.listen(_event);
  }
  final PiHistoryGateway api;
  final bool Function() canMutate;
  final void Function(bool) onLock;
  final Future<void> Function(
    PiHistoryResult,
    PiHistoryAction,
    PiHistorySnapshot,
  )
  onCommitted;
  late final StreamSubscription<PiRpcEvent> _events;
  PiHistorySnapshot? snapshot;
  Map<String, dynamic>? preview;
  String? selectedId, failure;
  String query = '';
  PiHistoryFilter filter = PiHistoryFilter.standard;
  final folded = <String>{};
  bool loading = false, previewLoading = false, busy = false, uncertain = false;
  bool _disposed = false, isOpen = false;
  int _load = 0, _selection = 0;
  (PiHistoryAction, PiHistorySnapshot)? _pending;
  bool _labelPending = false;
  PiHistoryEntry? get selected => snapshot?.entries[selectedId];
  List<PiHistoryRow> get rows => snapshot?.rows(filter, query, folded) ?? [];
  bool get canAct => !busy && !loading && snapshot != null && canMutate();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void availabilityChanged() {
    if (isOpen) _notify();
  }

  void _busy(bool value) {
    busy = value;
    onLock(value);
    _notify();
  }

  Future<void> open({PiChatMessage? message}) async {
    isOpen = true;
    await refresh();
    if (_disposed || !isOpen || snapshot == null) return;
    if (message != null) {
      // A shortcut only selects a preview; never derives a mutation ID from an
      // index/timestamp. Ambiguous matches require explicit selection in the tree.
      final candidates = snapshot!.entries.values
          .where(
            (e) =>
                snapshot!.activePath.contains(e.id) &&
                e.role == message.role &&
                e.messageTimestamp == message.timestamp &&
                e.text == message.text,
          )
          .toList();
      if (candidates.length == 1) {
        filter = PiHistoryFilter.all;
        folded.clear();
        await select(candidates.single.id);
      } else {
        selectedId = null;
        preview = null;
        _notify();
      }
    }
  }

  void close() {
    isOpen = false;
    _load++;
    _selection++;
    snapshot = null;
    preview = null;
    selectedId = null;
    loading = false;
    previewLoading = false;
    folded.clear();
    query = '';
  }

  Future<void> refresh() async {
    if (busy || _disposed) return;
    final version = ++_load;
    loading = true;
    failure = null;
    _notify();
    try {
      final next = await api.load();
      if (_disposed || version != _load) return;
      snapshot = next;
      folded.removeWhere((id) => !next.entries.containsKey(id));
      final id = next.entries.containsKey(selectedId)
          ? selectedId
          : next.leafId;
      if (id != null) await select(id);
    } catch (e) {
      if (!_disposed && version == _load) failure = _code(e);
    } finally {
      if (!_disposed && version == _load) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> select(String id) async {
    final source = snapshot;
    if (source == null || busy) return;
    final version = ++_selection;
    selectedId = id;
    preview = null;
    previewLoading = true;
    failure = null;
    _notify();
    try {
      final value = await api.entry(source, id);
      if (!_disposed && version == _selection && identical(source, snapshot)) {
        preview = value;
      }
    } catch (e) {
      if (!_disposed && version == _selection) failure = _code(e);
    } finally {
      if (!_disposed && version == _selection) {
        previewLoading = false;
        _notify();
      }
    }
  }

  void search(String value) {
    query = value;
    _notify();
  }

  void setFilter(PiHistoryFilter value) {
    filter = value;
    _notify();
  }

  void toggle(String id) {
    if (!folded.remove(id)) folded.add(id);
    _notify();
  }

  void expandAll() {
    folded.clear();
    _notify();
  }

  void revealCurrent() {
    folded.clear();
    query = '';
    filter = PiHistoryFilter.all;
    final id = snapshot?.leafId;
    if (id != null) unawaited(select(id));
    _notify();
  }

  Future<bool> act(
    PiHistoryAction action, {
    bool summarize = false,
    String? instructions,
    bool replaceInstructions = false,
  }) async {
    if (!canAct || action != PiHistoryAction.clone && selected == null) {
      return false;
    }
    final source = snapshot!;
    if (action == PiHistoryAction.fork && !selected!.isUser) {
      return false;
    }
    _pending = (action, source);
    failure = null;
    _busy(true);
    try {
      final result = await api.act(
        source,
        action,
        entryId: selectedId,
        summarize: summarize,
        instructions: instructions,
        replaceInstructions: replaceInstructions,
      );
      return await _complete(result);
    } catch (e) {
      if (_disposed) return false;
      uncertain = e is PiRpcException && e.outcomeUnknown;
      failure = uncertain ? 'HISTORY_UNCERTAIN' : _code(e);
      if (!uncertain) {
        _pending = null;
        _busy(false);
      }
      _notify();
      return false;
    }
  }

  Future<bool> _complete(PiHistoryResult result) async {
    if (_disposed || _pending == null) return false;
    final (action, source) = _pending!;
    _pending = null;
    uncertain = false;
    try {
      if (result.cancelled) {
        failure = 'HISTORY_CANCELLED';
        return false;
      }
      // The owner unlocks the chat just before authoritative hydration.
      await onCommitted(result, action, source);
      failure = null;
      return true;
    } catch (_) {
      failure = 'HISTORY_REFRESH_FAILED';
      return false;
    } finally {
      if (!_disposed) {
        _busy(false);
        final notice = failure;
        if (isOpen) await refresh();
        if (!_disposed && notice != null) {
          failure = notice;
          _notify();
        }
      }
    }
  }

  Future<void> setLabel(String value) async {
    if (!canAct || selectedId == null) return;
    _labelPending = true;
    failure = null;
    _busy(true);
    try {
      await api.label(snapshot!, selectedId!, value);
      _labelPending = false;
      _busy(false);
      await refresh();
    } catch (e) {
      if (_disposed) return;
      uncertain = e is PiRpcException && e.outcomeUnknown;
      failure = uncertain ? 'HISTORY_UNCERTAIN' : _code(e);
      if (!uncertain) {
        _labelPending = false;
        _busy(false);
      }
      _notify();
    }
  }

  void _event(PiRpcEvent event) {
    if (_disposed) return;
    if (event is PiChatEvent &&
        event.type == 'agent_settled' &&
        isOpen &&
        !busy) {
      unawaited(refresh());
    }
    if (event is PiRpcDisconnected && busy) {
      _pending = null;
      _labelPending = false;
      uncertain = false;
      failure = 'HISTORY_DISCONNECTED';
      _busy(false);
    }
    if (event is! PiAgentEvent ||
        event.type != 'gui_history_settled' ||
        !uncertain) {
      return;
    }
    if (event.payload['success'] != true) {
      _pending = null;
      _labelPending = false;
      uncertain = false;
      failure = 'HISTORY_FAILED';
      _busy(false);
      return;
    }
    if (_labelPending) {
      _labelPending = false;
      uncertain = false;
      _busy(false);
      if (isOpen) unawaited(refresh());
    } else {
      try {
        unawaited(_complete(PiHistoryResult.fromJson(event.payload['data'])));
      } catch (_) {
        failure = 'HISTORY_UNCERTAIN';
        _notify();
      }
    }
  }

  static String _code(Object error) =>
      error is PiRpcException ? error.message : 'HISTORY_FAILED';
  @override
  void dispose() {
    _disposed = true;
    _load++;
    _selection++;
    unawaited(_events.cancel());
    super.dispose();
  }
}
