import 'package:bot_creator/utils/runner_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the optional "developer runner URL" used to link the app to a
/// remote Bot Creator Runner instance via its REST API.
class RunnerConnectionConfig {
  const RunnerConnectionConfig({required this.url, this.apiToken});

  final String url;
  final String? apiToken;

  RunnerClient createClient({Duration? getTimeout, Duration? postTimeout}) {
    return RunnerClient(
      baseUrl: url,
      apiToken: apiToken,
      getTimeout: getTimeout,
      postTimeout: postTimeout,
    );
  }
}

class RunnerSettings {
  RunnerSettings._();

  static const _keyUrl = 'developer_runner_url';
  static const _keyApiToken = 'developer_runner_api_token';

  static String? _normalize(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<RunnerConnectionConfig?> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final url = _normalize(prefs.getString(_keyUrl));
    if (url == null) {
      return null;
    }

    return RunnerConnectionConfig(
      url: url,
      apiToken: _normalize(prefs.getString(_keyApiToken)),
    );
  }

  /// Returns the saved runner URL, or `null` if not configured.
  static Future<String?> getUrl() async {
    final config = await getConfig();
    return config?.url;
  }

  static Future<String?> getApiToken() async {
    final config = await getConfig();
    return config?.apiToken;
  }

  static Future<RunnerClient?> createClient({
    Duration? getTimeout,
    Duration? postTimeout,
  }) async {
    final config = await getConfig();
    if (config == null) {
      return null;
    }

    return config.createClient(
      getTimeout: getTimeout,
      postTimeout: postTimeout,
    );
  }

  static Future<void> save({String? url, String? apiToken}) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedUrl = _normalize(url);
    final normalizedToken = _normalize(apiToken);

    if (normalizedUrl == null) {
      await prefs.remove(_keyUrl);
      await prefs.remove(_keyApiToken);
      return;
    }

    await prefs.setString(_keyUrl, normalizedUrl);

    if (normalizedToken == null) {
      await prefs.remove(_keyApiToken);
    } else {
      await prefs.setString(_keyApiToken, normalizedToken);
    }
  }

  /// Saves the runner URL. Pass `null` or an empty string to clear it.
  static Future<void> setUrl(String? url) async {
    await save(url: url, apiToken: await getApiToken());
  }

  static Future<void> setApiToken(String? apiToken) async {
    await save(url: await getUrl(), apiToken: apiToken);
  }

  /// Clears the saved runner configuration.
  static Future<void> clear() => save(url: null, apiToken: null);
}
