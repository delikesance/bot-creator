part of 'bot.dart';

void _registerLocalEventWorkflowListeners(
  NyxxGateway gateway, {
  required AppManager manager,
  required String botId,
  required Map<String, dynamic> appData,
  void Function(String message)? onLog,
}) {
  final workflows = List<Map<String, dynamic>>.from(
        (appData['workflows'] as List?)?.whereType<Map>().map(
              (entry) => normalizeStoredWorkflowDefinition(
                Map<String, dynamic>.from(entry),
              ),
            ) ??
            const <Map<String, dynamic>>[],
      )
      .where((workflow) {
        return normalizeWorkflowType(workflow['workflowType']) ==
            workflowTypeEvent;
      })
      .toList(growable: false);

  if (workflows.isEmpty) {
    onLog?.call('No event workflows found - listeners disabled.');
    return;
  }

  onLog?.call(
    'Enabling event listeners (${workflows.length} workflow(s) found)...',
  );

  final configuredEvents = workflows
    .map((workflow) {
      final trigger = normalizeWorkflowEventTrigger(workflow['eventTrigger']);
      return (trigger['event'] ?? '').toString().trim();
    })
    .where((event) => event.isNotEmpty)
    .toSet()
    .toList(growable: false)..sort();

  final configuredEventsLower =
      configuredEvents.map((event) => event.toLowerCase()).toSet();

  final intentsMap = Map<String, bool>.from(appData['intents'] as Map? ?? {});
  final hasMessageEventConfigured =
      configuredEventsLower.contains('messagecreate') ||
      configuredEventsLower.contains('messageupdate') ||
      configuredEventsLower.contains('messagedelete') ||
      configuredEventsLower.contains('messagebulkdelete') ||
      configuredEventsLower.contains('messagereactionadd') ||
      configuredEventsLower.contains('messagereactionremove') ||
      configuredEventsLower.contains('messagereactionremoveall') ||
      configuredEventsLower.contains('messagereactionremoveemoji');
  final hasGuildMessagesIntent = intentsMap['Guild Messages'] == true;
  final hasMessageContentIntent = intentsMap['Message Content'] == true;

  const runtimeSupportedEvents = <String>[
    'messageCreate',
    'messageUpdate',
    'messageDelete',
    'guildMemberAdd',
    'guildMemberRemove',
    'channelUpdate',
    'inviteCreate',
    'ready',
    'resumed',
    'interactionCreate',
    'applicationCommandPermissionsUpdate',
    'autoModerationRuleCreate',
    'autoModerationRuleUpdate',
    'autoModerationRuleDelete',
    'autoModerationActionExecution',
    'channelCreate',
    'channelDelete',
    'channelPinsUpdate',
    'threadCreate',
    'threadUpdate',
    'threadDelete',
    'threadListSync',
    'threadMemberUpdate',
    'threadMembersUpdate',
    'guildCreate',
    'guildUpdate',
    'guildDelete',
    'guildAuditLogCreate',
    'guildBanAdd',
    'guildBanRemove',
    'guildEmojisUpdate',
    'guildStickersUpdate',
    'guildIntegrationsUpdate',
    'guildMemberUpdate',
    'guildMembersChunk',
    'guildRoleCreate',
    'guildRoleUpdate',
    'guildRoleDelete',
    'guildScheduledEventCreate',
    'guildScheduledEventUpdate',
    'guildScheduledEventDelete',
    'guildScheduledEventUserAdd',
    'guildScheduledEventUserRemove',
    'integrationCreate',
    'integrationUpdate',
    'integrationDelete',
    'inviteDelete',
    'messageBulkDelete',
    'messageReactionAdd',
    'messageReactionRemove',
    'messageReactionRemoveAll',
    'messageReactionRemoveEmoji',
    'presenceUpdate',
    'typingStart',
    'userUpdate',
    'voiceStateUpdate',
    'voiceServerUpdate',
    'webhooksUpdate',
    'stageInstanceCreate',
    'stageInstanceUpdate',
    'stageInstanceDelete',
    'entitlementCreate',
    'entitlementUpdate',
    'entitlementDelete',
    'messagePollVoteAdd',
    'messagePollVoteRemove',
    'soundboardSoundCreate',
    'soundboardSoundUpdate',
    'soundboardSoundDelete',
    'soundboardSoundsUpdate',
    'voiceChannelEffectSend',
  ];

  final unsupportedConfiguredEvents = configuredEvents
    .where((event) => !runtimeSupportedEvents.contains(event))
    .toList(growable: false)..sort();

  onLog?.call(
    'Events workflow configures: '
    '${configuredEvents.isEmpty ? 'aucun' : configuredEvents.join(', ')}',
  );
  onLog?.call('Events runtime ecoutes: ${runtimeSupportedEvents.join(', ')}');
  if (unsupportedConfiguredEvents.isNotEmpty) {
    onLog?.call(
      'Events configures non supportes en runtime local: '
      '${unsupportedConfiguredEvents.join(', ')}',
    );
  }
  if (hasMessageEventConfigured && !hasGuildMessagesIntent) {
    onLog?.call(
      'Attention: des workflows message sont configures mais l\'intent "Guild Messages" est desactive.',
    );
  }
  if (hasMessageEventConfigured && !hasMessageContentIntent) {
    onLog?.call(
      'Attention: des workflows message sont configures mais l\'intent "Message Content" est desactive.',
    );
  }

  Future<void> dispatch(EventExecutionContext context) async {
    final matching = workflows
        .where((workflow) {
          final trigger = normalizeWorkflowEventTrigger(
            workflow['eventTrigger'],
          );
          return (trigger['event'] ?? '').toString().trim().toLowerCase() ==
              context.eventName.toLowerCase();
        })
        .toList(growable: false);

    if (configuredEventsLower.contains(context.eventName.toLowerCase())) {
      onLog?.call(
        'Event recu: ${context.eventName} (workflows match: ${matching.length})',
      );
    }

    if (matching.isEmpty) {
      return;
    }

    for (final workflow in matching) {
      await _executeLocalEventWorkflow(
        gateway,
        manager: manager,
        botId: botId,
        workflow: workflow,
        context: context,
        onLog: onLog,
      );
    }
  }

  void registerEvent<T>(
    Stream<T> stream,
    String eventName, {
    EventExecutionContext Function(T event)? buildContext,
  }) {
    stream.listen((event) async {
      await dispatch(
        buildContext?.call(event) ??
            _baseLocalEventContext(
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

  if (configuredEvents.contains('ready')) {
    unawaited(
      dispatch(
        _baseLocalEventContext(
          eventName: 'ready',
          guildId: null,
          channelId: null,
          userId: null,
        ),
      ),
    );
  }

  onLog?.call(
    'Listeners event runtime actives (${workflows.length} workflow(s), '
    '${runtimeSupportedEvents.length} events supportes).',
  );
}

EventExecutionContext _baseLocalEventContext({
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

Future<void> _executeLocalEventWorkflow(
  NyxxGateway gateway, {
  required AppManager manager,
  required String botId,
  required Map<String, dynamic> workflow,
  required EventExecutionContext context,
  void Function(String message)? onLog,
}) async {
  final workflowName = (workflow['name'] ?? '').toString().trim();
  final entryPoint = normalizeWorkflowEntryPoint(workflow['entryPoint']);
  final definitions = parseWorkflowArgumentDefinitions(workflow['arguments']);
  final actions = List<Action>.from(
    ((workflow['actions'] as List?) ?? const <dynamic>[]).whereType<Map>().map(
      (json) => Action.fromJson(Map<String, dynamic>.from(json)),
    ),
  );
  if (actions.isEmpty) {
    return;
  }

  final runtimeVariables = <String, String>{
    ...context.variables,
    'workflow.type': workflowTypeEvent,
  };
  final globalVars = await manager.getGlobalVariables(botId);
  for (final entry in globalVars.entries) {
    runtimeVariables['global.${entry.key}'] = _runtimeVariableValueToString(
      entry.value,
    );
  }

  applyWorkflowInvocationContext(
    variables: runtimeVariables,
    workflowName: workflowName,
    entryPoint: entryPoint,
    definitions: definitions,
    providedArguments: const <String, String>{},
  );

  final actionResults = await handleActions(
    gateway,
    null,
    actions: actions,
    store: manager,
    botId: botId,
    variables: runtimeVariables,
    resolveTemplate:
        (input) =>
            updateString(input, Map<String, String>.from(runtimeVariables)),
    fallbackChannelId: context.channelId,
    fallbackGuildId: context.guildId,
    onLog: onLog,
  );

  if (actionResults.isNotEmpty) {
    onLog?.call(
      'Workflow event "$workflowName" execute sur ${context.eventName}.',
    );
  }
}
