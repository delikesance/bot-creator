import 'dart:io';

import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/bot/variable_database.dart';
import 'package:bot_creator_shared/utils/workflow_call.dart';

import 'package:bot_creator_shared/bot/json_variable_store.dart';
import 'package:bot_creator_runner/stores/sqlite_cli_variable_store.dart';

/// In-memory implementation of [BotDataStore] backed by a [BotConfig].
///
/// Global variables are mutable at runtime (actions can set/remove them).
/// Workflows are read from the config.
class RunnerDataStore implements BotDataStore {
  final String botId;
  final List<Map<String, dynamic>> _workflows;
  late JsonVariableStore _jsonFallbackStore;
  SqliteCliVariableStore? _sqliteStore;
  Future<void>? _initStoreFuture;
  final Set<String> _seededBotIds = <String>{};

  RunnerDataStore(BotConfig config)
    : botId = 'runner',
      _workflows = List<Map<String, dynamic>>.from(config.workflows) {
    // JSON fallback remains available if SQLite fails to initialize.
    // Scoped runtime values must NOT be preloaded from config: they are
    // created by bot execution and then persisted in SQLite.
    _jsonFallbackStore = JsonVariableStore.fromMaps(
      globalVariables: config.globalVariables,
      scopedVariables: const <String, Map<String, Map<String, dynamic>>>{},
    );

    _initStoreFuture = _initializePrimaryStore();
  }

  Future<void> _initializePrimaryStore() async {
    try {
      _sqliteStore = SqliteCliVariableStore(_resolveRunnerVariablesDir());
      await _sqliteStore!.init();
    } catch (_) {
      _sqliteStore = null;
    }
  }

  String _resolveRunnerVariablesDir() {
    final configured =
        (Platform.environment['BOT_CREATOR_DATA_DIR'] ?? '').trim();
    if (configured.isNotEmpty) {
      return '$configured/variables';
    }
    return './data/variables';
  }

  Future<VariableDatabase> _storeForBot(String botId) async {
    if (_initStoreFuture != null) {
      await _initStoreFuture;
    }

    final sqlite = _sqliteStore;
    if (sqlite == null) {
      return _jsonFallbackStore;
    }

    await _seedSqliteForBotIfNeeded(botId, sqlite);
    return sqlite;
  }

  Future<void> _seedSqliteForBotIfNeeded(
    String botId,
    SqliteCliVariableStore sqlite,
  ) async {
    if (_seededBotIds.contains(botId)) {
      return;
    }

    _seededBotIds.add(botId);
  }

  Future<void> dispose() async {
    _sqliteStore?.dispose();
    _sqliteStore = null;
    _seededBotIds.clear();
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async =>
      await _jsonFallbackStore.getGlobalVariables(botId);

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async =>
      await _jsonFallbackStore.getGlobalVariable(botId, key);

  @override
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value,
  ) async {
    await _jsonFallbackStore.setGlobalVariable(botId, key, value);
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) async {
    await _jsonFallbackStore.renameGlobalVariable(botId, oldKey, newKey);
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
    await _jsonFallbackStore.removeGlobalVariable(botId, key);
  }

  @override
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  ) async {
    return await (await _storeForBot(
      botId,
    )).getScopedVariables(botId, scope, contextId);
  }

  @override
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    return await (await _storeForBot(
      botId,
    )).getScopedVariable(botId, scope, contextId, key);
  }

  @override
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value,
  ) async {
    await (await _storeForBot(
      botId,
    )).setScopedVariable(botId, scope, contextId, key, value);
  }

  @override
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) async {
    await (await _storeForBot(
      botId,
    )).renameScopedVariable(botId, scope, contextId, oldKey, newKey);
  }

  @override
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    await (await _storeForBot(
      botId,
    )).removeScopedVariable(botId, scope, contextId, key);
  }

  @override
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic element,
  ) async {
    await (await _storeForBot(
      botId,
    )).pushScopedArrayElement(botId, scope, contextId, key, element);
  }

  @override
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    return await (await _storeForBot(
      botId,
    )).popScopedArrayElement(botId, scope, contextId, key);
  }

  @override
  Future<dynamic> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    return await (await _storeForBot(
      botId,
    )).removeScopedArrayElement(botId, scope, contextId, key, index);
  }

  @override
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    return await (await _storeForBot(
      botId,
    )).getScopedArrayElement(botId, scope, contextId, key, index);
  }

  @override
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    return await (await _storeForBot(
      botId,
    )).getScopedArrayLength(botId, scope, contextId, key);
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
    return await (await _storeForBot(botId)).queryScopedArray(
      botId,
      scope,
      contextId,
      key,
      offset: offset,
      limit: limit,
      descending: descending,
      filter: filter,
    );
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
    return await (await _storeForBot(botId)).queryScopedVariableIndex(
      botId,
      scope,
      key,
      offset: offset,
      limit: limit,
      descending: descending,
    );
  }

  @override
  Future<Map<String, dynamic>?> getWorkflowByName(
    String botId,
    String name,
  ) async {
    final lower = name.toLowerCase();
    for (final w in _workflows) {
      if ((w['name'] ?? '').toString().toLowerCase() == lower) {
        return _normalizeWorkflow(Map<String, dynamic>.from(w));
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizeWorkflow(Map<String, dynamic> w) {
    return normalizeStoredWorkflowDefinition(w);
  }
}
