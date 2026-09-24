import '../rpc/pi_chat_types.dart';

enum ToolPhase { preparing, running, completed, failed, interrupted }

class ChatToolCall {
  const ChatToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
    this.phase = ToolPhase.preparing,
    this.result,
    this.evicted = false,
  });
  final String id, name;
  final Map<String, dynamic> arguments;
  final ToolPhase phase;
  final PiToolResult? result;

  /// The full output is no longer retained: a short preview stays and a
  /// history re-read restores the complete text. Never true for unsettled
  /// tools, which the budget pass skips.
  final bool evicted;
  String? get path =>
      arguments['path'] is String ? arguments['path'] as String : null;
  String get summary =>
      path ??
      (arguments['command'] is String ? arguments['command'] as String : name);
  String? get writtenContent =>
      name == 'write' && arguments['content'] is String
      ? arguments['content'] as String
      : null;
  bool get isFileChange =>
      phase == ToolPhase.completed &&
      path != null &&
      (name == 'edit' ||
          name == 'write' ||
          result?.patch != null ||
          result?.diff != null);
  ChatToolCall copyWith({
    String? name,
    Map<String, dynamic>? arguments,
    ToolPhase? phase,
    PiToolResult? result,
  }) => ChatToolCall(
    id: id,
    name: name ?? this.name,
    arguments: arguments ?? this.arguments,
    phase: phase ?? this.phase,
    result: result ?? this.result,
    evicted: evicted,
  );
}

/// Pure RPC projection. Tool updates replace accumulated output, never append it.
class ChatTimeline {
  final _messages = <PiChatMessage>[];

  /// Streaming text/thinking/tool-argument deltas of the active message, by
  /// contentIndex. Appending to an immutable String on every token copies the
  /// whole block each time (quadratic for long replies); deltas are buffered
  /// here and folded into the block once, when anyone reads [messages] or a
  /// non-delta event arrives. Readers therefore always see complete text.
  final _pendingText = <int, StringBuffer>{};

  List<PiChatMessage> get messages {
    _flush();
    return _messages;
  }

  /// Cheap emptiness check that does not fold pending streaming text.
  bool get isEmpty => _messages.isEmpty;
  final tools = <String, ChatToolCall>{};
  // Count visible references, including orphan placeholders. A final message
  // may remove a draft tool call, so a grow-only set would hide later results.
  final _toolReferences = <String, int>{};
  int? _active;
  int? _thinkingContentIndex;
  int _fallbackTimestamp = -1;

  /// Retained tool output stays bounded: beyond this many bytes (UTF-16 code
  /// units doubled as a byte approximation) the oldest settled outputs are
  /// reduced to short previews. [applyOutputBudget] releases them.
  static const int defaultOutputBudgetBytes = 8 << 20;
  static const int _evictedPreviewLength = 2000;

  /// Releases the oldest settled tool outputs until the retained total fits
  /// [budgetBytes]. Conversation order comes from the messages, so "oldest"
  /// follows the user-visible order. Pinned ids (expanded rows) and unsettled
  /// tools are never released; already evicted previews are not counted.
  void applyOutputBudget(int budgetBytes, {Set<String> pinned = const {}}) {
    final order = _toolOrder();
    var total = 0;
    for (final id in order) {
      final tool = tools[id];
      if (tool != null) total += _retainedBytes(tool);
    }
    for (final id in order) {
      if (total <= budgetBytes) break;
      final tool = tools[id];
      if (tool == null ||
          tool.evicted ||
          pinned.contains(id) ||
          tool.phase == ToolPhase.preparing ||
          tool.phase == ToolPhase.running) {
        continue;
      }
      final replacement = _evict(tool);
      total += _retainedBytes(replacement) - _retainedBytes(tool);
      tools[id] = replacement;
      _releaseOrphanResult(id, replacement.result);
    }
  }

