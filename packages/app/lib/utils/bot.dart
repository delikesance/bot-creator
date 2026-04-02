library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:bot_creator/main.dart';
import 'package:bot_creator_shared/actions/handler.dart';
import 'package:bot_creator_shared/utils/command_workflow_routing.dart';
import 'package:bot_creator_shared/actions/handle_component_interaction.dart';
import 'package:bot_creator_shared/actions/interaction_response.dart';
import 'package:bot_creator_shared/events/event_contexts.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/command_autocomplete.dart';
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:bot_creator/utils/database.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:bot_creator_shared/utils/global.dart' as shared_global;
import 'package:bot_creator/utils/mobile_sessions_orchestrator.dart';
import 'package:bot_creator/utils/template_resolver.dart';
import 'package:bot_creator/utils/workflow_call.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';

part 'bot.logs.dart';
part 'bot.template.dart';
part 'bot.mobile_service.dart';
part 'bot.commands.dart';
part 'bot.event_workflows.dart';

String _formatBdfdRuntimeDiagnostics(List<BdfdCompileDiagnostic> diagnostics) {
  if (diagnostics.isEmpty) {
    return 'This BDFD script could not be compiled.';
  }

  final summary = diagnostics
      .take(5)
      .map((diagnostic) {
        final location =
            (diagnostic.line != null && diagnostic.column != null)
                ? 'L${diagnostic.line}:C${diagnostic.column} '
                : '';
        return '- $location${diagnostic.message}';
      })
      .join('\n');
  return 'This BDFD script could not be compiled:\n$summary';
}

/// Injects gateway-only bot variables (ping, uptime, shardId) into
/// a runtime variables map.  Works for both desktop and mobile sessions.
void _injectLocalGatewayBotVariables(
  NyxxGateway gateway,
  Map<String, String> variables, {
  DateTime? startedAt,
}) {
  try {
    variables['bot.ping'] = gateway.gateway.latency.inMilliseconds.toString();
  } catch (_) {}
  try {
    variables['bot.shardId'] = gateway.gateway.shardIds.join(',');
  } catch (_) {}
  if (startedAt != null) {
    variables['bot.uptime'] =
        DateTime.now().difference(startedAt).inSeconds.toString();
  }
}

/// Returns the [DateTime] at which the given bot session was started,
/// checking desktop first, then the mobile sessions map.
DateTime? _botStartedAt(String botId) {
  final desktopStartedAt = _desktopStartedAtByBotId[botId];
  if (desktopStartedAt != null) {
    return desktopStartedAt;
  }
  // Mobile sessions are tracked in DiscordBotTaskHandler._mobileStartedAt
  // but that instance is not directly accessible from here.  We only have
  // local desktop started-at tracking in this file for the desktop path.
  return null;
}

final Map<String, NyxxGateway> _desktopGatewaysByBotId =
    <String, NyxxGateway>{};
final Map<String, DateTime> _desktopStartedAtByBotId = <String, DateTime>{};
StreamSubscription<LogRecord>? _desktopNyxxLogsSubscription;
final Map<String, Timer> _desktopMetricsTimersByBotId = <String, Timer>{};
final Map<String, Timer> _desktopStatusRotationTimersByBotId =
    <String, Timer>{};
String? get desktopRunningBotId {
  if (_desktopGatewaysByBotId.isEmpty) {
    return null;
  }
  return _desktopGatewaysByBotId.keys.first;
}

Set<String> get desktopRunningBotIds =>
    Set<String>.unmodifiable(_desktopGatewaysByBotId.keys);
bool isDesktopBotRunningId(String botId) =>
    _desktopGatewaysByBotId.containsKey(botId.trim());
String? _mobileRunningBotId;
final Set<String> _mobileRunningBotIds = <String>{};
String? get mobileRunningBotId {
  if (_mobileRunningBotId != null && _mobileRunningBotId!.isNotEmpty) {
    return _mobileRunningBotId;
  }
  if (_mobileRunningBotIds.isEmpty) {
    return null;
  }
  return _mobileRunningBotIds.first;
}

Set<String> get mobileRunningBotIds =>
    Set<String>.unmodifiable(_mobileRunningBotIds);

bool isMobileBotRunning(String botId) => _mobileRunningBotIds.contains(botId);

