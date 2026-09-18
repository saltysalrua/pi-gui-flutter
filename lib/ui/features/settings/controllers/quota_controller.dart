import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// One sliding quota window from `GET /wham/usage`.
///
/// `primary` is the ~5h window (`limitWindowSeconds` 18000), `secondary`
/// the ~7d window (604800); `resetAt` is a Unix timestamp in seconds.
@immutable
class CodexUsageWindow {
  const CodexUsageWindow({
    required this.usedPercent,
    this.limitWindowSeconds,
    this.resetAfterSeconds,
    this.resetAt,
  });

  final int usedPercent;
  final int? limitWindowSeconds;
  final int? resetAfterSeconds;
  final int? resetAt;

  /// Reset time as a local [DateTime], null when the backend omits it.
  DateTime? get resetAtUtc => resetAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(resetAt! * 1000);

  factory CodexUsageWindow.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int
        ? v
        : v is num
        ? v.toInt()
        : v is String
        ? int.tryParse(v)
        : null;
    return CodexUsageWindow(
      usedPercent: (asInt(json['used_percent']) ?? 0).clamp(0, 100),
      limitWindowSeconds: asInt(json['limit_window_seconds']),
      resetAfterSeconds: asInt(json['reset_after_seconds']),
      resetAt: asInt(json['reset_at']),
    );
  }
}

/// Parsed payload of ChatGPT's read-only `wham/usage` endpoint. Only the
/// fields the quota page actually renders are kept; unknown extras are
/// ignored on purpose so backend additions never break the page.
@immutable
class CodexUsageSnapshot {
  const CodexUsageSnapshot({
    required this.email,
    required this.planType,
    required this.accountId,
    required this.allowed,
    required this.limitReached,
    required this.primaryWindow,
    this.secondaryWindow,
    required this.hasCredits,
    required this.creditsBalance,
  });

  final String email;
  final String planType;
  final String accountId;
  final bool allowed;
  final bool limitReached;
  final CodexUsageWindow primaryWindow;
  final CodexUsageWindow? secondaryWindow;
  final bool hasCredits;
  final String creditsBalance;

  factory CodexUsageSnapshot.fromJson(Map<String, dynamic> json) {
    final rateLimit = json['rate_limit'];
    Map<String, dynamic>? window(String key) =>
        rateLimit is Map<String, dynamic> && rateLimit[key] is Map
        ? Map<String, dynamic>.from(rateLimit[key] as Map)
        : null;
    final primary = window('primary_window');
    final secondary = window('secondary_window');
    final credits = json['credits'];
    final creditsMap = credits is Map<String, dynamic> ? credits : null;
    return CodexUsageSnapshot(
      email: json['email'] as String? ?? '',
      planType: json['plan_type'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      allowed: rateLimit is Map<String, dynamic>
          ? rateLimit['allowed'] as bool? ?? true
          : true,
      limitReached: rateLimit is Map<String, dynamic>
          ? rateLimit['limit_reached'] as bool? ?? false
          : false,
      primaryWindow: primary != null
          ? CodexUsageWindow.fromJson(primary)
          : const CodexUsageWindow(usedPercent: 0),
      secondaryWindow: secondary == null
          ? null
          : CodexUsageWindow.fromJson(secondary),
      hasCredits: creditsMap?['has_credits'] as bool? ?? false,
      creditsBalance: creditsMap?['balance'] as String? ?? '0',
    );
  }
}

enum QuotaStatus { loading, ready, failed, missing }

enum QuotaFailure { network, unauthorized, parse }

/// The `openai-codex` OAuth entry inside Pi's `~/.pi/agent/auth.json`.
@immutable
class CodexAuthEntry {
  const CodexAuthEntry({
    required this.accessToken,
    required this.accountId,
    required this.expiresAt,
  });

  final String accessToken;
  final String accountId;

  /// Millisecond epoch from Pi's own `expires` field; null if absent.
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

/// Reads the Codex OAuth token from Pi's auth.json and queries ChatGPT's
/// read-only `wham/usage` endpoint for plan quota windows.
///
/// The endpoint is the same one the official Codex desktop app uses for its
/// 5h/weekly gauges: `GET https://chatgpt.com/backend-api/wham/usage` with
/// `Authorization: Bearer <access>` and `ChatGPT-Account-Id` headers. It
/// does not consume any rate-limit budget. Settings pages use a short-lived
/// instance; app-level widgets (sidebar hover card) share [shared]; no RPC
/// channel is involved.
class QuotaController extends ChangeNotifier {
  QuotaController();

  static const _usageUrl = 'https://chatgpt.com/backend-api/wham/usage';

  /// Cached snapshots older than this are quietly re-fetched on hover.
  @visibleForTesting
  static const staleAfter = Duration(minutes: 5);

  static QuotaController? _sharedInstance;

  /// App-lifetime instance for always-visible widgets (sidebar quota
  /// button). Never disposed; lives like SidebarLayoutController.instance.
  static QuotaController get shared => _sharedInstance ??= QuotaController();

  QuotaStatus _status = QuotaStatus.loading;
  CodexUsageSnapshot? _snapshot;
  CodexAuthEntry? _auth;
  QuotaFailure? _failure;
  bool _loading = false;
  DateTime? _lastLoadedAt;

  QuotaStatus get status => _status;
  CodexUsageSnapshot? get snapshot => _snapshot;
  CodexAuthEntry? get auth => _auth;
  QuotaFailure? get failure => _failure;
  bool get isRefreshing => _loading;

