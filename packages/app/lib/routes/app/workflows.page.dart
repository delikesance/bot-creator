import 'dart:convert';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/builder.response.dart';
import 'package:bot_creator/routes/app/workflow_docs.page.dart';
import 'package:bot_creator/types/app_emoji.dart';
import 'package:bot_creator/utils/app_emoji_api.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/workflow_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WorkflowsPage extends StatefulWidget {
  const WorkflowsPage({super.key, required this.botId});

  final String botId;

  @override
  State<WorkflowsPage> createState() => _WorkflowsPageState();
}

class _WorkflowsPageState extends State<WorkflowsPage> {
  List<Map<String, dynamic>> _workflows = <Map<String, dynamic>>[];
  bool _loading = true;
  List<AppEmoji> _appEmojis = [];

  String _toScopedReferenceName(String rawKey) {
    final key = rawKey.trim();
    if (key.isEmpty) {
      return key;
    }
    return key.startsWith('bc_') ? key : 'bc_$key';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final workflows = await appManager.getWorkflows(widget.botId);
    if (!mounted) {
      return;
    }

    // Load application emojis silently for autocomplete
    List<AppEmoji> emojis = [];
    try {
      final token = (await appManager.getApp(widget.botId))['token'] as String?;
      if (token != null && token.isNotEmpty) {
        emojis = await AppEmojiApi.listEmojis(token, widget.botId);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _workflows = workflows;
      _appEmojis = emojis;
      _loading = false;
    });
  }

