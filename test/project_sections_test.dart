import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pi_gui/core/rpc/pi_catalog_types.dart';
import 'package:pi_gui/core/rpc/pi_channel_hub.dart';
import 'package:pi_gui/ui/features/home/controllers/workbench_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport;
import 'parallel_session_test.dart' show reply;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog accepts legacy sections and preserves virtual identity independently of paths', () {
    final legacy = {
      'projects': <Object>[],
      'channels': <Object>[],
      'jobs': <Object>[],
    };
    expect(PiCatalog.fromJson(legacy).sections, isEmpty);
    final catalog = PiCatalog.fromJson({
      ...legacy,
      'sections': [
        {'id': 'group-1', 'name': 'Projects', 'collapsed': true},
        {'id': 'group-2', 'name': 'Projects', 'collapsed': false},
      ],
      'projects': [
        {
          'path': '/real/Projects',
          'name': 'Projects',
          'sectionId': 'group-2',
          'branches': <String>[],
          'worktrees': <Object>[],
        },
      ],
    });
    expect(catalog.sections.map((s) => s.id), ['group-1', 'group-2']);
    expect(catalog.sections.first.collapsed, true);
    expect(catalog.projects.single.sectionId, 'group-2');
    expect(catalog.projects.single.path, '/real/Projects');
  });

  test('conversation sidebar retains child histories without reading files or launching channels', () async {
    final root = p.absolute('project');
    final child = p.join(root, 'src');
    final transport = TestTransport();
    final workbench = WorkbenchController(
      hub: PiChannelHub(() async => transport),
    );
    String? sectionId;
    var fileReads = 0;
    transport.onSend = (packet) {
      final command = packet['message'] as Map;
      switch (command['type']) {
        case 'gui_get_catalog':
          reply(transport, packet, {
            'sections': [
              {'id': 'work', 'name': '工作'},
            ],
            'projects': [
              {
                'path': root,
                'name': 'project',
                'sectionId': sectionId,
                'branches': <String>[],
                'worktrees': [
                  {'path': root, 'name': 'project', 'main': true},
                  {'path': child, 'name': 'src', 'folder': true},
                ],
              },
            ],
            'channels': <Object>[],
            'jobs': <Object>[],
          });
        case 'gui_list_files':
          fileReads++;
          throw StateError('Conversation navigation must not read files');
        case 'gui_workspace_history':
          reply(transport, packet, {'sessions': <Object>[]});
        case 'gui_move_project':
          sectionId = command['sectionId'] as String?;
          reply(transport, packet, null);
        default:
          throw StateError('Unexpected command ${command['type']}');
      }
    };
    addTearDown(() async {
      await workbench.shutdown();
      workbench.dispose();
    });
    await workbench.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(fileReads, 0);
    expect(workbench.history.containsKey(child), true);
    final childAlias = p.style == p.Style.windows
        ? child.replaceAll('\\', '/').toUpperCase()
        : '$child/.';
    workbench.history[childAlias] = workbench.history[child]!;
    expect(
      workbench.workspacesForProject(workbench.catalog!.projects.single),
      [root, child],
    );
    final browser = workbench.browserFor(root);
    await workbench.moveProject(root, 'work');
    expect(workbench.catalog!.projects.single.sectionId, 'work');
    expect(workbench.history.containsKey(child), true);
    expect(
      workbench.workspacesForProject(workbench.catalog!.projects.single),
      contains(child),
    );
    expect(workbench.browserFor(root), same(browser));
    expect(fileReads, 0);
    expect(
      transport.commands.where(
        (packet) => (packet['message'] as Map)['type'] == 'gui_open_channel',
      ),
      isEmpty,
    );
    workbench.toggleProject(root);
    workbench.toggleProject(root);
    await Future<void>.delayed(Duration.zero);
    expect(fileReads, 0);
  });
}
