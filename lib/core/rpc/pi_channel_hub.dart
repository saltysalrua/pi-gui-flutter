import 'dart:async';
import 'dart:convert';

import 'pi_rpc_transport.dart';

/// Multiplexes logical clients over ONE physical adapter. A channel close never
/// closes another channel or the supervisor. No prompts are replayed on failure.
class PiChannelHub {
  PiChannelHub(this._factory);
  final Future<PiRpcTransport> Function() _factory;
  final _channels = <String, _ChannelTransport>{};
  PiRpcTransport? _transport;
  Future<void>? _starting;
  StreamSubscription<String>? _subscription;
  bool _closed = false, _lost = false;

  Future<PiRpcTransport> attach(String id) async {
    if (_closed || _lost) throw StateError('Supervisor disconnected');
    final channel = _channels.putIfAbsent(
      id,
      () => _ChannelTransport(this, id),
    );
    if (channel.closed) throw StateError('Session disconnected');
    await (_starting ??= _start());
    return channel;
  }

  Future<void> _start() async {
    try {
      final transport = await _factory();
      if (_closed) {
        await transport.close();
        return;
      }
      _transport = transport;
      // Buffer startup UI requests until the primary client subscribes.
      _channels.putIfAbsent(
        'primary',
        () => _ChannelTransport(this, 'primary'),
      );
      _subscription = decodePiJsonl(transport.stdout).listen(
        (line) {
          Object? value;
          try {
            value = jsonDecode(line);
          } catch (_) {
            return;
          }
          if (value is! Map || value['type'] != 'gui_channel') return;
          final channel = _channels[value['channel']];
          if (channel == null || channel.closed) return;
          final message = value['message'];
          if (message is Map && message['type'] == 'gui_channel_exited') {
            unawaited(channel.close());
          } else {
            final text = value['line'] is String
                ? value['line'] as String
                : jsonEncode(message);
            channel.output.add(utf8.encode('$text\n'));
          }
        },
        onError: (Object _) => _disconnect(),
        onDone: _disconnect,
      );
    } catch (_) {
      _disconnect();
      rethrow;
    }
  }

  void _disconnect() {
    _lost = true;
    for (final channel in _channels.values) {
      unawaited(channel.close());
    }
  }

  Future<void> _send(String id, String line) async {
    if (_closed || _lost || _transport == null) {
      throw StateError('Supervisor disconnected');
    }
    await _transport!.send(
      '${jsonEncode({'type': 'gui_channel', 'channel': id, 'message': jsonDecode(line)})}\n',
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final cancelling = _subscription?.cancel();
    // A decoder can be awaiting the next byte. Close the pipe before awaiting
    // cancellation, just as PiRpcClient does for an ordinary transport.
    await _transport?.close();
    await cancelling;
    _disconnect();
  }
}

class _ChannelTransport implements PiRpcTransport {
  _ChannelTransport(this.hub, this.id);
  final PiChannelHub hub;
  final String id;
  final output = StreamController<List<int>>();
  bool closed = false;
  @override
  Stream<List<int>> get stdout => output.stream;
  @override
  Future<void> send(String line) async {
    if (closed) throw StateError('Session disconnected');
    await hub._send(id, line);
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    // An unlistened buffered startup stream must not block app shutdown.
    unawaited(output.close());
  }
}
