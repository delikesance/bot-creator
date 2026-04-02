import 'dart:convert';
import 'dart:io';

import 'package:bot_creator_shared/bot/json_variable_store.dart';
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

    test('supports variable endpoints for global/scoped data', () async {
      final port = await _allocatePort();
      final variableStore = JsonVariableStore();
      server = RunnerWebBootstrapServer(
        host: '127.0.0.1',
        port: port,
        logStore: RunnerLogStore(),
        variableStore: variableStore,
      );
      await server!.start();

      final base = Uri.parse('http://127.0.0.1:$port');
      const botId = 'bot-variables';

      final sync = await http.post(
        base.resolve('/bots/sync'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'botId': botId,
          'botName': 'Test Bot',
          'config': <String, dynamic>{
            'token': 'abc',
            'globalVariables': <String, dynamic>{'foo': 'bar'},
            'scopedVariableDefinitions': <Map<String, dynamic>>[
              <String, dynamic>{
                'scope': 'user',
                'key': 'coins',
                'defaultValue': 0,
                'valueType': 'number',
              },
            ],
          },
        }),
      );
      expect(sync.statusCode, HttpStatus.ok);

      final getGlobals = await http.get(
        base.resolve('/bots/$botId/variables/global'),
      );
      final globalsJson = Map<String, dynamic>.from(
        jsonDecode(getGlobals.body) as Map,
      );
      expect(getGlobals.statusCode, HttpStatus.ok);
      expect(globalsJson['variables']['foo'], 'bar');

      final setGlobal = await http.post(
        base.resolve('/bots/$botId/variables/global/set'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'key': 'hello', 'value': 42}),
      );
      expect(setGlobal.statusCode, HttpStatus.ok);

      final getGlobalsAfterSet = await http.get(
        base.resolve('/bots/$botId/variables/global'),
      );
      final globalsAfterSetJson = Map<String, dynamic>.from(
        jsonDecode(getGlobalsAfterSet.body) as Map,
      );
      expect(globalsAfterSetJson['variables']['hello'], 42);

      final removeGlobal = await http.post(
        base.resolve('/bots/$botId/variables/global/remove'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'key': 'hello'}),
      );
      expect(removeGlobal.statusCode, HttpStatus.ok);

      final defs = await http.get(
        base.resolve('/bots/$botId/variables/scoped-definitions'),
      );
      final defsJson = Map<String, dynamic>.from(jsonDecode(defs.body) as Map);
      expect(defs.statusCode, HttpStatus.ok);
      expect((defsJson['definitions'] as List).length, 1);

      final setDef = await http.post(
        base.resolve('/bots/$botId/variables/scoped-definitions/set'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'scope': 'user',
          'key': 'score',
          'defaultValue': 10,
          'valueType': 'number',
        }),
      );
      expect(setDef.statusCode, HttpStatus.ok);

      final removeDef = await http.post(
        base.resolve('/bots/$botId/variables/scoped-definitions/remove'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'scope': 'user', 'key': 'score'}),
      );
      expect(removeDef.statusCode, HttpStatus.ok);

      await variableStore.setScopedVariable(botId, 'user', 'u1', 'coins', 99);
      await variableStore.setScopedVariable(
        botId,
        'user',
        'u2',
        'bc_legacy',
        'yes',
      );

      final scopedValues = await http.get(
        base.resolve(
          '/bots/$botId/variables/scoped-values?scope=user&key=coins',
        ),
      );
      final scopedJson = Map<String, dynamic>.from(
        jsonDecode(scopedValues.body) as Map,
      );
      expect(scopedValues.statusCode, HttpStatus.ok);
      expect(scopedJson['values']['u1'], 99);

      final legacyValues = await http.get(
        base.resolve(
          '/bots/$botId/variables/scoped-values?scope=user&key=legacy',
        ),
      );
      final legacyJson = Map<String, dynamic>.from(
        jsonDecode(legacyValues.body) as Map,
      );
      expect(legacyValues.statusCode, HttpStatus.ok);
      expect(legacyJson['values']['u2'], 'yes');
    });

    test('exposes inbound webhook endpoint contract', () async {
      final port = await _allocatePort();
      server = RunnerWebBootstrapServer(
        host: '127.0.0.1',
        port: port,
        logStore: RunnerLogStore(),
      );
      await server!.start();

      final base = Uri.parse('http://127.0.0.1:$port');
      const botId = 'bot-inbound';

      final sync = await http.post(
        base.resolve('/bots/sync'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'botId': botId,
          'botName': 'Inbound Bot',
          'config': <String, dynamic>{
            'token': 'abc',
            'inboundWebhooks': true,
            'inboundWebhookEndpoints': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'wh_1',
                'path': 'incoming/orders',
                'workflowName': 'incoming',
                'secret': 'top-secret',
                'enabled': true,
              },
            ],
            'workflows': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'incoming',
                'workflowType': 'general',
                'entryPoint': 'main',
                'actions': <Map<String, dynamic>>[],
              },
            ],
          },
        }),
      );
      expect(sync.statusCode, HttpStatus.ok);

      final noSecret = await http.post(
        base.resolve('/bots/$botId/inbound/incoming/orders'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'hello': 'world'}),
      );
      expect(noSecret.statusCode, HttpStatus.unauthorized);

      final response = await http.post(
        base.resolve('/bots/$botId/inbound/incoming/orders'),
        headers: const <String, String>{
          'content-type': 'application/json',
          'x-bot-webhook-secret': 'top-secret',
        },
        body: jsonEncode(<String, dynamic>{'hello': 'world'}),
      );

      expect(response.statusCode, HttpStatus.conflict);
      final json = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      expect((json['error'] ?? '').toString(), contains('not running'));
    });
  });
}

Future<int> _allocatePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
