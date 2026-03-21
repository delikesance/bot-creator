import 'package:bot_creator/actions/create_channel.dart';
import 'package:bot_creator/actions/delete_message.dart';
import 'package:bot_creator/actions/remove_channel.dart';
import 'package:bot_creator/actions/send_message.dart';
import 'package:bot_creator/actions/update_channel.dart';
import 'package:bot_creator/actions/edit_message.dart';
import 'package:bot_creator/actions/add_reaction.dart';
import 'package:bot_creator/actions/remove_reaction.dart';
import 'package:bot_creator/actions/clear_all_reactions.dart';
import 'package:bot_creator/actions/ban_user.dart';
import 'package:bot_creator/actions/unban_user.dart';
import 'package:bot_creator/actions/kick_user.dart';
import 'package:bot_creator/actions/mute_user.dart';
import 'package:bot_creator/actions/unmute_user.dart';
import 'package:bot_creator/actions/add_role.dart';
import 'package:bot_creator/actions/remove_role.dart';
import 'package:bot_creator/actions/pin_message.dart';
import 'package:bot_creator/actions/update_automod.dart';
import 'package:bot_creator/actions/update_guild.dart';
import 'package:bot_creator/actions/list_members.dart';
import 'package:bot_creator/actions/get_member.dart';
import 'package:bot_creator/actions/send_component_v2.dart';
import 'package:bot_creator/actions/edit_component_v2.dart';
import 'package:bot_creator/actions/respond_modal.dart';
import 'package:bot_creator/actions/edit_interaction_response.dart';
import 'package:bot_creator/actions/respond_with_message.dart';
import 'package:bot_creator/actions/send_webhook.dart';
import 'package:bot_creator/actions/edit_webhook.dart';
import 'package:bot_creator/actions/delete_webhook.dart';
import 'package:bot_creator/actions/list_webhooks.dart';
import 'package:bot_creator/actions/get_webhook.dart';
import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart'
    as shared_control_flow_executor;
import 'package:bot_creator_shared/actions/executors/http_executor.dart'
    as shared_http_executor;
import 'package:bot_creator_shared/actions/handler.dart' as shared_handler;
import 'package:bot_creator_shared/types/action.dart' as shared_types;
import 'package:bot_creator/utils/database.dart';
import 'package:bot_creator/utils/interaction_listener_registry.dart';
import 'package:bot_creator/utils/workflow_call.dart';
import 'package:nyxx/nyxx.dart';
import '../types/action.dart';
import 'handler_utils.dart';

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

const Set<String> _supportedVariableScopes = {
  'guild',
  'user',
  'channel',
  'guildMember',
  'message',
};

