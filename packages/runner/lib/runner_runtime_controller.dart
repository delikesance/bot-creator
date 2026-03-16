import 'dart:io';

import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_runner/discord_runner.dart';
import 'package:bot_creator_runner/runner_bot_store.dart';

class RunnerRuntimeController {
  RunnerRuntimeController({RunnerBotStore? botStore})
    : _botStore = botStore ?? RunnerBotStore();

  final RunnerBotStore _botStore;

  DiscordRunner? _runner;
  String? _activeBotId;
  String? _activeBotName;
  int? _baselineRssBytes;

  bool get isRunning => _runner != null;
  String? get activeBotId => _activeBotId;
  String? get activeBotName => _activeBotName;
  int? get baselineRssBytes => _baselineRssBytes;

  RunnerBotStore get botStore => _botStore;

  /// Starts the bot identified by [botId] using the config persisted in the
  /// store. Throws [StateError] if already running or if the bot has not been
  /// synced yet.
  Future<void> startBot({required String botId, String? botName}) async {
    if (_runner != null) {
      throw StateError('Runner is already running.');
    }

    _baselineRssBytes = _readCurrentProcessRssBytes();

    final config = await _botStore.load(botId);
    if (config == null) {
      throw StateError(
        'Bot "$botId" not found in store. Sync from the app first.',
      );
    }

    final runner = DiscordRunner(config);
    await runner.start();

    _runner = runner;
    _activeBotId = botId;
    _activeBotName = (botName ?? '').trim().isEmpty ? botId : botName;
  }

  /// Starts a bot directly from a [BotConfig] (used when syncing and starting
  /// in a single call).
  Future<void> startBotWithConfig(
    BotConfig config, {
    required String botId,
    String? botName,
  }) async {
    if (_runner != null) {
      throw StateError('Runner is already running.');
    }

    _baselineRssBytes = _readCurrentProcessRssBytes();

    final runner = DiscordRunner(config);
    await runner.start();

    _runner = runner;
    _activeBotId = botId;
    _activeBotName = (botName ?? '').trim().isEmpty ? botId : botName;
  }

  Future<void> stopBot() async {
    final runner = _runner;
    _runner = null;
    _activeBotId = null;
    _activeBotName = null;
    _baselineRssBytes = null;

    if (runner != null) {
      await runner.stop();
    }
  }

  Future<void> dispose() async {
    await stopBot();
  }

  int? _readCurrentProcessRssBytes() {
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return null;
    }
  }
}
