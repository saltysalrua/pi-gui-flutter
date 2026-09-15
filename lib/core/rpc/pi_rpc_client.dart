import 'dart:async';
import 'dart:convert';

import 'pi_rpc_transport.dart';
import 'pi_chat_types.dart';
import 'pi_rpc_types.dart';
import 'pi_workspace_types.dart';

class _PendingRequest {
  _PendingRequest(this.command);
  final String command;
  final result = Completer<Object?>();
  final settled = Completer<void>();
  bool get isMutation =>
      command == 'set_model' || command == 'set_thinking_level';
  bool get isWorkspaceMutation => const {
    'gui_open_workspace',
    'gui_create_workspace',
    'gui_create_worktree',
    'gui_remove_worktree',
  }.contains(command);
  bool get isConversationMutation =>
      isWorkspaceMutation ||
      const {'prompt', 'new_session', 'switch_session'}.contains(command);
}

/// 单个长期存活的 Pi 子进程；Widget 不接触进程或协议 JSON。
class PiRpcClient implements PiModelGateway, PiChatGateway, PiWorkspaceGateway {
  PiRpcClient({
    String? workingDirectory,
    List<String> extraArguments = const [],
    Future<PiRpcTransport> Function()? transportFactory,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _transportFactory =
           transportFactory ??
           (() => PiProcessTransport.start(
             workingDirectory: workingDirectory,
             extraArguments: extraArguments,
           ));

  final Future<PiRpcTransport> Function() _transportFactory;
  final Duration requestTimeout;
  final _events = StreamController<PiRpcEvent>.broadcast();
  final _pending = <String, _PendingRequest>{};
  final _diagnostics = <PiRpcDiagnostic>[];
  PiRpcTransport? _transport;
  StreamSubscription<String>? _subscription;
  Future<void>? _connecting;
  Future<void>? _disconnecting;
  bool _closed = false;
  int _nextId = 0;
  int _connectionCount = 0;
  PiRpcDisconnectReason? lastDisconnectReason;

  @override
  bool get hasUnsettledConversationMutation =>
      _pending.values.any((p) => p.isConversationMutation);
  bool get isConnected => _transport != null && !_closed;
  int get connectionCount => _connectionCount;
  List<PiRpcDiagnostic> get diagnostics => List.unmodifiable(_diagnostics);

  @override
  Stream<PiRpcEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    if (_closed) throw const PiRpcException('Client is closed');
    await _disconnecting;
    if (_closed) throw const PiRpcException('Client is closed');
    if (_transport != null) return;
    final connecting = _connecting ??= _start();
    try {
      await connecting;
    } finally {
      if (identical(_connecting, connecting)) _connecting = null;
    }
  }

  Future<void> _start() async {
    final transport = await _transportFactory();
    if (_closed) {
      await transport.close();
      throw const PiRpcException('Client is closed');
    }
    _transport = transport;
    _connectionCount++;
    _events.add(const PiRpcConnected());
    _subscription = decodePiJsonl(transport.stdout).listen(
      (line) {
        if (identical(_transport, transport)) _onLine(line);
      },
      onError: (Object error) => _disconnect(error, source: transport),
      onDone: () => _disconnect(
        const PiRpcException('Pi exited'),
        source: transport,
        reason: PiRpcDisconnectReason.processExited,
      ),
    );
  }

  void _record(PiRpcDiagnosticKind kind, {String? command}) {
    final diagnostic = PiRpcDiagnostic(kind, command: command);
    if (_diagnostics.length == 24) _diagnostics.removeAt(0);
    _diagnostics.add(diagnostic);
    if (!_closed) _events.add(diagnostic);
  }

  void _onLine(String line) {
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      // 扩展/启动器可能往 stdout 打日志；一条旁路输出不能杀死健康的 Pi。
      _record(PiRpcDiagnosticKind.nonProtocolLine);
      return;
    }
    if (decoded is! Map<String, dynamic> || decoded['type'] is! String) {
      _record(PiRpcDiagnosticKind.nonProtocolLine);
      return;
    }
    final type = decoded['type'] as String;
    if (type == 'response') {
      final pending = _pending.remove(decoded['id']);
      if (pending == null) return; // 已超时的读请求或无关响应。
      final lateMutation = pending.isMutation && pending.result.isCompleted;
      final lateConversation =
          pending.isConversationMutation && pending.result.isCompleted;
      var acknowledged = true;
      try {
        if (decoded['command'] != pending.command ||
            decoded['success'] is! bool) {
          throw const FormatException('Invalid RPC response');
        }
        if (decoded['success'] == true) {
          if (!pending.result.isCompleted) {
            pending.result.complete(decoded['data']);
          }
        } else {
          final message = decoded['error'];
          if (message is! String) {
            throw const FormatException('Invalid RPC error');
          }
          if (!pending.result.isCompleted) {
            pending.result.completeError(
              PiRpcException(message, command: pending.command),
            );
          }
        }
      } catch (error) {
        _record(PiRpcDiagnosticKind.invalidResponse, command: pending.command);
        if (pending.isConversationMutation) {
          // A malformed acknowledgement cannot prove a prompt was rejected.
          acknowledged = false;
          _pending[decoded['id'] as String] = pending;
          if (!pending.result.isCompleted) {
            pending.result.completeError(
              PiRpcException(
                'Invalid acknowledgement',
                command: pending.command,
                outcomeUnknown: true,
              ),
            );
          }
        } else if (!pending.result.isCompleted) {
          pending.result.completeError(error);
        }
      } finally {
        if (acknowledged) pending.settled.complete();
      }
      if (acknowledged && lateMutation) {
        _events.add(const PiRpcSelectionSettled());
      }
      if (acknowledged && lateConversation) {
        _events.add(const PiRpcConversationSettled());
      }
      final data = decoded['data'];
      if (acknowledged &&
          decoded['success'] == true &&
          data is Map &&
          data['cancelled'] == false &&
          const {'new_session', 'switch_session'}.contains(pending.command)) {
        _events.add(const PiRpcSessionChanged());
      }
      return;
    }
    if (type == 'gui_workspace_reset') {
      _events.add(const PiRpcWorkspaceReset());
      return;
    }
    if (type == 'gui_workspace_changed') {
      final path = decoded['path'];
      if (path is String && path.isNotEmpty) {
        _events.add(PiRpcWorkspaceChanged(path));
      } else {
        _record(PiRpcDiagnosticKind.invalidEvent, command: type);
      }
      return;
    }
    if (type == 'extension_ui_request') {
      try {
        _events.add(PiExtensionUiRequest.fromJson(decoded));
      } catch (_) {
        _record(
          PiRpcDiagnosticKind.invalidEvent,
          command: 'extension_ui_request',
        );
        final id = decoded['id'];
        if (id is String &&
            const [
              'select',
              'confirm',
              'input',
              'editor',
            ].contains(decoded['method'])) {
          // 非法对话仍回取消，避免扩展一直等待；扩展桥会显示提示。
          unawaited(respondToExtension(id, cancelled: true));
        }
      }
    } else {
      try {
        _events.add(
          PiChatEvent.types.contains(type)
              ? PiChatEvent(type, Map.unmodifiable(decoded))
              : PiAgentEvent(type, Map.unmodifiable(decoded)),
        );
      } catch (_) {
        _record(PiRpcDiagnosticKind.invalidEvent, command: type);
      }
    }
  }

