import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 只按 LF 分帧；不把 JSON 字符串里的 CR / U+2028 / U+2029 当换行。
Stream<String> decodePiJsonl(Stream<List<int>> bytes) async* {
  var buffer = '';
  await for (final chunk in bytes.transform(utf8.decoder)) {
    buffer += chunk;
    int newline;
    while ((newline = buffer.indexOf('\n')) >= 0) {
      var line = buffer.substring(0, newline);
      buffer = buffer.substring(newline + 1);
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.isNotEmpty) yield line;
    }
  }
  if (buffer.endsWith('\r')) buffer = buffer.substring(0, buffer.length - 1);
  if (buffer.isNotEmpty) yield buffer;
}

abstract interface class PiRpcTransport {
  Stream<List<int>> get stdout;
  Future<void> send(String line);
  Future<void> close();
}

class PiProcessTransport implements PiRpcTransport {
  PiProcessTransport._(this._process) {
    // 必须持续排空 stderr，不能混入 JSONL 或将潜在密钥写进 UI/日志。
    _stderr = _process.stderr.listen((_) {}, onError: (Object _) {});
    unawaited(_process.stdin.done.then<void>((_) {}, onError: (Object _) {}));
  }

  static Future<PiProcessTransport> start({
    String? workingDirectory,
    List<String> extraArguments = const [],
  }) async {
    final process = await Process.start(
      'pi', // Windows 通过 PATHEXT 同时兼容 npm 的 pi.cmd 与独立 pi.exe。
      ['--mode', 'rpc', ...extraArguments],
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );
    return PiProcessTransport._(process);
  }

  static Future<PiProcessTransport> startAdapter(String scriptPath) async =>
      PiProcessTransport._(await Process.start('node', [scriptPath]));

  final Process _process;
  late final StreamSubscription<List<int>> _stderr;
  Future<void>? _closing;
  Future<void> _writing = Future.value();

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Future<void> send(String line) {
    // RPC 命令和扩展回复共用一个 stdin，逐帧串行 flush，避免 sink 竞争。
    final writing = _writing.then((_) async {
      if (_closing != null) throw StateError('Pi transport is closing');
      _process.stdin.add(utf8.encode(line));
      await _process.stdin.flush();
    });
    _writing = writing.then<void>((_) {}, onError: (Object _) {});
    return writing;
  }

  @override
  Future<void> close() => _closing ??= _stop();

  Future<void> _stop() async {
    // Windows 的 npm shim 会生成 cmd -> node，必须清理本客户端的整棵树。
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', [
          '/PID',
          '${_process.pid}',
          '/T',
          '/F',
        ]).timeout(const Duration(seconds: 3));
      } else {
        _process.kill();
      }
      await _process.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      _process.kill(ProcessSignal.sigkill);
    } finally {
      await _stderr.cancel();
    }
  }
}