  List<String> _toolOrder() {
    _flush();
    // Insertion-ordered set: long sessions must not pay O(n²) list lookups.
    final order = <String>{};
    for (final message in _messages) {
      for (final block in message.content) {
        if (block.kind == PiContentKind.toolCall && block.id.isNotEmpty) {
          order.add(block.id);
        }
      }
    }
    return order.toList();
  }

  static int _retainedBytes(ChatToolCall tool) {
    var bytes = 0;
    void add(String? value) => bytes += (value?.length ?? 0) * 2;
    final result = tool.result;
    if (result != null) {
      add(result.patch);
      add(result.diff);
      for (final block in result.content) {
        add(block.text);
        bytes += (block.image?.data.length ?? 0) * 2;
      }
    }
    add(tool.writtenContent);
    return bytes;
  }

  ChatToolCall _evict(ChatToolCall tool) {
    final result = tool.result;
    final preview = result?.text ?? '';
    final trimmed = preview.length <= _evictedPreviewLength
        ? preview
        : preview.substring(0, _evictedPreviewLength);
    final details = result?.details;
    return ChatToolCall(
      id: tool.id,
      name: tool.name,
      arguments: Map.of(tool.arguments)..remove('content'),
      phase: tool.phase,
      result: result == null
          ? null
          : PiToolResult(
              content: trimmed.isEmpty
                  ? const <PiContent>[]
                  : [PiContent(PiContentKind.text, text: trimmed)],
              details: details == null
                  ? null
                  : (Map<String, dynamic>.of(details)
                      ..remove('patch')
                      ..remove('diff')),
              isError: result.isError,
            ),
      evicted: true,
    );
  }

  /// Orphan tool-result messages hold their own result copy; release it too,
  /// otherwise the budget would be defeated by compacted-history orphans.
  void _releaseOrphanResult(String id, PiToolResult? replacement) {
    for (var i = 0; i < _messages.length; i++) {
      final current = _messages[i];
      if (current.toolCallId == id && current.result != null) {
        _messages[i] = PiChatMessage(
          role: current.role,
          content: current.content,
          timestamp: current.timestamp,
          model: current.model,
          stopReason: current.stopReason,
          errorMessage: current.errorMessage,
          toolCallId: current.toolCallId,
          toolName: current.toolName,
          result: replacement,
          isStreaming: current.isStreaming,
        );
      }
    }
  }

  /// Checked before settling: incomplete messages/tools require an authoritative
  /// history read rather than treating a partial draft as a final result.
  bool get hasUnsettledContent =>
      _active != null ||
      tools.values.any(
        (tool) =>
            tool.phase == ToolPhase.preparing ||
            tool.phase == ToolPhase.running,
      );

  /// Only the currently streaming thinking block animates, not every thinking
  /// block in a message that is still producing text or tool-call arguments.
  int? thinkingIndexFor(int messageIndex) =>
      messageIndex == _active ? _thinkingContentIndex : null;

  /// Session-local assistant ordinals, aligned with [messages]. Compute once
  /// before building the reversed list, never from builder invocation order.
  List<int?> get assistantNumbers {
    var number = 0;
    return [
      for (final message in _messages)
        message.role == 'assistant' ? ++number : null,
    ];
  }

  void load(List<PiChatMessage> history) {
    // Live tool events may carry details absent in old persisted tool results.
    final previous = Map<String, ChatToolCall>.of(tools);
    _pendingText.clear();
    _messages.clear();
    tools.clear();
    _toolReferences.clear();
    _active = null;
    _thinkingContentIndex = null;
    for (final message in history) {
      _message(message, start: false);
    }
    for (final id in tools.keys.toList()) {
      final old = previous[id];
      if (old != null &&
          tools[id]!.result?.patch == null &&
          tools[id]!.result?.diff == null &&
          (old.result?.patch != null || old.result?.diff != null)) {
        tools[id] = tools[id]!.copyWith(result: old.result);
      }
    }
  }

