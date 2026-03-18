import 'dart:io';
import 'package:path/path.dart';
import 'package:bot_creator_shared/bot/variable_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// SQLite implementation of [VariableDatabase] using sqlite3 (CLI runner).
/// Lightweight pure Dart implementation, works on all platforms (Windows, Mac, Linux, etc.).
///
/// Same schema as app version:
/// ```sql
/// CREATE TABLE variables (
///   id INTEGER PRIMARY KEY,
///   bot_id TEXT NOT NULL,
///   scope TEXT NOT NULL,
///   context_id_1 TEXT NOT NULL,
///   context_id_2 TEXT,
///   key TEXT NOT NULL,
///   value_raw TEXT NOT NULL,
///   value_type TEXT NOT NULL,
///   created_at INTEGER NOT NULL,
///   updated_at INTEGER NOT NULL,
///   UNIQUE(bot_id, scope, context_id_1, context_id_2, key),
///   CHECK(scope IN ('guild', 'user', 'channel', 'guildMember', 'message'))
/// );
/// ```
class SqliteCliVariableStore implements VariableDatabase {
  final String _dbPath;
  late sqlite3.Database _db;
  bool _initialized = false;

  SqliteCliVariableStore(String workDir)
      : _dbPath = join(workDir, 'variables.db');

