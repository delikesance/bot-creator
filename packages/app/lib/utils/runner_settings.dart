import 'package:shared_preferences/shared_preferences.dart';

/// Manages the optional "developer runner URL" used to link the app to a
/// remote Bot Creator Runner instance via its REST API.
class RunnerSettings {
  RunnerSettings._();

  static const _keyUrl = 'developer_runner_url';

  /// Returns the saved runner URL, or `null` if not configured.
  static Future<String?> getUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUrl)?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// Saves the runner URL.  Pass `null` or an empty string to clear it.
  static Future<void> setUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(_keyUrl);
    } else {
      await prefs.setString(_keyUrl, trimmed);
    }
  }

  /// Clears the saved runner URL.
  static Future<void> clear() => setUrl(null);
}
