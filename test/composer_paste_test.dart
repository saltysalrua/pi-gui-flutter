import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/core/theme/app_theme.dart';

void main() {
  testWidgets(
    'Ctrl+V intercepts images but delegates text selection replacement and undo',
    (tester) async {
      final controller = TextEditingController(text: 'before after');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var handled = true, calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') return {'text': 'TEXT'};
            if (call.method == 'Clipboard.hasStrings') return {'value': true};
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              focusNode: focus,
              hintText: '',
              onPaste: () async {
                calls++;
                return handled;
              },
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await tester.pump(const Duration(milliseconds: 600));
      Future<void> shortcut(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
      }

      await shortcut(LogicalKeyboardKey.keyV);
      expect(calls, 1);
      expect(controller.text, 'before after');
      handled = false;
      await shortcut(LogicalKeyboardKey.keyV);
      expect(calls, 2);
      expect(controller.text, 'TEXT after');
      await tester.pump(const Duration(milliseconds: 600));
      await shortcut(LogicalKeyboardKey.keyZ);
      expect(controller.text, 'before after');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'delayed text fallback does not overwrite subsequent edits',
    (tester) async {
      final controller = TextEditingController(text: 'original');
      final focus = FocusNode();
      final pending = Completer<bool>();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              focusNode: focus,
              hintText: '',
              onPaste: () => pending.future,
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      controller.text = 'new draft';
      pending.complete(false);
      await tester.pump();
      expect(controller.text, 'new draft');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
