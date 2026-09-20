import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/l10n/app_localizations.dart';
import 'package:pi_gui/ui/atoms/app_resize_divider.dart';
import 'package:pi_gui/ui/atoms/app_scale.dart';
import 'package:pi_gui/ui/atoms/app_split_panel.dart';
import 'package:pi_gui/ui/core/sidebar_layout_controller.dart';
import 'package:pi_gui/ui/core/theme/app_theme.dart';

void main() {
  for (final endPanel in [false, true]) {
    testWidgets(
      '${endPanel ? 'right' : 'left'} sidebar tracks the first move and bursts',
      (tester) async {
        const scale = 1.25;
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(1600, 900);
        addTearDown(tester.view.reset);
        final sidebar = SidebarLayoutController();
        addTearDown(sidebar.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => AppScale(scale: scale, child: child!),
            home: Scaffold(
              body: endPanel
                  ? AppSplitPanel(
                      isOpen: true,
                      onDismiss: () {},
                      contentBackground: Colors.transparent,
                      panelBackground: Colors.transparent,
                      panel: const SizedBox.expand(),
                      child: const SizedBox.expand(),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => ListenableBuilder(
                        listenable: sidebar,
                        builder: (context, _) => Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: sidebar.widthFor(constraints.maxWidth),
                            ),
                            AppResizeDivider(
                              onDelta: (dx) => sidebar.resizeBy(
                                dx,
                                viewportWidth: constraints.maxWidth,
                              ),
                              onReset: sidebar.reset,
                            ),
                            const Expanded(child: SizedBox.expand()),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        );
        final divider = find.byType(AppResizeDivider);
        final start = tester.getTopLeft(divider).dx;
        final direction = endPanel ? -1.0 : 1.0;
        final gesture = await tester.startGesture(
          tester.getCenter(divider),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(Offset(direction * 30 * scale, 0));
        await tester.pump();
        expect(
          tester.getTopLeft(divider).dx,
          closeTo(start + direction * 30 * scale, 0.01),
          reason: 'Do not discard the move that starts the drag.',
        );
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(Offset(direction * 3 * scale, 0));
        }
        await tester.pump();
        expect(
          tester.getTopLeft(divider).dx,
          closeTo(start + direction * 90 * scale, 0.01),
        );

        // Width constraints still apply, but overshooting must not delay a
        // reversal. Both directions can arrive before any frame is built.
        await gesture.moveBy(Offset(direction * 2000 * scale, 0));
        await gesture.moveBy(Offset(direction * 20 * scale, 0));
        await gesture.moveBy(Offset(-direction * 15 * scale, 0));
        await tester.pump();
        final edge = endPanel ? 1280 - (640 - 15) - 10 : 480 - 15;
        expect(tester.getTopLeft(divider).dx, closeTo(edge * scale, 0.01));
        await gesture.cancel();
        await tester.pumpAndSettle();

        // The shared divider must retain its double-click reset gesture.
        await tester.tap(divider, kind: PointerDeviceKind.mouse);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(divider, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(divider).dx, closeTo(start, 0.01));
      },
    );
  }
}
