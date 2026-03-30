part of 'bot.dart';

Future<void> _registerLocalEventWorkflowListeners(
  NyxxGateway gateway, {
  required AppManager manager,
  required String botId,
  required Map<String, dynamic> appData,
  void Function(String message)? onLog,
}) async {
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

  final allCommands = await manager.listAppCommands(botId);
  final legacyCommands = allCommands
      .where(_isLegacyLocalCommand)
      .toList(growable: false);
  final hasLegacyCommands = legacyCommands.isNotEmpty;

  if (workflows.isEmpty && !hasLegacyCommands) {
    onLog?.call(
      'No event workflows or legacy commands found - listeners disabled.',
    );
    return;
  }

  if (workflows.isNotEmpty) {
    onLog?.call(
      'Enabling event listeners (${workflows.length} workflow(s) found)...',
    );
  }
  if (hasLegacyCommands) {
    onLog?.call(
      'Enabling messageCreate listener for ${legacyCommands.length} legacy command(s).',
    );
  }

  final configuredEvents = <String>{
    ...workflows
        .map((workflow) {
          final trigger = normalizeWorkflowEventTrigger(
            workflow['eventTrigger'],
          );
          return (trigger['event'] ?? '').toString().trim();
        })
        .where((event) => event.isNotEmpty),
    if (hasLegacyCommands) 'messageCreate',
  }.toList(growable: false)..sort();

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
    'Configured workflow events: '
    '${configuredEvents.isEmpty ? 'none' : configuredEvents.join(', ')}',
  );
  onLog?.call(
    'Runtime listens to events: ${runtimeSupportedEvents.join(', ')}',
  );
  if (unsupportedConfiguredEvents.isNotEmpty) {
    onLog?.call(
      'Configured events not supported by local runtime: '
      '${unsupportedConfiguredEvents.join(', ')}',
    );
  }
  if (hasMessageEventConfigured && !hasGuildMessagesIntent) {
    onLog?.call(
      'Warning: message workflows are configured but the "Guild Messages" intent is disabled.',
    );
  }
  if (hasMessageEventConfigured && !hasMessageContentIntent) {
    onLog?.call(
      'Warning: message workflows are configured but the "Message Content" intent is disabled.',
    );
  }

  Future<void> dispatch(EventExecutionContext context) async {
    final normalizedEventName = context.eventName.toLowerCase();

    final matching = workflows
        .where((workflow) {
          final trigger = normalizeWorkflowEventTrigger(
            workflow['eventTrigger'],
          );
          return (trigger['event'] ?? '').toString().trim().toLowerCase() ==
              normalizedEventName;
        })
        .toList(growable: false);

    if (configuredEventsLower.contains(normalizedEventName)) {
      onLog?.call(
        'Event received: ${context.eventName} (matching workflows: ${matching.length})',
      );
    }

    Future<void> executeMatchingWorkflows() async {
      if (matching.isEmpty) {
        return;
      }

      final futures = matching
          .map((workflow) async {
            try {
              await _executeLocalEventWorkflow(
                gateway,
                manager: manager,
                botId: botId,
                workflow: workflow,
                context: context,
                onLog: onLog,
              );
            } catch (error) {
              if (_isClosedClientError(error)) {
                onLog?.call(
                  'Event ignored: client closed while executing ${context.eventName}.',
                );
                return;
              }
              onLog?.call(
                'Event workflow error for ${context.eventName}: $error',
              );
            }
          })
          .toList(growable: false);

      await Future.wait(futures, eagerError: false);
    }

    if (normalizedEventName == 'messagecreate') {
      final isBotMessage =
          (context.variables['message.isBot'] ??
                  context.variables['author.isBot'] ??
                  '')
              .toLowerCase() ==
          'true';
      if (isBotMessage) {
        onLog?.call('Event ignored: messageCreate from a bot.');
        return;
      }

      await Future.wait<dynamic>([
        _tryExecuteLocalLegacyCommand(
          gateway,
          manager: manager,
          botId: botId,
          appData: appData,
          context: context,
          onLog: onLog,
        ),
        executeMatchingWorkflows(),
      ], eagerError: false);
      return;
    }

    await executeMatchingWorkflows();
  }

  void registerEvent<T>(
    Stream<T> stream,
    String eventName, {
    EventExecutionContext Function(T event)? buildContext,
  }) {
    stream.listen((event) async {
      try {
        await dispatch(
          buildContext?.call(event) ??
              _baseLocalEventContext(
                eventName: eventName,
                guildId: null,
                channelId: null,
                userId: null,
              ),
        );
      } catch (error) {
        if (_isClosedClientError(error)) {
          onLog?.call(
            'Event ignored: listener $eventName received after client shutdown.',
          );
          return;
        }
        onLog?.call('Event listener error for $eventName: $error');
      }
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
    buildContext: buildInteractionCreateEventContext,
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
    'Runtime event listeners active (${workflows.length} workflow(s), '
    '${runtimeSupportedEvents.length} supported events).',
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

bool _isClosedClientError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('client is closed') ||
      text.contains('dead channel') ||
      text.contains('communicating on a dead channel');
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

  // Inject bot-level variables.
  runtimeVariables.addAll(shared_global.extractBotRuntimeDetails(gateway));
  _injectLocalGatewayBotVariables(
    gateway,
    runtimeVariables,
    startedAt: _botStartedAt(botId),
  );

  // Inject guild, channel and member variables for event workflows.
  final eventGuildId = context.guildId;
  Guild? eventGuild;
  if (eventGuildId != null) {
    try {
      final fetched = await gateway.guilds.fetch(eventGuildId);
      eventGuild = fetched;
      runtimeVariables.addAll(
        shared_global.extractGuildRuntimeDetails(fetched),
      );
    } catch (_) {}
  }

  final eventChannelId = context.channelId;
  if (eventChannelId != null) {
    try {
      final channel = await gateway.channels.fetch(eventChannelId);
      runtimeVariables.addAll(
        shared_global.extractChannelRuntimeDetails(channel),
      );
    } catch (_) {}
  }

  final eventUserId = context.userId;
  if (eventGuild != null && eventUserId != null) {
    try {
      final member = await eventGuild.members.fetch(eventUserId);
      runtimeVariables.addAll(
        shared_global.extractMemberRuntimeDetails(
          member: member,
          guild: eventGuild,
          guildId: eventGuildId.toString(),
        ),
      );
    } catch (_) {}
  }

  await hydrateRuntimeVariables(
    store: manager,
    botId: botId,
    runtimeVariables: runtimeVariables,
    guildContextId: context.variables['guildId'] ?? context.guildId?.toString(),
    channelContextId:
        context.variables['channelId'] ?? context.channelId?.toString(),
    userContextId:
        context.variables['userId'] ?? context.variables['author.id'],
    messageContextId:
        context.variables['messageId'] ??
        context.variables['message.id'] ??
        context.variables['event.id'],
  );

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
      'Event workflow "$workflowName" executed for ${context.eventName}.',
    );
  }
}

