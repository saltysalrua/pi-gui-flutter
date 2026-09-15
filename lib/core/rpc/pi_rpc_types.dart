/// Pi 的协议值，不代表某个模型一定支持这些等级。
enum PiThinkingLevel {
  off,
  minimal,
  low,
  medium,
  high,
  xhigh,
  max;

  static PiThinkingLevel parse(Object? value) => values.firstWhere(
    (level) => level.name == value,
    orElse: () => throw FormatException('Unknown thinking level: $value'),
  );
}

Map<String, dynamic> rpcObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected an RPC object');
  }
  return value;
}

class PiModel {
  const PiModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.reasoning,
    this.input,
  });

  factory PiModel.fromJson(Object? value) {
    final json = rpcObject(value);
    return PiModel(
      id: json['id'] as String,
      name: (json['name'] ?? json['id']) as String,
      provider: json['provider'] as String,
      reasoning: json['reasoning'] as bool,
      input: json['input'] == null
          ? null
          : List<String>.unmodifiable(json['input'] as List),
    );
  }

  final String id;
  final String name;
  final String provider;
  final bool reasoning;
  // Null means an older backend omitted capabilities; let Pi decide in that case.
  final List<String>? input;
  bool? get supportsImages => input?.contains('image');

  // 显示名称不唯一；选择、对勾和去重必须同时比较 provider 与 id。
  bool sameIdentity(PiModel? other) =>
      other != null && provider == other.provider && id == other.id;
}

class PiSessionState {
  const PiSessionState({
    required this.model,
    required this.thinkingLevel,
    this.isStreaming = false,
    this.isCompacting = false,
    this.sessionFile,
    this.sessionId,
    this.sessionName,
    this.pendingMessageCount = 0,
  });

  factory PiSessionState.fromJson(Object? value) {
    final json = rpcObject(value);
    return PiSessionState(
      model: json['model'] == null ? null : PiModel.fromJson(json['model']),
      thinkingLevel: PiThinkingLevel.parse(json['thinkingLevel']),
      isStreaming: json['isStreaming'] == true,
      isCompacting: json['isCompacting'] == true,
      sessionFile: json['sessionFile'] as String?,
      sessionId: json['sessionId'] as String?,
      sessionName: json['sessionName'] as String?,
      pendingMessageCount: json['pendingMessageCount'] as int? ?? 0,
    );
  }

  final PiModel? model;
  final PiThinkingLevel thinkingLevel;
  final bool isStreaming, isCompacting;
  final String? sessionFile, sessionId, sessionName;
  final int pendingMessageCount;
}

class PiRpcException implements Exception {
  const PiRpcException(
    this.message, {
    this.command,
    this.outcomeUnknown = false,
  });
  final bool outcomeUnknown;
  final String message;
  final String? command;
  @override
  String toString() => 'PiRpcException($command): $message';
}

sealed class PiRpcEvent {
  const PiRpcEvent();
}

class PiRpcConnected extends PiRpcEvent {
  const PiRpcConnected();
}

class PiRpcConversationSettled extends PiRpcEvent {
  const PiRpcConversationSettled();
}

/// Confirmed session switches can also change the selected model/thinking level.
class PiRpcSessionChanged extends PiRpcEvent {
  const PiRpcSessionChanged();
}

/// The adapter has confirmed a new execution directory and a fresh Pi process.
class PiRpcWorkspaceChanged extends PiRpcEvent {
  const PiRpcWorkspaceChanged(this.path);
  final String path;
}

/// Clear old extension slots before the replacement process starts emitting UI.
class PiRpcWorkspaceReset extends PiRpcEvent {
  const PiRpcWorkspaceReset();
}

enum PiRpcDisconnectReason { processExited, transportError }

class PiRpcDisconnected extends PiRpcEvent {
  const PiRpcDisconnected({this.reason = PiRpcDisconnectReason.transportError});
  final PiRpcDisconnectReason reason;
}

/// 调试信息只保存类别和命令，不保存 stdout/stderr 原文或潜在密钥。
enum PiRpcDiagnosticKind {
  nonProtocolLine,
  invalidEvent,
  invalidResponse,
  requestTimeout,
}

class PiRpcDiagnostic extends PiRpcEvent {
  const PiRpcDiagnostic(this.kind, {this.command});
  final PiRpcDiagnosticKind kind;
  final String? command;
}

/// 超时的写请求后来收到确认，通知界面重新回读，不能重发这次写入。
class PiRpcSelectionSettled extends PiRpcEvent {
  const PiRpcSelectionSettled();
}

/// 未实现的 Agent 事件仍保留完整载荷，供时间线等订阅者接入。
class PiAgentEvent extends PiRpcEvent {
  const PiAgentEvent(this.type, this.payload);
  final String type;
  final Map<String, dynamic> payload;
}

class PiExtensionUiRequest extends PiRpcEvent {
  PiExtensionUiRequest.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      method = json['method'] as String,
      title = json['title'] as String?,
      message = json['message'] as String?,
      options = json['options'] == null
          ? null
          : List<String>.from(json['options'] as List),
      placeholder = json['placeholder'] as String?,
      prefill = json['prefill'] as String?,
      text = json['text'] as String?,
      statusKey = json['statusKey'] as String?,
      statusText = json['statusText'] as String?,
      widgetKey = json['widgetKey'] as String?,
      widgetLines = json['widgetLines'] == null
          ? null
          : List<String>.from(json['widgetLines'] as List),
      widgetPlacement = json['widgetPlacement'] as String?,
      timeout = json['timeout'] as int?;

  final String id;
  final String method;
  final String? title, message, placeholder, prefill, text;
  final String? statusKey, statusText, widgetKey, widgetPlacement;
  final List<String>? options, widgetLines;
  final int? timeout;
}

abstract interface class PiModelGateway {
  Stream<PiRpcEvent> get events;
  Future<void> connect();
  Future<List<PiModel>> getAvailableModels();
  Future<PiSessionState> getState();
  Future<List<PiThinkingLevel>> getAvailableThinkingLevels();
  Future<PiModel> setModel(PiModel model);
  Future<void> setThinkingLevel(PiThinkingLevel level);
  Future<void> close();
}