  /// True when the cached data is older than [staleAfter] (or never loaded).
  bool get isStale {
    final last = _lastLoadedAt;
    return last == null || DateTime.now().difference(last) > staleAfter;
  }

  /// Loads only when nothing has ever been fetched; hover cards and the
  /// settings page both call this so opening them is instant when cached.
  Future<void> ensureLoaded() {
    if (_status == QuotaStatus.loading && !_loading) return refresh();
    return Future.value();
  }

  /// Hover entry point: fetch on first use, then silently re-fetch stale
  /// data. A silent refresh keeps showing the previous snapshot while it
  /// runs and only replaces it on success, so the card never flashes.
  Future<void> ensureFresh() async {
    if (_loading) return;
    if (_status == QuotaStatus.loading && _snapshot == null) {
      return refresh();
    }
    if (!isStale) return;
    if (_status == QuotaStatus.ready) {
      await _refresh(silent: true);
    } else {
      await refresh();
    }
  }

  /// Resolves Pi's auth.json the same way the backend does:
  /// `$PI_CODING_AGENT_DIR/auth.json`, else `~/.pi/agent/auth.json`.
  @visibleForTesting
  static String authJsonPath(Map<String, String> environment) {
    // Keep the separator style of the base path so POSIX-style values
    // (HOME, or a forward-slash override) stay consistent on Windows.
    var sep = Platform.pathSeparator;
    String join(String parent, String child) =>
        parent.endsWith('/') || parent.endsWith('\\')
        ? '$parent$child'
        : '$parent$sep$child';

    final override = environment['PI_CODING_AGENT_DIR'];
    if (override != null && override.isNotEmpty) {
      if (override.contains('/') && !override.contains('\\')) sep = '/';
      return join(override, 'auth.json');
    }
    final home = environment['USERPROFILE'] ?? environment['HOME'] ?? '.';
    if (home.contains('/') && !home.contains('\\')) sep = '/';
    return join(join(join(home, '.pi'), 'agent'), 'auth.json');
  }

  @visibleForTesting
  static CodexAuthEntry? parseAuthEntry(String json) {
    dynamic root;
    try {
      root = jsonDecode(json);
    } catch (_) {
      return null;
    }
    if (root is! Map<String, dynamic>) return null;
    final entry = root['openai-codex'];
    if (entry is! Map<String, dynamic>) return null;
    final access = entry['access'] as String?;
    if (access == null || access.isEmpty) return null;
    final accountId = entry['accountId'] as String? ?? '';
    final expiresRaw = entry['expires'];
    final expiresAt = expiresRaw is num
        ? DateTime.fromMillisecondsSinceEpoch(expiresRaw.toInt())
        : null;
    return CodexAuthEntry(
      accessToken: access,
      accountId: accountId,
      expiresAt: expiresAt,
    );
  }

  @visibleForTesting
  static CodexUsageSnapshot parseUsage(String json) =>
      CodexUsageSnapshot.fromJson(jsonDecode(json) as Map<String, dynamic>);

  Future<void> load() => refresh();

  Future<void> refresh() => _refresh();

  Future<void> _refresh({bool silent = false}) async {
    if (_loading) return;
    _loading = true;
    _failure = null;
    // A silent refresh keeps the ready snapshot visible instead of
    // flipping back to the loading state.
    if (!silent || _status != QuotaStatus.ready) {
      _status = QuotaStatus.loading;
    }
    notifyListeners();
    try {
      final file = File(authJsonPath(Platform.environment));
      _auth = parseAuthEntry(await file.readAsString());
      if (_auth == null) {
        _status = QuotaStatus.missing;
        _loading = false;
        notifyListeners();
        return;
      }
      _snapshot = await _fetchUsage(_auth!);
      _status = QuotaStatus.ready;
      _lastLoadedAt = DateTime.now();
    } on QuotaFetchException catch (e) {
      _failure = e.failure;
      // Keep the previous snapshot on a failed silent refresh; it is merely
      // stale, which beats showing an error card for a transient hiccup.
      if (!silent || _status != QuotaStatus.ready) {
        _status = QuotaStatus.failed;
      }
    } catch (_) {
      _failure = QuotaFailure.parse;
      if (!silent || _status != QuotaStatus.ready) {
        _status = QuotaStatus.failed;
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<CodexUsageSnapshot> _fetchUsage(CodexAuthEntry auth) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .getUrl(Uri.parse(_usageUrl))
          .timeout(const Duration(seconds: 15));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${auth.accessToken}',
      );
      if (auth.accountId.isNotEmpty) {
        request.headers.set('ChatGPT-Account-Id', auth.accountId);
      }
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'pi-gui/1.0 (codex usage gauge)',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw QuotaFetchException(QuotaFailure.unauthorized);
      }
      if (response.statusCode != 200) {
        throw QuotaFetchException(QuotaFailure.network);
      }
      try {
        return parseUsage(body);
      } on QuotaFetchException {
        rethrow;
      } catch (_) {
        throw QuotaFetchException(QuotaFailure.parse);
      }
    } on QuotaFetchException {
      rethrow;
    } on SocketException {
      throw QuotaFetchException(QuotaFailure.network);
    } on TimeoutException {
      throw QuotaFetchException(QuotaFailure.network);
    } on HttpException {
      throw QuotaFetchException(QuotaFailure.network);
    } finally {
      client.close(force: true);
    }
  }
}

class QuotaFetchException implements Exception {
  const QuotaFetchException(this.failure);
  final QuotaFailure failure;
}
