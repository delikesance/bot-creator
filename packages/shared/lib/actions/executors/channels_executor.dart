import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../create_channel.dart';
import '../remove_channel.dart';
import '../update_channel.dart';

Snowflake? _toSnowflake(dynamic value) {
  if (value == null) {
    return null;
  }
  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<bool> executeChannelsAction({
  required BotCreatorActionType type,
  required NyxxGateway client,
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required String Function(String input) resolveValue,
}) async {
  switch (type) {
    case BotCreatorActionType.createChannel:
      if (guildId == null) {
        throw Exception('This action requires a guild context');
      }

      final result = await createChannelAction(
        client,
        guildId: guildId,
        payload: payload,
        resolve: resolveValue,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['channelId'] ?? '';
      return true;

    case BotCreatorActionType.updateChannel:
      final result = await updateChannelAction(client, payload: payload);
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['channelId'] ?? '';
      return true;

    case BotCreatorActionType.removeChannel:
      final channelId = _toSnowflake(payload['channelId']);
      if (channelId == null) {
        throw Exception('Missing or invalid channelId for removeChannel');
      }

      final result = await removeChannel(client, channelId);
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['channelId'] ?? '';
      return true;

    default:
      return false;
  }
}
