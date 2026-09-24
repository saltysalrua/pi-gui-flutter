import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_provider_profiles_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/core/services/provider_plugin_installer.dart';
import 'package:pi_gui/ui/features/settings/controllers/provider_profiles_controller.dart';

import 'pi_rpc_client_test.dart' show TestTransport;

final profileState = {
  'profiles': [
    {
      'name': '猫饭',
      'api': 'openai-completions',
      'baseUrl': 'https://example.test/v1',
      'hasApiKey': true,
      'syncModels': true,
      'syncedAt': 1700000000000,
      'models': [
        {
          'id': 'gpt-5',
          'reasoning': true,
          'image': true,
          'contextWindow': 400000,
          'enabled': true,
          'discovered': true,
        },
        {'id': 'embed', 'enabled': false, 'discovered': true},
        {'id': 'alias', 'enabled': true, 'manual': true, 'custom': true},
      ],
    },
  ],
};

void main() {
  test('profile state maps models, badges and visibility', () {
    final state = PiProviderProfilesState.fromJson(profileState);
    final profile = state.profiles.single;
    expect(profile.name, '猫饭');
    expect(
      profile.syncedAt,
      DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    expect(profile.enabledCount, 2);
    final gpt = profile.models.first;
    expect([gpt.reasoning, gpt.image, gpt.contextWindow], [true, true, 400000]);
    expect(profile.models[1].enabled, isFalse);
    expect([profile.models[2].manual, profile.models[2].custom], [true, true]);
    expect(() => profile.models.add(gpt), throwsUnsupportedError);
    final list = PiProviderModelList.fromJson({
      'baseUrl': 'https://example.test/v1',
      'models': [
        {'id': 'model-a', 'reasoning': false},
      ],
    });
    expect(list.models.single.id, 'model-a');
    expect(list.models.single.enabled, isTrue, reason: 'listing defaults on');
  });

  test('installer reads the bundled version from an install path', () {
    expect(
      ProviderPluginInstaller.installedVersion(
        r'C:\Users\a\AppData\Roaming\x\pi-provider-switch\1.0.0\extensions\provider-switch.ts',
      ),
      '1.0.0',
    );
    expect(
      ProviderPluginInstaller.installedVersion('/opt/other/provider-switch.ts'),
      isNull,
    );
  });

  test('save sends manual/disabled/listed/discovered; key stays out', () async {
    final transport = TestTransport();
    final client = PiRpcClient(transportFactory: () async => transport);
    addTearDown(client.close);
    final controller = ProviderProfilesController(client);
    addTearDown(controller.dispose);
    transport.onSend = (request) => transport.reply(request, profileState);
    final ok = await controller.save(
      name: '猫饭',
      baseUrl: 'https://example.test/v1',
      api: 'openai-completions',
      syncModels: true,
      models: const [
        PiProviderModel(id: 'gpt-5', discovered: true),
        PiProviderModel(id: 'embed', enabled: false, discovered: true),
        PiProviderModel(id: 'alias', manual: true),
      ],
      discovered: const ['gpt-5', 'embed'],
      createOnly: true,
      clearApiKey: true,
    );
    expect(ok, isTrue);
    expect(controller.changed, isTrue);
    expect(controller.selected, '猫饭');
    final sent = transport.commands.single;
    expect(sent['createOnly'], isTrue);
    final profile = sent['profile'] as Map;
    expect(profile['manual'], ['alias']);
    expect(profile['disabled'], ['embed']);
    expect(profile['listed'], ['gpt-5', 'embed', 'alias']);
    expect(profile['discovered'], ['gpt-5', 'embed']);
    expect(profile['clearApiKey'], isTrue);
    expect(profile.containsKey('apiKey'), isFalse);
  });

  test('rename sends renameFrom; same name stays a plain save', () async {
    final transport = TestTransport();
    final client = PiRpcClient(transportFactory: () async => transport);
    addTearDown(client.close);
    final controller = ProviderProfilesController(client);
    addTearDown(controller.dispose);
    transport.onSend = (request) => transport.reply(request, profileState);
    Future<bool> base({
      required String name,
      String? renameFrom,
      bool createOnly = false,
    }) => controller.save(
      name: name,
      baseUrl: 'https://example.test/v1',
      api: 'openai-completions',
      syncModels: true,
      models: const [PiProviderModel(id: 'gpt-5')],
      createOnly: createOnly,
      renameFrom: renameFrom,
    );
    expect(await base(name: '新名字', renameFrom: '猫饭'), isTrue);
    expect(transport.commands.single['renameFrom'], '猫饭');
    expect(controller.selected, '新名字');
    transport.commands.clear();
    expect(await base(name: '猫饭', renameFrom: '猫饭'), isTrue);
    expect(
      transport.commands.single.containsKey('renameFrom'),
      isFalse,
      reason: 'unchanged name must not trigger a rename write',
    );
  });

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
}
