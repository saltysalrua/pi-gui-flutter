import 'dart:convert';
import 'dart:io';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';

/// 真实进程探针：不发送 Prompt，不调用 LLM，不读取 Pi 私有文件。
Future<void> main(List<String> arguments) async {
  final pi = PiRpcClient(extraArguments: ['--no-session']);
  final watchOption = arguments
      .where((arg) => arg.startsWith('--watch-seconds='))
      .firstOrNull;
  final watchSeconds = watchOption == null
      ? 0
      : int.parse(watchOption.split('=').last);
  if (watchSeconds < 0 || watchSeconds > 3600) {
    throw ArgumentError('watch-seconds must be 0..3600');
  }
  var checks = 0;
  try {
    final models = await pi.getAvailableModels();
    final state = await pi.getState();
    final levels = await pi.getAvailableThinkingLevels();
    if (arguments.contains('--verify-write') && state.model != null) {
      // 只写回当前值，验证写路径，不改变用户选择。
      await pi.setModel(state.model!);
      await pi.setThinkingLevel(state.thinkingLevel);
      final confirmed = await pi.getState();
      if (!state.model!.sameIdentity(confirmed.model) ||
          state.thinkingLevel != confirmed.thinkingLevel) {
        throw StateError('Pi did not confirm the same selection');
      }
    }
    final watch = Stopwatch()..start();
    while (watch.elapsed.inSeconds < watchSeconds) {
      final remaining = watchSeconds - watch.elapsed.inSeconds;
      await Future<void>.delayed(
        Duration(seconds: remaining < 4 ? remaining : 4),
      );
      await pi.getAvailableModels();
      await pi.getState();
      await pi.getAvailableThinkingLevels();
      checks++;
      if (pi.connectionCount != 1) {
        throw StateError('Pi reconnected during the stability check');
      }
    }
    stdout.writeln(
      jsonEncode({
        'modelCount': models.length,
        'watchSeconds': watchSeconds,
        'checks': checks,
        'connections': pi.connectionCount,
        'lastDisconnectReason': pi.lastDisconnectReason?.name,
        'diagnostics': pi.diagnostics.map((entry) => entry.kind.name).toList(),
        'currentModel': state.model == null
            ? null
            : '${state.model!.provider}/${state.model!.id}',
        'thinkingLevel': state.thinkingLevel.name,
        'availableThinkingLevels': levels.map((level) => level.name).toList(),
        'writeVerified':
            arguments.contains('--verify-write') && state.model != null,
      }),
    );
  } finally {
    await pi.close();
  }
}
