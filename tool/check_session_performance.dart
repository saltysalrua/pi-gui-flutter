// Synthetic data only: no Pi process, user history, model requests or GUI state.
// Run with `dart run tool/check_session_performance.dart [tool-call-count ...]`.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pi_gui/core/models/chat_timeline.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_transport.dart';

double medianMs(List<int> microseconds) {
  microseconds.sort();
  return microseconds[microseconds.length ~/ 2] / 1000;
}

List<Map<String, Object?>> fixture(int calls) => [
  for (var i = 0; i < calls; i++) ...[
    {
      'role': 'assistant',
      'timestamp': i * 2,
      'content': [
        {'type': 'text', 'text': 'Checking file $i'},
        {
          'type': 'toolCall',
          'id': 'call-$i',
          'name': 'read',
          'arguments': {'path': 'src/file-$i.dart'},
        },
      ],
    },
    {
      'role': 'toolResult',
      'toolCallId': 'call-$i',
      'toolName': 'read',
      'timestamp': i * 2 + 1,
      'content': [
        {'type': 'text', 'text': '中文 source line\n' * 24},
      ],
    },
  ],
];

Future<Map<String, Object>> measure(int calls, int repeats) async {
  final payload = jsonEncode({
    'type': 'response',
    'id': 'synthetic',
    'command': 'get_messages',
    'success': true,
    'data': {'messages': fixture(calls)},
  });
  final bytes = utf8.encode('$payload\n');
  final chunks = [
    for (var i = 0; i < bytes.length; i += 65536)
      Uint8List.sublistView(bytes, i, math.min(i + 65536, bytes.length)),
  ];
  final framing = <int>[],
      decoding = <int>[],
      mapping = <int>[],
      loading = <int>[];
  for (var sample = 0; sample < repeats; sample++) {
    final watch = Stopwatch()..start();
    final lines = await decodePiJsonl(Stream.fromIterable(chunks)).toList();
    framing.add(watch.elapsedMicroseconds);
    if (lines.length != 1 || lines.single != payload) {
      throw StateError('JSONL framing changed the payload');
    }
    watch.reset();
    final decoded = jsonDecode(lines.single) as Map<String, dynamic>;
    decoding.add(watch.elapsedMicroseconds);
    watch.reset();
    final history = List<PiChatMessage>.unmodifiable(
      (decoded['data']['messages'] as List).map(PiChatMessage.fromJson),
    );
    mapping.add(watch.elapsedMicroseconds);
    final timeline = ChatTimeline();
    watch.reset();
    timeline.load(history);
    loading.add(watch.elapsedMicroseconds);
    if (timeline.messages.length != calls || timeline.tools.length != calls) {
      throw StateError('Timeline lost or duplicated tool references');
    }
  }
  return {
    'toolCalls': calls,
    'records': calls * 2,
    'payloadMiB': bytes.length / 1024 / 1024,
    'medianMs': {
      'jsonl64KiBChunks': medianMs(framing),
      'jsonDecode': medianMs(decoding),
      'typedMapping': medianMs(mapping),
      'timelineLoad': medianMs(loading),
    },
  };
}

Future<void> main(List<String> args) async {
  final sizes = args.isEmpty ? [1000, 5000] : args.map(int.parse).toList();
  if (sizes.any((size) => size < 1 || size > 50000)) {
    throw ArgumentError('Use 1–50000 tool calls per sample');
  }
  await measure(200, 3); // Warm up before reporting steady-state medians.
  for (final count in sizes) {
    stdout.writeln(jsonEncode(await measure(count, 5)));
  }
}
