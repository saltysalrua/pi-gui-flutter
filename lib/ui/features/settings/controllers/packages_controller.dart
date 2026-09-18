import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/rpc/pi_packages_types.dart';
import '../../../../core/rpc/pi_rpc_client.dart';
import '../../../../core/rpc/pi_rpc_types.dart';

enum PackagesStatus { loading, ready, failed }

enum GalleryStatus { idle, loading, ready, failed }

/// Client-side ordering for the npm gallery; the registry ranks by
/// searchScore, everything else re-sorts the fetched page locally.
enum GallerySort { relevance, downloads, updated, name }

/// One gallery catalog row from the npm registry search API.
@immutable
class GalleryPackage {
  const GalleryPackage({
    required this.name,
    required this.version,
    this.description,
    this.publisher,
    this.updatedAt,
    this.monthlyDownloads,
    this.repositoryUrl,
    this.npmUrl,
    this.keywords = const [],
    this.searchScore,
  });
  final String name, version;
  final String? description, publisher, updatedAt, repositoryUrl, npmUrl;
  final int? monthlyDownloads;
  final List<String> keywords;
  final double? searchScore;

  bool get isExtension => keywords.contains('extension');
  bool get isSkill => keywords.contains('skill');
}

/// One install/remove/update/check run with the backend's streamed log.
class PackagesOperation {
  PackagesOperation({required this.id, required this.kind, this.source});
  final String id, kind;
  final String? source;
  final log = <String>[];
  bool running = true;
  String? error;
}

/// Backs the settings "packages" page. Management data and mutations go over
/// the shared control channel (same backend as the home shell); the gallery
/// browses the npm registry through the configured mirror like `npm` itself.
class PackagesController extends ChangeNotifier {
  PackagesController(PiRpcClient client)
    : _service = PiPackagesService(client) {
    _events = client.events.listen(_onEvent);
  }

  static const officialRegistry = 'https://registry.npmjs.org/';
  final PiPackagesService _service;
  StreamSubscription<PiRpcEvent>? _events;
  final _pending = <String, Completer<PiPackagesFinished>>{};
  final _toggling = <String>{};
  String? _registry;
  int _sequence = 0, _operations = 0;
  bool _disposed = false;

  PackagesStatus status = PackagesStatus.loading;
  PiPackagesState? state;
  String? failure, actionError;
  List<PiPackageUpdateInfo> updates = const [];
  PackagesOperation? operation;

  GalleryStatus galleryStatus = GalleryStatus.idle;
  String galleryQuery = '';
  List<GalleryPackage> gallery = const [];
  String? galleryFailure;
  GallerySort gallerySort = GallerySort.relevance;

  List<GalleryPackage> get sortedGallery => sortGallery(gallery, gallerySort);

  void setGallerySort(GallerySort sort) {
    if (gallerySort == sort) return;
    gallerySort = sort;
    _notify();
  }

  bool get busy => operation?.running == true;
  bool isToggling(PiResourceItem item) => _toggling.contains(item.path);
  bool isInstalled(String npmName) =>
      state?.packages.any(
        (entry) =>
            entry.source.startsWith('npm:') &&
            entry.source.substring(4).split('@').first == npmName,
      ) ??
      false;
  bool hasUpdate(String source) =>
      updates.any((update) => update.source == source);

