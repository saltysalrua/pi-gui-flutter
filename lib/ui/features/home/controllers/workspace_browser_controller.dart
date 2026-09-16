import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pi_gui/core/rpc/pi_browser_types.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';

enum WorkspaceBrowserTab { files, graph }

/// Read-only UI state; shares HomeView's RPC and never locks the conversation.
class WorkspaceBrowserController extends ChangeNotifier {
  WorkspaceBrowserController(this._pi) {
    _events = _pi.events.listen(_onEvent);
  }
  final PiBrowserGateway _pi;
  late final StreamSubscription<PiRpcEvent> _events;
  String? workspace;
  bool isOpen = false;
  WorkspaceBrowserTab tab = WorkspaceBrowserTab.files;
  final directories = <String, PiDirectoryListing>{};
  final expanded = <String>{};
  final directoryErrors = <String, String>{};
  final _directoryLoads = <String, Future<void>>{};
  final _directoryLimits = <String, int>{};
  PiGitGraph? graph;
  String? graphError;
  int graphLimit = 100;
  String? selectedPath, selectedCommit;
  bool _disposed = false, _dirty = true, _refreshAgain = false;
  int _generation = 0, _revision = 0;
  Future<void>? _refreshing, _graphLoad;
  Timer? _debounce;
  static const _refreshDelay = Duration(milliseconds: 500);

  bool get refreshing => _refreshing != null;
  bool get graphLoading => _graphLoad != null;
  bool loadingDirectory(String path) => _directoryLoads.containsKey(path);
  int directoryLimit(String path) => _directoryLimits[path] ?? 500;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String errorCode(Object error) =>
      error is PiRpcException ? error.message : 'BROWSER_FAILED';
  bool _current(int generation, int revision, String cwd) =>
      !_disposed &&
      generation == _generation &&
      revision == _revision &&
      workspace == cwd;

  void setWorkspace(String? path) {
    if (_disposed ||
        workspace == path ||
        (workspace != null && path != null && p.equals(workspace!, path))) {
      return;
    }
    workspace = path;
    _generation++;
    _revision++;
    _debounce?.cancel();
    directories.clear();
    directoryErrors.clear();
    expanded.clear();
    _directoryLoads.clear();
    _directoryLimits.clear();
    graph = null;
    graphError = null;
    graphLimit = 100;
    selectedPath = selectedCommit = null;
    _refreshing = _graphLoad = null;
    _refreshAgain = false;
    _dirty = true;
    _notify();
    if (isOpen && path != null) unawaited(refresh());
  }

  void toggle() {
    isOpen = !isOpen;
    _notify();
    if (isOpen) unawaited(ensureLoaded());
  }

  void showFiles([String? path]) {
    isOpen = true;
    tab = WorkspaceBrowserTab.files;
    final cwd = workspace;
    final generation = _generation;
    String? relative;
    if (path != null && cwd != null) {
      final target = p.normalize(p.isAbsolute(path) ? path : p.join(cwd, path));
      if (p.isWithin(cwd, target)) {
        relative = p.relative(target, from: cwd).replaceAll('\\', '/');
      }
    }
    selectedPath = relative;
    _notify();
    unawaited(() async {
      await ensureLoaded();
      if (relative == null || _disposed || generation != _generation) return;
      final parts = relative.split('/')..removeLast();
      for (var i = 1; i <= parts.length; i++) {
        if (_disposed || generation != _generation) return;
        final folder = parts.take(i).join('/');
        expanded.add(folder);
        await loadDirectory(folder);
      }
      _notify();
    }());
  }

  void selectTab(WorkspaceBrowserTab value) {
    tab = value;
    _notify();
    unawaited(ensureLoaded());
  }

  Future<void> ensureLoaded() async {
    if (_disposed || workspace == null || !isOpen) return;
    if (_dirty || directories.isEmpty) {
      await refresh(force: false);
    } else if (tab == WorkspaceBrowserTab.graph && graph == null) {
      await loadGraph();
    }
  }

  void refreshIfOpen() {
    if (isOpen) {
      unawaited(refresh());
    } else {
      _dirty = true;
    }
  }

  void _onEvent(PiRpcEvent event) {
    if (event is PiRpcWorkspaceReset) {
      setWorkspace(null);
    } else if (event is PiRpcWorkspaceChanged) {
      setWorkspace(event.path);
    } else if (event is PiRpcDisconnected) {
      _generation++;
      _refreshing = _graphLoad = null;
      _directoryLoads.clear();
      directoryErrors[''] = graphError = 'DISCONNECTED';
      _dirty = true;
      _notify();
    } else if (event is PiRpcConnected) {
      refreshIfOpen();
    } else if (event is PiChatEvent &&
        const {'tool_execution_end', 'agent_settled'}.contains(event.type)) {
      _dirty = true;
      if (!isOpen) return;
      _debounce?.cancel();
      _debounce = Timer(_refreshDelay, () => unawaited(refresh()));
    }
  }

