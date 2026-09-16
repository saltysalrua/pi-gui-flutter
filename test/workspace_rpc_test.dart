import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/features/home/controllers/chat_controller.dart';
import 'package:pi_gui/ui/features/home/controllers/model_picker_controller.dart';
import 'package:pi_gui/ui/features/home/controllers/workspace_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport;

Map<String, Object?> snapshot(String path) => {
  'current': {'path': path, 'name': 'workspace'},
  'recent': [
    {'path': path, 'name': 'workspace'},
  ],
  'git': null,
  'gitWarning': null,
  'persistenceWarning': false,
};
Future<void> tick() => Future<void>.delayed(Duration.zero);

Map<String, Object?> historyEntry(String path) => {
  'path': '$path/session.jsonl',
  'id': path,
  'cwd': path,
  'title': path,
  'modified': '2026-01-01T12:00:00Z',
  'messageCount': 2,
};

Future<(TestTransport, PiRpcClient, ChatController, WorkspaceController)>
historyFixture() async {
  final transport = TestTransport();
  final pi = PiRpcClient(transportFactory: () async => transport);
  // Drain the connection event before attaching controllers; tests explicitly
  // start the read they intend to hold instead of racing startup refreshes.
  await pi.connect();
  await tick();
  final chat = ChatController(pi);
  final model = ModelPickerController(pi);
  final workspace = WorkspaceController(pi, chat, model);
  addTearDown(() async {
    workspace.dispose();
    chat.dispose();
    model.dispose();
    await pi.close();
  });
  transport.onSend = (command) =>
      transport.reply(command, switch (command['type']) {
        'gui_get_workspace' => snapshot('/current'),
        'gui_list_sessions' => {
          'sessions': [historyEntry('/current')],
        },
        'get_state' => {'model': null, 'thinkingLevel': 'off'},
        'get_messages' => {'messages': <Object>[]},
        'get_available_models' => {'models': <Object>[]},
        'get_available_thinking_levels' => {
          'levels': ['off'],
        },
        _ => null,
      });
  return (transport, pi, chat, workspace);
}

