import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_transport.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

final modelJson = {
  'id': 'same-id',
  'name': 'Same name',
  'provider': 'custom',
  'reasoning': true,
};

class TestTransport implements PiRpcTransport {
  final output = StreamController<List<int>>();
  final commands = <Map<String, dynamic>>[];
  void Function(Map<String, dynamic>)? onSend;
  bool closed = false;
  Future<void>? sendResult;
  @override
  Stream<List<int>> get stdout => output.stream;
  @override
  Future<void> send(String line) async {
    // Sends can run from a callback during a lifecycle test's frame pump.
    expectSync(line.endsWith('\n'), isTrue);
    expectSync(line.split('\n').length, 2);
    final command = jsonDecode(line) as Map<String, dynamic>;
    commands.add(command);
    onSend?.call(command);
    await sendResult;
  }

  void emit(Map<String, Object?> json) =>
      output.add(utf8.encode('${jsonEncode(json)}\n'));
  void reply(Map<String, dynamic> request, Object? data) => emit({
    'id': request['id'],
    'type': 'response',
    'command': request['type'],
    'success': true,
    'data': data,
  });
  @override
  Future<void> close() async {
    closed = true;
    final closing = output.close();
    if (output.hasListener) await closing;
  }
}

void main() {
  test(
    'strict JSONL preserves Unicode separators and fragmented UTF-8',
    () async {
      final records = [
        jsonEncode({'text': '中文😀\u2028\u2029\r\n'}),
        jsonEncode({'name': '尾行'}),
      ];
      final bytes = utf8.encode('${records.first}\r\n${records.last}');
      final result = await decodePiJsonl(
        Stream.fromIterable(bytes.map((byte) => [byte])),
      ).toList();
      expect(result, records);
      expect(jsonDecode(result.first)['text'], '中文😀\u2028\u2029\r\n');
    },
  );

  test('JSONL handles a large fragmented record, split CRLF, empty lines and an EOF tail', () async {
    final large = jsonEncode({'text': '中文😀\u2028\u2029' * 20000});
    final chunks = <List<int>>[utf8.encode('\n\r\n')];
    final bytes = utf8.encode(large);
    for (var i = 0; i < bytes.length; i += 8191) {
      chunks.add(
        bytes.sublist(i, i + 8191 < bytes.length ? i + 8191 : bytes.length),
      );
    }
    chunks.addAll([utf8.encode('\r'), utf8.encode('\n\nsmall\r\nlast\r')]);
    expect(await decodePiJsonl(Stream.fromIterable(chunks)).toList(), [
      large,
      'small',
      'last',
    ]);
  });

  test(
    'correlates reversed responses and preserves extension UI events',
    () async {
      final transport = TestTransport();
      final pi = PiRpcClient(transportFactory: () async => transport);
      addTearDown(pi.close);
      final events = <PiRpcEvent>[];
      final subscription = pi.events.listen(events.add);
      addTearDown(subscription.cancel);
      transport.onSend = (_) {
        if (transport.commands.length != 2) return;
        transport.emit({
          'type': 'extension_ui_request',
          'id': 'ui-1',
          'method': 'setWidget',
          'widgetKey': 'test',
          'widgetLines': ['中文\u2028text'],
        });
        transport.reply(transport.commands[1], {
          'levels': ['off', 'low', 'high', 'xhigh'],
        });
        transport.reply(transport.commands[0], {
          'models': [modelJson],
        });
      };
      final models = pi.getAvailableModels();
      final levels = pi.getAvailableThinkingLevels();
      expect((await models).single.provider, 'custom');
      expect(await levels, [
        PiThinkingLevel.off,
        PiThinkingLevel.low,
        PiThinkingLevel.high,
        PiThinkingLevel.xhigh,
      ]);
      expect(events.whereType<PiExtensionUiRequest>().single.widgetLines, [
        '中文\u2028text',
      ]);
      transport.onSend = (request) => transport.reply(
        request,
        request['type'] == 'set_model' ? modelJson : null,
      );
      await pi.setModel(PiModel.fromJson(modelJson));
      expect(transport.commands.last, containsPair('provider', 'custom'));
      expect(transport.commands.last, containsPair('modelId', 'same-id'));
      await pi.setThinkingLevel(PiThinkingLevel.minimal);
      expect(transport.commands.last, containsPair('level', 'minimal'));
    },
  );

  test(
    'command errors are typed; malformed response rejects instead of hanging',
    () async {
      final transport = TestTransport();
      final pi = PiRpcClient(transportFactory: () async => transport);
      addTearDown(pi.close);
      transport.onSend = (request) => transport.emit({
        'type': 'response',
        'id': request['id'],
        'command': request['type'],
        'success': false,
        'error': 'No API key',
      });
      await expectLater(
        pi.setModel(PiModel.fromJson(modelJson)),
        throwsA(
          isA<PiRpcException>().having(
            (e) => e.command,
            'command',
            'set_model',
          ),
        ),
      );
      transport.onSend = (request) => transport.emit({
        'type': 'response',
        'id': request['id'],
        'command': request['type'],
        'success': false,
        'error': 42,
      });
      await expectLater(pi.getState(), throwsA(isA<FormatException>()));
      expect(pi.isConnected, isTrue);
      expect(transport.closed, isFalse);
    },
  );

  test('read timeout does not kill Pi; late responses cannot change later requests', () async {
    final transport = TestTransport();
    final pi = PiRpcClient(
      transportFactory: () async => transport,
      requestTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(pi.close);
    await expectLater(pi.getState(), throwsA(isA<PiRpcException>()));
    final old = transport.commands.single;
    transport.onSend = (request) {
      transport.reply(old, {'model': modelJson, 'thinkingLevel': 'high'});
      transport.reply(request, {'model': null, 'thinkingLevel': 'off'});
    };
    expect((await pi.getState()).model, isNull);
    expect(transport.closed, isFalse);
    expect(pi.connectionCount, 1);
  });

  test(
    'stdout noise and one invalid UI event do not interrupt valid responses',
    () async {
      final transport = TestTransport();
      final pi = PiRpcClient(transportFactory: () async => transport);
      addTearDown(pi.close);
      transport.onSend = (request) {
        if (request['type'] != 'get_state') return;
        transport.output.add(utf8.encode('[extension] background log\n'));
        transport.emit({
          'type': 'extension_ui_request',
          'id': 'bad-ui',
          'method': 'input',
          'options': [42],
        });
        transport.reply(request, {'model': modelJson, 'thinkingLevel': 'high'});
      };
      expect((await pi.getState()).model!.id, 'same-id');
      expect(pi.isConnected, isTrue);
      expect(transport.closed, isFalse);
      expect(pi.diagnostics.map((d) => d.kind), [
        PiRpcDiagnosticKind.nonProtocolLine,
        PiRpcDiagnosticKind.invalidEvent,
      ]);
      expect(
        transport.commands.last,
        containsPair('type', 'extension_ui_response'),
      );
      expect(transport.commands.last, containsPair('cancelled', true));
    },
  );

  test(
    'timed-out mutation is not replayed and must settle before state reads',
    () async {
      final transport = TestTransport();
      final pi = PiRpcClient(
        transportFactory: () async => transport,
        requestTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(pi.close);
      await expectLater(
        pi.setModel(PiModel.fromJson(modelJson)),
        throwsA(isA<PiRpcException>()),
      );
      final mutation = transport.commands.single;
      final reading = pi.getState();
      await Future<void>.delayed(Duration.zero);
      expect(transport.commands, hasLength(1));
      transport.onSend = (request) => transport.reply(request, {
        'model': modelJson,
        'thinkingLevel': 'high',
      });
      transport.reply(mutation, modelJson);
      expect((await reading).model!.provider, 'custom');
      expect(
        transport.commands.where((command) => command['type'] == 'set_model'),
        hasLength(1),
      );
      expect(transport.closed, isFalse);
    },
  );

  test(
    'late send failure from an old connection cannot close a new connection',
    () async {
      final first = TestTransport();
      final second = TestTransport();
      var starts = 0;
      final lateSend = Completer<void>();
      first.sendResult = lateSend.future;
      first.onSend = (request) =>
          first.reply(request, {'model': null, 'thinkingLevel': 'off'});
      second.onSend = (request) =>
          second.reply(request, {'model': modelJson, 'thinkingLevel': 'high'});
      final pi = PiRpcClient(
        transportFactory: () async => starts++ == 0 ? first : second,
      );
      addTearDown(pi.close);
      await pi.getState();
      first.output.addError(StateError('old pipe closed'));
      await Future<void>.delayed(Duration.zero);
      expect((await pi.getState()).model!.id, 'same-id');
      lateSend.completeError(StateError('late flush failure'));
      await Future<void>.delayed(Duration.zero);
      expect(pi.isConnected, isTrue);
      expect(second.closed, isFalse);
      expect(pi.connectionCount, 2);
    },
  );

  test(
    'process EOF rejects pending requests and close is safe during startup',
    () async {
      final transport = TestTransport();
      final pi = PiRpcClient(transportFactory: () async => transport);
      transport.onSend = (_) {
        unawaited(transport.output.close());
      };
      await expectLater(pi.getState(), throwsA(isA<PiRpcException>()));
      await pi.close();
      final gate = Completer<PiRpcTransport>();
      final started = Completer<void>();
      final starting = PiRpcClient(
        transportFactory: () {
          started.complete();
          return gate.future;
        },
      );
      final connection = starting.connect();
      final check = expectLater(connection, throwsA(isA<PiRpcException>()));
      await started.future;
      final closing = starting.close();
      final lateTransport = TestTransport();
      gate.complete(lateTransport);
      await check;
      await closing;
      expect(lateTransport.closed, isTrue);
    },
  );
}
