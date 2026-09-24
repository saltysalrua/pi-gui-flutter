import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// 只按 LF 字节分帧；不把 JSON 字符串里的 CR / U+2028 / U+2029 当换行。
/// UTF-8 多字节序列里不会出现 0x0A，所以按字节切分与按字符切分等价，
/// 但省掉整行先转成 Dart String 再解析的那一次完整复制。
Stream<Uint8List> splitPiJsonlBytes(Stream<List<int>> input) async* {
  final carry = BytesBuilder();
  Uint8List? trim(Uint8List line) {
    final end = line.isNotEmpty && line.last == 13
        ? line.length - 1
        : line.length;
    if (end == 0) return null;
    return end == line.length ? line : Uint8List.sublistView(line, 0, end);
  }

  await for (final raw in input) {
    final chunk = raw is Uint8List ? raw : Uint8List.fromList(raw);
    var start = 0;
    int newline;
    // Scan each chunk once; a large get_messages line never rescans its prefix.
    while ((newline = chunk.indexOf(10, start)) >= 0) {
      var line = Uint8List.sublistView(chunk, start, newline);
      start = newline + 1;
      if (carry.isNotEmpty) {
        carry.add(line);
        line = carry.takeBytes();
      }
      final framed = trim(line);
      if (framed != null) yield framed;
    }
    if (start < chunk.length) {
      carry.add(Uint8List.sublistView(chunk, start));
    }
  }
  final tail = trim(carry.takeBytes());
  if (tail != null) yield tail;
}

/// 字符串形式的分帧，仅供工具脚本/测试使用；客户端走 [decodePiJsonValues]。
Stream<String> decodePiJsonl(Stream<List<int>> bytes) =>
    splitPiJsonlBytes(bytes).map((line) => utf8.decode(line));

/// stdout 上不是合法 JSON 的一行（扩展日志、坏 UTF-8 等）。只作诊断，不断连。
final class PiNonProtocolLine {
  const PiNonProtocolLine(this.text);
  final String text;
}

/// 超过这个字节数的单行（整包历史、超大工具结果）放到后台 Isolate 解码，
/// 避免在 UI 线程上卡住几十到几百毫秒。小事件同步解码，没有调度开销。
const piJsonIsolateThreshold = 1 << 20;

final _jsonUtf8 = utf8.decoder.fuse(json.decoder);

Object? _decodeFrame(Uint8List line) {
  try {
    return _jsonUtf8.convert(line);
  } on FormatException {
    return PiNonProtocolLine(utf8.decode(line, allowMalformed: true));
  }
}

/// 分帧 + 直接从字节解码为 JSON 值（Map/List/...），坏行变成 [PiNonProtocolLine]。
/// asyncMap 保证顺序：大行在后台解码时，后面的小事件会等它完成再派发。
Stream<Object?> decodePiJsonValues(Stream<List<int>> bytes) =>
    splitPiJsonlBytes(bytes).asyncMap<Object?>(
      (line) => line.length >= piJsonIsolateThreshold
          ? Isolate.run(() => _decodeFrame(line))
          : _decodeFrame(line),
    );

abstract interface class PiRpcTransport {
  Stream<List<int>> get stdout;
  Future<void> send(String line);
  Future<void> close();
}

/// 进程内逻辑通道：直接交换已解码的 JSON 值，不再为同一条消息
/// 重复“编码成文本 → 转字节 → 再分帧解码”。
abstract interface class PiRpcMessageTransport implements PiRpcTransport {
  /// 已解码的消息；坏行以 [PiNonProtocolLine] 传递。
  Stream<Object?> get messages;
  Future<void> sendMessage(Map<String, Object?> message);
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

  static Future<PiProcessTransport> startAdapter(
    String scriptPath, {
    List<String> arguments = const [],
  }) async => PiProcessTransport._(
    await Process.start('node', [scriptPath, ...arguments]),
  );

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
