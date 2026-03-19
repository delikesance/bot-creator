import 'package:nyxx/nyxx.dart';
import '../types/component.dart';
import 'send_component_v2.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

/// Sends a message to a channel or directly to a user (DM).
///
/// Set `payload['targetType'] = 'user'` and provide `payload['userId']` to send
/// a DM rather than a channel message. In that case [channelId] is ignored.
Future<Map<String, String>> sendMessageToChannel(
  NyxxGateway client,
  Snowflake? channelId, {
  required String content,
  Map<String, dynamic>? payload,
  String Function(String)? resolve,
}) async {
  try {
    // Determine actual channel to send to
    Snowflake? targetChannelId = channelId;

    final targetType =
        (payload?['targetType'] ?? 'channel').toString().trim().toLowerCase();
    if (targetType == 'user') {
      final userId = _toSnowflake(payload?['userId']);
      if (userId == null) {
        return {
          'error': 'userId is required when targetType is "user"',
          'messageId': '',
        };
      }
      final dmChannel = await client.users.createDm(userId);
      targetChannelId = dmChannel.id;
    }

    if (targetChannelId == null) {
      return {
        'error':
            'channelId is required for sendMessage (or use targetType=user with userId)',
        'messageId': '',
      };
    }

    final channel = await client.channels.get(targetChannelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'messageId': ''};
    }

    List<ComponentBuilder>? components;
    bool isRichV2 = false;
    if (payload != null &&
        payload.containsKey('componentV2') &&
        payload['componentV2'] is Map) {
      try {
        final def = ComponentV2Definition.fromJson(
          Map<String, dynamic>.from(payload['componentV2']),
        );
        isRichV2 = def.isRichV2;
        components = buildComponentNodes(
          definition: def,
          resolve: resolve ?? (s) => s,
        );
      } catch (_) {}
    }

    final message = await channel.sendMessage(
      MessageBuilder(
        content: isRichV2 ? null : (content.isNotEmpty ? content : null),
        components: components,
        flags: isRichV2 ? MessageFlags(32768) : null,
      ),
    );
    return {'messageId': message.id.toString()};
  } catch (e) {
    return {'error': 'Failed to send message: $e', 'messageId': ''};
  }
}
