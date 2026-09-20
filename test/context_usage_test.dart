import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/features/home/controllers/context_usage_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport, modelJson;

Map<String, Object?> stats({int? tokens = 12000, String session = 'a'}) => {
  'sessionId': session,
  'tokens': {
    'total': 9999999,
  }, // Cumulative billing is intentionally unrelated.
  'contextUsage': {
    'tokens': tokens,
    'contextWindow': 200000,
    'percent': tokens == null ? null : tokens / 2000,
  },
};

Future<void> tick() => Future<void>.delayed(Duration.zero);

class FakeContextGateway implements PiContextGateway {
  final stream = StreamController<PiRpcEvent>.broadcast(sync: true);
  PiContextUsage? usage = PiContextUsage.fromSessionStats(stats());
  Completer<PiContextUsage?>? pending;
  int reads = 0;
  @override
  Stream<PiRpcEvent> get events => stream.stream;
  @override
  Future<PiContextUsage?> getContextUsage() async {
    reads++;
    return pending?.future ?? usage;
  }
}

void main() {
  test(
    'native stats decode current usage, unknown/old versions and over-limit',
    () {
      final usage = PiContextUsage.fromSessionStats(stats())!;
      expect(usage.tokens, 12000);
      expect(usage.percent, 6);
      expect(usage.contextWindow, 200000);
      expect(
        PiContextUsage.fromSessionStats(stats(tokens: null))?.percent,
        isNull,
      );
      expect(
        PiContextUsage.fromSessionStats(stats(tokens: 240000))?.percent,
        120,
      );
      expect(
        PiContextUsage.fromSessionStats({
          'sessionId': 'old',
          'tokens': {'total': 50000},
        }),
        isNull,
      );
      for (final invalid in [
        {'tokens': -1},
        {'tokens': 1.5},
        {'contextWindow': 0},
        {'percent': double.nan},
      ]) {
        expect(
          () => PiContextUsage.fromSessionStats({
            ...stats(),
            'contextUsage': {...stats()['contextUsage'] as Map, ...invalid},
          }),
          throwsFormatException,
        );
      }
    },
  );

  test('coalesces reads, ignores deltas and discards stale model/session responses', () async {
    final pi = FakeContextGateway(), otherPi = FakeContextGateway();
    final controller = ContextUsageController(pi),
        other = ContextUsageController(otherPi);
    addTearDown(() async {
      controller.dispose();
      other.dispose();
      await pi.stream.close();
      await otherPi.stream.close();
    });
    await controller.refresh();
    await other.refresh();
    for (var i = 0; i < 20; i++) {
      pi.stream.add(const PiAgentEvent('message_update', {}));
    }
    expect(pi.reads, 1);
    final pending = pi.pending = Completer<PiContextUsage?>();
    final read = controller.refresh();
    pi.stream.add(const PiContextUsageInvalidated());
    expect(controller.usage, isNull);
    pi.usage = PiContextUsage.fromSessionStats(
      stats(tokens: 18000, session: 'b'),
    );
    pi.pending = null;
    pending.complete(PiContextUsage.fromSessionStats(stats()));
    await read;
    await tick();
    expect(controller.usage?.sessionId, 'b');
    expect(controller.usage?.tokens, 18000);
    expect(pi.reads, 3);
    expect(other.usage?.sessionId, 'a');
    expect(otherPi.reads, 1);
    pi.usage = PiContextUsage.fromSessionStats(
      stats(tokens: null, session: 'b'),
    );
    pi.stream.add(const PiAgentEvent('compaction_end', {}));
    await tick();
    expect(controller.usage?.percent, isNull);
    expect(controller.usage?.contextWindow, 200000);
    final stale = pi.pending = Completer<PiContextUsage?>();
    final finalRead = controller.refresh();
    pi.stream.add(const PiRpcDisconnected());
    expect(controller.usage, isNull);
    final reads = pi.reads;
    await controller.refresh();
    expect(pi.reads, reads); // Never wake a disconnected/hibernated session.
    pi.pending = null;
    pi.usage = PiContextUsage.fromSessionStats(stats(session: 'reconnected'));
    pi.stream.add(const PiRpcConnected());
    stale.complete(PiContextUsage.fromSessionStats(stats()));
    await finalRead;
    await tick();
    expect(controller.usage?.sessionId, 'reconnected');
  });

  test(
    'RPC uses native stats and model acknowledgement refreshes only telemetry',
    () async {
      final transport = TestTransport();
      final pi = PiRpcClient(transportFactory: () async => transport);
      final controller = ContextUsageController(pi);
      addTearDown(() async {
        controller.dispose();
        await pi.close();
      });
      var snapshot = stats();
      transport.onSend = (request) => transport.reply(
        request,
        request['type'] == 'get_session_stats' ? snapshot : modelJson,
      );
      await controller.refresh();
      expect(transport.commands.single['type'], 'get_session_stats');
      expect(controller.usage?.percent, 6);
      snapshot = stats(tokens: 24000);
      await pi.setModel(PiModel.fromJson(modelJson));
      await tick();
      expect(controller.usage?.percent, 12);
      snapshot = {
        'sessionId': 'old',
        'tokens': {'total': 9999},
      };
      await controller.refresh();
      expect(controller.usage, isNull);
      snapshot = {
        'sessionId': 'a',
        'contextUsage': {'tokens': 'broken'},
      };
      await controller.refresh();
      expect(controller.usage, isNull);
      expect(pi.isConnected, isTrue);
    },
  );
}
