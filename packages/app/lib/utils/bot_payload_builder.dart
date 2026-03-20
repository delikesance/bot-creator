import 'dart:convert';
import 'dart:io';

import 'package:bot_creator/utils/database.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:path_provider/path_provider.dart';

final _appManager = AppManager();

/// Assembles a [BotConfig] JSON payload for a given bot by reading all data
/// from [AppManager] (app details, global variables, workflows, statuses) and
/// loading every command from its individual file under `apps/{botId}/`.
///
/// This payload can be pushed to the runner via [RunnerClient.syncBot].
Future<Map<String, dynamic>> buildBotPayload(String botId) async {
  final appData = await _appManager.getApp(botId);
  if (appData.isEmpty) {
    throw StateError('Bot "$botId" not found in local storage.');
  }

  final token = (appData['token'] ?? '').toString().trim();
  if (token.isEmpty) {
    throw StateError('Bot "$botId" has no token configured.');
  }

  final intents = Map<String, bool>.from(
    (appData['intents'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v == true),
        ) ??
        const {},
  );

  final globalVariables = Map<String, String>.from(
    (appData['globalVariables'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        ) ??
        const {},
  );

  final workflows = List<Map<String, dynamic>>.from(
    (appData['workflows'] as List?)?.whereType<Map>().map(
          (w) => Map<String, dynamic>.from(w),
        ) ??
        const [],
  );

  final statuses =
      ((appData['activities'] ?? appData['statuses']) as List?)
          ?.whereType<Map>()
          .map((s) => BotStatusConfig.fromJson(Map<String, dynamic>.from(s)))
          .toList(growable: false) ??
      const <BotStatusConfig>[];

  final commands = await _loadAllCommands(botId);

  final config = BotConfig(
    token: token,
    username:
        (appData['username'] ?? '').toString().trim().isEmpty
            ? null
            : appData['username'].toString().trim(),
    avatarPath:
        (appData['avatar'] ?? '').toString().trim().isEmpty
            ? null
            : appData['avatar'].toString().trim(),
    intents: intents,
    globalVariables: globalVariables,
    workflows: workflows,
    statuses: statuses,
    commands: commands,
  );

  config.validate();
  return config.toJson();
}

/// Reads all command JSON files from the `apps/{botId}/` sub-directory.
Future<List<Map<String, dynamic>>> _loadAllCommands(String botId) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final commandDir = Directory('${docsDir.path}/apps/$botId');

  if (!await commandDir.exists()) return const [];

  final commands = <Map<String, dynamic>>[];

  await for (final entity in commandDir.list()) {
    if (entity is File && entity.path.endsWith('.json')) {
      try {
        final raw = await entity.readAsString();
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            commands.add(Map<String, dynamic>.from(decoded));
          }
        }
      } catch (_) {
        // Skip corrupt command files — the runner will just not register them.
      }
    }
  }

  return commands;
}
