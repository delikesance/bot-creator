import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bot_creator_shared/actions/handle_component_interaction.dart';
import 'package:bot_creator_shared/actions/handler.dart';
import 'package:bot_creator_shared/actions/interaction_response.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/events/event_contexts.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:bot_creator_shared/utils/workflow_call.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:nyxx/nyxx.dart';

import 'runner_data_store.dart';

final _log = Logger('BotRunner');

/// Connects to Discord via nyxx, registers command listeners, and dispatches
/// interactions to the shared action handlers — matching commands by their Discord ID.
class DiscordRunner {
  final BotConfig config;
  final RunnerDataStore store;

  NyxxGateway? _gateway;
  Timer? _statusRotationTimer;
  final Random _random = Random();

  DiscordRunner(this.config) : store = RunnerDataStore(config);

  List<Map<String, dynamic>> get _eventWorkflows {
    final result = <Map<String, dynamic>>[];
    for (final workflow in config.workflows) {
      final normalized = normalizeStoredWorkflowDefinition(workflow);
      if (normalizeWorkflowType(normalized['workflowType']) ==
          workflowTypeEvent) {
        result.add(normalized);
      }
    }
    return result;
  }

  Future<void> start() async {
    _log.info('Starting runner with ${config.commands.length} command(s)...');

    final intents = _buildIntents(config.intents);
    _gateway = await Nyxx.connectGateway(
      config.token,
      intents,
      options: GatewayClientOptions(
        loggerName: 'BotCreatorRunner',
        plugins: [Logging(logLevel: Level.INFO)],
      ),
    );

    _gateway!.onReady.listen((event) async {
      final botId = event.gateway.client.user.id.toString();
      _log.info('Bot ready — bot ID: $botId');

      await _reconcileCurrentBotProfile(event.gateway.client);
      _startStatusRotation(event.gateway.client);
    });

    _gateway!.onInteractionCreate.listen((event) async {
      await _handleInteraction(event);
    });

    _registerEventWorkflowListeners();

    _log.info(
      'Gateway connected — listening for interactions and ${_eventWorkflows.length} event workflow(s).',
    );
  }

