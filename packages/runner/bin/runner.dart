import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:bot_creator_runner/web_log_store.dart';
import 'package:bot_creator_runner/web_bootstrap_server.dart';
import 'package:bot_creator_runner/web_runtime_config.dart';
import 'package:logging/logging.dart';

const _usageHeader =
    'Bot Creator Runner\n'
    '\n'
    'Runner API only.\n'
    'Exposes a REST API used by the Bot Creator app to sync/start/stop bots.\n'
    '\n'
    'Usage:\n'
    '  dart run packages/runner/bin/runner.dart\n'
    '  dart run packages/runner/bin/runner.dart --web-host 0.0.0.0 --web-port 8080 --api-token changeme\n';

Future<void> main(List<String> args) async {
  final parser =
      ArgParser()
        ..addOption(
          'web-host',
          help: 'Host/interface used by API mode.',
          valueHelp: '127.0.0.1',
          defaultsTo:
              Platform.environment['BOT_CREATOR_WEB_HOST'] ?? '127.0.0.1',
        )
        ..addOption(
          'web-port',
          help: 'Port used by API mode.',
          valueHelp: '8080',
          defaultsTo: Platform.environment['BOT_CREATOR_WEB_PORT'] ?? '8080',
        )
        ..addOption(
          'api-token',
          help: 'Bearer token required by protected API endpoints.',
          valueHelp: 'secret-token',
          defaultsTo: Platform.environment['BOT_CREATOR_API_TOKEN'] ?? '',
        )
        ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help.');

  late final ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    stderr.writeln('Invalid arguments: $e');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (results.flag('help')) {
    _printUsage(parser);
    return;
  }

  final webHost = (results.option('web-host') ?? '').trim();
  final webPortRaw = (results.option('web-port') ?? '').trim();
  final apiToken = normalizeRunnerApiToken(results.option('api-token'));
  if (results.rest.isNotEmpty) {
    stderr.writeln(
      'Unexpected positional arguments: ${results.rest.join(' ')}',
    );
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  final webPort = int.tryParse(webPortRaw);
  if (webHost.isEmpty || webPort == null || webPort <= 0 || webPort > 65535) {
    stderr.writeln('Invalid API options: --web-host or --web-port.');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  final configError = validateRunnerWebConfiguration(
    host: webHost,
    apiToken: apiToken,
  );
  if (configError != null) {
    stderr.writeln(configError);
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  Logger.root.level = Level.INFO;
  await _runWebMode(host: webHost, port: webPort, apiToken: apiToken);
}

void _printUsage(ArgParser parser) {
  stdout
    ..writeln(_usageHeader)
    ..writeln(parser.usage);
}

Future<void> _runWebMode({
  required String host,
  required int port,
  required String apiToken,
}) async {
  final logStore = RunnerLogStore();
  final logSubscription = Logger.root.onRecord.listen((record) {
    final errorPart = record.error == null ? '' : ' | ${record.error}';
    stdout.writeln(
      '[${record.level.name}] ${record.loggerName}: ${record.message}$errorPart',
    );
    if (record.stackTrace != null) {
      stdout.writeln(record.stackTrace);
    }
    logStore.add(record);
  });

  final server = RunnerWebBootstrapServer(
    host: host,
    port: port,
    apiToken: apiToken,
    logStore: logStore,
  );

  final shutdownCompleter = Completer<void>();
  Future<void> shutdown() async {
    if (shutdownCompleter.isCompleted) {
      return;
    }
    shutdownCompleter.complete();
    await server.stop();
  }

  final signalSubscriptions = <StreamSubscription<ProcessSignal>>[
    ProcessSignal.sigint.watch().listen((_) {
      unawaited(shutdown());
    }),
  ];
  if (!Platform.isWindows) {
    signalSubscriptions.add(
      ProcessSignal.sigterm.watch().listen((_) {
        unawaited(shutdown());
      }),
    );
  }

  try {
    await server.start();
    stdout.writeln('Runner API listening on http://$host:$port');
    await Future.any<void>(<Future<void>>[
      shutdownCompleter.future,
      server.waitForShutdown(),
    ]);
  } catch (error) {
    final text = error.toString();
    if (text.contains('Connection failed')) {
      stderr.writeln('Connection failed');
    } else {
      stderr.writeln(text);
    }
    exitCode = 1;
  } finally {
    for (final subscription in signalSubscriptions) {
      await subscription.cancel();
    }
    await logSubscription.cancel();
  }
}
