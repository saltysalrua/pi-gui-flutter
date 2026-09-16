import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/core/app_tabs_controller.dart';
import 'package:pi_gui/ui/features/home/controllers/workspace_browser_controller.dart';
import 'package:pi_gui/ui/features/home/controllers/workspace_tabs_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport;

void invariant(AppTabsController<String> tabs) {
  final all = tabs.groups.expand((group) => group.tabs).toList();
  expect(all.toSet().length, all.length);
  expect(all.toSet(), tabs.tabs.toSet());
  expect(
    tabs.groups.every(
      (group) => group.tabs.isNotEmpty && group.tabs.contains(group.selected),
    ),
    true,
  );
  expect(tabs.groups, contains(tabs.activeGroup));
  expect(tabs.groups.first.tabs.first, tabs.home);
}

void main() {
  test(
    'deduplicate globally; reorder/drop indices preserve the permanent home',
    () {
      final tabs = AppTabsController(home: 'chat');
      addTearDown(tabs.dispose);
      tabs
        ..open('a')
        ..open('b')
        ..open('c');
      tabs.move('a', 0, index: 4);
      expect(tabs.groups.single.tabs, ['chat', 'b', 'c', 'a']);
      tabs.move('a', 0, index: 0);
      expect(tabs.groups.single.tabs, ['chat', 'a', 'b', 'c']);
      tabs
        ..split('a')
        ..open('b');
      expect(tabs.groups.length, 2);
      expect(tabs.activeGroup.id, 0);
      expect(tabs.tabs, ['chat', 'a', 'b', 'c']);
      tabs
        ..close('chat')
        ..split('chat')
        ..move('chat', tabs.groups.last.id);
      invariant(tabs);
    },
  );

  test('moving the last tab removes only the empty group; close selects a neighbor', () {
    final tabs = AppTabsController(home: 'chat');
    addTearDown(tabs.dispose);
    tabs
      ..open('a')
      ..open('b')
      ..split('a');
    tabs.move('a', 0, index: 1);
    expect(tabs.groups.single.tabs, ['chat', 'a', 'b']);
    tabs.close('a');
    expect(tabs.selected, 'b');
    tabs
      ..split('b')
      ..close('b');
    expect(tabs.groups.single.tabs, ['chat']);
    expect(tabs.selected, 'chat');
    invariant(tabs);
  });

  test('merge retains each group order and active document; reset keeps home identity', () {
    final tabs = AppTabsController(home: 'chat');
    addTearDown(tabs.dispose);
    tabs
      ..open('a')
      ..open('b')
      ..split('b')
      ..open('c')
      ..split('c');
    expect(tabs.groups.length, 3);
    tabs.mergeAll();
    expect(tabs.groups.single.tabs, ['chat', 'a', 'b', 'c']);
    expect(tabs.selected, 'c');
    tabs.cycle(1);
    expect(tabs.selected, 'chat');
    tabs.cycle(-1);
    expect(tabs.selected, 'c');
    tabs.reset();
    expect(tabs.tabs, ['chat']);
    invariant(tabs);
  });

  test('mixed operations cannot duplicate, orphan or lose a document', () {
    final tabs = AppTabsController(home: 'chat');
    addTearDown(tabs.dispose);
    final random = Random(2319);
    for (var i = 0; i < 500; i++) {
      final tab = 'file-${random.nextInt(12)}';
      switch (random.nextInt(7)) {
        case 0:
          tabs.open(tab);
        case 1:
          tabs.close(tab);
        case 2:
          tabs.split(tab);
        case 3:
          final group = tabs.groups[random.nextInt(tabs.groups.length)];
          tabs.move(
            tab,
            group.id,
            index: random.nextInt(group.tabs.length + 1),
          );
        case 4:
          tabs.mergeAll();
        case 5:
          tabs.activate(tab);
        case 6:
          tabs.cycle(random.nextBool() ? 1 : -1);
      }
      invariant(tabs);
    }
  });

  test('workspace identity separates revisions, resets tabs, and rejects late preview results', () async {
    final transport = TestTransport();
    final pi = PiRpcClient(transportFactory: () async => transport);
    await pi.connect();
    final browser = WorkspaceBrowserController(pi)..setWorkspace('/first');
    final tabs = WorkspaceTabsController(browser);
    addTearDown(() async {
      tabs.dispose();
      browser.dispose();
      await pi.close();
    });
    tabs
      ..openFile('src/file.dart')
      ..openFile('src/file.dart', commit: 'a' * 40)
      ..openFile('src/file.dart', commit: 'b' * 40)
      ..openCommit('a' * 40);
    expect(tabs.tabs.length, 5);
    tabs.openFile('src/file.dart');
    expect(tabs.tabs.length, 5);
    browser.setWorkspace('/first');
    expect(tabs.tabs.length, 5);
    // No RPC is sent for selection, moving, or splitting documents.
    expect(transport.commands, isEmpty);
    final pending = <Map<String, dynamic>>[];
    transport.onSend = pending.add;
    final preview = browser.preview('src/file.dart');
    final rejected = expectLater(preview, throwsA(isA<PiRpcException>()));
    await Future<void>.delayed(Duration.zero);
    browser.setWorkspace('/second');
    expect(tabs.tabs, [const WorkspaceDocument.chat()]);
    tabs.openFile('src/file.dart');
    expect(tabs.selected.workspace, '/second');
    transport.reply(pending.single, {
      'workspace': '/first',
      'path': 'src/file.dart',
      'kind': 'text',
      'content': 'stale',
      'stagedDiff': '',
      'workingDiff': '',
      'commitDiff': '',
      'diffLimited': false,
    });
    await rejected;
    expect(tabs.selected.workspace, '/second');
    tabs.showChat();
    expect(tabs.selected, const WorkspaceDocument.chat());
    browser.setWorkspace(null);
    tabs.openFile('ignored');
    expect(tabs.tabs, [const WorkspaceDocument.chat()]);
  });
}