  /// Initialize database connection and create schema if needed.
  Future<void> init() async {
    if (_initialized) return;

    // Ensure database directory exists
    final dbDir = dirname(_dbPath);
    final dbDirectory = Directory(dbDir);
    if (!await dbDirectory.exists()) {
      await dbDirectory.create(recursive: true);
    }

    // Open database
    _db = sqlite3.sqlite3.open(_dbPath);

    // Create schema if not exists
    _db.execute('''
      CREATE TABLE IF NOT EXISTS variables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bot_id TEXT NOT NULL,
        scope TEXT NOT NULL,
        context_id_1 TEXT NOT NULL,
        context_id_2 TEXT,
        key TEXT NOT NULL,
        value_raw TEXT NOT NULL,
        value_type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(bot_id, scope, context_id_1, context_id_2, key),
        CHECK(scope IN ('guild', 'user', 'channel', 'guildMember', 'message'))
      )
    ''');

    // Create index if not exists
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_bot_lookup 
      ON variables(bot_id, scope, context_id_1, context_id_2)
    ''');

    _initialized = true;
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async {
    await init();
    final result = <String, dynamic>{};

    final stmt = _db.prepare('SELECT key, value_raw, value_type FROM variables WHERE bot_id = ? AND scope = ?');
    final rows = stmt.select([botId, '_global_']);

    for (final row in rows) {
      final key = row['key'] as String;
      final value = _deserializeValue(
        row['value_raw'] as String,
        row['value_type'] as String,
      );
      result[key] = value;
    }
    stmt.dispose();

    return result;
  }

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async {
    await init();

    final stmt = _db.prepare('SELECT value_raw, value_type FROM variables WHERE bot_id = ? AND scope = ? AND context_id_1 = ? AND key = ? LIMIT 1');
    final rows = stmt.select([botId, '_global_', '', key]);

    if (rows.isEmpty) {
      stmt.dispose();
      return null;
    }

    final row = rows[0];
    final value = _deserializeValue(
      row['value_raw'] as String,
      row['value_type'] as String,
    );
    stmt.dispose();

    return value;
  }

  @override
  Future<void> setGlobalVariable(String botId, String key, dynamic value) async {
    await init();
    final (valueRaw, valueType) = _serializeValue(value);
    final now = DateTime.now().millisecondsSinceEpoch;

    final stmt = _db.prepare('''
      INSERT INTO variables (bot_id, scope, context_id_1, context_id_2, key, value_raw, value_type, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(bot_id, scope, context_id_1, context_id_2, key) DO UPDATE SET
        value_raw = excluded.value_raw,
        value_type = excluded.value_type,
        updated_at = excluded.updated_at
    ''');
    stmt.execute([botId, '_global_', '', null, key, valueRaw, valueType, now, now]);
    stmt.dispose();
  }

  @override
  Future<void> renameGlobalVariable(String botId, String oldKey, String newKey) async {
    await init();
    final now = DateTime.now().millisecondsSinceEpoch;

    final stmt = _db.prepare('UPDATE variables SET key = ?, updated_at = ? WHERE bot_id = ? AND scope = ? AND key = ?');
    stmt.execute([newKey, now, botId, '_global_', oldKey]);
    stmt.dispose();
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
    await init();

    final stmt = _db.prepare('DELETE FROM variables WHERE bot_id = ? AND scope = ? AND key = ?');
    stmt.execute([botId, '_global_', key]);
    stmt.dispose();
  }

  @override
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  ) async {
    await init();
    final (ctx1, ctx2) = _parseContextId(scope, contextId);
    final result = <String, dynamic>{};

    final stmt = _db.prepare('SELECT key, value_raw, value_type FROM variables WHERE bot_id = ? AND scope = ? AND context_id_1 = ? AND context_id_2 IS ?');
    final rows = stmt.select([botId, scope, ctx1, ctx2]);

    for (final row in rows) {
      final key = row['key'] as String;
      final value = _deserializeValue(
        row['value_raw'] as String,
        row['value_type'] as String,
      );
      result[key] = value;
    }
    stmt.dispose();

    return result;
  }

  @override
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    await init();
    final (ctx1, ctx2) = _parseContextId(scope, contextId);

    final stmt = _db.prepare('SELECT value_raw, value_type FROM variables WHERE bot_id = ? AND scope = ? AND context_id_1 = ? AND context_id_2 IS ? AND key = ? LIMIT 1');
    final rows = stmt.select([botId, scope, ctx1, ctx2, key]);

    if (rows.isEmpty) {
      stmt.dispose();
      return null;
    }

    final row = rows[0];
    final value = _deserializeValue(
      row['value_raw'] as String,
      row['value_type'] as String,
    );
    stmt.dispose();

    return value;
  }

  @override
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value,
  ) async {
    await init();
    final (ctx1, ctx2) = _parseContextId(scope, contextId);
    final (valueRaw, valueType) = _serializeValue(value);
    final now = DateTime.now().millisecondsSinceEpoch;

    final stmt = _db.prepare('''
      INSERT INTO variables (bot_id, scope, context_id_1, context_id_2, key, value_raw, value_type, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(bot_id, scope, context_id_1, context_id_2, key) DO UPDATE SET
        value_raw = excluded.value_raw,
        value_type = excluded.value_type,
        updated_at = excluded.updated_at
    ''');
    stmt.execute([botId, scope, ctx1, ctx2, key, valueRaw, valueType, now, now]);
    stmt.dispose();
  }

  @override
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) async {
    await init();
    final (ctx1, ctx2) = _parseContextId(scope, contextId);
    final now = DateTime.now().millisecondsSinceEpoch;

    final stmt = _db.prepare('UPDATE variables SET key = ?, updated_at = ? WHERE bot_id = ? AND scope = ? AND context_id_1 = ? AND context_id_2 IS ? AND key = ?');
    stmt.execute([newKey, now, botId, scope, ctx1, ctx2, oldKey]);
    stmt.dispose();
  }

  @override
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    await init();
    final (ctx1, ctx2) = _parseContextId(scope, contextId);

    final stmt = _db.prepare('DELETE FROM variables WHERE bot_id = ? AND scope = ? AND context_id_1 = ? AND context_id_2 IS ? AND key = ?');
    stmt.execute([botId, scope, ctx1, ctx2, key]);
    stmt.dispose();
  }

  @override
  Future<List<String>> listContextIds(String botId, String scope, {String? searchKey}) async {
    await init();

    final stmt = _db.prepare('SELECT DISTINCT context_id_1 FROM variables WHERE bot_id = ? AND scope = ? AND context_id_1 != \'\'');
    final rows = stmt.select([botId, scope]);

    final contextIds = rows
        .map((row) => (row['context_id_1'] ?? '') as String)
        .where((id) => id.isNotEmpty)
        .toList();

    stmt.dispose();

    return contextIds;
  }

  @override
  Future<void> deleteAllForBot(String botId) async {
    await init();

    final stmt = _db.prepare('DELETE FROM variables WHERE bot_id = ?');
    stmt.execute([botId]);
    stmt.dispose();
  }

  /// Close database connection (call on runner shutdown).
  void close() {
    if (_initialized) {
      _db.dispose();
      _initialized = false;
    }
  }

  // ===== HELPERS =====

  /// Parse contextId into (context_id_1, context_id_2).
  /// guildMember scope uses "{guildId}:{userId}" format.
  (String, String?) _parseContextId(String scope, String contextId) {
    if (scope == 'guildMember') {
      final parts = contextId.split(':');
      return (parts[0], parts.length > 1 ? parts[1] : null);
    }
    return (contextId, null);
  }

  /// Serialize dynamic value to (string, type).
  (String, String) _serializeValue(dynamic value) {
    if (value is num) {
      return (value.toString(), 'number');
    }
    if (value is String) {
      final numValue = num.tryParse(value);
      if (numValue != null) {
        return (value, 'number');
      }
      return (value, 'string');
    }
    return (value.toString(), 'string');
  }

  /// Deserialize value from (string, type).
  dynamic _deserializeValue(String valueRaw, String valueType) {
    if (valueType == 'number') {
      return num.tryParse(valueRaw) ?? valueRaw;
    }
    return valueRaw;
  }
}
