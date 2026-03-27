import 'package:bot_creator_shared/actions/pin_message.dart';
import 'package:bot_creator_shared/actions/update_automod.dart';
import 'package:bot_creator_shared/actions/update_guild.dart';
import 'package:bot_creator_shared/actions/list_members.dart';
import 'package:bot_creator_shared/actions/get_member.dart';
import 'package:bot_creator_shared/actions/unpin_message.dart';
import 'package:bot_creator_shared/actions/poll_management.dart';
import 'package:bot_creator_shared/actions/invite_management.dart';
import 'package:bot_creator_shared/actions/voice_management.dart';
import 'package:bot_creator_shared/actions/emoji_management.dart';
import 'package:bot_creator_shared/actions/automod_management.dart';
import 'package:bot_creator_shared/actions/guild_onboarding.dart';
import 'package:bot_creator_shared/actions/update_self_user.dart';
import 'package:bot_creator_shared/actions/thread_management.dart';
import 'package:bot_creator_shared/actions/channel_permissions.dart';
import 'package:bot_creator_shared/actions/permission_checks.dart';
import 'package:bot_creator_shared/actions/executors/messaging_executor.dart';
import 'package:bot_creator_shared/actions/executors/moderation_roles_executor.dart';
import 'package:bot_creator_shared/actions/executors/reactions_executor.dart';
import 'package:bot_creator_shared/actions/executors/channels_executor.dart';
import 'package:bot_creator_shared/actions/executors/calculate_executor.dart';
import 'package:bot_creator_shared/actions/executors/components_interactions_executor.dart';
import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/actions/executors/http_executor.dart';
import 'package:bot_creator_shared/actions/executors/variables_executor.dart';
import 'package:bot_creator_shared/actions/executors/webhooks_executor.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:nyxx/nyxx.dart';
import '../types/action.dart';

// Helper functions for common action patterns

