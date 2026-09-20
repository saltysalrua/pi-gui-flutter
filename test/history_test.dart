import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_channel_hub.dart';
import 'package:pi_gui/ui/features/home/controllers/workbench_controller.dart';

import 'parallel_session_test.dart' show reply;

import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_history_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/features/home/controllers/history_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport;

Map<String, Object?> entry(
  String id,
  String? parent,
  String role,
  String text,
) => {
  'id': id,
  'parentId': parent,
  'type': 'message',
  'timestamp': '2026-09-20T00:00:00Z',
  'message': {
    'role': role,
    'content': text,
    'timestamp': id.hashCode,
    'stopReason': 'stop',
  },
};
final historyEntries = [
  entry('u1', null, 'user', 'root'),
  entry('a1', 'u1', 'assistant', 'answer'),
  entry('u2', 'a1', 'user', 'old prompt'),
  entry('a2', 'u2', 'assistant', 'old answer'),
  entry('u3', 'a1', 'user', 'alternative'),
  entry('a3', 'u3', 'assistant', 'new answer'),
  {
    'id': 'compact',
    'parentId': 'a3',
    'type': 'compaction',
    'summary': 'kept facts',
    'firstKeptEntryId': 'u3',
    'tokensBefore': 500,
  },
  {
    'id': 'label',
    'parentId': 'compact',
    'type': 'label',
    'targetId': 'a2',
    'label': 'bookmark',
    'timestamp': '2026-09-20T01:00:00Z',
  },
];
PiHistorySnapshot snapshot() => PiHistorySnapshot(
  sessionId: 'session',
  sessionFile: '/history.jsonl',
  data: {'entries': historyEntries, 'leafId': 'compact'},
);

class FakeHistory implements PiHistoryGateway {
  Future<PiHistoryResult> Function()? perform;
  final previews = <String, Completer<Map<String, dynamic>>>{};
  bool delayed = false;
  int mutations = 0;
  @override
  Future<PiHistorySnapshot> load() async => snapshot();
  @override
  Future<Map<String, dynamic>> entry(
    PiHistorySnapshot snapshot,
    String id,
  ) async {
    if (delayed) return (previews[id] = Completer()).future;
    return Map<String, dynamic>.from(
      historyEntries.firstWhere((e) => e['id'] == id),
    );
  }

  @override
  Future<PiHistoryResult> act(
    PiHistorySnapshot snapshot,
    PiHistoryAction action, {
    String? entryId,
    bool summarize = false,
    String? instructions,
    bool replaceInstructions = false,
  }) async {
    mutations++;
    return perform == null
        ? PiHistoryResult.fromJson({
            'cancelled': false,
            'editorText': 'restored',
          })
        : perform!();
  }

