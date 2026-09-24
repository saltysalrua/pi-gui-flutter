import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// One `## [x.y.z] - date` section of Pi's CHANGELOG.md.
@immutable
class PiChangelogEntry {
  const PiChangelogEntry({
    required this.version,
    required this.date,
    required this.body,
  });
  final String version;
  final String date;
  final String body;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return version.toLowerCase().contains(q) ||
        date.toLowerCase().contains(q) ||
        body.toLowerCase().contains(q);
  }
}

enum PiInfoStatus { loading, ready, failed }

enum PiCheckStatus { idle, checking, upToDate, available, failed }

enum PiSelfUpdateStatus { idle, running, succeeded, failed }

/// Fetch states for the not-yet-installed version's online CHANGELOG.md.
enum PiUpcomingStatus { idle, loading, ready, failed }

/// Reads the npm-installed Pi backend (package version + CHANGELOG.md) and
/// queries the npm registry for the latest published version.
///
/// The app shares one instance ([instance]) for its whole lifetime: the data
/// is warmed once at startup, refreshed silently by a periodic timer, and
/// every settings dialog just renders the cache — switching or reopening the
/// settings pages never re-triggers a visible reload. The controller never
/// touches the running Pi RPC sessions; all data comes from npm CLI + files.
class PiUpdateController extends ChangeNotifier {
  PiUpdateController();

