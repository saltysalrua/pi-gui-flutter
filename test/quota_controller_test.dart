import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/ui/features/settings/controllers/quota_controller.dart';

void main() {
  group('QuotaController.parseAuthEntry', () {
    test('parses the openai-codex OAuth entry from auth.json', () {
      const json = '''
      {
        "openai-codex": {
          "type": "oauth",
          "access": "token-value",
          "refresh": "refresh-value",
          "expires": 1790305171065,
          "accountId": "acc-123"
        },
        "deepseek": { "type": "api_key", "apiKey": "sk-x" }
      }
      ''';
      final entry = QuotaController.parseAuthEntry(json);
      expect(entry, isNotNull);
      expect(entry!.accessToken, 'token-value');
      expect(entry.accountId, 'acc-123');
      expect(
        entry.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1790305171065),
      );
      expect(entry.isExpired, isFalse);
    });

    test('returns null without an openai-codex entry', () {
      const json = '{"deepseek": {"type": "api_key", "apiKey": "sk-x"}}';
      expect(QuotaController.parseAuthEntry(json), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(QuotaController.parseAuthEntry('{oops'), isNull);
    });
  });

  group('QuotaController.parseUsage', () {
    test('maps the wham/usage payload to typed windows', () {
      const json = '''
      {
        "user_id": "user-1",
        "account_id": "acc-1",
        "email": "user@example.com",
        "plan_type": "plus",
        "rate_limit": {
          "allowed": true,
          "limit_reached": false,
          "primary_window": {
            "used_percent": 42,
            "limit_window_seconds": 18000,
            "reset_after_seconds": 9000,
            "reset_at": 1789756724
          },
          "secondary_window": {
            "used_percent": 79,
            "limit_window_seconds": 604800,
            "reset_after_seconds": 83595,
            "reset_at": 1789822318
          }
        },
        "credits": {
          "has_credits": false,
          "unlimited": false,
          "balance": "0"
        }
      }
      ''';
      final snapshot = QuotaController.parseUsage(json);
      expect(snapshot.email, 'user@example.com');
      expect(snapshot.planType, 'plus');
      expect(snapshot.allowed, isTrue);
      expect(snapshot.limitReached, isFalse);
      expect(snapshot.primaryWindow.usedPercent, 42);
      expect(snapshot.primaryWindow.limitWindowSeconds, 18000);
      expect(snapshot.primaryWindow.resetAt, 1789756724);
      expect(snapshot.primaryWindow.resetAtUtc, isNotNull);
      expect(snapshot.secondaryWindow?.usedPercent, 79);
      expect(snapshot.hasCredits, isFalse);
      expect(snapshot.creditsBalance, '0');
    });

    test('tolerates missing secondary window and credits block', () {
      const json = '''
      {
        "email": "",
        "plan_type": "",
        "rate_limit": {
          "allowed": true,
          "limit_reached": false,
          "primary_window": {"used_percent": "7"}
        }
      }
      ''';
      final snapshot = QuotaController.parseUsage(json);
      expect(snapshot.secondaryWindow, isNull);
      expect(snapshot.primaryWindow.usedPercent, 7);
      expect(snapshot.hasCredits, isFalse);
      expect(snapshot.creditsBalance, '0');
    });

    test('clamps out-of-range percentages', () {
      const json = '{"rate_limit": {"primary_window": {"used_percent": 250}}}';
      final snapshot = QuotaController.parseUsage(json);
      expect(snapshot.primaryWindow.usedPercent, 100);
    });
  });

  group('QuotaController.authJsonPath', () {
    test('prefers PI_CODING_AGENT_DIR, then falls back to ~/.pi/agent', () {
      final sep = Platform.pathSeparator;
      expect(
        QuotaController.authJsonPath({
          'PI_CODING_AGENT_DIR': 'C:${sep}custom',
          'USERPROFILE': 'C:${sep}Users${sep}me',
        }),
        'C:${sep}custom${sep}auth.json',
      );
      expect(
        QuotaController.authJsonPath({'USERPROFILE': 'C:${sep}Users${sep}me'}),
        'C:${sep}Users${sep}me$sep.pi${sep}agent${sep}auth.json',
      );
      expect(
        QuotaController.authJsonPath({'HOME': '/home/me'}),
        '/home/me/.pi/agent/auth.json',
      );
    });
  });
}
