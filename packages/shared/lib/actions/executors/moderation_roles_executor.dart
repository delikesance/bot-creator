import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../add_role.dart';
import '../ban_user.dart';
import '../kick_user.dart';
import '../mute_user.dart';
import '../remove_role.dart';
import '../unban_user.dart';
import '../unmute_user.dart';

Future<bool> executeModerationRolesAction({
  required BotCreatorActionType type,
  required NyxxGateway client,
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
}) async {
  switch (type) {
    case BotCreatorActionType.banUser:
    case BotCreatorActionType.unbanUser:
    case BotCreatorActionType.kickUser:
    case BotCreatorActionType.muteUser:
    case BotCreatorActionType.unmuteUser:
    case BotCreatorActionType.addRole:
    case BotCreatorActionType.removeRole:
      if (guildId == null) {
        throw Exception('User action requires a guild context');
      }

      final result = await switch (type) {
        BotCreatorActionType.banUser => banUserAction(
          client,
          guildId: guildId,
          payload: payload,
        ),
        BotCreatorActionType.unbanUser => unbanUserAction(
          client,
          guildId: guildId,
          payload: payload,
        ),
        BotCreatorActionType.kickUser => kickUserAction(
          client,
          guildId: guildId,
          payload: payload,
        ),
        BotCreatorActionType.muteUser => muteUserAction(
          client,
          guildId: guildId,
          payload: payload,
        ),
        BotCreatorActionType.unmuteUser => unmuteUserAction(
          client,
          guildId: guildId,
          payload: payload,
        ),
        BotCreatorActionType.addRole => addRoleAction(
          client,
          guildId: guildId,
          payload: payload,
        ),
        BotCreatorActionType.removeRole => removeRoleAction(
          client,
          guildId: guildId,
          payload: payload,
        ),
        _ => throw Exception('Unexpected action type'),
      };

      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['userId'] ?? '';
      return true;

    default:
      return false;
  }
}
