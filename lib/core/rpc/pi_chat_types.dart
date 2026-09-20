import 'dart:convert';

import 'pi_rpc_types.dart';

/// Provider content is kept in order; no model-specific reasoning assumptions.
enum PiContentKind { text, thinking, toolCall, image, unknown }

/// RPC image payload. Keep encoded bytes intact through history and live events.
class PiImage {
  const PiImage({required this.data, required this.mimeType});
  factory PiImage.fromJson(Map<String, dynamic> json) => PiImage(
    data: json['data'] as String? ?? '',
    mimeType: json['mimeType'] as String? ?? '',
  );
  final String data, mimeType;
  Map<String, dynamic> toJson() => {
    'type': 'image',
    'data': data,
    'mimeType': mimeType,
  };
}

class PiContent {
  const PiContent(
    this.kind, {
    this.text = '',
    this.id = '',
    this.name = '',
    this.arguments = const {},
    this.image,
  });
  factory PiContent.fromJson(Object? value) {
    final json = rpcObject(value);
    return switch (json['type']) {
      'text' => PiContent(PiContentKind.text, text: json['text'] as String),
      'thinking' => PiContent(
        PiContentKind.thinking,
        text: json['thinking'] as String? ?? '',
      ),
      'toolCall' => PiContent(
        PiContentKind.toolCall,
        id: json['id'] as String,
        name: json['name'] as String,
        arguments: Map.unmodifiable(
          rpcObject(json['arguments'] ?? <String, dynamic>{}),
        ),
      ),
      'image' => PiContent(PiContentKind.image, image: PiImage.fromJson(json)),
      _ => const PiContent(PiContentKind.unknown),
    };
  }
  final PiContentKind kind;
  final String text, id, name;
  final Map<String, dynamic> arguments;
  final PiImage? image;
  PiContent withText(String value) => PiContent(
    kind,
    text: value,
    id: id,
    name: name,
    arguments: arguments,
    image: image,
  );
}

List<PiContent> piContent(Object? value) => value is String
    ? [PiContent(PiContentKind.text, text: value)]
    : List.unmodifiable((value as List? ?? []).map(PiContent.fromJson));

enum PiWriteKind { created, modified, unchanged }

class PiToolResult {
  const PiToolResult({
    this.content = const [],
    this.patch,
    this.diff,
    this.details,
    this.isError = false,
  });
  factory PiToolResult.fromJson(Object? value, {bool isError = false}) {
    final json = rpcObject(value);
    final details = json['details'];
    return PiToolResult(
      content: piContent(json['content']),
      patch: details is Map ? details['patch'] as String? : null,
      diff: details is Map ? details['diff'] as String? : null,
      details: details is Map ? Map<String, dynamic>.from(details) : null,
      isError: isError || json['isError'] == true,
    );
  }
  final List<PiContent> content;
  final String? patch, diff;
  final Map<String, dynamic>? details;
  final bool isError;
  PiWriteKind? get writeKind => switch (details?['guiWrite']) {
    {'kind': 'created'} => PiWriteKind.created,
    {'kind': 'modified'} => PiWriteKind.modified,
    {'kind': 'unchanged'} => PiWriteKind.unchanged,
    _ => null,
  };
  String get text => content
      .where((b) => b.kind == PiContentKind.text)
      .map((b) => b.text)
      .join('\n');
}

class PiChatMessage {
  const PiChatMessage({
    required this.role,
    required this.content,
    this.timestamp = 0,
    this.model,
    this.stopReason,
    this.errorMessage,
    this.toolCallId,
    this.toolName,
    this.result,
    this.isStreaming = false,
  });
  factory PiChatMessage.fromJson(Object? value) {
    final json = rpcObject(value);
    final role = json['role'] as String;
    return PiChatMessage(
      role: role,
      content: role == 'bashExecution'
          ? [
              PiContent(
                PiContentKind.text,
                text: '${json['command'] ?? ''}\n${json['output'] ?? ''}',
              ),
            ]
          : piContent(json['content']),
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      model: json['model'] as String?,
      stopReason: json['stopReason'] as String?,
      errorMessage: json['errorMessage'] as String?,
      toolCallId: json['toolCallId'] as String?,
      toolName: json['toolName'] as String?,
      result: role == 'toolResult' ? PiToolResult.fromJson(json) : null,
    );
  }
  final String role;
  final List<PiContent> content;
  final int timestamp;
  final String? model, stopReason, toolCallId, toolName;

