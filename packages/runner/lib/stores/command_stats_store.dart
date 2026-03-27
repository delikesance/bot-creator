import 'dart:io';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Lightweight SQLite store that records command execution counts.
///
/// Schema:
/// ```sql
/// CREATE TABLE command_executions (
///   id          INTEGER PRIMARY KEY AUTOINCREMENT,
///   bot_id      TEXT NOT NULL,
///   command_name TEXT NOT NULL,
///   guild_id    TEXT NOT NULL DEFAULT '',
///   executed_at INTEGER NOT NULL
/// );
/// ```
class CommandStatsStore {
  final String _dbPath;
  late sqlite3.Database _db;
  final List<_CommandExecutionRecord> _memoryRecords = <_CommandExecutionRecord>[];
  bool _sqliteAvailable = false;
  bool _initialized = false;

  CommandStatsStore(String workDir)
    : _dbPath = join(workDir, 'command_stats.db');

  Future<void> init() async {
    if (_initialized) return;

    final dbDir = dirname(_dbPath);
    final dbDirectory = Directory(dbDir);
    if (!await dbDirectory.exists()) {
      await dbDirectory.create(recursive: true);
    }

    // Ensure the file exists even when native SQLite isn't available.
    final dbFile = File(_dbPath);
    if (!await dbFile.exists()) {
      await dbFile.create(recursive: true);
    }

    try {
      _db = sqlite3.sqlite3.open(_dbPath);

      _db.execute('''
        CREATE TABLE IF NOT EXISTS command_executions (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          bot_id      TEXT NOT NULL,
          command_name TEXT NOT NULL,
          guild_id    TEXT NOT NULL DEFAULT '',
          executed_at INTEGER NOT NULL
        )
      ''');

      _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_cmd_exec_bot
        ON command_executions(bot_id, command_name)
      ''');
      _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_cmd_exec_time
        ON command_executions(bot_id, executed_at)
      ''');
      _sqliteAvailable = true;
    } catch (_) {
      _sqliteAvailable = false;
    }

    _initialized = true;
  }

  /// Record one command execution.
  void record({
    required String botId,
    required String commandName,
    String guildId = '',
  }) {
    if (!_initialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!_sqliteAvailable) {
      _memoryRecords.add(
        _CommandExecutionRecord(
          botId: botId,
          commandName: commandName,
          guildId: guildId,
          executedAtMs: now,
        ),
      );
      return;
    }
    _db.execute(
      'INSERT INTO command_executions (bot_id, command_name, guild_id, executed_at) '
      'VALUES (?, ?, ?, ?)',
      [botId, commandName, guildId, now],
    );
  }

  /// Return per-command totals for [botId], optionally filtered to the
  /// last [sinceMs] milliseconds.
  List<Map<String, dynamic>> querySummary(String botId, {int? sinceMs}) {
    if (!_initialized) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = sinceMs != null ? now - sinceMs : 0;
    if (!_sqliteAvailable) {
      final counts = <String, int>{};
      for (final row in _memoryRecords) {
        if (row.botId != botId || row.executedAtMs < cutoff) continue;
        counts.update(row.commandName, (value) => value + 1, ifAbsent: () => 1);
      }
      final entries = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return entries
          .map(
            (entry) => <String, dynamic>{
              'command': entry.key,
              'count': entry.value,
            },
          )
          .toList(growable: false);
    }

    final stmt = _db.prepare(
      'SELECT command_name, COUNT(*) as count '
      'FROM command_executions '
      'WHERE bot_id = ? AND executed_at >= ? '
      'GROUP BY command_name '
      'ORDER BY count DESC',
    );
    final rows = stmt.select([botId, cutoff]);
    stmt.close();

    return rows
        .map(
          (row) => <String, dynamic>{
            'command': row['command_name'] as String,
            'count': row['count'] as int,
          },
        )
        .toList(growable: false);
  }

  /// Return execution counts per hour for [botId] over the last [hours] hours.
  List<Map<String, dynamic>> queryTimeline(String botId, {int hours = 24}) {
    if (!_initialized) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - (hours * 3600000);
    if (!_sqliteAvailable) {
      final counts = <int, int>{};
      for (final row in _memoryRecords) {
        if (row.botId != botId || row.executedAtMs < cutoff) continue;
        final bucket = row.executedAtMs ~/ 3600000;
        counts.update(bucket, (value) => value + 1, ifAbsent: () => 1);
      }
      final buckets = counts.keys.toList()..sort();
      return buckets
          .map(
            (bucket) => <String, dynamic>{
              'hour': bucket.toString(),
              'count': counts[bucket]!,
            },
          )
          .toList(growable: false);
    }

    final stmt = _db.prepare(
      'SELECT (executed_at / 3600000) as hour_bucket, COUNT(*) as count '
      'FROM command_executions '
      'WHERE bot_id = ? AND executed_at >= ? '
      'GROUP BY hour_bucket '
      'ORDER BY hour_bucket ASC',
    );
    final rows = stmt.select([botId, cutoff]);
    stmt.close();

    return rows
        .map(
          (row) => <String, dynamic>{
            'hour': (row['hour_bucket'] as int).toString(),
            'count': row['count'] as int,
          },
        )
        .toList(growable: false);
  }

  /// Total execution count for [botId].
  int totalCount(String botId) {
    if (!_initialized) return 0;
    if (!_sqliteAvailable) {
      var count = 0;
      for (final row in _memoryRecords) {
        if (row.botId == botId) {
          count++;
        }
      }
      return count;
    }
    final stmt = _db.prepare(
      'SELECT COUNT(*) as total FROM command_executions WHERE bot_id = ?',
    );
    final rows = stmt.select([botId]);
    stmt.close();
    if (rows.isEmpty) return 0;
    return rows.first['total'] as int;
  }

  void dispose() {
    if (_initialized) {
      if (_sqliteAvailable) {
        _db.close();
      }
      _memoryRecords.clear();
      _sqliteAvailable = false;
      _initialized = false;
    }
  }
}

class _CommandExecutionRecord {
  const _CommandExecutionRecord({
    required this.botId,
    required this.commandName,
    required this.guildId,
    required this.executedAtMs,
  });

  final String botId;
  final String commandName;
  final String guildId;
  final int executedAtMs;
}
