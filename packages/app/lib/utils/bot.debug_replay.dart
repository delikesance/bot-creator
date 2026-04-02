part of 'bot.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class DebugActionFrame {
  final String actionType;
  final int startMs;
  final int durationMs;
  final String? result;
  final int? loopDepth;
  final int? loopIteration;

  const DebugActionFrame({
    required this.actionType,
    required this.startMs,
    required this.durationMs,
    this.result,
    this.loopDepth,
    this.loopIteration,
  });

  bool get isError => result != null && result!.startsWith('Error:');

  factory DebugActionFrame.fromJson(Map<String, dynamic> json) =>
      DebugActionFrame(
        actionType: (json['actionType'] ?? '').toString(),
        startMs: (json['startMs'] as int?) ?? 0,
        durationMs: (json['durationMs'] as int?) ?? 0,
        result: json['result']?.toString(),
        loopDepth: json['loopDepth'] as int?,
        loopIteration: json['loopIteration'] as int?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'actionType': actionType,
    'startMs': startMs,
    'durationMs': durationMs,
    if (result != null) 'result': result,
    if (loopDepth != null) 'loopDepth': loopDepth,
    if (loopIteration != null) 'loopIteration': loopIteration,
  };
}

class DebugReplayRecord {
  final String commandLabel;
  final DateTime triggeredAt;
  final String botId;
  final List<DebugActionFrame> frames;
  final int totalMs;

  const DebugReplayRecord({
    required this.commandLabel,
    required this.triggeredAt,
    required this.botId,
    required this.frames,
    required this.totalMs,
  });

  bool get hasError => frames.any((f) => f.isError);
  int get actionCount => frames.length;

  factory DebugReplayRecord.fromJson(Map<String, dynamic> json) {
    final rawFrames = json['frames'];
    final frames =
        (rawFrames is List)
            ? rawFrames
                .whereType<Map>()
                .map(
                  (f) =>
                      DebugActionFrame.fromJson(Map<String, dynamic>.from(f)),
                )
                .toList(growable: false)
            : const <DebugActionFrame>[];
    return DebugReplayRecord(
      commandLabel: (json['commandLabel'] ?? '').toString(),
      triggeredAt:
          DateTime.tryParse(json['triggeredAt']?.toString() ?? '') ??
          DateTime.now(),
      botId: (json['botId'] ?? '').toString(),
      frames: frames,
      totalMs: (json['totalMs'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'commandLabel': commandLabel,
    'triggeredAt': triggeredAt.toUtc().toIso8601String(),
    'botId': botId,
    'frames': frames.map((f) => f.toJson()).toList(growable: false),
    'totalMs': totalMs,
  };
}

// ─── In-memory store (main isolate) ──────────────────────────────────────────

const String _debugReplayEnabledDataKey = 'debugReplayEnabled';
bool _debugReplayCapturing = false;

final List<DebugReplayRecord> _debugReplays = <DebugReplayRecord>[];
final StreamController<List<DebugReplayRecord>> _debugReplaysController =
    StreamController<List<DebugReplayRecord>>.broadcast();

const int _maxDebugReplays = 30;

bool get isDebugReplayCapturing => _debugReplayCapturing;

Stream<List<DebugReplayRecord>> get debugReplaysStream =>
    _debugReplaysController.stream;

List<DebugReplayRecord> get debugReplays =>
    List<DebugReplayRecord>.unmodifiable(_debugReplays);

void setDebugReplayCapturing(bool enabled) {
  _debugReplayCapturing = enabled;
  unawaited(_persistDebugReplayCapturing(enabled));
  unawaited(syncMobileDebugFlagsWithService());
}

Future<void> _persistDebugReplayCapturing(bool enabled) async {
  try {
    await FlutterForegroundTask.saveData(
      key: _debugReplayEnabledDataKey,
      value: enabled,
    );
  } catch (_) {}
}

Future<void> loadDebugReplayCapturingState() async {
  try {
    final saved = await FlutterForegroundTask.getData<dynamic>(
      key: _debugReplayEnabledDataKey,
    );
    _debugReplayCapturing = saved == true;
  } catch (_) {
    _debugReplayCapturing = false;
  }
}

void appendDebugReplay(DebugReplayRecord record) {
  _debugReplays.insert(0, record);
  if (_debugReplays.length > _maxDebugReplays) {
    _debugReplays.removeRange(_maxDebugReplays, _debugReplays.length);
  }
  if (!_debugReplaysController.isClosed) {
    _debugReplaysController.add(
      List<DebugReplayRecord>.unmodifiable(_debugReplays),
    );
  }
}

void clearDebugReplays() {
  _debugReplays.clear();
  if (!_debugReplaysController.isClosed) {
    _debugReplaysController.add(const <DebugReplayRecord>[]);
  }
}

// ─── Service-isolate → main-isolate bridge ───────────────────────────────────

Future<void> _emitReplayToMain(DebugReplayRecord record) async {
  try {
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'type': 'debug_replay',
      ...record.toJson(),
    });
  } catch (_) {}
}
