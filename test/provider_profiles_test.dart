import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_provider_profiles_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/features/settings/controllers/provider_profiles_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport;

final profileState = {
  'active': 'gateway',
  'profiles': [
    {
      'name': 'gateway',
      'api': 'openai-responses',
      'baseUrl': 'https://example.test/v1',
      'models': ['model-a', 'model-b'],
      'defaultModel': 'model-b',
      'reasoning': true,
      'hasApiKey': true,
    },
  ],
};

void main() {
  test('profile listing and model discovery map public metadata', () {
    final state = PiProviderProfilesState.fromJson(profileState);
    expect(state.active, 'gateway');
    expect(state.profiles.single.models, ['model-a', 'model-b']);
    expect(state.profiles.single.defaultModel, 'model-b');
    expect(state.profiles.single.hasApiKey, isTrue);
    final list = PiProviderModelList.fromJson({
      'baseUrl': 'https://example.test/v1',
      'models': ['model-a', 'model-b'],
    });
    expect(list.models, ['model-a', 'model-b']);
    expect(() => list.models.add('oops'), throwsUnsupportedError);
  });

  test(
    'discovery needs no model ID; key removal and create-only reach RPC',
    () async {
      final transport = TestTransport();
      final client = PiRpcClient(transportFactory: () async => transport);
      addTearDown(client.close);
      final service = PiProviderProfilesService(client);
      transport.onSend = (request) => transport.reply(
        request,
        request['type'] == 'gui_provider_profiles_models'
            ? {
                'baseUrl': 'https://example.test/v1',
                'models': ['model-a'],
              }
            : profileState,
      );
      final list = await service.fetchModels(
        baseUrl: 'https://example.test',
        api: 'openai-responses',
      );
      expect(transport.commands.single.containsKey('models'), isFalse);
      expect(transport.commands.single.containsKey('apiKey'), isFalse);
      await service.save(
        name: 'gateway',
        baseUrl: list.baseUrl,
        api: 'openai-responses',
        reasoning: false,
        models: list.models,
        defaultModel: list.models.first,
        createOnly: true,
        clearApiKey: true,
      );
      final saved = transport.commands.last;
      expect(saved['createOnly'], isTrue);
      expect(saved['profile']['clearApiKey'], isTrue);
      expect(saved['profile'].containsKey('apiKey'), isFalse);
    },
  );

  test(
    'timed-out save keeps a barrier until the original write settles',
    () async {
      final transport = TestTransport();
      final client = PiRpcClient(
        transportFactory: () async => transport,
        requestTimeout: const Duration(milliseconds: 40),
      );
      addTearDown(client.close);
      await expectLater(
        client.requestGui('gui_provider_profiles_save', {}),
        throwsA(
          isA<PiRpcException>().having(
            (e) => e.outcomeUnknown,
            'unknown result',
            isTrue,
          ),
        ),
      );
      final refresh = client.requestGui('gui_provider_profiles_state', {});
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(transport.commands.length, 1);
      transport.onSend = (request) => transport.reply(request, profileState);
      transport.reply(transport.commands.single, profileState);
      expect(await refresh, profileState);
      expect(transport.commands.map((c) => c['type']), [
        'gui_provider_profiles_save',
        'gui_provider_profiles_state',
      ]);
      expect(transport.closed, isFalse);
    },
  );

  for (final mode in ['missing', 'wrong-source', 'busy', 'success', 'failed']) {
    test(
      'activation: $mode does not send an unsafe or unverified switch',
      () async {
        final controlTransport = TestTransport();
        final sessionTransport = TestTransport();
        final control = PiRpcClient(
          transportFactory: () async => controlTransport,
        );
        final session = PiRpcClient(
          transportFactory: () async => sessionTransport,
        );
        final controller = ProviderProfilesController(control, () => session);
        addTearDown(() async {
          controller.dispose();
          await control.close();
          await session.close();
        });
        var prompted = false;
        controlTransport.onSend = (request) =>
            controlTransport.reply(request, profileState);
        sessionTransport.onSend = (request) {
          final Object? data = switch (request['type']) {
            'get_commands' => {
              'commands': mode == 'missing'
                  ? []
                  : [
                      {
                        'name': 'switch',
                        'source': 'extension',
                        'path': mode == 'wrong-source'
                            ? '/extensions/unrelated.ts'
                            : '/package/extensions/provider-switch.ts',
                      },
                    ],
            },
            'get_state' => {
              'isStreaming': mode == 'busy',
              'model': {
                'id': prompted && mode == 'success' ? 'model-b' : 'model-a',
                'provider': 'gateway',
                'name': 'Test',
                'reasoning': true,
              },
              'thinkingLevel': 'off',
            },
            _ => null,
          };
          if (request['type'] == 'prompt') prompted = true;
          sessionTransport.reply(request, data);
        };
        await controller.load();
        final ok = await controller.activate('gateway');
        expect(ok, mode != 'busy' && mode != 'failed');
        expect(prompted, mode == 'success' || mode == 'failed');
        if (mode == 'missing' || mode == 'wrong-source') {
          expect(controller.switchedCurrentSession, isFalse);
          expect(
            controlTransport.commands.last['type'],
            'gui_provider_profiles_activate',
          );
        } else if (mode == 'busy') {
          expect(controller.error, 'PROFILE_SESSION_BUSY');
          expect(
            controlTransport.commands.any(
              (c) => c['type'] == 'gui_provider_profiles_activate',
            ),
            isFalse,
          );
        } else if (mode == 'failed') {
          expect(controller.error, 'PROFILE_ACTIVATE_FAILED');
          expect(controller.switchedCurrentSession, isNull);
        } else {
          expect(controller.switchedCurrentSession, isTrue);
          expect(
            sessionTransport.commands.singleWhere(
              (c) => c['type'] == 'prompt',
            )['message'],
            '/switch gateway',
          );
        }
      },
    );
  }
}
