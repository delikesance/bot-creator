part of 'bot.dart';

const String _mobileSessionsDataKey = 'mobile_bot_sessions';
const String _mobileCommandTypeKey = 'type';
const String _mobileCommandAddSession = 'mobile_session_add';
const String _mobileCommandRemoveSession = 'mobile_session_remove';
const String _mobileCommandSyncSessions = 'mobile_sessions_sync';
final MobileSessionsOrchestrator _mobileSessionsOrchestrator =
    MobileSessionsOrchestrator();

Map<String, String> _normalizeMobileSessionsMap(dynamic raw) {
  if (raw is! Map) {
    return <String, String>{};
  }
  final normalized = <String, String>{};
  raw.forEach((key, value) {
    final botId = key.toString().trim();
    final token = value?.toString().trim() ?? '';
    if (botId.isEmpty || token.isEmpty) {
      return;
    }
    normalized[botId] = token;
  });
  return normalized;
}

Future<Map<String, String>> _readConfiguredMobileSessions() async {
  try {
    final raw = await FlutterForegroundTask.getData<dynamic>(
      key: _mobileSessionsDataKey,
    );
    final mapped = _normalizeMobileSessionsMap(raw);
    if (mapped.isNotEmpty) {
      return mapped;
    }
  } catch (_) {}

  // Legacy single-bot fallback.
  try {
    final token = await FlutterForegroundTask.getData<String>(key: 'token');
    final runningBotId = await FlutterForegroundTask.getData<String>(
      key: 'running_bot_id',
    );
    if (runningBotId != null &&
        runningBotId.trim().isNotEmpty &&
        token != null &&
        token.trim().isNotEmpty) {
      return <String, String>{runningBotId.trim(): token.trim()};
    }
  } catch (_) {}

  return <String, String>{};
}

Future<void> _writeConfiguredMobileSessions(
  Map<String, String> sessions,
) async {
  final sanitized = <String, String>{};
  for (final entry in sessions.entries) {
    final botId = entry.key.trim();
    final token = entry.value.trim();
    if (botId.isEmpty || token.isEmpty) {
      continue;
    }
    sanitized[botId] = token;
  }

  try {
    await FlutterForegroundTask.saveData(
      key: _mobileSessionsDataKey,
      value: sanitized,
    );
  } catch (_) {}

  if (sanitized.isEmpty) {
    try {
      await FlutterForegroundTask.removeData(key: 'token');
    } catch (_) {}
    try {
      await FlutterForegroundTask.removeData(key: 'running_bot_id');
    } catch (_) {}
    return;
  }

  final first = sanitized.entries.first;
  try {
    await FlutterForegroundTask.saveData(key: 'token', value: first.value);
  } catch (_) {}
  try {
    await FlutterForegroundTask.saveData(
      key: 'running_bot_id',
      value: first.key,
    );
  } catch (_) {}
}

Future<Set<String>> getConfiguredMobileBotIds() async {
  final sessions = await _readConfiguredMobileSessions();
  return sessions.keys.toSet();
}

Future<void> startMobileBotSession({
  required String botId,
  required String token,
}) async {
  await _mobileSessionsOrchestrator.runSerialized(() async {
    final trimmedBotId = botId.trim();
    final trimmedToken = token.trim();
    if (trimmedBotId.isEmpty || trimmedToken.isEmpty) {
      throw Exception('botId/token invalid for mobile session start.');
    }

    final sessions = await _readConfiguredMobileSessions();
    sessions[trimmedBotId] = trimmedToken;
    await _writeConfiguredMobileSessions(sessions);

    final payload = <String, dynamic>{
      _mobileCommandTypeKey: _mobileCommandAddSession,
      'botId': trimmedBotId,
      'token': trimmedToken,
    };

    var running = false;
    try {
      running = await FlutterForegroundTask.isRunningService;
    } on MissingPluginException {
      running = false;
    }

    if (running) {
      try {
        FlutterForegroundTask.sendDataToTask(payload);
      } catch (_) {}
    } else {
      await startService();
    }

    addMobileRunningBotId(trimmedBotId);
    setBotRuntimeActive(true);
  });
}

Future<void> stopMobileBotSession({required String botId}) async {
  await _mobileSessionsOrchestrator.runSerialized(() async {
    final trimmedBotId = botId.trim();
    if (trimmedBotId.isEmpty) {
      return;
    }

    final sessions = await _readConfiguredMobileSessions();
    sessions.remove(trimmedBotId);
    await _writeConfiguredMobileSessions(sessions);

    var running = false;
    try {
      running = await FlutterForegroundTask.isRunningService;
    } on MissingPluginException {
      running = false;
    }

    if (running) {
      if (sessions.isEmpty) {
        await FlutterForegroundTask.stopService();
      } else {
        try {
          FlutterForegroundTask.sendDataToTask(<String, dynamic>{
            _mobileCommandTypeKey: _mobileCommandRemoveSession,
            'botId': trimmedBotId,
          });
        } catch (_) {}
      }
    }

    removeMobileRunningBotId(trimmedBotId);
    setBotRuntimeActive(isDesktopBotRunning || mobileRunningBotIds.isNotEmpty);
  });
}

