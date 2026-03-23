import 'dart:convert';
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
///   CHECK(scope IN ('_global_', 'guild', 'user', 'channel', 'guildMember', 'message'))
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
        CHECK(scope IN ('_global_', 'guild', 'user', 'channel', 'guildMember', 'message'))
      )
    ''');

    // Create index if not exists
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_bot_lookup 
      ON variables(bot_id, scope, context_id_1, context_id_2)
    ''');
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_scope_key_lookup
      ON variables(bot_id, scope, key)
    ''');

    await _migrateScopeConstraintIfNeeded();

    _initialized = true;
  }

  Future<void> _migrateScopeConstraintIfNeeded() async {
    final stmt = _db.prepare(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'variables' LIMIT 1",
    );
    final rows = stmt.select();
    stmt.dispose();

    if (rows.isEmpty) {
      return;
    }

    final sql = (rows.first['sql'] as String?) ?? '';
    if (sql.contains("'_global_'") || sql.contains('"_global_"')) {
      return;
    }

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('''
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

      _db.execute('''
        INSERT INTO variables_v2 (
          id, bot_id, scope, context_id_1, context_id_2, key, value_raw, value_type, created_at, updated_at
        )
        SELECT
          id, bot_id, scope, context_id_1, context_id_2, key, value_raw, value_type, created_at, updated_at
        FROM variables
        WHERE scope IN ('_global_', 'guild', 'user', 'channel', 'guildMember', 'message')
      ''');

      _db.execute('DROP TABLE variables');
      _db.execute('ALTER TABLE variables_v2 RENAME TO variables');
      _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_bot_lookup
        ON variables(bot_id, scope, context_id_1, context_id_2)
      ''');

      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async {
    await init();
    final result = <String, dynamic>{};

    final stmt = _db.prepare(
      'SELECT key, value_raw, value_type FROM variables WHERE bot_id = ? AND scope = ?',
    );
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

    final stmt = _db.prepare(
      'SELECT value_raw, value_type FROM variables WHERE bot_id = ? AND scope = ? AND context_id_1 = ? AND key = ? LIMIT 1',
    );
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
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value,
  ) async {
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
    stmt.execute([
      botId,
      '_global_',
      '',
      null,
      key,
      valueRaw,
      valueType,
      now,
      now,
    ]);
    stmt.dispose();
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) async {
    await init();
    final now = DateTime.now().millisecondsSinceEpoch;

    final stmt = _db.prepare(
      'UPDATE variables SET key = ?, updated_at = ? WHERE bot_id = ? AND scope = ? AND key = ?',
    );
    stmt.execute([newKey, now, botId, '_global_', oldKey]);
    stmt.dispose();
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
    await init();

    final stmt = _db.prepare(
      'DELETE FROM variables WHERE bot_id = ? AND scope = ? AND key = ?',
    );
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

    final stmt = _db.prepare(
      'SELECT key, value_raw, value_type FROM variables WHERE ${_scopedContextWhereClause(includeKey: false)}',
    );
    final rows = stmt.select(
      _scopedContextWhereArgs(
        botId: botId,
        scope: scope,
        ctx1: ctx1,
        ctx2: ctx2,
      ),
    );

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

    final stmt = _db.prepare(
      'SELECT value_raw, value_type FROM variables WHERE ${_scopedContextWhereClause(includeKey: true)} LIMIT 1',
    );
    final rows = stmt.select(
      _scopedContextWhereArgs(
        botId: botId,
        scope: scope,
        ctx1: ctx1,
        ctx2: ctx2,
        key: key,
      ),
    );

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
    stmt.execute([
      botId,
      scope,
      ctx1,
      ctx2,
      key,
      valueRaw,
      valueType,
      now,
      now,
    ]);
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

    final stmt = _db.prepare(
      'UPDATE variables SET key = ?, updated_at = ? WHERE ${_scopedContextWhereClause(includeKey: true)}',
    );
    stmt.execute([
      newKey,
      now,
      ..._scopedContextWhereArgs(
        botId: botId,
        scope: scope,
        ctx1: ctx1,
        ctx2: ctx2,
        key: oldKey,
      ),
    ]);
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

    final stmt = _db.prepare(
      'DELETE FROM variables WHERE ${_scopedContextWhereClause(includeKey: true)}',
    );
    stmt.execute(
      _scopedContextWhereArgs(
        botId: botId,
        scope: scope,
        ctx1: ctx1,
        ctx2: ctx2,
        key: key,
      ),
    );
    stmt.dispose();
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
      final stmt = _db.prepare(
        'SELECT DISTINCT context_id_1, context_id_2 FROM variables WHERE $where',
      );
      final rows = stmt.select(args);
      final contextIds = rows
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
      stmt.dispose();
      return contextIds;
    }

    final stmt = _db.prepare(
      'SELECT DISTINCT context_id_1 FROM variables WHERE $where AND context_id_1 != \'\'',
    );
    final rows = stmt.select(args);

    final contextIds = rows
        .map((row) => (row['context_id_1'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    stmt.dispose();

    return contextIds;
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

    final stmt = _db.prepare(
      'SELECT context_id_1, context_id_2, key, value_raw, value_type FROM variables WHERE bot_id = ? AND scope = ? AND key = ?',
    );
    final rows = stmt.select([botId, scope, key]);
    stmt.dispose();

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
      .toList(growable: true)..sort(
      (a, b) => _compareVariableValues(a['value'], b['value'], descending),
    );

    final total = items.length;
    final end =
        (safeOffset + safeLimit) > total ? total : (safeOffset + safeLimit);
    final paged =
        safeOffset >= total
            ? const <Map<String, dynamic>>[]
            : items.sublist(safeOffset, end);

    return <String, dynamic>{
      'items': paged,
      'count': paged.length,
      'total': total,
    };
  }

  @override
  Future<void> deleteAllForBot(String botId) async {
    await init();

    final stmt = _db.prepare('DELETE FROM variables WHERE bot_id = ?');
    stmt.execute([botId]);
    stmt.dispose();
  }

  /// dispose database connection (call on runner shutdown).
  void dispose() {
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

  /// Serialize dynamic value to (string, type).
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

  /// Deserialize value from (string, type).
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

  String _composeGuildMemberContextId(String ctx1, String ctx2) {
    if (ctx1.isEmpty) {
      return '';
    }
    return ctx2.isEmpty ? ctx1 : '$ctx1:$ctx2';
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
    return leftText.compareTo(rightText);
  }

  String _valueToComparableString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.toLowerCase();
    if (value is List || value is Map) return jsonEncode(value).toLowerCase();
    return value.toString().toLowerCase();
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
    if (value is List) return value;
    return null;
  }
}