void setMobileRunningBotId(String? id) {
  _mobileRunningBotId = id;
  _mobileRunningBotIds.clear();
  if (id != null && id.trim().isNotEmpty) {
    _mobileRunningBotIds.add(id.trim());
  }
}

void addMobileRunningBotId(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) {
    return;
  }
  _mobileRunningBotIds.add(trimmed);
  _mobileRunningBotId ??= trimmed;
}

void removeMobileRunningBotId(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) {
    return;
  }
  _mobileRunningBotIds.remove(trimmed);
  if (_mobileRunningBotId == trimmed) {
    _mobileRunningBotId =
        _mobileRunningBotIds.isEmpty ? null : _mobileRunningBotIds.first;
  }
}

const int _maxBotLogLines = 500;
const String _globalBotBucketKey = '__global__';
final StreamController<List<String>> _botLogsController =
    StreamController<List<String>>.broadcast();
final StreamController<Map<String, List<String>>> _botLogsByBotController =
    StreamController<Map<String, List<String>>>.broadcast();
final StreamController<int?> _botProcessRssController =
    StreamController<int?>.broadcast();
final StreamController<int?> _botEstimatedRssController =
    StreamController<int?>.broadcast();
final StreamController<double?> _botProcessCpuController =
    StreamController<double?>.broadcast();
final StreamController<int?> _botProcessStorageController =
    StreamController<int?>.broadcast();
final StreamController<Map<String, BotRuntimeMetrics>>
_botMetricsByBotController =
    StreamController<Map<String, BotRuntimeMetrics>>.broadcast();
List<String> _botLogs = <String>[];
final Map<String, List<String>> _botLogsByBot = <String, List<String>>{};
String? _activeBotLogBotId;
bool _debugBotLogsEnabled = false;
const String _debugLogsEnabledDataKey = 'debugLogsEnabled';
int? _botProcessRssBytes;
int? _botBaselineRssBytes;
DateTime? _botBaselineCapturedAt;
int? _botEstimatedRssBytes;
double? _botProcessCpuPercent;
int? _botProcessStorageBytes;
final Map<String, BotRuntimeMetrics> _botMetricsByBot =
    <String, BotRuntimeMetrics>{};
bool _botRuntimeActive = false;
final Random _desktopStatusRandom = Random();

bool get isDesktopBotRunning => _desktopGatewaysByBotId.isNotEmpty;
bool get isBotDebugLogsEnabled => _debugBotLogsEnabled;
bool get isBotRuntimeActive => _botRuntimeActive;

void applyDesktopRuntimeSettings({
  required String botId,
  required Map<String, dynamic> appData,
}) {
  final gateway = _desktopGatewaysByBotId[botId];
  if (gateway == null) {
    return;
  }

  _startDesktopStatusRotation(botId, gateway, appData);
}

void setBotDebugLogsEnabled(bool enabled) {
  _debugBotLogsEnabled = enabled;
  appendBotLog(enabled ? 'Debug logs enabled' : 'Debug logs disabled');
  unawaited(_persistDebugLogsEnabled(enabled));
}

String _two(int value) => value < 10 ? '0$value' : '$value';

String _timestampNow() {
  final now = DateTime.now();
  return '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
}

List<String> _enabledIntentNames(Map<String, bool> intentsMap) {
  return intentsMap.entries
    .where((entry) => entry.value)
    .map((entry) => entry.key)
    .toList(growable: false)..sort();
}