  // Non-RPC failures (parse TypeErrors, OS errors, timeouts) used to
  // collapse into a bare PACKAGES_FAILED that hid the real cause; surface
  // the exception itself so the failed card is diagnosable.
  static String _code(Object error) {
    if (error is PiRpcException) {
      return error.outcomeUnknown ? 'OUTCOME_UNKNOWN' : error.message;
    }
    final detail = error.toString().split('\n').first;
    return detail.length > 160 ? detail.substring(0, 160) : detail;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      final next = await _service.state();
      if (_disposed) return;
      state = next;
      status = PackagesStatus.ready;
      failure = null;
    } catch (error) {
      if (_disposed) return;
      status = PackagesStatus.failed;
      failure = _code(error);
    }
    _notify();
  }

  Future<bool> installFromGallery(String npmName) =>
      _run('install', source: 'npm:$npmName');

  Future<bool> installSource(String source) => _run('install', source: source);

  Future<bool> remove(String source) => _run('remove', source: source);

  Future<bool> updateAll() => _run('update');

  Future<bool> updateSource(String source) => _run('update', source: source);

  Future<bool> checkUpdates() => _run('check_updates');

  Future<bool> _run(String kind, {String? source}) async {
    if (busy || _disposed) return false;
    final id = 'pkg-${DateTime.now().millisecondsSinceEpoch}-${++_operations}';
    final op = PackagesOperation(id: id, kind: kind, source: source);
    operation = op;
    actionError = null;
    final completer = Completer<PiPackagesFinished>();
    _pending[id] = completer;
    _notify();
    try {
      switch (kind) {
        case 'install':
          await _service.install(id, source!);
        case 'remove':
          await _service.remove(id, source!);
        case 'update':
          await _service.update(id, source: source);
        case 'check_updates':
          await _service.checkUpdates(id);
      }
    } catch (error) {
      _pending.remove(id);
      return _failOp(op, _code(error));
    }
    final finished = await completer.future;
    if (_disposed) return finished.ok;
    if (!finished.ok) return _failOp(op, finished.error ?? 'PACKAGES_FAILED');
    if (kind == 'check_updates') {
      updates = finished.updates;
    } else if (finished.state != null) {
      state = finished.state;
    }
    op.running = false;
    op.error = null;
    _notify();
    return true;
  }

  bool _failOp(PackagesOperation op, String error) {
    op.running = false;
    op.error = error;
    actionError = error;
    _notify();
    return false;
  }

  /// Optimistic-free toggles: the backend answers with the fresh state.
  Future<void> toggle(PiResourceItem item, bool enabled) async {
    if (busy || _disposed || !item.isUserScope || isToggling(item)) return;
    _toggling.add(item.path);
    actionError = null;
    _notify();
    try {
      state = await _service.toggle(item, enabled);
    } catch (error) {
      if (!_disposed) actionError = _code(error);
    } finally {
      _toggling.remove(item.path);
      _notify();
    }
  }

  void _onEvent(PiRpcEvent event) {
    if (event is PiRpcDisconnected) {
      for (final completer in _pending.values) {
        if (!completer.isCompleted) {
          completer.completeError(const PiRpcException('Pi disconnected'));
        }
      }
      _pending.clear();
      final op = operation;
      if (op != null && op.running && !_disposed) {
        op.running = false;
        op.error = 'PI_DISCONNECTED';
      }
      _notify();
      return;
    }
    if (event is! PiAgentEvent) return;
    if (event.type == 'gui_packages_progress') {
      final progress = PiPackagesProgress.fromJson(event.payload);
      final op = progress.operationId == null
          ? operation?.running == true
                ? operation
                : null
          : operation?.id == progress.operationId && operation!.running
          ? operation
          : null;
      if (op == null) return;
      op.log.add(
        progress.message ??
            '${progress.action} ${progress.source ?? ''}'.trim(),
      );
      _notify();
      return;
    }
    if (event.type == 'gui_packages_finished') {
      final finished = PiPackagesFinished.fromJson(event.payload);
      final completer = _pending.remove(finished.operationId);
      if (completer != null && !completer.isCompleted) {
        completer.complete(finished);
      }
    }
  }

  // ---- Gallery (npm registry search) ----

  Future<void> searchGallery(String query) async {
    galleryQuery = query;
    galleryStatus = GalleryStatus.loading;
    galleryFailure = null;
    final sequence = ++_sequence;
    _notify();
    try {
      final registry = await _npmRegistry();
      var results = await _fetchGallery(registry, query);
      if (results.isEmpty && registry != officialRegistry) {
        results = await _fetchGallery(officialRegistry, query);
      }
      if (_disposed || sequence != _sequence) return;
      gallery = results;
      galleryStatus = GalleryStatus.ready;
    } catch (error) {
      if (_disposed || sequence != _sequence) return;
      gallery = const [];
      galleryStatus = GalleryStatus.failed;
      galleryFailure = _code(error);
    }
    _notify();
  }

  Future<List<GalleryPackage>> _fetchGallery(
    String registry,
    String query,
  ) async {
    final text = query.isEmpty
        ? 'keywords:pi-package'
        : 'keywords:pi-package $query';
    final base = registry.endsWith('/') ? registry : '$registry/';
    final uri = Uri.parse('$base-/v1/search')
        .replace(queryParameters: {'text': text, 'size': '250'});
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.userAgentHeader, 'pi-gui');
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw const PiRpcException('REGISTRY_HTTP_ERROR');
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
      return parseRegistrySearch(jsonDecode(body));
    } finally {
      client.close();
    }
  }

  /// The configured registry is honored first, exactly like the npm CLI.
  Future<String> _npmRegistry() async {
    final cached = _registry;
    if (cached != null) return cached;
    Process? probe;
    try {
      probe = await Process.start('npm', [
        'config',
        'get',
        'registry',
      ], runInShell: Platform.isWindows);
      Future<String> stdout = probe.stdout.transform(utf8.decoder).join();
      Future<String> stderr = probe.stderr.transform(utf8.decoder).join();
      Future<int> exit = probe.exitCode;
      final code = await exit.timeout(const Duration(seconds: 15));
      final out = await stdout.timeout(const Duration(seconds: 15));
      await stderr.timeout(const Duration(seconds: 15));
      if (code != 0) throw const PiRpcException('NPM_FAILED');
      final line = const LineSplitter()
          .convert(out)
          .firstWhere(
            (line) => line.trim().startsWith('http'),
            orElse: () => '',
          );
      if (line.isEmpty) throw const PiRpcException('NPM_FAILED');
      return _registry ??= line.trim();
    } catch (error) {
      if (error is TimeoutException) {
        // Kill only THIS probe's process tree; a blanket `taskkill /IM
        // npm.cmd` would take down the user's unrelated npm installs too.
        await _killTree(probe?.pid);
      }
      return _registry ??= officialRegistry;
    }
  }

  Future<void> _killTree(int? pid) async {
    if (pid == null) return;
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
      } else {
        Process.killPid(pid);
      }
    } catch (_) {
      /* Best-effort cleanup only. */
    }
  }

  @visibleForTesting
  static List<GalleryPackage> parseRegistrySearch(Object? json) {
    if (json is! Map || json['objects'] is! List) return const [];
    final results = <GalleryPackage>[];
    for (final entry in json['objects'] as List) {
      if (entry is! Map || entry['package'] is! Map) continue;
      final package = entry['package'] as Map;
      final name = package['name'];
      if (name is! String || name.isEmpty) continue;
      final links = package['links'];
      final downloads = entry['downloads'];
      final score = entry['searchScore'];
      final publisher = package['publisher'];
      final maintainer = (package['maintainers'] as List?)
          ?.whereType<Map>()
          .firstOrNull;
      final date = package['date'];
      final raw = package['keywords'];
      results.add(
        GalleryPackage(
          name: name,
          version: package['version'] is String
              ? package['version'] as String
              : '',
          description: package['description'] as String?,
          publisher: publisher is Map && publisher['username'] is String
              ? publisher['username'] as String
              : maintainer?['username'] as String?,
          updatedAt: date is String ? date : null,
          monthlyDownloads: downloads is Map && downloads['monthly'] is int
              ? downloads['monthly'] as int
              : null,
          repositoryUrl: links is Map && links['repository'] is String
              ? links['repository'] as String
              : links is Map && links['npm'] is String
              ? links['npm'] as String
              : null,
          npmUrl: links is Map && links['npm'] is String
              ? links['npm'] as String
              : null,
          keywords: raw is List
              ? List.unmodifiable(
                  raw.whereType<String>().map((k) => k.toLowerCase()),
                )
              : const [],
          searchScore: score is num ? score.toDouble() : null,
        ),
      );
    }
    return List.unmodifiable(results);
  }

  /// Pure ordering so regressions can be unit-tested without a client.
  @visibleForTesting
  static List<GalleryPackage> sortGallery(
    List<GalleryPackage> items,
    GallerySort sort,
  ) {
    final list = List<GalleryPackage>.of(items);
    int byName(GalleryPackage a, GalleryPackage b) => a.name.compareTo(b.name);
    switch (sort) {
      case GallerySort.relevance:
        list.sort(
          (a, b) => (b.searchScore ?? -1).compareTo(a.searchScore ?? -1),
        );
      case GallerySort.downloads:
        list.sort((a, b) {
          final downloads = (b.monthlyDownloads ?? -1).compareTo(
            a.monthlyDownloads ?? -1,
          );
          return downloads != 0 ? downloads : byName(a, b);
        });
      case GallerySort.updated:
        list.sort((a, b) {
          final date = (b.updatedAt ?? '').compareTo(a.updatedAt ?? '');
          return date != 0 ? date : byName(a, b);
        });
      case GallerySort.name:
        list.sort(byName);
    }
    return list;
  }

  @override
  void dispose() {
    _disposed = true;
    _events?.cancel();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const PiRpcException('Client is closed'));
      }
    }
    _pending.clear();
    super.dispose();
  }
}
