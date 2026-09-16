import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pi_gui/core/models/commit_graph.dart';
import 'package:pi_gui/core/rpc/pi_browser_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/features/home/controllers/workspace_browser_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport;

Future<void> tick() => Future<void>.delayed(Duration.zero);
Map<String, Object?> listing(
  String workspace, {
  String path = '',
  String name = '文\n件.txt',
}) => {
  'workspace': workspace,
  'path': path,
  'branch': 'main',
  'gitWarning': null,
  'hasMore': false,
  'git': true,
  'entries': [
    {
      'name': name,
      'path': path.isEmpty ? name : '$path/$name',
      'directory': false,
      'symlink': false,
      'missing': false,
      'status': 'modified',
      'indexStatus': 'M',
      'worktreeStatus': 'M',
    },
  ],
};
Map<String, Object?> preview(String workspace) => {
  'workspace': workspace,
  'path': 'file',
  'content': 'text',
  'kind': 'text',
  'stagedDiff': '+stage',
  'workingDiff': '+work',
  'commitDiff': '',
  'diffLimited': false,
};
Future<(TestTransport, PiRpcClient, WorkspaceBrowserController)>
fixture() async {
  final transport = TestTransport();
  final pi = PiRpcClient(transportFactory: () async => transport);
  await pi.connect();
  await tick();
  final browser = WorkspaceBrowserController(pi)..setWorkspace('/workspace');
  addTearDown(() async {
    browser.dispose();
    await pi.close();
  });
  return (transport, pi, browser);
}

