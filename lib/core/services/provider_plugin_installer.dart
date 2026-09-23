import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Only called after the user confirms installation. Pi PackageManager owns
/// installation; this service prepares its persistent bundled source.
class ProviderPluginInstaller {
  static Future<String> prepareSource() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/pi-provider-switch/1.0.0');
    for (final name in [
      'package.json',
      'extensions/provider-switch.ts',
      'extensions/provider-switch/inputs.ts',
    ]) {
      final target = File('${root.path}/$name');
      await target.parent.create(recursive: true);
      if (!await target.exists()) {
        await target.writeAsString(
          await rootBundle.loadString('pi-provider-switch/$name'),
          flush: true,
        );
      }
    }
    return root.absolute.path;
  }
}
