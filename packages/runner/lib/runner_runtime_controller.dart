import 'dart:io';

import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_runner/discord_runner.dart';
import 'package:bot_creator_runner/runner_bot_store.dart';
import 'package:bot_creator_runner/stores/command_stats_store.dart';

class RunnerBotRuntimeState {
  const RunnerBotRuntimeState({
    required this.botId,
    required this.botName,
    required this.state,
    required this.lastSeenAt,
    this.lastError,
    this.baselineRssBytes,
  });

  final String botId;
  final String botName;
  final String state;
  final DateTime? lastSeenAt;
  final String? lastError;
  final int? baselineRssBytes;
}

class RunnerRuntimeController {
  RunnerRuntimeController({RunnerBotStore? botStore})
    : _botStore = botStore ?? RunnerBotStore();

  final RunnerBotStore _botStore;
  final CommandStatsStore _commandStatsStore = CommandStatsStore(
    _resolveDataDir(),
  );
  bool _statsInitialized = false;

  static String _resolveDataDir() {
    final configured =
        (Platform.environment['BOT_CREATOR_DATA_DIR'] ?? '').trim();
    return configured.isNotEmpty ? configured : './data';
  }

  final Map<String, DiscordRunner> _runners = <String, DiscordRunner>{};
  final Map<String, String> _botNames = <String, String>{};
  final Map<String, int?> _baselineRssByBot = <String, int?>{};
  final Map<String, DateTime> _lastSeenAtByBot = <String, DateTime>{};
  final Map<String, String?> _lastErrorByBot = <String, String?>{};
  final Set<String> _busyBots = <String>{};

  bool get isRunning => _runners.isNotEmpty;
  int get runningCount => _runners.length;
  List<String> get runningBotIds => _runners.keys.toList(growable: false);

  RunnerBotStore get botStore => _botStore;

  CommandStatsStore get commandStatsStore => _commandStatsStore;

  bool isBotRunning(String botId) => _runners.containsKey(botId);

  int? baselineRssForBot(String botId) => _baselineRssByBot[botId];

  RunnerBotRuntimeState runtimeStateForBot(String botId) {
    final running = _runners.containsKey(botId);
    return RunnerBotRuntimeState(
      botId: botId,
      botName: _botNames[botId] ?? botId,
      state: running ? 'running' : 'stopped',
      lastSeenAt: _lastSeenAtByBot[botId],
      lastError: _lastErrorByBot[botId],
      baselineRssBytes: _baselineRssByBot[botId],
    );
  }

  List<RunnerBotRuntimeState> listRuntimeStates() {
    final ids =
        <String>{
            ..._runners.keys,
            ..._botNames.keys,
            ..._lastSeenAtByBot.keys,
            ..._lastErrorByBot.keys,
          }.toList()
          ..sort();
    return ids.map(runtimeStateForBot).toList(growable: false);
  }

  /// Starts the bot identified by [botId] using the config persisted in the
  /// store.
  Future<void> startBot({required String botId, String? botName}) async {
    if (_busyBots.contains(botId)) {
      throw StateError('Bot "$botId" transition already in progress.');
    }
    if (_runners.containsKey(botId)) {
      throw StateError('Bot "$botId" is already running.');
    }

    _busyBots.add(botId);
    _lastSeenAtByBot[botId] = DateTime.now().toUtc();

    final baseline = _readCurrentProcessRssBytes();

    final config = await _botStore.load(botId);
    if (config == null) {
      _busyBots.remove(botId);
      throw StateError(
        'Bot "$botId" not found in store. Sync from the app first.',
      );
    }

    await startBotWithConfig(
      config,
      botId: botId,
      botName: botName,
      baselineRssBytes: baseline,
    );
  }

