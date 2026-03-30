part of 'bot.dart';

class _CpuSample {
  const _CpuSample({required this.jiffies, required this.timestampMs});

  final int jiffies;
  final int timestampMs;
}

class BotRuntimeMetrics {
  const BotRuntimeMetrics({
    this.rssBytes,
    this.estimatedRssBytes,
    this.cpuPercent,
    this.storageBytes,
    this.baselineRssBytes,
    this.baselineCapturedAt,
  });

  final int? rssBytes;
  final int? estimatedRssBytes;
  final double? cpuPercent;
  final int? storageBytes;
  final int? baselineRssBytes;
  final DateTime? baselineCapturedAt;

  BotRuntimeMetrics copyWith({
    int? rssBytes,
    int? estimatedRssBytes,
    double? cpuPercent,
    int? storageBytes,
    int? baselineRssBytes,
    DateTime? baselineCapturedAt,
  }) {
    return BotRuntimeMetrics(
      rssBytes: rssBytes ?? this.rssBytes,
      estimatedRssBytes: estimatedRssBytes ?? this.estimatedRssBytes,
      cpuPercent: cpuPercent ?? this.cpuPercent,
      storageBytes: storageBytes ?? this.storageBytes,
      baselineRssBytes: baselineRssBytes ?? this.baselineRssBytes,
      baselineCapturedAt: baselineCapturedAt ?? this.baselineCapturedAt,
    );
  }
}

String _resolveBotBucketKey(String? botId) {
  final trimmed = botId?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  final active = _activeBotLogBotId?.trim() ?? '';
  if (active.isNotEmpty) {
    return active;
  }
  return _globalBotBucketKey;
}

_CpuSample? _lastCpuSample;
bool _remoteMetricsBaselineInitialized = false;

Future<void> _persistDebugLogsEnabled(bool enabled) async {
  try {
    await FlutterForegroundTask.saveData(
      key: _debugLogsEnabledDataKey,
      value: enabled,
    );
  } catch (_) {}
}

int? _readCurrentProcessRssBytes() {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    return null;
  }
}

void captureBotBaselineRss({bool force = false}) {
  if (!force && _botBaselineRssBytes != null) {
    return;
  }
  final current = _readCurrentProcessRssBytes();
  if (current == null) {
    return;
  }
  _botBaselineRssBytes = current;
  _botBaselineCapturedAt = DateTime.now();
  if (!_botEstimatedRssController.isClosed) {
    _botEstimatedRssController.add(_botEstimatedRssBytes);
  }
}

void clearBotBaselineRss() {
  _botBaselineRssBytes = null;
  _botBaselineCapturedAt = null;
  _botEstimatedRssBytes = null;
  if (!_botEstimatedRssController.isClosed) {
    _botEstimatedRssController.add(null);
  }
}

void setBotRuntimeActive(bool active) {
  _botRuntimeActive = active;
  if (active) {
    return;
  }

  _remoteMetricsBaselineInitialized = false;
  clearBotBaselineRss();
  _lastCpuSample = null;
  _updateBotMetrics(
    rssBytes: null,
    cpuPercent: null,
    storageBytes: null,
    overwriteNulls: true,
  );
}

int? _readCurrentProcessCpuJiffies() {
  if (!(Platform.isAndroid || Platform.isLinux)) {
    return null;
  }

  try {
    final stat = File('/proc/self/stat').readAsStringSync();
    final lastParen = stat.lastIndexOf(')');
    if (lastParen == -1 || lastParen + 2 >= stat.length) {
      return null;
    }
    final afterState = stat.substring(lastParen + 2).trim();
    final fields = afterState.split(RegExp(r'\s+'));
    if (fields.length <= 11) {
      return null;
    }

    final utime = int.tryParse(fields[10]);
    final stime = int.tryParse(fields[11]);
    if (utime == null || stime == null) {
      return null;
    }
    return utime + stime;
  } catch (_) {
    return null;
  }
}

