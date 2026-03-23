/// Abstract interface over bot data storage.
/// Both [AppManager] (Flutter app) and [RunnerDataStore] (CLI runner) implement this.
abstract class BotDataStore {
  /// Returns all global variables for [botId] with typed values (string|number).
  Future<Map<String, dynamic>> getGlobalVariables(String botId);

  /// Returns a single global variable value, or null if not set.
  Future<dynamic> getGlobalVariable(String botId, String key);

  /// Persists or updates a global variable.
  Future<void> setGlobalVariable(String botId, String key, dynamic value);

  /// Renames a global variable key.
  Future<void> renameGlobalVariable(String botId, String oldKey, String newKey);

  /// Removes a global variable.
  Future<void> removeGlobalVariable(String botId, String key);

  /// Returns scoped variables for [scope] and [contextId].
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  );

  /// Returns a single scoped variable.
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Persists or updates a scoped variable.
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value,
  );

  /// Renames a scoped variable key.
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  );

  /// Removes a scoped variable.
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Lists scoped variable entries for a [scope]+[key] index with pagination.
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  });

  // Array operations

  /// Push an element to the end of a scoped array.
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic element,
  );

  /// Pop the last element from a scoped array.
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Remove an element at [index] from a scoped array.
  Future<dynamic> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  );

  /// Get an element at [index] from a scoped array.
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  );

  /// Get the length of a scoped array.
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// List elements of a scoped array with pagination, sorting, and filtering.
  Future<Map<String, dynamic>> queryScopedArray(
    String botId,
    String scope,
    String contextId,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
    String? filter,
  });

  /// Finds a workflow by name (case-insensitive), or null if not found.
  Future<Map<String, dynamic>?> getWorkflowByName(String botId, String name);
}
