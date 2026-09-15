import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/appearance_preferences.dart';

abstract interface class AppearanceStore {
  Future<AppearancePreferences> load();
  Future<void> save(AppearancePreferences preferences);
}

/// Versioned GUI-owned file, separate from Pi's private files and workspace.
class FileAppearanceStore implements AppearanceStore {
  FileAppearanceStore({Future<File> Function()? resolveFile})
    : _resolveFile = resolveFile ?? _defaultFile;
  final Future<File> Function() _resolveFile;
  static Future<File> _defaultFile() async => File(
    p.join((await getApplicationSupportDirectory()).path, 'appearance.json'),
  );

  @override
  Future<AppearancePreferences> load() async {
    final file = await _resolveFile();
    if (!await file.exists()) return AppearancePreferences();
    if (await file.length() > 65536) {
      throw const FormatException('appearance size');
    }
    return AppearancePreferences.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> save(AppearancePreferences preferences) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    // Writes are serialized by the controller; rename replaces only our own file.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(preferences.toJson()),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}