double? _readCurrentProcessCpuPercent() {
  final jiffies = _readCurrentProcessCpuJiffies();
  if (jiffies == null) {
    return null;
  }

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final prev = _lastCpuSample;
  _lastCpuSample = _CpuSample(jiffies: jiffies, timestampMs: nowMs);

  if (prev == null) {
    return 0.0;
  }

  final deltaJiffies = jiffies - prev.jiffies;
  final deltaMs = nowMs - prev.timestampMs;
  if (deltaJiffies <= 0 || deltaMs <= 0) {
    return 0;
  }

  const ticksPerSecond = 100.0;
  final elapsedSeconds = deltaMs / 1000.0;
  final cpuSeconds = deltaJiffies / ticksPerSecond;
  final cores = Platform.numberOfProcessors.clamp(1, 64);
  final percent = (cpuSeconds / elapsedSeconds) * 100.0 / cores;
  if (percent.isNaN || percent.isInfinite) {
    return null;
  }
  return percent.clamp(0, 100.0);
}

Future<int?> _readBotStorageBytes({String? botId}) async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final basePath = docsDir.path;
    final appsDir = Directory('$basePath/apps');
    if (!await appsDir.exists()) {
      return 0;
    }

    Future<int> dirSize(Directory dir) async {
      var total = 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
      return total;
    }

    if (botId == null || botId.isEmpty) {
      return await dirSize(appsDir);
    }

    var total = 0;
    final botJson = File('$basePath/apps/$botId.json');
    if (await botJson.exists()) {
      total += await botJson.length();
    }
    final botDir = Directory('$basePath/apps/$botId');
    if (await botDir.exists()) {
      total += await dirSize(botDir);
    }
    return total;
  } catch (_) {
    return null;
  }
}

void _updateBotMetrics({
  int? rssBytes,
  double? cpuPercent,
  int? storageBytes,
  int? estimatedRssBytes,
  String? botId,
  bool overwriteNulls = false,
}) {
  final key = _resolveBotBucketKey(botId);
  final previous = _botMetricsByBot[key] ?? const BotRuntimeMetrics();

  final nextRss =
      overwriteNulls || rssBytes != null ? rssBytes : previous.rssBytes;
  final nextCpu =
      overwriteNulls || cpuPercent != null ? cpuPercent : previous.cpuPercent;
  final nextStorage =
      overwriteNulls || storageBytes != null
          ? storageBytes
          : previous.storageBytes;

  int? nextEstimated;
  if (estimatedRssBytes != null) {
    nextEstimated = estimatedRssBytes;
  } else if (nextRss != null && _botBaselineRssBytes != null) {
    nextEstimated = (nextRss - _botBaselineRssBytes!).clamp(0, nextRss);
  } else if (overwriteNulls || nextRss == null) {
    nextEstimated = null;
  } else {
    nextEstimated = previous.estimatedRssBytes;
  }

  final next = BotRuntimeMetrics(
    rssBytes: nextRss,
    estimatedRssBytes: nextEstimated,
    cpuPercent: nextCpu,
    storageBytes: nextStorage,
    baselineRssBytes: _botBaselineRssBytes,
    baselineCapturedAt: _botBaselineCapturedAt,
  );
  _botMetricsByBot[key] = next;

  if (!_botMetricsByBotController.isClosed) {
    _botMetricsByBotController.add(
      Map<String, BotRuntimeMetrics>.unmodifiable(_botMetricsByBot),
    );
  }

  final selectedKey = _resolveBotBucketKey(_activeBotLogBotId);
  final selected =
      _botMetricsByBot[selectedKey] ??
      _botMetricsByBot[key] ??
      const BotRuntimeMetrics();

  _botProcessRssBytes = selected.rssBytes;
  _botEstimatedRssBytes = selected.estimatedRssBytes;
  _botProcessCpuPercent = selected.cpuPercent;
  _botProcessStorageBytes = selected.storageBytes;

  if (!_botProcessRssController.isClosed) {
    _botProcessRssController.add(_botProcessRssBytes);
  }
  if (!_botEstimatedRssController.isClosed) {
    _botEstimatedRssController.add(_botEstimatedRssBytes);
  }
  if (!_botProcessCpuController.isClosed) {
    _botProcessCpuController.add(_botProcessCpuPercent);
  }
  if (!_botProcessStorageController.isClosed) {
    _botProcessStorageController.add(_botProcessStorageBytes);
  }
}