Future<void> syncMobileBotSessionsWithService() async {
  await _mobileSessionsOrchestrator.runSerialized(() async {
    final sessions = await _readConfiguredMobileSessions();
    try {
      FlutterForegroundTask.sendDataToTask(<String, dynamic>{
        _mobileCommandTypeKey: _mobileCommandSyncSessions,
        'sessions': sessions,
      });
    } catch (_) {}
  });
}

Future<void> initForegroundService({int eventIntervalMs = 5000}) async {
  final safeIntervalMs = eventIntervalMs.clamp(1000, 60000);
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'foreground_service',
      channelName: 'Foreground Service Notification',
      channelDescription:
          'This notification appears when the foreground service is running.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(safeIntervalMs),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

Future<void> startService() async {
  debugPrint('[Bot] startService() called');
  await FlutterForegroundTask.startService(
    serviceId: 110,
    notificationTitle: 'Bots are running',
    notificationText: 'Bots are running in the background',
    callback: startCallback,
    notificationButtons: [NotificationButton(id: 'stop', text: 'Stop')],
  );
}

@pragma('vm:entry-point')
void startCallback() {
  ui.DartPluginRegistrant.ensureInitialized();
  debugPrint('[Bot] startCallback() invoked');
  FlutterForegroundTask.setTaskHandler(DiscordBotTaskHandler());
}

@pragma('vm:entry-point')
void stopCallback() {
  FlutterForegroundTask.stopService();
}

@pragma('vm:entry-point')
class DiscordBotTaskHandler extends TaskHandler {
  final Map<String, NyxxGateway> _clients = <String, NyxxGateway>{};
  final Map<String, DateTime> _mobileStartedAt = <String, DateTime>{};
  final Map<String, Timer> _mobileStatusRotationTimers = <String, Timer>{};
  final Map<String, bool> _readyBots = <String, bool>{};
  AppManager? _manager;
  StreamSubscription<LogRecord>? _mobileNyxxLogsSubscription;
  bool? _lastKnownDebugEnabled;
  final Random _mobileStatusRandom = Random();

  void _startMobileStatusRotation(
    String botId,
    NyxxGateway gateway,
    Map<String, dynamic> appData,
  ) {
    _mobileStatusRotationTimers[botId]?.cancel();
    _mobileStatusRotationTimers.remove(botId);

    final statuses = _normalizeStatuses(
      appData['activities'] ?? appData['statuses'],
    );
    if (statuses.isEmpty) {
      unawaited(
        _emitTaskLogToMain(
          'No configured status for mobile presence',
          botId: botId,
        ),
      );
      return;
    }

    final presenceStatus = (appData['presenceStatus'] as String?) ?? 'online';
    unawaited(
      _applyMobileInitialStatusThenRotate(
        botId,
        gateway,
        statuses,
        presenceStatus,
      ),
    );
  }

  Future<void> _applyMobileInitialStatusThenRotate(
    String botId,
    NyxxGateway gateway,
    List<Map<String, dynamic>> statuses,
    String presenceStatus,
  ) async {
    if (statuses.isEmpty) {
      return;
    }

    final firstStatus = statuses.first;
    await _applyMobileStatus(botId, gateway, firstStatus, presenceStatus);

    // Re-send once after READY to avoid occasional dropped first presence frame.
    Timer(const Duration(seconds: 3), () {
      unawaited(
        _applyMobileStatus(botId, gateway, firstStatus, presenceStatus),
      );
    });

    if (statuses.length == 1) {
      return;
    }

    final min = (firstStatus['minIntervalSeconds'] as int?) ?? 60;
    final max = (firstStatus['maxIntervalSeconds'] as int?) ?? min;
    final delaySeconds =
        max <= min ? min : min + _mobileStatusRandom.nextInt(max - min + 1);

    _mobileStatusRotationTimers[botId]?.cancel();
    _mobileStatusRotationTimers[botId] = Timer(
      Duration(seconds: delaySeconds),
      () {
        unawaited(
          _applyMobileRandomStatus(botId, gateway, statuses, presenceStatus),
        );
      },
    );
  }

  Future<void> _applyMobileRandomStatus(
    String botId,
    NyxxGateway gateway,
    List<Map<String, dynamic>> statuses,
    String presenceStatus,
  ) async {
    if (statuses.isEmpty) {
      return;
    }

    final picked = statuses[_mobileStatusRandom.nextInt(statuses.length)];
    await _applyMobileStatus(botId, gateway, picked, presenceStatus);

    final min = (picked['minIntervalSeconds'] as int?) ?? 60;
    final max = (picked['maxIntervalSeconds'] as int?) ?? min;
    final delaySeconds =
        max <= min ? min : min + _mobileStatusRandom.nextInt(max - min + 1);

    _mobileStatusRotationTimers[botId]?.cancel();
    _mobileStatusRotationTimers[botId] = Timer(
      Duration(seconds: delaySeconds),
      () {
        unawaited(
          _applyMobileRandomStatus(botId, gateway, statuses, presenceStatus),
        );
      },
    );
  }

  Future<void> _applyMobileStatus(
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
          status: _mapMobilePresenceStatus(presenceStatus),
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
      await _emitTaskLogToMain(
        'Mobile presence applied: $type $text',
        botId: botId,
      );
    } catch (error) {
      await _emitTaskDebugLogToMain(
        'Mobile presence update failed: $error',
        botId: botId,
      );
    }
  }

  CurrentUserStatus _mapMobilePresenceStatus(String statusString) {
    switch (statusString) {
      case 'idle':
        return CurrentUserStatus.idle;
      case 'dnd':
        return CurrentUserStatus.dnd;
      case 'invisible':
        return CurrentUserStatus.invisible;
      default:
        return CurrentUserStatus.online;
    }
  }

  Future<void> _syncDebugFlagFromMain() async {
    try {
      final persisted = await FlutterForegroundTask.getData<bool>(
        key: _debugLogsEnabledDataKey,
      );
      if (persisted != null) {
        final changed = _lastKnownDebugEnabled != persisted;
        _debugBotLogsEnabled = persisted;
        _lastKnownDebugEnabled = persisted;
        if (changed) {
          await _emitTaskLogToMain(
            persisted
                ? 'Mobile debug logs enabled'
                : 'Mobile debug logs disabled',
            botId: null,
          );
        }
      }
    } catch (_) {}

    try {
      final replayPersisted = await FlutterForegroundTask.getData<bool>(
        key: _debugReplayEnabledDataKey,
      );
      if (replayPersisted != null) {
        _debugReplayCapturing = replayPersisted;
      }
    } catch (_) {}
  }

  void _bindMobileNyxxLogs() {
    unawaited(_mobileNyxxLogsSubscription?.cancel());
    Logger.root.level = Level.ALL;
    _mobileNyxxLogsSubscription = Logger.root.onRecord.listen((record) {
      // Sur mobile, certains logs Nyxx n'utilisent pas toujours le préfixe
      // logger attendu. On laisse passer les records et le filtre final se fait
      // via _emitTaskDebugLogToMain (actif uniquement en mode debug).
      unawaited(_emitTaskDebugLogToMain(_formatNyxxLogRecord(record)));
    });
  }

  Future<void> _startSession(String botId, String token) async {
    if (_clients.containsKey(botId)) {
      return;
    }

    final trimmedBotId = botId.trim();
    final trimmedToken = token.trim();
    if (trimmedBotId.isEmpty || trimmedToken.isEmpty) {
      return;
    }

    try {
      await _emitTaskLogToMain(
        'Connecting for $trimmedBotId',
        botId: trimmedBotId,
      );
      final botUser = await getDiscordUser(trimmedToken);
      final resolvedBotId = botUser.id.toString();
      final appData = await _manager!.getApp(resolvedBotId);
      final intentsMap = Map<String, bool>.from(
        appData['intents'] as Map? ?? {},
      );
      final intents = buildGatewayIntents(intentsMap);
      final enabledIntentNames = _enabledIntentNames(intentsMap);

      await _emitTaskLogToMain(
        'Active runtime intents (${enabledIntentNames.length}): '
        '${enabledIntentNames.isEmpty ? 'none' : enabledIntentNames.join(', ')}',
        botId: resolvedBotId,
      );

      final gateway = await Nyxx.connectGateway(
        trimmedToken,
        intents,
        options: GatewayClientOptions(
          loggerName: 'CardiaKexa-$resolvedBotId',
          plugins: [Logging(logLevel: Level.ALL)],
        ),
      );

      _clients[resolvedBotId] = gateway;
      _mobileStartedAt[resolvedBotId] = DateTime.now();
      _readyBots[resolvedBotId] = false;

      gateway.onReady.listen((event) async {
        _readyBots[resolvedBotId] = true;
        await _emitTaskLifecycleToMain('started', botId: resolvedBotId);
        await _emitTaskLogToMain(
          'Mobile bot connected and ready',
          botId: resolvedBotId,
        );
        final latestAppData = await _manager!.getApp(resolvedBotId);
        _startMobileStatusRotation(resolvedBotId, gateway, latestAppData);
        await _emitTaskMetricsToMain(botId: resolvedBotId);

        gateway.onInteractionCreate.listen((event) async {
          await handleLocalCommands(event, _manager!);
        });

        await _registerLocalEventWorkflowListeners(
          gateway,
          manager: _manager!,
          botId: resolvedBotId,
          appData: latestAppData,
          onLog: (message) {
            unawaited(_emitTaskLogToMain(message, botId: resolvedBotId));
          },
        );
      });
    } catch (e) {
      await _emitTaskLifecycleToMain('stopped', botId: trimmedBotId);
      await _emitTaskLogToMain(
        'Discord connection failed: $e',
        botId: trimmedBotId,
      );
      developer.log(
        'Failed to start mobile session for $trimmedBotId: $e',
        name: 'DiscordBotTaskHandler',
      );
    }
  }

  Future<void> _stopSession(String botId) async {
    final trimmedBotId = botId.trim();
    if (trimmedBotId.isEmpty) {
      return;
    }

    _mobileStatusRotationTimers[trimmedBotId]?.cancel();
    _mobileStatusRotationTimers.remove(trimmedBotId);

    final client = _clients.remove(trimmedBotId);
    _readyBots.remove(trimmedBotId);
    _mobileStartedAt.remove(trimmedBotId);
    if (client != null) {
      await client.close();
    }
    await _emitTaskLifecycleToMain('stopped', botId: trimmedBotId);
    await _emitTaskLogToMain('Bot session stopped', botId: trimmedBotId);
  }

  Future<void> _syncSessions(Map<String, String> desired) async {
    final currentIds = _clients.keys.toSet();
    final desiredIds = desired.keys.toSet();

    for (final botId in currentIds.difference(desiredIds)) {
      await _stopSession(botId);
    }

    for (final entry in desired.entries) {
      if (!_clients.containsKey(entry.key)) {
        await _startSession(entry.key, entry.value);
      }
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    ui.DartPluginRegistrant.ensureInitialized();
    debugPrint('[Bot] DiscordBotTaskHandler.onStart()');
    await _syncDebugFlagFromMain();
    await _emitTaskLogToMain('Mobile service started');
    developer.log('Starting Discord bot', name: 'DiscordBotTaskHandler');
    _manager ??= AppManager();
    appManager = _manager!;

    _bindMobileNyxxLogs();
    final sessions = await _readConfiguredMobileSessions();
    if (sessions.isEmpty) {
      await _emitTaskLogToMain('No mobile sessions configured');
      return;
    }

    for (final entry in sessions.entries) {
      await _startSession(entry.key, entry.value);
    }
  }

  @override
  Future<void> onReceiveData(Object data) async {
    if (data is! Map) {
      return;
    }

    final payload = Map<String, dynamic>.from(data.cast<dynamic, dynamic>());
    final type = (payload[_mobileCommandTypeKey] ?? '').toString();
    if (type == _mobileCommandAddSession) {
      final botId = (payload['botId'] ?? '').toString();
      final token = (payload['token'] ?? '').toString();
      await _startSession(botId, token);
      return;
    }
    if (type == _mobileCommandRemoveSession) {
      final botId = (payload['botId'] ?? '').toString();
      await _stopSession(botId);
      return;
    }
    if (type == _mobileCommandSyncSessions) {
      final sessions = _normalizeMobileSessionsMap(payload['sessions']);
      await _syncSessions(sessions);
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      unawaited(
        _emitTaskLogToMain('Stop requested from notification', botId: null),
      );
      stopCallback();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    for (final timer in _mobileStatusRotationTimers.values) {
      timer.cancel();
    }
    _mobileStatusRotationTimers.clear();

    final sessionIds = _clients.keys.toList(growable: false);
    for (final botId in sessionIds) {
      await _stopSession(botId);
    }

    await _mobileNyxxLogsSubscription?.cancel();
    _mobileNyxxLogsSubscription = null;

    if (isTimeout) {
      await _emitTaskLogToMain('Service interrupted (timeout), restarting...');
      developer.log('Service timeout', name: 'DiscordBotTaskHandler');
      await startService();
    } else {
      await _emitTaskLogToMain('Service stopped');
      developer.log('Service stopped', name: 'DiscordBotTaskHandler');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_syncDebugFlagFromMain());
    for (final botId in _clients.keys) {
      unawaited(_emitTaskMetricsToMain(botId: botId));
    }
    unawaited(_emitTaskLogToMain('Heartbeat service'));
    developer.log('Repeat event', name: 'DiscordBotTaskHandler');
  }
}
