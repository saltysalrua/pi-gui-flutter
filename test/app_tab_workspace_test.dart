import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/l10n/app_localizations.dart';
import 'package:pi_gui/ui/atoms/app_document_tabs.dart';
import 'package:pi_gui/ui/atoms/app_tab_workspace.dart';
import 'package:pi_gui/ui/core/app_tabs_controller.dart';
import 'package:pi_gui/ui/core/theme/app_theme.dart';

/// Mirrors the real chat body: one ScrollController per mount, one scrollable
/// with an explicit PageStorageKey, and lifecycle visible from the test.
class _ProbeBody extends StatefulWidget {
  const _ProbeBody({
    required this.id,
    required this.bodies,
    required this.unloaded,
  });
  final int id;
  final Map<int, ScrollController> bodies;
  final List<int> unloaded;
  @override
  State<_ProbeBody> createState() => _ProbeBodyState();
}

class _ProbeBodyState extends State<_ProbeBody> {
  late final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    widget.bodies[widget.id] = _scroll;
  }

  @override
  void dispose() {
    widget.bodies.remove(widget.id);
    widget.unloaded.add(widget.id);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const PageStorageKey('probe-body'),
    controller: _scroll,
    itemCount: 100,
    itemBuilder: (context, index) =>
        SizedBox(height: 100, child: Text('item ${widget.id}.$index')),
  );
}

Future<void> _pump(
  WidgetTester tester,
  AppTabsController<int> controller,
  Map<int, ScrollController> bodies,
  List<int> unloaded,
) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: AppTabWorkspace<int>(
        controller: controller,
        describeTab: (tab) => AppDocumentTab(
          id: tab,
          label: 'Tab $tab',
          icon: Icons.description_outlined,
        ),
        builder: (context, tab) =>
            _ProbeBody(id: tab, bodies: bodies, unloaded: unloaded),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'hidden tab bodies unload while their scroll anchors survive in PageStorage',
    (tester) async {
      final controller = AppTabsController<int>(home: 0);
      addTearDown(controller.dispose);
      controller.open(1);
      controller.open(2);
      final bodies = <int, ScrollController>{};
      final unloaded = <int>[];
      await _pump(tester, controller, bodies, unloaded);

      // Bounded retention: only the selected pane ever mounts its heavy body.
      expect(bodies.keys, [2]);
      bodies[2]!.position.jumpTo(500);

      controller.activate(1);
      await tester.pump();
      expect(bodies.keys, [1]);
      expect(unloaded, [2]);

      // Coming back rebuilds from the controller and restores the offset.
      controller.activate(2);
      await tester.pump();
      expect(bodies.keys, [2]);
      expect(bodies[2]!.position.pixels, 500);

      // Closing the active tab drops its body, the previous tab takes over.
      controller.close(2);
      await tester.pump();
      expect(bodies.keys, [1]);
      expect(unloaded, [2, 1, 2]);
    },
  );

  testWidgets('split keeps both on-screen panes mounted and unloads the rest', (
    tester,
  ) async {
    final controller = AppTabsController<int>(home: 0);
    addTearDown(controller.dispose);
    controller.open(1);
    controller.open(2);
    controller.split(2);
    final bodies = <int, ScrollController>{};
    final unloaded = <int>[];
    await _pump(tester, controller, bodies, unloaded);

    // 800 px fits two 300 px panes: both selected bodies stay alive.
    expect(bodies.keys, unorderedEquals([1, 2]));
    expect(unloaded, isEmpty);

    // Narrowing below the compact threshold unloads the inactive group.
    tester.view.physicalSize = const Size(1200, 900); // 400x300 logical.
    addTearDown(tester.view.reset);
    await tester.pump();
    expect(bodies.keys, [2]); // The active group only.
    expect(unloaded, [1]);
  });
}
