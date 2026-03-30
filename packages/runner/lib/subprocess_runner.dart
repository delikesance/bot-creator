import 'dart:async';
import 'dart:io';

import 'package:bot_creator_runner/discord_runner.dart';
import 'package:bot_creator_runner/ipc/ipc_server.dart';
import 'package:bot_creator_runner/runner_bot_store.dart';
import 'package:logging/logging.dart';

final _subprocessLog = Logger('BotSubprocessRunner');

class BotSubprocessRunner {
  BotSubprocessRunner({
    required this.botId,
    required this.botName,
    required this.ipcHost,
    required this.ipcPort,
    RunnerBotStore? store,
  }) : _store = store ?? RunnerBotStore();

  final String botId;
  final String botName;
  final String ipcHost;
  final int ipcPort;
  final RunnerBotStore _store;

  final Completer<void> _lifecycleCompleter = Completer<void>();

  RunnerIpcServer? _ipcServer;
  DiscordRunner? _runner;

  bool _running = false;
  String? _lastError;
  DateTime? _startedAt;

  Future<void> run() async {
    final entry = await _store.loadEntry(botId);
    if (entry == null) {
      throw StateError('Bot "$botId" not found in RunnerBotStore.');
    }

    final server = RunnerIpcServer(
      host: ipcHost,
      port: ipcPort,
      onRequest: _handleIpcRequest,
    );
    await server.start();
    _ipcServer = server;

    stdout.writeln(
      'SUBPROCESS_READY botId=$botId name=${botName.isEmpty ? entry.name : botName} ipcPort=${server.boundPort}',
    );

    try {
      _runner = DiscordRunner(entry.config);
      await _runner!.start();
      _running = true;
      _startedAt = DateTime.now().toUtc();
      _lastError = null;
      _subprocessLog.info('Subprocess bot started: $botId');
      await _lifecycleCompleter.future;
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _running = false;
      await _runner?.stop();
      _runner = null;
      await _ipcServer?.stop();
      _ipcServer = null;
      _subprocessLog.info('Subprocess bot stopped: $botId');
    }
  }

  Future<Map<String, dynamic>> _handleIpcRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'ping':
        return <String, dynamic>{'ok': true, 'botId': botId};
      case 'status':
        return _statusPayload();
      case 'metrics':
        return <String, dynamic>{
          ..._statusPayload(),
          'rssBytes': _readCurrentProcessRssBytes(),
          'pid': pid,
        };
      case 'stop':
        unawaited(stop());
        return <String, dynamic>{'accepted': true};
      default:
        throw StateError('Unknown IPC method: $method');
    }
  }

  Map<String, dynamic> _statusPayload() {
    return <String, dynamic>{
      'botId': botId,
      'state': _running ? 'running' : 'stopped',
      'startedAt': _startedAt?.toIso8601String(),
      'lastError': _lastError,
      'pid': pid,
    };
  }

  Future<void> stop() async {
    if (_lifecycleCompleter.isCompleted) {
      return;
    }
    _lifecycleCompleter.complete();
  }

  int? _readCurrentProcessRssBytes() {
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return null;
    }
  }
}
