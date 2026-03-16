import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_runner/config_loader.dart';
import 'package:bot_creator_runner/discord_runner.dart';
import 'package:bot_creator_runner/web_log_store.dart';
import 'package:bot_creator_runner/web_bootstrap_server.dart';
import 'package:logging/logging.dart';

const _usageHeader =
    'Bot Creator Runner\n'
    '\n'
    'Runs a Discord bot from a local ZIP export or exposes a REST API for the\n'
    'Bot Creator app to push configs and control bots remotely.\n'
    '\n'
    'Usage:\n'
    '  dart run packages/runner/bin/runner.dart --config <path/to/export.zip>\n'
    '  dart run packages/runner/bin/runner.dart <path/to/export.zip>\n'
    '  dart run packages/runner/bin/runner.dart --web\n';

Future<void> main(List<String> args) async {
  final parser =
      ArgParser()
        ..addOption(
          'config',
          abbr: 'c',
          help: 'Path to the bot export ZIP file.',
          valueHelp: 'file.zip',
        )
        ..addFlag(
          'web',
          negatable: false,
          help:
              'Start the REST API server. The Bot Creator app connects to this '
              'server to push bot configs and control bots remotely.',
        )
        ..addOption(
          'web-host',
          help: 'Host/interface used by web mode.',
          valueHelp: '0.0.0.0',
          defaultsTo: Platform.environment['BOT_CREATOR_WEB_HOST'] ?? '0.0.0.0',
        )
        ..addOption(
          'web-port',
          help: 'Port used by web mode.',
          valueHelp: '8080',
          defaultsTo: Platform.environment['BOT_CREATOR_WEB_PORT'] ?? '8080',
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

  final webMode = results.flag('web');
  final webHost = (results.option('web-host') ?? '').trim();
  final webPortRaw = (results.option('web-port') ?? '').trim();

  var configPath = (results.option('config') ?? '').trim();
  if (!webMode && configPath.isEmpty && results.rest.isNotEmpty) {
    configPath = results.rest.first.trim();
  }

  if (webMode) {
    if (configPath.isNotEmpty) {
      stderr.writeln('Options conflict: --web cannot be used with --config.');
      _printUsage(parser);
      exitCode = 64;
      return;
    }

    final webPort = int.tryParse(webPortRaw);
    if (webHost.isEmpty || webPort == null || webPort <= 0 || webPort > 65535) {
      stderr.writeln('Invalid web options: --web-host or --web-port.');
      _printUsage(parser);
      exitCode = 64;
      return;
    }

    Logger.root.level = Level.INFO;

    await _runWebMode(host: webHost, port: webPort);
    return;
  }

  if (configPath.isEmpty) {
    stderr.writeln('Missing required option: --config <file.zip>');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (configPath.isNotEmpty) {
    final configFile = File(configPath);
    if (!configFile.existsSync()) {
      stderr.writeln('Config ZIP not found: $configPath');
      exitCode = 66;
      return;
    }
  }

  Logger.root
    ..level = Level.INFO
    ..onRecord.listen((record) {
      final errorPart = record.error == null ? '' : ' | ${record.error}';
      stdout.writeln(
        '[${record.level.name}] ${record.loggerName}: ${record.message}$errorPart',
      );
      if (record.stackTrace != null) {
        stdout.writeln(record.stackTrace);
      }
    });

  late final BotConfig config;
  try {
    config = loadConfigFromZip(configPath);
  } catch (e, st) {
    stderr.writeln('Failed to load config: $e');
    stderr.writeln(st);
    exitCode = 65;
    return;
  }

  final runner = DiscordRunner(config);

  final shutdownCompleter = Completer<void>();
  Future<void> shutdown() async {
    if (shutdownCompleter.isCompleted) return;
    shutdownCompleter.complete();
    await runner.stop();
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
    await runner.start();
    stdout.writeln('Runner started. Press Ctrl+C to stop.');
    await shutdownCompleter.future;
  } catch (e, st) {
    stderr.writeln('Failed to start runner: $e');
    stderr.writeln(st);
    exitCode = 1;
  } finally {
    for (final subscription in signalSubscriptions) {
      await subscription.cancel();
    }
  }
}

void _printUsage(ArgParser parser) {
  stdout
    ..writeln(_usageHeader)
    ..writeln(parser.usage);
}

Future<void> _runWebMode({required String host, required int port}) async {
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
