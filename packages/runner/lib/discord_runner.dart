import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bot_creator_shared/actions/handle_component_interaction.dart';
import 'package:bot_creator_shared/actions/handler.dart';
import 'package:bot_creator_shared/actions/interaction_response.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/events/event_contexts.dart';
import 'package:bot_creator_shared/utils/command_autocomplete.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:bot_creator_shared/utils/workflow_call.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:nyxx/nyxx.dart';

import 'command_workflow_routing.dart';
import 'runner_data_store.dart';
import 'stores/command_stats_store.dart';

final _log = Logger('BotRunner');

/// Connects to Discord via nyxx, registers command listeners, and dispatches
/// interactions to the shared action handlers — matching commands by their Discord ID.
class DiscordRunner {
  final BotConfig config;
  final RunnerDataStore store;
  final CommandStatsStore? statsStore;

  NyxxGateway? _gateway;
  Timer? _statusRotationTimer;
  final Random _random = Random();

  DiscordRunner(this.config, {this.statsStore})
    : store = RunnerDataStore(config);

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

    if (interaction is ApplicationCommandAutocompleteInteraction) {
      final commandId = interaction.data.id.toString();
      final commandData = _findCommand(
        commandId,
        name: interaction.data.name,
        type: _commandTypeToStorage(interaction.data.type),
      );
      if (commandData == null) {
        await interaction.respond(
          const <CommandOptionChoiceBuilder<dynamic>>[],
        );
        return;
      }

      await _executeAutocomplete(
        client: client,
        botId: botId,
        interaction: interaction,
        commandData: commandData,
      );
    } else if (interaction is ApplicationCommandInteraction) {
      final commandId = interaction.data.id.toString();
      final interactionType = _commandTypeToStorage(interaction.data.type);

      // Match by Discord command ID (same logic as bot.commands.dart)
      final commandData = _findCommand(
        commandId,
        name: interaction.data.name,
        type: interactionType,
      );
      if (commandData == null) {
        _log.warning(
          'Command $commandId (${interaction.data.name}, type=$interactionType) not found in config',
        );
        await _safeRespond(
          interaction,
          'Command not found.',
          isEphemeral: true,
        );
        return;
      }

      final storedType = _storedCommandType(commandData);
      if (storedType != interactionType) {
        _log.warning(
          'Command type mismatch for ${interaction.data.name} ($commandId): stored=$storedType, incoming=$interactionType. Executing anyway.',
        );
      } else {
        _log.info(
          'Executing ${interaction.data.name} ($commandId) as $interactionType command.',
        );
      }

      await _executeCommand(
        client: client,
        botId: botId,
        interaction: interaction,
        commandData: commandData,
      );

      // Record command usage
      statsStore?.record(
        botId: botId,
        commandName: interaction.data.name,
        guildId: interaction.guild?.id.toString() ?? '',
      );
    } else if (interaction is MessageComponentInteraction) {
      await handleComponentInteraction(client, interaction, store, botId);
    } else if (interaction is ModalSubmitInteraction) {
      await handleModalSubmitInteraction(client, interaction, store, botId);
    }
  }

  Map<String, dynamic>? _findCommand(
    String discordCommandId, {
    String? name,
    String? type,
  }) {
    for (final cmd in config.commands) {
      if ((cmd['id'] ?? '').toString() == discordCommandId) {
        return cmd;
      }
    }
    // Fallback: match by name+type when the local ID is a stale temp ID.
    if (name != null) {
      final normalizedType = (type ?? 'chatinput').toLowerCase();
      for (final cmd in config.commands) {
        if ((cmd['name'] ?? '').toString() == name &&
            (cmd['type'] ?? 'chatInput').toString().toLowerCase() ==
                normalizedType) {
          return cmd;
        }
      }
    }
    return null;
  }

  String _storedCommandType(Map<String, dynamic> commandData) {
    final data = Map<String, dynamic>.from(
      (commandData['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final raw =
        (data['commandType'] ?? commandData['type'] ?? 'chatInput')
            .toString()
            .trim()
            .toLowerCase();

    switch (raw) {
      case 'user':
      case 'usercommand':
      case 'user_command':
      case 'user-command':
        return 'user';
      case 'message':
      case 'messagecommand':
      case 'message_command':
      case 'message-command':
        return 'message';
      case 'chatinput':
      case 'chat_input':
      case 'chat-input':
      case 'slash':
      default:
        return 'chatInput';
    }
  }

  String _commandTypeToStorage(ApplicationCommandType type) {
    if (type == ApplicationCommandType.user) {
      return 'user';
    }
    if (type == ApplicationCommandType.message) {
      return 'message';
    }
    return 'chatInput';
  }

  void _registerEventWorkflowListeners() {
    final gateway = _gateway;
    if (gateway == null) {
      return;
    }

    final hasLegacyCommands = config.commands.any(_isLegacyCommandEnabled);
    if (_eventWorkflows.isEmpty && !hasLegacyCommands) {
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

    if (_eventWorkflows.isEmpty && hasLegacyCommands) {
      registerEvent<MessageCreateEvent>(
        gateway.onMessageCreate,
        'messageCreate',
        buildContext: buildMessageCreateEventContext,
      );
      _log.info(
        'No event workflows found; enabled messageCreate listener for legacy commands only.',
      );
      return;
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
    if (eventName.toLowerCase() == 'messagecreate') {
      final isBotMessage =
          (context.variables['message.isBot'] ??
                  context.variables['author.isBot'] ??
                  '')
              .toLowerCase() ==
          'true';
      if (isBotMessage) {
        return;
      }

      final handledLegacy = await _tryExecuteLegacyCommand(context);
      if (handledLegacy) {
        return;
      }
    }

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

  bool _isLegacyCommandEnabled(Map<String, dynamic> command) {
    final data = Map<String, dynamic>.from(
      (command['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final value = Map<String, dynamic>.from(
      (data['data'] as Map?)?.cast<String, dynamic>() ?? data,
    );
    final commandType =
        (value['commandType'] ?? command['type'] ?? 'chatInput')
            .toString()
            .toLowerCase();
    return value['legacyModeEnabled'] == true &&
        (commandType == 'chatinput' ||
            commandType == 'chat_input' ||
            commandType == 'chat-input' ||
            commandType == 'slash');
  }

  List<String> _splitLegacyTokens(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    return trimmed.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  String _effectiveLegacyResponseTarget(Map<String, dynamic> value) {
    final raw = (value['legacyResponseTarget'] ?? 'reply').toString().trim();
    return raw == 'channelSend' ? 'channelSend' : 'reply';
  }

  Future<String?> _resolveLegacyPrefix({
    required Map<String, dynamic> value,
    required Map<String, String> runtimeVariables,
  }) async {
    final commandOverride =
        (value['legacyPrefixOverride'] ?? '').toString().trim();
    final globalPrefix = config.prefix.trim().isEmpty ? '!' : config.prefix;
    final rawPrefix =
        commandOverride.isNotEmpty ? commandOverride : globalPrefix;
    final resolved =
        resolveTemplatePlaceholders(rawPrefix, runtimeVariables).trim();
    if (resolved.isEmpty) {
      return null;
    }
    return resolved;
  }

  String _legacyOptionTypeLabel(String rawType) {
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

  String _legacyUsageSignature({
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
      final type = _legacyOptionTypeLabel((option['type'] ?? '').toString());
      final isRequired =
          option['required'] == true || option['isRequired'] == true;
      final segment =
          isRequired ? '<$optionName:$type>' : '[$optionName:$type]';
      parts.add(segment);
    }
    final args = parts.isEmpty ? '' : ' ${parts.join(' ')}';
    return '$prefix$commandName$args';
  }

  String _buildLegacyHelpMessage({
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
      final value = Map<String, dynamic>.from(
        (data['data'] as Map?)?.cast<String, dynamic>() ?? data,
      );
      final description =
          (command['description'] ?? value['description'] ?? '')
              .toString()
              .trim();
      final options =
          (value['options'] as List?)
              ?.whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .where((entry) {
                final rawType = (entry['type'] ?? '').toString().toLowerCase();
                return rawType != 'subcommand' && rawType != 'subcommandgroup';
              })
              .toList(growable: false) ??
          const <Map<String, dynamic>>[];

      final usage = _legacyUsageSignature(
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
            final type = _legacyOptionTypeLabel(
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

  Future<bool> _tryExecuteBuiltInLegacyHelp(
    EventExecutionContext context, {
    required String content,
    required String botId,
    required List<Map<String, dynamic>> legacyCommands,
    required Map<String, String> runtimeVariables,
  }) async {
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
      final value = Map<String, dynamic>.from(
        (data['data'] as Map?)?.cast<String, dynamic>() ?? data,
      );
      final prefix = await _resolveLegacyPrefix(
        value: value,
        runtimeVariables: runtimeVariables,
      );
      if (prefix != null && prefix.isNotEmpty) {
        prefixes.add(prefix);
      }
    }
    if (prefixes.isEmpty) {
      prefixes.add(config.prefix.trim().isEmpty ? '!' : config.prefix.trim());
    }

    for (final prefix in prefixes) {
      if (!content.startsWith(prefix)) {
        continue;
      }
      final remainder = content.substring(prefix.length).trimLeft();
      final tokens = _splitLegacyTokens(remainder);
      if (tokens.isEmpty || tokens.first.toLowerCase() != 'help') {
        continue;
      }

      final specificCommand = tokens.length > 1 ? tokens[1] : null;
      final helpText = _buildLegacyHelpMessage(
        prefix: prefix,
        legacyCommands: legacyCommands,
        specificCommand: specificCommand,
      );
      await _sendLegacyMessage(
        context: context,
        content: helpText,
        embeds: const <EmbedBuilder>[],
        asReply: true,
      );
      _log.info('Built-in legacy help executed for bot $botId');
      return true;
    }

    return false;
  }

  Future<Map<String, String>?> _parseLegacyOptionValue({
    required String rawType,
    required String token,
    required EventExecutionContext context,
  }) async {
    final normalizedType = rawType.toLowerCase();
    switch (normalizedType) {
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
          if (parsedId == null || _gateway == null) {
            return <String, String>{'value': idText, 'id': idText};
          }
          try {
            final channel = await _gateway!.channels.fetch(Snowflake(parsedId));
            return <String, String>{
              'value': getChannelName(channel),
              'id': channel.id.toString(),
              'type': channel.type.toString(),
            };
          } catch (_) {}
          return <String, String>{'value': idText, 'id': idText};
        }
        if (token.startsWith('#') &&
            context.guildId != null &&
            _gateway != null) {
          final channelName = token.substring(1).trim().toLowerCase();
          if (channelName.isEmpty) {
            return null;
          }
          try {
            final guild = await _gateway!.guilds.fetch(context.guildId!);
            final channels = await guild.fetchChannels();
            for (final channel in channels) {
              final name = channel.name.toLowerCase();
              if (name == channelName) {
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
        if (idText == null) {
          return null;
        }
        final parsedId = int.tryParse(idText);
        if (parsedId == null) {
          return <String, String>{'value': idText, 'id': idText};
        }
        final parsed = <String, String>{'value': idText, 'id': idText};
        if (_gateway != null) {
          try {
            final user = await _gateway!.users.fetch(Snowflake(parsedId));
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
            parsed['banner'] = makeBannerUrl(
              user.id.toString(),
              bannerId: (user as dynamic).banner?.hash?.toString(),
              isAnimated: (user as dynamic).banner?.isAnimated == true,
              legacyFormat: 'webp',
            );
          } catch (_) {}
        }
        return parsed;
      case 'role':
        final mentionMatch = RegExp(r'^<@&(\d+)>$').firstMatch(token);
        final idText =
            mentionMatch?.group(1) ??
            (RegExp(r'^\d+$').hasMatch(token) ? token : null);
        if (idText == null) {
          return null;
        }
        final parsedId = int.tryParse(idText);
        if (parsedId == null || context.guildId == null || _gateway == null) {
          return <String, String>{'value': idText, 'id': idText};
        }
        try {
          final guild = await _gateway!.guilds.fetch(context.guildId!);
          final role = await guild.roles.fetch(Snowflake(parsedId));
          return <String, String>{'value': role.name, 'id': role.id.toString()};
        } catch (_) {}
        return <String, String>{'value': idText, 'id': idText};
      case 'mentionable':
        final userMatch = RegExp(r'^<@!?(\d+)>$').firstMatch(token);
        if (userMatch != null) {
          final id = userMatch.group(1)!;
          final parsedId = int.tryParse(id);
          if (parsedId != null && _gateway != null) {
            try {
              final user = await _gateway!.users.fetch(Snowflake(parsedId));
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
                'banner': makeBannerUrl(
                  user.id.toString(),
                  bannerId: (user as dynamic).banner?.hash?.toString(),
                  isAnimated: (user as dynamic).banner?.isAnimated == true,
                  legacyFormat: 'webp',
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
          if (parsedId != null && context.guildId != null && _gateway != null) {
            try {
              final guild = await _gateway!.guilds.fetch(context.guildId!);
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
          if (parsedId != null && _gateway != null) {
            try {
              final user = await _gateway!.users.fetch(Snowflake(parsedId));
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
                'banner': makeBannerUrl(
                  user.id.toString(),
                  bannerId: (user as dynamic).banner?.hash?.toString(),
                  isAnimated: (user as dynamic).banner?.isAnimated == true,
                  legacyFormat: 'webp',
                ),
              };
            } catch (_) {}
          }
          if (parsedId != null && context.guildId != null && _gateway != null) {
            try {
              final guild = await _gateway!.guilds.fetch(context.guildId!);
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

  Future<String?> _bindLegacyPositionalOptions({
    required Map<String, dynamic> value,
    required List<String> args,
    required EventExecutionContext context,
    required Map<String, String> runtimeVariables,
  }) async {
    final rawOptions = value['options'];
    if (rawOptions is! List) {
      runtimeVariables['args.count'] = args.length.toString();
      return null;
    }

    final optionMaps = rawOptions
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((entry) {
          final rawType = (entry['type'] ?? '').toString().toLowerCase();
          return rawType != 'subcommand' && rawType != 'subcommandgroup';
        })
        .toList(growable: false);

    var argIndex = 0;
    for (final option in optionMaps) {
      final optionName = (option['name'] ?? '').toString().trim();
      if (optionName.isEmpty) {
        continue;
      }
      final isRequired =
          option['required'] == true || option['isRequired'] == true;
      if (argIndex >= args.length) {
        if (isRequired) {
          return 'Missing required option "$optionName".';
        }
        continue;
      }

      final token = args[argIndex];
      final parsed = await _parseLegacyOptionValue(
        rawType: (option['type'] ?? 'string').toString(),
        token: token,
        context: context,
      );
      if (parsed == null) {
        if (isRequired) {
          return 'Invalid value for required option "$optionName": $token';
        }
        argIndex++;
        continue;
      }

      runtimeVariables['opts.$optionName'] = parsed['value'] ?? token;
      runtimeVariables['legacy.option.$optionName.raw'] = token;
      for (final entry in parsed.entries) {
        if (entry.key == 'value') {
          continue;
        }
        runtimeVariables['opts.$optionName.${entry.key}'] = entry.value;
      }

      argIndex++;
    }

    runtimeVariables['args.count'] = args.length.toString();
    for (var i = 0; i < args.length; i++) {
      runtimeVariables['args.${i + 1}'] = args[i];
    }
    return null;
  }

  Future<void> _sendLegacyMessage({
    required EventExecutionContext context,
    required String content,
    required List<EmbedBuilder> embeds,
    required bool asReply,
  }) async {
    if (_gateway == null || context.channelId == null) {
      return;
    }

    final channel = await _gateway!.channels.fetch(context.channelId!);
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

  Future<void> _sendLegacyWorkflowResponse({
    required EventExecutionContext context,
    required Map<String, dynamic> response,
    required Map<String, String> runtimeVariables,
    required String responseTarget,
  }) async {
    final workflowConditional = Map<String, dynamic>.from(
      (response['workflow']?['conditional'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );

    final useCondition = workflowConditional['enabled'] == true;
    final conditionVariable =
        (workflowConditional['variable'] ?? '').toString().trim();
    final whenTrueType =
        (workflowConditional['whenTrueType'] ?? 'normal').toString();
    final whenFalseType =
        (workflowConditional['whenFalseType'] ?? 'normal').toString();
    final whenTrueText = (workflowConditional['whenTrueText'] ?? '').toString();
    final whenFalseText =
        (workflowConditional['whenFalseText'] ?? '').toString();

    var activeResponseType = (response['type'] ?? 'normal').toString();
    var responseText = (response['text'] ?? '').toString();
    var embedsRaw =
        (response['embeds'] is List)
            ? List<Map<String, dynamic>>.from(
              (response['embeds'] as List).whereType<Map>().map(
                (entry) => Map<String, dynamic>.from(entry),
              ),
            )
            : <Map<String, dynamic>>[];

    if (useCondition && conditionVariable.isNotEmpty) {
      final variableValue =
          conditionVariable.contains('((')
              ? resolveTemplatePlaceholders(
                conditionVariable,
                runtimeVariables,
              ).trim()
              : (runtimeVariables[conditionVariable] ?? '').trim();
      final matched = variableValue.isNotEmpty;
      if (matched) {
        activeResponseType = whenTrueType;
        if (whenTrueText.trim().isNotEmpty) {
          responseText = whenTrueText;
        }
        embedsRaw = List<Map<String, dynamic>>.from(
          (workflowConditional['whenTrueEmbeds'] as List?)
                  ?.whereType<Map>()
                  .map((entry) => Map<String, dynamic>.from(entry)) ??
              const <Map<String, dynamic>>[],
        );
      } else {
        activeResponseType = whenFalseType;
        if (whenFalseText.trim().isNotEmpty) {
          responseText = whenFalseText;
        }
        embedsRaw = List<Map<String, dynamic>>.from(
          (workflowConditional['whenFalseEmbeds'] as List?)
                  ?.whereType<Map>()
                  .map((entry) => Map<String, dynamic>.from(entry)) ??
              const <Map<String, dynamic>>[],
        );
      }
    }

    if (activeResponseType == 'modal') {
      await _sendLegacyMessage(
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
      final title = resolveTemplatePlaceholders(
        (embedJson['title'] ?? '').toString(),
        runtimeVariables,
      );
      final description = resolveTemplatePlaceholders(
        (embedJson['description'] ?? '').toString(),
        runtimeVariables,
      );
      final urlText =
          resolveTemplatePlaceholders(
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
      if (embed.title != null ||
          embed.description != null ||
          embed.url != null) {
        embeds.add(embed);
      }
    }

    final resolvedText =
        resolveTemplatePlaceholders(responseText, runtimeVariables).trim();
    final fallbackText =
        activeResponseType == 'componentV2'
            ? 'Legacy command executed (component layout is not rendered in legacy mode).'
            : 'Legacy command executed.';
    final contentToSend =
        resolvedText.isNotEmpty || embeds.isNotEmpty
            ? resolvedText
            : fallbackText;

    await _sendLegacyMessage(
      context: context,
      content: contentToSend,
      embeds: embeds,
      asReply: responseTarget == 'reply',
    );
  }

  Map<String, dynamic> _adaptLegacyActionForMessageCreate(
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
      return adapted;
    }

    return adapted;
  }

  Future<bool> _tryExecuteLegacyCommand(EventExecutionContext context) async {
    final gateway = _gateway;
    if (gateway == null) {
      return false;
    }

    final content = (context.variables['message.content'] ?? '').trim();
    if (content.isEmpty) {
      return false;
    }

    final botId = gateway.user.id.toString();
    final legacyCommands = config.commands
        .where(_isLegacyCommandEnabled)
        .toList(growable: false);
    if (legacyCommands.isEmpty) {
      return false;
    }

    final baseRuntimeVariables = <String, String>{
      ...context.variables,
      'workflow.type': 'command',
    };
    await hydrateRuntimeVariables(
      store: store,
      botId: botId,
      runtimeVariables: baseRuntimeVariables,
      guildContextId:
          context.variables['guildId'] ?? context.guildId?.toString(),
      channelContextId:
          context.variables['channelId'] ?? context.channelId?.toString(),
      userContextId:
          context.variables['userId'] ?? context.variables['author.id'],
      messageContextId:
          context.variables['messageId'] ?? context.variables['message.id'],
    );

    final handledBuiltInHelp = await _tryExecuteBuiltInLegacyHelp(
      context,
      content: content,
      botId: botId,
      legacyCommands: legacyCommands,
      runtimeVariables: baseRuntimeVariables,
    );
    if (handledBuiltInHelp) {
      return true;
    }

    for (final command in legacyCommands) {
      final data = Map<String, dynamic>.from(
        (command['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final value = Map<String, dynamic>.from(
        (data['data'] as Map?)?.cast<String, dynamic>() ?? data,
      );
      final runtimeVariables = <String, String>{...context.variables};
      runtimeVariables['workflow.type'] = 'command';

      await hydrateRuntimeVariables(
        store: store,
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

      final prefix = await _resolveLegacyPrefix(
        value: value,
        runtimeVariables: runtimeVariables,
      );
      if (prefix == null || prefix.isEmpty || !content.startsWith(prefix)) {
        continue;
      }

      final remainder = content.substring(prefix.length).trimLeft();
      if (remainder.isEmpty) {
        continue;
      }
      final tokens = _splitLegacyTokens(remainder);
      if (tokens.isEmpty) {
        continue;
      }

      final incomingName = tokens.first.trim().toLowerCase();
      final commandName =
          (command['name'] ?? '').toString().trim().toLowerCase();
      if (incomingName != commandName) {
        continue;
      }

      final args = tokens.length > 1 ? tokens.sublist(1) : const <String>[];
      runtimeVariables['legacy.prefix'] = prefix;
      runtimeVariables['legacy.command.name'] = commandName;
      runtimeVariables['command.type'] = 'legacy';
      runtimeVariables['interaction.command.type'] = 'legacy';
      runtimeVariables['config.command.type'] = 'chatInput';
      runtimeVariables['interaction.command.name'] = commandName;
      runtimeVariables['interaction.command.route'] = '';

      final optionError = await _bindLegacyPositionalOptions(
        value: value,
        args: args,
        context: context,
        runtimeVariables: runtimeVariables,
      );
      if (optionError != null) {
        await _sendLegacyMessage(
          context: context,
          content: optionError,
          embeds: const <EmbedBuilder>[],
          asReply: _effectiveLegacyResponseTarget(value) == 'reply',
        );
        return true;
      }

      final response = Map<String, dynamic>.from(
        (value['response'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final actionsJson = List<Map<String, dynamic>>.from(
        (value['actions'] as List?)?.whereType<Map>().map(
              (entry) => Map<String, dynamic>.from(entry),
            ) ??
            const <Map<String, dynamic>>[],
      );

      if (actionsJson.isNotEmpty) {
        final actions = actionsJson
            .map((json) => _adaptLegacyActionForMessageCreate(json, context))
            .map(Action.fromJson)
            .toList(growable: false);
        final actionResults = await handleActions(
          gateway,
          null,
          actions: actions,
          store: store,
          botId: botId,
          variables: runtimeVariables,
          resolveTemplate:
              (input) => resolveTemplatePlaceholders(input, runtimeVariables),
          fallbackChannelId: context.channelId,
          fallbackGuildId: context.guildId,
          onLog: (msg) => _log.info(msg),
        );
        for (final entry in actionResults.entries) {
          runtimeVariables['action.${entry.key}'] = entry.value;
        }
      }

      await _sendLegacyWorkflowResponse(
        context: context,
        response: response,
        runtimeVariables: runtimeVariables,
        responseTarget: _effectiveLegacyResponseTarget(value),
      );
      _log.info('Legacy command executed: $commandName');
      return true;
    }

    return false;
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

    // Inject guild variables (systemChannelId, etc.) for event workflows.
    final eventGuildId = context.guildId;
    if (eventGuildId != null && _gateway != null) {
      try {
        final guild = await _gateway!.guilds.fetch(eventGuildId);
        runtimeVariables.addAll(extractGuildRuntimeDetails(guild));
      } catch (_) {}
    }

    await hydrateRuntimeVariables(
      store: store,
      botId: botId,
      runtimeVariables: runtimeVariables,
      guildContextId:
          context.variables['guildId'] ?? context.guildId?.toString(),
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
    final subcommandRoute = resolveSubcommandRoute(interaction.data.options);
    final routePayload =
        (subcommandRoute == null)
            ? null
            : resolveSubcommandWorkflowPayload(value, subcommandRoute);
    final executionValue = routePayload ?? value;

    final response = Map<String, dynamic>.from(
      (executionValue['response'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final workflow = Map<String, dynamic>.from(
      (response['workflow'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final workflowConditional = Map<String, dynamic>.from(
      (workflow['conditional'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    // Build runtime variables from interaction
    final runtimeVariables = await generateKeyValues(interaction);
    final interactionType = _commandTypeToStorage(interaction.data.type);
    final storedType = _storedCommandType(commandData);
    runtimeVariables['command.type'] = interactionType;
    runtimeVariables['interaction.command.type'] = interactionType;
    runtimeVariables['config.command.type'] = storedType;
    runtimeVariables['interaction.command.name'] = interaction.data.name;
    runtimeVariables['interaction.command.id'] = interaction.data.id.toString();
    runtimeVariables['interaction.command.route'] = subcommandRoute ?? '';
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

    final dynamic rawInteraction = interaction;
    await hydrateRuntimeVariables(
      store: store,
      botId: botId,
      runtimeVariables: runtimeVariables,
      guildContextId:
          normalizeContextId(runtimeVariables['guildId']) ??
          normalizeContextId(runtimeVariables['guild.id']) ??
          normalizeContextId(rawInteraction.guildId?.toString()) ??
          normalizeContextId(rawInteraction.guild?.id?.toString()),
      channelContextId:
          normalizeContextId(runtimeVariables['channelId']) ??
          normalizeContextId(runtimeVariables['channel.id']) ??
          normalizeContextId(rawInteraction.channelId?.toString()) ??
          normalizeContextId(rawInteraction.channel?.id?.toString()) ??
          normalizeContextId(rawInteraction.message?.channelId?.toString()),
      userContextId:
          normalizeContextId(runtimeVariables['userId']) ??
          normalizeContextId(runtimeVariables['user.id']) ??
          normalizeContextId(runtimeVariables['interaction.userId']) ??
          normalizeContextId(rawInteraction.user?.id?.toString()) ??
          normalizeContextId(rawInteraction.member?.user?.id?.toString()) ??
          normalizeContextId(rawInteraction.author?.id?.toString()),
      messageContextId:
          normalizeContextId(runtimeVariables['messageId']) ??
          normalizeContextId(runtimeVariables['message.id']) ??
          normalizeContextId(rawInteraction.message?.id?.toString()) ??
          normalizeContextId(rawInteraction.id?.toString()),
    );

    // Collect actions
    var actionsJson = List<Map<String, dynamic>>.from(
      (executionValue['actions'] as List?)?.whereType<Map>().map(
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
    final interactionId = interaction.id.toString();

    try {
      _log.fine(
        'Interaction $interactionId: executing command with ${actionsJson.length} action(s), shouldDefer=$shouldDefer, responseType=$responseType',
      );

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
        _log.fine('Interaction $interactionId: defer acknowledged.');
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
      _log.fine('Interaction $interactionId: sendWorkflowResponse completed.');
    } catch (e, st) {
      _log.severe('Error executing command ${commandData['name']}: $e', e, st);
      // Surface specific, user-safe error messages from permission checks.
      final errorMsg = e.toString();
      String? userMessage;
      if (errorMsg.contains('I do not have permission') ||
          errorMsg.contains('I cannot')) {
        userMessage = errorMsg.replaceFirst('Exception: ', '');
      }
      await _safeErrorResponse(
        interaction,
        didDefer: didDefer,
        isEphemeral: isEphemeral,
        errorMessage: userMessage,
      );
    }
  }

  Future<void> _executeAutocomplete({
    required NyxxGateway client,
    required String botId,
    required ApplicationCommandAutocompleteInteraction interaction,
    required Map<String, dynamic> commandData,
  }) async {
    try {
      final data = Map<String, dynamic>.from(
        (commandData['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final value = Map<String, dynamic>.from(
        (data['data'] as Map?)?.cast<String, dynamic>() ?? data,
      );
      final autocompleteConfig = resolveAutocompleteConfigForInteraction(
        storedOptions: value['options'],
        interactionOptions: interaction.data.options,
      );
      if (autocompleteConfig == null || autocompleteConfig['enabled'] != true) {
        await interaction.respond(
          const <CommandOptionChoiceBuilder<dynamic>>[],
        );
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
        await interaction.respond(
          const <CommandOptionChoiceBuilder<dynamic>>[],
        );
        return;
      }

      final workflow = await store.getWorkflowByName(botId, workflowName);
      if (workflow == null) {
        await interaction.respond(
          const <CommandOptionChoiceBuilder<dynamic>>[],
        );
        return;
      }

      final normalizedWorkflow = normalizeStoredWorkflowDefinition(workflow);
      if (normalizeWorkflowType(normalizedWorkflow['workflowType']) !=
          workflowTypeGeneral) {
        await interaction.respond(
          const <CommandOptionChoiceBuilder<dynamic>>[],
        );
        return;
      }

      final focusedOption = findFocusedOption(interaction.data.options);
      final runtimeVariables = await generateKeyValues(interaction);
      runtimeVariables['command.type'] = 'chatInput';
      runtimeVariables['interaction.command.type'] = 'chatInput';
      runtimeVariables['config.command.type'] = 'chatInput';
      runtimeVariables['interaction.command.name'] = interaction.data.name;
      runtimeVariables['interaction.command.id'] =
          interaction.data.id.toString();
      runtimeVariables['interaction.command.route'] =
          resolveSubcommandRoute(interaction.data.options) ?? '';
      runtimeVariables['autocomplete.query'] =
          focusedOption?.value?.toString() ?? '';
      runtimeVariables['autocomplete.optionName'] = focusedOption?.name ?? '';
      runtimeVariables['autocomplete.optionType'] =
          focusedOption == null
              ? 'string'
              : commandOptionTypeToText(focusedOption.type);
      runtimeVariables['workflow.type'] = workflowTypeGeneral;

      await hydrateRuntimeVariables(
        store: store,
        botId: botId,
        runtimeVariables: runtimeVariables,
        guildContextId: runtimeVariables['guildId'],
        channelContextId: runtimeVariables['channelId'],
        userContextId: runtimeVariables['userId'],
        messageContextId:
            runtimeVariables['messageId'] ?? runtimeVariables['message.id'],
      );

      final providedArguments = resolveWorkflowCallArguments(
        autocompleteConfig['arguments'],
        (input) => resolveTemplatePlaceholders(
          input,
          Map<String, String>.from(runtimeVariables),
        ),
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
        enforceRequired: false,
      );

      final actions = List<Action>.from(
        ((normalizedWorkflow['actions'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((json) => Action.fromJson(Map<String, dynamic>.from(json))),
      );
      if (actions.isEmpty) {
        await interaction.respond(
          const <CommandOptionChoiceBuilder<dynamic>>[],
        );
        return;
      }

      try {
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

        if (!actionResults.containsKey('__stopped__')) {
          await interaction.respond(
            const <CommandOptionChoiceBuilder<dynamic>>[],
          );
        }
      } catch (error, stackTrace) {
        _log.warning(
          'Autocomplete workflow "$workflowName" failed: $error',
          error,
          stackTrace,
        );
        try {
          await interaction.respond(
            const <CommandOptionChoiceBuilder<dynamic>>[],
          );
        } catch (_) {}
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Autocomplete interaction failed: $error',
        error,
        stackTrace,
      );
      try {
        await interaction.respond(
          const <CommandOptionChoiceBuilder<dynamic>>[],
        );
      } catch (_) {}
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
    } catch (e, st) {
      _log.warning(
        'Safe respond failed for ${interaction.runtimeType}: $e',
        e,
        st,
      );
    }
  }

  Future<void> _safeErrorResponse(
    ApplicationCommandInteraction interaction, {
    required bool didDefer,
    required bool isEphemeral,
    String? errorMessage,
  }) async {
    final text =
        errorMessage ?? 'An error occurred while executing this command.';
    try {
      if (didDefer) {
        await interaction.updateOriginalResponse(
          MessageUpdateBuilder(content: text, embeds: const []),
        );
      } else {
        await interaction.respond(
          MessageBuilder(content: text, flags: MessageFlags.ephemeral),
        );
      }
    } catch (e, st) {
      _log.warning(
        'Safe error response failed for ${interaction.runtimeType} (didDefer=$didDefer): $e',
        e,
        st,
      );
    }
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
