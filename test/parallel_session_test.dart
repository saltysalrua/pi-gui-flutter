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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('one physical transport routes identical request IDs and a child EOF only closes its channel', () async {
    final transport = TestTransport();
    var starts = 0;
    final hub = PiChannelHub(() async {
      starts++;
      return transport;
    });
    final a = PiRpcClient(transportFactory: () => hub.attach('a'));
    final b = PiRpcClient(transportFactory: () => hub.attach('b'));
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
        transportFactory: () => hub.attach('a'),
        requestTimeout: const Duration(milliseconds: 25),
      );
      final b = PiRpcClient(transportFactory: () => hub.attach('b'));
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
    final a = PiRpcClient(transportFactory: () => hub.attach('a'));
    final b = PiRpcClient(transportFactory: () => hub.attach('b'));
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
}