  void apply(PiChatEvent event) {
    if (event.type != 'message_update') _flush();
    switch (event.type) {
      case 'message_start':
        if (event.message != null) _message(event.message!, start: true);
      case 'message_end':
        if (event.message != null) _message(event.message!, start: false);
      case 'message_update':
        if (event.delta != null) _delta(event.delta!);
      case 'tool_execution_start':
      case 'tool_execution_update':
      case 'tool_execution_end':
        final id = event.toolCallId;
        if (id == null) return;
        final old =
            tools[id] ?? ChatToolCall(id: id, name: event.toolName ?? '');
        tools[id] = old.copyWith(
          name: event.toolName,
          arguments: event.arguments,
          result: event.result,
          phase: event.type == 'tool_execution_end'
              ? (event.result?.isError == true
                    ? ToolPhase.failed
                    : ToolPhase.completed)
              : ToolPhase.running,
        );
      case 'agent_settled':
        settle();
    }
  }

  void settle() {
    _flush();
    _thinkingContentIndex = null;
    if (_active != null) {
      _messages[_active!] = _messages[_active!].copyWith(isStreaming: false);
      _active = null;
    }
    for (final entry in tools.entries.toList()) {
      if (entry.value.phase == ToolPhase.running ||
          entry.value.phase == ToolPhase.preparing) {
        tools[entry.key] = entry.value.copyWith(phase: ToolPhase.interrupted);
      }
    }
  }

  void _registerTools(PiChatMessage message) {
    for (final block in message.content) {
      _registerTool(block);
    }
  }

  void _registerTool(PiContent block) {
    if (block.kind != PiContentKind.toolCall) return;
    _toolReferences.update(block.id, (count) => count + 1, ifAbsent: () => 1);
    if (block.id.isEmpty) return;
    final old = tools[block.id] ?? ChatToolCall(id: block.id, name: block.name);
    tools[block.id] = old.copyWith(
      name: block.name,
      arguments: block.arguments,
    );
  }

  void _unregisterTool(PiContent block) {
    if (block.kind != PiContentKind.toolCall) return;
    final count = _toolReferences[block.id] ?? 0;
    if (count <= 1) {
      _toolReferences.remove(block.id);
    } else {
      _toolReferences[block.id] = count - 1;
    }
  }

  void _message(PiChatMessage message, {required bool start}) {
    if (message.role == 'toolResult') {
      if (start) return;
      final id = message.toolCallId;
      if (id == null) return;
      final old =
          tools[id] ?? ChatToolCall(id: id, name: message.toolName ?? '');
      tools[id] = old.copyWith(
        result: message.result,
        phase: message.result?.isError == true
            ? ToolPhase.failed
            : ToolPhase.completed,
      );
      // Orphan results (e.g. compacted history) must still remain visible.
      if (!_toolReferences.containsKey(id)) {
        _messages.add(
          PiChatMessage(
            role: 'toolResult',
            toolCallId: id,
            toolName: old.name,
            result: message.result,
            content: [
              PiContent(
                PiContentKind.toolCall,
                id: id,
                name: old.name,
                arguments: old.arguments,
              ),
            ],
            timestamp: message.timestamp,
          ),
        );
        _registerTools(_messages.last);
      }
      return;
    }
    if (start) {
      _messages.add(message.copyWith(isStreaming: message.role == 'assistant'));
      _active = _messages.length - 1;
      _thinkingContentIndex = null;
    } else if (_active != null && _messages[_active!].role == message.role) {
      for (final block in _messages[_active!].content) {
        _unregisterTool(block);
      }
      _messages[_active!] = message;
      _active = null;
      _thinkingContentIndex = null;
    } else {
      _messages.add(message);
    }
    _registerTools(message);
  }

  /// Text length of the newest message including buffered deltas, without
  /// folding them (used to pick the streaming notify interval per event).
  int get lastMessageTextLength {
    final last = _messages.lastOrNull;
    if (last == null) return 0;
    var length = last.content.fold<int>(0, (sum, b) => sum + b.text.length);
    if (_active == _messages.length - 1) {
      for (final buffer in _pendingText.values) {
        length += buffer.length;
      }
    }
    return length;
  }

