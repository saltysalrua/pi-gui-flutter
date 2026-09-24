import 'package:flutter/foundation.dart';
import 'package:pi_gui/core/rpc/pi_provider_profiles_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

/// Profiles are ordinary providers once saved: the plugin registers them and
/// picks up edits live, so this controller only reads/writes the config and
/// tracks which profile the settings page shows.
///
/// [error] holds a stable code (e.g. `PROFILE_INVALID`, `MODELS_UNAUTHORIZED`)
/// that the view maps to plain-language text; raw exceptions never reach UI.
class ProviderProfilesController extends ChangeNotifier {
  ProviderProfilesController(PiRpcClient control)
    : _service = PiProviderProfilesService(control);

  final PiProviderProfilesService _service;
  PiProviderProfilesState? state;
  String? error;
  bool busy = false;

  /// Name of the profile open in the detail pane; null = new profile draft.
  String? selected;

  /// Set after any successful write so the host can refresh model pickers.
  bool changed = false;
  bool _disposed = false;

  static String errorCode(Object error) {
    if (error is PiRpcException) {
      return error.outcomeUnknown ? 'OUTCOME_UNKNOWN' : error.message;
    }
    return 'PROVIDER_FAILED';
  }

  PiProviderProfile? get selectedProfile =>
      state?.profiles.where((p) => p.name == selected).firstOrNull;

  void select(String? name) {
    if (selected == name) return;
    selected = name;
    error = null;
    _notify();
  }

  Future<void> load() async {
    if (await _run(_service.state) && selectedProfile == null) {
      selected = state?.profiles.firstOrNull?.name;
      _notify();
    }
  }

  Future<bool> _run(
    Future<PiProviderProfilesState> Function() task, {
    bool write = false,
  }) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    _notify();
    try {
      final next = await task();
      if (_disposed) return false;
      state = next;
      if (write) changed = true;
      return true;
    } catch (e) {
      if (!_disposed) error = errorCode(e);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Read-only listing; independent of [busy] so the editor can fetch while
  /// the list stays interactive. Throws; callers map with [errorCode].
  Future<PiProviderModelList> fetchModels({
    String? name,
    required String baseUrl,
    required String api,
    String? apiKey,
    bool clearApiKey = false,
  }) => _service.fetchModels(
    name: name,
    baseUrl: baseUrl,
    api: api,
    apiKey: apiKey,
    clearApiKey: clearApiKey,
  );

  Future<bool> save({
    required String name,
    required String baseUrl,
    required String api,
    required bool syncModels,
    required List<PiProviderModel> models,
    List<String>? discovered,
    String? apiKey,
    bool createOnly = false,
    bool clearApiKey = false,
    String? renameFrom,
  }) async {
    final ok = await _run(
      () => _service.save(
        name: name,
        baseUrl: baseUrl,
        api: api,
        syncModels: syncModels,
        manual: [
          for (final m in models)
            if (m.manual) m.id,
        ],
        disabled: [
          for (final m in models)
            if (!m.enabled) m.id,
        ],
        listed: [for (final m in models) m.id],
        discovered: discovered,
        apiKey: apiKey,
        createOnly: createOnly,
        clearApiKey: clearApiKey,
        renameFrom: renameFrom,
      ),
      write: true,
    );
    if (ok) {
      selected = name;
      _notify();
    }
    return ok;
  }

  Future<bool> remove(String name) async {
    final ok = await _run(() => _service.remove(name), write: true);
    if (ok && selected == name) {
      selected = state?.profiles.firstOrNull?.name;
      _notify();
    }
    return ok;
  }

  void clearError() {
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
