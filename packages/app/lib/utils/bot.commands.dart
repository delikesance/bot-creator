part of 'bot.dart';

// Route resolution functions are provided by
// package:bot_creator_shared/utils/command_workflow_routing.dart
// imported in bot.dart.

@pragma('vm:entry-point')
Future<void> handleLocalCommands(
  InteractionCreateEvent event,
  AppManager manager,
) async {
  final interaction = event.interaction;
  final clientId = event.gateway.client.user.id.toString();
  if (interaction is ApplicationCommandAutocompleteInteraction) {
    await _handleLocalCommandAutocomplete(
      event,
      manager,
      interaction,
      clientId,
    );
  } else if (interaction is ApplicationCommandInteraction) {
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
      unawaited(
        manager.recordCommandExecution(clientId, interaction.data.name),
      );
      final listOfArgs = await generateKeyValues(interaction);
      final runtimeVariables = <String, String>{...listOfArgs};
      final dynamic rawInteraction = interaction;
      String? normalizeContextId(String? value) {
        final trimmed = (value ?? '').trim();
        if (trimmed.isEmpty) {
          return null;
        }
        final lowered = trimmed.toLowerCase();
        if (lowered == 'unknown user' || lowered == 'dm') {
          return null;
        }
        return trimmed;
      }

      final guildContextId =
          normalizeContextId(runtimeVariables['guildId']) ??
          normalizeContextId(runtimeVariables['guild.id']) ??
          normalizeContextId(rawInteraction.guildId?.toString()) ??
          normalizeContextId(rawInteraction.guild?.id?.toString());
      final channelContextId =
          normalizeContextId(runtimeVariables['channelId']) ??
          normalizeContextId(runtimeVariables['channel.id']) ??
          normalizeContextId(rawInteraction.channelId?.toString()) ??
          normalizeContextId(rawInteraction.channel?.id?.toString()) ??
          normalizeContextId(rawInteraction.message?.channelId?.toString());
      final userContextId =
          normalizeContextId(runtimeVariables['userId']) ??
          normalizeContextId(runtimeVariables['user.id']) ??
          normalizeContextId(runtimeVariables['interaction.userId']) ??
          normalizeContextId(rawInteraction.user?.id?.toString()) ??
          normalizeContextId(rawInteraction.member?.user?.id?.toString()) ??
          normalizeContextId(rawInteraction.author?.id?.toString());
      final messageContextId =
          normalizeContextId(runtimeVariables['messageId']) ??
          normalizeContextId(runtimeVariables['message.id']) ??
          normalizeContextId(rawInteraction.message?.id?.toString()) ??
          normalizeContextId(rawInteraction.id?.toString());

      await hydrateRuntimeVariables(
        store: manager,
        botId: clientId,
        runtimeVariables: runtimeVariables,
        guildContextId: guildContextId,
        channelContextId: channelContextId,
        userContextId: userContextId,
        messageContextId: messageContextId,
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

      final subcommandRoute = resolveSubcommandRoute(command.options);
      runtimeVariables['interaction.command.route'] = subcommandRoute ?? '';

      final routePayload =
          (subcommandRoute == null)
              ? null
              : resolveSubcommandWorkflowPayload(value, subcommandRoute);
      final executionValue = routePayload ?? value;
      final executionMode =
          (value['executionMode'] ?? 'workflow')
              .toString()
              .trim()
              .toLowerCase();

      appendBotDebugLog(
        'Resolved command route=${subcommandRoute ?? '(none)'} payloadFound=${routePayload != null}',
        botId: clientId,
      );

      if (executionMode == 'bdfd_script') {
        final scriptSource =
            (executionValue['bdfdScriptContent'] ??
                    value['bdfdScriptContent'] ??
                    '')
                .toString();
        final compileResult = BdfdCompiler().compile(scriptSource);

        if (compileResult.hasErrors) {
          await sendWorkflowResponse(
            interaction: interaction,
            response: {
              'type': 'normal',
              'text': _formatBdfdRuntimeDiagnostics(compileResult.diagnostics),
              'embeds': const <Map<String, dynamic>>[],
              'components': const <String, dynamic>{},
              'modal': const <String, dynamic>{},
              'workflow': const {
                'visibility': 'ephemeral',
                'conditional': {'enabled': false},
              },
            },
            runtimeVariables: runtimeVariables,
            botId: clientId,
            isEphemeral: true,
            onLog:
                (msg, {required botId}) async =>
                    appendBotLog(msg, botId: botId),
            onDebugLog:
                (msg, {required botId}) async =>
                    appendBotDebugLog(msg, botId: botId),
          );
          return;
        }

        if (compileResult.actions.isEmpty) {
          await sendWorkflowResponse(
            interaction: interaction,
            response: {
              'type': 'normal',
              'text':
                  'This BDFD script compiled successfully but did not produce any action.',
              'embeds': const <Map<String, dynamic>>[],
              'components': const <String, dynamic>{},
              'modal': const <String, dynamic>{},
              'workflow': const {
                'visibility': 'ephemeral',
                'conditional': {'enabled': false},
              },
            },
            runtimeVariables: runtimeVariables,
            botId: clientId,
            isEphemeral: true,
            onLog:
                (msg, {required botId}) async =>
                    appendBotLog(msg, botId: botId),
            onDebugLog:
                (msg, {required botId}) async =>
                    appendBotDebugLog(msg, botId: botId),
          );
          return;
        }

        try {
          final actionResults = await handleActions(
            event.gateway.client,
            interaction,
            actions: compileResult.actions,
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
          for (final entry in actionResults.entries) {
            runtimeVariables['action.${entry.key}'] = entry.value;
          }
        } catch (e, st) {
          appendBotDebugLog(
            'Error executing BDFD actions: $e',
            botId: clientId,
          );
          appendBotDebugLog('Stack: $st', botId: clientId);
          await sendWorkflowResponse(
            interaction: interaction,
            response: {
              'type': 'normal',
              'text': 'An error occurred while executing this BDFD script.',
              'embeds': const <Map<String, dynamic>>[],
              'components': const <String, dynamic>{},
              'modal': const <String, dynamic>{},
              'workflow': const {
                'visibility': 'ephemeral',
                'conditional': {'enabled': false},
              },
            },
            runtimeVariables: runtimeVariables,
            botId: clientId,
            isEphemeral: true,
            onLog:
                (msg, {required botId}) async =>
                    appendBotLog(msg, botId: botId),
            onDebugLog:
                (msg, {required botId}) async =>
                    appendBotDebugLog(msg, botId: botId),
          );
        }
        return;
      }

      final response = Map<String, dynamic>.from(
        (executionValue["response"] as Map?)?.cast<String, dynamic>() ??
            const {},
      );
      final workflow = Map<String, dynamic>.from(
        (response['workflow'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final workflowConditional = Map<String, dynamic>.from(
        (workflow['conditional'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

      // Récupérer les actions : d'abord de la commande, puis du workflow sauvegardé si spécifié
      var actionsJson = List<Map<String, dynamic>>.from(
        (executionValue["actions"] as List?)?.whereType<Map>().map(
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
      clientId,
    );
  } else if (interaction is ModalSubmitInteraction) {
    // Route modal submit to the interaction listener registry
    await handleModalSubmitInteraction(
      event.gateway.client,
      interaction,
      manager,
      clientId,
    );
  }
}

Future<void> _handleLocalCommandAutocomplete(
  InteractionCreateEvent event,
  AppManager manager,
  ApplicationCommandAutocompleteInteraction interaction,
  String clientId,
) async {
  try {
    final command = interaction.data;
    final action = await manager.getAppCommand(clientId, command.id.toString());
    if (action['id'] != command.id.toString()) {
      await interaction.respond(const <CommandOptionChoiceBuilder<dynamic>>[]);
      return;
    }

    final normalized = manager.normalizeCommandData(
      Map<String, dynamic>.from(action),
    );
    final normalizedData = Map<String, dynamic>.from(
      (normalized['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final autocompleteConfig = resolveAutocompleteConfigForInteraction(
      storedOptions: normalizedData['options'],
      interactionOptions: interaction.data.options,
    );
    if (autocompleteConfig == null || autocompleteConfig['enabled'] != true) {
      await interaction.respond(const <CommandOptionChoiceBuilder<dynamic>>[]);
      return;
    }

    // Static options mode: filter pre-defined choices by user query.
    if ((autocompleteConfig['mode'] ?? 'workflow').toString() == 'static') {
      final focusedOption = findFocusedOption(interaction.data.options);
      final query =
          (focusedOption?.value?.toString() ?? '').toLowerCase().trim();
      final rawChoices = autocompleteConfig['staticChoices'];
      final choices = <CommandOptionChoiceBuilder<dynamic>>[];
      if (rawChoices is List) {
        for (final raw in rawChoices) {
          if (raw is! Map) continue;
          final name = (raw['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          if (query.isNotEmpty && !name.toLowerCase().contains(query)) {
            continue;
          }
          final value = raw['value'];
          choices.add(
            CommandOptionChoiceBuilder<dynamic>(
              name: name,
              value: value is num ? value : (value?.toString() ?? name),
            ),
          );
          if (choices.length >= 25) break;
        }
      }
      await interaction.respond(choices);
      return;
    }

    final workflowName =
        (autocompleteConfig['workflow'] ?? '').toString().trim();
    if (workflowName.isEmpty) {
      await interaction.respond(const <CommandOptionChoiceBuilder<dynamic>>[]);
      return;
    }

    final workflow = await manager.getWorkflowByName(clientId, workflowName);
    if (workflow == null) {
      await interaction.respond(const <CommandOptionChoiceBuilder<dynamic>>[]);
      return;
    }

    final normalizedWorkflow = normalizeStoredWorkflowDefinition(workflow);
    if (normalizeWorkflowType(normalizedWorkflow['workflowType']) !=
        workflowTypeGeneral) {
      await interaction.respond(const <CommandOptionChoiceBuilder<dynamic>>[]);
      return;
    }

    final focusedOption = findFocusedOption(interaction.data.options);
    final runtimeVariables = <String, String>{
      ...await generateKeyValues(interaction),
      'command.type': 'chatInput',
      'interaction.command.type': 'chatInput',
      'config.command.type': 'chatInput',
      'interaction.command.name': interaction.data.name,
      'interaction.command.id': interaction.data.id.toString(),
      'interaction.command.route':
          resolveSubcommandRoute(interaction.data.options) ?? '',
      'autocomplete.query': focusedOption?.value?.toString() ?? '',
      'autocomplete.optionName': focusedOption?.name ?? '',
      'autocomplete.optionType':
          focusedOption == null
              ? 'string'
              : commandOptionTypeToText(focusedOption.type),
      'workflow.type': workflowTypeGeneral,
    };
    final dynamic rawInteraction = interaction;

    await hydrateRuntimeVariables(
      store: manager,
      botId: clientId,
      runtimeVariables: runtimeVariables,
      guildContextId:
          runtimeVariables['guildId'] ?? rawInteraction.guildId?.toString(),
      channelContextId:
          runtimeVariables['channelId'] ??
          rawInteraction.channel?.id?.toString(),
      userContextId:
          runtimeVariables['userId'] ??
          rawInteraction.user?.id?.toString() ??
          rawInteraction.author?.id?.toString(),
      messageContextId:
          runtimeVariables['messageId'] ??
          runtimeVariables['message.id'] ??
          rawInteraction.message?.id?.toString(),
    );

    final providedArguments = resolveWorkflowCallArguments(
      autocompleteConfig['arguments'],
      (value) =>
          updateString(value, Map<String, String>.from(runtimeVariables)),
    );
    applyWorkflowInvocationContext(
      variables: runtimeVariables,
      workflowName: workflowName,
      entryPoint: normalizeWorkflowEntryPoint(
        autocompleteConfig['entryPoint'] ?? normalizedWorkflow['entryPoint'],
      ),
      definitions: parseWorkflowArgumentDefinitions(
        normalizedWorkflow['arguments'],
      ),
      providedArguments: providedArguments,
    );

    final actions = List<Action>.from(
      ((normalizedWorkflow['actions'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((json) => Action.fromJson(Map<String, dynamic>.from(json))),
    );
    if (actions.isEmpty) {
      await interaction.respond(const <CommandOptionChoiceBuilder<dynamic>>[]);
      return;
    }

    final actionResults = await handleActions(
      event.gateway.client,
      interaction,
      actions: actions,
      store: manager,
      botId: clientId,
      variables: runtimeVariables,
      resolveTemplate:
          (input) =>
              updateString(input, Map<String, String>.from(runtimeVariables)),
      onLog: (msg) {
        appendBotLog(msg, botId: clientId);
        unawaited(_emitTaskLogToMain(msg, botId: clientId));
      },
    );

    if (!actionResults.containsKey('__stopped__')) {
      await interaction.respond(const <CommandOptionChoiceBuilder<dynamic>>[]);
    }
  } catch (error, stackTrace) {
    appendBotLog('Autocomplete workflow error: $error', botId: clientId);
    appendBotDebugLog('$stackTrace', botId: clientId);
    try {
      await interaction.respond(const <CommandOptionChoiceBuilder<dynamic>>[]);
    } catch (_) {}
  }
}
