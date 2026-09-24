import 'pi_rpc_client.dart';
import 'pi_rpc_types.dart';

/// One model row of a provider profile, with capability badges resolved by
/// the plugin's shared catalog (explicit settings > rules > models.dev).
class PiProviderModel {
  PiProviderModel.fromJson(Object? value) : this._(rpcObject(value));
  PiProviderModel._(Map<String, dynamic> json)
    : id = json['id'] as String,
      reasoning = json['reasoning'] == true,
      image = json['image'] == true,
      contextWindow = (json['contextWindow'] as num?)?.toInt(),
      enabled = json['enabled'] != false,
      manual = json['manual'] == true,
      discovered = json['discovered'] == true,
      custom = json['custom'] == true;
  const PiProviderModel({
    required this.id,
    this.reasoning = false,
    this.image = false,
    this.contextWindow,
    this.enabled = true,
    this.manual = false,
    this.discovered = false,
    this.custom = false,
  });
  final String id;
  final bool reasoning, image, enabled, manual, discovered, custom;
  final int? contextWindow;

  PiProviderModel copyWith({bool? enabled, bool? manual, bool? discovered}) =>
      PiProviderModel(
        id: id,
        reasoning: reasoning,
        image: image,
        contextWindow: contextWindow,
        enabled: enabled ?? this.enabled,
        manual: manual ?? this.manual,
        discovered: discovered ?? this.discovered,
        custom: custom,
      );
}

class PiProviderProfile {
  PiProviderProfile.fromJson(Object? value) : this._(rpcObject(value));
  PiProviderProfile._(Map<String, dynamic> json)
    : name = json['name'] as String,
      baseUrl = json['baseUrl'] as String,
      api = json['api'] as String,
      hasApiKey = json['hasApiKey'] == true,
      syncModels = json['syncModels'] != false,
      syncedAt = json['syncedAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['syncedAt'] as num).toInt(),
            )
          : null,
      models = List<PiProviderModel>.unmodifiable(
        (json['models'] as List).map(PiProviderModel.fromJson),
      );
  final String name, baseUrl, api;
  final bool hasApiKey, syncModels;

  /// Last successful /models listing for the current endpoint, if any.
  final DateTime? syncedAt;
  final List<PiProviderModel> models;
  int get enabledCount => models.where((m) => m.enabled).length;
}

class PiProviderProfilesState {
  PiProviderProfilesState.fromJson(Object? value) : this._(rpcObject(value));
  PiProviderProfilesState._(Map<String, dynamic> json)
    : profiles = List<PiProviderProfile>.unmodifiable(
        (json['profiles'] as List).map(PiProviderProfile.fromJson),
      );
  final List<PiProviderProfile> profiles;
}

/// Result of GET {baseUrl}/models; baseUrl may gain a missing `/v1`.
class PiProviderModelList {
  PiProviderModelList.fromJson(Object? value) : this._(rpcObject(value));
  PiProviderModelList._(Map<String, dynamic> json)
    : baseUrl = json['baseUrl'] as String,
      models = List<PiProviderModel>.unmodifiable(
        (json['models'] as List).map(PiProviderModel.fromJson),
      );
  final String baseUrl;
  final List<PiProviderModel> models;
}

/// pi-provider-switch owns provider-profiles.json. Only the Node adapter
/// touches that file; the Flutter UI exchanges typed control messages.
class PiProviderProfilesService {
  PiProviderProfilesService(this.client);
  final PiRpcClient client;

  Future<PiProviderProfilesState> state() async =>
      PiProviderProfilesState.fromJson(
        await client.requestGui('gui_provider_profiles_state', {}),
      );

  /// [discovered] is the fresh listing from this edit (written to the
  /// plugin's cache, never into the config); [listed] is every id the editor
  /// showed, so legacy 1.x entries survive until the first listing.
  /// [renameFrom] renames an existing profile: the entry and its discovered
  /// cache move to [name] in one write.
  Future<PiProviderProfilesState> save({
    required String name,
    required String baseUrl,
    required String api,
    required bool syncModels,
    required List<String> manual,
    required List<String> disabled,
    required List<String> listed,
    List<String>? discovered,
    String? apiKey,
    bool createOnly = false,
    bool clearApiKey = false,
    String? renameFrom,
  }) async => PiProviderProfilesState.fromJson(
    await client.requestGui('gui_provider_profiles_save', {
      'name': name,
      if (createOnly) 'createOnly': true,
      if (renameFrom != null && renameFrom != name) 'renameFrom': renameFrom,
      'profile': {
        'baseUrl': baseUrl,
        'api': api,
        'syncModels': syncModels,
        'manual': manual,
        'disabled': disabled,
        'listed': listed,
        'discovered': ?discovered,
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

  Future<PiProviderProfilesState> remove(String name) async =>
      PiProviderProfilesState.fromJson(
        await client.requestGui('gui_provider_profiles_remove', {'name': name}),
      );
}