/// Convert the intents configuration map to GatewayIntents
Flags<GatewayIntents> buildGatewayIntents(Map<String, bool>? intentsMap) {
  if (intentsMap == null || intentsMap.isEmpty) {
    return GatewayIntents.allUnprivileged;
  }

  Flags<GatewayIntents> intents = GatewayIntents.none;

  if (intentsMap['Guild Presence'] == true) {
    intents = intents | GatewayIntents.guildPresences;
  }
  if (intentsMap['Guild Members'] == true) {
    intents = intents | GatewayIntents.guildMembers;
  }
  if (intentsMap['Message Content'] == true) {
    intents = intents | GatewayIntents.messageContent;
  }
  if (intentsMap['Direct Messages'] == true) {
    intents = intents | GatewayIntents.directMessages;
  }
  if (intentsMap['Guilds'] == true) {
    intents = intents | GatewayIntents.guilds;
  }
  if (intentsMap['Guild Messages'] == true) {
    intents = intents | GatewayIntents.guildMessages;
  }
  if (intentsMap['Guild Message Reactions'] == true) {
    intents = intents | GatewayIntents.guildMessageReactions;
  }
  if (intentsMap['Direct Message Reactions'] == true) {
    intents = intents | GatewayIntents.directMessageReactions;
  }
  if (intentsMap['Guild Message Typing'] == true) {
    intents = intents | GatewayIntents.guildMessageTyping;
  }
  if (intentsMap['Direct Message Typing'] == true) {
    intents = intents | GatewayIntents.directMessageTyping;
  }
  if (intentsMap['Guild Scheduled Events'] == true) {
    intents = intents | GatewayIntents.guildScheduledEvents;
  }
  if (intentsMap['Auto Moderation Configuration'] == true) {
    intents = intents | GatewayIntents.autoModerationConfiguration;
  }
  if (intentsMap['Auto Moderation Execution'] == true) {
    intents = intents | GatewayIntents.autoModerationExecution;
  }

  if (intents == GatewayIntents.none) {
    return GatewayIntents.allUnprivileged;
  }

  return intents;
}

Future<void> startDesktopBot(String token) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    throw Exception('Desktop bot mode is only available on desktop platforms.');
  }

  final botUser = await getDiscordUser(token);
  final botId = botUser.id.toString();
  if (_desktopGatewaysByBotId.containsKey(botId)) {
    appendBotLog('Desktop bot "$botId" is already running', botId: botId);
    return;
  }

  appendBotLog('Starting desktop bot...', botId: botId);
  appendBotDebugLog('Desktop platform detected');

  final appData = await appManager.getApp(botId);
  final intentsMap = Map<String, bool>.from(appData['intents'] as Map? ?? {});
  final intents = buildGatewayIntents(intentsMap);
  final enabledIntentNames = _enabledIntentNames(intentsMap);
  _bindDesktopNyxxLogs();
  appendBotLog(
    'Active runtime intents (${enabledIntentNames.length}): '
    '${enabledIntentNames.isEmpty ? 'none' : enabledIntentNames.join(', ')}',
    botId: botId,
  );

  final gateway = await Nyxx.connectGateway(
    token,
    intents,
    options: GatewayClientOptions(
      loggerName: 'CardiaKexaDesktop',
      plugins: [Logging(logLevel: Level.ALL)],
    ),
  );
  _desktopStartedAtByBotId[botId] = DateTime.now();
  _desktopGatewaysByBotId[botId] = gateway;
  setBotRuntimeActive(true);

  gateway.onReady.listen((event) async {
    setBotRuntimeActive(true);
    appendBotLog('Desktop bot connected and ready', botId: botId);
    unawaited(appManager.updateGuildCount(botId, event.guilds.length));
    unawaited(_refreshBotMetrics(botId: botId));
    _desktopMetricsTimersByBotId[botId]?.cancel();
    _desktopMetricsTimersByBotId[botId] = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        unawaited(_refreshBotMetrics(botId: botId));
      },
    );
    final latestAppData = await appManager.getApp(botId);
    _startDesktopStatusRotation(botId, gateway, latestAppData);
    appManager = AppManager();
    gateway.onInteractionCreate.listen((event) async {
      await handleLocalCommands(event, appManager);
    });
    await _registerLocalEventWorkflowListeners(
      gateway,
      manager: appManager,
      botId: botId,
      appData: latestAppData,
      onLog: (message) {
        appendBotLog(message, botId: botId);
      },
    );
  });
}

