import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../delete_message.dart';
import '../edit_message.dart';
import '../get_message.dart';
import '../permission_checks.dart';
import '../send_message.dart';

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

Future<bool> executeMessagingAction({
  required BotCreatorActionType type,
  required NyxxGateway client,
  required Interaction? interaction,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String botId,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  required String Function(String input) resolveValue,
}) async {
  switch (type) {
    case BotCreatorActionType.deleteMessages:
      if (guildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: guildId,
          requiredPermissions: [
            Permissions.manageMessages,
            Permissions.readMessageHistory,
          ],
          actionLabel: 'delete messages',
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }
      final resolvedChannelIdRaw = resolveValue(
        (payload['channelId'] ?? '').toString(),
      );
      final channelId = _toSnowflake(resolvedChannelIdRaw) ?? fallbackChannelId;
      if (channelId == null) {
        throw Exception('Missing or invalid channelId for deleteMessages');
      }

      final rawCount = payload['messageCount'];
      final resolvedCountRaw = resolveValue((rawCount ?? '').toString());
      final parsedCount = double.tryParse(resolvedCountRaw);
      final count =
          parsedCount != null
              ? parsedCount.round()
              : (rawCount is num ? rawCount.toInt() : 0);

      final onlyUserId = resolveValue((payload['onlyUserId'] ?? '').toString());
      final reason = resolveValue((payload['reason'] ?? '').toString()).trim();

      final filterBotsRaw =
          resolveValue((payload['filterBots'] ?? '').toString()).toLowerCase();
      final filterUsersRaw =
          resolveValue((payload['filterUsers'] ?? '').toString()).toLowerCase();
      final filterBots = filterBotsRaw == 'true' || filterBotsRaw == '1';
      final filterUsers = filterUsersRaw == 'true' || filterUsersRaw == '1';

      final beforeRaw = resolveValue(
        (payload['beforeMessageId'] ?? '').toString(),
      );
      final beforeMessageId = _toSnowflake(beforeRaw);

      final deleteItselfRaw =
          resolveValue(
            (payload['deleteItself'] ?? '').toString(),
          ).toLowerCase();
      var deleteItself = false;
      if (deleteItselfRaw.isNotEmpty) {
        if (deleteItselfRaw == 'true' ||
            deleteItselfRaw == 'yes' ||
            deleteItselfRaw == 'y' ||
            deleteItselfRaw == '1') {
          deleteItself = true;
        } else {
          final numVal = num.tryParse(deleteItselfRaw);
          if (numVal != null && numVal > 0) {
            deleteItself = true;
          }
        }
      }

      Snowflake? commandMessageId;
      try {
        if (interaction is ApplicationCommandInteraction) {
          final resp = await interaction.fetchOriginalResponse();
          commandMessageId = resp.id;
        }
      } catch (_) {}

      final result = await deleteMessage(
        client,
        channelId,
        count: count,
        onlyThisUserID: onlyUserId,
        beforeMessageId: beforeMessageId,
        deleteItself: deleteItself,
        commandMessageId: commandMessageId,
        filterBots: filterBots,
        filterUsers: filterUsers,
        reason: reason,
      );
      if (result['error'] != null) {
        final errorCode = result['errorCode'];
        if (errorCode != null && errorCode.isNotEmpty) {
          throw Exception('[$errorCode] ${result['error']}');
        }
        throw Exception(result['error']);
      }
      final deletedCount = result['count'] ?? '0';
      results[resultKey] = deletedCount;
      variables['action.$resultKey.count'] = deletedCount;
      variables['$resultKey.count'] = deletedCount;
      final deleteMode = result['mode'] ?? 'none';
      variables['action.$resultKey.mode'] = deleteMode;
      variables['$resultKey.mode'] = deleteMode;
      if (deleteItself) {
        variables['action.$resultKey.deleteItself'] = deleteItself.toString();
        variables['$resultKey.deleteItself'] = deleteItself.toString();
        variables['action.$resultKey.deleteResponse'] = deleteItself.toString();
        variables['$resultKey.deleteResponse'] = deleteItself.toString();
      }
      return true;

    case BotCreatorActionType.sendMessage:
      final targetType =
          (payload['targetType'] ?? 'channel').toString().trim().toLowerCase();
      final channelId = _toSnowflake(payload['channelId']) ?? fallbackChannelId;

      if (targetType != 'user' && guildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: guildId,
          requiredPermissions: [Permissions.sendMessages],
          actionLabel: 'send messages',
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }

      if (targetType != 'user' && channelId == null) {
        throw Exception('Missing or invalid channelId for sendMessage');
      }

      final content = resolveValue((payload['content'] ?? '').toString());
      if (content.trim().isEmpty) {
        throw Exception('content is required for sendMessage');
      }

      final resolvedSendPayload = Map<String, dynamic>.from(payload);
      if (targetType == 'user') {
        resolvedSendPayload['userId'] = resolveValue(
          (payload['userId'] ?? '').toString(),
        );
      }

      final result = await sendMessageToChannel(
        client,
        channelId,
        content: content,
        payload: resolvedSendPayload,
        resolve: resolveValue,
        botId: botId,
        guildId: guildId?.toString(),
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      variables['$resultKey.messageId'] = result['messageId'] ?? '';
      return true;

    case BotCreatorActionType.editMessage:
      final content = resolveValue((payload['content'] ?? '').toString());
      final result = await editMessageAction(
        client,
        payload: payload,
        fallbackChannelId: fallbackChannelId,
        content: content,
        resolve: resolveValue,
        botId: botId,
        guildId: guildId?.toString(),
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      return true;

    case BotCreatorActionType.getMessage:
      final result = await getMessageAction(
        client,
        payload: payload,
        fallbackChannelId: fallbackChannelId,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      for (final entry in result.entries) {
        variables['$resultKey.${entry.key}'] = entry.value;
      }
      return true;

    default:
      return false;
  }
}
