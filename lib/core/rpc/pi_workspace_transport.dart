import 'dart:io';

import 'package:flutter/services.dart';

import 'pi_rpc_transport.dart';

/// Ships the adapter with the app; no dependency on the app's launch directory.
class PiWorkspaceTransport implements PiRpcTransport {
  PiWorkspaceTransport._(this._transport, this._directory);
  final PiRpcTransport _transport;
  final Directory _directory;
  Future<void>? _closing;

  static Future<PiWorkspaceTransport> start() async {
    final directory = await Directory.systemTemp.createTemp('pi-gui-rpc-');
    try {
      for (final name in [
        'workspace_rpc.mjs',
        'workspace_manager.mjs',
        'workspace_browser.mjs',
        'gui_tool_diff.mjs',
        'gui_history.mjs',
        'gui_image_upload.mjs',
        'gui_packages.mjs',
        'gui_provider_profiles.mjs',
      ]) {
        final script = await rootBundle.loadString('assets/backend/$name');
        await File('${directory.path}/$name')
            .writeAsString(script, flush: true);
      }
      // The provider settings adapter shares listing/capability rules with
      // the bundled pi-provider-switch plugin instead of duplicating them.
      await File('${directory.path}/provider_catalog.mjs').writeAsString(
        await rootBundle.loadString(
          'pi-provider-switch/extensions/provider-switch/catalog.mjs',
        ),
        flush: true,
      );
      final file = File('${directory.path}/workspace_rpc.mjs');
      return PiWorkspaceTransport._(
        await PiProcessTransport.startAdapter(
          file.path,
          arguments: const ['--gui-multiplex'],
        ),
        directory,
      );
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Stream<List<int>> get stdout => _transport.stdout;
  @override
  Future<void> send(String line) => _transport.send(line);
  @override
  Future<void> close() => _closing ??= _stop();
  Future<void> _stop() async {
    try {
      await _transport.close();
    } finally {
      try {
        await _directory.delete(recursive: true);
      } on FileSystemException {
        /* OS may still hold the script. */
      }
    }
  }
}