Future<void> stopDesktopBot({String? botId}) async {
  final normalizedBotId = (botId ?? '').trim();
  if (normalizedBotId.isEmpty) {
    final runningIds = _desktopGatewaysByBotId.keys.toList(growable: false);
    for (final id in runningIds) {
      await stopDesktopBot(botId: id);
    }
    return;
  }

  appendBotLog('Desktop bot shutdown requested', botId: normalizedBotId);
  _desktopMetricsTimersByBotId.remove(normalizedBotId)?.cancel();
  _desktopStatusRotationTimersByBotId.remove(normalizedBotId)?.cancel();

  final gateway = _desktopGatewaysByBotId.remove(normalizedBotId);
  _desktopStartedAtByBotId.remove(normalizedBotId);
  if (gateway != null) {
    await gateway.close();
  }

  if (_desktopGatewaysByBotId.isEmpty) {
    await _desktopNyxxLogsSubscription?.cancel();
    _desktopNyxxLogsSubscription = null;
    _updateBotMetrics(
      rssBytes: null,
      cpuPercent: null,
      storageBytes: null,
      overwriteNulls: true,
    );
  }

  setBotRuntimeActive(
    _desktopGatewaysByBotId.isNotEmpty || mobileRunningBotIds.isNotEmpty,
  );
}

void _startDesktopStatusRotation(
  String botId,
  NyxxGateway gateway,
  Map<String, dynamic> appData,
) {
  _desktopStatusRotationTimersByBotId[botId]?.cancel();
  _desktopStatusRotationTimersByBotId.remove(botId);

  final statuses = _normalizeStatuses(
    appData['activities'] ?? appData['statuses'],
  );
  if (statuses.isEmpty) {
    return;
  }

  final presenceStatus = (appData['presenceStatus'] as String?) ?? 'online';
  unawaited(
    _applyDesktopInitialStatusThenRotate(
      botId,
      gateway,
      statuses,
      presenceStatus,
    ),
  );
}

Future<void> _applyDesktopInitialStatusThenRotate(
  String botId,
  NyxxGateway gateway,
  List<Map<String, dynamic>> statuses,
  String presenceStatus,
) async {
  if (statuses.isEmpty) {
    return;
  }

  final firstStatus = statuses.first;
  await _applyDesktopStatus(botId, gateway, firstStatus, presenceStatus);

  // Re-send once after READY to avoid occasional dropped first presence frame.
  Timer(const Duration(seconds: 3), () {
    unawaited(_applyDesktopStatus(botId, gateway, firstStatus, presenceStatus));
  });

  if (statuses.length == 1) {
    return;
  }

  final min = (firstStatus['minIntervalSeconds'] as int?) ?? 60;
  final max = (firstStatus['maxIntervalSeconds'] as int?) ?? min;
  final delaySeconds =
      max <= min ? min : min + _desktopStatusRandom.nextInt(max - min + 1);

  _desktopStatusRotationTimersByBotId[botId]?.cancel();
  _desktopStatusRotationTimersByBotId[botId] = Timer(
    Duration(seconds: delaySeconds),
    () {
      unawaited(
        _applyDesktopRandomStatus(botId, gateway, statuses, presenceStatus),
      );
    },
  );
}

CurrentUserStatus _mapPresenceStatus(String statusString) {
  switch (statusString) {
    case 'idle':
      return CurrentUserStatus.idle;
    case 'dnd':
      return CurrentUserStatus.dnd;
    default:
      return CurrentUserStatus.online;
  }
}

Future<void> _applyDesktopStatus(
  String botId,
  NyxxGateway gateway,
  Map<String, dynamic> status,
  String presenceStatus,
) async {
  final type = (status['type'] ?? 'playing').toString();
  final streamUrl = _parseStreamingUrl((status['url'] ?? '').toString());
  final text = _sanitizeDesktopActivityText(
    ((status['name'] ?? status['text']) ?? '').toString(),
  );

  if (text.isEmpty) {
    return;
  }

  try {
    gateway.updatePresence(
      PresenceBuilder(
        status: _mapPresenceStatus(presenceStatus),
        isAfk: false,
        activities: <ActivityBuilder>[
          ActivityBuilder(
            name: text,
            type: _mapDesktopActivityType(type, streamUrl: streamUrl),
            url: streamUrl,
          ),
        ],
      ),
    );
    appendBotLog('Desktop presence applied: $type $text', botId: botId);
  } catch (error) {
    appendBotDebugLog('Status rotation update failed: $error');
  }
}

