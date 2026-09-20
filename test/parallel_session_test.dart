import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_channel_hub.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/core/slots/slot_manager.dart';
import 'package:pi_gui/ui/features/home/controllers/pi_extension_ui_bridge.dart';
import 'package:pi_gui/ui/features/home/controllers/workbench_controller.dart';
import 'package:pi_gui/ui/features/home/controllers/workspace_tabs_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport;

void reply(TestTransport transport, Map<String, dynamic> packet, Object? data) {
  final request = packet['message'] as Map;
  transport.emit({
    'type': 'gui_channel',
    'channel': packet['channel'],
    'message': {
      'type': 'response',
      'id': request['id'],
      'command': request['type'],
      'success': true,
      'data': data,
    },
  });
}

void event(
  TestTransport transport,
  String channel,
  Map<String, Object?> message,
) => transport.emit({
  'type': 'gui_channel',
  'channel': channel,
  'message': message,
});

class _GatedCloseTransport extends TestTransport {
  final closeStarted = Completer<void>();
  final allowClose = Completer<void>();

  @override
  Future<void> close() async {
    closeStarted.complete();
    await allowClose.future;
    await super.close();
  }
}

class _ShutdownSession extends Fake implements WorkbenchSession {
  _ShutdownSession(this.onDispose);
  final Future<void> Function() onDispose;

