import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../types/app_emoji.dart';

/// Helper for Discord Application Emoji REST endpoints.
/// Docs: https://discord.com/developers/docs/resources/emoji#list-application-emojis
class AppEmojiApi {
  static const String _base = 'https://discord.com/api/v10';

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bot $token',
    'Content-Type': 'application/json',
  };

  /// Returns all application emojis for [applicationId].
  static Future<List<AppEmoji>> listEmojis(
    String token,
    String applicationId,
  ) async {
    final response = await http.get(
      Uri.parse('$_base/applications/$applicationId/emojis'),
      headers: _headers(token),
    );
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to list application emojis: ${response.statusCode}',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['items'] as List?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AppEmoji.fromJson)
        .toList();
  }

  /// Uploads a new emoji from a data URI (e.g. `data:image/png;base64,...`).
  /// Returns the created [AppEmoji].
  static Future<AppEmoji> createEmoji(
    String token,
    String applicationId,
    String name,
    String imageDataUri,
  ) async {
    final response = await http.post(
      Uri.parse('$_base/applications/$applicationId/emojis'),
      headers: _headers(token),
      body: jsonEncode({'name': name, 'image': imageDataUri}),
    );
    if (response.statusCode != 201) {
      final error = _tryParseError(response.body);
      throw HttpException('Failed to create emoji: $error');
    }
    return AppEmoji.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Renames [emojiId] to [newName]. Returns the updated [AppEmoji].
  static Future<AppEmoji> renameEmoji(
    String token,
    String applicationId,
    String emojiId,
    String newName,
  ) async {
    final response = await http.patch(
      Uri.parse('$_base/applications/$applicationId/emojis/$emojiId'),
      headers: _headers(token),
      body: jsonEncode({'name': newName}),
    );
    if (response.statusCode != 200) {
      final error = _tryParseError(response.body);
      throw HttpException('Failed to rename emoji: $error');
    }
    return AppEmoji.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Deletes [emojiId].
  static Future<void> deleteEmoji(
    String token,
    String applicationId,
    String emojiId,
  ) async {
    final response = await http.delete(
      Uri.parse('$_base/applications/$applicationId/emojis/$emojiId'),
      headers: _headers(token),
    );
    if (response.statusCode != 204) {
      final error = _tryParseError(response.body);
      throw HttpException('Failed to delete emoji: $error');
    }
  }

  static String _tryParseError(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map) {
        return parsed['message']?.toString() ?? body;
      }
    } catch (_) {}
    return body;
  }
}
