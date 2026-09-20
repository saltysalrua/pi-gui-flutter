import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_history_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/l10n/app_localizations.dart';
import 'package:pi_gui/l10n/app_localizations_en.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
import 'package:pi_gui/ui/core/theme/app_theme.dart';
import 'package:pi_gui/ui/features/home/controllers/history_controller.dart';
import 'package:pi_gui/ui/features/home/widgets/history_dialog.dart';

import 'history_test.dart' show FakeHistory;

class _PreviewFailure extends FakeHistory {
  bool failPreview = true;
  @override
  Future<Map<String, dynamic>> entry(PiHistorySnapshot snapshot, String id) {
    if (failPreview) throw const PiRpcException('UNKNOWN_COMMAND');
    return super.entry(snapshot, id);
  }
}

void main() {
  // Regression for shared-controller lifecycle, not a layout/style assertion:
  // the real chat subscribes behind the Navigator route as well as the dialog.
  testWidgets(
    'opening history never notifies the subscribed page during route build; preview failure can retry',
    (tester) async {
      final events = StreamController<PiRpcEvent>.broadcast();
      final api = _PreviewFailure();
      final history = HistoryController(
        api,
        events: events.stream,
        canMutate: () => true,
        onLock: (_) {},
        onCommitted: (_, _, _) async {},
      );
      final l10n = AppLocalizationsEn();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ListenableBuilder(
            listenable: history,
            builder: (context, _) => Scaffold(
              body: Center(
                child: AppActionButton(
                  label: l10n.historyTitle,
                  onPressed: () => showAppDialog<void>(
                    context,
                    (_) => HistoryDialog(
                      controller: history,
                      hasDraft: () => false,
                      onAbort: () async {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(AppActionButton, l10n.historyTitle));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(history.isOpen, true);
      expect(history.loading, false);
      expect(history.failure, 'UNKNOWN_COMMAND');
      expect(history.preview, isNull);
      expect(find.text(l10n.historyPreviewFailed), findsOneWidget);

      api.failPreview = false;
      await tester.tap(find.widgetWithText(AppActionButton, l10n.chatRefresh));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(history.failure, isNull);
      expect(history.preview?['id'], history.selectedId);
      expect(find.text(l10n.historyPreviewFailed), findsNothing);

      await tester.tap(find.widgetWithText(AppActionButton, l10n.close));
      await tester.pumpAndSettle();
      expect(history.isOpen, false);
      expect(history.snapshot, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      history.dispose();
      await events.close();
    },
  );
}