  /// App-wide shared instance with the periodic background refresh.
  PiUpdateController._shared() {
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => unawaited(refresh()),
    );
  }

  static PiUpdateController? _instance;

  /// The one instance the app uses; created on first access (HomeView warms
  /// it at startup) and never disposed.
  static PiUpdateController get instance =>
      _instance ??= PiUpdateController._shared();

  /// Background cadence for the silent refresh: install info + update check.
  static const _refreshInterval = Duration(minutes: 30);

  /// Set in [dispose]; async continuations (npm subprocess waits) must not
  /// notify listeners after a settings page that owned this controller
  /// has closed — otherwise ChangeNotifier throws used-after-dispose.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  static const packageName = '@earendil-works/pi-coding-agent';
  static const _registryPage = 'https://www.npmjs.com/package/$packageName';
  static const updateCommand = 'npm install -g $packageName@latest';

  PiInfoStatus _infoStatus = PiInfoStatus.loading;
  String? _currentVersion;
  String? _installPath;
  List<PiChangelogEntry> _entries = const [];

  PiCheckStatus _checkStatus = PiCheckStatus.idle;
  String? _latestVersion;

  PiUpcomingStatus _upcomingStatus = PiUpcomingStatus.idle;
  List<PiChangelogEntry> _upcomingEntries = const [];
  String? _upcomingVersion;

  PiSelfUpdateStatus _selfUpdateStatus = PiSelfUpdateStatus.idle;
  final selfUpdateLog = <String>[];

  PiInfoStatus get infoStatus => _infoStatus;
  String? get currentVersion => _currentVersion;
  String? get installPath => _installPath;
  List<PiChangelogEntry> get entries => _entries;
  PiCheckStatus get checkStatus => _checkStatus;
  String? get latestVersion => _latestVersion;
  PiUpcomingStatus get upcomingStatus => _upcomingStatus;
  List<PiChangelogEntry> get upcomingEntries => _upcomingEntries;
  PiSelfUpdateStatus get selfUpdateStatus => _selfUpdateStatus;
  static String get registryPage => _registryPage;

  bool _loading = false;
  bool _started = false;
  Timer? _refreshTimer;
  bool get isSelfUpdating => _selfUpdateStatus == PiSelfUpdateStatus.running;

  /// Loads only if nothing has ever been fetched (used when a settings
  /// dialog opens before the startup warm-up ran, e.g. in tests).
  void ensureLoaded() {
    if (!_started) unawaited(load());
  }

  /// One installed-package snapshot: version, path and parsed changelog.
  Future<({String version, String path, List<PiChangelogEntry> entries})>
  _readInstallInfo() async {
    final root = (await _runNpm(['root', '-g'])).trim();
    if (root.isEmpty) throw StateError('npm root -g returned nothing');
    final resolved = _normalize(Directory(root), packageName);
    final packageJson = File('$resolved${Platform.pathSeparator}package.json');
    final changelogFile = File(
      '$resolved${Platform.pathSeparator}CHANGELOG.md',
    );
    final package =
        jsonDecode(await packageJson.readAsString()) as Map<String, dynamic>;
    final version = package['version'] as String?;
    if (version == null || version.isEmpty) {
      throw StateError('package.json has no version');
    }
    return (
      version: version,
      path: resolved,
      entries: _parseChangelog(await changelogFile.readAsString()),
    );
  }

  /// Visible load: flips the page into its loading state, then warms the
  /// update check in the background. Used at startup and for manual retries.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _started = true;
    _infoStatus = PiInfoStatus.loading;
    _notify();
    try {
      final info = await _readInstallInfo();
      if (_disposed) return;
      _currentVersion = info.version;
      _installPath = info.path;
      _entries = info.entries;
      _infoStatus = PiInfoStatus.ready;
      _loading = false;
      _notify();
      // Silent auto-check once install info is available.
      unawaited(checkForUpdate());
    } catch (_) {
      _infoStatus = PiInfoStatus.failed;
      _loading = false;
      _notify();
    }
  }

  /// Silent refresh (periodic timer): keeps the current data on screen and
  /// only swaps in the fresh snapshot when it arrives. Failures are ignored
  /// so a flaky network never destroys a good cached page. If the initial
  /// load never succeeded, the timer retries the visible path instead so a
  /// failed startup (e.g. offline at launch) heals on its own.
  Future<void> refresh() async {
    if (_loading) return;
    if (_infoStatus != PiInfoStatus.ready) return load();
    try {
      final info = await _readInstallInfo();
      if (_disposed) return;
      _currentVersion = info.version;
      _installPath = info.path;
      _entries = info.entries;
      _notify();
    } catch (_) {
      // Keep the cached snapshot.
    }
    unawaited(checkForUpdate());
  }

  Future<void> checkForUpdate() async {
    if (_checkStatus == PiCheckStatus.checking) return;
    _checkStatus = PiCheckStatus.checking;
    _notify();
    try {
      final latest = await _runNpm(['view', packageName, 'dist-tags.latest']);
      if (_disposed) return;
      final match = RegExp(r'^\d+(\.\d+)+').firstMatch(latest);
      if (match == null) throw StateError('unexpected npm output: $latest');
      _latestVersion = match.group(0);
      _checkStatus =
          _currentVersion != null &&
              compareVersions(_currentVersion!, _latestVersion!) >= 0
          ? PiCheckStatus.upToDate
          : PiCheckStatus.available;
    } catch (_) {
      _checkStatus = PiCheckStatus.failed;
    }
    _notify();
    if (_checkStatus == PiCheckStatus.available) {
      unawaited(_fetchUpcomingNotes());
    }
  }

  /// Fetches the CHANGELOG.md that ships with the *latest published*
  /// version (via unpkg, then jsdelivr as fallback) so the settings page can
  /// show release notes for the update that is about to be installed — the
  /// locally installed changelog only covers versions up to the current one.
  Future<void> _fetchUpcomingNotes() async {
    final latest = _latestVersion;
    final current = _currentVersion;
    if (latest == null || current == null) return;
    if (_upcomingStatus == PiUpcomingStatus.loading) return;
    // Cached for this target version; manual refresh clears it below.
    if (_upcomingVersion == latest &&
        (_upcomingStatus == PiUpcomingStatus.ready ||
            _upcomingEntries.isNotEmpty)) {
      return;
    }
    _upcomingStatus = PiUpcomingStatus.loading;
    _notify();
    try {
      String? text;
      for (final uri in _upcomingNoteUris(latest)) {
        text = await _tryFetchText(uri);
        if (text != null && text.isNotEmpty) break;
      }
      if (_disposed) return;
      final upcoming = text == null || text.isEmpty
          ? const <PiChangelogEntry>[]
          : filterUpcomingEntries(_parseChangelog(text), current);
      if (upcoming.isEmpty) throw StateError('changelog has no entries');
      _upcomingEntries = upcoming;
      _upcomingVersion = latest;
      _upcomingStatus = PiUpcomingStatus.ready;
    } catch (_) {
      _upcomingStatus = PiUpcomingStatus.failed;
    }
    _notify();
  }

  static List<Uri> _upcomingNoteUris(String version) => [
    Uri.parse('https://unpkg.com/$packageName@$version/CHANGELOG.md'),
    Uri.parse(
      'https://cdn.jsdelivr.net/npm/$packageName@$version/CHANGELOG.md',
    ),
  ];

  Future<String?> _tryFetchText(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.userAgentHeader, 'pi-gui');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) return null;
      return await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Picks the changelog entries newer than the installed version. If the
  /// published changelog has no newer section (prerelease tags, lagging
  /// changelog), falls back to its top entry so the card still shows
  /// something useful. Pure function, unit-tested.
  @visibleForTesting
  static List<PiChangelogEntry> filterUpcomingEntries(
    List<PiChangelogEntry> entries,
    String currentVersion,
  ) {
    final newer = entries
        .where((e) => compareVersions(e.version, currentVersion) > 0)
        .toList(growable: false);
    if (newer.isNotEmpty) return newer;
    return entries.isEmpty
        ? const <PiChangelogEntry>[]
        : <PiChangelogEntry>[entries.first];
  }

  /// Runs `pi update --self` and streams its output. The official command
  /// picks the right install method (npm/pnpm/yarn/bun) for this machine.
  /// Running sessions keep the old code; newly spawned Pi uses the new one.
  Future<bool> runSelfUpdate() async {
    if (isSelfUpdating) return false;
    _selfUpdateStatus = PiSelfUpdateStatus.running;
    selfUpdateLog.clear();
    _notify();
    Process? process;
    var success = false;
    try {
      process = await Process.start('pi', [
        'update',
        '--self',
      ], runInShell: Platform.isWindows);
      void push(String line) {
        final text = line.trimRight();
        if (text.isEmpty) return;
        selfUpdateLog.add(text);
        if (selfUpdateLog.length > 500) selfUpdateLog.removeAt(0);
        _notify();
      }

      final collecting = [
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(push),
        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(push),
      ];
      try {
        final code = await process.exitCode.timeout(
          const Duration(minutes: 10),
        );
        success = code == 0;
      } finally {
        for (final subscription in collecting) {
          await subscription.cancel();
        }
      }
    } catch (_) {
      if (process != null) await _killTree(process);
      success = false;
    }
    _selfUpdateStatus = success
        ? PiSelfUpdateStatus.succeeded
        : PiSelfUpdateStatus.failed;
    _notify();
    // The npm install replaced the package on disk; re-read version and log.
    // The update check runs again and the upcoming-notes cache is now stale.
    if (success && !_disposed) {
      _upcomingVersion = null;
      _upcomingEntries = const [];
      _upcomingStatus = PiUpcomingStatus.idle;
      await load();
    }
    return success;
  }

  /// Runs npm on a detached-shell child and kills the whole tree on timeout,
  /// so a hung registry probe cannot leave stray node processes behind.
  Future<String> _runNpm(
    List<String> args, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final process = await Process.start(
      'npm',
      args,
      runInShell: Platform.isWindows,
    );
    Future<String> stdout = process.stdout.transform(utf8.decoder).join();
    Future<String> stderr = process.stderr.transform(utf8.decoder).join();
    Future<int> exit = process.exitCode;
    try {
      final code = await exit.timeout(timeout);
      final err = await stderr.timeout(timeout);
      if (code != 0) throw StateError('npm ${args.join(' ')} failed: $err');
      return (await stdout.timeout(timeout)).trim();
    } on TimeoutException {
      await _killTree(process);
      rethrow;
    }
  }

  Future<void> _killTree(Process process) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
      } else {
        process.kill(ProcessSignal.sigkill);
      }
    } catch (_) {
      process.kill();
    }
  }

  static String _normalize(Directory npmRoot, String packageName) {
    final sep = Platform.pathSeparator;
    final quoted = packageName.split('/').join(sep);
    final raw = '${npmRoot.path}$sep$quoted';
    return raw.endsWith(sep) ? raw.substring(0, raw.length - 1) : raw;
  }

  @visibleForTesting
  static List<PiChangelogEntry> parseChangelog(String text) =>
      _parseChangelog(text);

  static List<PiChangelogEntry> _parseChangelog(String text) {
    final entries = <PiChangelogEntry>[];
    final header = RegExp(r'^##\s*\[([^\]]+)\]\s*-?\s*(.*)$');
    String version = '';
    String date = '';
    final body = <String>[];
    void flush() {
      if (version.isEmpty) return;
      while (body.isNotEmpty && body.last.trim().isEmpty) {
        body.removeLast();
      }
      while (body.isNotEmpty && body.first.trim().isEmpty) {
        body.removeAt(0);
      }
      entries.add(
        PiChangelogEntry(
          version: version,
          date: date.trim(),
          body: body.join('\n'),
        ),
      );
    }

    for (final line in const LineSplitter().convert(text)) {
      final match = header.firstMatch(line);
      if (match != null) {
        flush();
        version = match.group(1)!.trim();
        date = match.group(2) ?? '';
        body.clear();
      } else {
        body.add(line);
      }
    }
    flush();
    return entries;
  }

  /// Numeric major.minor.patch comparison; prerelease suffixes are ignored.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    List<int> parse(String v) => v
        .split(RegExp('[-+]'))
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final pa = parse(a);
    final pb = parse(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final d = (pa.length > i ? pa[i] : 0) - (pb.length > i ? pb[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }
}
