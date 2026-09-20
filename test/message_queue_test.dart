import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/features/home/controllers/chat_controller.dart';

import 'chat_rpc_test.dart' show FakeChatGateway, event, tick;
import 'pi_rpc_client_test.dart' show TestTransport;

void main() {
  test('prompt policies and images cross RPC unchanged; malformed queues are isolated', () async {
    final transport = TestTransport();
    final pi = PiRpcClient(transportFactory: () async => transport);
    addTearDown(pi.close);
    transport.onSend = (request) => transport.reply(request, null);
    const image = PiImage(data: 'aGVsbG8=', mimeType: 'image/png');
    await pi.prompt('idle');
    for (final policy in PiStreamingBehavior.values) {
      await pi.prompt(
        '/template arg',
        images: [image],
        streamingBehavior: policy,
      );
      expect(transport.commands.last['type'], 'prompt');
      expect(transport.commands.last['streamingBehavior'], policy.name);
      expect(transport.commands.last['images'], [image.toJson()]);
    }
    expect(transport.commands.first.containsKey('streamingBehavior'), false);
    final chat = ChatController(pi);
    addTearDown(chat.dispose);
    transport.emit({
      'type': 'queue_update',
      'steering': ['same', 'same'],
      'followUp': ['later'],
    });
    await tick();
    expect(chat.queue.all, ['same', 'same', 'later']);
    transport.emit({'type': 'queue_update', 'steering': 'broken'});
    await tick();
    expect(chat.queue.all, ['same', 'same', 'later']);
    expect(chat.failure, ChatFailure.invalidEvent);
    expect(pi.isConnected, true);
  });

  test('live submissions use native queues without optimistic messages or unlocking the run', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    await chat.refresh();
    pi.stream.add(event('agent_start'));
    expect(chat.canSend, false);
    expect(chat.canSubmit, true);
    pi.pendingPrompt = Completer<void>();
    final sending = chat.send('steer');
    expect(pi.sentBehavior, PiStreamingBehavior.steer);
    expect(chat.canSubmit, false);
    expect(await chat.send('duplicate'), false);
    pi.stream.add(
      event('queue_update', {
        'steering': ['expanded steer'],
        'followUp': [],
      }),
    );
    pi.pendingPrompt!.complete();
    expect(await sending, true);
    expect(chat.canSubmit, true);
    expect(chat.timeline.messages, isEmpty);
    expect(chat.queue.steering, ['expanded steer']);
    pi.pendingPrompt = null;
    expect(
      await chat.send('later', streamingBehavior: PiStreamingBehavior.followUp),
      true,
    );
    expect(pi.sentBehavior, PiStreamingBehavior.followUp);
    pi.stream.add(event('agent_end'));
    expect(chat.isRunning, true);
    expect(chat.canSwitch, false);
    pi.stream.add(
      event('queue_update', {
        'steering': [],
        'followUp': ['later'],
      }),
    );
    expect(chat.queue.all, ['later']);
    pi.stream.add(event('compaction_start'));
    expect(
      await chat.send('keep draft'),
      false,
    ); // Native RPC rejects during compaction.
    pi.stream.add(event('compaction_end'));
    expect(chat.canSubmit, true);
    pi.pendingPrompt = Completer<void>();
    final rejected = chat.send('rejected');
    pi.pendingPrompt!.completeError(const PiRpcException('rejected'));
    expect(await rejected, false);
    expect(chat.queue.all, ['later']);
    pi.pendingPrompt = null;
    pi.stream.add(event('queue_update', {'steering': [], 'followUp': []}));
    pi.stream.add(event('agent_settled'));
    await tick();
    expect(chat.canSend, true);
    expect(chat.queue.isEmpty, true);
    expect(
      await chat.send(
        'idle race',
        streamingBehavior: PiStreamingBehavior.followUp,
      ),
      true,
    );
    expect(
      pi.sentBehavior,
      PiStreamingBehavior.followUp,
    ); // Pi starts immediately if already idle.
    await tick();
  });

  test('dequeue is exclusive, does not abort, and cannot overwrite a newer queue event', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    await chat.refresh();
    pi.stream.add(event('agent_start'));
    pi.stream.add(
      event('queue_update', {
        'steering': ['old'],
        'followUp': ['later'],
      }),
    );
    pi.pendingQueue = Completer<PiPromptQueue>();
    final taking = chat.takeQueue();
    expect(chat.canSubmit, false);
    expect(chat.canSwitch, false);
    expect(await chat.takeQueue(), isEmpty);
    expect(await chat.stop(), isEmpty);
    pi.stream.add(event('queue_update', {'steering': [], 'followUp': []}));
    pi.stream.add(
      event('queue_update', {
        'steering': ['new from extension'],
        'followUp': [],
      }),
    );
    pi.pendingQueue!.complete(
      const PiPromptQueue(steering: ['old'], followUp: ['later']),
    );
    expect(await taking, ['old', 'later']);
    expect(chat.queue.all, ['new from extension']);
    expect(chat.isRunning, true);
    expect(pi.commands.where((c) => c == 'clear_queue').length, 1);
    expect(pi.commands, isNot(contains('abort')));
    pi.pendingQueue = Completer<PiPromptQueue>();
    final failed = chat.takeQueue();
    pi.pendingQueue!.completeError(const PiRpcException('rejected'));
    expect(await failed, isEmpty);
    expect(chat.failure, ChatFailure.queue);
    expect(chat.queue.all, ['new from extension']);
    expect(chat.canTakeQueue, true);
  });

  test(
    'queue snapshots belong to one session and disconnect never replays them',
    () async {
      final first = FakeChatGateway(), second = FakeChatGateway();
      final a = ChatController(first), b = ChatController(second);
      addTearDown(() async {
        a.dispose();
        b.dispose();
        await first.stream.close();
        await second.stream.close();
      });
      await a.refresh();
      await b.refresh();
      first.stream.add(
        event('queue_update', {
          'steering': ['first'],
          'followUp': [],
        }),
      );
      second.stream.add(
        event('queue_update', {
          'steering': [],
          'followUp': ['second'],
        }),
      );
      expect(a.canSwitch, false);
      first.stream.add(const PiRpcDisconnected());
      expect(a.queue.isEmpty, true);
      expect(a.canSubmit, false);
      expect(b.queue.all, ['second']);
      first.stream.add(const PiRpcConnected());
      await tick();
      expect(first.commands.where((c) => c.startsWith('prompt:')), isEmpty);
      expect(b.queue.all, ['second']);
    },
  );

  test('settled during dequeue waits for its acknowledgement before refreshing readiness', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    await chat.refresh();
    pi.stream.add(event('agent_start'));
    pi.stream.add(
      event('queue_update', {
        'steering': ['take'],
        'followUp': [],
      }),
    );
    pi.pendingQueue = Completer<PiPromptQueue>();
    final taking = chat.takeQueue();
    pi.hasUnsettledConversationMutation = true;
    pi.stream.add(event('agent_settled'));
    await tick();
    expect(pi.commands.where((c) => c == 'get_state').length, 1);
    pi.hasUnsettledConversationMutation = false;
    pi.pendingQueue!.complete(const PiPromptQueue(steering: ['take']));
    expect(await taking, ['take']);
    await tick();
    expect(chat.canSubmit, true);
    expect(pi.commands.where((c) => c == 'get_state').length, 2);
  });

  test('uncertain clear_queue retains the write barrier; a rejected clear cannot abort', () async {
    for (final malformed in [false, true]) {
      final transport = TestTransport();
      final pi = PiRpcClient(
        transportFactory: () async => transport,
        requestTimeout: const Duration(milliseconds: 30),
      );
      try {
        if (malformed) {
          transport.onSend = (request) =>
              transport.reply(request, {'steering': []});
        }
        await expectLater(
          pi.clearQueue(),
          throwsA(
            isA<PiRpcException>().having(
              (e) => e.outcomeUnknown,
              'outcome unknown',
              true,
            ),
          ),
        );
        expect(pi.hasUnsettledConversationMutation, true);
        final clearing = transport.commands.single;
        await expectLater(
          pi.prompt('must not bypass'),
          throwsA(isA<PiRpcException>()),
        );
        expect(transport.commands.length, 1);
        transport.reply(clearing, {'steering': [], 'followUp': []});
        await tick();
        expect(pi.hasUnsettledConversationMutation, false);
        expect(pi.isConnected, true);
      } finally {
        await pi.close();
      }
    }
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(() async {
      chat.dispose();
      await pi.stream.close();
    });
    await chat.refresh();
    pi.stream.add(event('agent_start'));
    pi.pendingQueue = Completer<PiPromptQueue>();
    final stopping = chat.stop();
    pi.stream.add(event('agent_settled'));
    pi.stream.add(
      event('agent_start'),
    ); // A native continuation raced the stop.
    expect(chat.canSubmit, false);
    expect(chat.canStop, false);
    expect(chat.canSwitch, false);
    pi.pendingQueue!.completeError(const PiRpcException('clear failed'));
    expect(await stopping, isEmpty);
    expect(pi.commands, isNot(contains('abort')));
    expect(chat.canStop, true);
    pi.pendingQueue = null;
    expect(await chat.stop(), ['next']);
    expect(
      pi.commands.indexOf('clear_queue'),
      lessThan(pi.commands.indexOf('abort')),
    );
    await tick();
  });
}
