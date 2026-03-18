import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/utils/workflow_call.dart';

import 'package:bot_creator_shared/bot/json_variable_store.dart';

/// In-memory implementation of [BotDataStore] backed by a [BotConfig].
///
/// Global variables are mutable at runtime (actions can set/remove them).
/// Workflows are read from the config.
class RunnerDataStore implements BotDataStore {
  final String botId;
  final List<Map<String, dynamic>> _workflows;
  late JsonVariableStore _variableStore;

  RunnerDataStore(BotConfig config)
    : botId = 'runner',
      _workflows = List<Map<String, dynamic>>.from(config.workflows) {
    // Initialize variable store from config
    _variableStore = JsonVariableStore.fromMaps(
      globalVariables: config.globalVariables,
      scopedVariables: config.scopedVariables,
    );
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async =>
     await _variableStore.getGlobalVariables(botId);

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async =>
     await _variableStore.getGlobalVariable(botId, key);

  @override
  Future<void> setGlobalVariable(String botId, String key, dynamic value) async {
     await _variableStore.setGlobalVariable(botId, key, value);
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
    ) async {
      await _variableStore.renameGlobalVariable(botId, oldKey, newKey);
    }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
     await _variableStore.removeGlobalVariable(botId, key);
  }

  @override
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
    ) async {
      return await _variableStore.getScopedVariables(botId, scope, contextId);
  }

  @override
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    ) async {
      return await _variableStore.getScopedVariable(botId, scope, contextId, key);
  }

  @override
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value,
    ) async {
      await _variableStore.setScopedVariable(botId, scope, contextId, key, value);
  }

  @override
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
    ) async {
      await _variableStore.renameScopedVariable(botId, scope, contextId, oldKey, newKey);
  }

  @override
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    ) async {
      await _variableStore.removeScopedVariable(botId, scope, contextId, key);
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

