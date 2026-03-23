part of 'bot.dart';

String _runtimeVariableValueToString(dynamic value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is List || value is Map) {
    return jsonEncode(value);
  }
  return value.toString();
}

Future<void> _injectScopedCommandVariables({
  required AppManager manager,
  required String botId,
  required String scope,
  required String? contextId,
  required Map<String, String> runtimeVariables,
}) async {
  final normalizedContextId = (contextId ?? '').trim();
  if (normalizedContextId.isEmpty) {
    return;
  }

  final values = await manager.getScopedVariables(
    botId,
    scope,
    normalizedContextId,
  );
  for (final entry in values.entries) {
    final rawKey = entry.key.toString().trim();
    if (rawKey.isEmpty) {
      continue;
    }

    final canonicalKey = rawKey.startsWith('bc_') ? rawKey : 'bc_$rawKey';
    final value = _runtimeVariableValueToString(entry.value);
    runtimeVariables['$scope.$canonicalKey'] = value;
    runtimeVariables['$scope.$rawKey'] = value;
  }
}

@pragma('vm:entry-point')
Future<void> handleLocalCommands(
  InteractionCreateEvent event,
  AppManager manager,
) async {
  final interaction = event.interaction;
  final clientId = event.gateway.client.user.id.toString();
  if (interaction is ApplicationCommandInteraction) {
    appendBotLog('Command received: ${interaction.data.name}', botId: clientId);
    await _emitTaskLogToMain(
      'Command received: ${interaction.data.name}',
      botId: clientId,
    );
    final command = interaction.data;
    final action = await manager.getAppCommand(clientId, command.id.toString());
    appendBotDebugLog(
      'Command lookup id=${command.id} found=${action["id"] == command.id.toString()}',
      botId: clientId,
    );

    if (action["id"] == command.id.toString()) {
      final listOfArgs = await generateKeyValues(interaction);
      final runtimeVariables = <String, String>{...listOfArgs};
      final globalVars = await manager.getGlobalVariables(clientId);
      for (final entry in globalVars.entries) {
        runtimeVariables['global.${entry.key}'] = _runtimeVariableValueToString(
          entry.value,
        );
      }

      final dynamic rawInteraction = interaction;
      final guildContextId =
          runtimeVariables['guildId'] ?? rawInteraction.guildId?.toString();
      final channelContextId =
          runtimeVariables['channelId'] ??
          rawInteraction.channel?.id?.toString();
      final userContextId =
          runtimeVariables['userId'] ??
          rawInteraction.user?.id?.toString() ??
          rawInteraction.author?.id?.toString();
      final guildMemberContextId =
          (guildContextId != null &&
                  guildContextId.trim().isNotEmpty &&
                  userContextId != null &&
                  userContextId.trim().isNotEmpty)
              ? '${guildContextId.trim()}:${userContextId.trim()}'
              : null;
      final messageContextId =
          runtimeVariables['messageId'] ??
          runtimeVariables['message.id'] ??
          rawInteraction.message?.id?.toString();

      await _injectScopedCommandVariables(
        manager: manager,
        botId: clientId,
        scope: 'guild',
        contextId: guildContextId,
        runtimeVariables: runtimeVariables,
      );
      await _injectScopedCommandVariables(
        manager: manager,
        botId: clientId,
        scope: 'channel',
        contextId: channelContextId,
        runtimeVariables: runtimeVariables,
      );
      await _injectScopedCommandVariables(
        manager: manager,
        botId: clientId,
        scope: 'user',
        contextId: userContextId,
        runtimeVariables: runtimeVariables,
      );
      await _injectScopedCommandVariables(
        manager: manager,
        botId: clientId,
        scope: 'guildMember',
        contextId: guildMemberContextId,
        runtimeVariables: runtimeVariables,
      );
      await _injectScopedCommandVariables(
        manager: manager,
        botId: clientId,
        scope: 'message',
        contextId: messageContextId,
        runtimeVariables: runtimeVariables,
      );

      appendBotDebugLog(
        'Runtime variables built: ${runtimeVariables.length}',
        botId: clientId,
      );

      final normalized = manager.normalizeCommandData(
        Map<String, dynamic>.from(action),
      );
      final value = Map<String, dynamic>.from(
        (normalized["data"] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final response = Map<String, dynamic>.from(
        (value["response"] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final workflow = Map<String, dynamic>.from(
        (response['workflow'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final workflowConditional = Map<String, dynamic>.from(
        (workflow['conditional'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

      // Récupérer les actions : d'abord de la commande, puis du workflow sauvegardé si spécifié
      var actionsJson = List<Map<String, dynamic>>.from(
        (value["actions"] as List?)?.whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ) ??
            const [],
      );

      appendBotDebugLog(
        'Actions found in command: ${actionsJson.length}',
        botId: clientId,
      );
      if (actionsJson.isNotEmpty) {
        for (var i = 0; i < actionsJson.length; i++) {
          final action = actionsJson[i];
          appendBotDebugLog(
            'Action $i: type=${action["type"]}, enabled=${action["enabled"]}',
            botId: clientId,
          );
        }
      }

      // Si un workflow sauvegardé est spécifié, le charger et utiliser ses actions
      final workflowName = (workflow['name'] ?? '').toString().trim();
      if (workflowName.isNotEmpty && actionsJson.isEmpty) {
        try {
          final savedWorkflows = await manager.getWorkflows(clientId);
          final savedWorkflow = savedWorkflows.firstWhere(
            (w) =>
                (w['name'] ?? '').toString().toLowerCase() ==
                workflowName.toLowerCase(),
            orElse: () => <String, dynamic>{},
          );
          if (savedWorkflow.isNotEmpty) {
            actionsJson = List<Map<String, dynamic>>.from(
              (savedWorkflow['actions'] as List?)?.whereType<Map>().map(
                    (e) => Map<String, dynamic>.from(e),
                  ) ??
                  const [],
            );
            appendBotDebugLog(
              'Saved workflow loaded: $workflowName with ${actionsJson.length} actions',
              botId: clientId,
            );
          }
        } catch (e) {
          appendBotDebugLog(
            'Error loading workflow $workflowName: $e',
            botId: clientId,
          );
        }
      }

      final responseType = (response['type'] ?? 'normal').toString();
      final isBaseModal = responseType == 'modal';

      final whenTrueType =
          (workflowConditional['whenTrueType'] ?? 'normal').toString();
      final whenFalseType =
          (workflowConditional['whenFalseType'] ?? 'normal').toString();
      final useCondition = workflowConditional['enabled'] == true;
      final isConditionalModal =
          useCondition && (whenTrueType == 'modal' || whenFalseType == 'modal');

      final shouldDefer =
          actionsJson.isNotEmpty &&
          workflow['autoDeferIfActions'] != false &&
          !isBaseModal &&
          !isConditionalModal;
      final isEphemeral =
          workflow['visibility']?.toString().toLowerCase() == 'ephemeral';

      var didDefer = false;

      try {
        if (shouldDefer) {
          int deferFlags = isEphemeral ? 64 : 0;
          if (responseType == 'componentV2' ||
              (useCondition &&
                  (whenTrueType == 'componentV2' ||
                      whenFalseType == 'componentV2'))) {
            deferFlags |= 32768; // IS_COMPONENTS_V2
          }

          if (deferFlags == 0 || deferFlags == 64) {
            await interaction.acknowledge(isEphemeral: isEphemeral);
          } else {
            final builder = InteractionResponseBuilder(
              type: InteractionCallbackType.deferredChannelMessageWithSource,
              data: {'flags': deferFlags},
            );
            await interaction.manager.createResponse(
              interaction.id,
              interaction.token,
              builder,
            );
          }

          didDefer = true;
          appendBotLog('Response deferred (defer ACK)', botId: clientId);
          await _emitTaskLogToMain(
            'Response deferred (defer ACK)',
            botId: clientId,
          );
        }

        if (actionsJson.isNotEmpty) {
          appendBotDebugLog(
            'Actions to execute: ${actionsJson.length}',
            botId: clientId,
          );
          try {
            final actions = actionsJson.map(Action.fromJson).toList();
            appendBotDebugLog(
              'Actions converted to Action objects: ${actions.length}',
              botId: clientId,
            );
            final actionResults = await handleActions(
              event.gateway.client,
              interaction,
              actions: actions,
              store: manager,
              botId: clientId,
              variables: runtimeVariables,
              resolveTemplate:
                  (input) => updateString(
                    input,
                    Map<String, String>.from(runtimeVariables),
                  ),
              onLog: (msg) {
                appendBotLog(msg, botId: clientId);
                unawaited(_emitTaskLogToMain(msg, botId: clientId));
              },
            );
            appendBotDebugLog(
              'Actions executed, results: ${actionResults.length}',
              botId: clientId,
            );
            for (final entry in actionResults.entries) {
              runtimeVariables['action.${entry.key}'] = entry.value;
            }
            // Debug: log all action.* variables (include counts even if '0')
            final actionVars =
                runtimeVariables.entries
                    .where((e) => e.key.startsWith('action.'))
                    .map((e) => '${e.key}=${e.value}')
                    .toList();
            appendBotDebugLog(
              'Action runtime variables: $actionVars',
              botId: clientId,
            );
          } catch (e, st) {
            appendBotDebugLog('Error executing actions: $e', botId: clientId);
            appendBotDebugLog('Stack: $st', botId: clientId);
          }
        }

        await sendWorkflowResponse(
          interaction: interaction,
          response: response,
          runtimeVariables: runtimeVariables,
          botId: clientId,
          didDefer: didDefer,
          isEphemeral: isEphemeral,
          onLog: (msg, {required botId}) async {
            appendBotLog(msg, botId: botId);
          },
          onDebugLog: (msg, {required botId}) async {
            appendBotDebugLog(msg, botId: botId);
          },
        );
      } catch (error, stackTrace) {
        appendBotLog('Command workflow error: $error', botId: clientId);
        appendBotDebugLog('$stackTrace', botId: clientId);
        final errorText = 'An error occurred while executing this command.';

        try {
          if (didDefer) {
            await interaction.updateOriginalResponse(
              MessageUpdateBuilder(
                content: errorText,
                embeds: const <EmbedBuilder>[],
              ),
            );
          } else {
            await interaction.respond(
              MessageBuilder(
                content: errorText,
                flags: isEphemeral ? MessageFlags.ephemeral : null,
              ),
            );
          }
        } catch (sendError) {
          appendBotLog(
            'Failed to send error message: $sendError',
            botId: clientId,
          );
        }
      }

      return;
    } else {
      await interaction.respond(MessageBuilder(content: "Command not found"));
      appendBotLog('Command not found', botId: clientId);
      await _emitTaskLogToMain('Command not found', botId: clientId);
      return;
    }
  } else if (interaction is MessageComponentInteraction) {
    // Route to the interaction listener registry
    await handleComponentInteraction(
      event.gateway.client,
      interaction,
      manager,
    );
  } else if (interaction is ModalSubmitInteraction) {
    // Route modal submit to the interaction listener registry
    await handleModalSubmitInteraction(
      event.gateway.client,
      interaction,
      manager,
    );
  }
}
