import 'pi_rpc_client.dart';
import 'pi_rpc_types.dart';

class PiProviderProfile {
  PiProviderProfile.fromJson(Object? value) : this._(rpcObject(value));
  PiProviderProfile._(Map<String, dynamic> json)
    : name = json['name'] as String,
      baseUrl = json['baseUrl'] as String,
      api = json['api'] as String,
      reasoning = json['reasoning'] == true,
      models = List<String>.unmodifiable(
        (json['models'] as List).cast<String>(),
      ),
      defaultModel = json['defaultModel'] as String?,
      hasApiKey = json['hasApiKey'] == true;
  final String name, baseUrl, api;
  final bool reasoning, hasApiKey;
  final List<String> models;
  final String? defaultModel;
}

class PiProviderProfilesState {
  PiProviderProfilesState.fromJson(Object? value) : this._(rpcObject(value));
  PiProviderProfilesState._(Map<String, dynamic> json)
    : active = json['active'] as String?,
      profiles = List<PiProviderProfile>.unmodifiable(
        (json['profiles'] as List).map(PiProviderProfile.fromJson),
      );
  final String? active;
  final List<PiProviderProfile> profiles;
}

/// Result of GET {baseUrl}/models; baseUrl may gain a missing `/v1`.
class PiProviderModelList {
  PiProviderModelList.fromJson(Object? value) : this._(rpcObject(value));
  PiProviderModelList._(Map<String, dynamic> json)
    : baseUrl = json['baseUrl'] as String,
      models = List<String>.unmodifiable(
        (json['models'] as List).cast<String>(),
      );
  final String baseUrl;
  final List<String> models;
}

/// Provider-switch owns provider-profiles.json. Only the Node adapter touches
/// that extension file; the Flutter UI exchanges typed control messages.
class PiProviderProfilesService {
  PiProviderProfilesService(this.client);
  final PiRpcClient client;

  Future<PiProviderProfilesState> state() async =>
      PiProviderProfilesState.fromJson(
        await client.requestGui('gui_provider_profiles_state', {}),
      );

  Future<PiProviderProfilesState> save({
    required String name,
    required String baseUrl,
    required String api,
    required bool reasoning,
    required List<String> models,
    required String defaultModel,
    String? apiKey,
    bool createOnly = false,
    bool clearApiKey = false,
  }) async => PiProviderProfilesState.fromJson(
    await client.requestGui('gui_provider_profiles_save', {
      'name': name,
      if (createOnly) 'createOnly': true,
      'profile': {
        'baseUrl': baseUrl,
        'api': api,
        'reasoning': reasoning,
        'models': models,
        'defaultModel': defaultModel,
        if (clearApiKey) 'clearApiKey': true,
        if (apiKey != null && apiKey.isNotEmpty) 'apiKey': apiKey,
      },
    }),
  );

  /// Lists models through the Node adapter. A blank [apiKey] makes the adapter
  /// reuse the saved key of [name]; the key itself never comes back.
  Future<PiProviderModelList> fetchModels({
    String? name,
    required String baseUrl,
    required String api,
    String? apiKey,
    bool clearApiKey = false,
  }) async => PiProviderModelList.fromJson(
    await client.requestGui('gui_provider_profiles_models', {
      if (name != null && name.isNotEmpty) 'name': name,
      'baseUrl': baseUrl,
      'api': api,
      if (clearApiKey) 'clearApiKey': true,
      if (apiKey != null && apiKey.isNotEmpty) 'apiKey': apiKey,
    }),
  );

  Future<PiProviderProfilesState> activate(String name) async =>
      PiProviderProfilesState.fromJson(
        await client.requestGui('gui_provider_profiles_activate', {
          'name': name,
        }),
      );

  Future<PiProviderProfilesState> remove(String name) async =>
      PiProviderProfilesState.fromJson(
        await client.requestGui('gui_provider_profiles_remove', {'name': name}),
      );
}
