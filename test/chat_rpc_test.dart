import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/models/chat_timeline.dart';
import 'package:pi_gui/core/models/diff_document.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/features/home/controllers/chat_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport;

PiChatEvent event(String type, [Map<String, dynamic> fields = const {}]) =>
    PiChatEvent(type, {'type': type, ...fields});
Map<String, dynamic> message(
  String role,
  Object content, [
  int timestamp = 1,
]) => {'role': role, 'content': content, 'timestamp': timestamp};
Map<String, dynamic> text(String value) => {'type': 'text', 'text': value};
Future<void> tick() => Future<void>.delayed(Duration.zero);

class FakeChatGateway implements PiChatGateway {
  final stream = StreamController<PiRpcEvent>.broadcast(sync: true);
  final commands = <String>[];
  List<PiChatMessage> history = [];
  PiSessionState state = const PiSessionState(
    model: null,
    thinkingLevel: PiThinkingLevel.off,
    sessionFile: '/first.jsonl',
  );
  bool cancelled = false;
  Completer<void>? pendingPrompt;
  List<PiImage> sentImages = const [];
  Completer<List<PiChatMessage>>? pendingHistory;
  Completer<PiSessionState>? pendingState;
  @override
  bool hasUnsettledConversationMutation = false;
  @override
  Stream<PiRpcEvent> get events => stream.stream;
  @override
  Future<void> connect() async {
    commands.add('connect');
  }

  @override
  Future<PiSessionState> getState() async {
    commands.add('get_state');
    return pendingState?.future ?? state;
  }

  @override
  Future<List<PiChatMessage>> getMessages() async {
    commands.add('get_messages');
    return pendingHistory?.future ?? history;
  }

  @override
  Future<void> prompt(String value, {List<PiImage> images = const []}) async {
    sentImages = images;
    commands.add('prompt:$value');
    await pendingPrompt?.future;
  }

  @override
  Future<void> abort() async {
    commands.add('abort');
  }

  @override
  Future<PiPromptQueue> clearQueue() async {
    commands.add('clear_queue');
    return const PiPromptQueue(followUp: ['next']);
  }

  @override
  Future<bool> newSession() async {
    commands.add('new_session');
    return !cancelled;
  }

  @override
  Future<bool> switchSession(String path) async {
    commands.add('switch_session:$path');
    return !cancelled;
  }
}