  Future<void> refresh({bool force = true}) {
    if (_disposed || workspace == null) return Future.value();
    if (_refreshing case final loading?) {
      _refreshAgain |= force;
      return loading;
    }
    final completion = Completer<void>();
    _refreshing = completion.future;
    final generation = _generation;
    var forceRead = force;
    unawaited(() async {
      try {
        do {
          _refreshAgain = false;
          _revision++;
          _directoryLoads.clear();
          _graphLoad = null;
          final revision = _revision;
          final cwd = workspace!;
          _notify();
          await loadDirectory('', force: forceRead);
          if (!_current(generation, revision, cwd)) break;
          // Only revisit expanded directories, not the entire disk tree.
          final folders = expanded.toList()..sort();
          for (final folder in folders) {
            if (!_current(generation, revision, cwd)) break;
            await loadDirectory(folder);
          }
          if (!_current(generation, revision, cwd)) break;
          if (tab == WorkspaceBrowserTab.graph) {
            await loadGraph();
          } else {
            graph = null;
          }
          if (!_current(generation, revision, cwd)) break;
          _dirty = false;
          forceRead = _refreshAgain;
        } while (!_disposed && generation == _generation && _refreshAgain);
      } finally {
        if (identical(_refreshing, completion.future)) {
          _refreshing = null;
          _notify();
        }
        completion.complete();
      }
    }());
    return completion.future;
  }

  Future<void> loadDirectory(
    String path, {
    bool force = false,
    bool more = false,
  }) {
    if (_disposed || workspace == null) return Future.value();
    if (_directoryLoads[path] case final loading?) return loading;
    if (more) {
      _directoryLimits[path] = (directoryLimit(path) + 500).clamp(500, 5000);
    }
    final cwd = workspace!, generation = _generation, revision = _revision;
    final completion = Completer<void>();
    _directoryLoads[path] = completion.future;
    directoryErrors.remove(path);
    _notify();
    unawaited(() async {
      try {
        final result = await _pi.listFiles(
          cwd,
          path,
          force: force,
          limit: directoryLimit(path),
        );
        if (_current(generation, revision, cwd)) {
          // Git uses forward slashes on Windows; Node returns native paths.
          // Compare directory identity, not its spelling, while keeping the
          // generation/revision guard for genuinely stale responses.
          if (!p.equals(result.workspace, cwd) || result.path != path) {
            throw const PiRpcException('WORKSPACE_CHANGED');
          }
          directories[path] = result;
        }
      } catch (error) {
        if (_current(generation, revision, cwd)) {
          directoryErrors[path] = errorCode(error);
        }
      } finally {
        if (identical(_directoryLoads[path], completion.future)) {
          _directoryLoads.remove(path);
          _notify();
        }
        completion.complete();
      }
    }());
    return completion.future;
  }

  void toggleDirectory(String path) {
    if (!expanded.remove(path)) {
      expanded.add(path);
      if (!directories.containsKey(path) || directoryErrors.containsKey(path)) {
        unawaited(loadDirectory(path));
      }
    }
    _notify();
  }

  void collapseAll() {
    expanded.clear();
    _notify();
  }

  void selectFile(String path) {
    selectedPath = path;
    _notify();
  }

  void selectCommit(String hash) {
    selectedCommit = hash;
    _notify();
  }

  Future<void> loadGraph({bool more = false}) {
    if (_disposed || workspace == null) return Future.value();
    if (_graphLoad case final loading?) return loading;
    if (more) graphLimit = (graphLimit + 100).clamp(100, 1000);
    final cwd = workspace!, generation = _generation, revision = _revision;
    final completion = Completer<void>();
    _graphLoad = completion.future;
    graphError = null;
    _notify();
    unawaited(() async {
      try {
        final result = await _pi.getGitGraph(cwd, limit: graphLimit);
        if (_current(generation, revision, cwd)) {
          if (!p.equals(result.workspace, cwd)) {
            throw const PiRpcException('WORKSPACE_CHANGED');
          }
          graph = result;
        }
      } catch (error) {
        if (_current(generation, revision, cwd)) graphError = errorCode(error);
      } finally {
        if (identical(_graphLoad, completion.future)) {
          _graphLoad = null;
          _notify();
        }
        completion.complete();
      }
    }());
    return completion.future;
  }

  Future<PiFilePreview> preview(String path, {String? commit}) async {
    final cwd = workspace;
    final generation = _generation;
    if (cwd == null) throw const PiRpcException('WORKSPACE_CHANGED');
    final result = await _pi.getFilePreview(cwd, path, commit: commit);
    if (_disposed ||
        generation != _generation ||
        !p.equals(result.workspace, cwd)) {
      throw const PiRpcException('WORKSPACE_CHANGED');
    }
    return result;
  }

  Future<PiCommitDetails> details(String commit) async {
    final cwd = workspace;
    final generation = _generation;
    if (cwd == null) throw const PiRpcException('WORKSPACE_CHANGED');
    final result = await _pi.getGitCommit(cwd, commit);
    if (_disposed ||
        generation != _generation ||
        !p.equals(result.workspace, cwd)) {
      throw const PiRpcException('WORKSPACE_CHANGED');
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    unawaited(_events.cancel());
    super.dispose();
  }
}
