import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:pi_gui/core/models/chat_timeline.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

/// Opt-in real model probe. Only uses a disposable temp directory.
Future<void> main(List<String> arguments) async {
  final imageIndex = arguments.indexOf('--with-image');
  if (imageIndex >= 0 && imageIndex + 1 >= arguments.length) {
    throw ArgumentError('--with-image requires a PNG path');
  }
  final imagePath = imageIndex < 0 ? null : arguments[imageIndex + 1];
  final withModel = arguments.contains('--with-model') || imagePath != null;
  final directory = await Directory.systemTemp.createTemp('pi-gui-chat-check-');
  final pi = PiRpcClient(
    workingDirectory: directory.path,
    extraArguments: [
      '--no-session',
      '--no-extensions',
      '--no-skills',
      '--no-prompt-templates',
    ],
  );
  final timeline = ChatTimeline();
  final settled = Completer<void>();
  final eventCounts = <String, int>{};
  final subscription = pi.events.listen((event) {
    if (event is PiChatEvent) {
      eventCounts.update(event.type, (v) => v + 1, ifAbsent: () => 1);
      timeline.apply(event);
      if (event.type == 'agent_settled' && !settled.isCompleted) {
        settled.complete();
      }
    }
  });
  try {
    await pi.getState();
    if (!await pi.newSession()) throw StateError('New session cancelled');
    if ((await pi.getMessages()).isNotEmpty) {
      throw StateError('Probe did not start empty');
    }
    await pi.clearQueue();
    await pi.abort();
    if (withModel) {
      final levels = await pi.getAvailableThinkingLevels();
      if (levels.contains(PiThinkingLevel.off)) {
        await pi.setThinkingLevel(PiThinkingLevel.off);
      }
      if (imagePath != null) {
        final bytes = await File(imagePath).readAsBytes();
        if (bytes.length > 10 * 1024 * 1024 ||
            bytes.length < 8 ||
            !List.generate(
              8,
              (i) => bytes[i] == [137, 80, 78, 71, 13, 10, 26, 10][i],
            ).every((v) => v)) {
          throw ArgumentError('Use a PNG no larger than 10 MB');
        }
        final image = PiImage(data: base64Encode(bytes), mimeType: 'image/png');
        await pi.prompt(
          'Describe the attached image in one short sentence. Do not use any tools or change any files.',
          images: [image],
        );
        await settled.future.timeout(const Duration(seconds: 150));
        final saved = await pi.getMessages();
        if (!saved
            .where((m) => m.role == 'user')
            .any((m) => m.content.any((b) => b.image?.data == image.data))) {
          throw StateError('Image did not survive RPC history');
        }
        final reply = saved
            .where((m) => m.role == 'assistant' && m.text.isNotEmpty)
            .lastOrNull;
        if (reply == null ||
            reply.stopReason == 'error' ||
            timeline.tools.isNotEmpty) {
          throw StateError('Image probe did not produce a clean no-tool reply');
        }
        stdout.writeln(jsonEncode({'imageReply': reply.text}));
      } else {
        final file = File('${directory.path}/sample.txt');
        await file.writeAsString('hello before\n');
        await pi.prompt(
          'Use the edit tool exactly once on sample.txt, replacing "hello before" with "hello after". '
          'Do not use any other tools or files. Then reply with a short Markdown heading, a two-item list, '
          'and a fenced code block showing the new text.',
        );
        await settled.future.timeout(const Duration(seconds: 150));
        if (await file.readAsString() != 'hello after\n') {
          throw StateError('Edit was not applied');
        }
        final changed = timeline.tools.values
            .where((t) => t.isFileChange)
            .toList();
        if (changed.isEmpty ||
            changed.every(
              (t) => t.result?.patch == null && t.result?.diff == null,
            )) {
          throw StateError('No backend diff received');
        }
        final saved = await pi.getMessages();
        if (saved
            .where((m) => m.role == 'assistant' && m.text.isNotEmpty)
            .isEmpty) {
          throw StateError('No persisted reply');
        }
      }
    }
    stdout.writeln(
      jsonEncode({
        'withModel': withModel,
        'withImage': imagePath != null,
        'connections': pi.connectionCount,
        'events': eventCounts,
        'messages': timeline.messages.length,
        'fileChanges': timeline.tools.values
            .where((t) => t.isFileChange)
            .length,
        'diagnostics': pi.diagnostics.map((d) => d.kind.name).toList(),
      }),
    );
  } finally {
    await subscription.cancel();
    await pi.close();
    await directory.delete(recursive: true);
  }
}