void main() {
  test('stream batches only notify content; final state flushes without a stale batch', () async {
    final gateway = FakeChatGateway();
    final chat = ChatController(gateway);
    addTearDown(chat.dispose);
    addTearDown(gateway.stream.close);
    var stateChanges = 0, contentChanges = 0;
    chat.addListener(() => stateChanges++);
    chat.timelineChanges.addListener(() => contentChanges++);
    gateway.stream.add(
      event('message_start', {'message': message('assistant', [], 1)}),
    );
    stateChanges = contentChanges = 0;
    void delta(String value) => gateway.stream.add(
      event('message_update', {
        'assistantMessageEvent': {
          'type': 'text_delta',
          'contentIndex': 0,
          'delta': value,
        },
      }),
    );
    delta('a');
    delta('b');
    expect(stateChanges, 0);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(contentChanges, 1);
    expect(stateChanges, 0);
    expect(chat.timeline.messages.single.text, 'ab');
    delta('c');
    gateway.stream.add(
      event('message_end', {
        'message': message('assistant', [text('abc')], 1),
      }),
    );
    expect(contentChanges, 2);
    expect(stateChanges, 1);
    expect(chat.timeline.messages.single.text, 'abc');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(contentChanges, 2);
    // Missing message_start still moves an empty conversation into its
    // started layout, rather than notifying only an invisible timeline.
    chat.timeline.load([]);
    delta('fallback');
    expect(stateChanges, 2);
    expect(contentChanges, 3);
    expect(chat.timeline.messages.single.text, 'fallback');
  });

  test('thinking activity follows content events, not the whole reply', () {
    final timeline = ChatTimeline();
    timeline.apply(
      event('message_start', {'message': message('assistant', [], 1)}),
    );
    void delta(String type, int index) => timeline.apply(
      event('message_update', {
        'assistantMessageEvent': {
          'type': type,
          'contentIndex': index,
          'delta': 'content',
        },
      }),
    );
    expect(timeline.thinkingIndexFor(0), isNull);
    delta('thinking_start', 0);
    expect(timeline.thinkingIndexFor(0), 0);
    delta('thinking_delta', 0);
    expect(timeline.thinkingIndexFor(0), 0);
    delta('thinking_end', 0);
    expect(timeline.thinkingIndexFor(0), isNull);
    expect(timeline.messages.single.isStreaming, true);
    delta('thinking_start', 1);
    delta('thinking_end', 0); // A late end must not stop the next block.
    expect(timeline.thinkingIndexFor(0), 1);
    delta('text_start', 2); // Safe even if a thinking_end was omitted.
    expect(timeline.thinkingIndexFor(0), isNull);
    delta('thinking_delta', 3);
    expect(timeline.thinkingIndexFor(0), 3);
    delta('toolcall_start', 4);
    expect(timeline.thinkingIndexFor(0), isNull);
    timeline.apply(
      event('message_start', {'message': message('assistant', [], 2)}),
    );
    delta('thinking_delta', 0);
    expect(timeline.thinkingIndexFor(0), isNull);
    expect(timeline.thinkingIndexFor(1), 0);
  });

  test(
    'thinking activity clears on final messages, settle and history load',
    () {
      final timeline = ChatTimeline();
      void think() => timeline.apply(
        event('message_update', {
          'assistantMessageEvent': {
            'type': 'thinking_delta',
            'contentIndex': 0,
            'delta': 'checking',
          },
        }),
      );
      for (final reason in ['stop', 'aborted', 'error']) {
        think(); // Missing message_start uses the normal fallback projection.
        final index = timeline.messages.length - 1;
        expect(timeline.thinkingIndexFor(index), 0);
        timeline.apply(
          event('message_end', {
            'message': {
              ...message('assistant', [text('final')]),
              'stopReason': reason,
            },
          }),
        );
        expect(timeline.thinkingIndexFor(index), isNull);
      }
      think();
      timeline.apply(event('agent_settled'));
      expect(timeline.thinkingIndexFor(timeline.messages.length - 1), isNull);
      expect(timeline.messages.last.isStreaming, false);
      think();
      timeline.load([
        PiChatMessage.fromJson(
          message('assistant', [
            {'type': 'thinking', 'thinking': 'saved thinking'},
          ]),
        ),
      ]);
      expect(timeline.thinkingIndexFor(0), isNull);
      timeline.load([]);
      think();
      expect(timeline.thinkingIndexFor(0), 0);
    },
  );

  test(
    'assistant ordinals survive streaming, tool results and history reload',
    () {
      final orphan = PiChatMessage.fromJson({
        'role': 'toolResult',
        'toolCallId': 'orphan',
        'toolName': 'read',
        'content': [text('old output')],
      });
      final timeline = ChatTimeline()..load([orphan]);
      expect(timeline.messages.single.role, 'toolResult');
      expect(timeline.tools['orphan']!.result!.text, 'old output');
      expect(timeline.assistantNumbers, [null]);
      final user = message('user', 'question');
      timeline.apply(event('message_start', {'message': user}));
      timeline.apply(event('message_end', {'message': user}));
      final call = {
        'type': 'toolCall',
        'id': 'c1',
        'name': 'read',
        'arguments': {'path': 'a'},
      };
      final first = message('assistant', [call], 2);
      timeline.apply(
        event('message_start', {'message': message('assistant', [], 2)}),
      );
      expect(timeline.assistantNumbers, [null, null, 1]);
      timeline.apply(
        event('message_update', {
          'assistantMessageEvent': {
            'type': 'thinking_delta',
            'contentIndex': 0,
            'delta': 'checking',
          },
        }),
      );
      timeline.apply(event('message_end', {'message': first}));
      final result = {
        'role': 'toolResult',
        'toolCallId': 'c1',
        'toolName': 'read',
        'content': [text('output')],
      };
      timeline.apply(event('message_end', {'message': result}));
      expect(timeline.assistantNumbers, [null, null, 1]);
      final second = message('assistant', [text('answer')], 3);
      timeline.apply(event('message_start', {'message': second}));
      timeline.apply(event('message_end', {'message': second}));
      timeline.apply(event('agent_settled'));
      expect(timeline.assistantNumbers, [null, null, 1, 2]);
      timeline.load([
        orphan,
        ...[user, first, result, second].map(PiChatMessage.fromJson),
      ]);
      expect(timeline.assistantNumbers, [null, null, 1, 2]);
      timeline.load([]);
      timeline.apply(event('message_end', {'message': second}));
      expect(timeline.assistantNumbers, [1]);
    },
  );

  test(
    'images round trip through prompt, history and cumulative tool output',
    () async {
      const image = PiImage(data: 'aGVsbG8=', mimeType: 'image/png');
      final transport = TestTransport();
      final pi = PiRpcClient(transportFactory: () async => transport);
      addTearDown(pi.close);
      transport.onSend = (request) => transport.reply(request, null);
      await pi.prompt('', images: [image]);
      expect(transport.commands.single['images'], [image.toJson()]);
      expect(transport.commands.single['message'], '');
      final saved = PiChatMessage.fromJson(
        message('user', [image.toJson(), text('caption')]),
      );
      expect(saved.content.first.image!.toJson(), image.toJson());
      final timeline = ChatTimeline()..load([saved]);
      for (final content in [
        [image.toJson()],
        [text('done'), image.toJson()],
      ]) {
        timeline.apply(
          event('tool_execution_update', {
            'toolCallId': 'image-tool',
            'toolName': 'read',
            'partialResult': {'content': content},
          }),
        );
      }
      expect(timeline.tools['image-tool']!.result!.content.length, 2);
      expect(
        timeline.tools['image-tool']!.result!.content.last.image!.data,
        image.data,
      );
      expect(PiContent.fromJson({'type': 'image'}).image!.data, isEmpty);
      expect(
        PiModel.fromJson({
          'id': 'm',
          'provider': 'p',
          'reasoning': false,
          'input': ['text', 'image'],
        }).supportsImages,
        true,
      );
    },
  );

  test(
    'image-only sends preserve rejection and unsettled safety barriers',
    () async {
      final pi = FakeChatGateway();
      final chat = ChatController(pi);
      addTearDown(() async {
        chat.dispose();
        await pi.stream.close();
      });
      await chat.refresh();
      const images = [PiImage(data: 'encoded', mimeType: 'image/png')];
      expect(await chat.send(''), false);
      pi.pendingPrompt = Completer<void>();
      final sending = chat.send('', images: images);
      expect(pi.sentImages, images);
      expect(await chat.send('', images: images), false);
      pi.pendingPrompt!.completeError(const PiRpcException('Rejected'));
      expect(await sending, false);
      expect(chat.failure, ChatFailure.send);
      pi.pendingPrompt = Completer<void>();
      final processing = chat.send('', images: images);
      pi.pendingPrompt!.completeError(
        const PiRpcException('IMAGE_PREPROCESS_FAILED'),
      );
      expect(await processing, false);
      expect(chat.failure, ChatFailure.imageProcessing);
      expect(chat.canSend, true);
      expect(chat.timeline.messages, isEmpty);
      expect(pi.sentImages, images);
      pi.pendingPrompt = null;
      expect(await chat.send('', images: images), true);
      await tick();
      pi.hasUnsettledConversationMutation = true;
      expect(await chat.send('', images: images), false);
    },
  );

  test('ordered deltas assemble without snapshots; message_end replaces the live draft', () {
    final timeline = ChatTimeline();
    timeline.apply(event('message_start', {'message': message('user', '你好')}));
    timeline.apply(event('message_end', {'message': message('user', '你好')}));
    timeline.apply(
      event('message_start', {'message': message('assistant', [], 2)}),
    );
    void delta(String type, int index, Map<String, Object?> fields) =>
        timeline.apply(
          event('message_update', {
            'assistantMessageEvent': {
              'type': type,
              'contentIndex': index,
              ...fields,
            },
          }),
        );
    delta('thinking_delta', 0, {'delta': '分析'});
    delta('text_delta', 1, {'delta': '**中'});
    delta('text_delta', 1, {'delta': '文**\u2028😀'});
    delta('toolcall_start', 2, {'id': 'c1', 'toolName': 'edit'});
    delta('toolcall_delta', 2, {'delta': '{"path":'});
    final call = {
      'type': 'toolCall',
      'id': 'c1',
      'name': 'edit',
      'arguments': {'path': 'x.dart', 'edits': []},
    };
    delta('toolcall_end', 2, {'toolCall': call});
    expect(timeline.messages.length, 2);
    expect(timeline.messages.last.content.map((b) => b.kind), [
      PiContentKind.thinking,
      PiContentKind.text,
      PiContentKind.toolCall,
    ]);
    expect(timeline.messages.last.text, '**中文**\u2028😀');
    expect(timeline.tools['c1']!.path, 'x.dart');
    timeline.apply(
      event('message_end', {
        'message': message('assistant', [text('authoritative'), call], 2),
      }),
    );
    expect(timeline.messages.length, 2);
    expect(timeline.messages.last.text, 'authoritative');
    expect(timeline.messages.last.isStreaming, false);
  });

  test('tool reference index tracks replacement, duplicate references and orphan resets', () {
    Map<String, dynamic> call(String id) => {
      'type': 'toolCall',
      'id': id,
      'name': 'read',
      'arguments': {'path': id},
    };
    Map<String, dynamic> result(String id) => {
      'role': 'toolResult',
      'toolCallId': id,
      'toolName': 'read',
      'content': [text('result')],
    };
    final timeline = ChatTimeline();
    timeline.load([
      PiChatMessage.fromJson(message('assistant', [call('shared')])),
    ]);
    timeline.apply(
      event('message_start', {
        'message': message('assistant', [call('shared'), call('removed')], 2),
      }),
    );
    timeline.apply(
      event('message_end', {
        'message': message('assistant', [text('authoritative')], 2),
      }),
    );
    timeline.apply(event('message_end', {'message': result('shared')}));
    expect(
      timeline.messages.length,
      2,
    ); // The earlier shared reference remains.
    timeline.apply(event('message_end', {'message': result('removed')}));
    timeline.apply(event('message_end', {'message': result('removed')}));
    expect(
      timeline.messages.length,
      3,
    ); // Removed draft becomes exactly one orphan.
    expect(timeline.messages.last.role, 'toolResult');
    timeline.load([]);
    timeline.apply(event('message_end', {'message': result('shared')}));
    expect(timeline.messages.single.role, 'toolResult');
    timeline.load([]);
    timeline.apply(
      event('message_start', {
        'message': message('assistant', [call('delta')]),
      }),
    );
    timeline.apply(
      event('message_update', {
        'assistantMessageEvent': {'type': 'text_start', 'contentIndex': 0},
      }),
    );
    timeline.apply(event('message_end', {'message': result('delta')}));
    expect(
      timeline.messages.length,
      2,
    ); // Block replacement also drops its reference.
    expect(timeline.messages.last.toolCallId, 'delta');
    expect(timeline.assistantNumbers, [1, null]);
  });

  test('tool output is accumulated replacement; final result correlates once and history restores diff', () {
    final timeline = ChatTimeline();
    const patch = '--- a\n+++ a\n@@ -1 +1 @@\n-old\n+new\n';
    final call = {
      'type': 'toolCall',
      'id': 'c1',
      'name': 'edit',
      'arguments': {'path': 'a'},
    };
    timeline.load([
      PiChatMessage.fromJson(message('assistant', [call])),
    ]);
    for (final output in ['a', 'ab']) {
      timeline.apply(
        event('tool_execution_update', {
          'toolCallId': 'c1',
          'toolName': 'edit',
          'partialResult': {
            'content': [text(output)],
          },
        }),
      );
    }
    expect(timeline.tools['c1']!.result!.text, 'ab');
    timeline.apply(
      event('tool_execution_end', {
        'toolCallId': 'c1',
        'result': {
          'content': [text('done')],
          'details': {'patch': patch},
        },
        'isError': false,
      }),
    );
    final result = PiChatMessage.fromJson({
      'role': 'toolResult',
      'toolCallId': 'c1',
      'toolName': 'edit',
      'content': [text('done')],
      'timestamp': 2,
    });
    timeline.apply(
      event('message_end', {
        'message': {
          'role': 'toolResult',
          'toolCallId': 'c1',
          'content': [text('done')],
          'details': {'patch': patch},
        },
      }),
    );
    timeline.load([
      PiChatMessage.fromJson(message('assistant', [call])),
      result,
    ]);
    expect(timeline.tools['c1']!.result!.patch, patch);
    expect(timeline.tools['c1']!.isFileChange, true);
    expect(timeline.messages.length, 1);
    timeline.apply(
      event('tool_execution_end', {
        'toolCallId': 'c1',
        'result': {'content': []},
        'isError': true,
      }),
    );
    expect(timeline.tools['c1']!.isFileChange, false);
  });

  test('unified diff excludes file headers, keeps real +++ content, and numbers multiple hunks', () {
    final doc = DiffDocument(
      '--- a\r\n+++ b\r\n@@ -3,2 +3,2 @@\r\n-old\r\n+++new\r\n same\r\n@@ -10 +12 @@\r\n-x\r\n+y\r\n\\ No newline at end of file\r\n',
    );
    expect(doc.added, 2);
    expect(doc.removed, 2);
    expect(
      doc.lines.firstWhere((l) => l.kind == DiffLineKind.added).text,
      '++new',
    );
    expect(
      doc.lines.where((l) => l.kind == DiffLineKind.added).last.newLine,
      12,
    );
    final numbered = DiffDocument(
      '-12 old\n+12 new\n 13 same\n    ...',
      numbered: true,
    );
    expect(numbered.added, 1);
    expect(numbered.removed, 1);
    expect(numbered.lines[1].newLine, 12);
    expect(doc.displayLines.length, doc.lines.length - 2);
    expect(
      doc.displayLines
          .where((line) => line.kind == DiffLineKind.added)
          .first
          .text,
      '++new',
    );
    final written = DiffDocument.written(
      '--- literal content\r\n\r\n+not an addition\r\n',
    );
    expect(written.displayLines.length, 3);
    expect(written.added, 0);
    expect(written.removed, 0);
    expect(written.lines.map((line) => line.newLine), [1, 2, 3]);
    expect(written.lines.every((line) => line.oldLine == null), true);
    expect(DiffDocument.written('').lines, isEmpty);
  });

  test('write patch survives live events and persisted history without changing tool output', () {
    const patch = '--- note.txt\n+++ note.txt\n@@ -1 +1 @@\n-before\n+after\n';
    final details = {
      'patch': patch,
      'guiWrite': {'kind': 'modified'},
      'custom': 42,
    };
    final call = {
      'type': 'toolCall',
      'id': 'write-1',
      'name': 'write',
      'arguments': {'path': 'note.txt', 'content': 'after\n'},
    };
    final result = {
      'role': 'toolResult',
      'toolCallId': 'write-1',
      'toolName': 'write',
      'content': [text('Successfully wrote to note.txt')],
      'details': details,
    };
    final timeline = ChatTimeline()
      ..load([
        PiChatMessage.fromJson(message('assistant', [call])),
      ]);
    timeline.apply(
      event('tool_execution_end', {
        'toolCallId': 'write-1',
        'toolName': 'write',
        'result': result,
        'isError': false,
      }),
    );
    expect(timeline.tools['write-1']!.result!.patch, patch);
    timeline.load([
      PiChatMessage.fromJson(message('assistant', [call])),
      PiChatMessage.fromJson(result),
    ]);
    final restored = timeline.tools['write-1']!;
    expect(restored.isFileChange, true);
    expect(restored.result!.text, 'Successfully wrote to note.txt');
    expect(restored.result!.details, details);
    expect(restored.result!.writeKind, PiWriteKind.modified);
    expect(
      PiToolResult.fromJson({
        'details': {'guiWrite': 'unknown'},
      }).writeKind,
      isNull,
    );
    expect(DiffDocument(restored.result!.patch!).added, 1);
    expect(DiffDocument(restored.result!.patch!).removed, 1);
  });

  test('RPC prompt ack is not completion; typed deltas, invalid-event isolation, queue and cancel responses', () async {
    final transport = TestTransport();
    final pi = PiRpcClient(transportFactory: () async => transport);
    addTearDown(pi.close);
    final events = <PiRpcEvent>[];
    final sub = pi.events.listen(events.add);
    addTearDown(sub.cancel);
    transport.onSend = (request) {
      switch (request['type']) {
        case 'prompt':
          transport.reply(request, null);
          transport.emit({
            'type': 'message_update',
            'assistantMessageEvent': {
              'type': 'text_delta',
              'contentIndex': -1,
              'delta': 'invalid',
            },
          });
          transport.emit({
            'type': 'message_update',
            'assistantMessageEvent': {
              'type': 'text_delta',
              'contentIndex': 0,
              'delta': 'valid',
            },
          });
        case 'clear_queue':
          transport.reply(request, {
            'steering': ['s'],
            'followUp': ['f'],
          });
        case 'new_session':
          transport.reply(request, {'cancelled': true});
        case 'get_messages':
          transport.reply(request, {
            'messages': [
              message('user', [text('saved')]),
            ],
          });
      }
    };
    await pi.prompt('hello\nworld');
    await tick();
    expect(transport.commands.single['message'], 'hello\nworld');
    expect(events.whereType<PiChatEvent>().single.delta!.delta, 'valid');
    expect(
      events.whereType<PiRpcDiagnostic>().single.kind,
      PiRpcDiagnosticKind.invalidEvent,
    );
    expect(pi.isConnected, true);
    expect((await pi.clearQueue()).all, ['s', 'f']);
    expect(await pi.newSession(), false);
    expect((await pi.getMessages()).single.text, 'saved');
  });

  test('timed-out prompt blocks replay but permits stop/read until late acknowledgement', () async {
    final transport = TestTransport();
    final pi = PiRpcClient(
      transportFactory: () async => transport,
      requestTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(pi.close);
    await expectLater(
      pi.prompt('once'),
      throwsA(
        isA<PiRpcException>().having(
          (e) => e.outcomeUnknown,
          'uncertain',
          true,
        ),
      ),
    );
    final first = transport.commands.single;
    expect(pi.hasUnsettledConversationMutation, true);
    transport.onSend = (request) => transport.reply(
      request,
      request['type'] == 'get_messages' ? {'messages': []} : null,
    );
    await pi.abort();
    await pi.getMessages();
    expect(transport.commands.map((c) => c['type']), [
      'prompt',
      'abort',
      'get_messages',
    ]);
    transport.reply(first, null);
    await tick();
    expect(pi.hasUnsettledConversationMutation, false);
    expect(pi.connectionCount, 1);
  });

  test('malformed prompt acknowledgement retains the safety barrier; stop bypasses selection writes', () async {
    final transport = TestTransport();
    final pi = PiRpcClient(transportFactory: () async => transport);
    addTearDown(pi.close);
    transport.onSend = (request) => transport.emit({
      'id': request['id'],
      'type': 'response',
      'command': 'wrong',
      'success': true,
    });
    await expectLater(
      pi.prompt('only once'),
      throwsA(
        isA<PiRpcException>().having(
          (e) => e.outcomeUnknown,
          'outcome unknown',
          true,
        ),
      ),
    );
    expect(pi.hasUnsettledConversationMutation, true);
    final prompt = transport.commands.single;
    transport.reply(prompt, null);
    await tick();
    expect(pi.hasUnsettledConversationMutation, false);
    transport.onSend = null;
    final selecting = pi.setThinkingLevel(PiThinkingLevel.low);
    await tick();
    final selection = transport.commands.last;
    transport.onSend = (request) =>
        transport.reply(request, {'steering': [], 'followUp': []});
    await pi.clearQueue();
    await pi.abort();
    transport.reply(selection, null);
    await selecting;
    expect(transport.commands.where((c) => c['type'] == 'prompt').length, 1);
  });

  test('empty reconnect skips nonexistent session files; a failed read still permits an explicit new session', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    await chat.refresh();
    pi.stream.add(const PiRpcDisconnected());
    pi.stream.add(const PiRpcConnected());
    await tick();
    expect(pi.commands.where((c) => c.startsWith('switch_session:')), isEmpty);
    pi.pendingHistory = Completer<List<PiChatMessage>>();
    final refresh = chat.refresh();
    await tick();
    pi.pendingHistory!.completeError(const PiRpcException('Missing session'));
    await refresh;
    expect(chat.canSend, false);
    expect(chat.canSwitch, true);
    pi.pendingHistory = null;
    expect(await chat.changeSession(), true);
    expect(chat.timeline.messages, isEmpty);
    expect(chat.canSend, true);
  });

  test('controller holds busy through agent_end/retry, refresh keeps live deltas, stops queue first', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    await chat.refresh();
    pi.pendingPrompt = Completer<void>();
    final sending = chat.send('one');
    expect(await chat.send('duplicate'), false);
    pi.stream.add(event('agent_start'));
    pi.stream.add(
      event('message_start', {'message': message('assistant', [], 3)}),
    );
    pi.stream.add(
      event('message_update', {
        'assistantMessageEvent': {
          'type': 'text_delta',
          'contentIndex': 0,
          'delta': 'live',
        },
      }),
    );
    pi.pendingPrompt!.complete();
    expect(await sending, true);
    pi.stream.add(event('agent_end', {'willRetry': true}));
    pi.stream.add(event('auto_retry_start'));
    await chat.refresh();
    expect(chat.activity, ChatActivity.retrying);
    expect(chat.timeline.messages.last.text, 'live');
    expect(chat.canSend, false);
    expect(await chat.stop(), ['next']);
    expect(
      pi.commands.indexOf('clear_queue'),
      lessThan(pi.commands.indexOf('abort')),
    );
    await tick();
    expect(chat.activity, ChatActivity.idle);
  });

  test('history hydration racing deltas cannot overwrite live content; settled re-syncs', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    pi.pendingHistory = Completer<List<PiChatMessage>>();
    final loading = chat.refresh();
    await tick();
    pi.stream.add(event('agent_start'));
    pi.stream.add(
      event('message_start', {'message': message('assistant', [], 1)}),
    );
    pi.stream.add(
      event('message_update', {
        'assistantMessageEvent': {
          'type': 'text_delta',
          'contentIndex': 0,
          'delta': 'new',
        },
      }),
    );
    pi.pendingHistory!.complete([]);
    await loading;
    expect(chat.timeline.messages.last.text, 'new');
    pi.pendingHistory = null;
    pi.history = [
      PiChatMessage.fromJson(message('assistant', [text('final')])),
    ];
    pi.stream.add(event('agent_settled'));
    await tick();
    expect(chat.timeline.messages.single.text, 'final');
    expect(chat.canSend, true);
  });

  test('complete live runs only refresh metadata, including acknowledgement after settled', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    await chat.refresh();
    pi.pendingPrompt = Completer<void>();
    final sending = chat.send('once');
    final finalMessage = message('assistant', [text('kept live')]);
    pi.stream.add(event('agent_start'));
    pi.stream.add(
      event('message_start', {'message': message('assistant', [])}),
    );
    pi.stream.add(event('message_end', {'message': finalMessage}));
    pi.stream.add(event('agent_end'));
    expect(chat.canSend, false);
    pi.stream.add(event('agent_settled'));
    // The saved fixture stays empty: a redundant snapshot would erase the live reply.
    pi.pendingPrompt!.complete();
    expect(await sending, true);
    await tick();
    expect(chat.timeline.messages.single.text, 'kept live');
    expect(pi.commands.where((c) => c == 'get_messages').length, 1);
    expect(pi.commands.where((c) => c == 'get_state').length, 2);
    expect(chat.canSend, true);
    expect(pi.commands.where((c) => c.startsWith('prompt:')).length, 1);

    // A command handled by an extension without an agent run still reads history.
    pi.pendingPrompt = null;
    pi.history = [PiChatMessage.fromJson(message('user', 'extension result'))];
    expect(await chat.send('/custom'), true);
    await tick();
    expect(chat.timeline.messages.single.text, 'extension result');
    expect(pi.commands.where((c) => c == 'get_messages').length, 2);
  });

  test('changed branches, bad events and incomplete content force authoritative history', () async {
    for (final reason in [
      'compaction',
      'retry',
      'invalid',
      'missing_end',
      'missing_tool_end',
    ]) {
      final pi = FakeChatGateway();
      final chat = ChatController(pi);
      try {
        await chat.refresh();
        pi.stream.add(event('agent_start'));
        pi.stream.add(
          event('message_start', {
            'message': message('assistant', [text('draft')]),
          }),
        );
        if (reason != 'missing_end') {
          pi.stream.add(
            event('message_end', {
              'message': message('assistant', [text('old')]),
            }),
          );
        }
        if (reason == 'compaction') {
          pi.stream.add(event('compaction_start'));
          pi.stream.add(event('compaction_end'));
        }
        if (reason == 'retry') {
          pi.stream.add(event('auto_retry_start'));
          pi.stream.add(event('auto_retry_end'));
        }
        if (reason == 'missing_tool_end') {
          pi.stream.add(
            event('tool_execution_start', {
              'toolCallId': 'unfinished',
              'toolName': 'read',
              'args': {'path': 'a'},
            }),
          );
        }
        if (reason == 'invalid') {
          pi.stream.add(
            const PiRpcDiagnostic(
              PiRpcDiagnosticKind.invalidEvent,
              command: 'message_end',
            ),
          );
        }
        pi.history = [
          PiChatMessage.fromJson(message('assistant', [text('saved')])),
        ];
        pi.stream.add(event('agent_settled'));
        await tick();
        expect(chat.timeline.messages.single.text, 'saved', reason: reason);
        expect(
          pi.commands.where((c) => c == 'get_messages').length,
          2,
          reason: reason,
        );
        expect(chat.canSend, true);
      } finally {
        chat.dispose();
        await pi.stream.close();
      }
    }
  });

  test('explicit refresh queued behind metadata retains authoritative history intent', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    await chat.refresh();
    pi.pendingState = Completer<PiSessionState>();
    pi.stream.add(event('agent_settled'));
    await tick();
    await chat
        .refresh(); // Mark the in-flight metadata read as needing history.
    pi.history = [
      PiChatMessage.fromJson(message('assistant', [text('authoritative')])),
    ];
    pi.pendingState!.complete(pi.state);
    pi.pendingState = null;
    await tick();
    expect(chat.timeline.messages.single.text, 'authoritative');
    expect(chat.canSend, true);
    expect(
      pi.commands.where((c) => c == 'get_messages').length,
      greaterThan(1),
    );
  });

  test('diff memo shares one parse and invalidates source, format and neutral write mode', () {
    final memo = DiffDocumentMemo();
    const source = '-1 before\n+1 after\n';
    final numbered = memo.resolve(source, numbered: true);
    expect(numbered.added, 1);
    expect(numbered.removed, 1);
    expect(memo.resolve(source, numbered: true), same(numbered));
    expect(memo.resolve(source), isNot(same(numbered)));
    final written = memo.resolve(source, written: true);
    expect(written.added, 0);
    expect(written.removed, 0);
    expect(written.lines.map((line) => line.newLine), [1, 2]);
    expect(memo.resolve(source, written: true), same(written));
    expect(memo.resolve('new', written: true).lines.single.text, 'new');
    memo.clear();
    expect(memo.resolve(source, written: true), isNot(same(written)));
  });

  test('cancelled session switch preserves history; reconnect restores saved session without replay', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    pi.history = [PiChatMessage.fromJson(message('user', 'persisted'))];
    await chat.refresh();
    pi.cancelled = true;
    expect(await chat.changeSession(), false);
    expect(chat.timeline.messages.single.text, 'persisted');
    pi.cancelled = false;
    pi.stream.add(const PiRpcDisconnected());
    pi.stream.add(const PiRpcConnected());
    await tick();
    expect(pi.commands, contains('switch_session:/first.jsonl'));
    expect(pi.commands.where((c) => c.startsWith('prompt:')), isEmpty);
    expect(chat.isReady, true);
  });

  test('output budget releases the oldest settled tools, keeps previews, skips running and pinned', () {
    Map<String, dynamic> call(String id, [String name = 'read']) => {
      'type': 'toolCall',
      'id': id,
      'name': name,
      'arguments': name == 'write'
          ? {'path': id, 'content': 'BIG' * 2000}
          : {'path': id},
    };
    Map<String, dynamic> result(String id, String body) => {
      'role': 'toolResult',
      'toolCallId': id,
      'toolName': 'read',
      'content': [text(body)],
    };
    final big = 'x' * 6000;
    final timeline = ChatTimeline();
    timeline.load([
      PiChatMessage.fromJson(message('assistant', [call('old')], 1)),
      PiChatMessage.fromJson(message('assistant', [call('pinned')], 2)),
      PiChatMessage.fromJson(message('assistant', [call('write', 'write')], 3)),
    ]);
    timeline.apply(event('message_end', {'message': result('old', big)}));
    timeline.apply(event('message_end', {'message': result('pinned', big)}));
    timeline.apply(
      event('message_end', {
        'message': {
          'role': 'toolResult',
          'toolCallId': 'write',
          'toolName': 'write',
          'content': [text('ok')],
          'details': {
            'patch': '--- a\n+++ b\n@@ -1 +1 @@\n-old\n+new\n',
            'guiWrite': {'kind': 'modified'},
          },
        },
      }),
    );
    // Still running: never released by the budget.
    timeline.apply(
      event('tool_execution_start', {'toolCallId': 'live', 'toolName': 'read'}),
    );
    timeline.applyOutputBudget(0, pinned: {'pinned'});
    final released = timeline.tools['old']!;
    expect(released.evicted, true);
    expect(released.result!.text.length, 2000);
    expect(released.result!.text, big.substring(0, 2000));
    expect(timeline.tools['pinned']!.evicted, false);
    expect(timeline.tools['live']!.evicted, false);
    expect(timeline.tools['live']!.phase, ToolPhase.running);
    final write = timeline.tools['write']!;
    expect(write.evicted, true);
    expect(write.result!.patch, null);
    expect(write.result!.details!.containsKey('patch'), false);
    expect(write.writtenContent, null);
    // Small identity arguments survive so the title stays meaningful.
    expect(write.path, 'write');
    // Idempotent: released previews are not counted or re-processed.
    timeline.applyOutputBudget(0, pinned: {'pinned'});
    expect(timeline.tools['old']!.result!.text.length, 2000);
  });

  test('output budget releases orphan result copies held by messages', () {
    final timeline = ChatTimeline();
    final big = 'y' * 5000;
    timeline.load([]);
    timeline.apply(
      event('message_end', {
        'message': {
          'role': 'toolResult',
          'toolCallId': 'orphan',
          'toolName': 'read',
          'content': [text(big)],
        },
      }),
    );
    expect(timeline.messages.single.result!.text, big);
    timeline.applyOutputBudget(0);
    expect(timeline.tools['orphan']!.evicted, true);
    expect(timeline.messages.single.result!.text.length, 2000);
  });

  test('reloadToolOutput restores a released row through a history read and pins it', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi, outputBudget: 12000);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    Map<String, dynamic> call(String id) => {
      'type': 'toolCall',
      'id': id,
      'name': 'read',
      'arguments': {'path': id},
    };
    final big = 'z' * 4000;
    pi.history = [
      PiChatMessage.fromJson(message('assistant', [call('a')], 1)),
      PiChatMessage.fromJson(message('assistant', [call('b')], 2)),
      PiChatMessage.fromJson({
        'role': 'toolResult',
        'toolCallId': 'a',
        'toolName': 'read',
        'content': [text(big)],
        'timestamp': 3,
      }),
      PiChatMessage.fromJson({
        'role': 'toolResult',
        'toolCallId': 'b',
        'toolName': 'read',
        'content': [text(big)],
        'timestamp': 4,
      }),
    ];
    await chat.refresh();
    expect(chat.timeline.tools['a']!.evicted, true);
    expect(chat.timeline.tools['b']!.evicted, false);
    await chat.reloadToolOutput('a');
    expect(pi.commands.where((c) => c == 'get_messages').length, 2);
    expect(pi.commands.where((c) => c.startsWith('prompt:')), isEmpty);
    expect(chat.timeline.tools['a']!.evicted, false);
    expect(chat.timeline.tools['a']!.result!.text, big);
    // The pinned reload pushed the next oldest unpinned row out instead.
    expect(chat.timeline.tools['b']!.evicted, true);
    // Collapsing the row releases the pin; the next read can release it too.
    chat.pinToolOutput('a', false);
    await chat.refresh();
    expect(chat.timeline.tools['a']!.evicted, true);
  });

  test('settling applies the output budget to live tool results', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi, outputBudget: 0);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    final big = 'w' * 6000;
    // The first settled refresh is the authoritative read: it rebuilds the
    // timeline from history and must apply the budget to what it loaded.
    pi.history = [
      PiChatMessage.fromJson(
        message('assistant', [
          {
            'type': 'toolCall',
            'id': 'live',
            'name': 'read',
            'arguments': {'path': 'p'},
          },
        ], 1),
      ),
      PiChatMessage.fromJson({
        'role': 'toolResult',
        'toolCallId': 'live',
        'toolName': 'read',
        'content': [text(big)],
        'timestamp': 2,
      }),
    ];
    pi.stream.add(event('agent_start'));
    pi.stream.add(
      event('tool_execution_end', {
        'toolCallId': 'live',
        'result': {
          'content': [text(big)],
        },
      }),
    );
    pi.stream.add(event('agent_settled'));
    await tick();
    await tick();
    expect(chat.timeline.tools['live']!.evicted, true);
    expect(chat.timeline.tools['live']!.result!.text.length, 2000);
    expect(pi.commands.where((c) => c.startsWith('prompt:')), isEmpty);
  });
}
