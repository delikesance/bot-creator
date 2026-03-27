import 'dart:convert';

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
      version: 3,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateSchemaToV2(db);
        }
        if (oldVersion < 3) {
          await _ensureSecondaryIndexes(db);
        }
      },
    );

    await _ensureSecondaryIndexes(_db);

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
    await _ensureSecondaryIndexes(db);
  }

  Future<void> _ensureSecondaryIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_scope_key_lookup ON variables(bot_id, scope, key)',
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
      where: _scopedContextWhereClause(includeKey: false),
      whereArgs: _scopedContextWhereArgs(
        botId: botId,
        scope: scope,
        ctx1: ctx1,
        ctx2: ctx2,
      ),
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
      where: _scopedContextWhereClause(includeKey: true),
      whereArgs: _scopedContextWhereArgs(
        botId: botId,
        scope: scope,
        ctx1: ctx1,
        ctx2: ctx2,
        key: key,
      ),
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
      where: _scopedContextWhereClause(includeKey: true),
      whereArgs: _scopedContextWhereArgs(
        botId: botId,
        scope: scope,
        ctx1: ctx1,
        ctx2: ctx2,
        key: oldKey,
      ),
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
      where: _scopedContextWhereClause(includeKey: true),
      whereArgs: _scopedContextWhereArgs(
        botId: botId,
        scope: scope,
        ctx1: ctx1,
        ctx2: ctx2,
        key: key,
      ),
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
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  }) async {
    await init();
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit.clamp(1, 25);

    final rows = await _db.query(
      'variables',
      columns: [
        'context_id_1',
        'context_id_2',
        'key',
        'value_raw',
        'value_type',
      ],
      where: 'bot_id = ? AND scope = ? AND key = ?',
      whereArgs: [botId, scope, key],
    );

    final items = rows
        .map((row) {
          final contextId =
              scope == 'guildMember'
                  ? _composeGuildMemberContextId(
                    (row['context_id_1'] ?? '').toString(),
                    (row['context_id_2'] ?? '').toString(),
                  )
                  : (row['context_id_1'] ?? '').toString();
          return <String, dynamic>{
            'contextId': contextId,
            'key': (row['key'] ?? '').toString(),
            'value': _deserializeValue(
              (row['value_raw'] ?? '').toString(),
              (row['value_type'] ?? 'string').toString(),
            ),
          };
        })
        .where((entry) => (entry['contextId'] ?? '').toString().isNotEmpty)
        .toList(growable: false);

    final sorted = items.toList(growable: true)..sort(
      (a, b) => _compareVariableValues(a['value'], b['value'], descending),
    );

    final total = sorted.length;
    final end =
        (safeOffset + safeLimit) > total ? total : (safeOffset + safeLimit);
    final paged =
        safeOffset >= total
            ? const <Map<String, dynamic>>[]
            : sorted.sublist(safeOffset, end);

    return <String, dynamic>{
      'items': paged,
      'count': paged.length,
      'total': total,
    };
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

  String _scopedContextWhereClause({required bool includeKey}) {
    final keyClause = includeKey ? ' AND key = ?' : '';
    return 'bot_id = ? AND scope = ? AND context_id_1 = ? AND '
        '((? = 1 AND context_id_2 IS NULL) OR context_id_2 = ?)$keyClause';
  }

  List<Object?> _scopedContextWhereArgs({
    required String botId,
    required String scope,
    required String ctx1,
    required String? ctx2,
    String? key,
  }) {
    return <Object?>[
      botId,
      scope,
      ctx1,
      ctx2 == null ? 1 : 0,
      ctx2 ?? '',
      if (key != null) key,
    ];
  }

  /// Serialize dynamic value to (JSON string, type).
  (String, String) _serializeValue(dynamic value) {
    final normalized = _normalizeVariableValue(value);
    if (normalized == null) {
      return ('null', 'null');
    }
    if (normalized is bool) {
      return (normalized.toString(), 'bool');
    }
    if (normalized is List || normalized is Map<String, dynamic>) {
      return (jsonEncode(normalized), 'json');
    }
    if (normalized is num) {
      return (normalized.toString(), 'number');
    }
    if (normalized is String) {
      return (normalized, 'string');
    }
    return (normalized.toString(), 'string');
  }

  /// Deserialize value from (JSON string, type).
  dynamic _deserializeValue(String valueRaw, String valueType) {
    if (valueType == 'number') {
      return num.tryParse(valueRaw) ?? valueRaw;
    }
    if (valueType == 'bool') {
      return valueRaw.toLowerCase() == 'true';
    }
    if (valueType == 'null') {
      return null;
    }
    if (valueType == 'json') {
      try {
        return _normalizeVariableValue(jsonDecode(valueRaw));
      } catch (_) {
        return valueRaw;
      }
    }
    return valueRaw;
  }

  dynamic _normalizeVariableValue(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is List) {
      return value.map(_normalizeVariableValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, value) =>
            MapEntry(key.toString(), _normalizeVariableValue(value)),
      );
    }
    return value.toString();
  }

  @override
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic element,
  ) async {
    await init();
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current) ?? [];
    list.add(element);
    await setScopedVariable(botId, scope, contextId, key, list);
  }

  @override
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    await init();
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current);
    if (list == null || list.isEmpty) {
      return null;
    }
    final popped = list.removeLast();
    await setScopedVariable(botId, scope, contextId, key, list);
    return popped;
  }

  @override
  Future<dynamic> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    await init();
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current);
    if (list == null || index < 0 || index >= list.length) {
      return null;
    }
    final removed = list.removeAt(index);
    await setScopedVariable(botId, scope, contextId, key, list);
    return removed;
  }

  @override
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    await init();
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current);
    if (list == null || index < 0 || index >= list.length) {
      return null;
    }
    return list[index];
  }

  @override
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    await init();
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current);
    return list?.length ?? 0;
  }

  @override
  Future<Map<String, dynamic>> queryScopedArray(
    String botId,
    String scope,
    String contextId,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
    String? filter,
  }) async {
    await init();
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current) ?? [];

    // Apply filter
    List<dynamic> filtered = list;
    if (filter != null && filter.trim().isNotEmpty) {
      filtered = _applyArrayFilter(list, filter.trim());
    }

    // Sort
    filtered.sort((a, b) => _compareVariableValues(a, b, descending));

    // Paginate
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit < 1 ? 1 : (limit > 25 ? 25 : limit);
    final start = safeOffset;
    final end = (safeOffset + safeLimit).clamp(0, filtered.length);
    final items = filtered.sublist(start, end);

    return {'items': items, 'count': items.length, 'total': filtered.length};
  }

  List<dynamic> _applyArrayFilter(List<dynamic> list, String filter) {
    if (filter.isEmpty) return list;

    final result = <dynamic>[];
    for (final item in list) {
      if (_matchesArrayFilter(item, filter)) {
        result.add(item);
      }
    }
    return result;
  }

  bool _matchesArrayFilter(dynamic item, String filter) {
    // Parse filter: "> 100", "< 50", "== 42", "contains abc"
    if (filter.startsWith('> ')) {
      final value = num.tryParse(filter.substring(2));
      if (value == null || item is! num) return false;
      return item > value;
    }
    if (filter.startsWith('< ')) {
      final value = num.tryParse(filter.substring(2));
      if (value == null || item is! num) return false;
      return item < value;
    }
    if (filter.startsWith('>= ')) {
      final value = num.tryParse(filter.substring(3));
      if (value == null || item is! num) return false;
      return item >= value;
    }
    if (filter.startsWith('<= ')) {
      final value = num.tryParse(filter.substring(3));
      if (value == null || item is! num) return false;
      return item <= value;
    }
    if (filter.startsWith('== ')) {
      final valueStr = filter.substring(3);
      if (item is String) return item == valueStr;
      final value = num.tryParse(valueStr);
      if (value == null) return false;
      return item == value;
    }
    if (filter.startsWith('contains ')) {
      final search = filter.substring(9);
      return item.toString().toLowerCase().contains(search.toLowerCase());
    }
    return false;
  }

  List<dynamic>? _toList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    return null;
  }

  int _compareVariableValues(dynamic left, dynamic right, bool descending) {
    final normalized = _compareNormalized(left, right);
    return descending ? -normalized : normalized;
  }

  int _compareNormalized(dynamic left, dynamic right) {
    if (left is num && right is num) {
      return left.compareTo(right);
    }
    if (left is bool && right is bool) {
      return (left ? 1 : 0).compareTo(right ? 1 : 0);
    }
    final leftText = _valueToComparableString(left);
    final rightText = _valueToComparableString(right);
    final byValue = leftText.compareTo(rightText);
    if (byValue != 0) {
      return byValue;
    }
    return 0;
  }

  String _valueToComparableString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.toLowerCase();
    if (value is List || value is Map) return jsonEncode(value).toLowerCase();
    return value.toString().toLowerCase();
  }

  String _composeGuildMemberContextId(String ctx1, String ctx2) {
    if (ctx1.isEmpty) {
      return '';
    }
    return ctx2.isEmpty ? ctx1 : '$ctx1:$ctx2';
  }
}