  /// Folds buffered streaming deltas into the active message (one copy per
  /// block per read, instead of one per token).
  void _flush() {
    if (_pendingText.isEmpty) return;
    final index = _active;
    if (index == null) {
      _pendingText.clear();
      return;
    }
    final message = _messages[index];
    final blocks = [...message.content];
    for (final MapEntry(key: i, value: buffer) in _pendingText.entries) {
      blocks[i] = blocks[i].withText(blocks[i].text + buffer.toString());
    }
    _pendingText.clear();
    _messages[index] = message.copyWith(content: List.unmodifiable(blocks));
  }

  /// Appends a text/thinking/tool-argument delta to an existing block of the
  /// same kind without rebuilding the message. Returns false when the normal
  /// path must create or convert the block.
  bool _buffer(PiContentDelta delta) {
    final index = _active;
    if (index == null || _messages[index].role != 'assistant') return false;
    final content = _messages[index].content;
    if (delta.index >= content.length) return false;
    final kind = content[delta.index].kind;
    final matches = switch (delta.type) {
      'text_delta' => kind == PiContentKind.text,
      'thinking_delta' => kind == PiContentKind.thinking,
      'toolcall_delta' => true,
      _ => false,
    };
    if (!matches) return false;
    _pendingText.putIfAbsent(delta.index, StringBuffer.new).write(delta.delta);
    return true;
  }

  void _delta(PiContentDelta delta) {
    if (_buffer(delta)) {
      _thinkingContentIndex = delta.type == 'thinking_delta'
          ? delta.index
          : null;
      return;
    }
    _flush();
    if (_active == null || _messages[_active!].role != 'assistant') {
      _messages.add(
        PiChatMessage(
          role: 'assistant',
          content: const [],
          timestamp: _fallbackTimestamp--,
          isStreaming: true,
        ),
      );
      _active = _messages.length - 1;
      _thinkingContentIndex = null;
    }
    _thinkingContentIndex = switch (delta.type) {
      'thinking_start' || 'thinking_delta' => delta.index,
      'thinking_end' =>
        delta.index == _thinkingContentIndex ? null : _thinkingContentIndex,
      'text_start' ||
      'text_delta' ||
      'text_end' ||
      'toolcall_start' ||
      'toolcall_delta' ||
      'toolcall_end' => null,
      _ => _thinkingContentIndex,
    };
    final message = _messages[_active!];
    final blocks = [...message.content];
    while (blocks.length <= delta.index) {
      blocks.add(const PiContent(PiContentKind.unknown));
    }
    final old = blocks[delta.index];
    switch (delta.type) {
      case 'text_start':
        blocks[delta.index] = const PiContent(PiContentKind.text);
      case 'thinking_start':
        blocks[delta.index] = const PiContent(PiContentKind.thinking);
      case 'text_delta':
        blocks[delta.index] = PiContent(
          PiContentKind.text,
          text: old.text + delta.delta,
        );
      case 'thinking_delta':
        blocks[delta.index] = PiContent(
          PiContentKind.thinking,
          text: old.text + delta.delta,
        );
      case 'text_end':
      case 'thinking_end':
        blocks[delta.index] = old.withText(delta.content ?? old.text);
      case 'toolcall_start':
        blocks[delta.index] = PiContent(
          PiContentKind.toolCall,
          id: delta.id,
          name: delta.name,
        );
      case 'toolcall_delta':
        blocks[delta.index] = old.withText(old.text + delta.delta);
      case 'toolcall_end':
        if (delta.toolCall != null) blocks[delta.index] = delta.toolCall!;
    }
    _messages[_active!] = message.copyWith(content: List.unmodifiable(blocks));
    // Only the changed block needs bookkeeping, not every prior tool in this
    // assistant message on every text/thinking delta.
    _unregisterTool(old);
    _registerTool(blocks[delta.index]);
  }
}
