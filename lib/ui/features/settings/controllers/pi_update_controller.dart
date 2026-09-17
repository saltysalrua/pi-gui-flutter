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

/// Reads the npm-installed Pi backend (package version + CHANGELOG.md) and
/// queries the npm registry for the latest published version.
///
/// The controller is short-lived: one instance per open settings page. It never
/// touches the running Pi RPC sessions; all data comes from npm CLI + files.
class PiUpdateController extends ChangeNotifier {
  PiUpdateController();

  static const packageName = '@earendil-works/pi-coding-agent';
  static const _registryPage = 'https://www.npmjs.com/package/$packageName';
  static const updateCommand = 'npm install -g $packageName@latest';

  PiInfoStatus _infoStatus = PiInfoStatus.loading;
  String? _currentVersion;
  String? _installPath;
  List<PiChangelogEntry> _entries = const [];

  PiCheckStatus _checkStatus = PiCheckStatus.idle;
  String? _latestVersion;

  PiInfoStatus get infoStatus => _infoStatus;
  String? get currentVersion => _currentVersion;
  String? get installPath => _installPath;
  List<PiChangelogEntry> get entries => _entries;
  PiCheckStatus get checkStatus => _checkStatus;
  String? get latestVersion => _latestVersion;
  static String get registryPage => _registryPage;

  bool _loading = false;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _infoStatus = PiInfoStatus.loading;
    notifyListeners();
    try {
      final root = (await _runNpm(['root', '-g'])).trim();
      if (root.isEmpty) throw StateError('npm root -g returned nothing');
      final resolved = _normalize(Directory(root), packageName);
      final packageJson = File(
        '$resolved${Platform.pathSeparator}package.json',
      );
      final changelogFile = File(
        '$resolved${Platform.pathSeparator}CHANGELOG.md',
      );
      final package =
          jsonDecode(await packageJson.readAsString()) as Map<String, dynamic>;
      _currentVersion = package['version'] as String?;
      if (_currentVersion == null || _currentVersion!.isEmpty) {
        throw StateError('package.json has no version');
      }
      _installPath = resolved;
      _entries = _parseChangelog(await changelogFile.readAsString());
      _infoStatus = PiInfoStatus.ready;
      _loading = false;
      notifyListeners();
      // Silent auto-check once install info is available.
      unawaited(checkForUpdate());
    } catch (_) {
      _infoStatus = PiInfoStatus.failed;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> checkForUpdate() async {
    if (_checkStatus == PiCheckStatus.checking) return;
    _checkStatus = PiCheckStatus.checking;
    notifyListeners();
    try {
      final latest = await _runNpm(['view', packageName, 'dist-tags.latest']);
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
    notifyListeners();
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