  List<_WorkflowEventDefinition>
  get _workflowEventCatalog => const <_WorkflowEventDefinition>[
    _WorkflowEventDefinition(
      category: 'core',
      event: 'ready',
      label: 'Ready',
      description: 'Contains the initial state information.',
    ),
    _WorkflowEventDefinition(
      category: 'core',
      event: 'resumed',
      label: 'Resumed',
      description: 'Response to Resume.',
    ),
    _WorkflowEventDefinition(
      category: 'core',
      event: 'interactionCreate',
      label: 'Interaction Create',
      description: 'User used an interaction, such as an application command.',
    ),
    _WorkflowEventDefinition(
      category: 'commands',
      event: 'applicationCommandPermissionsUpdate',
      label: 'Application Command Permissions Update',
      description: 'Application command permission was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'automod',
      event: 'autoModerationRuleCreate',
      label: 'Auto Moderation Rule Create',
      description: 'Auto Moderation rule was created.',
    ),
    _WorkflowEventDefinition(
      category: 'automod',
      event: 'autoModerationRuleUpdate',
      label: 'Auto Moderation Rule Update',
      description: 'Auto Moderation rule was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'automod',
      event: 'autoModerationRuleDelete',
      label: 'Auto Moderation Rule Delete',
      description: 'Auto Moderation rule was deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'automod',
      event: 'autoModerationActionExecution',
      label: 'Auto Moderation Action Execution',
      description:
          'Auto Moderation rule was triggered and an action was executed.',
    ),
    _WorkflowEventDefinition(
      category: 'channels',
      event: 'channelCreate',
      label: 'Channel Create',
      description: 'New guild channel created.',
    ),
    _WorkflowEventDefinition(
      category: 'channels',
      event: 'channelUpdate',
      label: 'Channel Update',
      description: 'Channel was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'channels',
      event: 'channelDelete',
      label: 'Channel Delete',
      description: 'Channel was deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'channels',
      event: 'channelPinsUpdate',
      label: 'Channel Pins Update',
      description: 'Message was pinned or unpinned.',
    ),
    _WorkflowEventDefinition(
      category: 'threads',
      event: 'threadCreate',
      label: 'Thread Create',
      description:
          'Thread created, also sent when being added to a private thread.',
    ),
    _WorkflowEventDefinition(
      category: 'threads',
      event: 'threadUpdate',
      label: 'Thread Update',
      description: 'Thread was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'threads',
      event: 'threadDelete',
      label: 'Thread Delete',
      description: 'Thread was deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'threads',
      event: 'threadListSync',
      label: 'Thread List Sync',
      description:
          'Sent when gaining access to a channel, contains all active threads in that channel.',
    ),
    _WorkflowEventDefinition(
      category: 'threads',
      event: 'threadMemberUpdate',
      label: 'Thread Member Update',
      description: 'Thread member for the current user was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'threads',
      event: 'threadMembersUpdate',
      label: 'Thread Members Update',
      description: 'Some users were added to or removed from a thread.',
    ),
    _WorkflowEventDefinition(
      category: 'entitlements',
      event: 'entitlementCreate',
      label: 'Entitlement Create',
      description: 'Entitlement was created.',
    ),
    _WorkflowEventDefinition(
      category: 'entitlements',
      event: 'entitlementUpdate',
      label: 'Entitlement Update',
      description: 'Entitlement was updated or renewed.',
    ),
    _WorkflowEventDefinition(
      category: 'entitlements',
      event: 'entitlementDelete',
      label: 'Entitlement Delete',
      description: 'Entitlement was deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'guilds',
      event: 'guildCreate',
      label: 'Guild Create',
      description: 'Guild became available, or the bot joined a guild.',
    ),
    _WorkflowEventDefinition(
      category: 'guilds',
      event: 'guildUpdate',
      label: 'Guild Update',
      description: 'Guild was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'guilds',
      event: 'guildDelete',
      label: 'Guild Delete',
      description: 'Guild became unavailable, or the bot left a guild.',
    ),
    _WorkflowEventDefinition(
      category: 'guilds',
      event: 'guildAuditLogCreate',
      label: 'Guild Audit Log Entry Create',
      description: 'A guild audit log entry was created.',
    ),
    _WorkflowEventDefinition(
      category: 'guilds',
      event: 'guildEmojisUpdate',
      label: 'Guild Emojis Update',
      description: 'Guild emojis were updated.',
    ),
    _WorkflowEventDefinition(
      category: 'guilds',
      event: 'guildStickersUpdate',
      label: 'Guild Stickers Update',
      description: 'Guild stickers were updated.',
    ),
    _WorkflowEventDefinition(
      category: 'guilds',
      event: 'guildIntegrationsUpdate',
      label: 'Guild Integrations Update',
      description: 'Guild integration was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'guilds',
      event: 'guildMembersChunk',
      label: 'Guild Members Chunk',
      description: 'Response to Request Guild Members.',
    ),
    _WorkflowEventDefinition(
      category: 'members',
      event: 'guildBanAdd',
      label: 'Guild Ban Add',
      description: 'User was banned from a guild.',
    ),
    _WorkflowEventDefinition(
      category: 'members',
      event: 'guildBanRemove',
      label: 'Guild Ban Remove',
      description: 'User was unbanned from a guild.',
    ),
    _WorkflowEventDefinition(
      category: 'members',
      event: 'guildMemberAdd',
      label: 'Guild Member Add',
      description: 'New user joined a guild.',
    ),
    _WorkflowEventDefinition(
      category: 'members',
      event: 'guildMemberRemove',
      label: 'Guild Member Remove',
      description: 'User was removed from a guild.',
    ),
    _WorkflowEventDefinition(
      category: 'members',
      event: 'guildMemberUpdate',
      label: 'Guild Member Update',
      description: 'Guild member was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'roles',
      event: 'guildRoleCreate',
      label: 'Guild Role Create',
      description: 'Guild role was created.',
    ),
    _WorkflowEventDefinition(
      category: 'roles',
      event: 'guildRoleUpdate',
      label: 'Guild Role Update',
      description: 'Guild role was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'roles',
      event: 'guildRoleDelete',
      label: 'Guild Role Delete',
      description: 'Guild role was deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'scheduled',
      event: 'guildScheduledEventCreate',
      label: 'Guild Scheduled Event Create',
      description: 'Guild scheduled event was created.',
    ),
    _WorkflowEventDefinition(
      category: 'scheduled',
      event: 'guildScheduledEventUpdate',
      label: 'Guild Scheduled Event Update',
      description: 'Guild scheduled event was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'scheduled',
      event: 'guildScheduledEventDelete',
      label: 'Guild Scheduled Event Delete',
      description: 'Guild scheduled event was deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'scheduled',
      event: 'guildScheduledEventUserAdd',
      label: 'Guild Scheduled Event User Add',
      description: 'User subscribed to a guild scheduled event.',
    ),
    _WorkflowEventDefinition(
      category: 'scheduled',
      event: 'guildScheduledEventUserRemove',
      label: 'Guild Scheduled Event User Remove',
      description: 'User unsubscribed from a guild scheduled event.',
    ),
    _WorkflowEventDefinition(
      category: 'integrations',
      event: 'integrationCreate',
      label: 'Integration Create',
      description: 'Guild integration was created.',
    ),
    _WorkflowEventDefinition(
      category: 'integrations',
      event: 'integrationUpdate',
      label: 'Integration Update',
      description: 'Guild integration was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'integrations',
      event: 'integrationDelete',
      label: 'Integration Delete',
      description: 'Guild integration was deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'invites',
      event: 'inviteCreate',
      label: 'Invite Create',
      description: 'Invite to a channel was created.',
    ),
    _WorkflowEventDefinition(
      category: 'invites',
      event: 'inviteDelete',
      label: 'Invite Delete',
      description: 'Invite to a channel was deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'messages',
      event: 'messageCreate',
      label: 'Message Create',
      description: 'Message was created.',
    ),
    _WorkflowEventDefinition(
      category: 'messages',
      event: 'messageUpdate',
      label: 'Message Update',
      description: 'Message was edited.',
    ),
    _WorkflowEventDefinition(
      category: 'messages',
      event: 'messageDelete',
      label: 'Message Delete',
      description: 'Message was deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'messages',
      event: 'messageBulkDelete',
      label: 'Message Delete Bulk',
      description: 'Multiple messages were deleted at once.',
    ),
    _WorkflowEventDefinition(
      category: 'reactions',
      event: 'messageReactionAdd',
      label: 'Message Reaction Add',
      description: 'User reacted to a message.',
    ),
    _WorkflowEventDefinition(
      category: 'reactions',
      event: 'messageReactionRemove',
      label: 'Message Reaction Remove',
      description: 'User removed a reaction from a message.',
    ),
    _WorkflowEventDefinition(
      category: 'reactions',
      event: 'messageReactionRemoveAll',
      label: 'Message Reaction Remove All',
      description: 'All reactions were explicitly removed from a message.',
    ),
    _WorkflowEventDefinition(
      category: 'reactions',
      event: 'messageReactionRemoveEmoji',
      label: 'Message Reaction Remove Emoji',
      description:
          'All reactions for a given emoji were explicitly removed from a message.',
    ),
    _WorkflowEventDefinition(
      category: 'reactions',
      event: 'messagePollVoteAdd',
      label: 'Message Poll Vote Add',
      description: 'User voted on a poll.',
    ),
    _WorkflowEventDefinition(
      category: 'reactions',
      event: 'messagePollVoteRemove',
      label: 'Message Poll Vote Remove',
      description: 'User removed a vote on a poll.',
    ),
    _WorkflowEventDefinition(
      category: 'presence',
      event: 'presenceUpdate',
      label: 'Presence Update',
      description: 'User presence was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'presence',
      event: 'typingStart',
      label: 'Typing Start',
      description: 'User started typing in a channel.',
    ),
    _WorkflowEventDefinition(
      category: 'presence',
      event: 'userUpdate',
      label: 'User Update',
      description: 'Properties about the user changed.',
    ),
    _WorkflowEventDefinition(
      category: 'stages',
      event: 'stageInstanceCreate',
      label: 'Stage Instance Create',
      description: 'Stage instance was created.',
    ),
    _WorkflowEventDefinition(
      category: 'stages',
      event: 'stageInstanceUpdate',
      label: 'Stage Instance Update',
      description: 'Stage instance was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'stages',
      event: 'stageInstanceDelete',
      label: 'Stage Instance Delete',
      description: 'Stage instance was deleted or closed.',
    ),
    _WorkflowEventDefinition(
      category: 'voice',
      event: 'voiceStateUpdate',
      label: 'Voice State Update',
      description: 'Someone joined, left, or moved a voice channel.',
    ),
    _WorkflowEventDefinition(
      category: 'voice',
      event: 'voiceServerUpdate',
      label: 'Voice Server Update',
      description: 'Guild voice server was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'voice',
      event: 'voiceChannelEffectSend',
      label: 'Voice Channel Effect Send',
      description: 'Someone sent an effect in a connected voice channel.',
    ),
    _WorkflowEventDefinition(
      category: 'webhooks',
      event: 'webhooksUpdate',
      label: 'Webhooks Update',
      description: 'Guild channel webhook was created, updated, or deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'soundboard',
      event: 'soundboardSoundCreate',
      label: 'Guild Soundboard Sound Create',
      description: 'Guild soundboard sound was created.',
    ),
    _WorkflowEventDefinition(
      category: 'soundboard',
      event: 'soundboardSoundUpdate',
      label: 'Guild Soundboard Sound Update',
      description: 'Guild soundboard sound was updated.',
    ),
    _WorkflowEventDefinition(
      category: 'soundboard',
      event: 'soundboardSoundDelete',
      label: 'Guild Soundboard Sound Delete',
      description: 'Guild soundboard sound was deleted.',
    ),
    _WorkflowEventDefinition(
      category: 'soundboard',
      event: 'soundboardSoundsUpdate',
      label: 'Guild Soundboard Sounds Update',
      description: 'Guild soundboard sounds were updated.',
    ),
  ];

