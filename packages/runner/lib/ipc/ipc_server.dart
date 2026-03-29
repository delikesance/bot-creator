import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef IpcRequestHandler =
    FutureOr<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> params,
    );

typedef IpcEventHandler =
    FutureOr<void> Function(String name, Map<String, dynamic> payload);

class RunnerIpcServer {
  RunnerIpcServer({
    required this.host,
    required this.port,
    required this.onRequest,
    this.onEvent,
  });

  final String host;
  final int port;
  final IpcRequestHandler onRequest;
  final IpcEventHandler? onEvent;

  ServerSocket? _server;
  final Set<Socket> _clients = <Socket>{};
  final Set<StreamSubscription<String>> _lineSubscriptions =
      <StreamSubscription<String>>{};

  int get boundPort => _server?.port ?? port;

  Future<void> start() async {
    if (_server != null) {
      return;
    }

    _server = await ServerSocket.bind(host, port);
    _server!.listen(_handleSocket);
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;

    for (final sub in _lineSubscriptions.toList(growable: false)) {
      await sub.cancel();
    }
    _lineSubscriptions.clear();

    for (final socket in _clients.toList(growable: false)) {
      try {
        await socket.close();
      } catch (_) {}
    }
    _clients.clear();

    if (server != null) {
      await server.close();
    }
  }

  Future<void> broadcastEvent(String name, Map<String, dynamic> payload) async {
    final message = jsonEncode(<String, dynamic>{
      'type': 'event',
      'name': name,
      'payload': payload,
      'ts': DateTime.now().toUtc().toIso8601String(),
    });

    for (final socket in _clients.toList(growable: false)) {
      try {
        socket.writeln(message);
      } catch (_) {
        _clients.remove(socket);
      }
    }
  }

  void _handleSocket(Socket socket) {
    _clients.add(socket);

    late final StreamSubscription<String> sub;
    sub = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => unawaited(_handleLine(socket, line)),
          onDone: () {
            _clients.remove(socket);
            _lineSubscriptions.remove(sub);
          },
          onError: (_) {
            _clients.remove(socket);
            _lineSubscriptions.remove(sub);
          },
          cancelOnError: true,
        );
    _lineSubscriptions.add(sub);
  }

  Future<void> _handleLine(Socket socket, String line) async {
    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return;
      }
      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    final type = (payload['type'] ?? '').toString();
    if (type == 'event') {
      final name = (payload['name'] ?? '').toString();
      final eventPayload =
          (payload['payload'] is Map)
              ? Map<String, dynamic>.from(payload['payload'] as Map)
              : <String, dynamic>{};
      final handler = onEvent;
      if (handler != null && name.isNotEmpty) {
        await handler(name, eventPayload);
      }
      return;
    }

    if (type != 'request') {
      return;
    }

    final requestId = (payload['id'] ?? '').toString();
    final method = (payload['method'] ?? '').toString();
    final params =
        (payload['params'] is Map)
            ? Map<String, dynamic>.from(payload['params'] as Map)
            : <String, dynamic>{};

    if (requestId.isEmpty || method.isEmpty) {
      return;
    }

    try {
      final result = await onRequest(method, params);
      socket.writeln(
        jsonEncode(<String, dynamic>{
          'type': 'response',
          'id': requestId,
          'ok': true,
          'data': result,
          'ts': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (error) {
      socket.writeln(
        jsonEncode(<String, dynamic>{
          'type': 'response',
          'id': requestId,
          'ok': false,
          'error': error.toString(),
          'ts': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    }
  }
}
