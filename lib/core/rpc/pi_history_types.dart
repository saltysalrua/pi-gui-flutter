import 'pi_chat_types.dart';
import 'pi_rpc_client.dart';
import 'pi_rpc_types.dart';

enum PiHistoryFilter { standard, noTools, userOnly, labeledOnly, all }

enum PiHistoryAction { navigate, fork, clone }

/// Display projection only. Pi remains the sole owner of context reconstruction.
class PiHistoryEntry {
  PiHistoryEntry.fromJson(Object? value) {
    final json = rpcObject(value);
    id = json['id'] as String;
    parentId = json['parentId'] as String?;
    type = json['type'] as String;
    timestamp = json['timestamp'] as String? ?? '';
    final message = json['message'] is Map ? rpcObject(json['message']) : json;
    role = message['role'] as String? ?? '';
    messageTimestamp = (message['timestamp'] is num)
        ? (message['timestamp'] as num).toInt()
        : null;
    final content = piContent(message['content']);
    text = content
        .where((b) => b.kind == PiContentKind.text)
        .map((b) => b.text)
        .join('\n\n');
    toolOnly =
        role == 'assistant' &&
        text.isEmpty &&
        (message['stopReason'] == null ||
            message['stopReason'] == 'stop' ||
            message['stopReason'] == 'toolUse');
    imageCount = content.where((b) => b.kind == PiContentKind.image).length;
    if (text.isEmpty) {
      text =
          (json['summary'] ??
                  message['command'] ??
                  message['toolName'] ??
                  json['modelId'] ??
                  json['thinkingLevel'] ??
                  json['name'] ??
                  json['customType'] ??
                  '')
              .toString();
    }
    if (text.isEmpty) {
      text = content
          .where((b) => b.kind == PiContentKind.toolCall)
          .map((b) => b.name)
          .join(', ');
    }
  }
  late final String id, type, role, timestamp;
  late final String? parentId;
  late final int? messageTimestamp;
  late final int imageCount;
  late final bool toolOnly;
  late String text;
  String? label, labelTimestamp;
  bool get isUser => type == 'message' && role == 'user';
  bool get restoresDraft => isUser || type == 'custom_message';
  late final String preview =
      (text.length > 500 ? text.substring(0, 500) : text)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  bool visible(PiHistoryFilter filter, String? leafId) {
    // Match Pi's five filter modes, including its always-hidden usage entries.
    if (type == 'usage' || toolOnly && id != leafId) return false;
    final settings = const {
      'label',
      'custom',
      'model_change',
      'thinking_level_change',
      'session_info',
    }.contains(type);
    return switch (filter) {
      PiHistoryFilter.standard => !settings,
      PiHistoryFilter.noTools => !settings && role != 'toolResult',
      PiHistoryFilter.userOnly => isUser,
      PiHistoryFilter.labeledOnly => label != null,
      PiHistoryFilter.all => true,
    };
  }
}

class PiHistoryRow {
  const PiHistoryRow(this.entry, this.depth, this.hasChildren);
  final PiHistoryEntry entry;
  final int depth;
  final bool hasChildren;
}

class PiHistorySnapshot {
  PiHistorySnapshot({
    required this.sessionId,
    required this.sessionFile,
    required Object? data,
  }) {
    final json = rpcObject(data);
    leafId = json['leafId'] as String?;
    final raw = json['entries'] as List;
    entries = {
      for (final value in raw)
        (value as Map)['id'] as String: PiHistoryEntry.fromJson(value),
    };
    if (entries.length != raw.length) {
      throw const FormatException('Duplicate history IDs');
    }
    for (final value in raw) {
      final entry = rpcObject(value);
      if (entry['type'] == 'label') {
        final target = entries[entry['targetId']];
        if (target != null) {
          target.label = entry['label'] as String?;
          target.labelTimestamp = entry['timestamp'] as String?;
        }
      }
    }
    var cursor = leafId;
    while (cursor != null && activePath.add(cursor)) {
      cursor = entries[cursor]?.parentId;
    }
  }
  final String sessionId;
  final String? sessionFile;
  late final String? leafId;
  late final Map<String, PiHistoryEntry> entries;
  final activePath = <String>{};
  Map<String, Object?> get identity => {
    'sessionId': sessionId,
    'leafId': leafId,
  };

