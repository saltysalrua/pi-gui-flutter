import 'pi_rpc_client.dart';
import 'pi_rpc_types.dart';

/// State of one built-in runtime hook, mirrored from
/// `assets/backend/gui_hooks.mjs`. Persisted by the backend in its own
/// `hooks.json`; Pi's `settings.json` is never touched.
enum PiHookState {
  active,
  off,
  removed;

  static PiHookState fromName(String? name) => switch (name) {
    'off' => PiHookState.off,
    'removed' => PiHookState.removed,
    _ => PiHookState.active,
  };
}

/// One built-in hook row (e.g. the write-diff observer or the history
/// bridge) injected into every newly started Pi process via `--extension`.
class PiHookItem {
  PiHookItem.fromJson(Object? value) : this._(rpcObject(value));

  PiHookItem._(Map<String, dynamic> json)
    : id = json['id'] as String,
      file = json['file'] as String,
      state = PiHookState.fromName(json['state'] as String?);

  final String id, file;
  final PiHookState state;

  /// The hook id the UI maps i18n name/description text onto.
  String get key => 'hooks_${id}_name';
}

/// Full `gui_hooks_state` payload: every built-in hook plus a backend
/// persistence warning flag.
class PiHooksState {
  PiHooksState.fromJson(Object? value) : this._(rpcObject(value));
  PiHooksState._(Map<String, dynamic> json)
    : hooks = List.unmodifiable(
        ((json['hooks'] as List?) ?? const [])
            .map((item) => PiHookItem.fromJson(item)),
      ),
      persistenceWarning = json['persistenceWarning'] == true;
  final List<PiHookItem> hooks;
  final bool persistenceWarning;
}

/// Typed management API over the shared control channel. Both commands
/// answer synchronously; a state change is honored by Pi processes started
/// afterwards (running sessions keep the hooks they launched with).
class PiHooksService {
  PiHooksService(this.client);
  final PiRpcClient client;

  Future<PiHooksState> state() async => PiHooksState.fromJson(
    await client.requestGui('gui_hooks_state', {}),
  );

  Future<PiHooksState> set(String id, PiHookState state) async =>
      PiHooksState.fromJson(
        await client.requestGui('gui_hooks_set', {
          'hookId': id,
          'state': state.name,
        }),
      );
}