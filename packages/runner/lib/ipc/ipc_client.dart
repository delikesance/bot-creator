import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RunnerIpcClient {
  RunnerIpcClient({required this.host, required this.port});

  final String host;
  final int port;

  Socket? _socket;
  StreamSubscription<String>? _lineSub;
  final Map<String, Completer<Map<String, dynamic>>> _pending =
      <String, Completer<Map<String, dynamic>>>{};
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  int _requestCounter = 0;

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  bool get isConnected => _socket != null;

  Future<void> connect({Duration timeout = const Duration(seconds: 5)}) async {
    if (_socket != null) {
      return;
    }

    final socket = await Socket.connect(host, port).timeout(timeout);
    _socket = socket;

    _lineSub = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleLine,
          onDone: _handleDisconnected,
          onError: (_) => _handleDisconnected(),
          cancelOnError: true,
        );
  }

  Future<void> close() async {
    final lineSub = _lineSub;
    _lineSub = null;
    if (lineSub != null) {
      await lineSub.cancel();
    }

    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close();
      } catch (_) {}
    }

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('IPC connection closed.'));
      }
    }
    _pending.clear();
  }

  Future<Map<String, dynamic>> request(
    String method, {
    Map<String, dynamic> params = const <String, dynamic>{},
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('RunnerIpcClient is not connected.');
    }

    final requestId =
        'req-${DateTime.now().microsecondsSinceEpoch}-${_requestCounter++}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestId] = completer;

    socket.writeln(
      jsonEncode(<String, dynamic>{
        'type': 'request',
        'id': requestId,
        'method': method,
        'params': params,
      }),
    );

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(requestId);
      throw TimeoutException('IPC request "$method" timed out.', timeout);
    }
  }

  Future<void> sendEvent(String name, Map<String, dynamic> payload) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('RunnerIpcClient is not connected.');
    }

    socket.writeln(
      jsonEncode(<String, dynamic>{
        'type': 'event',
        'name': name,
        'payload': payload,
        'ts': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  void _handleLine(String line) {
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return;
      }
      message = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    final type = (message['type'] ?? '').toString();
    if (type == 'event') {
      if (!_eventController.isClosed) {
        _eventController.add(message);
      }
      return;
    }

    if (type != 'response') {
      return;
    }

    final requestId = (message['id'] ?? '').toString();
    if (requestId.isEmpty) {
      return;
    }

    final completer = _pending.remove(requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }

    if (message['ok'] == true) {
      final data =
          (message['data'] is Map)
              ? Map<String, dynamic>.from(message['data'] as Map)
              : <String, dynamic>{};
      completer.complete(data);
      return;
    }

    final error = (message['error'] ?? 'Unknown IPC error').toString();
    completer.completeError(StateError(error));
  }

  void _handleDisconnected() {
    final socket = _socket;
    if (socket != null) {
      _socket = null;
    }

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('IPC connection closed.'));
      }
    }
    _pending.clear();
  }
}
