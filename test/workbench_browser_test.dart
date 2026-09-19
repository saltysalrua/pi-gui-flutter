import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pi_gui/core/rpc/pi_channel_hub.dart';
import 'package:pi_gui/ui/features/home/controllers/workbench_controller.dart';
import 'package:pi_gui/ui/features/home/controllers/workspace_browser_controller.dart';
import 'package:pi_gui/ui/features/home/controllers/workspace_tabs_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport;
import 'parallel_session_test.dart' show reply;
import 'workspace_browser_test.dart' show listing;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Uses a frame only to exercise deferred controller disposal, not UI rendering.
  testWidgets(
    'removed workspaces release caches after the last document closes and reject late history',
    (tester) async {
      final a = p.absolute('A'), b = p.absolute('B');
      Map<String, Object?> project(String path) => {
        'path': path,
        'name': p.basename(path),
        'branches': <String>[],
        'worktrees': [
          {'path': path, 'name': p.basename(path), 'main': true},
        ],
      };
      final projects = [project(a), project(b)];
      final transport = TestTransport();
      final workbench = WorkbenchController(
        hub: PiChannelHub(() async => transport),
      );
      addTearDown(() async {
        await workbench.shutdown();
        workbench.dispose();
      });
      final historyRequests = <Map<String, dynamic>>[];
      transport.onSend = (packet) {
        final command = packet['message'] as Map;
        switch (command['type']) {
          case 'gui_get_catalog':
            reply(transport, packet, {
              'projects': projects,
              'channels': [],
              'jobs': [],
            });
          case 'gui_forget_project':
            projects.removeWhere(
              (project) => project['path'] == command['path'],
            );
            reply(transport, packet, null);
          case 'gui_workspace_history':
            historyRequests.add(packet);
          default:
            throw StateError('Unexpected command: ${command['type']}');
        }
      };
      await workbench.initialize();
      final browserA = workbench.browserFor(a),
          browserB = workbench.browserFor(b);
      final documentsA = workbench.documentTabsFor(a);
      final file = WorkspaceDocument.file(a, 'note.txt');
      workbench.tabs.add(file);
      final firstRead = workbench.loadHistory(a);
      await tester.pump();
      await workbench.forgetProject(a);
      expect(workbench.failure, isNull);
      expect(workbench.catalog!.projects.map((project) => project.path), [b]);
      expect(workbench.browserFor(a), same(browserA)); // Open document pins it.
      expect(workbench.documentTabsFor(a), same(documentsA));
      workbench.tabs.remove(file);
      expect(workbench.tabs.tabs.map((tab) => tab.workspace), [null]);
      await tester.pump(); // Consumers unmount before controller disposal.
      expect(workbench.selectedWorkspace, b);
      expect(workbench.loadingHistory, isNot(contains(a)));
      expect(workbench.browserFor(b), same(browserB));

      // Re-registering starts a new read, while the old request is still pending.
      projects.add(project(a));
      await workbench.refresh();
      expect(workbench.browserFor(a), isNot(same(browserA)));
      expect(workbench.documentTabsFor(a), isNot(same(documentsA)));
      final secondRead = workbench.loadHistory(a);
      await tester.pump();
      reply(transport, historyRequests.first, {'sessions': []});
      await firstRead;
      expect(workbench.history.containsKey(a), false);
      expect(workbench.loadingHistory, contains(a));
      reply(transport, historyRequests.last, {'sessions': []});
      await secondRead;
      expect(workbench.history[a], isEmpty);
      expect(workbench.loadingHistory, isNot(contains(a)));
    },
  );

  test('second session shares file/graph state despite a differently spelled workspace', () async {
    final cwd = p.absolute('Workspace');
    final alias = p.style == p.Style.windows
        ? cwd.replaceAll('\\', '/').toLowerCase()
        : '$cwd/.';
    final transport = TestTransport();
    final workbench = WorkbenchController(
      hub: PiChannelHub(() async => transport),
    );
    addTearDown(() async {
      await workbench.shutdown();
      workbench.dispose();
    });
    final channels = <Map<String, Object?>>[
      {'id': 'primary', 'workspace': cwd, 'status': 'ready'},
    ];
    transport.onSend = (packet) {
      final command = packet['message'] as Map<String, dynamic>;
      final data = switch (command['type']) {
        'gui_get_catalog' => {
          'projects': <Object>[],
          'channels': channels,
          'jobs': <Object>[],
        },
        'gui_open_channel' => () {
          final channel = <String, Object?>{
            'id': command['channelId'],
            'workspace': cwd,
            'status': 'ready',
          };
          channels.add(channel);
          return channel;
        }(),
        'gui_workspace_history' => {'sessions': <Object>[]},
        'gui_list_files' => listing(cwd),
        'gui_get_git_graph' => {
          'workspace': cwd,
          'root': cwd,
          'branch': 'main',
          'head': null,
          'hasMore': false,
          'commits': <Object>[],
        },
        'get_state' => {'model': null, 'thinkingLevel': 'off'},
        'get_messages' => {'messages': <Object>[]},
        'get_available_models' => {'models': <Object>[]},
        'get_available_thinking_levels' => {
          'levels': ['off'],
        },
        _ => throw StateError('Unexpected command: ${command['type']}'),
      };
      transport.emit({
        'type': 'gui_channel',
        'channel': packet['channel'],
        'message': {
          'type': 'response',
          'id': command['id'],
          'command': command['type'],
          'success': true,
          'data': data,
        },
      });
    };
    await workbench.initialize();
    final browser = workbench.activeBrowser!;
    browser.tab = WorkspaceBrowserTab.graph;
    browser.toggle();
    await browser.ensureLoaded();
    final tree = browser.directories[''];
    final graph = browser.graph;
    final documents = workbench.documentTabsFor(cwd);
    browser.expanded.add('src');
    browser.selectFile('file');
    final reads = transport.commands.where((packet) {
      final type = (packet['message'] as Map)['type'];
      return type == 'gui_list_files' || type == 'gui_get_git_graph';
    }).length;

    await workbench.openSession(alias);
    expect(workbench.sessions.length, 2);
    expect(workbench.activeSession!.id, isNot('primary'));
    expect(workbench.activeBrowser, same(browser));
    expect(workbench.documentTabsFor(alias), same(documents));
    expect(browser.isOpen, true);
    expect(browser.tab, WorkspaceBrowserTab.graph);
    expect(browser.expanded, {'src'});
    expect(browser.selectedPath, 'file');
    await workbench.activeBrowser!.ensureLoaded();
    expect(browser.directories[''], same(tree));
    expect(browser.graph, same(graph));
    expect(browser.refreshing || browser.graphLoading, false);
    expect(
      transport.commands.where((packet) {
        final type = (packet['message'] as Map)['type'];
        return type == 'gui_list_files' || type == 'gui_get_git_graph';
      }).length,
      reads,
    );
    expect(
      workbench.browserFor(p.join(cwd, 'different')),
      isNot(same(browser)),
    );
    // Drain hydration before disposing the independent session controllers.
    while (workbench.sessions.values.any((session) => session.hydrating)) {
      await Future<void>.delayed(Duration.zero);
    }
  });
}