void main() {
  test(
    'concurrent history readers share a request and await one forced follow-up',
    () async {
      final (transport, _, _, workspace) = await historyFixture();
      final pending = <Map<String, dynamic>>[];
      transport.onSend = pending.add;
      final first = workspace.refreshSessions();
      final duplicate = workspace.refreshSessions();
      expect(identical(first, duplicate), true);
      await tick();
      expect(pending.length, 1);
      var completed = false;
      final forced = workspace
          .refreshSessions(force: true)
          .then((_) => completed = true);
      workspace.refreshSessions(force: true);
      transport.reply(pending.first, {
        'sessions': [historyEntry('/stale')],
      });
      await tick();
      expect(pending.length, 2);
      expect(pending.last['force'], true);
      expect(completed, false);
      expect(workspace.sessions, isEmpty);
      expect(workspace.isLoadingSessions, true);
      transport.reply(pending.last, {
        'sessions': [historyEntry('/fresh')],
      });
      await Future.wait([first, duplicate, forced]);
      expect(workspace.sessions.single.cwd, '/fresh');
      expect(workspace.isLoadingSessions, false);
      expect(pending.length, 2);
    },
  );

  test('old workspace history is discarded and does not block conversation hydration', () async {
    final (transport, _, chat, workspace) = await historyFixture();
    final respond = transport.onSend!;
    final pending = <Map<String, dynamic>>[];
    transport.onSend = (command) {
      if (command['type'] == 'gui_list_sessions') {
        pending.add(command);
      } else {
        respond(command);
      }
    };
    final loading = workspace.refresh();
    await tick();
    // A held sidebar request no longer prevents get_messages from starting.
    expect(transport.commands.any((c) => c['type'] == 'get_messages'), true);
    expect(chat.isReady, true);
    expect(workspace.isBusy, true);
    transport.emit({'type': 'gui_workspace_changed', 'path': '/next'});
    await tick();
    transport.reply(pending.first, {
      'sessions': [historyEntry('/old')],
    });
    await tick();
    expect(workspace.sessions, isEmpty);
    expect(pending.length, 2);
    transport.reply(pending.last, {
      'sessions': [historyEntry('/next')],
    });
    await loading;
    expect(workspace.sessions.single.cwd, '/next');
    expect(workspace.isBusy, false);
  });

  test('settlement refreshes unchanged session summaries; manual refresh bypasses the cache', () async {
    final (transport, _, _, workspace) = await historyFixture();
    await workspace.refresh();
    final before = transport.commands
        .where((c) => c['type'] == 'gui_list_sessions')
        .length;
    transport.emit({'type': 'agent_settled'});
    await tick();
    await workspace.refreshSessions();
    expect(
      transport.commands.where((c) => c['type'] == 'gui_list_sessions').length,
      greaterThan(before),
    );
    await workspace.refresh(loadConversation: false, forceSessions: true);
    expect(
      transport.commands.lastWhere(
        (c) => c['type'] == 'gui_list_sessions',
      )['force'],
      true,
    );
    expect(transport.commands.where((c) => c['type'] == 'prompt'), isEmpty);
  });

  test('typed history keeps paths and timestamps; malformed history fails independently', () async {
    final transport = TestTransport();
    final pi = PiRpcClient(transportFactory: () async => transport);
    addTearDown(pi.close);
    final entry = <String, Object?>{
      'path': r'C:\会话\a.jsonl',
      'id': 'one',
      'cwd': r'C:\工作区',
      'title': '中文\u2028title',
      'modified': '2026-01-01T12:00:00Z',
      'messageCount': 4,
    };
    transport.onSend = (command) => transport.reply(command, {
      'sessions': [entry],
    });
    final sessions = await pi.listSessions();
    expect(sessions.single.path, entry['path']);
    expect(sessions.single.modified.isUtc, true);
    entry['modified'] = 'not-a-date';
    await expectLater(pi.listSessions(), throwsFormatException);
    expect(pi.isConnected, true);
  });

  test('timed-out directory mutation blocks reads and model writes until late acknowledgement', () async {
    final transport = TestTransport();
    final pi = PiRpcClient(
      transportFactory: () async => transport,
      requestTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(pi.close);
    final events = <PiRpcEvent>[];
    final subscription = pi.events.listen(events.add);
    addTearDown(subscription.cancel);
    await expectLater(
      pi.openWorkspace('/next'),
      throwsA(
        isA<PiRpcException>().having((e) => e.outcomeUnknown, 'unknown', true),
      ),
    );
    expect(pi.hasUnsettledConversationMutation, true);
    final original = transport.commands.single;
    final reading = pi.getWorkspace();
    await tick();
    expect(transport.commands.length, 1);
    transport.onSend = (command) => transport.reply(command, snapshot('/next'));
    transport.emit({'type': 'gui_workspace_changed', 'path': '/next'});
    transport.reply(original, snapshot('/next'));
    expect((await reading).current.path, '/next');
    await tick();
    expect(events.whereType<PiRpcWorkspaceChanged>().single.path, '/next');
    expect(pi.hasUnsettledConversationMutation, false);
    expect(transport.closed, false);
    expect(
      transport.commands.where((c) => c['type'] == 'gui_open_workspace').length,
      1,
    );
  });

  test('workspace transition locks chat/picker, resets old projection only on confirmation, and reads the new session', () async {
    final transport = TestTransport();
    final pi = PiRpcClient(transportFactory: () async => transport);
    final chat = ChatController(pi);
    final model = ModelPickerController(pi);
    final workspace = WorkspaceController(pi, chat, model);
    addTearDown(() async {
      workspace.dispose();
      chat.dispose();
      model.dispose();
      await pi.close();
    });
    var cwd = '/first';
    Map<String, dynamic>? switching;
    transport.onSend = (command) {
      final data = switch (command['type']) {
        'gui_get_workspace' => snapshot(cwd),
        'gui_list_sessions' => {'sessions': <Object>[]},
        'get_state' => {
          'model': null,
          'thinkingLevel': 'off',
          'sessionFile': '$cwd/session.jsonl',
        },
        'get_messages' => {
          'messages': [
            {'role': 'user', 'content': cwd, 'timestamp': 1},
          ],
        },
        'get_available_models' => {'models': <Object>[]},
        'get_available_thinking_levels' => {
          'levels': ['off'],
        },
        _ => null,
      };
      if (command['type'] == 'gui_open_workspace') {
        switching = command;
      } else {
        transport.reply(command, data);
      }
    };
    await workspace.refresh();
    expect(chat.timeline.messages.single.text, '/first');
    final opening = workspace.open('/second');
    await tick();
    expect(chat.canSend, false);
    expect(model.canChangeModel, false);
    expect(chat.timeline.messages.single.text, '/first');
    cwd = '/second';
    transport.emit({'type': 'gui_workspace_changed', 'path': cwd});
    transport.reply(switching!, snapshot(cwd));
    expect(await opening, true);
    expect(chat.timeline.messages.single.text, '/second');
    expect(chat.sessionFile, '/second/session.jsonl');
    expect(chat.canSend, true);
    expect(workspace.snapshot!.current.path, cwd);
    expect(transport.commands.where((c) => c['type'] == 'prompt'), isEmpty);

    final failing = workspace.open('/missing');
    await tick();
    transport.emit({
      'id': switching!['id'],
      'type': 'response',
      'command': 'gui_open_workspace',
      'success': false,
      'error': 'DIRECTORY_UNAVAILABLE',
    });
    expect(await failing, false);
    expect(chat.timeline.messages.single.text, '/second');
    expect(workspace.snapshot!.current.path, '/second');
    expect(workspace.failureCode, 'DIRECTORY_UNAVAILABLE');
  });
}
