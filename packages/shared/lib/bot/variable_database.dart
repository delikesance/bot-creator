/// Abstract interface for variable storage (scoped + global).
/// Implementations: JsonVariableStore, SqliteVariableStore, SqliteCliVariableStore
abstract class VariableDatabase {
  // ===== GLOBAL VARIABLES =====
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

  // ===== SCOPED VARIABLES =====
  /// Returns all scoped variables for [botId]+[scope]+[contextId].
  /// For guildMember scope, [contextId] is "{guildId}:{userId}" format.
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  );

  /// Returns a single scoped variable, or null if not set.
  /// For guildMember scope, [contextId] is "{guildId}:{userId}" format.
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Persists or updates a scoped variable.
  /// For guildMember scope, [contextId] is "{guildId}:{userId}" format.
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value,
  );

  /// Renames a scoped variable key.
  /// For guildMember scope, [contextId] is "{guildId}:{userId}" format.
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  );

  /// Removes a scoped variable.
  /// For guildMember scope, [contextId] is "{guildId}:{userId}" format.
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Lists all context IDs for a given [scope] (e.g. all guild IDs that have guild-scoped vars).
  /// Optionally filter by a [searchKey] prefix (e.g. "bc_" to find only bc_* variables).
  Future<List<String>> listContextIds(
    String botId,
    String scope, {
    String? searchKey,
  });

  /// Delete all variables for a bot.
  Future<void> deleteAllForBot(String botId);
}
