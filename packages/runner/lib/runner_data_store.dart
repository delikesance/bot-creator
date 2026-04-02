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
  static final Map<String, JsonVariableStore> _fallbackStoresByDir =
      <String, JsonVariableStore>{};

  final String botId;
  final List<Map<String, dynamic>> _workflows;
  final Map<String, dynamic> _seedGlobalVariables;
  final Map<String, Map<String, Map<String, dynamic>>> _seedScopedVariables;
  final List<Map<String, dynamic>> _scopedVariableDefinitions;
  final String _variablesDir;
  late JsonVariableStore _jsonFallbackStore;
  SqliteCliVariableStore? _sqliteStore;
  Future<void>? _initStoreFuture;
  final Set<String> _seededBotIds = <String>{};

  RunnerDataStore(BotConfig config)
    : botId = 'runner',
      _workflows = List<Map<String, dynamic>>.from(config.workflows),
      _seedGlobalVariables = Map<String, dynamic>.from(config.globalVariables),
      _seedScopedVariables = _cloneScopedVariables(config.scopedVariables),
      _scopedVariableDefinitions = List<Map<String, dynamic>>.from(
        config.scopedVariableDefinitions,
      ),
      _variablesDir = _resolveRunnerVariablesDirStatic() {
    // JSON fallback remains available if SQLite fails to initialize.
    _jsonFallbackStore = _fallbackStoresByDir.putIfAbsent(
      _variablesDir,
      () => JsonVariableStore.fromMaps(
        globalVariables: _seedGlobalVariables,
        scopedVariables: _seedScopedVariables,
      ),
    );

    _initStoreFuture = _initializePrimaryStore();
  }

  Future<void> _initializePrimaryStore() async {
    try {
      _sqliteStore = SqliteCliVariableStore(_variablesDir);
      await _sqliteStore!.init();
    } catch (_) {
      _sqliteStore = null;
    }
  }

  static String _resolveRunnerVariablesDirStatic() {
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

    if (await sqlite.hasAnyVariablesForBot(botId)) {
      _seededBotIds.add(botId);
      return;
    }

    for (final entry in _seedGlobalVariables.entries) {
      await sqlite.setGlobalVariable(botId, entry.key, entry.value);
    }

    for (final scopeEntry in _seedScopedVariables.entries) {
      final scope = scopeEntry.key;
      for (final contextEntry in scopeEntry.value.entries) {
        final contextId = contextEntry.key;
        for (final valueEntry in contextEntry.value.entries) {
          await sqlite.setScopedVariable(
            botId,
            scope,
            contextId,
            valueEntry.key,
            valueEntry.value,
          );
        }
      }
    }

    _seededBotIds.add(botId);
  }

  Future<void> dispose() async {
    _sqliteStore?.dispose();
    _sqliteStore = null;
    _seededBotIds.clear();
  }

  @override
  Future<List<Map<String, dynamic>>> getScopedVariableDefinitions(
    String botId,
  ) async {
    return _scopedVariableDefinitions
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  @override
  Future<void> setScopedVariableDefinition(
    String botId,
    String key,
    String scope,
    dynamic defaultValue, {
    String valueType = 'string',
  }) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    final normalizedScope = scope.trim();
    if (normalizedScope.isEmpty) {
      return;
    }

    final entry = <String, dynamic>{
      'key': normalizedKey,
      'scope': normalizedScope,
      'defaultValue': defaultValue,
      'valueType': valueType,
    };

    final idx = _scopedVariableDefinitions.indexWhere(
      (existing) =>
          (existing['key'] ?? '').toString().trim() == normalizedKey &&
          (existing['scope'] ?? '').toString().trim() == normalizedScope,
    );

    if (idx >= 0) {
      _scopedVariableDefinitions[idx] = entry;
    } else {
      _scopedVariableDefinitions.add(entry);
    }
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async =>
      await (await _storeForBot(botId)).getGlobalVariables(botId);

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async =>
      await (await _storeForBot(botId)).getGlobalVariable(botId, key);

  @override
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value,
  ) async {
    await (await _storeForBot(botId)).setGlobalVariable(botId, key, value);
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) async {
    await (await _storeForBot(
      botId,
    )).renameGlobalVariable(botId, oldKey, newKey);
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
    await (await _storeForBot(botId)).removeGlobalVariable(botId, key);
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

  /// Replaces the in-memory workflow list without recreating the store.
  ///
  /// Called by [DiscordRunner.reloadConfig] so that workflow lookups
  /// immediately use the updated configuration without a full bot restart.
  void updateWorkflows(List<Map<String, dynamic>> workflows) {
    _workflows
      ..clear()
      ..addAll(workflows);
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

Map<String, Map<String, Map<String, dynamic>>> _cloneScopedVariables(
  Map<String, Map<String, Map<String, dynamic>>> source,
) {
  final cloned = <String, Map<String, Map<String, dynamic>>>{};
  for (final scopeEntry in source.entries) {
    cloned[scopeEntry.key] = <String, Map<String, dynamic>>{};
    for (final contextEntry in scopeEntry.value.entries) {
      cloned[scopeEntry.key]![contextEntry.key] = Map<String, dynamic>.from(
        contextEntry.value,
      );
    }
  }
  return cloned;
}
