import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../add_reaction.dart';
import '../clear_all_reactions.dart';
import '../permission_checks.dart';
import '../remove_reaction.dart';

Future<bool> executeReactionsAction({
  required BotCreatorActionType type,
  required NyxxGateway client,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Snowflake? fallbackChannelId,
  Snowflake? guildId,
}) async {
  switch (type) {
    case BotCreatorActionType.addReaction:
      if (guildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: guildId,
          requiredPermissions: [
            Permissions.addReactions,
            Permissions.readMessageHistory,
          ],
          actionLabel: 'add reactions',
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }
      final result = await addReactionAction(
        client,
        payload: payload,
        fallbackChannelId: fallbackChannelId,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['status'] ?? 'OK';
      return true;

    case BotCreatorActionType.removeReaction:
      final result = await removeReactionAction(
        client,
        payload: payload,
        fallbackChannelId: fallbackChannelId,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['status'] ?? 'OK';
      return true;

    case BotCreatorActionType.clearAllReactions:
      if (guildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: guildId,
          requiredPermissions: [Permissions.manageMessages],
          actionLabel: 'clear reactions',
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }
      final result = await clearAllReactionsAction(
        client,
        payload: payload,
        fallbackChannelId: fallbackChannelId,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['status'] ?? 'OK';
      return true;

    default:
      return false;
  }
}