  List<String> get _workflowEventCategories {
    final categories = <String>[];
    for (final event in _workflowEventCatalog) {
      if (!categories.contains(event.category)) {
        categories.add(event.category);
      }
    }
    return categories;
  }

  List<_WorkflowEventDefinition> _eventsForCategory(String category) {
    return _workflowEventCatalog
        .where((event) => event.category == category)
        .toList(growable: false);
  }

  _WorkflowEventDefinition? _findEventDefinition(String eventName) {
    for (final event in _workflowEventCatalog) {
      if (event.event == eventName) {
        return event;
      }
    }
    return null;
  }

  String _eventCategoryLabel(String category) {
    switch (category) {
      case 'core':
        return 'Core';
      case 'commands':
        return 'Commands';
      case 'automod':
        return 'Auto Moderation';
      case 'channels':
        return 'Channels';
      case 'threads':
        return 'Threads';
      case 'entitlements':
        return 'Entitlements';
      case 'guilds':
        return 'Guilds';
      case 'members':
        return 'Members';
      case 'roles':
        return 'Roles';
      case 'scheduled':
        return 'Scheduled Events';
      case 'integrations':
        return 'Integrations';
      case 'invites':
        return 'Invites';
      case 'messages':
        return 'Messages';
      case 'reactions':
        return 'Reactions';
      case 'presence':
        return 'Presence';
      case 'stages':
        return 'Stage Instances';
      case 'voice':
        return 'Voice';
      case 'webhooks':
        return 'Webhooks';
      case 'soundboard':
        return 'Soundboard';
      default:
        return category;
    }
  }

  String _eventLabel(String eventName) {
    final definition = _findEventDefinition(eventName);
    if (definition == null) {
      return eventName;
    }
    return definition.label;
  }

  String _eventDescription(String eventName) {
    final definition = _findEventDefinition(eventName);
    if (definition == null) {
      return eventName;
    }
    return definition.description;
  }

  String _workflowTypeBadgeLabel(String workflowType) {
    return workflowType == workflowTypeEvent
        ? AppStrings.t('workflows_type_badge_event')
        : AppStrings.t('workflows_type_badge_general');
  }

