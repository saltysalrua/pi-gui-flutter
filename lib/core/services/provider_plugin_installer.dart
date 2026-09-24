import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Only called after the user confirms installation. Pi PackageManager owns
/// installation; this service prepares its persistent bundled source.
class ProviderPluginInstaller {
  /// Bundled plugin version; also the versioned install directory name.
  static const version = '2.0.0';
  static const _files = [
    'package.json',
    'extensions/provider-switch.ts',
    'extensions/provider-switch/inputs.ts',
    'extensions/provider-switch/catalog.mjs',
  ];

  /// `…/pi-provider-switch/<version>/…` of an installed extension path.
  static String? installedVersion(String path) =>
      RegExp(r'pi-provider-switch[\\/](\d+\.\d+\.\d+)[\\/]')
          .firstMatch(path)
          ?.group(1);

  static Future<String> prepareSource() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/pi-provider-switch/$version');
    for (final name in _files) {
      final target = File('${root.path}/$name');
      final content = await rootBundle.loadString('pi-provider-switch/$name');
      await target.parent.create(recursive: true);
      // Rewrite only when different, so an unchanged install stays untouched.
      if (!await target.exists() || await target.readAsString() != content) {
        await target.writeAsString(content, flush: true);
      }
    }
    return root.absolute.path;
  }
}
