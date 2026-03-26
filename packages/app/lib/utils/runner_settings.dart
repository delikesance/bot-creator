import 'dart:convert';

import 'package:bot_creator/utils/runner_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single runner connection configuration.
class RunnerConnectionConfig {
  const RunnerConnectionConfig({
    required this.id,
    required this.url,
    this.apiToken,
    this.name,
  });

  /// Unique identifier for this runner entry.
  final String id;

  final String url;
  final String? apiToken;

  /// Optional human-readable label (e.g. "Production", "Dev Server").
  final String? name;

  RunnerClient createClient({Duration? getTimeout, Duration? postTimeout}) {
    return RunnerClient(
      baseUrl: url,
      apiToken: apiToken,
      getTimeout: getTimeout,
      postTimeout: postTimeout,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    if (apiToken != null) 'apiToken': apiToken,
    if (name != null) 'name': name,
  };

  factory RunnerConnectionConfig.fromJson(Map<String, dynamic> json) {
    return RunnerConnectionConfig(
      id: (json['id'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      apiToken: _normalize(json['apiToken']?.toString()),
      name: _normalize(json['name']?.toString()),
    );
  }
}

/// Manages a registry of runner connections with an active runner selection.
///
/// Stores data in SharedPreferences. Backward-compatible: automatically
/// migrates the legacy single-runner format (keys `developer_runner_url` /
/// `developer_runner_api_token`) into the registry on first access.
class RunnerSettings {
  RunnerSettings._();

  // Legacy keys (singleton format)
  static const _keyUrl = 'developer_runner_url';
  static const _keyApiToken = 'developer_runner_api_token';

  // Multi-runner keys
  static const _keyRegistry = 'runner_registry';
  static const _keyActiveId = 'runner_active_id';

  /// Returns all registered runners.
  static Future<List<RunnerConnectionConfig>> getRunners() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacy(prefs);
    final raw = prefs.getString(_keyRegistry);
    if (raw == null) return [];
    return _decodeRegistry(raw);
  }

  /// Returns the active runner ID, or `null` if none is selected.
  static Future<String?> getActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacy(prefs);
    return prefs.getString(_keyActiveId);
  }

  /// Returns the active runner config, or `null` if none is configured.
  static Future<RunnerConnectionConfig?> getConfig() async {
    final runners = await getRunners();
    if (runners.isEmpty) return null;
    final activeId = await getActiveId();
    if (activeId != null) {
      final match = runners.where((r) => r.id == activeId);
      if (match.isNotEmpty) return match.first;
    }
    // Fallback to first runner if active ID is stale
    return runners.first;
  }

  /// Creates a [RunnerClient] for the active runner, or `null` if none is
  /// configured.
  static Future<RunnerClient?> createClient({
    Duration? getTimeout,
    Duration? postTimeout,
  }) async {
    final config = await getConfig();
    return config?.createClient(
      getTimeout: getTimeout,
      postTimeout: postTimeout,
    );
  }

  /// Returns the saved runner URL of the active runner, or `null`.
  static Future<String?> getUrl() async => (await getConfig())?.url;

  /// Returns the API token of the active runner, or `null`.
  static Future<String?> getApiToken() async => (await getConfig())?.apiToken;

  /// Adds or updates a runner in the registry.
  ///
  /// If a runner with the same [config.id] already exists, it is replaced.
  /// If this is the first runner, it automatically becomes the active one.
  static Future<void> addRunner(RunnerConnectionConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacy(prefs);
    final runners = _decodeRegistry(prefs.getString(_keyRegistry));
    runners.removeWhere((r) => r.id == config.id);
    runners.add(config);
    await _saveRegistry(prefs, runners);

    // Auto-select if it's the only runner or no active selection
    final currentActive = prefs.getString(_keyActiveId);
    if (currentActive == null || runners.length == 1) {
      await prefs.setString(_keyActiveId, config.id);
    }
  }

  /// Removes a runner from the registry by [id].
  ///
  /// If the removed runner was active, the first remaining runner (if any)
  /// becomes active.
  static Future<void> removeRunner(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacy(prefs);
    final runners = _decodeRegistry(prefs.getString(_keyRegistry));
    runners.removeWhere((r) => r.id == id);
    await _saveRegistry(prefs, runners);

    if (prefs.getString(_keyActiveId) == id) {
      if (runners.isNotEmpty) {
        await prefs.setString(_keyActiveId, runners.first.id);
      } else {
        await prefs.remove(_keyActiveId);
      }
    }
  }

  /// Sets the active runner by [id]. The runner must already be registered.
  static Future<void> setActiveRunner(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveId, id);
  }

  /// Backward-compatible save: updates the active runner, or creates one.
  static Future<void> save({String? url, String? apiToken}) async {
    final normalizedUrl = _normalize(url);
    if (normalizedUrl == null) {
      // Clear all runners
      await clear();
      return;
    }

    final config = await getConfig();
    final id = config?.id ?? _generateId();
    await addRunner(
      RunnerConnectionConfig(
        id: id,
        url: normalizedUrl,
        apiToken: _normalize(apiToken),
        name: config?.name,
      ),
    );
  }

  /// Backward-compatible helper.
  static Future<void> setUrl(String? url) async {
    await save(url: url, apiToken: await getApiToken());
  }

  /// Backward-compatible helper.
  static Future<void> setApiToken(String? apiToken) async {
    await save(url: await getUrl(), apiToken: apiToken);
  }

  /// Clears the entire runner registry.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRegistry);
    await prefs.remove(_keyActiveId);
    // Also clean up legacy keys
    await prefs.remove(_keyUrl);
    await prefs.remove(_keyApiToken);
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Migrates the old singleton format into the registry (once).
  static Future<void> _migrateLegacy(SharedPreferences prefs) async {
    // If registry already exists, skip migration
    if (prefs.containsKey(_keyRegistry)) return;

    final legacyUrl = _normalize(prefs.getString(_keyUrl));
    if (legacyUrl == null) return;

    final legacyToken = _normalize(prefs.getString(_keyApiToken));
    final config = RunnerConnectionConfig(
      id: _generateId(),
      url: legacyUrl,
      apiToken: legacyToken,
      name: 'Default',
    );

    await _saveRegistry(prefs, [config]);
    await prefs.setString(_keyActiveId, config.id);
    // Remove legacy keys after successful migration
    await prefs.remove(_keyUrl);
    await prefs.remove(_keyApiToken);
  }

  static List<RunnerConnectionConfig> _decodeRegistry(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map(
            (e) =>
                RunnerConnectionConfig.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((c) => c.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveRegistry(
    SharedPreferences prefs,
    List<RunnerConnectionConfig> runners,
  ) async {
    final json = jsonEncode(runners.map((r) => r.toJson()).toList());
    await prefs.setString(_keyRegistry, json);
  }

  static String _generateId() {
    // Simple timestamp-based ID, sufficient for a small local registry
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  }
}

String? _normalize(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
