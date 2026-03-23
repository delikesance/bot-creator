import 'dart:convert';
import 'dart:io';

import 'package:bot_creator_runner/web_bootstrap_server.dart';
import 'package:bot_creator_runner/web_log_store.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('RunnerWebBootstrapServer', () {
    late Directory tempDir;
    late String originalCwd;
    RunnerWebBootstrapServer? server;

    setUp(() async {
      originalCwd = Directory.current.path;
      tempDir = await Directory.systemTemp.createTemp('runner-web-server-');
      Directory.current = tempDir.path;
    });

    tearDown(() async {
      await server?.stop();
      Directory.current = originalCwd;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'loopback host without token allows protected status endpoint',
      () async {
        final port = await _allocatePort();
        server = RunnerWebBootstrapServer(
          host: '127.0.0.1',
          port: port,
          logStore: RunnerLogStore(),
        );
        await server!.start();

        final response = await http.get(
          Uri.parse('http://127.0.0.1:$port/status'),
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(
          (jsonDecode(response.body) as Map<String, dynamic>)['apiVersion'],
          2,
        );
      },
    );

    test(
      'requires bearer auth on protected endpoints when token configured',
      () async {
        final port = await _allocatePort();
        server = RunnerWebBootstrapServer(
          host: '127.0.0.1',
          port: port,
          apiToken: 'secret-token',
          logStore: RunnerLogStore(),
        );
        await server!.start();

        final noAuth = await http.get(
          Uri.parse('http://127.0.0.1:$port/status'),
        );
        final wrongAuth = await http.get(
          Uri.parse('http://127.0.0.1:$port/status'),
          headers: <String, String>{'authorization': 'Bearer wrong-token'},
        );
        final okAuth = await http.get(
          Uri.parse('http://127.0.0.1:$port/status'),
          headers: <String, String>{'authorization': 'Bearer secret-token'},
        );
        final health = await http.get(
          Uri.parse('http://127.0.0.1:$port/health'),
        );

        expect(noAuth.statusCode, HttpStatus.unauthorized);
        expect(wrongAuth.statusCode, HttpStatus.unauthorized);
        expect(okAuth.statusCode, HttpStatus.ok);
        expect(health.statusCode, HttpStatus.ok);
        expect((jsonDecode(health.body) as Map<String, dynamic>)['ok'], isTrue);
      },
    );
  });
}

Future<int> _allocatePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