  void _disconnect(
    Object error, {
    required PiRpcTransport source,
    PiRpcDisconnectReason reason = PiRpcDisconnectReason.transportError,
  }) {
    // 旧连接迟到的 flush 异常/EOF，绝不能关闭新连接。
    if (!identical(_transport, source)) return;
    for (final pending in _pending.values) {
      if (!pending.result.isCompleted) pending.result.completeError(error);
      pending.settled.complete();
    }
    _pending.clear();
    _transport = null;
    final subscription = _subscription;
    _subscription = null;
    _disconnecting = () async {
      final cancelling = subscription?.cancel();
      try {
        await source.close();
      } finally {
        await cancelling;
      }
    }();
    if (!_closed) {
      lastDisconnectReason = reason;
      _events.add(PiRpcDisconnected(reason: reason));
    }
  }

  Future<Object?> _request(
    String command, [
    Map<String, Object?> fields = const {},
  ]) async {
    await connect();
    // 写请求超时也不能重放。等原请求确认后再查询/写入，防止迟到提交覆盖新选择。
    while (true) {
      final writes = _pending.values
          .where(
            (pending) =>
                pending.isWorkspaceMutation ||
                (pending.isMutation &&
                    !const {'abort', 'clear_queue'}.contains(command)) ||
                (pending.isConversationMutation &&
                    const {
                      'prompt',
                      'new_session',
                      'switch_session',
                      'gui_open_workspace',
                      'gui_create_workspace',
                      'gui_create_worktree',
                      'gui_remove_worktree',
                    }.contains(command)),
          )
          .toList();
      if (writes.isEmpty) break;
      try {
        await Future.wait(
          writes.map((pending) => pending.settled.future),
        ).timeout(requestTimeout);
      } on TimeoutException {
        _record(PiRpcDiagnosticKind.requestTimeout, command: command);
        throw PiRpcException(
          'Waiting for an earlier selection to settle',
          command: command,
        );
      }
    }
    final transport = _transport;
    if (_closed || transport == null) {
      throw const PiRpcException('Pi disconnected');
    }
    final id = 'gui-${++_nextId}';
    final pending = _PendingRequest(command);
    _pending[id] = pending;
    final timer = Timer(requestTimeout, () {
      if (!identical(_pending[id], pending)) return;
      _record(PiRpcDiagnosticKind.requestTimeout, command: command);
      pending.result.completeError(
        PiRpcException(
          'Request timed out',
          command: command,
          outcomeUnknown: pending.isMutation || pending.isConversationMutation,
        ),
      );
      if (!pending.isMutation && !pending.isConversationMutation) {
        _pending.remove(id);
        pending.settled.complete();
      }
      // 读超时只影响本次请求；写超时保留待确认屏障，都不主动杀 Pi。
    });
    unawaited(
      transport
          .send('${jsonEncode({'id': id, 'type': command, ...fields})}\n')
          .catchError((Object error) => _disconnect(error, source: transport)),
    );
    try {
      return await pending.result.future;
    } finally {
      timer.cancel();
    }
  }

