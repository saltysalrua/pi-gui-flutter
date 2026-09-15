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

void main() {
  test(
    'typed history keeps paths and timestamps; malformed history fails independently',
    () async {
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
    },
  );

  test(
    'timed-out directory mutation blocks reads and model writes until late acknowledgement',
    () async {
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
          isA<PiRpcException>().having(
            (e) => e.outcomeUnknown,
            'unknown',
            true,
          ),
        ),
      );
      expect(pi.hasUnsettledConversationMutation, true);
      final original = transport.commands.single;
      final reading = pi.getWorkspace();
      await tick();
      expect(transport.commands.length, 1);
      transport.onSend = (command) =>
          transport.reply(command, snapshot('/next'));
      transport.emit({'type': 'gui_workspace_changed', 'path': '/next'});
      transport.reply(original, snapshot('/next'));
      expect((await reading).current.path, '/next');
      await tick();
      expect(events.whereType<PiRpcWorkspaceChanged>().single.path, '/next');
      expect(pi.hasUnsettledConversationMutation, false);
      expect(transport.closed, false);
      expect(
        transport.commands
            .where((c) => c['type'] == 'gui_open_workspace')
            .length,
        1,
      );
    },
  );

  test(
    'workspace transition locks chat/picker, resets old projection only on confirmation, and reads the new session',
    () async {
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
    },
  );
}