Future<void> _refreshBotMetrics({String? botId}) async {
  final rss = _readCurrentProcessRssBytes();
  final cpu = _readCurrentProcessCpuPercent();
  final storage = await _readBotStorageBytes(botId: botId);
  _updateBotMetrics(
    rssBytes: rss,
    cpuPercent: cpu,
    storageBytes: storage,
    botId: botId,
  );
}

Future<void> refreshBotStatsNow({
  String? botId,
  bool captureBaseline = false,
}) async {
  if (!isBotRuntimeActive) {
    _updateBotMetrics(
      rssBytes: null,
      cpuPercent: null,
      storageBytes: null,
      botId: botId,
      overwriteNulls: true,
    );
    return;
  }

  if (captureBaseline) {
    captureBotBaselineRss(force: true);
  }
  await _refreshBotMetrics(botId: botId);
}

void updateBotRuntimeMetricsFromRemote({
  required bool running,
  String? botId,
  int? rssBytes,
  int? estimatedRssBytes,
  double? cpuPercent,
  int? storageBytes,
}) {
  if (!running) {
    setBotRuntimeActive(false);
    return;
  }

  if (!_remoteMetricsBaselineInitialized && rssBytes != null) {
    _botBaselineRssBytes = rssBytes;
    _botBaselineCapturedAt = DateTime.now();
    _remoteMetricsBaselineInitialized = true;
  }

  setBotRuntimeActive(true);
  _updateBotMetrics(
    rssBytes: rssBytes,
    estimatedRssBytes: estimatedRssBytes,
    cpuPercent: cpuPercent,
    storageBytes: storageBytes,
    botId: botId,
    overwriteNulls: true,
  );
}

Stream<int?> getBotProcessRssStream() => _botProcessRssController.stream;

int? getBotProcessRssBytes() => _botProcessRssBytes;

Stream<int?> getBotEstimatedRssStream() => _botEstimatedRssController.stream;

int? getBotEstimatedRssBytes() => _botEstimatedRssBytes;

int? getBotBaselineRssBytes() => _botBaselineRssBytes;

DateTime? getBotBaselineCapturedAt() => _botBaselineCapturedAt;

Stream<double?> getBotProcessCpuStream() => _botProcessCpuController.stream;

double? getBotProcessCpuPercent() => _botProcessCpuPercent;

Stream<int?> getBotProcessStorageStream() =>
    _botProcessStorageController.stream;

int? getBotProcessStorageBytes() => _botProcessStorageBytes;

