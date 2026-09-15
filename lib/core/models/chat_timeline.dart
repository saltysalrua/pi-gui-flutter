import '../rpc/pi_chat_types.dart';

enum ToolPhase { preparing, running, completed, failed, interrupted }

class ChatToolCall {
  const ChatToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
    this.phase = ToolPhase.preparing,
    this.result,
  });
  final String id, name;
  final Map<String, dynamic> arguments;
  final ToolPhase phase;
  final PiToolResult? result;
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
  );
}

/// Pure RPC projection. Tool updates replace accumulated output, never append it.
class ChatTimeline {
  final messages = <PiChatMessage>[];
  final tools = <String, ChatToolCall>{};
  int? _active;
  int? _thinkingContentIndex;
  int _fallbackTimestamp = -1;

  /// Only the currently streaming thinking block animates, not every thinking
  /// block in a message that is still producing text or tool-call arguments.
  int? thinkingIndexFor(int messageIndex) =>
      messageIndex == _active ? _thinkingContentIndex : null;

  /// Session-local assistant ordinals, aligned with [messages]. Compute once
  /// before building the reversed list, never from builder invocation order.
  List<int?> get assistantNumbers {
    var number = 0;
    return [
      for (final message in messages)
        message.role == 'assistant' ? ++number : null,
    ];
  }

  void load(List<PiChatMessage> history) {
    // Live tool events may carry details absent in old persisted tool results.
    final previous = Map<String, ChatToolCall>.of(tools);
    messages.clear();
    tools.clear();
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
    _thinkingContentIndex = null;
    if (_active != null) {
      messages[_active!] = messages[_active!].copyWith(isStreaming: false);
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
      if (block.kind != PiContentKind.toolCall || block.id.isEmpty) continue;
      final old =
          tools[block.id] ?? ChatToolCall(id: block.id, name: block.name);
      tools[block.id] = old.copyWith(
        name: block.name,
        arguments: block.arguments,
      );
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
      final referenced = messages.any(
        (m) => m.content.any(
          (b) => b.kind == PiContentKind.toolCall && b.id == id,
        ),
      );
      if (!referenced) {
        messages.add(
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
      }
      return;
    }
    if (start) {
      messages.add(message.copyWith(isStreaming: message.role == 'assistant'));
      _active = messages.length - 1;
      _thinkingContentIndex = null;
    } else if (_active != null && messages[_active!].role == message.role) {
      messages[_active!] = message;
      _active = null;
      _thinkingContentIndex = null;
    } else {
      messages.add(message);
    }
    _registerTools(message);
  }

  void _delta(PiContentDelta delta) {
    if (_active == null || messages[_active!].role != 'assistant') {
      messages.add(
        PiChatMessage(
          role: 'assistant',
          content: const [],
          timestamp: _fallbackTimestamp--,
          isStreaming: true,
        ),
      );
      _active = messages.length - 1;
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
    final message = messages[_active!];
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
    messages[_active!] = message.copyWith(content: List.unmodifiable(blocks));
    _registerTools(messages[_active!]);
  }
}
