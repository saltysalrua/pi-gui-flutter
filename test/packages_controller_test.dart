import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_packages_types.dart';
import 'package:pi_gui/ui/features/settings/controllers/packages_controller.dart';

void main() {
  group('PackagesController.parseRegistrySearch', () {
    test('parses the npm registry search payload', () {
      const payload = '''
{
  "objects": [
    {
      "package": {
        "name": "pi-lens",
        "version": "4.2.1",
        "description": "Real-time code feedback for pi",
        "keywords": ["pi-package", "extension"],
        "publisher": { "username": "apmantza" },
        "date": "2026-09-14T09:00:00.000Z",
        "links": {
          "repository": "git+https://github.com/apmantza/pi-lens.git",
          "npm": "https://www.npmjs.com/package/pi-lens"
        }
      },
      "downloads": { "monthly": 96000 },
      "searchScore": 42.5
    },
    {
      "package": {
        "name": "@scoped/skill-pkg",
        "version": "0.1.0",
        "keywords": ["pi-package", "skill"],
        "maintainers": [{ "username": "someone" }],
        "links": { "npm": "https://www.npmjs.com/package/@scoped/skill-pkg" }
      },
      "searchScore": 0.5
    },
    {
      "package": { "name": "", "version": "1.0.0" }
    },
    null
  ],
  "total": 4
}
''';
      final results = PackagesController.parseRegistrySearch(
        jsonDecode(payload),
      );
      expect(results, hasLength(2));
      final first = results.first;
      expect(first.name, 'pi-lens');
      expect(first.version, '4.2.1');
      expect(first.description, 'Real-time code feedback for pi');
      expect(first.publisher, 'apmantza');
      expect(first.monthlyDownloads, 96000);
      expect(first.updatedAt, startsWith('2026-09-14'));
      expect(first.repositoryUrl, contains('github.com'));
      expect(first.isExtension, isTrue);
      expect(first.isSkill, isFalse);
      expect(first.searchScore, 42.5);
      final second = results[1];
      expect(second.name, '@scoped/skill-pkg');
      expect(second.publisher, 'someone');
      expect(second.monthlyDownloads, isNull);
      expect(second.repositoryUrl, contains('npmjs.com'));
      expect(second.isSkill, isTrue);
      expect(second.searchScore, 0.5);
    });

    test('rejects malformed payloads without throwing', () {
      expect(PackagesController.parseRegistrySearch(null), isEmpty);
      expect(
        PackagesController.parseRegistrySearch(<String, dynamic>{}),
        isEmpty,
      );
      expect(
        PackagesController.parseRegistrySearch(<String, dynamic>{
          'objects': 'not-a-list',
        }),
        isEmpty,
      );
      expect(
        PackagesController.parseRegistrySearch(<String, dynamic>{
          'objects': [
            <String, dynamic>{'package': <String, dynamic>{}},
            <String, dynamic>{},
          ],
        }),
        isEmpty,
      );
    });
    test('sorts gallery results by the selected order', () {
      final a = GalleryPackage(
        name: 'zz-pkg',
        version: '1.0.0',
        updatedAt: '2026-01-01T00:00:00.000Z',
        monthlyDownloads: 10,
        searchScore: 1,
      );
      final b = GalleryPackage(
        name: 'mm-pkg',
        version: '1.0.0',
        updatedAt: '2026-06-01T00:00:00.000Z',
        monthlyDownloads: 500,
        searchScore: 9,
      );
      final c = GalleryPackage(
        name: 'aa-pkg',
        version: '1.0.0',
        updatedAt: '2026-03-01T00:00:00.000Z',
        searchScore: 4,
      );
      final items = [a, b, c];
      expect(
        PackagesController.sortGallery(
          items,
          GallerySort.relevance,
        ).map((e) => e.name),
        ['mm-pkg', 'aa-pkg', 'zz-pkg'],
      );
      expect(
        PackagesController.sortGallery(
          items,
          GallerySort.downloads,
        ).map((e) => e.name),
        ['mm-pkg', 'zz-pkg', 'aa-pkg'],
      );
      expect(
        PackagesController.sortGallery(
          items,
          GallerySort.updated,
        ).map((e) => e.name),
        ['mm-pkg', 'aa-pkg', 'zz-pkg'],
      );
      expect(
        PackagesController.sortGallery(
          items,
          GallerySort.name,
        ).map((e) => e.name),
        ['aa-pkg', 'mm-pkg', 'zz-pkg'],
      );
      // Sorting never mutates the controller's stored list.
      expect(items.first.name, 'zz-pkg');
    });
  });

  group('PiPackagesState.fromJson', () {
    // Regression: the resources map used to reach Map.unmodifiable inferred
    // as MapEntry<String, List<dynamic>>, so every real gui_packages_state
    // response crashed with a TypeError shown as a bare PACKAGES_FAILED.
    const payload = '''
{
  "version": 1,
  "agentDir": "C:/Users/x/.pi/agent",
  "packages": [
    { "source": "npm:fake-pkg", "scope": "user", "filtered": false,
      "installedPath": "C:/npm/fake-pkg" },
    { "source": "npm:filtered@1.0.0", "scope": "user", "filtered": true,
      "installedPath": null }
  ],
  "resources": {
    "extensions": [
      { "path": "C:/npm/fake-pkg/ext/index.ts", "enabled": true,
        "source": "npm:fake-pkg", "scope": "user", "origin": "package",
        "baseDir": "C:/npm/fake-pkg" },
      { "path": "C:/agent/extensions/local.ts", "enabled": false,
        "source": "local", "scope": "user", "origin": "top-level",
        "baseDir": null }
    ],
    "skills": [],
    "prompts": [],
    "themes": []
  }
}
''';

    test('maps gui_packages_state into typed packages and resources', () {
      final state = PiPackagesState.fromJson(jsonDecode(payload));
      expect(state.agentDir, 'C:/Users/x/.pi/agent');
      expect(state.packages, hasLength(2));
      expect(state.packages[0].source, 'npm:fake-pkg');
      expect(state.packages[0].displayName, 'fake-pkg');
      expect(state.packages[1].displayName, 'filtered');
      expect(state.packages[1].filtered, isTrue);
      expect(state.packages[1].installedPath, isNull);
      final extensions = state.resources['extensions']!;
      expect(extensions, hasLength(2));
      expect(extensions[0].path, 'C:/npm/fake-pkg/ext/index.ts');
      expect(extensions[0].origin, 'package');
      expect(extensions[0].baseDir, 'C:/npm/fake-pkg');
      expect(extensions[0].isUserScope, isTrue);
      expect(extensions[1].enabled, isFalse);
      expect(state.resources['skills'], isEmpty);
      expect(state.resources['themes'], isEmpty);
    });

    test('finished install events carry the same typed state', () {
      final finished = PiPackagesFinished.fromJson({
        'operationId': 'op-1',
        'kind': 'install',
        'ok': true,
        'data': jsonDecode(payload),
      });
      expect(finished.state, isNotNull);
      expect(finished.state!.packages, hasLength(2));
      expect(finished.state!.resources['extensions'], hasLength(2));
    });
  });
}