  Future<void> stop() async {
    _statusRotationTimer?.cancel();
    _statusRotationTimer = null;
    await _gateway?.close();
    _gateway = null;
    await store.dispose();
    _log.info('Runner stopped.');
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _handleInteraction(InteractionCreateEvent event) async {
    final interaction = event.interaction;
    final client = event.gateway.client;
    final botId = client.user.id.toString();

    if (interaction is ApplicationCommandInteraction) {
      final commandId = interaction.data.id.toString();

      // Match by Discord command ID (same logic as bot.commands.dart)
      final commandData = _findCommand(commandId);
      if (commandData == null) {
        _log.warning('Command $commandId not found in config');
        await _safeRespond(
          interaction,
          'Command not found.',
          isEphemeral: true,
        );
        return;
      }

      await _executeCommand(
        client: client,
        botId: botId,
        interaction: interaction,
        commandData: commandData,
      );
    } else if (interaction is MessageComponentInteraction) {
      await handleComponentInteraction(client, interaction, store);
    } else if (interaction is ModalSubmitInteraction) {
      await handleModalSubmitInteraction(client, interaction, store);
    }
  }

  Map<String, dynamic>? _findCommand(String discordCommandId) {
    for (final cmd in config.commands) {
      if ((cmd['id'] ?? '').toString() == discordCommandId) {
        return cmd;
      }
    }
    return null;
  }

  void _registerEventWorkflowListeners() {
    final gateway = _gateway;
    if (gateway == null) {
      return;
    }

    if (_eventWorkflows.isEmpty) {
      return;
    }

    void registerEvent<T>(
      Stream<T> stream,
      String eventName, {
      EventExecutionContext Function(T event)? buildContext,
    }) {
      stream.listen((event) async {
        await _dispatchEventWorkflows(
          eventName: eventName,
          context:
              buildContext?.call(event) ??
              _baseEventContext(
                eventName: eventName,
                guildId: null,
                channelId: null,
                userId: null,
              ),
        );
      });
    }

    registerEvent<MessageCreateEvent>(
      gateway.onMessageCreate,
      'messageCreate',
      buildContext: buildMessageCreateEventContext,
    );
    registerEvent<MessageUpdateEvent>(
      gateway.onMessageUpdate,
      'messageUpdate',
      buildContext: buildMessageUpdateEventContext,
    );
    registerEvent<MessageDeleteEvent>(
      gateway.onMessageDelete,
      'messageDelete',
      buildContext: buildMessageDeleteEventContext,
    );
    registerEvent<GuildMemberAddEvent>(
      gateway.onGuildMemberAdd,
      'guildMemberAdd',
      buildContext: buildGuildMemberAddEventContext,
    );
    registerEvent<GuildMemberRemoveEvent>(
      gateway.onGuildMemberRemove,
      'guildMemberRemove',
      buildContext: buildGuildMemberRemoveEventContext,
    );
    registerEvent<ChannelUpdateEvent>(
      gateway.onChannelUpdate,
      'channelUpdate',
      buildContext: buildChannelUpdateEventContext,
    );
    registerEvent<InviteCreateEvent>(
      gateway.onInviteCreate,
      'inviteCreate',
      buildContext: buildInviteCreateEventContext,
    );

    registerEvent<ReadyEvent>(gateway.onReady, 'ready');
    registerEvent<ResumedEvent>(gateway.onResumed, 'resumed');
    registerEvent<InteractionCreateEvent>(
      gateway.onInteractionCreate,
      'interactionCreate',
    );
    registerEvent<ApplicationCommandPermissionsUpdateEvent>(
      gateway.onApplicationCommandPermissionsUpdate,
      'applicationCommandPermissionsUpdate',
    );
    registerEvent<AutoModerationRuleCreateEvent>(
      gateway.onAutoModerationRuleCreate,
      'autoModerationRuleCreate',
    );
    registerEvent<AutoModerationRuleUpdateEvent>(
      gateway.onAutoModerationRuleUpdate,
      'autoModerationRuleUpdate',
    );
    registerEvent<AutoModerationRuleDeleteEvent>(
      gateway.onAutoModerationRuleDelete,
      'autoModerationRuleDelete',
    );
    registerEvent<AutoModerationActionExecutionEvent>(
      gateway.onAutoModerationActionExecution,
      'autoModerationActionExecution',
    );
    registerEvent<ChannelCreateEvent>(gateway.onChannelCreate, 'channelCreate');
    registerEvent<ChannelDeleteEvent>(gateway.onChannelDelete, 'channelDelete');
    registerEvent<ChannelPinsUpdateEvent>(
      gateway.onChannelPinsUpdate,
      'channelPinsUpdate',
      buildContext: buildChannelPinsUpdateEventContext,
    );
    registerEvent<ThreadCreateEvent>(
      gateway.onThreadCreate,
      'threadCreate',
      buildContext: buildThreadCreateEventContext,
    );
    registerEvent<ThreadUpdateEvent>(
      gateway.onThreadUpdate,
      'threadUpdate',
      buildContext: buildThreadUpdateEventContext,
    );
    registerEvent<ThreadDeleteEvent>(
      gateway.onThreadDelete,
      'threadDelete',
      buildContext: buildThreadDeleteEventContext,
    );
    registerEvent<ThreadListSyncEvent>(
      gateway.onThreadListSync,
      'threadListSync',
    );
    registerEvent<ThreadMemberUpdateEvent>(
      gateway.onThreadMemberUpdate,
      'threadMemberUpdate',
      buildContext: buildThreadMemberUpdateEventContext,
    );
    registerEvent<ThreadMembersUpdateEvent>(
      gateway.onThreadMembersUpdate,
      'threadMembersUpdate',
      buildContext: buildThreadMembersUpdateEventContext,
    );
    registerEvent<UnavailableGuildCreateEvent>(
      gateway.onGuildCreate,
      'guildCreate',
    );
    registerEvent<GuildUpdateEvent>(gateway.onGuildUpdate, 'guildUpdate');
    registerEvent<GuildDeleteEvent>(gateway.onGuildDelete, 'guildDelete');
    registerEvent<GuildAuditLogCreateEvent>(
      gateway.onGuildAuditLogCreate,
      'guildAuditLogCreate',
      buildContext: buildGuildAuditLogCreateEventContext,
    );
    registerEvent<GuildBanAddEvent>(gateway.onGuildBanAdd, 'guildBanAdd');
    registerEvent<GuildBanRemoveEvent>(
      gateway.onGuildBanRemove,
      'guildBanRemove',
    );
    registerEvent<GuildEmojisUpdateEvent>(
      gateway.onGuildEmojisUpdate,
      'guildEmojisUpdate',
    );
    registerEvent<GuildStickersUpdateEvent>(
      gateway.onGuildStickersUpdate,
      'guildStickersUpdate',
    );
    registerEvent<GuildIntegrationsUpdateEvent>(
      gateway.onGuildIntegrationsUpdate,
      'guildIntegrationsUpdate',
    );
    registerEvent<GuildMemberUpdateEvent>(
      gateway.onGuildMemberUpdate,
      'guildMemberUpdate',
    );
    registerEvent<GuildMembersChunkEvent>(
      gateway.onGuildMembersChunk,
      'guildMembersChunk',
    );
    registerEvent<GuildRoleCreateEvent>(
      gateway.onGuildRoleCreate,
      'guildRoleCreate',
      buildContext: buildGuildRoleCreateEventContext,
    );
    registerEvent<GuildRoleUpdateEvent>(
      gateway.onGuildRoleUpdate,
      'guildRoleUpdate',
      buildContext: buildGuildRoleUpdateEventContext,
    );
    registerEvent<GuildRoleDeleteEvent>(
      gateway.onGuildRoleDelete,
      'guildRoleDelete',
      buildContext: buildGuildRoleDeleteEventContext,
    );
    registerEvent<GuildScheduledEventCreateEvent>(
      gateway.onGuildScheduledEventCreate,
      'guildScheduledEventCreate',
    );
    registerEvent<GuildScheduledEventUpdateEvent>(
      gateway.onGuildScheduledEventUpdate,
      'guildScheduledEventUpdate',
    );
    registerEvent<GuildScheduledEventDeleteEvent>(
      gateway.onGuildScheduledEventDelete,
      'guildScheduledEventDelete',
    );
    registerEvent<GuildScheduledEventUserAddEvent>(
      gateway.onGuildScheduledEventUserAdd,
      'guildScheduledEventUserAdd',
    );
    registerEvent<GuildScheduledEventUserRemoveEvent>(
      gateway.onGuildScheduledEventUserRemove,
      'guildScheduledEventUserRemove',
    );
    registerEvent<IntegrationCreateEvent>(
      gateway.onIntegrationCreate,
      'integrationCreate',
    );
    registerEvent<IntegrationUpdateEvent>(
      gateway.onIntegrationUpdate,
      'integrationUpdate',
    );
    registerEvent<IntegrationDeleteEvent>(
      gateway.onIntegrationDelete,
      'integrationDelete',
    );
    registerEvent<InviteDeleteEvent>(
      gateway.onInviteDelete,
      'inviteDelete',
      buildContext: buildInviteDeleteEventContext,
    );
    registerEvent<MessageBulkDeleteEvent>(
      gateway.onMessageBulkDelete,
      'messageBulkDelete',
    );
    registerEvent<MessageReactionAddEvent>(
      gateway.onMessageReactionAdd,
      'messageReactionAdd',
      buildContext: buildMessageReactionAddEventContext,
    );
    registerEvent<MessageReactionRemoveEvent>(
      gateway.onMessageReactionRemove,
      'messageReactionRemove',
      buildContext: buildMessageReactionRemoveEventContext,
    );
    registerEvent<MessageReactionRemoveAllEvent>(
      gateway.onMessageReactionRemoveAll,
      'messageReactionRemoveAll',
      buildContext: buildMessageReactionRemoveAllEventContext,
    );
    registerEvent<MessageReactionRemoveEmojiEvent>(
      gateway.onMessageReactionRemoveEmoji,
      'messageReactionRemoveEmoji',
      buildContext: buildMessageReactionRemoveEmojiEventContext,
    );
    registerEvent<PresenceUpdateEvent>(
      gateway.onPresenceUpdate,
      'presenceUpdate',
      buildContext: buildPresenceUpdateEventContext,
    );
    registerEvent<TypingStartEvent>(
      gateway.onTypingStart,
      'typingStart',
      buildContext: buildTypingStartEventContext,
    );
    registerEvent<UserUpdateEvent>(
      gateway.onUserUpdate,
      'userUpdate',
      buildContext: buildUserUpdateEventContext,
    );
    registerEvent<VoiceStateUpdateEvent>(
      gateway.onVoiceStateUpdate,
      'voiceStateUpdate',
      buildContext: buildVoiceStateUpdateEventContext,
    );
    registerEvent<VoiceServerUpdateEvent>(
      gateway.onVoiceServerUpdate,
      'voiceServerUpdate',
      buildContext: buildVoiceServerUpdateEventContext,
    );
    registerEvent<WebhooksUpdateEvent>(
      gateway.onWebhooksUpdate,
      'webhooksUpdate',
    );
    registerEvent<StageInstanceCreateEvent>(
      gateway.onStageInstanceCreate,
      'stageInstanceCreate',
    );
    registerEvent<StageInstanceUpdateEvent>(
      gateway.onStageInstanceUpdate,
      'stageInstanceUpdate',
    );
    registerEvent<StageInstanceDeleteEvent>(
      gateway.onStageInstanceDelete,
      'stageInstanceDelete',
    );
    registerEvent<EntitlementCreateEvent>(
      gateway.onEntitlementCreate,
      'entitlementCreate',
    );
    registerEvent<EntitlementUpdateEvent>(
      gateway.onEntitlementUpdate,
      'entitlementUpdate',
    );
    registerEvent<EntitlementDeleteEvent>(
      gateway.onEntitlementDelete,
      'entitlementDelete',
    );
    registerEvent<MessagePollVoteAddEvent>(
      gateway.onMessagePollVoteAdd,
      'messagePollVoteAdd',
      buildContext: buildMessagePollVoteAddEventContext,
    );
    registerEvent<MessagePollVoteRemoveEvent>(
      gateway.onMessagePollVoteRemove,
      'messagePollVoteRemove',
      buildContext: buildMessagePollVoteRemoveEventContext,
    );
    registerEvent<SoundboardSoundCreateEvent>(
      gateway.onSoundboardSoundCreate,
      'soundboardSoundCreate',
    );
    registerEvent<SoundboardSoundUpdateEvent>(
      gateway.onSoundboardSoundUpdate,
      'soundboardSoundUpdate',
    );
    registerEvent<SoundboardSoundDeleteEvent>(
      gateway.onSoundboardSoundDelete,
      'soundboardSoundDelete',
    );
    registerEvent<SoundboardSoundsUpdateEvent>(
      gateway.onSoundboardSoundsUpdate,
      'soundboardSoundsUpdate',
    );
    registerEvent<VoiceChannelEffectSendEvent>(
      gateway.onVoiceChannelEffectSend,
      'voiceChannelEffectSend',
      buildContext: buildVoiceChannelEffectSendEventContext,
    );
  }

  EventExecutionContext _baseEventContext({
    required String eventName,
    required Snowflake? guildId,
    required Snowflake? channelId,
    required Snowflake? userId,
  }) {
    return EventExecutionContext(
      eventName: eventName,
      variables: const <String, String>{},
      guildId: guildId,
      channelId: channelId,
      userId: userId,
    );
  }

  Future<void> _dispatchEventWorkflows({
    required String eventName,
    required EventExecutionContext context,
  }) async {
    final botId = _gateway?.user.id.toString() ?? store.botId;
    final matching = _eventWorkflows
        .where((workflow) {
          final trigger = normalizeWorkflowEventTrigger(
            workflow['eventTrigger'],
          );
          return (trigger['event'] ?? '').toString() == eventName;
        })
        .toList(growable: false);

    if (matching.isEmpty) {
      return;
    }

    for (final workflow in matching) {
      await _executeEventWorkflow(
        botId: botId,
        workflow: workflow,
        context: context,
      );
    }
  }

  Future<void> _executeEventWorkflow({
    required String botId,
    required Map<String, dynamic> workflow,
    required EventExecutionContext context,
  }) async {
    final workflowName = (workflow['name'] ?? '').toString().trim();
    final entryPoint = normalizeWorkflowEntryPoint(workflow['entryPoint']);
    final definitions = parseWorkflowArgumentDefinitions(workflow['arguments']);
    final actions = List<Action>.from(
      ((workflow['actions'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((json) => Action.fromJson(Map<String, dynamic>.from(json))),
    );
    if (actions.isEmpty) {
      return;
    }

    final runtimeVariables = <String, String>{
      ...context.variables,
      'workflow.type': workflowTypeEvent,
    };
    final globalVars = await store.getGlobalVariables(botId);
    for (final entry in globalVars.entries) {
      runtimeVariables['global.${entry.key}'] = entry.value.toString();
    }

    final guildContextId =
        context.variables['guildId'] ?? context.guildId?.toString();
    final channelContextId =
        context.variables['channelId'] ?? context.channelId?.toString();
    final userContextId =
        context.variables['userId'] ?? context.variables['author.id'];
    final guildMemberContextId =
        (guildContextId != null &&
                guildContextId.trim().isNotEmpty &&
                userContextId != null &&
                userContextId.trim().isNotEmpty)
            ? '${guildContextId.trim()}:${userContextId.trim()}'
            : null;
    final messageContextId =
        context.variables['messageId'] ??
        context.variables['message.id'] ??
        context.variables['event.id'];

    await _injectScopedVariables(
      runtimeVariables: runtimeVariables,
      botId: botId,
      scope: 'guild',
      contextId: guildContextId,
    );
    await _injectScopedVariables(
      runtimeVariables: runtimeVariables,
      botId: botId,
      scope: 'channel',
      contextId: channelContextId,
    );
    await _injectScopedVariables(
      runtimeVariables: runtimeVariables,
      botId: botId,
      scope: 'user',
      contextId: userContextId,
    );
    await _injectScopedVariables(
      runtimeVariables: runtimeVariables,
      botId: botId,
      scope: 'guildMember',
      contextId: guildMemberContextId,
    );
    await _injectScopedVariables(
      runtimeVariables: runtimeVariables,
      botId: botId,
      scope: 'message',
      contextId: messageContextId,
    );

    applyWorkflowInvocationContext(
      variables: runtimeVariables,
      workflowName: workflowName,
      entryPoint: entryPoint,
      definitions: definitions,
      providedArguments: const <String, String>{},
    );

    try {
      await handleActions(
        _gateway!,
        null,
        actions: actions,
        store: store,
        botId: botId,
        variables: runtimeVariables,
        resolveTemplate:
            (input) => resolveTemplatePlaceholders(
              input,
              Map<String, String>.from(runtimeVariables),
            ),
        fallbackChannelId: context.channelId,
        fallbackGuildId: context.guildId,
        onLog: (msg) => _log.info(msg),
      );
      _log.info(
        'Executed event workflow "$workflowName" for ${context.eventName}.',
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Failed executing event workflow "$workflowName" for ${context.eventName}: $error',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _injectScopedVariables({
    required Map<String, String> runtimeVariables,
    required String botId,
    required String scope,
    required String? contextId,
  }) async {
    final normalizedContextId = (contextId ?? '').trim();
    if (normalizedContextId.isEmpty) {
      return;
    }

    final values = await store.getScopedVariables(
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
      final value = entry.value.toString();

      // Canonical reference form for scoped placeholders.
      runtimeVariables['$scope.$canonicalKey'] = value;
      // Backward-compat alias for older payloads still using raw keys.
      runtimeVariables['$scope.$rawKey'] = value;
    }
  }

  Future<void> _executeCommand({
    required NyxxGateway client,
    required String botId,
    required ApplicationCommandInteraction interaction,
    required Map<String, dynamic> commandData,
  }) async {
    final data = Map<String, dynamic>.from(
      (commandData['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final value = Map<String, dynamic>.from(
      (data['data'] as Map?)?.cast<String, dynamic>() ?? data,
    );
    final response = Map<String, dynamic>.from(
      (value['response'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final workflow = Map<String, dynamic>.from(
      (response['workflow'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final workflowConditional = Map<String, dynamic>.from(
      (workflow['conditional'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    // Build runtime variables from interaction
    final runtimeVariables = await generateKeyValues(interaction);
    final globalVars = await store.getGlobalVariables(botId);
    for (final entry in globalVars.entries) {
      runtimeVariables['global.${entry.key}'] = entry.value.toString();
    }

    final guildContextId = runtimeVariables['guildId'];
    final channelContextId = runtimeVariables['channelId'];
    final userContextId = runtimeVariables['userId'];
    final guildMemberContextId =
        (guildContextId != null &&
                guildContextId.trim().isNotEmpty &&
                userContextId != null &&
                userContextId.trim().isNotEmpty)
            ? '${guildContextId.trim()}:${userContextId.trim()}'
            : null;
    final messageContextId =
        runtimeVariables['messageId'] ?? runtimeVariables['message.id'];

    await _injectScopedVariables(
      runtimeVariables: runtimeVariables,
      botId: botId,
      scope: 'guild',
      contextId: guildContextId,
    );
    await _injectScopedVariables(
      runtimeVariables: runtimeVariables,
      botId: botId,
      scope: 'channel',
      contextId: channelContextId,
    );
    await _injectScopedVariables(
      runtimeVariables: runtimeVariables,
      botId: botId,
      scope: 'user',
      contextId: userContextId,
    );
    await _injectScopedVariables(
      runtimeVariables: runtimeVariables,
      botId: botId,
      scope: 'guildMember',
      contextId: guildMemberContextId,
    );
    await _injectScopedVariables(
      runtimeVariables: runtimeVariables,
      botId: botId,
      scope: 'message',
      contextId: messageContextId,
    );

    // Collect actions
    var actionsJson = List<Map<String, dynamic>>.from(
      (value['actions'] as List?)?.whereType<Map>().map(
            (e) => Map<String, dynamic>.from(e),
          ) ??
          const [],
    );

    // If empty, try to load from a named workflow
    final workflowName = (workflow['name'] ?? '').toString().trim();
    if (workflowName.isNotEmpty && actionsJson.isEmpty) {
      final saved = await store.getWorkflowByName(botId, workflowName);
      if (saved != null) {
        actionsJson = List<Map<String, dynamic>>.from(
          (saved['actions'] as List?)?.whereType<Map>().map(
                (e) => Map<String, dynamic>.from(e),
              ) ??
              const [],
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
          deferFlags |= 32768;
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
      }

      if (actionsJson.isNotEmpty) {
        final actions = actionsJson.map(Action.fromJson).toList();
        final actionResults = await handleActions(
          client,
          interaction,
          actions: actions,
          store: store,
          botId: botId,
          variables: runtimeVariables,
          resolveTemplate:
              (input) => resolveTemplatePlaceholders(
                input,
                Map<String, String>.from(runtimeVariables),
              ),
          onLog: (msg) => _log.info(msg),
        );
        for (final entry in actionResults.entries) {
          runtimeVariables['action.${entry.key}'] = entry.value;
        }
      }

      await sendWorkflowResponse(
        interaction: interaction,
        response: response,
        runtimeVariables: runtimeVariables,
        botId: botId,
        didDefer: didDefer,
        isEphemeral: isEphemeral,
        onLog: (msg, {required botId}) async => _log.info(msg),
        onDebugLog: (msg, {required botId}) async => _log.fine(msg),
      );
    } catch (e, st) {
      _log.severe('Error executing command ${commandData['name']}: $e', e, st);
      await _safeErrorResponse(
        interaction,
        didDefer: didDefer,
        isEphemeral: isEphemeral,
      );
    }
  }

  Future<void> _safeRespond(
    Interaction interaction,
    String text, {
    bool isEphemeral = false,
  }) async {
    try {
      await (interaction as dynamic).respond(
        MessageBuilder(
          content: text,
          flags: isEphemeral ? MessageFlags.ephemeral : null,
        ),
      );
    } catch (_) {}
  }

  Future<void> _safeErrorResponse(
    ApplicationCommandInteraction interaction, {
    required bool didDefer,
    required bool isEphemeral,
  }) async {
    const text = 'An error occurred while executing this command.';
    try {
      if (didDefer) {
        await interaction.updateOriginalResponse(
          MessageUpdateBuilder(content: text, embeds: const []),
        );
      } else {
        await interaction.respond(
          MessageBuilder(
            content: text,
            flags: isEphemeral ? MessageFlags.ephemeral : null,
          ),
        );
      }
    } catch (_) {}
  }

  Flags<GatewayIntents> _buildIntents(Map<String, bool> intentsMap) {
    if (intentsMap.isEmpty) return GatewayIntents.allUnprivileged;

    Flags<GatewayIntents> intents = GatewayIntents.none;
    if (intentsMap['Guild Presence'] == true) {
      intents = intents | GatewayIntents.guildPresences;
    }
    if (intentsMap['Guild Members'] == true) {
      intents = intents | GatewayIntents.guildMembers;
    }
    if (intentsMap['Message Content'] == true) {
      intents = intents | GatewayIntents.messageContent;
    }
    if (intentsMap['Direct Messages'] == true) {
      intents = intents | GatewayIntents.directMessages;
    }
    if (intentsMap['Guilds'] == true) {
      intents = intents | GatewayIntents.guilds;
    }
    if (intentsMap['Guild Messages'] == true) {
      intents = intents | GatewayIntents.guildMessages;
    }
    if (intentsMap['Guild Message Reactions'] == true) {
      intents = intents | GatewayIntents.guildMessageReactions;
    }
    if (intentsMap['Direct Message Reactions'] == true) {
      intents = intents | GatewayIntents.directMessageReactions;
    }
    if (intentsMap['Guild Message Typing'] == true) {
      intents = intents | GatewayIntents.guildMessageTyping;
    }
    if (intentsMap['Direct Message Typing'] == true) {
      intents = intents | GatewayIntents.directMessageTyping;
    }
    if (intentsMap['Guild Scheduled Events'] == true) {
      intents = intents | GatewayIntents.guildScheduledEvents;
    }
    if (intentsMap['Auto Moderation Configuration'] == true) {
      intents = intents | GatewayIntents.autoModerationConfiguration;
    }
    if (intentsMap['Auto Moderation Execution'] == true) {
      intents = intents | GatewayIntents.autoModerationExecution;
    }

    return intents == GatewayIntents.none
        ? GatewayIntents.allUnprivileged
        : intents;
  }

  Future<void> _reconcileCurrentBotProfile(NyxxGateway client) async {
    final username = config.username?.trim();
    final avatarPath = config.avatarPath?.trim();
    final shouldUpdateUsername = username != null && username.isNotEmpty;
    final shouldUpdateAvatar = avatarPath != null && avatarPath.isNotEmpty;

    if (!shouldUpdateUsername && !shouldUpdateAvatar) {
      return;
    }

    try {
      final builder = UserUpdateBuilder();
      var hasPayload = false;
      if (shouldUpdateUsername) {
        builder.username = username;
        hasPayload = true;
      }

      if (shouldUpdateAvatar) {
        final file = File(avatarPath);
        if (!await file.exists()) {
          _log.warning(
            'Avatar file not found for profile reconciliation: $avatarPath',
          );
        } else {
          builder.avatar = await ImageBuilder.fromFile(file);
          hasPayload = true;
        }
      }

      if (!hasPayload) {
        return;
      }

      await client.users.updateCurrentUser(builder);
      _log.info('Bot profile reconciled from config (username/avatar).');
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to reconcile bot profile: $error',
        error,
        stackTrace,
      );
    }
  }

  void _startStatusRotation(NyxxGateway client) {
    _statusRotationTimer?.cancel();
    _statusRotationTimer = null;

    if (config.statuses.isEmpty) {
      _log.info('No statuses configured, skipping rotation.');
      return;
    }

    unawaited(_applyInitialStatusThenRotate(client));
  }

  Future<void> _applyInitialStatusThenRotate(NyxxGateway client) async {
    if (config.statuses.isEmpty) {
      return;
    }

    final firstStatus = config.statuses.first;
    await _applyStatus(client, firstStatus);

    // Some sessions ignore the first presence packet right after READY.
    // Re-sending shortly after improves reliability.
    Timer(const Duration(seconds: 3), () {
      unawaited(_applyStatus(client, firstStatus));
    });

    final nextDelaySeconds = _randomDelaySeconds(
      min: firstStatus.minIntervalSeconds,
      max: firstStatus.maxIntervalSeconds,
    );
    _statusRotationTimer?.cancel();
    _statusRotationTimer = Timer(Duration(seconds: nextDelaySeconds), () {
      unawaited(_applyRandomStatus(client));
    });
  }

  Future<void> _applyStatus(NyxxGateway client, BotStatusConfig status) async {
    final streamUrl = _parseStreamingUrl(status.url);
    final activityType = _mapActivityType(status.type, streamUrl: streamUrl);
    final activityText = _sanitizeActivityText(status.name);
    if (activityText.isEmpty) {
      _log.warning('Skipped status update because activity text is empty.');
      return;
    }

    try {
      client.updatePresence(
        PresenceBuilder(
          status: CurrentUserStatus.online,
          isAfk: false,
          activities: <ActivityBuilder>[
            ActivityBuilder(
              name: activityText,
              type: activityType,
              url: streamUrl,
            ),
          ],
        ),
      );
      _log.info('Presence updated: ${status.type} $activityText');
    } catch (error, stackTrace) {
      _log.warning('Failed to update presence: $error', error, stackTrace);
    }
  }

  Future<void> _applyRandomStatus(NyxxGateway client) async {
    if (config.statuses.isEmpty) {
      return;
    }

    final status = config.statuses[_random.nextInt(config.statuses.length)];
    await _applyStatus(client, status);

    final nextDelaySeconds = _randomDelaySeconds(
      min: status.minIntervalSeconds,
      max: status.maxIntervalSeconds,
    );
    _statusRotationTimer?.cancel();
    _statusRotationTimer = Timer(Duration(seconds: nextDelaySeconds), () {
      unawaited(_applyRandomStatus(client));
    });
  }

  int _randomDelaySeconds({required int min, required int max}) {
    if (max <= min) {
      return min;
    }
    return min + _random.nextInt(max - min + 1);
  }

  ActivityType _mapActivityType(String rawType, {required Uri? streamUrl}) {
    switch (rawType.trim().toLowerCase()) {
      case 'streaming':
        return streamUrl != null ? ActivityType.streaming : ActivityType.game;
      case 'listening':
        return ActivityType.listening;
      case 'watching':
        return ActivityType.watching;
      case 'competing':
        return ActivityType.competing;
      case 'playing':
      default:
        return ActivityType.game;
    }
  }

  String _sanitizeActivityText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    // Discord activity names should be short; keep a safe cap.
    if (trimmed.length > 120) {
      return trimmed.substring(0, 120);
    }

    return trimmed;
  }

  Uri? _parseStreamingUrl(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) {
      return null;
    }
    if ((parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty) {
      return null;
    }
    return parsed;
  }
}