Future<void> _emitTaskMetricsToMain({String? botId}) async {
  final rssBytes = _readCurrentProcessRssBytes();
  final cpuPercent = _readCurrentProcessCpuPercent();
  final storageBytes = await _readBotStorageBytes(botId: botId);
  try {
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'type': 'bot_metrics',
      'botId': botId,
      'rssBytes': rssBytes,
      'cpuPercent': cpuPercent,
      'storageBytes': storageBytes,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

void _publishBotLogs() {
  final selectedKey = _resolveBotBucketKey(_activeBotLogBotId);
  _botLogs = List<String>.from(
    _botLogsByBot[selectedKey] ?? const <String>[],
    growable: false,
  );

  if (!_botLogsController.isClosed) {
    _botLogsController.add(List<String>.unmodifiable(_botLogs));
  }
  if (!_botLogsByBotController.isClosed) {
    _botLogsByBotController.add(
      Map<String, List<String>>.unmodifiable(
        _botLogsByBot.map(
          (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
        ),
      ),
    );
  }
}

Stream<List<String>> getBotLogsStream() => _botLogsController.stream;

List<String> getBotLogsSnapshot() => List<String>.unmodifiable(_botLogs);

Stream<List<String>> getBotLogsStreamForBot(String? botId) {
  final key = _resolveBotBucketKey(botId);
  return _botLogsByBotController.stream.map(
    (logsByBot) =>
        List<String>.unmodifiable(logsByBot[key] ?? const <String>[]),
  );
}

List<String> getBotLogsSnapshotForBot(String? botId) {
  final key = _resolveBotBucketKey(botId);
  final logs = _botLogsByBot[key] ?? const <String>[];
  return List<String>.unmodifiable(logs);
}

Set<String> getKnownBotLogIds() {
  final ids = <String>{
    ..._botLogsByBot.keys,
    ...mobileRunningBotIds,
    ..._botMetricsByBot.keys,
  }..remove(_globalBotBucketKey);
  return ids;
}

void startBotLogSession({required String botId}) {
  _activeBotLogBotId = botId;
  _botLogsByBot[botId] = <String>[];
  _remoteMetricsBaselineInitialized = false;
  captureBotBaselineRss(force: true);
  _lastCpuSample = null;
  _updateBotMetrics(
    rssBytes: null,
    cpuPercent: null,
    storageBytes: null,
    botId: botId,
    overwriteNulls: true,
  );
  appendBotLog('Log session started', botId: botId);
}

void endBotLogSession({required String botId, bool clearLogs = true}) {
  final key = botId.trim();
  if (key.isEmpty) {
    return;
  }

  if (clearLogs) {
    _botLogsByBot.remove(key);
  }
  _botMetricsByBot.remove(key);

  if (_activeBotLogBotId == key) {
    _activeBotLogBotId = null;
  }

  _publishBotLogs();

  if (!_botMetricsByBotController.isClosed) {
    _botMetricsByBotController.add(
      Map<String, BotRuntimeMetrics>.unmodifiable(_botMetricsByBot),
    );
  }

  final selectedKey = _resolveBotBucketKey(_activeBotLogBotId);
  final selected = _botMetricsByBot[selectedKey];
  _botProcessRssBytes = selected?.rssBytes;
  _botEstimatedRssBytes = selected?.estimatedRssBytes;
  _botProcessCpuPercent = selected?.cpuPercent;
  _botProcessStorageBytes = selected?.storageBytes;

  if (!_botProcessRssController.isClosed) {
    _botProcessRssController.add(_botProcessRssBytes);
  }
  if (!_botEstimatedRssController.isClosed) {
    _botEstimatedRssController.add(_botEstimatedRssBytes);
  }
  if (!_botProcessCpuController.isClosed) {
    _botProcessCpuController.add(_botProcessCpuPercent);
  }
  if (!_botProcessStorageController.isClosed) {
    _botProcessStorageController.add(_botProcessStorageBytes);
  }
}

bool _startsWithTimestamp(String message) {
  final trimmed = message.trimLeft();
  if (trimmed.isEmpty) {
    return false;
  }

  final hhmmssPattern = RegExp(
    r'^\[(?:[01]?\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?\]',
  );
  if (hhmmssPattern.hasMatch(trimmed)) {
    return true;
  }

  final isoPattern = RegExp(
    r'^\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\]',
  );
  return isoPattern.hasMatch(trimmed);
}

void appendBotLog(String message, {String? botId}) {
  final key = _resolveBotBucketKey(botId);
  final logs = _botLogsByBot.putIfAbsent(key, () => <String>[]);
  final line =
      _startsWithTimestamp(message) ? message : '[${_timestampNow()}] $message';
  logs.add(line);
  if (logs.length > _maxBotLogLines) {
    _botLogsByBot[key] = logs.sublist(logs.length - _maxBotLogLines);
  }
  _publishBotLogs();
}

Stream<int?> getBotProcessRssStreamForBot(String? botId) {
  final key = _resolveBotBucketKey(botId);
  return _botMetricsByBotController.stream.map(
    (metricsByBot) => metricsByBot[key]?.rssBytes,
  );
}

int? getBotProcessRssBytesForBot(String? botId) {
  final key = _resolveBotBucketKey(botId);
  return _botMetricsByBot[key]?.rssBytes;
}

Stream<int?> getBotEstimatedRssStreamForBot(String? botId) {
  final key = _resolveBotBucketKey(botId);
  return _botMetricsByBotController.stream.map(
    (metricsByBot) => metricsByBot[key]?.estimatedRssBytes,
  );
}

int? getBotEstimatedRssBytesForBot(String? botId) {
  final key = _resolveBotBucketKey(botId);
  return _botMetricsByBot[key]?.estimatedRssBytes;
}

Stream<double?> getBotProcessCpuStreamForBot(String? botId) {
  final key = _resolveBotBucketKey(botId);
  return _botMetricsByBotController.stream.map(
    (metricsByBot) => metricsByBot[key]?.cpuPercent,
  );
}

double? getBotProcessCpuPercentForBot(String? botId) {
  final key = _resolveBotBucketKey(botId);
  return _botMetricsByBot[key]?.cpuPercent;
}

Stream<int?> getBotProcessStorageStreamForBot(String? botId) {
  final key = _resolveBotBucketKey(botId);
  return _botMetricsByBotController.stream.map(
    (metricsByBot) => metricsByBot[key]?.storageBytes,
  );
}

int? getBotProcessStorageBytesForBot(String? botId) {
  final key = _resolveBotBucketKey(botId);
  return _botMetricsByBot[key]?.storageBytes;
}

void appendBotDebugLog(String message, {String? botId}) {
  if (!_debugBotLogsEnabled) {
    return;
  }
  appendBotLog('DEBUG: $message', botId: botId);
}

String _formatNyxxLogRecord(LogRecord record) {
  final buffer = StringBuffer(
    '[${record.level.name}] [${record.loggerName}] ${record.message}',
  );
  if (record.error != null) {
    buffer.write(' | error=${record.error}');
  }
  return buffer.toString();
}

void _bindDesktopNyxxLogs({String? botId}) {
  _desktopNyxxLogsSubscription?.cancel();
  Logger.root.level = Level.ALL;
  _desktopNyxxLogsSubscription = Logger.root.onRecord.listen((record) {
    final name = record.loggerName;
    if (!name.startsWith('CardiaKexa')) {
      return;
    }
    appendBotDebugLog(_formatNyxxLogRecord(record), botId: botId);
  });
}

void consumeForegroundTaskDataForBotLogs(Object data) {
  if (data is! Map) {
    return;
  }
  final map = Map<String, dynamic>.from(data.cast<dynamic, dynamic>());
  if (map['type'] == 'bot_lifecycle') {
    final state = map['state']?.toString();
    final botId = map['botId']?.toString();
    if (state == 'started') {
      if (botId != null && botId.isNotEmpty) {
        addMobileRunningBotId(botId);
      }
      setBotRuntimeActive(true);
      return;
    }
    if (state == 'stopped') {
      if (botId != null && botId.isNotEmpty) {
        removeMobileRunningBotId(botId);
        endBotLogSession(botId: botId);
      } else {
        setMobileRunningBotId(null);
      }
      setBotRuntimeActive(
        isDesktopBotRunning || mobileRunningBotIds.isNotEmpty,
      );
    }
    return;
  }

  if (map['type'] == 'bot_metrics') {
    final botId = map['botId']?.toString();
    final rssBytes = map['rssBytes'];
    final rssAsInt =
        (rssBytes is int)
            ? rssBytes
            : int.tryParse((rssBytes ?? '').toString());
    final cpuRaw = map['cpuPercent'];
    final cpuAsDouble =
        (cpuRaw is num) ? cpuRaw.toDouble() : double.tryParse('$cpuRaw');
    final storageRaw = map['storageBytes'];
    final storageAsInt =
        (storageRaw is int)
            ? storageRaw
            : int.tryParse((storageRaw ?? '').toString());
    _updateBotMetrics(
      rssBytes: rssAsInt,
      cpuPercent: cpuAsDouble,
      storageBytes: storageAsInt,
      botId: botId,
    );
    return;
  }

  if (map['type'] != 'bot_log') {
    return;
  }
  final botId = map['botId']?.toString();
  final message = map['message']?.toString();
  if (message == null || message.isEmpty) {
    return;
  }
  appendBotLog(message, botId: botId);
}

Future<void> _emitTaskLifecycleToMain(String state, {String? botId}) async {
  try {
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'type': 'bot_lifecycle',
      'state': state,
      'botId': botId,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

Future<void> _emitTaskLogToMain(String message, {String? botId}) async {
  try {
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'type': 'bot_log',
      'botId': botId,
      'message': message,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

Future<void> _emitTaskDebugLogToMain(String message, {String? botId}) async {
  if (!_debugBotLogsEnabled) {
    return;
  }
  await _emitTaskLogToMain('DEBUG: $message', botId: botId);
}