void main() {
  test(
    'strongly typed browser RPC preserves path/status/parents and is read-only',
    () async {
      final (transport, pi, _) = await fixture();
      transport.onSend = (command) =>
          transport.reply(command, switch (command['type']) {
            'gui_list_files' => listing('/workspace'),
            'gui_get_file_preview' => preview('/workspace'),
            'gui_get_git_graph' => {
              'workspace': '/workspace',
              'root': '/workspace',
              'branch': 'main',
              'head': 'merge',
              'hasMore': true,
              'commits': [
                {
                  'hash': 'merge',
                  'parents': ['first', 'second'],
                  'author': '作者',
                  'date': '2026-01-01T12:00:00Z',
                  'subject': 'Merge',
                  'refs': ['refs/heads/main'],
                },
              ],
            },
            _ => null,
          });
      final tree = await pi.listFiles(
        '/workspace',
        '',
        force: true,
        limit: 1000,
      );
      expect(tree.entries.single.name, '文\n件.txt');
      expect(tree.entries.single.status, PiFileStatus.modified);
      expect(tree.entries.single.indexStatus, 'M');
      final graph = await pi.getGitGraph('/workspace', limit: 200);
      expect(graph.commits.single.parents, ['first', 'second']);
      expect(graph.hasMore, true);
      final file = await pi.getFilePreview(
        '/workspace',
        '文\n件.txt',
        commit: 'a' * 40,
      );
      expect(file.stagedDiff, '+stage');
      expect(file.workingDiff, '+work');
      expect(
        transport.commands.every(
          (command) => command['workspace'] == '/workspace',
        ),
        true,
      );
      expect(pi.hasUnsettledConversationMutation, false);
      expect(transport.closed, false);
      expect(transport.commands.map((command) => command['type']), [
        'gui_list_files',
        'gui_get_git_graph',
        'gui_get_file_preview',
      ]);
      expect(
        () => PiDirectoryListing.fromJson({
          ...listing('/workspace'),
          'entries': [
            {'status': 'mystery'},
          ],
        }),
        throwsA(anything),
      );
    },
  );

  test('shared directory reads and stale workspace responses cannot overwrite a newer tree or preview', () async {
    final (transport, _, browser) = await fixture();
    final pending = <Map<String, dynamic>>[];
    transport.onSend = pending.add;
    final old = browser.loadDirectory('');
    final duplicate = browser.loadDirectory('');
    expect(identical(old, duplicate), true);
    final oldPreview = browser.preview('file');
    final rejected = expectLater(oldPreview, throwsA(isA<PiRpcException>()));
    await tick();
    expect(pending.length, 2);
    browser.setWorkspace('/next');
    final next = browser.loadDirectory('');
    await tick();
    transport.reply(pending[2], listing('/next', name: 'new'));
    await next;
    transport.reply(pending[0], listing('/workspace', name: 'stale'));
    transport.reply(pending[1], preview('/workspace'));
    await Future.wait([old, duplicate, rejected]);
    expect(browser.directories['']!.entries.single.name, 'new');
    expect(browser.loadingDirectory(''), false);
    expect(browser.directoryErrors, isEmpty);
  });

  test('refresh merges a forced follow-up, preserves expansion, and exposes failures without dropping confirmed files', () async {
    final (transport, _, browser) = await fixture();
    transport.onSend = (command) => transport.reply(
      command,
      listing('/workspace', path: command['path'] as String),
    );
    browser.expanded.add('src');
    await browser.refresh();
    expect(browser.directories.keys, containsAll(['', 'src']));
    final pending = <Map<String, dynamic>>[];
    transport.onSend = pending.add;
    final first = browser.refresh(force: false);
    await tick();
    final forced = browser.refresh();
    expect(identical(first, forced), true);
    transport.reply(pending[0], listing('/workspace'));
    await tick();
    transport.reply(pending[1], listing('/workspace', path: 'src'));
    await tick();
    expect(pending.length, 3);
    expect(pending[2]['force'], true);
    transport.reply(pending[2], listing('/workspace'));
    await tick();
    transport.reply(pending[3], listing('/workspace', path: 'src'));
    await Future.wait([first, forced]);
    expect(browser.expanded, {'src'});
    transport.onSend = (command) => transport.emit({
      'type': 'response',
      'id': command['id'],
      'command': command['type'],
      'success': false,
      'error': 'DIRECTORY_UNAVAILABLE',
    });
    await browser.refresh();
    expect(browser.directories['']!.entries, isNotEmpty);
    expect(browser.directoryErrors[''], 'DIRECTORY_UNAVAILABLE');
    expect(browser.refreshing, false);
  });

  test('equivalent workspace paths accept all browser results and keep cached state', () async {
    final (transport, _, browser) = await fixture();
    // On Windows, reproduce Git's forward slashes versus Node's native path,
    // including casing. On POSIX, retain its case-sensitive path semantics.
    final cwd = p.absolute('Workspace');
    final alias = p.style == p.Style.windows
        ? cwd.replaceAll('\\', '/').toLowerCase()
        : '$cwd/.';
    browser.setWorkspace(alias);
    browser.tab = WorkspaceBrowserTab.graph;
    transport.onSend = (command) =>
        transport.reply(command, switch (command['type']) {
          'gui_list_files' => listing(cwd),
          'gui_get_git_graph' => {
            'workspace': cwd,
            'root': cwd,
            'branch': 'main',
            'head': null,
            'hasMore': false,
            'commits': <Object>[],
          },
          'gui_get_file_preview' => preview(cwd),
          'gui_get_git_commit' => {
            'workspace': cwd,
            'hash': 'a' * 40,
            'author': 'author',
            'message': 'initial',
            'date': '2026-01-01T12:00:00Z',
            'parents': <String>[],
            'files': <Object>[],
            'limited': false,
          },
          _ => null,
        });
    await browser.refresh();
    expect(browser.directories['']?.workspace, cwd);
    expect(browser.graph?.workspace, cwd);
    expect((await browser.preview('file')).workspace, cwd);
    expect((await browser.details('a' * 40)).workspace, cwd);
    final cached = browser.directories[''];
    browser.expanded.add('src');
    browser.selectFile('file');
    browser.setWorkspace(cwd);
    expect(browser.directories[''], same(cached));
    expect(browser.expanded, {'src'});
    expect(browser.selectedPath, 'file');
    expect(browser.directoryErrors, isEmpty);
    expect(browser.graphError, isNull);
    expect(browser.refreshing || browser.graphLoading, false);
  });

  test('a mismatched current response reports failure instead of indefinite loading', () async {
    final (transport, _, browser) = await fixture();
    transport.onSend = (command) =>
        transport.reply(command, switch (command['type']) {
          'gui_list_files' => listing('/different'),
          'gui_get_git_graph' => {
            'workspace': '/different',
            'root': '/different',
            'branch': null,
            'head': null,
            'hasMore': false,
            'commits': <Object>[],
          },
          _ => null,
        });
    browser.tab = WorkspaceBrowserTab.graph;
    await browser.refresh();
    expect(browser.directoryErrors[''], 'WORKSPACE_CHANGED');
    expect(browser.graphError, 'WORKSPACE_CHANGED');
    expect(browser.refreshing || browser.graphLoading, false);
    expect(browser.directories, isEmpty);
    expect(browser.graph, isNull);
  });

  test('DAG lanes preserve merge edges, join shared parents, and do not connect independent roots', () {
    final nodes = [
      const CommitGraphNode('merge', ['left', 'right', 'third']),
      const CommitGraphNode('left', ['base']),
      const CommitGraphNode('right', ['base']),
      const CommitGraphNode('third', ['base']),
      const CommitGraphNode('base', []),
      const CommitGraphNode('separate', ['unloaded']),
    ];
    final layout = CommitGraphLayout(nodes);
    expect(layout.rows.length, nodes.length);
    expect(layout.columns, 3);
    expect(layout.rows.first.incoming, false);
    expect(layout.rows[5].incoming, false);
    for (var i = 0; i < nodes.length; i++) {
      final row = layout.rows[i];
      expect(
        row.edges.where((edge) => edge.fromNode).length,
        nodes[i].parents.length,
      );
      expect(
        row.edges.every(
          (edge) =>
              edge.from >= 0 &&
              edge.to >= 0 &&
              edge.from < layout.columns &&
              edge.to < layout.columns,
        ),
        true,
      );
    }
    expect(layout.rows[4].edges, isEmpty);
    expect(layout.rows[5].edges.single.fromNode, true);
  });
}
