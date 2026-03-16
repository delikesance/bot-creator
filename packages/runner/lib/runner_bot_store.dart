import 'dart:convert';
import 'dart:io';

import 'package:bot_creator_shared/bot/bot_config.dart';

/// A single persisted bot entry (config + metadata).
class RunnerBotEntry {
  RunnerBotEntry({
    required this.id,
    required this.name,
    required this.syncedAt,
    required this.config,
  });

  final String id;
  final String name;
  final DateTime syncedAt;
  final BotConfig config;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'syncedAt': syncedAt.toUtc().toIso8601String(),
    'config': config.toJson(),
  };

  factory RunnerBotEntry.fromJson(Map<String, dynamic> json) {
    return RunnerBotEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      syncedAt: DateTime.parse(json['syncedAt'] as String),
      config: BotConfig.fromJson(
        Map<String, dynamic>.from(json['config'] as Map),
      ),
    );
  }
}

/// Persistent store for bot configs synced from the app.
///
/// Each bot is stored as a JSON file at `<dataDir>/<botId>.json`.
/// Default data directory is resolved from the `BOT_CREATOR_DATA_DIR`
/// environment variable, falling back to `./data/bots`.
class RunnerBotStore {
  RunnerBotStore({String? dataDir})
    : _dataDir =
          dataDir ??
          (Platform.environment['BOT_CREATOR_DATA_DIR'] != null &&
                  Platform.environment['BOT_CREATOR_DATA_DIR']!.isNotEmpty
              ? Platform.environment['BOT_CREATOR_DATA_DIR']!
              : './data/bots');

  final String _dataDir;

  File _fileForBot(String botId) {
    final safe = botId.replaceAll(RegExp(r'[^\w\-]'), '_');
    return File('$_dataDir/$safe.json');
  }

  Future<void> save(String botId, String botName, BotConfig config) async {
    final entry = RunnerBotEntry(
      id: botId,
      name: botName,
      syncedAt: DateTime.now().toUtc(),
      config: config,
    );
    final file = _fileForBot(botId);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(entry.toJson()));
  }

  Future<BotConfig?> load(String botId) async {
    final file = _fileForBot(botId);
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw);
      final entry = RunnerBotEntry.fromJson(
        Map<String, dynamic>.from(json as Map),
      );
      return entry.config;
    } catch (_) {
      return null;
    }
  }

  Future<RunnerBotEntry?> loadEntry(String botId) async {
    final file = _fileForBot(botId);
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw);
      return RunnerBotEntry.fromJson(Map<String, dynamic>.from(json as Map));
    } catch (_) {
      return null;
    }
  }

  Future<List<RunnerBotEntry>> listAll() async {
    final dir = Directory(_dataDir);
    if (!await dir.exists()) return <RunnerBotEntry>[];
    final entries = <RunnerBotEntry>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final raw = await entity.readAsString();
          final json = jsonDecode(raw);
          entries.add(
            RunnerBotEntry.fromJson(Map<String, dynamic>.from(json as Map)),
          );
        } catch (_) {}
      }
    }
    return entries;
  }

  Future<void> delete(String botId) async {
    final file = _fileForBot(botId);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