bool _isLegacyLocalCommand(Map<String, dynamic> command) {
  final data = Map<String, dynamic>.from(
    (command['data'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
  final commandType =
      (data['commandType'] ?? command['type'] ?? 'chatInput')
          .toString()
          .toLowerCase();
  return data['legacyModeEnabled'] == true &&
      (commandType == 'chatinput' ||
          commandType == 'chat_input' ||
          commandType == 'chat-input' ||
          commandType == 'slash');
}

class _AwaitedLocalTrigger {
  const _AwaitedLocalTrigger({
    required this.name,
    required this.isErrorTrigger,
    this.filter,
  });

  final String name;
  final bool isErrorTrigger;
  final String? filter;
}

class _AwaitedLocalCallbacks {
  const _AwaitedLocalCallbacks({
    this.successCommand,
    this.errorCommand,
    this.filter,
  });

  final Map<String, dynamic>? successCommand;
  final Map<String, dynamic>? errorCommand;
  final String? filter;

  _AwaitedLocalCallbacks copyWith({
    Map<String, dynamic>? successCommand,
    Map<String, dynamic>? errorCommand,
    String? filter,
  }) {
    return _AwaitedLocalCallbacks(
      successCommand: successCommand ?? this.successCommand,
      errorCommand: errorCommand ?? this.errorCommand,
      filter: filter ?? this.filter,
    );
  }
}

_AwaitedLocalTrigger? _parseAwaitedLocalTrigger(String rawName) {
  final name = rawName.trim();
  final successMatch = RegExp(
    r'^\$awaitedcommand\[(.+?);(.*)\]$',
    caseSensitive: false,
  ).firstMatch(name);
  if (successMatch != null) {
    final awaitedName = successMatch.group(1)?.trim().toLowerCase() ?? '';
    final filter = successMatch.group(2)?.trim();
    if (awaitedName.isEmpty) {
      return null;
    }
    return _AwaitedLocalTrigger(
      name: awaitedName,
      isErrorTrigger: false,
      filter: filter == null || filter.isEmpty ? null : filter,
    );
  }

  final errorMatch = RegExp(
    r'^\$awaitedcommanderror\[(.+?)\]$',
    caseSensitive: false,
  ).firstMatch(name);
  if (errorMatch != null) {
    final awaitedName = errorMatch.group(1)?.trim().toLowerCase() ?? '';
    if (awaitedName.isEmpty) {
      return null;
    }
    return _AwaitedLocalTrigger(name: awaitedName, isErrorTrigger: true);
  }

  return null;
}

bool _matchesAwaitedLocalFilter(String message, String? rawFilter) {
  final filter = (rawFilter ?? '').trim();
  if (filter.isEmpty) {
    return true;
  }

  if (!filter.startsWith('<') || !filter.endsWith('>')) {
    return true;
  }

  final body = filter.substring(1, filter.length - 1).trim();
  if (body.isEmpty) {
    return true;
  }

  if (body.toLowerCase() == 'numeric') {
    return RegExp(r'^-?\d+(\.\d+)?$').hasMatch(message.trim());
  }

  final allowed =
      body
          .split('/')
          .map((entry) => entry.trim().toLowerCase())
          .where((entry) => entry.isNotEmpty)
          .toSet();
  if (allowed.isEmpty) {
    return true;
  }
  return allowed.contains(message.trim().toLowerCase());
}

Future<List<Map<String, dynamic>>?> _resolveLocalLegacyActionsJson({
  required Map<String, dynamic> data,
  required String commandName,
  void Function(String message)? onLog,
}) async {
  final executionMode =
      (data['executionMode'] ?? 'workflow').toString().trim().toLowerCase();
  if (executionMode != 'bdfd_script') {
    return List<Map<String, dynamic>>.from(
      (data['actions'] as List?)?.whereType<Map>().map(
            (entry) => Map<String, dynamic>.from(entry),
          ) ??
          const <Map<String, dynamic>>[],
    );
  }

  final source = (data['bdfdScriptContent'] ?? '').toString();
  final compileResult = BdfdCompiler().compile(source);
  if (compileResult.hasErrors) {
    onLog?.call(
      'BDFD compile errors in local legacy command "$commandName": '
      '${_formatBdfdRuntimeDiagnostics(compileResult.diagnostics)}',
    );
    return null;
  }

  return compileResult.actions
      .map((action) => action.toJson())
      .toList(growable: false);
}

Future<bool> _tryExecuteLocalAwaitedInput(
  NyxxGateway gateway, {
  required AppManager manager,
  required String botId,
  required List<Map<String, dynamic>> legacyCommands,
  required EventExecutionContext context,
  void Function(String message)? onLog,
}) async {
  final authorId =
      (context.variables['author.id'] ?? context.variables['user.id'] ?? '')
          .trim();
  final channelId =
      (context.variables['channel.id'] ?? context.channelId?.toString() ?? '')
          .trim();
  final messageContent = (context.variables['message.content'] ?? '').trim();
  if (authorId.isEmpty || channelId.isEmpty || messageContent.isEmpty) {
    return false;
  }

  final callbacks = <String, _AwaitedLocalCallbacks>{};
  for (final command in legacyCommands) {
    final trigger = _parseAwaitedLocalTrigger(
      (command['name'] ?? '').toString(),
    );
    if (trigger == null) {
      continue;
    }

    final current = callbacks[trigger.name] ?? const _AwaitedLocalCallbacks();
    callbacks[trigger.name] =
        trigger.isErrorTrigger
            ? current.copyWith(errorCommand: command)
            : current.copyWith(successCommand: command, filter: trigger.filter);
  }

  if (callbacks.isEmpty) {
    return false;
  }

  for (final entry in callbacks.entries) {
    final awaitName = entry.key;
    final awaitKey = 'await_$awaitName';
    final pendingRaw = await manager.getScopedVariable(
      botId,
      'user',
      authorId,
      awaitKey,
    );
    if (pendingRaw == null) {
      continue;
    }

    Map<String, dynamic> pending = <String, dynamic>{};
    if (pendingRaw is Map) {
      pending = Map<String, dynamic>.from(pendingRaw);
    } else {
      final text = pendingRaw.toString();
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          pending = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        pending = <String, dynamic>{};
      }
    }

    final expectedUser = (pending['userId'] ?? authorId).toString().trim();
    final expectedChannel =
        (pending['channelId'] ?? channelId).toString().trim();
    if (expectedUser.isNotEmpty && expectedUser != authorId) {
      continue;
    }
    if (expectedChannel.isNotEmpty && expectedChannel != channelId) {
      continue;
    }

    final callbackSet = entry.value;
    final passesFilter = _matchesAwaitedLocalFilter(
      messageContent,
      callbackSet.filter,
    );
    final selected =
        passesFilter ? callbackSet.successCommand : callbackSet.errorCommand;
    if (selected == null) {
      return true;
    }

    final data = Map<String, dynamic>.from(
      (selected['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final runtimeVariables = <String, String>{
      ...context.variables,
      'workflow.type': 'command',
    };
    await hydrateRuntimeVariables(
      store: manager,
      botId: botId,
      runtimeVariables: runtimeVariables,
      guildContextId:
          context.variables['guildId'] ?? context.guildId?.toString(),
      channelContextId: channelId,
      userContextId: authorId,
      messageContextId:
          context.variables['messageId'] ?? context.variables['message.id'],
    );

    final commandName =
        (selected['name'] ?? '').toString().trim().toLowerCase();
    runtimeVariables['legacy.command.name'] = commandName;
    runtimeVariables['command.type'] = 'legacy';
    runtimeVariables['interaction.command.type'] = 'legacy';
    runtimeVariables['config.command.type'] = 'chatInput';
    runtimeVariables['interaction.command.name'] = commandName;
    runtimeVariables['interaction.command.route'] = '';

    final response = Map<String, dynamic>.from(
      (data['response'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final actionsJson = await _resolveLocalLegacyActionsJson(
      data: data,
      commandName: commandName,
      onLog: onLog,
    );
    if (actionsJson != null && actionsJson.isNotEmpty) {
      final actions = actionsJson
          .map(
            (entry) => Action.fromJson(
              _adaptLocalLegacyActionForMessageCreate(entry, context),
            ),
          )
          .toList(growable: false);
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
      for (final resultEntry in actionResults.entries) {
        runtimeVariables['action.${resultEntry.key}'] = resultEntry.value;
      }
    }

    await _sendLocalLegacyWorkflowResponse(
      gateway,
      context: context,
      response: response,
      runtimeVariables: runtimeVariables,
      responseTarget: _localLegacyResponseTarget(data),
    );

    await manager.removeScopedVariable(botId, 'user', authorId, awaitKey);
    onLog?.call('Awaited local callback executed: $awaitName');
    return true;
  }

  return false;
}

String _localLegacyResponseTarget(Map<String, dynamic> data) {
  final target = (data['legacyResponseTarget'] ?? 'reply').toString().trim();
  return target == 'channelSend' ? 'channelSend' : 'reply';
}

String _localLegacyOptionTypeLabel(String rawType) {
  final normalized = rawType.trim().toLowerCase();
  switch (normalized) {
    case 'string':
      return 'text';
    case 'integer':
      return 'int';
    case 'number':
      return 'number';
    case 'boolean':
      return 'bool';
    case 'user':
    case 'channel':
    case 'role':
    case 'mentionable':
      return normalized;
    default:
      return normalized.isEmpty ? 'value' : normalized;
  }
}

String _localLegacyUsageSignature({
  required String prefix,
  required String commandName,
  required List<Map<String, dynamic>> options,
}) {
  final parts = <String>[];
  for (final option in options) {
    final optionName = (option['name'] ?? '').toString().trim();
    if (optionName.isEmpty) {
      continue;
    }
    final type = _localLegacyOptionTypeLabel((option['type'] ?? '').toString());
    final isRequired =
        option['required'] == true || option['isRequired'] == true;
    final segment = isRequired ? '<$optionName:$type>' : '[$optionName:$type]';
    parts.add(segment);
  }
  final args = parts.isEmpty ? '' : ' ${parts.join(' ')}';
  return '$prefix$commandName$args';
}

String _buildLocalLegacyHelpMessage({
  required String prefix,
  required List<Map<String, dynamic>> legacyCommands,
  String? specificCommand,
}) {
  final normalizedSpecific = (specificCommand ?? '').trim().toLowerCase();
  final sorted = List<Map<String, dynamic>>.from(legacyCommands)..sort(
    (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
      (b['name'] ?? '').toString().toLowerCase(),
    ),
  );

  final matches =
      normalizedSpecific.isEmpty
          ? sorted
          : sorted
              .where((command) {
                final name =
                    (command['name'] ?? '').toString().trim().toLowerCase();
                return name == normalizedSpecific;
              })
              .toList(growable: false);

  if (matches.isEmpty && normalizedSpecific.isNotEmpty) {
    return 'Unknown legacy command "$normalizedSpecific". Use ${prefix}help to list commands.';
  }

  final lines = <String>[];
  if (normalizedSpecific.isEmpty) {
    lines.add('Legacy help (${sorted.length} commands)');
    lines.add('Use ${prefix}help <command> for details.');
    lines.add('');
  }

  for (final command in matches) {
    final name = (command['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      continue;
    }
    final data = Map<String, dynamic>.from(
      (command['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final description =
        (command['description'] ?? data['description'] ?? '').toString().trim();
    final options =
        (data['options'] as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .where((entry) {
              final rawType = (entry['type'] ?? '').toString().toLowerCase();
              return rawType != 'subcommand' && rawType != 'subcommandgroup';
            })
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];

    final usage = _localLegacyUsageSignature(
      prefix: prefix,
      commandName: name,
      options: options,
    );

    if (normalizedSpecific.isEmpty) {
      lines.add('- $usage${description.isNotEmpty ? ' - $description' : ''}');
    } else {
      lines.add('Command: $name');
      lines.add('Usage: $usage');
      if (description.isNotEmpty) {
        lines.add('Description: $description');
      }
      if (options.isNotEmpty) {
        lines.add('Arguments:');
        for (final option in options) {
          final optionName = (option['name'] ?? '').toString().trim();
          final type = _localLegacyOptionTypeLabel(
            (option['type'] ?? '').toString(),
          );
          final isRequired =
              option['required'] == true || option['isRequired'] == true;
          final optionDescription =
              (option['description'] ?? '').toString().trim();
          lines.add(
            '- $optionName ($type, ${isRequired ? 'required' : 'optional'})${optionDescription.isNotEmpty ? ' - $optionDescription' : ''}',
          );
        }
      }
    }
  }

  var text = lines.join('\n').trimRight();
  if (text.length > 1800) {
    text = '${text.substring(0, 1750).trimRight()}\n...';
  }
  return text;
}

Future<bool> _tryExecuteBuiltInLocalLegacyHelp(
  NyxxGateway gateway, {
  required EventExecutionContext context,
  required String content,
  required String globalPrefix,
  required bool builtInLegacyHelpEnabled,
  required List<Map<String, dynamic>> legacyCommands,
  required Map<String, String> runtimeVariables,
}) async {
  if (!builtInLegacyHelpEnabled) {
    return false;
  }

  final hasCustomHelp = legacyCommands.any(
    (command) =>
        (command['name'] ?? '').toString().trim().toLowerCase() == 'help',
  );
  if (hasCustomHelp) {
    return false;
  }

  final prefixes = <String>{};
  for (final command in legacyCommands) {
    final data = Map<String, dynamic>.from(
      (command['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final overridePrefix =
        (data['legacyPrefixOverride'] ?? '').toString().trim();
    final rawPrefix = overridePrefix.isNotEmpty ? overridePrefix : globalPrefix;
    final resolvedPrefix = updateString(rawPrefix, runtimeVariables).trim();
    if (resolvedPrefix.isNotEmpty) {
      prefixes.add(resolvedPrefix);
    }
  }
  if (prefixes.isEmpty) {
    final fallback = globalPrefix.trim();
    prefixes.add(fallback.isEmpty ? '!' : fallback);
  }

  for (final prefix in prefixes) {
    if (!content.startsWith(prefix)) {
      continue;
    }
    final remainder = content.substring(prefix.length).trimLeft();
    final tokens = remainder
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty || tokens.first.toLowerCase() != 'help') {
      continue;
    }

    final specificCommand = tokens.length > 1 ? tokens[1] : null;
    final helpText = _buildLocalLegacyHelpMessage(
      prefix: prefix,
      legacyCommands: legacyCommands,
      specificCommand: specificCommand,
    );

    await _sendLocalLegacyMessage(
      gateway,
      context: context,
      content: helpText,
      embeds: const <EmbedBuilder>[],
      asReply: true,
    );
    return true;
  }

  return false;
}

Future<Map<String, String>?> _parseLocalLegacyOptionValue(
  NyxxGateway gateway, {
  required String rawType,
  required String token,
  required EventExecutionContext context,
}) async {
  switch (rawType.toLowerCase()) {
    case 'integer':
      final parsed = int.tryParse(token);
      if (parsed == null) return null;
      return <String, String>{'value': parsed.toString()};
    case 'number':
      final parsed = double.tryParse(token);
      if (parsed == null) return null;
      return <String, String>{'value': parsed.toString()};
    case 'boolean':
      final lowered = token.toLowerCase();
      if (lowered == 'true' ||
          lowered == 'yes' ||
          lowered == '1' ||
          lowered == 'on') {
        return <String, String>{'value': 'true'};
      }
      if (lowered == 'false' ||
          lowered == 'no' ||
          lowered == '0' ||
          lowered == 'off') {
        return <String, String>{'value': 'false'};
      }
      return null;
    case 'channel':
      final mentionMatch = RegExp(r'^<#(\d+)>$').firstMatch(token);
      final idText =
          mentionMatch?.group(1) ??
          (RegExp(r'^\d+$').hasMatch(token) ? token : null);
      if (idText != null) {
        final parsedId = int.tryParse(idText);
        if (parsedId == null) {
          return <String, String>{'value': idText, 'id': idText};
        }
        try {
          final channel = await gateway.channels.fetch(Snowflake(parsedId));
          return <String, String>{
            'value': getChannelName(channel),
            'id': channel.id.toString(),
            'type': channel.type.toString(),
          };
        } catch (_) {}
        return <String, String>{'value': idText, 'id': idText};
      }
      if (token.startsWith('#') && context.guildId != null) {
        final wanted = token.substring(1).trim().toLowerCase();
        if (wanted.isEmpty) {
          return null;
        }
        try {
          final guild = await gateway.guilds.fetch(context.guildId!);
          final channels = await guild.fetchChannels();
          for (final channel in channels) {
            final name = channel.name.toLowerCase();
            if (name == wanted) {
              final id = channel.id.toString();
              return <String, String>{
                'value': id,
                'id': id,
                'name': channel.name,
              };
            }
          }
        } catch (_) {}
      }
      return null;
    case 'user':
      final mentionMatch = RegExp(r'^<@!?(\d+)>$').firstMatch(token);
      final idText =
          mentionMatch?.group(1) ??
          (RegExp(r'^\d+$').hasMatch(token) ? token : null);
      if (idText == null) return null;
      final parsedId = int.tryParse(idText);
      if (parsedId == null) {
        return <String, String>{'value': idText, 'id': idText};
      }
      final parsed = <String, String>{'value': idText, 'id': idText};
      try {
        final user = await gateway.users.fetch(Snowflake(parsedId));
        parsed['value'] = user.username;
        parsed['username'] = user.username;
        parsed['name'] = user.username;
        parsed['tag'] = user.discriminator;
        parsed['avatar'] = makeAvatarUrl(
          user.id.toString(),
          avatarId: user.avatar.hash,
          isAnimated: user.avatar.isAnimated,
          legacyFormat: 'webp',
          discriminator: user.discriminator,
        );
      } catch (_) {}
      return parsed;
    case 'role':
      final mentionMatch = RegExp(r'^<@&(\d+)>$').firstMatch(token);
      final idText =
          mentionMatch?.group(1) ??
          (RegExp(r'^\d+$').hasMatch(token) ? token : null);
      if (idText == null) return null;
      final parsedId = int.tryParse(idText);
      if (parsedId == null || context.guildId == null) {
        return <String, String>{'value': idText, 'id': idText};
      }
      try {
        final guild = await gateway.guilds.fetch(context.guildId!);
        final role = await guild.roles.fetch(Snowflake(parsedId));
        return <String, String>{'value': role.name, 'id': role.id.toString()};
      } catch (_) {}
      return <String, String>{'value': idText, 'id': idText};
    case 'mentionable':
      final userMatch = RegExp(r'^<@!?(\d+)>$').firstMatch(token);
      if (userMatch != null) {
        final id = userMatch.group(1)!;
        final parsedId = int.tryParse(id);
        if (parsedId != null) {
          try {
            final user = await gateway.users.fetch(Snowflake(parsedId));
            return <String, String>{
              'value': user.username,
              'id': user.id.toString(),
              'kind': 'user',
              'username': user.username,
              'name': user.username,
              'tag': user.discriminator,
              'avatar': makeAvatarUrl(
                user.id.toString(),
                avatarId: user.avatar.hash,
                isAnimated: user.avatar.isAnimated,
                legacyFormat: 'webp',
                discriminator: user.discriminator,
              ),
            };
          } catch (_) {}
        }
        return <String, String>{'value': id, 'id': id, 'kind': 'user'};
      }
      final roleMatch = RegExp(r'^<@&(\d+)>$').firstMatch(token);
      if (roleMatch != null) {
        final id = roleMatch.group(1)!;
        final parsedId = int.tryParse(id);
        if (parsedId != null && context.guildId != null) {
          try {
            final guild = await gateway.guilds.fetch(context.guildId!);
            final role = await guild.roles.fetch(Snowflake(parsedId));
            return <String, String>{
              'value': role.name,
              'id': role.id.toString(),
              'kind': 'role',
            };
          } catch (_) {}
        }
        return <String, String>{'value': id, 'id': id, 'kind': 'role'};
      }
      if (RegExp(r'^\d+$').hasMatch(token)) {
        final parsedId = int.tryParse(token);
        if (parsedId != null) {
          try {
            final user = await gateway.users.fetch(Snowflake(parsedId));
            return <String, String>{
              'value': user.username,
              'id': user.id.toString(),
              'kind': 'user',
              'username': user.username,
              'name': user.username,
              'tag': user.discriminator,
              'avatar': makeAvatarUrl(
                user.id.toString(),
                avatarId: user.avatar.hash,
                isAnimated: user.avatar.isAnimated,
                legacyFormat: 'webp',
                discriminator: user.discriminator,
              ),
            };
          } catch (_) {}
        }
        if (parsedId != null && context.guildId != null) {
          try {
            final guild = await gateway.guilds.fetch(context.guildId!);
            final role = await guild.roles.fetch(Snowflake(parsedId));
            return <String, String>{
              'value': role.name,
              'id': role.id.toString(),
              'kind': 'role',
            };
          } catch (_) {}
        }
        return <String, String>{'value': token, 'id': token};
      }
      return null;
    default:
      return <String, String>{'value': token};
  }
}

Future<String?> _bindLocalLegacyPositionalOptions(
  NyxxGateway gateway, {
  required Map<String, dynamic> data,
  required List<String> args,
  required String prefix,
  required String commandName,
  required EventExecutionContext context,
  required Map<String, String> runtimeVariables,
}) async {
  final optionsRaw = data['options'];
  if (optionsRaw is! List) {
    runtimeVariables['args.count'] = args.length.toString();
    return null;
  }

  final options = optionsRaw
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .where((entry) {
        final type = (entry['type'] ?? '').toString().toLowerCase();
        return type != 'subcommand' && type != 'subcommandgroup';
      })
      .toList(growable: false);

  var argIndex = 0;
  for (final option in options) {
    final name = (option['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      continue;
    }
    final required = option['required'] == true || option['isRequired'] == true;
    if (argIndex >= args.length) {
      if (required) {
        return 'Missing required option "$name".';
      }
      continue;
    }

    final token = args[argIndex];
    final parsed = await _parseLocalLegacyOptionValue(
      gateway,
      rawType: (option['type'] ?? 'string').toString(),
      token: token,
      context: context,
    );
    if (parsed == null) {
      if (required) {
        return 'Invalid value for required option "$name": $token';
      }
      // Keep this token available for the next optional positional option.
      continue;
    }

    runtimeVariables['opts.$name'] = parsed['value'] ?? token;
    runtimeVariables['legacy.option.$name.raw'] = token;
    for (final entry in parsed.entries) {
      if (entry.key == 'value') continue;
      runtimeVariables['opts.$name.${entry.key}'] = entry.value;
    }

    argIndex++;
  }

  runtimeVariables['args.count'] = args.length.toString();
  runtimeVariables['args.0'] = prefix;
  runtimeVariables['args.1'] = commandName;
  for (var i = 0; i < args.length; i++) {
    runtimeVariables['args.${i + 2}'] = args[i];
  }

  return null;
}

Future<void> _sendLocalLegacyMessage(
  NyxxGateway gateway, {
  required EventExecutionContext context,
  required String content,
  required List<EmbedBuilder> embeds,
  required bool asReply,
}) async {
  if (context.channelId == null) {
    return;
  }

  final channel = await gateway.channels.fetch(context.channelId!);
  final builder = MessageBuilder(
    content: content.isEmpty ? null : content,
    embeds: embeds.isEmpty ? null : embeds,
  );

  if (asReply) {
    final messageIdText = (context.variables['message.id'] ?? '').trim();
    final messageId = int.tryParse(messageIdText);
    if (messageId != null) {
      builder.referencedMessage = MessageReferenceBuilder.reply(
        messageId: Snowflake(messageId),
        channelId: context.channelId,
        guildId: context.guildId,
        failIfInexistent: false,
      );
    }
  }

  await (channel as dynamic).sendMessage(builder);
}

Future<void> _sendLocalLegacyWorkflowResponse(
  NyxxGateway gateway, {
  required EventExecutionContext context,
  required Map<String, dynamic> response,
  required Map<String, String> runtimeVariables,
  required String responseTarget,
}) async {
  final workflowConditional = Map<String, dynamic>.from(
    (response['workflow']?['conditional'] as Map?)?.cast<String, dynamic>() ??
        const {},
  );

  var responseType = (response['type'] ?? 'normal').toString();
  var responseText = (response['text'] ?? '').toString();
  var embedsRaw =
      (response['embeds'] is List)
          ? List<Map<String, dynamic>>.from(
            (response['embeds'] as List).whereType<Map>().map(
              (entry) => Map<String, dynamic>.from(entry),
            ),
          )
          : <Map<String, dynamic>>[];

  if (workflowConditional['enabled'] == true) {
    final variable = (workflowConditional['variable'] ?? '').toString().trim();
    final variableValue =
        variable.contains('((')
            ? updateString(variable, runtimeVariables).trim()
            : (runtimeVariables[variable] ?? '').trim();
    final matched = variableValue.isNotEmpty;

    responseType =
        (matched
                ? workflowConditional['whenTrueType']
                : workflowConditional['whenFalseType'])
            ?.toString() ??
        responseType;
    final conditionalText =
        (matched
                ? workflowConditional['whenTrueText']
                : workflowConditional['whenFalseText'])
            ?.toString() ??
        '';
    if (conditionalText.trim().isNotEmpty) {
      responseText = conditionalText;
    }
    embedsRaw = List<Map<String, dynamic>>.from(
      ((matched
                      ? workflowConditional['whenTrueEmbeds']
                      : workflowConditional['whenFalseEmbeds'])
                  as List?)
              ?.whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry)) ??
          const <Map<String, dynamic>>[],
    );
  }

  if (responseType == 'modal') {
    await _sendLocalLegacyMessage(
      gateway,
      context: context,
      content: 'Modal responses are not supported in legacy command mode.',
      embeds: const <EmbedBuilder>[],
      asReply: responseTarget == 'reply',
    );
    return;
  }

  if (embedsRaw.isEmpty) {
    final legacyEmbed = Map<String, dynamic>.from(
      (response['embed'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final hasLegacyEmbed =
        (legacyEmbed['title']?.toString().isNotEmpty ?? false) ||
        (legacyEmbed['description']?.toString().isNotEmpty ?? false) ||
        (legacyEmbed['url']?.toString().isNotEmpty ?? false);
    if (hasLegacyEmbed) {
      embedsRaw.add(legacyEmbed);
    }
  }

  final embeds = <EmbedBuilder>[];
  for (final embedJson in embedsRaw.take(10)) {
    final embed = EmbedBuilder();
    final title = updateString(
      (embedJson['title'] ?? '').toString(),
      runtimeVariables,
    );
    final description = updateString(
      (embedJson['description'] ?? '').toString(),
      runtimeVariables,
    );
    final urlText =
        updateString(
          (embedJson['url'] ?? '').toString(),
          runtimeVariables,
        ).trim();
    if (title.isNotEmpty) {
      embed.title = title;
    }
    if (description.isNotEmpty) {
      embed.description = description;
    }
    if (urlText.isNotEmpty) {
      final uri = Uri.tryParse(urlText);
      if (uri != null && uri.hasScheme) {
        embed.url = uri;
      }
    }
    if (embed.title != null || embed.description != null || embed.url != null) {
      embeds.add(embed);
    }
  }

  final resolvedText = updateString(responseText, runtimeVariables).trim();
  if (resolvedText.isEmpty && embeds.isEmpty) {
    return;
  }
  final contentToSend = resolvedText;

  await _sendLocalLegacyMessage(
    gateway,
    context: context,
    content: contentToSend,
    embeds: embeds,
    asReply: responseTarget == 'reply',
  );
}

Map<String, dynamic> _adaptLocalLegacyActionForMessageCreate(
  Map<String, dynamic> actionJson,
  EventExecutionContext context,
) {
  final adapted = Map<String, dynamic>.from(actionJson);
  final type = (adapted['type'] ?? '').toString();

  if (type == BotCreatorActionType.respondWithMessage.name) {
    adapted['type'] = BotCreatorActionType.sendMessage.name;
    final payload = Map<String, dynamic>.from(
      (adapted['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    payload['channelId'] =
        (payload['channelId'] ?? '').toString().trim().isNotEmpty
            ? payload['channelId']
            : context.channelId?.toString();
    adapted['payload'] = payload;
    return adapted;
  }

  if (type == BotCreatorActionType.respondWithComponentV2.name) {
    adapted['type'] = BotCreatorActionType.sendComponentV2.name;
    final payload = Map<String, dynamic>.from(
      (adapted['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    payload['channelId'] =
        (payload['channelId'] ?? '').toString().trim().isNotEmpty
            ? payload['channelId']
            : context.channelId?.toString();
    adapted['payload'] = payload;
  }

  final payload = (adapted['payload'] as Map?)?.cast<String, dynamic>();
  if (payload != null) {
    adapted['payload'] = _adaptLocalLegacyValueForMessageCreate(
      Map<String, dynamic>.from(payload),
      context,
    );
  }

  return adapted;
}

dynamic _adaptLocalLegacyValueForMessageCreate(
  dynamic raw,
  EventExecutionContext context,
) {
  if (raw is List) {
    return raw
        .map((entry) => _adaptLocalLegacyValueForMessageCreate(entry, context))
        .toList(growable: false);
  }

  if (raw is Map) {
    final normalized = Map<String, dynamic>.from(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (normalized.containsKey('type')) {
      return _adaptLocalLegacyActionForMessageCreate(normalized, context);
    }
    return normalized.map(
      (key, value) =>
          MapEntry(key, _adaptLocalLegacyValueForMessageCreate(value, context)),
    );
  }

  return raw;
}

Future<bool> _tryExecuteLocalLegacyCommand(
  NyxxGateway gateway, {
  required AppManager manager,
  required String botId,
  required Map<String, dynamic> appData,
  required EventExecutionContext context,
  void Function(String message)? onLog,
}) async {
  final content = (context.variables['message.content'] ?? '').trim();
  if (content.isEmpty) {
    return false;
  }

  final allCommands = await manager.listAppCommands(botId);
  final legacyCommands = allCommands
      .where(_isLegacyLocalCommand)
      .toList(growable: false);
  if (legacyCommands.isEmpty) {
    return false;
  }

  final baseRuntimeVariables = <String, String>{
    ...context.variables,
    'workflow.type': 'command',
  };
  await hydrateRuntimeVariables(
    store: manager,
    botId: botId,
    runtimeVariables: baseRuntimeVariables,
    guildContextId: context.variables['guildId'] ?? context.guildId?.toString(),
    channelContextId:
        context.variables['channelId'] ?? context.channelId?.toString(),
    userContextId:
        context.variables['userId'] ?? context.variables['author.id'],
    messageContextId:
        context.variables['messageId'] ?? context.variables['message.id'],
  );

  final handledBuiltInHelp = await _tryExecuteBuiltInLocalLegacyHelp(
    gateway,
    context: context,
    content: content,
    globalPrefix: (appData['prefix'] ?? '!').toString(),
    builtInLegacyHelpEnabled: appData['builtInLegacyHelpEnabled'] != false,
    legacyCommands: legacyCommands,
    runtimeVariables: baseRuntimeVariables,
  );
  if (handledBuiltInHelp) {
    onLog?.call('Built-in legacy help executed.');
    return true;
  }

  final handledAwaited = await _tryExecuteLocalAwaitedInput(
    gateway,
    manager: manager,
    botId: botId,
    legacyCommands: legacyCommands,
    context: context,
    onLog: onLog,
  );
  if (handledAwaited) {
    return true;
  }

  for (final command in legacyCommands) {
    if (_parseAwaitedLocalTrigger((command['name'] ?? '').toString()) != null) {
      continue;
    }
    final data = Map<String, dynamic>.from(
      (command['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    final runtimeVariables = <String, String>{
      ...context.variables,
      'workflow.type': 'command',
    };
    await hydrateRuntimeVariables(
      store: manager,
      botId: botId,
      runtimeVariables: runtimeVariables,
      guildContextId:
          context.variables['guildId'] ?? context.guildId?.toString(),
      channelContextId:
          context.variables['channelId'] ?? context.channelId?.toString(),
      userContextId:
          context.variables['userId'] ?? context.variables['author.id'],
      messageContextId:
          context.variables['messageId'] ?? context.variables['message.id'],
    );

    final overridePrefix =
        (data['legacyPrefixOverride'] ?? '').toString().trim();
    final globalPrefix = (appData['prefix'] ?? '!').toString();
    final rawPrefix = overridePrefix.isNotEmpty ? overridePrefix : globalPrefix;
    final prefix = updateString(rawPrefix, runtimeVariables).trim();
    if (prefix.isEmpty || !content.startsWith(prefix)) {
      continue;
    }

    final remainder = content.substring(prefix.length).trimLeft();
    if (remainder.isEmpty) {
      continue;
    }

    final tokens = remainder
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      continue;
    }

    final commandName = (command['name'] ?? '').toString().trim().toLowerCase();
    if (tokens.first.toLowerCase() != commandName) {
      continue;
    }

    final args = tokens.length > 1 ? tokens.sublist(1) : const <String>[];
    runtimeVariables['message.content[0]'] = commandName;
    for (var i = 0; i < args.length; i++) {
      runtimeVariables['message.content[${i + 1}]'] = args[i];
    }
    runtimeVariables['legacy.prefix'] = prefix;
    runtimeVariables['legacy.command.name'] = commandName;
    runtimeVariables['command.type'] = 'legacy';
    runtimeVariables['interaction.command.type'] = 'legacy';
    runtimeVariables['config.command.type'] = 'chatInput';
    runtimeVariables['interaction.command.name'] = commandName;
    runtimeVariables['interaction.command.route'] = '';

    final optionError = await _bindLocalLegacyPositionalOptions(
      gateway,
      data: data,
      args: args,
      prefix: prefix,
      commandName: commandName,
      context: context,
      runtimeVariables: runtimeVariables,
    );
    final responseTarget = _localLegacyResponseTarget(data);
    if (optionError != null) {
      await _sendLocalLegacyMessage(
        gateway,
        context: context,
        content: optionError,
        embeds: const <EmbedBuilder>[],
        asReply: responseTarget == 'reply',
      );
      onLog?.call('Legacy command validation failed: $optionError');
      return true;
    }

    final response = Map<String, dynamic>.from(
      (data['response'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final executionMode =
        (data['executionMode'] ?? 'workflow').toString().trim().toLowerCase();
    final actionsJson = await _resolveLocalLegacyActionsJson(
      data: data,
      commandName: commandName,
      onLog: onLog,
    );
    if (actionsJson == null) {
      await _sendLocalLegacyMessage(
        gateway,
        context: context,
        content: 'Failed to compile BDFD script for command "$commandName".',
        embeds: const <EmbedBuilder>[],
        asReply: responseTarget == 'reply',
      );
      return true;
    }
    final actions = List<Action>.from(
      actionsJson.map(
        (entry) => Action.fromJson(
          _adaptLocalLegacyActionForMessageCreate(entry, context),
        ),
      ),
    );

    if (actions.isNotEmpty) {
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
      for (final entry in actionResults.entries) {
        runtimeVariables['action.${entry.key}'] = entry.value;
      }
    }

    if (executionMode != 'bdfd_script') {
      await _sendLocalLegacyWorkflowResponse(
        gateway,
        context: context,
        response: response,
        runtimeVariables: runtimeVariables,
        responseTarget: responseTarget,
      );
    }

    onLog?.call('Legacy command executed: $commandName');
    return true;
  }

  return false;
}