  @override
  Future<void> label(
    PiHistorySnapshot snapshot,
    String id,
    String label,
  ) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native fork retains its channel, reopens the source once, and preserves sibling and newer drafts', () async {
    final transport = TestTransport();
    final workbench = WorkbenchController(
      hub: PiChannelHub(() async => transport),
    );
    addTearDown(() async {
      await workbench.shutdown();
      workbench.dispose();
    });
    final channels = <Map<String, Object?>>[
      {
        'id': 'source',
        'workspace': '/h',
        'sessionFile': '/h/source.jsonl',
        'status': 'ready',
      },
      {
        'id': 'sibling',
        'workspace': '/h',
        'sessionFile': '/h/sibling.jsonl',
        'status': 'ready',
      },
    ];
    Map<String, dynamic>? navigation;
    transport.onSend = (packet) {
      final q = packet['message'] as Map<String, dynamic>;
      final channel = channels
          .where((c) => c['id'] == packet['channel'])
          .firstOrNull;
      Object? data;
      switch (q['type']) {
        case 'gui_get_catalog':
          data = {
            'projects': <Object>[],
            'channels': channels,
            'jobs': <Object>[],
          };
        case 'gui_workspace_history':
          data = {'sessions': <Object>[]};
        case 'gui_open_channel':
          final newChannel = <String, Object?>{
            'id': q['channelId'],
            'workspace': '/h',
            'sessionFile': q['sessionPath'],
            'status': 'ready',
          };
          channels.add(newChannel);
          data = newChannel;
        case 'gui_close_channel':
          channels.removeWhere((c) => c['id'] == q['channelId']);
          data = <String, Object?>{};
        case 'get_state':
          data = {
            'sessionId': channel!['sessionFile'],
            'sessionFile': channel['sessionFile'],
            'model': null,
            'thinkingLevel': 'off',
          };
        case 'get_messages':
          data = {'messages': <Object>[]};
        case 'get_available_models':
          data = {'models': <Object>[]};
        case 'get_available_thinking_levels':
          data = {
            'levels': ['off'],
          };
        case 'get_entries':
          data = {'entries': historyEntries, 'leafId': 'compact'};
        case 'gui_history_entry':
          data = {
            'entry': historyEntries.firstWhere((e) => e['id'] == q['entryId']),
          };
        case 'gui_history_fork':
          channel!['sessionFile'] = '/h/fork.jsonl';
          data = {'cancelled': false, 'editorText': 'alternative'};
        case 'gui_history_navigate':
          navigation = packet;
          return;
        default:
          throw StateError('Unexpected command ${q['type']}');
      }
      reply(transport, packet, data);
    };
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    await workbench.initialize();
    await settle();
    final source = workbench.sessions['source']!,
        sibling = workbench.sessions['sibling']!;
    sibling.input.text = 'keep sibling';
    source.input.text = 'confirmed replacement';
    final client = source.client;
    workbench.tabs.activate(source.document);
    await source.history.open();
    await source.history.select('u3');
    expect(await source.history.act(PiHistoryAction.fork), true);
    await settle();
    expect(source.client, same(client));
    expect(source.chat.sessionFile, '/h/fork.jsonl');
    expect(source.historyPath, '/h/fork.jsonl');
    expect(source.input.text, 'alternative');
    expect(workbench.sessions.length, 3);
    expect(
      workbench.sessions.values
          .where((s) => s.chat.sessionFile == '/h/source.jsonl')
          .length,
      1,
    );
    expect(workbench.tabs.selected, source.document);
    expect(sibling.input.text, 'keep sibling');
    await source.history.select('u1');
    final navigating = source.history.act(PiHistoryAction.navigate);
    await settle();
    source.input.text = 'typed after confirmation';
    reply(transport, navigation!, {
      'cancelled': false,
      'editorText': 'restored prompt',
      'images': [
        {'type': 'image', 'data': 'aGVsbG8=', 'mimeType': 'image/png'},
      ],
    });
    expect(await navigating, true);
    expect(source.input.text, 'typed after confirmation');
    expect(source.pendingHistoryDraft?.text, 'restored prompt');
    source.restoreHistoryDraft();
    expect(source.input.text, 'restored prompt');
    expect(source.attachments.items.single.image.data, 'aGVsbG8=');
    expect(
      transport.commands.where((p) => p['message']['type'] == 'prompt'),
      isEmpty,
    );
  });
  test('append-only tree preserves abandoned and compacted history, labels, filtering and folds', () {
    final tree = snapshot();
    expect(tree.activePath, {'compact', 'a3', 'u3', 'a1', 'u1'});
    expect(tree.rows(PiHistoryFilter.standard, '', {}).map((e) => e.entry.id), [
      'u1',
      'a1',
      'u3',
      'a3',
      'compact',
      'u2',
      'a2',
    ]);
    expect(tree.rows(PiHistoryFilter.userOnly, '', {}).map((e) => e.entry.id), [
      'u1',
      'u3',
      'u2',
    ]);
    expect(
      tree.rows(PiHistoryFilter.labeledOnly, '', {}).single.entry.id,
      'a2',
    );
    expect(
      tree.rows(PiHistoryFilter.all, 'old answer', {}).single.entry.id,
      'a2',
    );
    expect(
      tree.rows(PiHistoryFilter.standard, '', {'a1'}).map((e) => e.entry.id),
      ['u1', 'a1'],
    );
    // Search reveals a hidden branch without changing the actual leaf.
    expect(tree.rows(PiHistoryFilter.standard, 'old', {'a1'}).length, 2);
    expect(tree.leafId, 'compact');
    final cleared = PiHistorySnapshot(
      sessionId: 's',
      sessionFile: null,
      data: {
        'entries': [
          ...historyEntries,
          {
            'id': 'unlabel',
            'type': 'label',
            'parentId': 'compact',
            'targetId': 'a2',
          },
        ],
        'leafId': null,
      },
    );
    expect(cleared.rows(PiHistoryFilter.labeledOnly, '', {}), isEmpty);
    expect(cleared.activePath, isEmpty);
    expect(
      PiChatMessage.fromJson({
        'role': 'compactionSummary',
        'summary': 'kept facts',
      }).text,
      'kept facts',
    );
  });
  test('long linear history stays flat and stack-safe, orphan nodes remain browseable', () {
    final tree = PiHistorySnapshot(
      sessionId: 's',
      sessionFile: null,
      data: {
        'entries': [
          for (var i = 0; i < 6000; i++)
            entry('$i', i == 0 ? null : '${i - 1}', 'user', 'turn $i'),
          entry('orphan', 'missing', 'user', 'orphan'),
        ],
        'leafId': '5999',
      },
    );
    final rows = tree.rows(PiHistoryFilter.all, '', {});
    expect(rows.length, 6001);
    expect(rows.every((r) => r.depth == 0), true);
  });
  test(
    'out-of-order preview responses never replace the selected node',
    () async {
      final api = FakeHistory(),
          events = StreamController<PiRpcEvent>.broadcast();
      final controller = HistoryController(
        api,
        events: events.stream,
        canMutate: () => true,
        onLock: (_) {},
        onCommitted: (_, _, _) async {},
      );
      await controller.open();
      api.delayed = true;
      final a = controller.select('u2'), b = controller.select('u3');
      api.previews['u3']!.complete({'id': 'u3'});
      await b;
      api.previews['u2']!.complete({'id': 'u2'});
      await a;
      expect(controller.preview!['id'], 'u3');
      controller.dispose();
      await events.close();
    },
  );
  test('cancellation preserves draft; fork permits abandoned user nodes but rejects non-user nodes', () async {
    final api = FakeHistory(),
        events = StreamController<PiRpcEvent>.broadcast();
    api.perform = () async => PiHistoryResult.fromJson({'cancelled': true});
    var commits = 0;
    final controller = HistoryController(
      api,
      events: events.stream,
      canMutate: () => true,
      onLock: (_) {},
      onCommitted: (_, _, _) async {
        commits++;
      },
    );
    await controller.open();
    await controller.select('a2');
    expect(await controller.act(PiHistoryAction.fork), false);
    expect(api.mutations, 0);
    await controller.select('u2');
    expect(await controller.act(PiHistoryAction.fork), false);
    expect(api.mutations, 1);
    expect(await controller.act(PiHistoryAction.navigate), false);
    expect(commits, 0);
    expect(controller.busy, false);
    expect(controller.failure, 'HISTORY_CANCELLED');
    controller.dispose();
    await events.close();
  });
  test('timed-out mutation stays locked and applies a late acknowledgement exactly once', () async {
    final api = FakeHistory(),
        events = StreamController<PiRpcEvent>.broadcast();
    api.perform = () async =>
        throw const PiRpcException('timeout', outcomeUnknown: true);
    final committed = <String>[];
    var locked = false;
    final controller = HistoryController(
      api,
      events: events.stream,
      canMutate: () => !locked,
      onLock: (v) {
        locked = v;
      },
      onCommitted: (r, _, _) async {
        committed.add(r.text);
      },
    );
    await controller.open();
    await controller.select('u1');
    expect(await controller.act(PiHistoryAction.navigate), false);
    expect(locked, true);
    expect(controller.uncertain, true);
    expect(await controller.act(PiHistoryAction.navigate), false);
    expect(api.mutations, 1);
    const ack = PiAgentEvent('gui_history_settled', {
      'success': true,
      'data': {'cancelled': false, 'editorText': 'root'},
    });
    events.add(ack);
    await Future<void>.delayed(Duration.zero);
    events.add(ack);
    await Future<void>.delayed(Duration.zero);
    expect(committed, ['root']);
    expect(locked, false);
    expect(controller.busy, false);
    controller.dispose();
    await events.close();
  });
  test('RPC history mutation barrier permits abort but prevents prompt replay after a timeout', () async {
    final transport = TestTransport();
    final client = PiRpcClient(
      transportFactory: () async => transport,
      requestTimeout: const Duration(milliseconds: 20),
    );
    final events = <PiRpcEvent>[];
    client.events.listen(events.add);
    await expectLater(
      client.requestGui('gui_history_navigate', {'entryId': 'u'}),
      throwsA(
        isA<PiRpcException>().having((e) => e.outcomeUnknown, 'unknown', true),
      ),
    );
    final pending = transport.commands.single;
    transport.onSend = (q) {
      if (q['type'] == 'abort') transport.reply(q, null);
    };
    await client.abort();
    await expectLater(
      client.prompt('must not send'),
      throwsA(isA<PiRpcException>()),
    );
    expect(transport.commands.where((q) => q['type'] == 'prompt'), isEmpty);
    transport.reply(pending, {'cancelled': 'broken'});
    await Future<void>.delayed(Duration.zero);
    expect(client.hasUnsettledConversationMutation, true);
    transport.reply(pending, {'cancelled': false, 'editorText': 'original'});
    await Future<void>.delayed(Duration.zero);
    expect(client.hasUnsettledConversationMutation, false);
    expect(
      events
          .whereType<PiAgentEvent>()
          .where((e) => e.type == 'gui_history_settled')
          .single
          .payload['data'],
      {'cancelled': false, 'editorText': 'original'},
    );
    await client.close();
  });
}