  /// Starts a bot directly from a [BotConfig] (used when syncing and starting
  /// in a single call).
  Future<void> startBotWithConfig(
    BotConfig config, {
    required String botId,
    String? botName,
    int? baselineRssBytes,
  }) async {
    if (_busyBots.contains(botId) && !_runners.containsKey(botId)) {
      // already locked by startBot
    } else if (_busyBots.contains(botId)) {
      throw StateError('Bot "$botId" transition already in progress.');
    } else {
      _busyBots.add(botId);
    }

    if (_runners.containsKey(botId)) {
      _busyBots.remove(botId);
      throw StateError('Bot "$botId" is already running.');
    }

    final runner = DiscordRunner(config, statsStore: _commandStatsStore);
    try {
      if (!_statsInitialized) {
        await _commandStatsStore.init();
        _statsInitialized = true;
      }
      await runner.start();
      _runners[botId] = runner;
      _botNames[botId] = (botName ?? '').trim().isEmpty ? botId : botName!;
      _baselineRssByBot[botId] =
          baselineRssBytes ?? _readCurrentProcessRssBytes();
      _lastSeenAtByBot[botId] = DateTime.now().toUtc();
      _lastErrorByBot.remove(botId);
    } catch (error) {
      _lastSeenAtByBot[botId] = DateTime.now().toUtc();
      _lastErrorByBot[botId] = error.toString();
      rethrow;
    } finally {
      _busyBots.remove(botId);
    }
  }

  Future<void> stopBot(String botId) async {
    if (_busyBots.contains(botId)) {
      throw StateError('Bot "$botId" transition already in progress.');
    }

    final runner = _runners[botId];
    if (runner == null) {
      return;
    }

    _busyBots.add(botId);
    try {
      await runner.stop();
      _runners.remove(botId);
      _lastSeenAtByBot[botId] = DateTime.now().toUtc();
    } finally {
      _busyBots.remove(botId);
    }
  }

  Future<void> stopAllBots() async {
    final ids = _runners.keys.toList(growable: false);
    for (final botId in ids) {
      await stopBot(botId);
    }
  }

  Future<void> dispose() async {
    await stopAllBots();
  }

  /// Hot-reloads the config for a running bot without disconnecting
  /// from Discord.  Also persists the updated config to the store so
  /// a subsequent [startBot] call uses the latest version.
  Future<void> reloadBot(String botId, BotConfig newConfig) async {
    final name = _botNames[botId] ?? botId;
    await _botStore.save(botId, name, newConfig);
    final runner = _runners[botId];
    if (runner != null) {
      final requiresReconnect = await runner.reloadConfig(newConfig);
      if (requiresReconnect && newConfig.autoRestart) {
        await _restartRunningBotWithConfig(
          botId,
          name: name,
          config: newConfig,
        );
      }
      _lastSeenAtByBot[botId] = DateTime.now().toUtc();
    }
  }

  Future<void> triggerInboundWebhook(
    String botId, {
    required String workflowName,
    required Map<String, dynamic> payload,
    required Map<String, String> headers,
    String? requestId,
    String? sourceIp,
  }) async {
    final runner = _runners[botId];
    if (runner == null) {
      throw StateError('Bot "$botId" is not running.');
    }
    if (!runner.config.inboundWebhooks) {
      throw StateError('Inbound webhooks are disabled for bot "$botId".');
    }

    await runner.executeInboundWebhook(
      workflowName: workflowName,
      payload: payload,
      headers: headers,
      requestId: requestId,
      sourceIp: sourceIp,
    );
    _lastSeenAtByBot[botId] = DateTime.now().toUtc();
  }

  Future<void> _restartRunningBotWithConfig(
    String botId, {
    required String name,
    required BotConfig config,
  }) async {
    final existing = _runners[botId];
    if (existing == null) {
      return;
    }

    await existing.stop();
    _runners.remove(botId);

    final replacement = DiscordRunner(config, statsStore: _commandStatsStore);
    try {
      await replacement.start();
      _runners[botId] = replacement;
      _botNames[botId] = name;
      _lastErrorByBot.remove(botId);
    } catch (error) {
      _lastErrorByBot[botId] = error.toString();
      rethrow;
    }
  }

  int? _readCurrentProcessRssBytes() {
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return null;
    }
  }
}
