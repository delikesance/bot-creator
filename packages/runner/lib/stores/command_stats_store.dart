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
///   locale      TEXT NOT NULL DEFAULT '',
///   guild_locale TEXT NOT NULL DEFAULT '',
///   success     INTEGER NOT NULL DEFAULT 1,
///   latency_ms  INTEGER NOT NULL DEFAULT 0,
///   executed_at INTEGER NOT NULL
/// );
/// ```
class CommandStatsStore {
  final String _dbPath;
  late sqlite3.Database _db;
  final List<_CommandExecutionRecord> _memoryRecords =
      <_CommandExecutionRecord>[];
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
          locale      TEXT NOT NULL DEFAULT '',
          guild_locale TEXT NOT NULL DEFAULT '',
          success     INTEGER NOT NULL DEFAULT 1,
          latency_ms  INTEGER NOT NULL DEFAULT 0,
          executed_at INTEGER NOT NULL
        )
      ''');

      _ensureColumnExists(
        'command_executions',
        'locale',
        "TEXT NOT NULL DEFAULT ''",
      );
      _ensureColumnExists(
        'command_executions',
        'guild_locale',
        "TEXT NOT NULL DEFAULT ''",
      );
      _ensureColumnExists(
        'command_executions',
        'success',
        'INTEGER NOT NULL DEFAULT 1',
      );
      _ensureColumnExists(
        'command_executions',
        'latency_ms',
        'INTEGER NOT NULL DEFAULT 0',
      );

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
    String locale = '',
    String guildLocale = '',
    bool success = true,
    int latencyMs = 0,
  }) {
    if (!_initialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!_sqliteAvailable) {
      _memoryRecords.add(
        _CommandExecutionRecord(
          botId: botId,
          commandName: commandName,
          guildId: guildId,
          locale: locale,
          guildLocale: guildLocale,
          success: success,
          latencyMs: latencyMs,
          executedAtMs: now,
        ),
      );
      return;
    }
    _db.execute(
      'INSERT INTO command_executions (bot_id, command_name, guild_id, locale, guild_locale, success, latency_ms, executed_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        botId,
        commandName,
        guildId,
        locale,
        guildLocale,
        success ? 1 : 0,
        latencyMs < 0 ? 0 : latencyMs,
        now,
      ],
    );
  }

  Map<String, dynamic> queryHealthMetrics(String botId, {int? sinceMs}) {
    if (!_initialized) {
      return const <String, dynamic>{
        'total': 0,
        'failed': 0,
        'errorRatePct': 0.0,
        'p50LatencyMs': 0,
        'p95LatencyMs': 0,
      };
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = sinceMs != null ? now - sinceMs : 0;

    int total = 0;
    int failed = 0;
    List<int> latencies = <int>[];

    if (!_sqliteAvailable) {
      for (final row in _memoryRecords) {
        if (row.botId != botId || row.executedAtMs < cutoff) continue;
        total += 1;
        if (!row.success) {
          failed += 1;
        }
        if (row.latencyMs > 0) {
          latencies.add(row.latencyMs);
        }
      }
    } else {
      final totalsStmt = _db.prepare(
        'SELECT COUNT(*) as total, '
        'SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) as failed '
        'FROM command_executions '
        'WHERE bot_id = ? AND executed_at >= ?',
      );
      final totalsRows = totalsStmt.select([botId, cutoff]);
      totalsStmt.close();

      if (totalsRows.isNotEmpty) {
        total = totalsRows.first['total'] as int;
        failed = (totalsRows.first['failed'] as int?) ?? 0;
      }

      final latencyStmt = _db.prepare(
        'SELECT latency_ms FROM command_executions '
        'WHERE bot_id = ? AND executed_at >= ? AND latency_ms > 0 '
        'ORDER BY latency_ms ASC',
      );
      final latencyRows = latencyStmt.select([botId, cutoff]);
      latencyStmt.close();
      latencies = latencyRows
          .map((row) => row['latency_ms'] as int)
          .toList(growable: false);
    }

    final errorRate = total == 0 ? 0.0 : (failed * 100.0) / total;

    return <String, dynamic>{
      'total': total,
      'failed': failed,
      'errorRatePct': double.parse(errorRate.toStringAsFixed(1)),
      'p50LatencyMs': _percentile(latencies, 0.50),
      'p95LatencyMs': _percentile(latencies, 0.95),
    };
  }

  List<Map<String, dynamic>> queryLocales(String botId, {int? sinceMs}) {
    if (!_initialized) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = sinceMs != null ? now - sinceMs : 0;
    if (!_sqliteAvailable) {
      final counts = <String, int>{};
      for (final row in _memoryRecords) {
        if (row.botId != botId || row.executedAtMs < cutoff) continue;
        final normalized = _normalizedLocale(row.locale, row.guildLocale);
        if (normalized.isEmpty) continue;
        counts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
      }
      final entries =
          counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return entries
          .map(
            (entry) => <String, dynamic>{
              'locale': entry.key,
              'count': entry.value,
            },
          )
          .toList(growable: false);
    }

    final stmt = _db.prepare(
      'SELECT '
      "CASE "
      "WHEN TRIM(locale) <> '' THEN LOWER(TRIM(locale)) "
      "WHEN TRIM(guild_locale) <> '' THEN LOWER(TRIM(guild_locale)) "
      "ELSE '' END AS locale_key, "
      'COUNT(*) as count '
      'FROM command_executions '
      'WHERE bot_id = ? AND executed_at >= ? '
      'GROUP BY locale_key '
      "HAVING locale_key <> '' "
      'ORDER BY count DESC '
      'LIMIT 16',
    );
    final rows = stmt.select([botId, cutoff]);
    stmt.close();

    return rows
        .map(
          (row) => <String, dynamic>{
            'locale': (row['locale_key'] ?? '').toString(),
            'count': row['count'] as int,
          },
        )
        .toList(growable: false);
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
      final entries =
          counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
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

  void _ensureColumnExists(String table, String column, String definition) {
    final info = _db.select('PRAGMA table_info($table)');
    final hasColumn = info.any((row) => row['name']?.toString() == column);
    if (hasColumn) {
      return;
    }
    _db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  String _normalizedLocale(String locale, String guildLocale) {
    final primary = locale.trim().toLowerCase();
    if (primary.isNotEmpty) {
      return primary;
    }
    final fallback = guildLocale.trim().toLowerCase();
    return fallback;
  }

  int _percentile(List<int> sortedValues, double p) {
    if (sortedValues.isEmpty) {
      return 0;
    }
    final sorted = List<int>.from(sortedValues)..sort();
    final index = ((sorted.length - 1) * p).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}

class _CommandExecutionRecord {
  const _CommandExecutionRecord({
    required this.botId,
    required this.commandName,
    required this.guildId,
    required this.locale,
    required this.guildLocale,
    required this.success,
    required this.latencyMs,
    required this.executedAtMs,
  });

  final String botId;
  final String commandName;
  final String guildId;
  final String locale;
  final String guildLocale;
  final bool success;
  final int latencyMs;
  final int executedAtMs;
}
