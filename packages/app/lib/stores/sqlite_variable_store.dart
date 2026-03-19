import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:bot_creator_shared/bot/variable_database.dart';

/// SQLite implementation of [VariableDatabase] using sqflite (Flutter apps).
/// Supports Windows, Mac, Linux, iOS, Android.
///
/// Schema:
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
///   CHECK(scope IN ('_global_', 'guild', 'user', 'channel', 'guildMember', 'message'))
/// );
/// CREATE INDEX idx_bot_lookup ON variables(bot_id, scope, context_id_1, context_id_2);
/// ```
class SqliteVariableStore implements VariableDatabase {
  late Database _db;
  bool _initialized = false;
  static bool _ffiInitialized = false;

  SqliteVariableStore();

  /// Initialize database connection and create schema if needed.
  Future<void> init() async {
    if (_initialized) return;

    // sqflite on desktop requires explicit FFI initialization.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      if (!_ffiInitialized) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        _ffiInitialized = true;
      }
    }

    // Determine database path
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docsDir.path, 'databases', 'variables.db');

    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateSchemaToV2(db);
        }
      },
    );

    _initialized = true;
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE variables (
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
        CHECK(scope IN ('_global_', 'guild', 'user', 'channel', 'guildMember', 'message'))
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bot_lookup ON variables(bot_id, scope, context_id_1, context_id_2)',
    );
  }

  Future<void> _migrateSchemaToV2(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE variables_v2 (
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
        CHECK(scope IN ('_global_', 'guild', 'user', 'channel', 'guildMember', 'message'))
      )
    ''');

    await db.execute('''
      INSERT INTO variables_v2 (
        id, bot_id, scope, context_id_1, context_id_2, key, value_raw, value_type, created_at, updated_at
      )
      SELECT
        id, bot_id, scope, context_id_1, context_id_2, key, value_raw, value_type, created_at, updated_at
      FROM variables
      WHERE scope IN ('_global_', 'guild', 'user', 'channel', 'guildMember', 'message')
    ''');

    await db.execute('DROP TABLE variables');
    await db.execute('ALTER TABLE variables_v2 RENAME TO variables');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bot_lookup ON variables(bot_id, scope, context_id_1, context_id_2)',
    );
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async {
    await init();
    final rows = await _db.query(
      'variables',
      where: 'bot_id = ? AND scope = ?',
      whereArgs: [botId, '_global_'],
    );

    final result = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'] as String;
      final value = _deserializeValue(
        row['value_raw'] as String,
        row['value_type'] as String,
      );
      result[key] = value;
    }
    return result;
  }

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async {
    await init();
    final rows = await _db.query(
      'variables',
      where: 'bot_id = ? AND scope = ? AND context_id_1 = ? AND key = ?',
      whereArgs: [botId, '_global_', '', key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _deserializeValue(
      rows[0]['value_raw'] as String,
      rows[0]['value_type'] as String,
    );
  }

  @override
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value,
  ) async {
    await init();
    final (valueRaw, valueType) = _serializeValue(value);
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.insert('variables', {
      'bot_id': botId,
      'scope': '_global_',
      'context_id_1': '',
      'context_id_2': null,
      'key': key,
      'value_raw': valueRaw,
      'value_type': valueType,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) async {
    await init();
    final row = await _db.query(
      'variables',
      where: 'bot_id = ? AND scope = ? AND key = ?',
      whereArgs: [botId, '_global_', oldKey],
      limit: 1,
    );

    if (row.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'variables',
      {'key': newKey, 'updated_at': now},
      where: 'bot_id = ? AND scope = ? AND key = ?',
      whereArgs: [botId, '_global_', oldKey],
    );
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
    await init();
    await _db.delete(
      'variables',
      where: 'bot_id = ? AND scope = ? AND key = ?',
      whereArgs: [botId, '_global_', key],
    );
  }

  @override
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  ) async {
    await init();
    final (ctx1, ctx2) = _parseContextId(scope, contextId);

    final rows = await _db.query(
      'variables',
      where:
          'bot_id = ? AND scope = ? AND context_id_1 = ? AND context_id_2 IS ?',
      whereArgs: [botId, scope, ctx1, ctx2],
    );

    final result = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'] as String;
      final value = _deserializeValue(
        row['value_raw'] as String,
        row['value_type'] as String,
      );
      result[key] = value;
    }
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

    final rows = await _db.query(
      'variables',
      where:
          'bot_id = ? AND scope = ? AND context_id_1 = ? AND context_id_2 IS ? AND key = ?',
      whereArgs: [botId, scope, ctx1, ctx2, key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _deserializeValue(
      rows[0]['value_raw'] as String,
      rows[0]['value_type'] as String,
    );
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

    await _db.insert('variables', {
      'bot_id': botId,
      'scope': scope,
      'context_id_1': ctx1,
      'context_id_2': ctx2,
      'key': key,
      'value_raw': valueRaw,
      'value_type': valueType,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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

    await _db.update(
      'variables',
      {'key': newKey, 'updated_at': now},
      where:
          'bot_id = ? AND scope = ? AND context_id_1 = ? AND context_id_2 IS ? AND key = ?',
      whereArgs: [botId, scope, ctx1, ctx2, oldKey],
    );
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

    await _db.delete(
      'variables',
      where:
          'bot_id = ? AND scope = ? AND context_id_1 = ? AND context_id_2 IS ? AND key = ?',
      whereArgs: [botId, scope, ctx1, ctx2, key],
    );
  }

  @override
  Future<List<String>> listContextIds(
    String botId,
    String scope, {
    String? searchKey,
  }) async {
    await init();
    final whereClauses = <String>['bot_id = ?', 'scope = ?'];
    final args = <Object?>[botId, scope];

    final trimmedSearchKey = searchKey?.trim() ?? '';
    if (trimmedSearchKey.isNotEmpty) {
      whereClauses.add('key = ?');
      args.add(trimmedSearchKey);
    }

    final where = whereClauses.join(' AND ');
    if (scope == 'guildMember') {
      final rows = await _db.rawQuery(
        'SELECT DISTINCT context_id_1, context_id_2 FROM variables WHERE $where',
        args,
      );
      return rows
          .map((row) {
            final ctx1 = (row['context_id_1'] ?? '').toString();
            final ctx2 = (row['context_id_2'] ?? '').toString();
            if (ctx1.isEmpty) {
              return '';
            }
            return ctx2.isEmpty ? ctx1 : '$ctx1:$ctx2';
          })
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
    }

    final rows = await _db.rawQuery(
      'SELECT DISTINCT context_id_1 FROM variables WHERE $where',
      args,
    );
    return rows
        .map((row) => (row['context_id_1'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> deleteAllForBot(String botId) async {
    await init();
    await _db.delete('variables', where: 'bot_id = ?', whereArgs: [botId]);
  }

  /// Close database connection (call on app cleanup).
  Future<void> close() async {
    if (_initialized) {
      await _db.close();
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

  /// Serialize dynamic value to (JSON string, type).
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

  /// Deserialize value from (JSON string, type).
  dynamic _deserializeValue(String valueRaw, String valueType) {
    if (valueType == 'number') {
      return num.tryParse(valueRaw) ?? valueRaw;
    }
    return valueRaw;
  }
}