  @override
  Future<void> dispose() => onDispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final failSession in [false, true]) {
    test(
      'shutdown waits for the owned process tree even with session failure=$failSession',
      () async {
        final transport = _GatedCloseTransport();
        final workbench = WorkbenchController(
          hub: PiChannelHub(() async => transport),
        );
        addTearDown(workbench.dispose);
        await workbench.control.connect();
        var disposedHealthy = false;
        workbench.sessions['first'] = _ShutdownSession(() async {
          if (failSession) throw StateError('cleanup failed');
        });
        workbench.sessions['second'] = _ShutdownSession(() async {
          disposedHealthy = true;
        });
        var finished = false;
        final shutdown = workbench.shutdown();
        final checked = expectLater(
          shutdown.whenComplete(() => finished = true),
          failSession ? throwsStateError : completes,
        );
        expect(identical(shutdown, workbench.shutdown()), true);
        await transport.closeStarted.future;
        expect(disposedHealthy, true);
        expect(finished, false);
        transport.allowClose.complete();
        await checked;
        expect(transport.closed, true);
        expect(workbench.hub.channelCount, 0);
      },
    );
  }

  test('one physical transport routes identical request IDs and a child EOF only closes its channel', () async {
    final transport = TestTransport();
    var starts = 0;
    final hub = PiChannelHub(() async {
      starts++;
      return transport;
    });
    final a = PiRpcClient(transportFactory: hub.transportFor('a'));
    final b = PiRpcClient(transportFactory: hub.transportFor('b'));
    addTearDown(() async {
      await a.close();
      await b.close();
      await hub.close();
    });
    final pa = a.getState(), pb = b.getState();
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1);
    expect(transport.commands.length, 2);
    expect(
      (transport.commands[0]['message'] as Map)['id'],
      (transport.commands[1]['message'] as Map)['id'],
    );
    for (final packet in transport.commands.reversed) {
      reply(transport, packet, {
        'sessionId': packet['channel'],
        'thinkingLevel': 'off',
      });
    }
    expect((await pa).sessionId, 'a');
    expect((await pb).sessionId, 'b');
    event(transport, 'a', {'type': 'gui_channel_exited'});
    await Future<void>.delayed(Duration.zero);
    expect(a.isConnected, false);
    expect(b.isConnected, true);
    expect(transport.closed, false);
    transport.onSend = (packet) =>
        reply(transport, packet, {'thinkingLevel': 'off'});
    await b.getState();
    await expectLater(a.getState(), throwsStateError);
  });

  test(
    'timed-out prompt is not replayed and does not block another session',
    () async {
      final transport = TestTransport();
      final hub = PiChannelHub(() async => transport);
      final a = PiRpcClient(
        transportFactory: hub.transportFor('a'),
        requestTimeout: const Duration(milliseconds: 25),
      );
      final b = PiRpcClient(transportFactory: hub.transportFor('b'));
      addTearDown(() async {
        await a.close();
        await b.close();
        await hub.close();
      });
      await expectLater(
        a.prompt('one'),
        throwsA(
          isA<PiRpcException>().having(
            (e) => e.outcomeUnknown,
            'uncertain',
            true,
          ),
        ),
      );
      final timedOut = transport.commands.single;
      transport.onSend = (packet) =>
          reply(transport, packet, {'thinkingLevel': 'off'});
      await b.getState();
      expect(a.hasUnsettledConversationMutation, true);
      reply(transport, timedOut, null);
      await Future<void>.delayed(Duration.zero);
      expect(a.hasUnsettledConversationMutation, false);
      expect(
        transport.commands
            .where((p) => (p['message'] as Map)['type'] == 'prompt')
            .length,
        1,
      );
    },
  );

  test('per-session extension widgets, editor updates and identical question IDs cannot cross channels', () async {
    final transport = TestTransport();
    final hub = PiChannelHub(() async => transport);
    final a = PiRpcClient(transportFactory: hub.transportFor('a'));
    final b = PiRpcClient(transportFactory: hub.transportFor('b'));
    final sa = SlotManager(), sb = SlotManager();
    final ia = TextEditingController(), ib = TextEditingController();
    final ba = PiExtensionUiBridge(a, ia, slots: sa, foreground: false);
    final bb = PiExtensionUiBridge(b, ib, slots: sb, foreground: false);
    addTearDown(() async {
      ba.dispose();
      bb.dispose();
      ia.dispose();
      ib.dispose();
      sa.dispose();
      sb.dispose();
      await a.close();
      await b.close();
      await hub.close();
    });
    await Future.wait([a.connect(), b.connect()]);
    for (final channel in ['a', 'b']) {
      event(transport, channel, {
        'type': 'extension_ui_request',
        'id': 'same',
        'method': 'setWidget',
        'widgetKey': 'same',
        'widgetLines': [channel],
      });
      event(transport, channel, {
        'type': 'extension_ui_request',
        'id': 'editor',
        'method': 'set_editor_text',
        'text': channel,
      });
      event(transport, channel, {
        'type': 'extension_ui_request',
        'id': 'question',
        'method': 'confirm',
        'title': channel,
      });
    }
    await Future<void>.delayed(Duration.zero);
    expect(ia.text, 'a');
    expect(ib.text, 'b');
    expect(sa.editorAnchor, isNot(sb.editorAnchor));
    expect(sa.notifierFor(ExtensibleSlotId.aboveEditor).value.length, 1);
    expect(sb.notifierFor(ExtensibleSlotId.aboveEditor).value.length, 1);
    expect(ba.needsAttention, true);
    expect(bb.needsAttention, true);
    expect(
      SlotManager.instance.notifierFor(ExtensibleSlotId.dialogOverlay).value,
      isEmpty,
    );
    ba.setForeground(true);
    final aDialog = SlotManager.instance
        .notifierFor(ExtensibleSlotId.dialogOverlay)
        .value
        .single;
    ba.setForeground(false);
    bb.setForeground(true);
    final bDialog = SlotManager.instance
        .notifierFor(ExtensibleSlotId.dialogOverlay)
        .value
        .single;
    expect(aDialog.key, isNot(bDialog.key));
    // Closing a background bridge cannot clear the foreground question.
    ba.setForeground(false);
    expect(
      SlotManager.instance
          .notifierFor(ExtensibleSlotId.dialogOverlay)
          .value
          .single
          .key,
      bDialog.key,
    );
    await b.respondToExtension('question', confirmed: true);
    expect(transport.commands.last['channel'], 'b');
  });

  test(
    'closing channel leases releases routes without resurrecting old clients',
    () async {
      final transport = TestTransport();
      final hub = PiChannelHub(() async => transport);
      addTearDown(hub.close);
      for (var i = 0; i < 40; i++) {
        final lease = hub.transportFor('session-$i');
        final channel = await lease();
        expect(hub.channelCount, 2); // This lease plus buffered primary.
        await channel.close();
        expect(hub.channelCount, 1);
        await expectLater(lease(), throwsStateError);
        expect(hub.channelCount, 1);
      }
      final primary = await hub.transportFor('primary')();
      await primary.close();
      expect(hub.channelCount, 0);
      expect(transport.closed, false);
      await hub.close();
      expect(hub.channelCount, 0);
    },
  );

  test(
    'startup failure and shutdown during attachment release all routes',
    () async {
      final failed = PiChannelHub(
        () async => throw StateError('startup failed'),
      );
      await expectLater(failed.transportFor('a')(), throwsStateError);
      expect(failed.channelCount, 0);
      await failed.close();

      final startup = Completer<TestTransport>();
      final hub = PiChannelHub(() => startup.future);
      final attaching = expectLater(hub.transportFor('a')(), throwsStateError);
      await hub.close();
      final transport = TestTransport();
      startup.complete(transport);
      await attaching;
      expect(hub.channelCount, 0);
      expect(transport.closed, true);
    },
  );

  test('parallel chat tabs can split, close the original and recreate the empty fallback', () {
    final tabs = WorkbenchTabs();
    addTearDown(tabs.dispose);
    const a = WorkspaceDocument.chat('a', '/project');
    const b = WorkspaceDocument.chat('b', '/project');
    tabs.add(a);
    tabs.add(b);
    tabs.split(a);
    expect(tabs.groups.length, 2);
    expect(tabs.tabs, [a, b]);
    tabs.remove(a);
    expect(tabs.selected, b);
    expect(tabs.home, b);
    tabs.remove(b);
    expect(tabs.tabs, [const WorkspaceDocument.chat()]);
    tabs.add(a);
    expect(tabs.tabs, [a]);
  });

  test('idle sweep hibernates exempt-checked background sessions and wake reopens the same history', () async {
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
        'id': 'a',
        'workspace': '/h',
        'sessionFile': '/h/a.jsonl',
        'status': 'ready',
      },
      {
        'id': 'b',
        'workspace': '/h',
        'sessionFile': '/h/b.jsonl',
        'status': 'ready',
      },
    ];
    transport.onSend = (packet) {
      final command = packet['message'] as Map<String, dynamic>;
      Object? data;
      switch (command['type']) {
        case 'gui_get_catalog':
          data = {
            'projects': <Object>[],
            'channels': channels,
            'jobs': <Object>[],
          };
        case 'gui_workspace_history':
          data = {'sessions': <Object>[]};
        case 'gui_close_channel':
          channels.removeWhere((c) => c['id'] == command['channelId']);
          data = <String, Object?>{};
        case 'gui_open_channel':
          final channel = <String, Object?>{
            'id': command['channelId'],
            'workspace': '/h',
            'sessionFile': command['sessionPath'],
            'status': 'ready',
          };
          channels.add(channel);
          data = channel;
        case 'get_state':
          final channel = channels.firstWhere(
            (c) => c['id'] == packet['channel'],
            orElse: () => channels.first,
          );
          data = {
            'model': null,
            'thinkingLevel': 'off',
            'sessionFile': channel['sessionFile'],
          };
        case 'get_messages':
          data = {'messages': <Object>[]};
        case 'get_available_models':
          data = {'models': <Object>[]};
        case 'get_available_thinking_levels':
          data = {
            'levels': ['off'],
          };
        default:
          throw StateError('Unexpected command: ${command['type']}');
      }
      reply(transport, packet, data);
    };
    await workbench.initialize();
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    await settle();
    // 'b' was adopted last and is selected; 'a' runs in the background.
    expect(workbench.tabs.selected.sessionId, 'b');
    final a = workbench.sessions['a']!;
    expect(a.chat.sessionFile, '/h/a.jsonl');
    a.lastActivity = DateTime.now().subtract(const Duration(minutes: 30));

    // A pending draft forbids hibernation.
    a.input.text = 'draft';
    workbench.sweepIdleSessions(idleMinutes: 15);
    await settle();
    expect(a.hibernating, false);
    expect(
      transport.commands.where(
        (c) => c['message']['type'] == 'gui_close_channel',
      ),
      isEmpty,
    );

    a.input.clear();
    workbench.sweepIdleSessions(idleMinutes: 15);
    await settle();
    expect(a.hibernating, true);
    expect(
      transport.commands
          .where((c) => c['message']['type'] == 'gui_close_channel')
          .single['message']['channelId'],
      'a',
    );
    // The tab and the controller stay; only the process is gone.
    expect(workbench.sessions['a'], same(a));
    expect(workbench.tabs.tabs.map((t) => t.sessionId), contains('a'));

    // Typing while asleep carries over; waking reopens the same saved file
    // and never resends a prompt.
    a.input.text = 'typed while asleep';
    await workbench.wakeSession('a');
    await settle();
    final opened =
        transport.commands
                .where((c) => c['message']['type'] == 'gui_open_channel')
                .single['message']
            as Map<String, dynamic>;
    expect(opened['sessionPath'], '/h/a.jsonl');
    expect(
      transport.commands.where((c) => c['message']['type'] == 'prompt'),
      isEmpty,
    );
    expect(workbench.sessions.containsKey('a'), false);
    final fresh = workbench.sessions.values
        .where(
          (s) =>
              s.chat.sessionFile == '/h/a.jsonl' ||
              s.historyPath == '/h/a.jsonl',
        )
        .single;
    expect(fresh.input.text, 'typed while asleep');
    expect(workbench.tabs.tabs.map((t) => t.sessionId), contains(fresh.id));
    // The sleeping controller is disposed after the current frame, matching
    // the existing closeSession pattern; nothing references it anymore.
  });
}