  Future<List<VariableSuggestion>> _buildWorkflowVariableSuggestions({
    required String workflowType,
    required List<WorkflowArgumentDefinition> argumentDefinitions,
    required Map<String, dynamic> eventTrigger,
  }) async {
    final suggestions = <VariableSuggestion>[
      const VariableSuggestion(
        name: 'workflow.name',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      const VariableSuggestion(
        name: 'workflow.entryPoint',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      const VariableSuggestion(
        name: 'workflow.args',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      for (final arg in argumentDefinitions) ...[
        VariableSuggestion(
          name: 'arg.${arg.name}',
          kind: VariableSuggestionKind.unknown,
        ),
        VariableSuggestion(
          name: 'workflow.arg.${arg.name}',
          kind: VariableSuggestionKind.unknown,
        ),
      ],
    ];

    if (workflowType == workflowTypeEvent) {
      suggestions.addAll(const <VariableSuggestion>[
        VariableSuggestion(
          name: 'event.name',
          kind: VariableSuggestionKind.nonNumeric,
        ),
        VariableSuggestion(
          name: 'timestamp',
          kind: VariableSuggestionKind.numeric,
        ),
        VariableSuggestion(
          name: 'actualTime',
          kind: VariableSuggestionKind.nonNumeric,
        ),
        VariableSuggestion(
          name: 'guildId',
          kind: VariableSuggestionKind.numeric,
        ),
        VariableSuggestion(
          name: 'channelId',
          kind: VariableSuggestionKind.numeric,
        ),
        VariableSuggestion(
          name: 'userId',
          kind: VariableSuggestionKind.numeric,
        ),
      ]);

      final eventName = (eventTrigger['event'] ?? '').toString();
      if (eventName.startsWith('message') &&
          !eventName.startsWith('messageReaction') &&
          !eventName.startsWith('messagePoll') &&
          !eventName.startsWith('messageBulk')) {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'message.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'message.content',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'message.content[0]',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'message.content[1]',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'message.word.count',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'message.isBot',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'message.isSystem',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'message.mentions',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'message.mentions[0]',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'message.mention.count',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'author.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'author.name',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'author.isBot',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'author.avatar',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName.startsWith('guildMember')) {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'member.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'member.name',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'member.joinedAt',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName == 'channelUpdate') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'channel.name',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'channel.type',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName == 'inviteCreate') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'invite.code',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'invite.channelId',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'invite.inviterId',
            kind: VariableSuggestionKind.numeric,
          ),
        ]);
      } else if (eventName == 'presenceUpdate') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'presence.status',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'presence.activity.count',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'presence.activity[0].name',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'presence.activity[0].type',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'presence.activity[0].details',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'presence.activity[0].state',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'presence.activity[0].url',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'presence.client.desktop',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'presence.client.mobile',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'presence.client.web',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'user.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'user.name',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'user.username',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'user.tag',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'user.avatar',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName.startsWith('messageReaction')) {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'message.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'reaction.emoji.name',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'reaction.emoji.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'reaction.emoji.animated',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName.startsWith('messagePollVote')) {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'message.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'poll.answer.id',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'poll.question',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName == 'typingStart') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'typing.timestamp',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'typing.member.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'typing.member.name',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName == 'voiceStateUpdate') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'voice.channel.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'voice.user.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'voice.state.sessionId',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'voice.selfMute',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'voice.selfDeafen',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'voice.mute',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'voice.deafen',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName == 'voiceServerUpdate') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'voice.server.token',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'voice.server.endpoint',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName == 'voiceChannelEffectSend') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'voice.effect.emoji',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'voice.effect.soundId',
            kind: VariableSuggestionKind.numeric,
          ),
        ]);
      } else if (eventName == 'userUpdate') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'user.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'user.username',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'user.avatar',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'user.banner',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'user.accentColor',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName.startsWith('guildRole')) {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'role.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'role.name',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'role.color',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'role.permissions',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'role.position',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'role.mentionable',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'role.hoist',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName.startsWith('thread')) {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'thread.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'thread.name',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'thread.parent.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'thread.owner.id',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'thread.archived',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'thread.locked',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'thread.autoArchiveDuration',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName == 'channelPinsUpdate') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'channel.lastPinTimestamp',
            kind: VariableSuggestionKind.nonNumeric,
          ),
        ]);
      } else if (eventName == 'inviteDelete') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'invite.code',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'invite.channelId',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'invite.inviterId',
            kind: VariableSuggestionKind.numeric,
          ),
        ]);
      } else if (eventName == 'guildAuditLogCreate') {
        suggestions.addAll(const <VariableSuggestion>[
          VariableSuggestion(
            name: 'auditLog.action',
            kind: VariableSuggestionKind.nonNumeric,
          ),
          VariableSuggestion(
            name: 'auditLog.executorId',
            kind: VariableSuggestionKind.numeric,
          ),
          VariableSuggestion(
            name: 'auditLog.targetId',
            kind: VariableSuggestionKind.numeric,
          ),
        ]);
      }
    }

    try {
      final globals = await appManager.getGlobalVariables(widget.botId);
      for (final entry in globals.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) {
          continue;
        }
        suggestions.add(
          VariableSuggestion(
            name: 'global.$key',
            kind:
                entry.value is num
                    ? VariableSuggestionKind.numeric
                    : VariableSuggestionKind.unknown,
          ),
        );
      }

      final scopedDefinitions = await appManager.getScopedVariableDefinitions(
        widget.botId,
      );
      for (final definition in scopedDefinitions) {
        final scope = (definition['scope'] ?? '').toString().trim();
        final storageKey = (definition['key'] ?? '').toString().trim();
        if (scope.isEmpty || storageKey.isEmpty) {
          continue;
        }
        suggestions.add(
          VariableSuggestion(
            name: '$scope.${_toScopedReferenceName(storageKey)}',
            kind:
                definition['defaultValue'] is num
                    ? VariableSuggestionKind.numeric
                    : VariableSuggestionKind.unknown,
          ),
        );
      }
    } catch (_) {
      // Keep editor resilient when local persistence is temporarily unavailable.
    }

    final uniqueByName = <String, VariableSuggestion>{};
    for (final suggestion in suggestions) {
      uniqueByName[suggestion.name] = suggestion;
    }
    return uniqueByName.values.toList(growable: false);
  }

  List<String> _eventVariablePreview(String eventName) {
    final preview = <String>['event.name', 'timestamp', 'actualTime'];
    if (eventName.startsWith('message') &&
        !eventName.startsWith('messageReaction') &&
        !eventName.startsWith('messagePoll') &&
        !eventName.startsWith('messageBulk')) {
      preview.addAll(const <String>[
        'message.id',
        'message.content',
        'message.content[0]',
        'message.content[1]',
        'message.word.count',
        'message.isBot',
        'message.isSystem',
        'message.mentions',
        'message.mentions[0]',
        'message.mention.count',
        'author.id',
        'author.name',
        'author.isBot',
        'author.avatar',
        'channelId',
        'guildId',
      ]);
    } else if (eventName.startsWith('guildMember') ||
        eventName.startsWith('guildBan')) {
      preview.addAll(const <String>[
        'member.id',
        'member.name',
        'member.joinedAt',
        'guildId',
      ]);
    } else if (eventName.startsWith('channel') ||
        eventName.startsWith('thread')) {
      preview.addAll(const <String>[
        'channel.id',
        'channel.name',
        'channel.type',
        'guildId',
      ]);
    } else if (eventName.startsWith('invite')) {
      preview.addAll(const <String>[
        'invite.code',
        'invite.channelId',
        'invite.inviterId',
        'guildId',
      ]);
    } else if (eventName.startsWith('guild')) {
      preview.addAll(const <String>['guildId', 'guild.name']);
    } else if (eventName == 'presenceUpdate') {
      preview.addAll(const <String>[
        'user.id',
        'user.name',
        'user.username',
        'user.tag',
        'user.avatar',
        'presence.status',
        'presence.activity.count',
        'presence.activity[0].name',
        'presence.activity[0].type',
        'presence.activity[0].details',
        'presence.activity[0].state',
        'presence.activity[0].url',
        'presence.client.desktop',
        'presence.client.mobile',
        'presence.client.web',
        'guildId',
      ]);
    } else if (eventName.startsWith('voice')) {
      preview.addAll(const <String>[
        'guildId',
        'channelId',
        'userId',
        'voice.channel.id',
        'voice.user.id',
        'voice.state.sessionId',
        'voice.selfMute',
        'voice.selfDeafen',
        'voice.mute',
        'voice.deafen',
        'voice.server.endpoint',
        'voice.effect.emoji',
      ]);
    } else if (eventName.startsWith('messageReaction') ||
        eventName.startsWith('messagePoll') ||
        eventName.startsWith('messageBulk')) {
      preview.addAll(const <String>[
        'message.id',
        'channelId',
        'guildId',
        'userId',
        'reaction.emoji.name',
        'reaction.emoji.id',
        'poll.answer.id',
      ]);
    } else if (eventName.startsWith('guildRole')) {
      preview.addAll(const <String>[
        'role.id',
        'role.name',
        'role.color',
        'role.permissions',
        'role.position',
      ]);
    } else if (eventName.startsWith('thread')) {
      preview.addAll(const <String>[
        'thread.id',
        'thread.name',
        'thread.parent.id',
        'thread.owner.id',
        'thread.archived',
      ]);
    } else if (eventName == 'typingStart') {
      preview.addAll(const <String>[
        'typing.timestamp',
        'typing.member.id',
        'typing.member.name',
      ]);
    } else if (eventName == 'userUpdate') {
      preview.addAll(const <String>[
        'user.id',
        'user.username',
        'user.avatar',
        'user.banner',
        'user.accentColor',
      ]);
    } else if (eventName == 'channelPinsUpdate') {
      preview.addAll(const <String>['channel.lastPinTimestamp']);
    } else if (eventName == 'guildAuditLogCreate') {
      preview.addAll(const <String>[
        'auditLog.action',
        'auditLog.executorId',
        'auditLog.targetId',
      ]);
    }
    return preview;
  }

  Future<void> _createOrEditWorkflow({Map<String, dynamic>? initial}) async {
    final normalizedInitial =
        initial == null
            ? null
            : normalizeStoredWorkflowDefinition(
              Map<String, dynamic>.from(initial),
            );
    final nameController = TextEditingController(
      text: (normalizedInitial?['name'] ?? '').toString(),
    );
    final entryPointController = TextEditingController(
      text: normalizeWorkflowEntryPoint(normalizedInitial?['entryPoint']),
    );
    var selectedWorkflowType = normalizeWorkflowType(
      normalizedInitial?['workflowType'],
    );
    var selectedEventTrigger = normalizeWorkflowEventTrigger(
      normalizedInitial?['eventTrigger'],
    );
    final editableArgs =
        parseWorkflowArgumentDefinitions(normalizedInitial?['arguments']).map((
          definition,
        ) {
          return _EditableWorkflowArgument(
            name: definition.name,
            required: definition.required,
            defaultValue: definition.defaultValue,
          );
        }).toList();
    if (editableArgs.isEmpty) {
      editableArgs.add(const _EditableWorkflowArgument(name: ''));
    }

    var selectedCategory =
        (selectedEventTrigger['category'] ?? 'messages').toString();
    var selectedEvent =
        (selectedEventTrigger['event'] ?? 'messageCreate').toString();

    void ensureEventSelection() {
      if (!_workflowEventCategories.contains(selectedCategory)) {
        selectedCategory = _workflowEventCategories.first;
      }
      final events = _eventsForCategory(selectedCategory);
      if (events.isEmpty) {
        return;
      }
      final hasSelectedEvent = events.any(
        (event) => event.event == selectedEvent,
      );
      if (!hasSelectedEvent) {
        selectedEvent = events.first.event;
      }
      selectedEventTrigger = <String, dynamic>{
        'category': selectedCategory,
        'event': selectedEvent,
      };
    }

    ensureEventSelection();

    final saveInfo = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  initial == null
                      ? AppStrings.t('workflows_create')
                      : AppStrings.t('workflows_edit'),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          AppStrings.t('workflows_type_title'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _WorkflowTypeCard(
                                title: AppStrings.t('workflows_type_general'),
                                description: AppStrings.t(
                                  'workflows_type_general_desc',
                                ),
                                icon: Icons.account_tree_outlined,
                                selected:
                                    selectedWorkflowType == workflowTypeGeneral,
                                onTap: () {
                                  setDialogState(() {
                                    selectedWorkflowType = workflowTypeGeneral;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _WorkflowTypeCard(
                                title: AppStrings.t('workflows_type_event'),
                                description: AppStrings.t(
                                  'workflows_type_event_desc',
                                ),
                                icon: Icons.notifications_active_outlined,
                                selected:
                                    selectedWorkflowType == workflowTypeEvent,
                                onTap: () {
                                  setDialogState(() {
                                    selectedWorkflowType = workflowTypeEvent;
                                    ensureEventSelection();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: AppStrings.t('workflows_name'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (selectedWorkflowType == workflowTypeGeneral) ...[
                          TextField(
                            controller: entryPointController,
                            decoration: InputDecoration(
                              labelText: AppStrings.t('workflows_entry_point'),
                              border: const OutlineInputBorder(),
                              helperText: AppStrings.t(
                                'workflows_entry_point_hint',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppStrings.t('workflows_arguments'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: AppStrings.t('workflows_add_arg'),
                                onPressed: () {
                                  setDialogState(() {
                                    editableArgs.add(
                                      const _EditableWorkflowArgument(name: ''),
                                    );
                                  });
                                },
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          ...editableArgs.asMap().entries.map((entry) {
                            final index = entry.key;
                            final value = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: TextFormField(
                                      initialValue: value.name,
                                      decoration: InputDecoration(
                                        labelText: AppStrings.t(
                                          'workflows_arg_name',
                                        ),
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (next) {
                                        editableArgs[index] =
                                            editableArgs[index].copyWith(
                                              name: next.trim(),
                                            );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 4,
                                    child: TextFormField(
                                      initialValue: value.defaultValue,
                                      decoration: InputDecoration(
                                        labelText: AppStrings.t(
                                          'workflows_arg_default',
                                        ),
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (next) {
                                        editableArgs[index] =
                                            editableArgs[index].copyWith(
                                              defaultValue: next,
                                            );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    children: [
                                      Checkbox(
                                        value: value.required,
                                        onChanged: (next) {
                                          editableArgs[index] =
                                              editableArgs[index].copyWith(
                                                required: next == true,
                                              );
                                          setDialogState(() {});
                                        },
                                      ),
                                      Text(
                                        AppStrings.t(
                                          'workflows_arg_required_short',
                                        ),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        editableArgs.removeAt(index);
                                        if (editableArgs.isEmpty) {
                                          editableArgs.add(
                                            const _EditableWorkflowArgument(
                                              name: '',
                                            ),
                                          );
                                        }
                                      });
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            );
                          }),
                          Text(
                            AppStrings.t('workflows_arg_hint'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: InputDecoration(
                              labelText: AppStrings.t(
                                'workflows_event_category',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            items: _workflowEventCategories
                                .map((category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(_eventCategoryLabel(category)),
                                  );
                                })
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() {
                                selectedCategory = value;
                                ensureEventSelection();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedEvent,
                            decoration: InputDecoration(
                              labelText: AppStrings.t('workflows_listen_for'),
                              border: const OutlineInputBorder(),
                              helperText: AppStrings.t('workflows_event_hint'),
                            ),
                            items: _eventsForCategory(selectedCategory)
                                .map((event) {
                                  return DropdownMenuItem<String>(
                                    value: event.event,
                                    child: Text(event.label),
                                  );
                                })
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() {
                                selectedEvent = value;
                                ensureEventSelection();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.tr(
                                    'workflows_event_preview',
                                    params: {
                                      'event': _eventLabel(selectedEvent),
                                    },
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(_eventDescription(selectedEvent)),
                                const SizedBox(height: 10),
                                Text(
                                  AppStrings.t(
                                    'workflows_event_available_vars',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _eventVariablePreview(
                                    selectedEvent,
                                  ).join(', '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(AppStrings.t('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(AppStrings.t('workflows_continue')),
                  ),
                ],
              );
            },
          ),
    );

    if (saveInfo != true) {
      return;
    }

    final name = nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    final entryPoint = normalizeWorkflowEntryPoint(entryPointController.text);
    final argumentDefinitions = editableArgs
        .where((item) => item.name.trim().isNotEmpty)
        .map(
          (item) => WorkflowArgumentDefinition(
            name: item.name.trim(),
            required: item.required,
            defaultValue: item.defaultValue,
          ),
        )
        .toList(growable: false);
    final workflowVariableSuggestions = await _buildWorkflowVariableSuggestions(
      workflowType: selectedWorkflowType,
      argumentDefinitions: argumentDefinitions,
      eventTrigger: selectedEventTrigger,
    );

    final initialActions = List<Map<String, dynamic>>.from(
      (initial?['actions'] as List?)?.whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ) ??
          const <Map<String, dynamic>>[],
    );

    final nextActions = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder:
            (context) => ActionsBuilderPage(
              initialActions: initialActions,
              botIdForConfig: widget.botId,
              variableSuggestions: workflowVariableSuggestions,
              emojiSuggestions: _appEmojis,
            ),
      ),
    );

    if (nextActions == null) {
      return;
    }

    await appManager.saveWorkflow(
      widget.botId,
      name: name,
      actions: nextActions,
      entryPoint: entryPoint,
      arguments: serializeWorkflowArgumentDefinitions(argumentDefinitions),
      workflowType: selectedWorkflowType,
      eventTrigger:
          selectedWorkflowType == workflowTypeEvent
              ? selectedEventTrigger
              : null,
    );
    await _load();
  }

  Future<void> _deleteWorkflow(String name) async {
    await appManager.deleteWorkflow(widget.botId, name);
    await _load();
  }

  Map<String, dynamic> _buildWorkflowSharePayload() {
    final normalized = _workflows
        .map((workflow) {
          return normalizeStoredWorkflowDefinition(
            Map<String, dynamic>.from(workflow),
          );
        })
        .toList(growable: false);
    return <String, dynamic>{
      'version': 1,
      'type': 'bot_creator_workflows',
      'workflows': normalized,
    };
  }

  Future<void> _copyWorkflowPayload({required bool asBase64}) async {
    if (_workflows.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('workflows_copy_none'))),
      );
      return;
    }

    final payload = _buildWorkflowSharePayload();
    final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
    final text = asBase64 ? base64Encode(utf8.encode(jsonText)) : jsonText;
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          asBase64
              ? AppStrings.t('workflows_copy_done_base64')
              : AppStrings.t('workflows_copy_done_json'),
        ),
      ),
    );
  }

  Future<void> _showWorkflowExportOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.data_object_outlined),
                title: Text(AppStrings.t('workflows_export_json')),
                subtitle: Text(AppStrings.t('workflows_export_json_desc')),
                onTap: () async {
                  Navigator.pop(context);
                  await _copyWorkflowPayload(asBase64: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: Text(AppStrings.t('workflows_export_base64')),
                subtitle: Text(AppStrings.t('workflows_export_base64_desc')),
                onTap: () async {
                  Navigator.pop(context);
                  await _copyWorkflowPayload(asBase64: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importWorkflows() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final initialText = (clipboard?.text ?? '').trim();
    final controller = TextEditingController(text: initialText);
    var overwrite = true;

    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(AppStrings.t('workflows_import_title')),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(AppStrings.t('workflows_import_desc')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      minLines: 6,
                      maxLines: 12,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: AppStrings.t('workflows_import_input_hint'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppStrings.t('workflows_import_overwrite')),
                      value: overwrite,
                      onChanged: (value) {
                        setDialogState(() {
                          overwrite = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(AppStrings.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(AppStrings.t('workflows_import_action')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldImport != true) {
      return;
    }

    final rawInput = controller.text.trim();
    if (rawInput.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('workflows_import_empty'))),
      );
      return;
    }

    dynamic decoded;
    try {
      if (rawInput.startsWith('{') || rawInput.startsWith('[')) {
        decoded = jsonDecode(rawInput);
      } else {
        final jsonText = utf8.decode(base64Decode(rawInput));
        decoded = jsonDecode(jsonText);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.t('workflows_import_invalid_format')),
        ),
      );
      return;
    }

    List<Map<String, dynamic>> imported = <Map<String, dynamic>>[];
    if (decoded is Map && decoded['workflows'] is List) {
      imported = (decoded['workflows'] as List)
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    } else if (decoded is List) {
      imported = decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    } else if (decoded is Map) {
      imported = <Map<String, dynamic>>[Map<String, dynamic>.from(decoded)];
    }

    if (imported.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('workflows_import_no_valid'))),
      );
      return;
    }

    String uniqueName(String base, Set<String> used) {
      var candidate = base;
      var index = 2;
      while (used.contains(candidate)) {
        candidate = '$base ($index)';
        index++;
      }
      used.add(candidate);
      return candidate;
    }

    final usedNames =
        _workflows
            .map((workflow) => (workflow['name'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet();

    var importedCount = 0;
    for (final raw in imported) {
      final workflow = normalizeStoredWorkflowDefinition(raw);
      final rawName = (workflow['name'] ?? '').toString().trim();
      if (rawName.isEmpty) {
        continue;
      }

      final workflowType = normalizeWorkflowType(workflow['workflowType']);
      final targetName =
          overwrite
              ? rawName
              : uniqueName(rawName, Set<String>.from(usedNames));
      usedNames.add(targetName);

      final actions = List<Map<String, dynamic>>.from(
        (workflow['actions'] as List?)?.whereType<Map>().map(
              (entry) => Map<String, dynamic>.from(entry),
            ) ??
            const <Map<String, dynamic>>[],
      );

      await appManager.saveWorkflow(
        widget.botId,
        name: targetName,
        actions: actions,
        entryPoint: normalizeWorkflowEntryPoint(workflow['entryPoint']),
        arguments: serializeWorkflowArgumentDefinitions(
          parseWorkflowArgumentDefinitions(workflow['arguments']),
        ),
        workflowType: workflowType,
        eventTrigger:
            workflowType == workflowTypeEvent
                ? normalizeWorkflowEventTrigger(workflow['eventTrigger'])
                : null,
      );
      importedCount++;
    }

    await _load();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.tr(
            'workflows_import_done',
            params: {'count': importedCount.toString()},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generalWorkflows = _workflows
        .where(
          (workflow) =>
              normalizeWorkflowType(workflow['workflowType']) ==
              workflowTypeGeneral,
        )
        .toList(growable: false);
    final eventWorkflows = _workflows
        .where(
          (workflow) =>
              normalizeWorkflowType(workflow['workflowType']) ==
              workflowTypeEvent,
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('workflows_title')),
        actions: [
          IconButton(
            tooltip: AppStrings.t('workflows_import_tooltip'),
            onPressed: _importWorkflows,
            icon: const Icon(Icons.content_paste_go_outlined),
          ),
          IconButton(
            tooltip: AppStrings.t('workflows_export_tooltip'),
            onPressed: _showWorkflowExportOptions,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: AppStrings.t('workflows_docs_tooltip'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkflowDocumentationPage(),
                ),
              );
            },
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createOrEditWorkflow(),
        child: const Icon(Icons.add),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _workflows.isEmpty
              ? Center(child: Text(AppStrings.t('workflows_empty')))
              : ListView(
                children: [
                  if (generalWorkflows.isNotEmpty) ...[
                    _WorkflowSectionHeader(
                      title: AppStrings.t('workflows_general_section'),
                    ),
                    ...generalWorkflows.map(_buildWorkflowTile),
                  ],
                  if (eventWorkflows.isNotEmpty) ...[
                    _WorkflowSectionHeader(
                      title: AppStrings.t('workflows_event_section'),
                    ),
                    ...eventWorkflows.map(_buildWorkflowTile),
                  ],
                ],
              ),
    );
  }

  Widget _buildWorkflowTile(Map<String, dynamic> workflow) {
    final name = (workflow['name'] ?? '').toString();
    final actions =
        (workflow['actions'] is List)
            ? (workflow['actions'] as List).length
            : 0;
    final workflowType = normalizeWorkflowType(workflow['workflowType']);
    final entryPoint = normalizeWorkflowEntryPoint(workflow['entryPoint']);
    final argsCount =
        parseWorkflowArgumentDefinitions(workflow['arguments']).length;
    final eventTrigger = normalizeWorkflowEventTrigger(
      workflow['eventTrigger'],
    );
    final subtitle =
        workflowType == workflowTypeEvent
            ? AppStrings.tr(
              'workflows_event_subtitle',
              params: {
                'count': actions.toString(),
                'event': _eventLabel((eventTrigger['event'] ?? '').toString()),
              },
            )
            : AppStrings.tr(
              'workflows_subtitle',
              params: {
                'count': actions.toString(),
                'entry': entryPoint,
                'args': argsCount.toString(),
              },
            );

    return Column(
      children: [
        ListTile(
          leading: Icon(
            workflowType == workflowTypeEvent
                ? Icons.notifications_active_outlined
                : Icons.account_tree_outlined,
          ),
          title: Row(
            children: [
              Expanded(child: Text(name)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Text(
                  _workflowTypeBadgeLabel(workflowType),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(subtitle),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                onPressed: () => _createOrEditWorkflow(initial: workflow),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: () => _deleteWorkflow(name),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _EditableWorkflowArgument {
  final String name;
  final bool required;
  final String defaultValue;

  const _EditableWorkflowArgument({
    required this.name,
    this.required = false,
    this.defaultValue = '',
  });

  _EditableWorkflowArgument copyWith({
    String? name,
    bool? required,
    String? defaultValue,
  }) {
    return _EditableWorkflowArgument(
      name: name ?? this.name,
      required: required ?? this.required,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }
}

class _WorkflowTypeCard extends StatelessWidget {
  const _WorkflowTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color:
              selected
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowSectionHeader extends StatelessWidget {
  const _WorkflowSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _WorkflowEventDefinition {
  const _WorkflowEventDefinition({
    required this.category,
    required this.event,
    required this.label,
    required this.description,
  });

  final String category;
  final String event;
  final String label;
  final String description;
}