Future<Map<String, String>> handleActions(
  NyxxGateway client,
  Interaction? interaction, {
  required List<Action> actions,
  required BotDataStore store,
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

    final handledByMessagingExecutor = await executeMessagingAction(
      type: action.type,
      client: client,
      interaction: interaction,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      variables: variables,
      botId: botId,
      guildId: guildId,
      fallbackChannelId: resolvedFallbackChannelId,
      resolveValue: resolveValue,
    );
    if (handledByMessagingExecutor) {
      continue;
    }

    final handledByReactionsExecutor = await executeReactionsAction(
      type: action.type,
      client: client,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      fallbackChannelId: resolvedFallbackChannelId,
      guildId: guildId,
    );
    if (handledByReactionsExecutor) {
      continue;
    }

    final handledByModerationRolesExecutor = await executeModerationRolesAction(
      type: action.type,
      client: client,
      guildId: guildId,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
    );
    if (handledByModerationRolesExecutor) {
      continue;
    }

    final handledByChannelsExecutor = await executeChannelsAction(
      type: action.type,
      client: client,
      guildId: guildId,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      resolveValue: resolveValue,
    );
    if (handledByChannelsExecutor) {
      continue;
    }

    final handledByWebhooksExecutor = await executeWebhooksAction(
      type: action.type,
      client: client,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      fallbackChannelId: fallbackChannelId,
      fallbackGuildId: guildId,
      resolveValue: resolveValue,
    );
    if (handledByWebhooksExecutor) {
      continue;
    }

    final handledByComponentsInteractionsExecutor =
        await executeComponentsInteractionsAction(
          type: action.type,
          client: client,
          interaction: interaction,
          payload: action.payload,
          resultKey: resultKey,
          results: results,
          variables: variables,
          botId: botId,
          guildId: guildId,
          fallbackChannelId: fallbackChannelId,
          resolveValue: resolveValue,
        );
    if (handledByComponentsInteractionsExecutor) {
      continue;
    }

    final handledByVariablesExecutor = await executeVariablesAction(
      type: action.type,
      store: store,
      botId: botId,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      variables: variables,
      resolveValue: resolveValue,
      guildId: guildId,
      fallbackChannelId: fallbackChannelId,
      interaction: interaction,
    );
    if (handledByVariablesExecutor) {
      if (results.containsKey('__stopped__')) {
        return results;
      }
      continue;
    }

    final handledByControlFlowExecutor = await executeControlFlowAction(
      type: action.type,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      variables: variables,
      resolveValue: resolveValue,
      onLog: onLog,
      activeWorkflowStack: activeWorkflowStack,
      getWorkflowByName:
          (workflowName) => store.getWorkflowByName(botId, workflowName),
      executeActions:
          (nestedActions) => handleActions(
            client,
            interaction,
            actions: nestedActions,
            store: store,
            botId: botId,
            variables: variables,
            resolveTemplate: resolveTemplate,
            fallbackChannelId: resolvedFallbackChannelId,
            fallbackGuildId: guildId,
            workflowStack: activeWorkflowStack,
            onLog: onLog,
          ),
    );
    if (handledByControlFlowExecutor) {
      if (results.containsKey('__stopped__')) {
        return results;
      }
      continue;
    }

    final handledByHttpExecutor = await executeHttpAction(
      type: action.type,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      variables: variables,
      resolveValue: resolveValue,
      onLog: onLog,
      setGlobalVariable:
          (key, value) => store.setGlobalVariable(botId, key, value),
    );
    if (handledByHttpExecutor) continue;

    final handledByCalculateExecutor = await executeCalculateAction(
      type: action.type,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      variables: variables,
      resolveValue: resolveValue,
    );
    if (handledByCalculateExecutor) continue;

    try {
      switch (action.type) {
        case BotCreatorActionType.deleteMessages:
        case BotCreatorActionType.createChannel:
        case BotCreatorActionType.updateChannel:
        case BotCreatorActionType.removeChannel:
        case BotCreatorActionType.sendMessage:
        case BotCreatorActionType.editMessage:
        case BotCreatorActionType.getMessage:
        case BotCreatorActionType.addReaction:
        case BotCreatorActionType.removeReaction:
        case BotCreatorActionType.clearAllReactions:
        case BotCreatorActionType.banUser:
        case BotCreatorActionType.unbanUser:
        case BotCreatorActionType.kickUser:
        case BotCreatorActionType.muteUser:
        case BotCreatorActionType.unmuteUser:
        case BotCreatorActionType.addRole:
        case BotCreatorActionType.removeRole:
        case BotCreatorActionType.sendWebhook:
        case BotCreatorActionType.editWebhook:
        case BotCreatorActionType.deleteWebhook:
        case BotCreatorActionType.listWebhooks:
        case BotCreatorActionType.getWebhook:
        case BotCreatorActionType.sendComponentV2:
        case BotCreatorActionType.editComponentV2:
        case BotCreatorActionType.respondWithComponentV2:
        case BotCreatorActionType.respondWithMessage:
        case BotCreatorActionType.respondWithModal:
        case BotCreatorActionType.editInteractionMessage:
        case BotCreatorActionType.listenForButtonClick:
        case BotCreatorActionType.listenForSelectMenu:
        case BotCreatorActionType.listenForModalSubmit:
        case BotCreatorActionType.setScopedVariable:
        case BotCreatorActionType.getScopedVariable:
        case BotCreatorActionType.removeScopedVariable:
        case BotCreatorActionType.renameScopedVariable:
        case BotCreatorActionType.listScopedVariableIndex:
        case BotCreatorActionType.appendArrayElement:
        case BotCreatorActionType.removeArrayElement:
        case BotCreatorActionType.queryArray:
        case BotCreatorActionType.setGlobalVariable:
        case BotCreatorActionType.getGlobalVariable:
        case BotCreatorActionType.removeGlobalVariable:
        case BotCreatorActionType.respondWithAutocomplete:
        case BotCreatorActionType.httpRequest:
        case BotCreatorActionType.runWorkflow:
        case BotCreatorActionType.stopUnless:
        case BotCreatorActionType.ifBlock:
        case BotCreatorActionType.calculate:
          throw StateError(
            'Action ${action.type.name} should have been handled by an executor before switch dispatch.',
          );
        case BotCreatorActionType.pinMessage:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageMessages],
              actionLabel: 'pin messages',
            );
            if (permError != null) throw Exception(permError);
          }
          final result = await pinMessageAction(
            client,
            payload: action.payload,
            fallbackChannelId: fallbackChannelId,
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
            resolve: resolveValue,
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
        case BotCreatorActionType.unpinMessage:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageMessages],
              actionLabel: 'unpin messages',
            );
            if (permError != null) throw Exception(permError);
          }
          final unpinResult = await unpinMessageAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
          );
          if (unpinResult['error'] != null) {
            throw Exception(unpinResult['error']);
          }
          results[resultKey] = unpinResult['status'] ?? 'unpinned';
          break;

        // ─── Polls ────────────────────────────────────────────────────────
        case BotCreatorActionType.createPoll:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.sendMessages],
              actionLabel: 'create polls',
            );
            if (permError != null) throw Exception(permError);
          }
          final pollResult = await createPollAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            resolve: resolveValue,
          );
          if (pollResult['error'] != null) {
            throw Exception(pollResult['error']);
          }
          results[resultKey] = pollResult['messageId'] ?? '';
          variables['$resultKey.messageId'] = pollResult['messageId'] ?? '';
          variables['$resultKey.pollId'] = pollResult['pollId'] ?? '';
          break;

        case BotCreatorActionType.endPoll:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageMessages],
              actionLabel: 'end polls',
            );
            if (permError != null) throw Exception(permError);
          }
          final endPollResult = await endPollAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
          );
          if (endPollResult['error'] != null) {
            throw Exception(endPollResult['error']);
          }
          results[resultKey] = endPollResult['status'] ?? 'ended';
          break;

        // ─── Invitations ──────────────────────────────────────────────────
        case BotCreatorActionType.createInvite:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.createInstantInvite],
              actionLabel: 'create invites',
            );
            if (permError != null) throw Exception(permError);
          }
          final ciResult = await createInviteAction(
            client,
            payload: action.payload,
            resolve: resolveValue,
            fallbackChannelId: resolvedFallbackChannelId,
          );
          if (ciResult['error'] != null) {
            throw Exception(ciResult['error']);
          }
          results[resultKey] = ciResult['inviteCode'] ?? '';
          for (final entry in ciResult.entries) {
            variables['$resultKey.${entry.key}'] = entry.value;
          }
          break;

        case BotCreatorActionType.deleteInvite:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageChannels],
              actionLabel: 'delete invites',
            );
            if (permError != null) throw Exception(permError);
          }
          final diResult = await deleteInviteAction(
            client,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (diResult['error'] != null) {
            throw Exception(diResult['error']);
          }
          results[resultKey] = diResult['status'] ?? 'deleted';
          break;

        case BotCreatorActionType.getInvite:
          final giResult = await getInviteAction(
            client,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (giResult['error'] != null) {
            throw Exception(giResult['error']);
          }
          results[resultKey] = giResult['inviteCode'] ?? '';
          for (final entry in giResult.entries) {
            variables['$resultKey.${entry.key}'] = entry.value;
          }
          break;

        // ─── Voice management ─────────────────────────────────────────────
        case BotCreatorActionType.moveToVoiceChannel:
          final mvResult = await moveToVoiceChannelAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (mvResult['error'] != null) {
            throw Exception(mvResult['error']);
          }
          results[resultKey] = mvResult['status'] ?? 'moved';
          break;

        case BotCreatorActionType.disconnectFromVoice:
          final dvResult = await disconnectFromVoiceAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (dvResult['error'] != null) {
            throw Exception(dvResult['error']);
          }
          results[resultKey] = dvResult['status'] ?? 'disconnected';
          break;

        case BotCreatorActionType.serverMuteMember:
          final smResult = await serverMuteMemberAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (smResult['error'] != null) {
            throw Exception(smResult['error']);
          }
          results[resultKey] = smResult['status'] ?? 'muted';
          break;

        case BotCreatorActionType.serverDeafenMember:
          final sdResult = await serverDeafenMemberAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (sdResult['error'] != null) {
            throw Exception(sdResult['error']);
          }
          results[resultKey] = sdResult['status'] ?? 'deafened';
          break;

        // ─── Emoji management ─────────────────────────────────────────────
        case BotCreatorActionType.createEmoji:
          final ceResult = await createEmojiAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (ceResult['error'] != null) {
            throw Exception(ceResult['error']);
          }
          results[resultKey] = ceResult['emojiId'] ?? '';
          for (final entry in ceResult.entries) {
            variables['$resultKey.${entry.key}'] = entry.value;
          }
          break;

        case BotCreatorActionType.updateEmoji:
          final ueResult = await updateEmojiAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (ueResult['error'] != null) {
            throw Exception(ueResult['error']);
          }
          results[resultKey] = ueResult['emojiId'] ?? '';
          for (final entry in ueResult.entries) {
            variables['$resultKey.${entry.key}'] = entry.value;
          }
          break;

        case BotCreatorActionType.deleteEmoji:
          final deResult = await deleteEmojiAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (deResult['error'] != null) {
            throw Exception(deResult['error']);
          }
          results[resultKey] = deResult['status'] ?? 'deleted';
          break;

        // ─── AutoMod management ───────────────────────────────────────────
        case BotCreatorActionType.createAutoModRule:
          final camResult = await createAutoModRuleAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (camResult['error'] != null) {
            throw Exception(camResult['error']);
          }
          results[resultKey] = camResult['ruleId'] ?? '';
          variables['$resultKey.ruleId'] = camResult['ruleId'] ?? '';
          variables['$resultKey.name'] = camResult['name'] ?? '';
          break;

        case BotCreatorActionType.deleteAutoModRule:
          final damResult = await deleteAutoModRuleAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (damResult['error'] != null) {
            throw Exception(damResult['error']);
          }
          results[resultKey] = damResult['status'] ?? 'deleted';
          break;

        case BotCreatorActionType.listAutoModRules:
          final lamResult = await listAutoModRulesAction(
            client,
            guildId: guildId,
          );
          if (lamResult['error'] != null) {
            throw Exception(lamResult['error']);
          }
          results[resultKey] = lamResult['rulesJson'] ?? '[]';
          variables['$resultKey.rulesJson'] = lamResult['rulesJson'] ?? '[]';
          variables['$resultKey.count'] = lamResult['count'] ?? '0';
          break;

        // ─── Guild Onboarding ─────────────────────────────────────────────
        case BotCreatorActionType.getGuildOnboarding:
          final goResult = await getGuildOnboardingAction(
            client,
            guildId: guildId,
          );
          if (goResult['error'] != null) {
            throw Exception(goResult['error']);
          }
          results[resultKey] = goResult['onboardingJson'] ?? '{}';
          variables['$resultKey.onboardingJson'] =
              goResult['onboardingJson'] ?? '{}';
          variables['$resultKey.enabled'] = goResult['enabled'] ?? 'false';
          break;

        case BotCreatorActionType.updateGuildOnboarding:
          final ugoResult = await updateGuildOnboardingAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (ugoResult['error'] != null) {
            throw Exception(ugoResult['error']);
          }
          results[resultKey] = ugoResult['status'] ?? 'updated';
          break;

        // ─── Self user ────────────────────────────────────────────────────
        case BotCreatorActionType.updateSelfUser:
          final suResult = await updateSelfUserAction(
            client,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (suResult['error'] != null) {
            throw Exception(suResult['error']);
          }
          results[resultKey] = suResult['status'] ?? 'updated';
          variables['$resultKey.username'] = suResult['username'] ?? '';
          variables['$resultKey.userId'] = suResult['userId'] ?? '';
          break;

        // ─── Thread management ────────────────────────────────────────────
        case BotCreatorActionType.createThread:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.createPublicThreads],
              actionLabel: 'create threads',
            );
            if (permError != null) throw Exception(permError);
          }
          final ctResult = await createThreadAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            resolve: resolveValue,
          );
          if (ctResult['error'] != null) {
            throw Exception(ctResult['error']);
          }
          results[resultKey] = ctResult['threadId'] ?? '';
          variables['$resultKey.threadId'] = ctResult['threadId'] ?? '';
          variables['$resultKey.name'] = ctResult['name'] ?? '';
          variables['$resultKey.parentId'] = ctResult['parentId'] ?? '';
          break;

        // ─── Channel permissions ──────────────────────────────────────────
        case BotCreatorActionType.editChannelPermissions:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageRoles],
              actionLabel: 'edit channel permissions',
            );
            if (permError != null) throw Exception(permError);
          }
          final ecpResult = await editChannelPermissionsAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            resolve: resolveValue,
          );
          if (ecpResult['error'] != null) {
            throw Exception(ecpResult['error']);
          }
          results[resultKey] = ecpResult['status'] ?? 'updated';
          break;

        case BotCreatorActionType.deleteChannelPermission:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageRoles],
              actionLabel: 'delete channel permissions',
            );
            if (permError != null) throw Exception(permError);
          }
          final dcpResult = await deleteChannelPermissionAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            resolve: resolveValue,
          );
          if (dcpResult['error'] != null) {
            throw Exception(dcpResult['error']);
          }
          results[resultKey] = dcpResult['status'] ?? 'deleted';
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
  required BotDataStore store,
  required String botId,
  required Map<String, String> variables,
  required String Function(String input) resolveTemplate,
  Interaction? interaction,
}) async {
  return handleActions(
    client,
    interaction,
    actions: actions,
    store: store,
    botId: botId,
    variables: variables,
    resolveTemplate: resolveTemplate,
  );
}
