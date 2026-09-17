import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/ui/features/settings/controllers/pi_update_controller.dart';

void main() {
  group('PiUpdateController.parseChangelog', () {
    test('splits version sections and trims bodies', () {
      const text = '''
# Changelog

## [0.85.1] - 2026-09-05

### Added

- Added something.

## [0.85.0] - 2026-09-04

### Fixed

- Fixed something.

''';
      final entries = PiUpdateController.parseChangelog(text);
      expect(entries, hasLength(2));
      expect(entries.first.version, '0.85.1');
      expect(entries.first.date, '2026-09-05');
      expect(entries.first.body, '### Added\n\n- Added something.');
      expect(entries.last.version, '0.85.0');
      expect(entries.last.date, '2026-09-04');
      expect(entries.last.body, '### Fixed\n\n- Fixed something.');
    });

    test('keeps the preamble out of entries', () {
      final entries = PiUpdateController.parseChangelog(
        '# Changelog\n\nonly a preamble',
      );
      expect(entries, isEmpty);
    });

    test('matches by version and body text', () {
      final entries = PiUpdateController.parseChangelog(
        '## [0.9.0] - 2026-01-01\n\n- Added fullscreen support.',
      );
      expect(entries.single.matches('0.9.0'), isTrue);
      expect(entries.single.matches('fullscreen'), isTrue);
      expect(entries.single.matches('0.8.0'), isFalse);
      expect(entries.single.matches(''), isTrue);
    });
  });

  group('PiUpdateController.compareVersions', () {
    test('compares numeric parts', () {
      expect(PiUpdateController.compareVersions('0.85.1', '0.85.1'), 0);
      expect(
        PiUpdateController.compareVersions('0.85.0', '0.85.1') < 0,
        isTrue,
      );
      expect(
        PiUpdateController.compareVersions('0.86.0', '0.85.9') > 0,
        isTrue,
      );
      expect(
        PiUpdateController.compareVersions('1.0.0', '0.99.99') > 0,
        isTrue,
      );
      // 1.10.0 > 1.9.0 despite string comparison saying otherwise.
      expect(PiUpdateController.compareVersions('1.10.0', '1.9.0') > 0, isTrue);
    });

    test('ignores prerelease suffixes and missing parts', () {
      expect(PiUpdateController.compareVersions('0.85.1-beta.1', '0.85.1'), 0);
      expect(PiUpdateController.compareVersions('0.85', '0.85.0'), 0);
      expect(
        PiUpdateController.compareVersions('0.85.1.2', '0.85.1') > 0,
        isTrue,
      );
    });
  });
}