String? _resolveScopeContextId({
  required String scope,
  required Map<String, String> variables,
  required Snowflake? guildId,
  required Snowflake? channelId,
  required Interaction? interaction,
}) {
  String? fromVariables(String key) {
    final value = variables[key]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? fromSnowflake(Snowflake? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? interactionUserId() {
    final dynamic raw = interaction;
    final userId = (raw?.user ?? raw?.author?.id)?.toString().trim();
    return (userId == null || userId.isEmpty) ? null : userId;
  }

  String? interactionMessageId() {
    final dynamic raw = interaction;
    final messageId = raw?.message?.id?.toString().trim();
    return (messageId == null || messageId.isEmpty) ? null : messageId;
  }

  switch (scope) {
    case 'guild':
      return fromVariables('guildId') ?? fromSnowflake(guildId);
    case 'user':
      return fromVariables('userId') ?? interactionUserId();
    case 'channel':
      return fromVariables('channelId') ?? fromSnowflake(channelId);
    case 'guildMember':
      {
        final guild = fromVariables('guildId') ?? fromSnowflake(guildId);
        final user = fromVariables('userId') ?? interactionUserId();
        if (guild == null || user == null) {
          return null;
        }
        return '$guild:$user';
      }
    case 'message':
      return fromVariables('messageId') ??
          fromVariables('message.id') ??
          interactionMessageId();
    default:
      return null;
  }
}

dynamic _resolveVariableValuePayload(
  Map<String, dynamic> payload,
  String Function(String) resolveValue,
) {
  final valueType =
      resolveValue(
        (payload['valueType'] ?? 'string').toString(),
      ).trim().toLowerCase();
  if (valueType == 'number') {
    final numberRaw =
        resolveValue((payload['numberValue'] ?? '').toString()).trim();
    final parsed = num.tryParse(numberRaw);
    if (parsed != null) {
      return parsed;
    }
  }

  return resolveValue((payload['value'] ?? '').toString());
}

String _scopedStorageKey(String rawKey) {
  final key = rawKey.trim();
  if (key.isEmpty) {
    throw Exception('key is required for scoped variables');
  }
  if (key.startsWith('bc_')) {
    if (key.length <= 3) {
      throw Exception('key is required for scoped variables');
    }
    return key.substring(3);
  }
  return key;
}

String _scopedReferenceKey(String rawKey) {
  final key = rawKey.trim();
  if (key.isEmpty) {
    throw Exception('key is required for scoped variables');
  }
  return key.startsWith('bc_') ? key : 'bc_$key';
}

// Helper functions for common action patterns

Future<Map<String, String>> _executeUserAction(
  Future<Map<String, String>> Function() action, {
  required Snowflake? guildId,
  String actionName = 'User action',
}) async {
  if (guildId == null) {
    throw Exception('$actionName requires a guild context');
  }
  return action();
}

Future<Map<String, String>> handleActions(
  NyxxGateway client,
  Interaction? interaction, {
  required List<Action> actions,
  required AppManager manager,
  required String botId,
  required Map<String, String> variables,
  required String Function(String input) resolveTemplate,
  Snowflake? fallbackChannelId,
  Snowflake? fallbackGuildId,
  Set<String>? workflowStack,
  void Function(String message)? onLog,
}) async {
  final results = <String, String>{};
  final resolvedFallbackChannelId =
      fallbackChannelId ?? (interaction as dynamic)?.channel?.id as Snowflake?;
  final guildId =
      fallbackGuildId ?? (interaction as dynamic)?.guildId as Snowflake?;
  final activeWorkflowStack = workflowStack ?? <String>{};

  String resolveValue(String value) => resolveTemplate(value);

  for (var i = 0; i < actions.length; i++) {
    final action = actions[i];
    final resultKey = action.key ?? 'action_$i';
    if (!action.enabled) {
      continue;
    }

    final sharedActionType = shared_types.BotCreatorActionType.values
        .cast<shared_types.BotCreatorActionType?>()
        .firstWhere(
          (value) => value?.name == action.type.name,
          orElse: () => null,
        );

    var handledByControlFlowExecutor = false;
    if (sharedActionType != null) {
      handledByControlFlowExecutor = await shared_control_flow_executor
          .executeControlFlowAction(
            type: sharedActionType,
            payload: action.payload,
            resultKey: resultKey,
            results: results,
            variables: variables,
            resolveValue: resolveValue,
            onLog: onLog,
            activeWorkflowStack: activeWorkflowStack,
            getWorkflowByName:
                (workflowName) =>
                    manager.getWorkflowByName(botId, workflowName),
            executeActions: (nestedSharedActions) async {
              final nestedAppActions =
                  nestedSharedActions
                      .map(
                        (sharedAction) =>
                            Action.fromJson(sharedAction.toJson()),
                      )
                      .toList();
              return handleActions(
                client,
                interaction,
                actions: nestedAppActions,
                manager: manager,
                botId: botId,
                variables: variables,
                resolveTemplate: resolveTemplate,
                fallbackChannelId: resolvedFallbackChannelId,
                fallbackGuildId: guildId,
                workflowStack: activeWorkflowStack,
                onLog: onLog,
              );
            },
          );
    }
    if (handledByControlFlowExecutor) {
      if (results.containsKey('__stopped__')) {
        return results;
      }
      continue;
    }

    var handledByHttpExecutor = false;
    if (sharedActionType != null) {
      handledByHttpExecutor = await shared_http_executor.executeHttpAction(
        type: sharedActionType,
        payload: action.payload,
        resultKey: resultKey,
        results: results,
        variables: variables,
        resolveValue: resolveValue,
        onLog: onLog,
        setGlobalVariable:
            (key, value) => manager.setGlobalVariable(botId, key, value),
      );
    }
    if (handledByHttpExecutor) continue;

    try {
      switch (action.type) {
        case BotCreatorActionType.deleteMessages:
          final resolvedChannelIdRaw = resolveValue(
            (action.payload['channelId'] ?? '').toString(),
          );
          final channelId =
              _toSnowflake(resolvedChannelIdRaw) ?? resolvedFallbackChannelId;
          if (channelId == null) {
            throw Exception('Missing or invalid channelId for deleteMessages');
          }

          final rawCount = action.payload['messageCount'];
          final resolvedCountRaw = resolveValue((rawCount ?? '').toString());
          double? parsedCount = double.tryParse(resolvedCountRaw);
          final count =
              parsedCount != null
                  ? parsedCount.round()
                  : (rawCount is num ? rawCount.toInt() : 0);

          final onlyUserId = resolveValue(
            (action.payload['onlyUserId'] ?? '').toString(),
          );

          // optional before message id for deleting messages above
          final beforeRaw = resolveValue(
            (action.payload['beforeMessageId'] ?? '').toString(),
          );
          Snowflake? beforeMessageId = _toSnowflake(beforeRaw);
          // when beforeMessageId is null we will fetch recent messages (no
          // restriction). this means count=1 will remove the last message in
          // the channel. deleteItself only works when a specific message ID is
          // supplied, since otherwise we have nothing to delete.

          // optional flag to delete the command message itself
          final deleteItselfRaw =
              resolveValue(
                (action.payload['deleteItself'] ?? '').toString(),
              ).toLowerCase();
          bool deleteItself = false;
          if (deleteItselfRaw.isNotEmpty) {
            if (deleteItselfRaw == 'true' ||
                deleteItselfRaw == 'yes' ||
                deleteItselfRaw == 'y' ||
                deleteItselfRaw == '1') {
              deleteItself = true;
            } else {
              final num? numVal = num.tryParse(deleteItselfRaw);
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
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          final deletedCount = result['count'] ?? '0';
          results[resultKey] = deletedCount;
          variables['action.$resultKey.count'] = deletedCount;
          variables['$resultKey.count'] = deletedCount;
          // propagate flag for external handling (e.g. deleting bot response)
          if (deleteItself) {
            // propagate both legacy flag and explicit response-deletion flag
            variables['action.$resultKey.deleteItself'] =
                deleteItself.toString();
            variables['$resultKey.deleteItself'] = deleteItself.toString();
            variables['action.$resultKey.deleteResponse'] =
                deleteItself.toString();
            variables['$resultKey.deleteResponse'] = deleteItself.toString();
          }
          break;
        case BotCreatorActionType.createChannel:
          if (guildId == null) {
            throw Exception('This action requires a guild context');
          }

          final typeRaw = (action.payload['type'] ?? 'text').toString();
          final channelType =
              typeRaw == 'voice'
                  ? ChannelType.guildVoice
                  : ChannelType.guildText;
          final result = await createChannel(
            client,
            (action.payload['name'] ?? '').toString(),
            guildId: guildId,
            type: channelType,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['channelId'] ?? '';
          break;
        case BotCreatorActionType.updateChannel:
          final result = await updateChannelAction(
            client,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['channelId'] ?? '';
          break;
        case BotCreatorActionType.removeChannel:
          final channelId = _toSnowflake(action.payload['channelId']);
          if (channelId == null) {
            throw Exception('Missing or invalid channelId for removeChannel');
          }

          final result = await removeChannel(client, channelId);
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['channelId'] ?? '';
          break;
        case BotCreatorActionType.sendMessage:
          final channelId =
              _toSnowflake(action.payload['channelId']) ??
              resolvedFallbackChannelId;
          if (channelId == null) {
            throw Exception('Missing or invalid channelId for sendMessage');
          }

          final content = resolveValue(
            (action.payload['content'] ?? '').toString(),
          );
          if (content.trim().isEmpty) {
            throw Exception('content is required for sendMessage');
          }

          final result = await sendMessageToChannel(
            client,
            channelId,
            content: content,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.editMessage:
          final content = resolveValue(
            (action.payload['content'] ?? '').toString(),
          );
          final result = await editMessageAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            content: content,
            resolve: resolveValue,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.addReaction:
          final result = await addReactionAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['status'] ?? 'OK';
          break;
        case BotCreatorActionType.removeReaction:
          final result = await removeReactionAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['status'] ?? 'OK';
          break;
        case BotCreatorActionType.clearAllReactions:
          final result = await clearAllReactionsAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['status'] ?? 'OK';
          break;
        case BotCreatorActionType.banUser:
        case BotCreatorActionType.unbanUser:
        case BotCreatorActionType.kickUser:
        case BotCreatorActionType.muteUser:
        case BotCreatorActionType.unmuteUser:
        case BotCreatorActionType.addRole:
        case BotCreatorActionType.removeRole:
          final result = await _executeUserAction(() async {
            return switch (action.type) {
              BotCreatorActionType.banUser => banUserAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              BotCreatorActionType.unbanUser => unbanUserAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              BotCreatorActionType.kickUser => kickUserAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              BotCreatorActionType.muteUser => muteUserAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              BotCreatorActionType.unmuteUser => unmuteUserAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              BotCreatorActionType.addRole => addRoleAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              BotCreatorActionType.removeRole => removeRoleAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              _ => throw Exception('Unexpected action type'),
            };
          }, guildId: guildId);
          if (result.hasError) {
            throw Exception(result.error);
          }
          results[resultKey] = result.getOrEmpty('userId');
          break;
        case BotCreatorActionType.pinMessage:
          final result = await pinMessageAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.updateAutoMod:
          final result = await updateAutoModAction(
            client,
            guildId: guildId,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['status'] ?? 'OK';
          break;
        case BotCreatorActionType.updateGuild:
          final result = await updateGuildAction(
            client,
            guildId: guildId,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['guildId'] ?? '';
          break;
        case BotCreatorActionType.listMembers:
          final result = await listMembersAction(
            client,
            guildId: guildId,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['members'] ?? '[]';
          break;
        case BotCreatorActionType.getMember:
          final result = await getMemberAction(
            client,
            guildId: guildId,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['member'] ?? '';
          break;
        case BotCreatorActionType.sendComponentV2:
          final result = await sendComponentV2Action(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            resolve: resolveValue,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.editComponentV2:
          final result = await editComponentV2Action(
            client,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.respondWithComponentV2:
          if (interaction == null) {
            results[resultKey] =
                'Error: respondWithComponentV2 requires an interaction context';
            break;
          }
          final respResult = await respondWithComponentV2Action(
            interaction,
            payload: action.payload,
            resolve: resolveValue,
            botId: botId,
          );
          if (respResult['error'] != null) {
            throw Exception(respResult['error']);
          }
          results[resultKey] = respResult['messageId'] ?? 'responded';
          break;
        case BotCreatorActionType.respondWithMessage:
          if (interaction == null) {
            results[resultKey] =
                'Error: respondWithMessage requires an interaction context';
            break;
          }
          final messageResult = await respondWithMessageAction(
            interaction,
            payload: action.payload,
            resolve: resolveValue,
            botId: botId,
          );
          if (messageResult['error'] != null) {
            throw Exception(messageResult['error']);
          }
          results[resultKey] = messageResult['messageId'] ?? 'responded';
          break;
        case BotCreatorActionType.respondWithModal:
          if (interaction == null) {
            results[resultKey] =
                'Error: respondWithModal requires a slash command interaction';
            break;
          }
          final modalResult = await respondWithModalAction(
            interaction,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (modalResult['error'] != null) {
            throw Exception(modalResult['error']);
          }
          final customId = modalResult['customId'] ?? 'modal_sent';
          results[resultKey] = customId;

          // Auto-register listener if onSubmitWorkflow is provided
          final onSubmitWorkflow =
              resolveValue(
                (modalResult['onSubmitWorkflow'] ?? '').toString(),
              ).trim();
          if (onSubmitWorkflow.isNotEmpty) {
            final onSubmitEntryPoint =
                resolveValue(
                  (modalResult['onSubmitEntryPoint'] ?? '').toString(),
                ).trim();
            final onSubmitArguments = resolveWorkflowCallArguments(
              modalResult['onSubmitArguments'],
              resolveValue,
            );
            InteractionListenerRegistry.instance.register(
              customId,
              ListenerEntry(
                botId: botId,
                workflowName: onSubmitWorkflow,
                workflowEntryPoint: onSubmitEntryPoint,
                workflowArguments: onSubmitArguments,
                expiresAt: DateTime.now().add(const Duration(hours: 1)),
                type: 'modal',
                oneShot: true,
                guildId: guildId?.toString(),
                channelId: resolvedFallbackChannelId?.toString(),
              ),
            );
          }
          break;
        case BotCreatorActionType.editInteractionMessage:
          if (interaction == null) {
            results[resultKey] =
                'Error: editInteractionMessage requires an interaction context';
            break;
          }
          final editResult = await editInteractionMessageAction(
            interaction,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (editResult['error'] != null) {
            throw Exception(editResult['error']);
          }
          results[resultKey] = editResult['messageId'] ?? '';
          break;
        case BotCreatorActionType.listenForButtonClick:
        case BotCreatorActionType.listenForModalSubmit:
          final customId = resolveValue(
            (action.payload['customId'] ?? '').toString(),
          );
          if (customId.isEmpty) {
            throw Exception('customId is required for ${action.type.name}');
          }
          final workflowName = resolveValue(
            (action.payload['workflowName'] ?? '').toString(),
          );
          if (workflowName.isEmpty) {
            throw Exception('workflowName is required for ${action.type.name}');
          }
          final ttlRaw = action.payload['ttlMinutes'];
          final ttlMinutes = (ttlRaw is num
                  ? ttlRaw.toInt()
                  : int.tryParse(ttlRaw?.toString() ?? '') ?? 60)
              .clamp(1, 60);
          final oneShot =
              action.type == BotCreatorActionType.listenForModalSubmit
                  ? true
                  : (action.payload['oneShot'] != false);
          final workflowEntryPoint =
              resolveValue(
                (action.payload['entryPoint'] ?? '').toString(),
              ).trim();
          final workflowArguments = resolveWorkflowCallArguments(
            action.payload['arguments'],
            resolveValue,
          );

          InteractionListenerRegistry.instance.register(
            customId,
            ListenerEntry(
              botId: botId,
              workflowName: workflowName,
              workflowEntryPoint: workflowEntryPoint,
              workflowArguments: workflowArguments,
              expiresAt: DateTime.now().add(Duration(minutes: ttlMinutes)),
              type:
                  action.type == BotCreatorActionType.listenForButtonClick
                      ? 'button'
                      : 'modal',
              oneShot: oneShot,
              guildId: guildId?.toString(),
              channelId: resolvedFallbackChannelId?.toString(),
            ),
          );
          results[resultKey] = 'listening:$customId';
          break;
        case BotCreatorActionType.sendWebhook:
        case BotCreatorActionType.editWebhook:
        case BotCreatorActionType.deleteWebhook:
          final result = await switch (action.type) {
            BotCreatorActionType.sendWebhook => sendWebhookAction(
              client,
              payload: action.payload,
              resolve: resolveValue,
            ),
            BotCreatorActionType.editWebhook => editWebhookAction(
              client,
              payload: action.payload,
            ),
            BotCreatorActionType.deleteWebhook => deleteWebhookAction(
              client,
              payload: action.payload,
            ),
            _ => throw Exception('Unexpected action type'),
          };
          if (result.hasError) {
            throw Exception(result.error);
          }
          results[resultKey] = result.getOrEmpty('webhookId');
          break;
        case BotCreatorActionType.listWebhooks:
          final result = await listWebhooksAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            fallbackGuildId: guildId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['webhooks'] ?? '[]';
          break;
        case BotCreatorActionType.getWebhook:
          final result = await getWebhookAction(
            client,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['webhook'] ?? '';
          break;
        case BotCreatorActionType.setScopedVariable:
          final scope =
              resolveValue((action.payload['scope'] ?? '').toString()).trim();
          if (!_supportedVariableScopes.contains(scope)) {
            throw Exception(
              'scope is required for setScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
            );
          }

          final rawKey =
              resolveValue((action.payload['key'] ?? '').toString()).trim();
          final storageKey = _scopedStorageKey(rawKey);
          final referenceKey = _scopedReferenceKey(rawKey);

          final contextId = _resolveScopeContextId(
            scope: scope,
            variables: variables,
            guildId: guildId,
            channelId: resolvedFallbackChannelId,
            interaction: interaction,
          );
          if (contextId == null || contextId.trim().isEmpty) {
            throw Exception('Unable to resolve context ID for scope "$scope"');
          }

          final value = _resolveVariableValuePayload(
            action.payload,
            resolveValue,
          );
          await manager.setScopedVariable(
            botId,
            scope,
            contextId,
            storageKey,
            value,
          );
          variables['$scope.$referenceKey'] = value.toString();
          if (rawKey.isNotEmpty && rawKey != referenceKey) {
            variables['$scope.$rawKey'] = value.toString();
          }
          results[resultKey] = 'OK';
          break;
        case BotCreatorActionType.getScopedVariable:
          final scope =
              resolveValue((action.payload['scope'] ?? '').toString()).trim();
          if (!_supportedVariableScopes.contains(scope)) {
            throw Exception(
              'scope is required for getScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
            );
          }

          final rawKey =
              resolveValue((action.payload['key'] ?? '').toString()).trim();
          final storageKey = _scopedStorageKey(rawKey);
          final referenceKey = _scopedReferenceKey(rawKey);

          final contextId = _resolveScopeContextId(
            scope: scope,
            variables: variables,
            guildId: guildId,
            channelId: resolvedFallbackChannelId,
            interaction: interaction,
          );
          if (contextId == null || contextId.trim().isEmpty) {
            throw Exception('Unable to resolve context ID for scope "$scope"');
          }

          var value = await manager.getScopedVariable(
            botId,
            scope,
            contextId,
            storageKey,
          );
          if (value == null && referenceKey != storageKey) {
            value = await manager.getScopedVariable(
              botId,
              scope,
              contextId,
              referenceKey,
            );
          }
          value ??= '';
          final storeAs =
              resolveValue(
                (action.payload['storeAs'] ?? '$scope.$referenceKey')
                    .toString(),
              ).trim();
          if (storeAs.isNotEmpty) {
            variables[storeAs] = value.toString();
          }
          variables['$scope.$referenceKey'] = value.toString();
          if (rawKey.isNotEmpty && rawKey != referenceKey) {
            variables['$scope.$rawKey'] = value.toString();
          }
          results[resultKey] = value.toString();
          break;
        case BotCreatorActionType.removeScopedVariable:
          final scope =
              resolveValue((action.payload['scope'] ?? '').toString()).trim();
          if (!_supportedVariableScopes.contains(scope)) {
            throw Exception(
              'scope is required for removeScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
            );
          }

          final rawKey =
              resolveValue((action.payload['key'] ?? '').toString()).trim();
          final storageKey = _scopedStorageKey(rawKey);
          final referenceKey = _scopedReferenceKey(rawKey);

          final contextId = _resolveScopeContextId(
            scope: scope,
            variables: variables,
            guildId: guildId,
            channelId: resolvedFallbackChannelId,
            interaction: interaction,
          );
          if (contextId == null || contextId.trim().isEmpty) {
            throw Exception('Unable to resolve context ID for scope "$scope"');
          }

          await manager.removeScopedVariable(
            botId,
            scope,
            contextId,
            storageKey,
          );
          if (referenceKey != storageKey) {
            await manager.removeScopedVariable(
              botId,
              scope,
              contextId,
              referenceKey,
            );
          }
          variables.remove('$scope.$referenceKey');
          if (rawKey.isNotEmpty && rawKey != referenceKey) {
            variables.remove('$scope.$rawKey');
          }
          results[resultKey] = 'REMOVED';
          break;
        case BotCreatorActionType.renameScopedVariable:
          final scope =
              resolveValue((action.payload['scope'] ?? '').toString()).trim();
          if (!_supportedVariableScopes.contains(scope)) {
            throw Exception(
              'scope is required for renameScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
            );
          }

          final oldRawKey =
              resolveValue((action.payload['oldKey'] ?? '').toString()).trim();
          final newRawKey =
              resolveValue((action.payload['newKey'] ?? '').toString()).trim();
          final oldStorageKey = _scopedStorageKey(oldRawKey);
          final newStorageKey = _scopedStorageKey(newRawKey);
          final oldReferenceKey = _scopedReferenceKey(oldRawKey);
          final newReferenceKey = _scopedReferenceKey(newRawKey);

          final contextId = _resolveScopeContextId(
            scope: scope,
            variables: variables,
            guildId: guildId,
            channelId: resolvedFallbackChannelId,
            interaction: interaction,
          );
          if (contextId == null || contextId.trim().isEmpty) {
            throw Exception('Unable to resolve context ID for scope "$scope"');
          }

          await manager.renameScopedVariable(
            botId,
            scope,
            contextId,
            oldStorageKey,
            newStorageKey,
          );
          if (oldReferenceKey != oldStorageKey) {
            final legacyValue = await manager.getScopedVariable(
              botId,
              scope,
              contextId,
              oldReferenceKey,
            );
            if (legacyValue != null) {
              await manager.setScopedVariable(
                botId,
                scope,
                contextId,
                newStorageKey,
                legacyValue,
              );
              await manager.removeScopedVariable(
                botId,
                scope,
                contextId,
                oldReferenceKey,
              );
            }
          }
          final oldRuntimeKey = '$scope.$oldReferenceKey';
          final newRuntimeKey = '$scope.$newReferenceKey';
          if (variables.containsKey(oldRuntimeKey)) {
            final runtimeValue = variables.remove(oldRuntimeKey);
            if (runtimeValue != null) {
              variables[newRuntimeKey] = runtimeValue;
              if (oldRawKey.isNotEmpty && oldRawKey != oldReferenceKey) {
                variables.remove('$scope.$oldRawKey');
              }
              if (newRawKey.isNotEmpty && newRawKey != newReferenceKey) {
                variables['$scope.$newRawKey'] = runtimeValue;
              }
            }
          }
          results[resultKey] = 'RENAMED';
          break;
        case BotCreatorActionType.httpRequest:
        case BotCreatorActionType.runWorkflow:
        case BotCreatorActionType.stopUnless:
        case BotCreatorActionType.ifBlock:
          throw StateError(
            'Action ${action.type.name} should have been handled by an executor before switch dispatch.',
          );
        case BotCreatorActionType.setGlobalVariable:
          final key =
              resolveValue((action.payload['key'] ?? '').toString()).trim();
          if (key.isEmpty) {
            throw Exception('key is required for setGlobalVariable');
          }
          final value = _resolveVariableValuePayload(
            action.payload,
            resolveValue,
          );
          await manager.setGlobalVariable(botId, key, value);
          variables['global.$key'] = value.toString();
          results[resultKey] = 'OK';
          break;
        case BotCreatorActionType.getGlobalVariable:
          final key =
              resolveValue((action.payload['key'] ?? '').toString()).trim();
          if (key.isEmpty) {
            throw Exception('key is required for getGlobalVariable');
          }
          final value = await manager.getGlobalVariable(botId, key) ?? '';
          final valueAsString = value.toString();
          final storeAs =
              resolveValue(
                (action.payload['storeAs'] ?? 'global.$key').toString(),
              ).trim();
          if (storeAs.isNotEmpty) {
            variables[storeAs] = valueAsString;
          }
          variables['global.$key'] = valueAsString;
          results[resultKey] = valueAsString;
          break;
        case BotCreatorActionType.removeGlobalVariable:
          final key =
              resolveValue((action.payload['key'] ?? '').toString()).trim();
          if (key.isEmpty) {
            throw Exception('key is required for removeGlobalVariable');
          }
          await manager.removeGlobalVariable(botId, key);
          variables.remove('global.$key');
          results[resultKey] = 'REMOVED';
          break;
        case BotCreatorActionType.calculate:
        case BotCreatorActionType.getMessage:
        case BotCreatorActionType.unpinMessage:
        case BotCreatorActionType.createPoll:
        case BotCreatorActionType.endPoll:
        case BotCreatorActionType.createInvite:
        case BotCreatorActionType.deleteInvite:
        case BotCreatorActionType.getInvite:
        case BotCreatorActionType.moveToVoiceChannel:
        case BotCreatorActionType.disconnectFromVoice:
        case BotCreatorActionType.serverMuteMember:
        case BotCreatorActionType.serverDeafenMember:
        case BotCreatorActionType.createEmoji:
        case BotCreatorActionType.updateEmoji:
        case BotCreatorActionType.deleteEmoji:
        case BotCreatorActionType.createAutoModRule:
        case BotCreatorActionType.deleteAutoModRule:
        case BotCreatorActionType.listAutoModRules:
        case BotCreatorActionType.getGuildOnboarding:
        case BotCreatorActionType.updateGuildOnboarding:
        case BotCreatorActionType.updateSelfUser:
        case BotCreatorActionType.createThread:
        case BotCreatorActionType.editChannelPermissions:
        case BotCreatorActionType.deleteChannelPermission:
          final delegated = await shared_handler.handleActions(
            client,
            interaction,
            actions: <shared_types.Action>[
              shared_types.Action.fromJson(action.toJson()),
            ],
            store: manager,
            botId: botId,
            variables: variables,
            resolveTemplate: resolveTemplate,
            fallbackChannelId: resolvedFallbackChannelId,
            fallbackGuildId: guildId,
            workflowStack: activeWorkflowStack,
            onLog: onLog,
          );

          final delegatedValue =
              delegated[resultKey] ?? delegated['action_0'] ?? '';
          if (delegatedValue.startsWith('Error:')) {
            throw Exception(delegatedValue.substring('Error:'.length).trim());
          }

          results[resultKey] = delegatedValue;
          break;
      }
    } catch (e) {
      results[resultKey] = 'Error: $e';
      if (action.onErrorMode == ActionOnErrorMode.stop) {
        break;
      }
    }
  }
  return results;
}

/// Simplified action handler for workflows triggered by component/modal interactions.
/// These workflows don't have a slash command interaction context, so some action
/// types (e.g. respondWithModal) will not work and are simply skipped.
Future<Map<String, String>> handleListenerWorkflowActions(
  NyxxGateway client, {
  required List<Action> actions,
  required AppManager manager,
  required String botId,
  required Map<String, String> variables,
  required String Function(String input) resolveTemplate,
  Interaction? interaction,
}) async {
  return handleActions(
    client,
    interaction,
    actions: actions,
    manager: manager,
    botId: botId,
    variables: variables,
    resolveTemplate: resolveTemplate,
  );
}
