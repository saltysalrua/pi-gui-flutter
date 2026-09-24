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
  StreamSubscription<Object?>? _subscription;
  bool _closed = false, _lost = false;

  /// One client owns one lease. Reconnecting that client must never resurrect
  /// an exited channel, even after the hub has released its routing entry.
  Future<PiRpcTransport> Function() transportFor(String id) {
    Future<_ChannelTransport>? attached;
    return () async {
      final channel = await (attached ??= _attach(id));
      if (_closed || _lost || channel.closed) {
        throw StateError('Session disconnected');
      }
      return channel;
    };
  }

  /// Includes the buffered primary channel, but never closed routing entries.
  int get channelCount => _channels.length;

  Future<_ChannelTransport> _attach(String id) async {
    if (_closed || _lost) throw StateError('Supervisor disconnected');
    final channel = _channels.putIfAbsent(
      id,
      () => _ChannelTransport(this, id),
    );
    if (channel.closed) throw StateError('Session disconnected');
    await (_starting ??= _start());
    if (_closed || _lost || channel.closed) {
      throw StateError('Session disconnected');
    }
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
      // One decode per frame: the routed inner message is handed to the
      // logical client as a Map, never re-encoded and parsed a second time.
      _subscription = decodePiJsonValues(transport.stdout).listen(
        (value) {
          if (value is! Map || value['type'] != 'gui_channel') return;
          final channel = _channels[value['channel']];
          if (channel == null || channel.closed) return;
          final message = value['message'];
          if (message is Map && message['type'] == 'gui_channel_exited') {
            unawaited(channel.close());
          } else if (value['line'] is String) {
            // Node forwards unparsable Pi stdout verbatim as `line`.
            channel.output.add(PiNonProtocolLine(value['line'] as String));
          } else {
            channel.output.add(message);
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
    for (final channel in _channels.values.toList()) {
      unawaited(channel.close());
    }
  }

  void _detach(_ChannelTransport channel) {
    if (identical(_channels[channel.id], channel)) {
      _channels.remove(channel.id);
    }
  }

  Future<void> _send(String id, Object? message) async {
    if (_closed || _lost || _transport == null) {
      throw StateError('Supervisor disconnected');
    }
    await _transport!.send(
      '${jsonEncode({'type': 'gui_channel', 'channel': id, 'message': message})}\n',
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

class _ChannelTransport implements PiRpcMessageTransport {
  _ChannelTransport(this.hub, this.id);
  final PiChannelHub hub;
  final String id;
  final output = StreamController<Object?>();
  bool closed = false;

  @override
  Stream<Object?> get messages => output.stream;

  /// Byte view for generic consumers only; PiRpcClient uses [messages].
  @override
  Stream<List<int>> get stdout => output.stream.map(
    (value) => utf8.encode(
      '${value is PiNonProtocolLine ? value.text : jsonEncode(value)}\n',
    ),
  );

  @override
  Future<void> sendMessage(Map<String, Object?> message) async {
    if (closed) throw StateError('Session disconnected');
    await hub._send(id, message);
  }

  @override
  Future<void> send(String line) async {
    if (closed) throw StateError('Session disconnected');
    await hub._send(id, jsonDecode(line));
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    hub._detach(this);
    // An unlistened buffered startup stream must not block app shutdown.
    unawaited(output.close());
  }
}
