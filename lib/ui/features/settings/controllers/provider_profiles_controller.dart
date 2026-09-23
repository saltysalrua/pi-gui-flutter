import 'package:flutter/foundation.dart';
import 'package:pi_gui/core/rpc/pi_provider_profiles_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

/// The active session is resolved at click time, never cached across tabs.
///
/// [error] holds a stable code (e.g. `PROFILE_INVALID`, `MODELS_UNAUTHORIZED`)
/// that the view maps to plain-language text; raw exceptions never reach UI.
class ProviderProfilesController extends ChangeNotifier {
  ProviderProfilesController(PiRpcClient control, this.activeClient)
    : _service = PiProviderProfilesService(control);

  final PiProviderProfilesService _service;
  final PiRpcClient? Function() activeClient;
  PiProviderProfilesState? state;
  String? error;
  bool busy = false;

  /// Result of the last activation: true = current session switched, false =
  /// only the default changed (next session), null = none/failed.
  bool? switchedCurrentSession;
  String? lastActivated;
  bool _disposed = false;

  static String errorCode(Object error) {
    if (error is PiRpcException) {
      return error.outcomeUnknown ? 'OUTCOME_UNKNOWN' : error.message;
    }
    return 'PROVIDER_FAILED';
  }

  Future<void> load() async => _run(_service.state);

  Future<bool> _run(Future<PiProviderProfilesState> Function() task) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    switchedCurrentSession = null;
    lastActivated = null;
    notifyListeners();
    try {
      final next = await task();
      if (_disposed) return false;
      state = next;
      return true;
    } catch (e) {
      if (!_disposed) error = errorCode(e);
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
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
    required bool reasoning,
    required List<String> models,
    required String defaultModel,
    String? apiKey,
    bool createOnly = false,
    bool clearApiKey = false,
  }) => _run(
    () => _service.save(
      name: name,
      baseUrl: baseUrl,
      api: api,
      reasoning: reasoning,
      models: models,
      defaultModel: defaultModel,
      apiKey: apiKey,
      createOnly: createOnly,
      clearApiKey: clearApiKey,
    ),
  );

  Future<bool> remove(String name) => _run(() => _service.remove(name));

  void clearMessages() {
    error = null;
    switchedCurrentSession = null;
    lastActivated = null;
    if (!_disposed) notifyListeners();
  }

  Future<bool> activate(String name) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    switchedCurrentSession = null;
    lastActivated = name;
    notifyListeners();
    try {
      // The plugin owns current-session registration and model change. Never
      // prompt an absent /switch: Pi would send it to the model instead.
      final current = activeClient();
      bool available = false;
      if (current != null) {
        try {
          available = await current.hasProviderSwitchCommand();
        } catch (_) {
          // Offline sessions pick up the default on their next start.
        }
      }
      if (_disposed) return false;
      if (available) {
        final before = await current!.getState();
        if (before.isStreaming ||
            before.isCompacting ||
            before.pendingMessageCount > 0 ||
            current.hasUnsettledConversationMutation) {
          error = 'PROFILE_SESSION_BUSY';
          return false;
        }
        await current.prompt('/switch $name');
        // Command dispatch alone is not proof of a successful model change.
        final selected = await current.getState();
        state = await _service.state();
        final profile = state?.profiles
            .where((p) => p.name == name)
            .firstOrNull;
        final expectedModel =
            profile?.defaultModel ?? profile?.models.firstOrNull;
        if (selected.model?.provider != name ||
            selected.model?.id != expectedModel ||
            state?.active != name) {
          error = 'PROFILE_ACTIVATE_FAILED';
          return false;
        }
        switchedCurrentSession = true;
      } else {
        state = await _service.activate(name);
        switchedCurrentSession = false;
      }
      return !_disposed;
    } catch (e) {
      if (!_disposed) error = errorCode(e);
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
