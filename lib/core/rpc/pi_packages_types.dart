import 'pi_rpc_client.dart';
import 'pi_rpc_types.dart';

/// One `settings.json` `packages` entry (same shape as `pi list`).
class PiPackageEntry {
  PiPackageEntry.fromJson(Object? value) : this._(rpcObject(value));
  PiPackageEntry._(Map<String, dynamic> json)
    : source = json['source'] as String,
      scope = json['scope'] as String,
      filtered = json['filtered'] == true,
      installedPath = json['installedPath'] as String?;
  final String source, scope;
  final bool filtered;
  final String? installedPath;

  /// `npm:pi-lens` -> `pi-lens`; bare git/local sources stay as-is.
  String get displayName {
    final stripped = source.startsWith('npm:')
        ? source.substring(4)
        : source.startsWith('git:')
        ? source.substring(4)
        : source;
    return stripped.split('@').first;
  }
}

/// One discovered resource row with the metadata `pi config` toggles on.
class PiResourceItem {
  PiResourceItem.fromJson(String type, Object? value)
    : this._(type, rpcObject(value));
  PiResourceItem._(this.type, Map<String, dynamic> json)
    : path = json['path'] as String,
      enabled = json['enabled'] == true,
      source = json['source'] as String,
      scope = json['scope'] as String,
      origin = json['origin'] as String,
      baseDir = json['baseDir'] as String?;
  final String type, path, source, scope, origin;
  final bool enabled;
  final String? baseDir;
  bool get isUserScope => scope == 'user';

  /// Row label: skills are directories named after the skill with a generic
  /// SKILL.md inside, so "find-skills" is the informative label, not the
  /// shared filename every skill row would otherwise show.
  String get displayName {
    final segments = path
        .split(RegExp(r'[\\/]'))
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) return path;
    final last = segments.last;
    if (segments.length >= 2 && last.toLowerCase() == 'skill.md') {
      return segments[segments.length - 2];
    }
    return last;
  }
}

/// Full management state: configured packages + resolved resources.
class PiPackagesState {
  PiPackagesState.fromJson(Object? value) : this._(rpcObject(value));
  PiPackagesState._(Map<String, dynamic> json)
    : agentDir = json['agentDir'] as String,
      packages = List.unmodifiable(
        (json['packages'] as List).map(PiPackageEntry.fromJson),
      ),
      resources = Map.unmodifiable(
        (json['resources'] as Map<String, dynamic>).map(
          (type, list) => MapEntry<String, List<PiResourceItem>>(
            type,
            List.unmodifiable(
              (list as List).map((item) => PiResourceItem.fromJson(type, item)),
            ),
          ),
        ),
      );
  final String agentDir;
  final List<PiPackageEntry> packages;
  final Map<String, List<PiResourceItem>> resources;
}

/// One available package update from the backend's npm/git probe.
class PiPackageUpdateInfo {
  PiPackageUpdateInfo.fromJson(Object? value) : this._(rpcObject(value));
  PiPackageUpdateInfo._(Map<String, dynamic> json)
    : source = json['source'] as String,
      displayName = json['displayName'] as String,
      type = json['type'] as String,
      scope = json['scope'] as String;
  final String source, displayName, type, scope;
}

/// Control-channel progress line emitted during install/remove/update.
class PiPackagesProgress {
  PiPackagesProgress.fromJson(Map<String, dynamic> json)
    : operationId = json['operationId'] as String?,
      phase = json['phase'] as String,
      action = json['action'] as String,
      source = json['source'] as String?,
      message = json['message'] as String?;
  final String? operationId, source, message;
  final String phase, action;
}

/// Terminal event of an async backend package operation.
class PiPackagesFinished {
  PiPackagesFinished.fromJson(Map<String, dynamic> json)
    : operationId = json['operationId'] as String,
      kind = json['kind'] as String,
      source = json['source'] as String?,
      ok = json['ok'] == true,
      error = json['error'] as String?,
      data = json['data'];
  final String operationId, kind;
  final String? source, error;
  final bool ok;
  final Object? data;

  PiPackagesState? get state => kind == 'check_updates'
      ? null
      : ok && data != null
      ? PiPackagesState.fromJson(data)
      : null;
  List<PiPackageUpdateInfo> get updates {
    if (kind != 'check_updates' || !ok) return const [];
    final list = rpcObject(data)['updates'];
    return List.unmodifiable((list as List).map(PiPackageUpdateInfo.fromJson));
  }
}

/// Typed management API over the control channel. Long operations answer
/// immediately with an operation id; results arrive as `gui_packages_finished`
/// events, which the caller collects from the client's event stream.
class PiPackagesService {
  PiPackagesService(this.client);
  final PiRpcClient client;

  Future<PiPackagesState> state() async => PiPackagesState.fromJson(
    await client.requestGui('gui_packages_state', {}),
  );

  Future<void> install(String operationId, String source) async {
    await client.requestGui('gui_packages_install', {
      'operationId': operationId,
      'source': source,
    });
  }

  Future<void> remove(String operationId, String source) async {
    await client.requestGui('gui_packages_remove', {
      'operationId': operationId,
      'source': source,
    });
  }

  Future<void> update(String operationId, {String? source}) async {
    await client.requestGui('gui_packages_update', {
      'operationId': operationId,
      'source': ?source,
    });
  }

  Future<void> checkUpdates(String operationId) async {
    await client.requestGui('gui_packages_check_updates', {
      'operationId': operationId,
    });
  }

  Future<PiPackagesState> toggle(PiResourceItem item, bool enabled) async =>
      PiPackagesState.fromJson(
        await client.requestGui('gui_packages_toggle', {
          'resourceType': item.type,
          'path': item.path,
          'enabled': enabled,
          'origin': item.origin,
          'source': item.source,
          'scope': item.scope,
          'baseDir': item.baseDir,
        }),
      );
}
