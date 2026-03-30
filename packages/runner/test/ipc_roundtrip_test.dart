import 'dart:async';

import 'package:bot_creator_runner/ipc/ipc_client.dart';
import 'package:bot_creator_runner/ipc/ipc_server.dart';
import 'package:test/test.dart';

void main() {
  group('Runner IPC', () {
    test('request/response roundtrip works', () async {
      final server = RunnerIpcServer(
        host: '127.0.0.1',
        port: 0,
        onRequest: (method, params) async {
          if (method == 'ping') {
            return <String, dynamic>{'pong': true, 'echo': params['value']};
          }
          throw StateError('unexpected method: $method');
        },
      );

      await server.start();
      addTearDown(server.stop);

      final client = RunnerIpcClient(host: '127.0.0.1', port: server.boundPort);
      await client.connect();
      addTearDown(client.close);

      final response = await client.request(
        'ping',
        params: <String, dynamic>{'value': 'hello'},
      );

      expect(response['pong'], isTrue);
      expect(response['echo'], 'hello');
    });

    test('client receives server broadcast events', () async {
      final eventCompleter = Completer<Map<String, dynamic>>();
      final server = RunnerIpcServer(
        host: '127.0.0.1',
        port: 0,
        onRequest: (method, params) async => <String, dynamic>{'ok': true},
      );

      await server.start();
      addTearDown(server.stop);

      final client = RunnerIpcClient(host: '127.0.0.1', port: server.boundPort);
      await client.connect();
      addTearDown(client.close);

      final sub = client.events.listen((event) {
        if (!eventCompleter.isCompleted) {
          eventCompleter.complete(event);
        }
      });
      addTearDown(sub.cancel);

      await server.broadcastEvent('runner.ready', <String, dynamic>{
        'botId': 'bot-1',
      });

      final event = await eventCompleter.future.timeout(
        const Duration(seconds: 5),
      );
      expect(event['type'], 'event');
      expect(event['name'], 'runner.ready');
      final payload = Map<String, dynamic>.from(event['payload'] as Map);
      expect(payload['botId'], 'bot-1');
    });
  });
}
