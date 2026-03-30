import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:bot_creator_runner/subprocess_runner.dart';
import 'package:logging/logging.dart';

const _usageHeader =
    'Bot Creator Runner Subprocess\n'
    '\n'
    'Executes a single bot runtime in a dedicated process.\n'
    '\n'
    'Usage:\n'
    '  dart run packages/runner/bin/bot_subprocess.dart --bot-id <id> [--bot-name <name>] [--ipc-host 127.0.0.1] [--ipc-port 0]\n';

Future<void> main(List<String> args) async {
  final parser =
      ArgParser()
        ..addOption(
          'bot-id',
          help: 'Bot ID to load from RunnerBotStore.',
          valueHelp: '123456789',
        )
        ..addOption(
          'bot-name',
          help: 'Optional display name used for diagnostic output.',
          valueHelp: 'MyBot',
          defaultsTo: '',
        )
        ..addOption(
          'ipc-host',
          help: 'Host/interface for subprocess IPC server.',
          valueHelp: '127.0.0.1',
          defaultsTo: '127.0.0.1',
        )
        ..addOption(
          'ipc-port',
          help: 'Port for subprocess IPC server (0 = ephemeral).',
          valueHelp: '0',
          defaultsTo: '0',
        )
        ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help.');

  late final ArgResults results;
  try {
    results = parser.parse(args);
  } catch (error) {
    stderr.writeln('Invalid arguments: $error');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (results.flag('help')) {
    _printUsage(parser);
    return;
  }

  final botId = (results.option('bot-id') ?? '').trim();
  final botName = (results.option('bot-name') ?? '').trim();
  final ipcHost = (results.option('ipc-host') ?? '').trim();
  final ipcPortRaw = (results.option('ipc-port') ?? '').trim();
  final ipcPort = int.tryParse(ipcPortRaw);

  if (botId.isEmpty || ipcHost.isEmpty || ipcPort == null || ipcPort < 0) {
    stderr.writeln('Invalid subprocess arguments.');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  Logger.root.level = Level.INFO;
  final logSubscription = Logger.root.onRecord.listen((record) {
    final errorPart = record.error == null ? '' : ' | ${record.error}';
    stdout.writeln(
      '[${record.level.name}] ${record.loggerName}: ${record.message}$errorPart',
    );
    if (record.stackTrace != null) {
      stdout.writeln(record.stackTrace);
    }
  });

  final runner = BotSubprocessRunner(
    botId: botId,
    botName: botName,
    ipcHost: ipcHost,
    ipcPort: ipcPort,
  );

  final signalSubscriptions = <StreamSubscription<ProcessSignal>>[
    ProcessSignal.sigint.watch().listen((_) {
      unawaited(runner.stop());
    }),
  ];
  if (!Platform.isWindows) {
    signalSubscriptions.add(
      ProcessSignal.sigterm.watch().listen((_) {
        unawaited(runner.stop());
      }),
    );
  }

  try {
    await runner.run();
  } catch (error, stackTrace) {
    stderr.writeln('Subprocess failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    for (final sub in signalSubscriptions) {
      await sub.cancel();
    }
    await logSubscription.cancel();
  }
}

void _printUsage(ArgParser parser) {
  stdout
    ..writeln(_usageHeader)
    ..writeln(parser.usage);
}
