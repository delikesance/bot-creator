import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../../utils/interaction_listener_registry.dart';
import '../../utils/workflow_call.dart';
import '../edit_component_v2.dart';
import '../edit_interaction_response.dart';
import '../respond_modal.dart';
import '../respond_with_message.dart';
import '../send_component_v2.dart';

Future<bool> executeComponentsInteractionsAction({
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
    case BotCreatorActionType.sendComponentV2:
      final result = await sendComponentV2Action(
        client,
        payload: payload,
        fallbackChannelId: fallbackChannelId,
        resolve: resolveValue,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      return true;

    case BotCreatorActionType.editComponentV2:
      final result = await editComponentV2Action(client, payload: payload);
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      return true;

    case BotCreatorActionType.respondWithComponentV2:
      if (interaction == null) {
        results[resultKey] =
            'Error: respondWithComponentV2 requires an interaction context';
        return true;
      }
      final respResult = await respondWithComponentV2Action(
        interaction,
        payload: payload,
        resolve: resolveValue,
        botId: botId,
      );
      if (respResult['error'] != null) {
        throw Exception(respResult['error']);
      }
      results[resultKey] = respResult['messageId'] ?? 'responded';
      return true;

    case BotCreatorActionType.respondWithMessage:
      if (interaction == null) {
        results[resultKey] =
            'Error: respondWithMessage requires an interaction context';
        return true;
      }
      final messageResult = await respondWithMessageAction(
        interaction,
        payload: payload,
        resolve: resolveValue,
        botId: botId,
      );
      if (messageResult['error'] != null) {
        throw Exception(messageResult['error']);
      }
      results[resultKey] = messageResult['messageId'] ?? 'responded';
      return true;

    case BotCreatorActionType.respondWithModal:
      if (interaction == null) {
        results[resultKey] =
            'Error: respondWithModal requires a slash command interaction';
        return true;
      }
      final modalResult = await respondWithModalAction(
        interaction,
        payload: payload,
        resolve: resolveValue,
      );
      if (modalResult['error'] != null) {
        throw Exception(modalResult['error']);
      }
      final customId = modalResult['customId'] ?? 'modal_sent';
      results[resultKey] = customId;

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
            channelId: fallbackChannelId?.toString(),
          ),
        );
      }
      return true;

    case BotCreatorActionType.editInteractionMessage:
      if (interaction == null) {
        results[resultKey] =
            'Error: editInteractionMessage requires an interaction context';
        return true;
      }
      final editResult = await editInteractionMessageAction(
        interaction,
        payload: payload,
        resolve: resolveValue,
      );
      if (editResult['error'] != null) {
        throw Exception(editResult['error']);
      }
      results[resultKey] = editResult['messageId'] ?? '';
      return true;

    case BotCreatorActionType.listenForButtonClick:
    case BotCreatorActionType.listenForModalSubmit:
      final customId = resolveValue((payload['customId'] ?? '').toString());
      if (customId.isEmpty) {
        throw Exception('customId is required for ${type.name}');
      }
      final workflowName = resolveValue(
        (payload['workflowName'] ?? '').toString(),
      );
      if (workflowName.isEmpty) {
        throw Exception('workflowName is required for ${type.name}');
      }
      final ttlRaw = payload['ttlMinutes'];
      final ttlMinutes = (ttlRaw is num
              ? ttlRaw.toInt()
              : int.tryParse(ttlRaw?.toString() ?? '') ?? 60)
          .clamp(1, 60);
      final oneShot =
          type == BotCreatorActionType.listenForModalSubmit
              ? true
              : (payload['oneShot'] != false);
      final workflowEntryPoint =
          resolveValue((payload['entryPoint'] ?? '').toString()).trim();
      final workflowArguments = resolveWorkflowCallArguments(
        payload['arguments'],
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
              type == BotCreatorActionType.listenForButtonClick
                  ? 'button'
                  : 'modal',
          oneShot: oneShot,
          guildId: guildId?.toString(),
          channelId: fallbackChannelId?.toString(),
        ),
      );
      results[resultKey] = 'listening:$customId';
      return true;

    default:
      return false;
  }
}