  /// Iterative, branch-only indentation: long linear sessions never build a
  /// deeply nested Widget tree. Missing parents and malformed cycles stay bounded.
  List<PiHistoryRow> rows(
    PiHistoryFilter filter,
    String query,
    Set<String> folded,
  ) {
    final children = <String?, List<PiHistoryEntry>>{};
    for (final entry in entries.values) {
      final parent =
          entries.containsKey(entry.parentId) && entry.parentId != entry.id
          ? entry.parentId
          : null;
      children.putIfAbsent(parent, () => []).add(entry);
    }
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((v) => v.isNotEmpty)
        .toList();
    final visible = <String, PiHistoryEntry>{};
    final visibleChildren = <String?, List<String>>{};
    final visited = <String>{};
    final stack = <(PiHistoryEntry, String?, bool)>[];
    void push(List<PiHistoryEntry> list, String? parent, bool hidden) {
      final ordered = [
        ...list.where((e) => activePath.contains(e.id)),
        ...list.where((e) => !activePath.contains(e.id)),
      ];
      for (final e in ordered.reversed) {
        stack.add((e, parent, hidden));
      }
    }

    push(children[null] ?? [], null, false);
    final remaining = entries.values.iterator;
    while (stack.isNotEmpty || remaining.moveNext()) {
      if (stack.isEmpty) stack.add((remaining.current, null, false));
      final (entry, parent, hidden) = stack.removeLast();
      if (!visited.add(entry.id)) continue;
      final searchable =
          '${entry.text} ${entry.label ?? ''} ${entry.id} ${entry.role} ${entry.type}'
              .toLowerCase();
      final show =
          !hidden &&
          entry.visible(filter, leafId) &&
          tokens.every(searchable.contains);
      if (show) {
        visible[entry.id] = entry;
        visibleChildren.putIfAbsent(parent, () => []).add(entry.id);
      }
      push(
        children[entry.id] ?? [],
        show ? entry.id : parent,
        hidden || (tokens.isEmpty && folded.contains(entry.id)),
      );
    }
    final result = <PiHistoryRow>[];
    final rows = <(String, int)>[
      for (final id in (visibleChildren[null] ?? []).reversed) (id, 0),
    ];
    while (rows.isNotEmpty) {
      final (id, depth) = rows.removeLast();
      final descendants = visibleChildren[id] ?? [];
      result.add(
        PiHistoryRow(visible[id]!, depth, (children[id]?.isNotEmpty ?? false)),
      );
      for (final child in descendants.reversed) {
        rows.add((child, depth + (descendants.length > 1 ? 1 : 0)));
      }
    }
    return result;
  }
}

class PiHistoryResult {
  PiHistoryResult.fromJson(Object? value) {
    final json = rpcObject(value);
    if (json['cancelled'] is! bool) {
      throw const FormatException('Missing history acknowledgement');
    }
    cancelled = json['cancelled'] as bool;
    unchanged = json['unchanged'] == true;
    text = json['editorText'] as String? ?? '';
    images = List.unmodifiable(
      (json['images'] as List? ?? []).map(
        (v) => PiImage.fromJson(rpcObject(v)),
      ),
    );
  }
  late final bool cancelled, unchanged;
  late final String text;
  late final List<PiImage> images;
}

abstract interface class PiHistoryGateway {
  Future<PiHistorySnapshot> load();
  Future<Map<String, dynamic>> entry(PiHistorySnapshot snapshot, String id);
  Future<PiHistoryResult> act(
    PiHistorySnapshot snapshot,
    PiHistoryAction action, {
    String? entryId,
    bool summarize = false,
    String? instructions,
    bool replaceInstructions = false,
  });
  Future<void> label(PiHistorySnapshot snapshot, String id, String label);
}

class PiHistoryService implements PiHistoryGateway {
  PiHistoryService(this.client);
  final PiRpcClient client;
  @override
  Future<PiHistorySnapshot> load() async {
    final state = await client.getState();
    final data = await client.getHistoryEntries();
    final after = await client.getState();
    if (state.sessionId != after.sessionId) {
      throw const PiRpcException('HISTORY_STALE');
    }
    return PiHistorySnapshot(
      sessionId: after.sessionId!,
      sessionFile: after.sessionFile,
      data: data,
    );
  }

  @override
  Future<Map<String, dynamic>> entry(
    PiHistorySnapshot snapshot,
    String id,
  ) async => rpcObject(
    rpcObject(
      await client.requestGui('gui_history_entry', {
        ...snapshot.identity,
        'entryId': id,
      }),
    )['entry'],
  );
  @override
  Future<PiHistoryResult> act(
    PiHistorySnapshot snapshot,
    PiHistoryAction action, {
    String? entryId,
    bool summarize = false,
    String? instructions,
    bool replaceInstructions = false,
  }) async => PiHistoryResult.fromJson(
    await client.requestGui('gui_history_${action.name}', {
      ...snapshot.identity,
      'entryId': ?entryId,
      'summarize': summarize,
      'customInstructions': ?instructions,
      'replaceInstructions': replaceInstructions,
    }),
  );
  @override
  Future<void> label(
    PiHistorySnapshot snapshot,
    String id,
    String label,
  ) async {
    await client.requestGui('gui_history_label', {
      ...snapshot.identity,
      'entryId': id,
      'label': label,
    });
  }
}