Future<void> _applyDesktopRandomStatus(
  String botId,
  NyxxGateway gateway,
  List<Map<String, dynamic>> statuses,
  String presenceStatus,
) async {
  if (statuses.isEmpty) {
    return;
  }

  final picked = statuses[_desktopStatusRandom.nextInt(statuses.length)];
  final min = (picked['minIntervalSeconds'] as int?) ?? 60;
  final max = (picked['maxIntervalSeconds'] as int?) ?? min;

  await _applyDesktopStatus(botId, gateway, picked, presenceStatus);

  final delaySeconds =
      max <= min ? min : min + _desktopStatusRandom.nextInt(max - min + 1);
  _desktopStatusRotationTimersByBotId[botId]?.cancel();
  _desktopStatusRotationTimersByBotId[botId] = Timer(
    Duration(seconds: delaySeconds),
    () {
      unawaited(
        _applyDesktopRandomStatus(botId, gateway, statuses, presenceStatus),
      );
    },
  );
}

List<Map<String, dynamic>> _normalizeStatuses(dynamic raw) {
  if (raw is! List) {
    return const <Map<String, dynamic>>[];
  }

  final normalized = <Map<String, dynamic>>[];
  for (final entry in raw.whereType<Map>()) {
    final map = Map<String, dynamic>.from(entry);
    final text = ((map['name'] ?? map['text']) ?? '').toString().trim();
    if (text.isEmpty) {
      continue;
    }
    final min =
        int.tryParse((map['minIntervalSeconds'] ?? '').toString()) ?? 60;
    final maxRaw =
        int.tryParse((map['maxIntervalSeconds'] ?? '').toString()) ?? min;
    final max = maxRaw < min ? min : maxRaw;
    normalized.add({
      'type': (map['type'] ?? 'playing').toString().trim().toLowerCase(),
      'name': text,
      'text': text,
      'state': (map['state'] ?? '').toString(),
      'url': (map['url'] ?? '').toString(),
      'minIntervalSeconds': min > 0 ? min : 60,
      'maxIntervalSeconds': max > 0 ? max : 60,
    });
  }

  return normalized;
}

ActivityType _mapDesktopActivityType(
  String rawType, {
  required Uri? streamUrl,
}) {
  switch (rawType.trim().toLowerCase()) {
    case 'streaming':
      return streamUrl != null ? ActivityType.streaming : ActivityType.game;
    case 'listening':
      return ActivityType.listening;
    case 'watching':
      return ActivityType.watching;
    case 'competing':
      return ActivityType.competing;
    case 'playing':
    default:
      return ActivityType.game;
  }
}

Uri? _parseStreamingUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) {
    return null;
  }
  if ((parsed.scheme != 'http' && parsed.scheme != 'https') ||
      parsed.host.isEmpty) {
    return null;
  }
  return parsed;
}

String _sanitizeDesktopActivityText(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.length > 120) {
    return trimmed.substring(0, 120);
  }
  return trimmed;
}

Future<void> createCommand(
  NyxxRest client,
  ApplicationCommandBuilder commandBuilder, {
  Map<String, dynamic> data = const {},
}) async {
  try {
    final command = await client.commands.create(commandBuilder);
    final Map<String, dynamic> commandData = {
      'name': command.name,
      'description': command.description,
      'type': _commandTypeToStorage(command.type),
      'id': command.id.toString(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    if (data.isNotEmpty) {
      commandData['data'] = data;
    }
    appManager.saveAppCommand(
      client.user.id.toString(),
      command.id.toString(),
      commandData,
    );
  } catch (e) {
    throw Exception('Failed to create command: $e');
  }
}

Future<void> updateCommand(
  NyxxRest client,
  Snowflake commandId, {
  required ApplicationCommandUpdateBuilder commandBuilder,
  Map<String, dynamic> data = const {},
}) async {
  try {
    final command = await client.commands.update(commandId, commandBuilder);
    final Map<String, dynamic> commandData = {
      'name': command.name,
      'description': command.description,
      'type': _commandTypeToStorage(command.type),
      'id': command.id.toString(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (data.isNotEmpty) {
      commandData['data'] = data;
    }
    appManager.saveAppCommand(
      client.user.id.toString(),
      command.id.toString(),
      commandData,
    );
  } catch (e) {
    throw Exception('Failed to update command: $e');
  }
}

String _commandTypeToStorage(ApplicationCommandType type) {
  if (type == ApplicationCommandType.user) {
    return 'user';
  }
  if (type == ApplicationCommandType.message) {
    return 'message';
  }
  return 'chatInput';
}
