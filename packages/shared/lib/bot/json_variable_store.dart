import 'variable_database.dart';

/// In-memory implementation of [VariableDatabase] backed by Dart Maps.
/// No persistence — used for runtime or fallback storage.
/// Suitable for: CLI runner (ZIP config source), app fallback when SQLite unavailable.
class JsonVariableStore implements VariableDatabase {
  final Map<String, dynamic> _globalVariables = {};
  final Map<String, Map<String, Map<String, dynamic>>> _scopedVariables = {};

  JsonVariableStore();

  /// Initialize from existing maps (e.g., from BotConfig or JSON file).
  JsonVariableStore.fromMaps({
    Map<String, dynamic>? globalVariables,
    Map<String, Map<String, Map<String, dynamic>>>? scopedVariables,
  }) {
    if (globalVariables != null) {
      _globalVariables.addAll(globalVariables);
    }
    if (scopedVariables != null) {
      for (final scope in scopedVariables.entries) {
        final byId = <String, Map<String, dynamic>>{};
        for (final id in scope.value.entries) {
          byId[id.key] = Map<String, dynamic>.from(id.value);
        }
        _scopedVariables[scope.key] = byId;
      }
    }
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async =>
      Map<String, dynamic>.from(_globalVariables);

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async =>
      _globalVariables[key];

  @override
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value,
  ) async {
    _globalVariables[key] = _normalizeVariableValue(value);
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) async {
    if (!_globalVariables.containsKey(oldKey)) {
      return;
    }
    final value = _globalVariables.remove(oldKey);
    _globalVariables[newKey] = value;
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
    _globalVariables.remove(key);
  }

  @override
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  ) async {
    final byScope =
        _scopedVariables[scope] ?? const <String, Map<String, dynamic>>{};
    final values = byScope[contextId] ?? const <String, dynamic>{};
    return Map<String, dynamic>.from(values);
  }

  @override
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    final values = await getScopedVariables(botId, scope, contextId);
    return values[key];
  }

  @override
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value,
  ) async {
    final byScope = _scopedVariables.putIfAbsent(
      scope,
      () => <String, Map<String, dynamic>>{},
    );
    final byId = byScope.putIfAbsent(contextId, () => <String, dynamic>{});
    byId[key] = _normalizeVariableValue(value);
  }

  @override
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) async {
    final byScope = _scopedVariables[scope];
    final byId = byScope?[contextId];
    if (byId == null || !byId.containsKey(oldKey)) {
      return;
    }
    final value = byId.remove(oldKey);
    byId[newKey] = value;
  }

  @override
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    final byScope = _scopedVariables[scope];
    final byId = byScope?[contextId];
    if (byId == null) {
      return;
    }
    byId.remove(key);
  }

  @override
  Future<List<String>> listContextIds(
    String botId,
    String scope, {
    String? searchKey,
  }) async {
    final byScope = _scopedVariables[scope];
    if (byScope == null) return [];

    final contextIds =
        byScope.entries
            .where((entry) {
              if (searchKey == null) return true;
              // Check if any key in this context starts with searchKey
              return entry.value.keys.any((k) => k.startsWith(searchKey));
            })
            .map((e) => e.key)
            .toList();

    return contextIds;
  }

  @override
  Future<void> deleteAllForBot(String botId) async {
    _globalVariables.clear();
    _scopedVariables.clear();
  }

  /// Normalize variable value: preserve numbers, coerce others to strings.
  static dynamic _normalizeVariableValue(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final numValue = num.tryParse(value);
      return numValue ?? value;
    }
    if (value == null) return '';
    return value.toString();
  }

  /// Export current state as maps (for JSON serialization, backup, etc).
  Map<String, dynamic> exportGlobalVariables() =>
      Map<String, dynamic>.from(_globalVariables);

  Map<String, Map<String, Map<String, dynamic>>> exportScopedVariables() {
    final export = <String, Map<String, Map<String, dynamic>>>{};
    for (final scope in _scopedVariables.entries) {
      final byId = <String, Map<String, dynamic>>{};
      for (final id in scope.value.entries) {
        byId[id.key] = Map<String, dynamic>.from(id.value);
      }
      export[scope.key] = byId;
    }
    return export;
  }
}