  @override
  Future<List<PiModel>> getAvailableModels() async {
    final data = rpcObject(await _request('get_available_models'));
    return List.unmodifiable((data['models'] as List).map(PiModel.fromJson));
  }

  @override
  Future<PiSessionState> getState() async =>
      PiSessionState.fromJson(await _request('get_state'));

  @override
  Future<List<PiThinkingLevel>> getAvailableThinkingLevels() async {
    final data = rpcObject(await _request('get_available_thinking_levels'));
    return List.unmodifiable(
      (data['levels'] as List).map(PiThinkingLevel.parse),
    );
  }

  @override
  Future<PiModel> setModel(PiModel model) async => PiModel.fromJson(
    await _request('set_model', {
      'provider': model.provider,
      'modelId': model.id,
    }),
  );

  @override
  Future<void> setThinkingLevel(PiThinkingLevel level) async {
    await _request('set_thinking_level', {'level': level.name});
  }

  @override
  Future<List<PiChatMessage>> getMessages() async {
    final data = rpcObject(await _request('get_messages'));
    return List.unmodifiable(
      (data['messages'] as List).map(PiChatMessage.fromJson),
    );
  }

  @override
  Future<void> prompt(String text, {List<PiImage> images = const []}) async {
    await _request('prompt', {
      'message': text,
      if (images.isNotEmpty)
        'images': images.map((image) => image.toJson()).toList(),
    });
  }

  @override
  Future<void> abort() async {
    await _request('abort');
  }

  @override
  Future<PiPromptQueue> clearQueue() async =>
      PiPromptQueue.fromJson(await _request('clear_queue'));

  @override
  Future<bool> newSession() async =>
      rpcObject(await _request('new_session'))['cancelled'] != true;

  @override
  Future<bool> switchSession(String path) async =>
      rpcObject(
        await _request('switch_session', {'sessionPath': path}),
      )['cancelled'] !=
      true;

  @override
  Future<PiWorkspaceSnapshot> getWorkspace() async =>
      PiWorkspaceSnapshot.fromJson(await _request('gui_get_workspace'));

  @override
  Future<List<PiSessionSummary>> listSessions() async {
    final data = rpcObject(await _request('gui_list_sessions'));
    return List.unmodifiable(
      (data['sessions'] as List).map(PiSessionSummary.fromJson),
    );
  }

  @override
  Future<PiWorkspaceSnapshot> openWorkspace(String path) async =>
      PiWorkspaceSnapshot.fromJson(
        await _request('gui_open_workspace', {'path': path}),
      );

  @override
  Future<String> createWorkspace(String parent, String name) async =>
      rpcObject(
            await _request('gui_create_workspace', {
              'parent': parent,
              'name': name,
            }),
          )['path']
          as String;

  @override
  Future<String> createWorktree(String branch, String baseRef) async =>
      rpcObject(
            await _request('gui_create_worktree', {
              'branch': branch,
              'baseRef': baseRef,
            }),
          )['path']
          as String;

  @override
  Future<void> removeWorktree(String path) async {
    await _request('gui_remove_worktree', {'path': path});
  }

  Future<void> respondToExtension(
    String id, {
    String? value,
    bool? confirmed,
    bool cancelled = false,
  }) async {
    final transport = _transport;
    if (transport == null || _closed) return;
    try {
      await transport.send(
        '${jsonEncode({'type': 'extension_ui_response', 'id': id, if (cancelled) 'cancelled': true, if (!cancelled && value != null) 'value': value, if (!cancelled && confirmed != null) 'confirmed': confirmed})}\n',
      );
    } catch (error) {
      _disconnect(error, source: transport);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final transport = _transport;
    if (transport != null) {
      _disconnect(const PiRpcException('Client is closed'), source: transport);
    }
    try {
      await _connecting;
    } catch (_) {
      /* 启动中关闭。 */
    }
    await _disconnecting;
    await _events.close();
  }
}