  /// Pi's model/provider error, preserved for both live messages and history.
  final String? errorMessage;
  final PiToolResult? result;
  final bool isStreaming;
  String get text => content
      .where((b) => b.kind == PiContentKind.text)
      .map((b) => b.text)
      .join('\n\n');
  PiChatMessage copyWith({List<PiContent>? content, bool? isStreaming}) =>
      PiChatMessage(
        role: role,
        content: content ?? this.content,
        timestamp: timestamp,
        model: model,
        stopReason: stopReason,
        errorMessage: errorMessage,
        toolCallId: toolCallId,
        toolName: toolName,
        result: result,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

class PiContentDelta {
  PiContentDelta.fromJson(Object? value) {
    final json = rpcObject(value);
    type = json['type'] as String;
    index = json['contentIndex'] as int;
    if (index < 0 || index > 4096) {
      throw const FormatException('Invalid content index');
    }
    delta = json['delta'] as String? ?? '';
    content = json['content'] as String?;
    id = json['id'] as String? ?? '';
    name = json['toolName'] as String? ?? '';
    toolCall = json['toolCall'] == null
        ? null
        : PiContent.fromJson(json['toolCall']);
  }
  late final String type, delta, id, name;
  late final String? content;
  late final int index;
  late final PiContent? toolCall;
}

/// Typed chat events also retain the generic event identity for existing subscribers.
class PiChatEvent extends PiAgentEvent {
  PiChatEvent(super.type, super.payload)
    : message = payload['message'] == null
          ? null
          : PiChatMessage.fromJson(payload['message']),
      delta = payload['assistantMessageEvent'] == null
          ? null
          : PiContentDelta.fromJson(payload['assistantMessageEvent']),
      toolCallId = payload['toolCallId'] as String?,
      toolName = payload['toolName'] as String?,
      arguments = payload['args'] == null
          ? null
          : Map.unmodifiable(rpcObject(payload['args'])),
      result =
          (payload['partialResult'] ?? payload['result']) is Map &&
              type.startsWith('tool_execution_')
          ? PiToolResult.fromJson(
              payload['partialResult'] ?? payload['result'],
              isError: payload['isError'] == true,
            )
          : null,
      queued = type == 'queue_update' ? PiPromptQueue.fromJson(payload) : null,
      failed =
          payload['success'] == false ||
          payload['errorMessage'] != null && type == 'compaction_end';
  static const types = {
    'agent_start',
    'agent_end',
    'agent_settled',
    'message_start',
    'message_update',
    'message_end',
    'tool_execution_start',
    'tool_execution_update',
    'tool_execution_end',
    'queue_update',
    'compaction_start',
    'compaction_end',
    'auto_retry_start',
    'auto_retry_end',
    'summarization_retry_scheduled',
    'summarization_retry_attempt_start',
    'summarization_retry_finished',
    'extension_error',
  };
  final PiChatMessage? message;
  final PiContentDelta? delta;
  final String? toolCallId, toolName;
  final Map<String, dynamic>? arguments;
  final PiToolResult? result;
  final PiPromptQueue? queued;
  final bool failed;
}

class PiPromptQueue {
  const PiPromptQueue({this.steering = const [], this.followUp = const []});
  factory PiPromptQueue.fromJson(Object? value) {
    final json = rpcObject(value);
    return PiPromptQueue(
      steering: List<String>.from(json['steering'] as List? ?? []),
      followUp: List<String>.from(json['followUp'] as List? ?? []),
    );
  }
  final List<String> steering, followUp;
  List<String> get all => [...steering, ...followUp];
}

abstract interface class PiChatGateway {
  Stream<PiRpcEvent> get events;
  bool get hasUnsettledConversationMutation;
  Future<void> connect();
  Future<PiSessionState> getState();
  Future<List<PiChatMessage>> getMessages();
  Future<void> prompt(String text, {List<PiImage> images = const []});
  Future<void> abort();
  Future<PiPromptQueue> clearQueue();
  Future<bool> newSession();
  Future<bool> switchSession(String path);
}

/// Stable, pretty output for the generic tool renderer, never a command to execute.
String formatToolArguments(Map<String, dynamic> arguments) =>
    const JsonEncoder.withIndent('  ').convert(arguments);
