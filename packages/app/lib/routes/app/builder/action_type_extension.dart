import 'package:flutter/material.dart' show Icons, IconData;
import '../../../types/action.dart' show BotCreatorActionType;
import 'action_types.dart';

// Extension pour obtenir les détails des actions
extension BotCreatorActionTypeExtension on BotCreatorActionType {
  String get displayName {
    switch (this) {
      case BotCreatorActionType.deleteMessages:
        return 'Delete Messages';
      case BotCreatorActionType.createChannel:
        return 'Create Channel';
      case BotCreatorActionType.updateChannel:
        return 'Update Channel';
      case BotCreatorActionType.removeChannel:
        return 'Remove Channel';
      case BotCreatorActionType.sendMessage:
        return 'Send Message';
      case BotCreatorActionType.editMessage:
        return 'Edit Message';
      case BotCreatorActionType.addReaction:
        return 'Add Reaction';
      case BotCreatorActionType.removeReaction:
        return 'Remove Reaction';
      case BotCreatorActionType.clearAllReactions:
        return 'Clear All Reactions';
      case BotCreatorActionType.banUser:
        return 'Ban User';
      case BotCreatorActionType.unbanUser:
        return 'Unban User';
      case BotCreatorActionType.kickUser:
        return 'Kick User';
      case BotCreatorActionType.muteUser:
        return 'Mute User';
      case BotCreatorActionType.unmuteUser:
        return 'Unmute User';
      case BotCreatorActionType.addRole:
        return 'Add Role';
      case BotCreatorActionType.removeRole:
        return 'Remove Role';
      case BotCreatorActionType.pinMessage:
        return 'Pin Message';
      case BotCreatorActionType.updateAutoMod:
        return 'Update AutoMod';
      case BotCreatorActionType.updateGuild:
        return 'Update Guild';
      case BotCreatorActionType.listMembers:
        return 'List Members';
      case BotCreatorActionType.getMember:
        return 'Get Member';
      case BotCreatorActionType.sendComponentV2:
        return 'Send Component V2';
      case BotCreatorActionType.editComponentV2:
        return 'Edit Component V2';
      case BotCreatorActionType.sendWebhook:
        return 'Send Webhook';
      case BotCreatorActionType.editWebhook:
        return 'Edit Webhook';
      case BotCreatorActionType.deleteWebhook:
        return 'Delete Webhook';
      case BotCreatorActionType.listWebhooks:
        return 'List Webhooks';
      case BotCreatorActionType.getWebhook:
        return 'Get Webhook';
      case BotCreatorActionType.httpRequest:
        return 'HTTP Request';
      case BotCreatorActionType.setGlobalVariable:
        return 'Set Global Variable';
      case BotCreatorActionType.getGlobalVariable:
        return 'Get Global Variable';
      case BotCreatorActionType.removeGlobalVariable:
        return 'Remove Global Variable';
      case BotCreatorActionType.setScopedVariable:
        return 'Set Scoped Variable';
      case BotCreatorActionType.getScopedVariable:
        return 'Get Scoped Variable';
      case BotCreatorActionType.removeScopedVariable:
        return 'Remove Scoped Variable';
      case BotCreatorActionType.renameScopedVariable:
        return 'Rename Scoped Variable';
      case BotCreatorActionType.runWorkflow:
        return 'Run Workflow';
      case BotCreatorActionType.respondWithMessage:
        return 'Respond with Message';
      case BotCreatorActionType.respondWithComponentV2:
        return 'Respond with ComponentV2';
      case BotCreatorActionType.respondWithModal:
        return 'Respond with Modal';
      case BotCreatorActionType.editInteractionMessage:
        return 'Edit Interaction Message';
      case BotCreatorActionType.listenForButtonClick:
        return 'Listen for Button Click';
      case BotCreatorActionType.listenForModalSubmit:
        return 'Listen for Modal Submit';
      case BotCreatorActionType.stopUnless:
        return 'Stop Unless Condition';
      case BotCreatorActionType.ifBlock:
        return 'IF / ELSE Block';
    }
  }

  IconData get icon {
    switch (this) {
      case BotCreatorActionType.deleteMessages:
        return Icons.delete_sweep;
      case BotCreatorActionType.createChannel:
        return Icons.add_box;
      case BotCreatorActionType.updateChannel:
        return Icons.edit;
      case BotCreatorActionType.removeChannel:
        return Icons.remove_circle;
      case BotCreatorActionType.sendMessage:
        return Icons.send;
      case BotCreatorActionType.editMessage:
        return Icons.edit_note;
      case BotCreatorActionType.addReaction:
        return Icons.emoji_emotions;
      case BotCreatorActionType.removeReaction:
        return Icons.emoji_emotions_outlined;
      case BotCreatorActionType.clearAllReactions:
        return Icons.clear_all;
      case BotCreatorActionType.banUser:
        return Icons.block;
      case BotCreatorActionType.unbanUser:
        return Icons.person_add;
      case BotCreatorActionType.kickUser:
        return Icons.exit_to_app;
      case BotCreatorActionType.muteUser:
        return Icons.volume_off;
      case BotCreatorActionType.unmuteUser:
        return Icons.volume_up;
      case BotCreatorActionType.addRole:
        return Icons.person_add_alt_1;
      case BotCreatorActionType.removeRole:
        return Icons.person_remove_alt_1;
      case BotCreatorActionType.pinMessage:
        return Icons.push_pin;
      case BotCreatorActionType.updateAutoMod:
        return Icons.security;
      case BotCreatorActionType.updateGuild:
        return Icons.settings;
      case BotCreatorActionType.listMembers:
        return Icons.group;
      case BotCreatorActionType.getMember:
        return Icons.person;
      case BotCreatorActionType.sendComponentV2:
        return Icons.widgets;
      case BotCreatorActionType.editComponentV2:
        return Icons.build;
      case BotCreatorActionType.sendWebhook:
        return Icons.webhook;
      case BotCreatorActionType.editWebhook:
        return Icons.edit_attributes;
      case BotCreatorActionType.deleteWebhook:
        return Icons.delete_forever;
      case BotCreatorActionType.listWebhooks:
        return Icons.list;
      case BotCreatorActionType.getWebhook:
        return Icons.search;
      case BotCreatorActionType.httpRequest:
        return Icons.http;
      case BotCreatorActionType.setGlobalVariable:
        return Icons.save_as;
      case BotCreatorActionType.getGlobalVariable:
        return Icons.key;
      case BotCreatorActionType.removeGlobalVariable:
        return Icons.key_off;
      case BotCreatorActionType.setScopedVariable:
      case BotCreatorActionType.getScopedVariable:
      case BotCreatorActionType.removeScopedVariable:
      case BotCreatorActionType.renameScopedVariable:
        return Icons.inventory_2;
      case BotCreatorActionType.runWorkflow:
        return Icons.account_tree;
      case BotCreatorActionType.respondWithMessage:
        return Icons.chat;
      case BotCreatorActionType.respondWithComponentV2:
        return Icons.dashboard_customize;
      case BotCreatorActionType.respondWithModal:
        return Icons.input;
      case BotCreatorActionType.editInteractionMessage:
        return Icons.edit_notifications;
      case BotCreatorActionType.listenForButtonClick:
        return Icons.touch_app;
      case BotCreatorActionType.listenForModalSubmit:
        return Icons.dynamic_form;
      case BotCreatorActionType.stopUnless:
        return Icons.filter_alt;
      case BotCreatorActionType.ifBlock:
        return Icons.account_tree;
    }
  }

  static const _conditionOperators = [
    'equals',
    'notEquals',
    'contains',
    'notContains',
    'startsWith',
    'endsWith',
    'greaterThan',
    'lessThan',
    'greaterOrEqual',
    'lessOrEqual',
    'isEmpty',
    'isNotEmpty',
    'matches',
  ];

  // Nouvelle méthode pour obtenir les définitions de paramètres typés
  List<ParameterDefinition> get parameterDefinitions {
    switch (this) {
      case BotCreatorActionType.deleteMessages:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Optional: target channel (uses current channel if empty)',
          ),
          ParameterDefinition(
            key: 'messageCount',
            type: ParameterType.number,
            defaultValue: 10,
            hint: 'Number of messages to delete',
            minValue: 1,
            maxValue: 100,
          ),
          ParameterDefinition(
            key: 'onlyUserId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'Optional: only delete messages from this user',
          ),
          ParameterDefinition(
            key: 'beforeMessageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint:
                'Optional: delete messages posted before the given message ID',
          ),
          ParameterDefinition(
            key: 'deleteItself',
            type: ParameterType.boolean,
            defaultValue: false,
            hint:
                'If true and beforeMessageId is set, also delete that message',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Reason for deletion',
          ),
          ParameterDefinition(
            key: 'filterBots',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Only delete bot messages',
          ),
          ParameterDefinition(
            key: 'filterUsers',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Only delete user messages',
          ),
        ];
      case BotCreatorActionType.removeChannel:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel to remove',
            required: true,
          ),
        ];
      case BotCreatorActionType.createChannel:
        return [
          ParameterDefinition(
            key: 'name',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Channel name',
            required: true,
          ),
          ParameterDefinition(
            key: 'type',
            type: ParameterType.multiSelect,
            defaultValue: 'text',
            hint: 'Channel type',
            options: [
              'text',
              'voice',
              'announcement',
              'stage',
              'forum',
              'category',
            ],
          ),
          ParameterDefinition(
            key: 'categoryId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Parent category',
          ),
          ParameterDefinition(
            key: 'topic',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Channel topic/description',
          ),
          ParameterDefinition(
            key: 'nsfw',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Age-restricted channel',
          ),
          ParameterDefinition(
            key: 'slowmode',
            type: ParameterType.duration,
            defaultValue: '0s',
            hint: 'Slowmode duration',
          ),
        ];
      case BotCreatorActionType.updateChannel:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel to update',
            required: true,
          ),
          ParameterDefinition(
            key: 'name',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New channel name',
          ),
          ParameterDefinition(
            key: 'topic',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New channel topic/description',
          ),
          ParameterDefinition(
            key: 'nsfw',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Toggle NSFW status',
          ),
          ParameterDefinition(
            key: 'slowmode',
            type: ParameterType.duration,
            defaultValue: '0s',
            hint: 'New slowmode duration',
          ),
        ];
      case BotCreatorActionType.sendMessage:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Target channel (optional: current command channel if empty)',
          ),
          ParameterDefinition(
            key: 'content',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Message content',
            required: true,
          ),
          ParameterDefinition(
            key: 'mentions',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Users/roles to mention',
          ),
          ParameterDefinition(
            key: 'embeds',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Include embeds',
          ),
          ParameterDefinition(
            key: 'tts',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Text-to-speech',
          ),
          ParameterDefinition(
            key: 'ephemeral',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Only visible to user',
          ),
          ParameterDefinition(
            key: 'componentV2',
            type: ParameterType.componentV2,
            defaultValue: null,
            hint: 'Attach Component V2 interactive elements (optional)',
          ),
        ];
      case BotCreatorActionType.editMessage:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel containing message',
            required: true,
          ),
          ParameterDefinition(
            key: 'messageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint: 'Message to edit',
            required: true,
          ),
          ParameterDefinition(
            key: 'content',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New message content',
          ),
          ParameterDefinition(
            key: 'embeds',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Update embeds',
          ),
          ParameterDefinition(
            key: 'componentV2',
            type: ParameterType.componentV2,
            defaultValue: null,
            hint: 'Edit Component V2 interactive elements (optional)',
          ),
        ];
      case BotCreatorActionType.banUser:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'User to ban',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Ban reason',
          ),
          ParameterDefinition(
            key: 'deleteMessageDays',
            type: ParameterType.number,
            defaultValue: 1,
            hint: 'Days of messages to delete',
            minValue: 0,
            maxValue: 7,
          ),
        ];
      case BotCreatorActionType.unbanUser:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'User to unban',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Unban reason',
          ),
        ];
      case BotCreatorActionType.kickUser:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'User to kick',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Kick reason',
          ),
        ];
      case BotCreatorActionType.muteUser:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'User/Member to mute',
            required: true,
          ),
          ParameterDefinition(
            key: 'duration',
            type: ParameterType.duration,
            defaultValue: '10m',
            hint: 'Mute duration (e.g. 10m, 1h)',
          ),
          ParameterDefinition(
            key: 'until',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Or specify explicit until datetime ISO8601',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Mute reason',
          ),
        ];
      case BotCreatorActionType.unmuteUser:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'User/Member to unmute',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Unmute reason',
          ),
        ];
      case BotCreatorActionType.addRole:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'User/Member receiving the role',
            required: true,
          ),
          ParameterDefinition(
            key: 'roleId',
            type: ParameterType.roleId,
            defaultValue: '',
            hint: 'Role to add',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];
      case BotCreatorActionType.removeRole:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'User/Member losing the role',
            required: true,
          ),
          ParameterDefinition(
            key: 'roleId',
            type: ParameterType.roleId,
            defaultValue: '',
            hint: 'Role to remove',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];
      case BotCreatorActionType.addReaction:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint:
                'Optional: Channel containing message (uses current channel if empty)',
          ),
          ParameterDefinition(
            key: 'messageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint: 'Message to react to',
            required: true,
          ),
          ParameterDefinition(
            key: 'emoji',
            type: ParameterType.emoji,
            defaultValue: '',
            hint: 'Emoji to add (e.g. 🐶 or <:name:id>)',
            required: true,
          ),
        ];
      case BotCreatorActionType.removeReaction:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint:
                'Optional: Channel containing message (uses current channel if empty)',
          ),
          ParameterDefinition(
            key: 'messageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint: 'Message to remove reaction from',
            required: true,
          ),
          ParameterDefinition(
            key: 'emoji',
            type: ParameterType.emoji,
            defaultValue: '',
            hint: 'Emoji to remove (e.g. 🐶 or <:name:id>)',
            required: true,
          ),
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'Optional: Specific user whose reaction to remove',
          ),
          ParameterDefinition(
            key: 'removeOwn',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Remove bot\'s own reaction',
          ),
        ];
      case BotCreatorActionType.clearAllReactions:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint:
                'Optional: Channel containing message (uses current channel if empty)',
          ),
          ParameterDefinition(
            key: 'messageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint: 'Message to clear reactions from',
            required: true,
          ),
        ];
      case BotCreatorActionType.pinMessage:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint:
                'Optional: Channel containing message (uses current channel if empty)',
          ),
          ParameterDefinition(
            key: 'messageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint: 'Message to pin',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Pin reason',
          ),
        ];
      case BotCreatorActionType.updateGuild:
        return [
          ParameterDefinition(
            key: 'name',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New guild name',
          ),
          ParameterDefinition(
            key: 'description',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New guild description',
          ),
          ParameterDefinition(
            key: 'preferredLocale',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Preferred locale (e.g. en-US)',
          ),
          ParameterDefinition(
            key: 'afkChannelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'AFK voice channel',
          ),
          ParameterDefinition(
            key: 'afkTimeoutSeconds',
            type: ParameterType.number,
            defaultValue: 300,
            hint: 'AFK timeout in seconds',
          ),
          ParameterDefinition(
            key: 'systemChannelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'System messages channel',
          ),
          ParameterDefinition(
            key: 'rulesChannelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Rules channel',
          ),
          ParameterDefinition(
            key: 'publicUpdatesChannelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Public updates channel',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Update reason',
          ),
        ];
      case BotCreatorActionType.listMembers:
        return [
          ParameterDefinition(
            key: 'limit',
            type: ParameterType.number,
            defaultValue: 100,
            hint: 'Max members to return (1-1000)',
            minValue: 1,
            maxValue: 1000,
          ),
          ParameterDefinition(
            key: 'after',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'Fetch members after this ID',
          ),
          ParameterDefinition(
            key: 'query',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Search members by username/nickname',
          ),
        ];
      case BotCreatorActionType.getMember:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'User/Member to fetch',
            required: true,
          ),
        ];
      case BotCreatorActionType.sendComponentV2:
        return [
          ParameterDefinition(
            key: 'components',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Component definitions (Not implemented yet)',
          ),
        ];
      case BotCreatorActionType.editComponentV2:
        return [
          ParameterDefinition(
            key: 'components',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Component definitions (Not implemented yet)',
          ),
        ];
      case BotCreatorActionType.sendWebhook:
        return [
          ParameterDefinition(
            key: 'webhookUrl',
            type: ParameterType.url,
            defaultValue: '',
            hint: 'Full webhook URL (or provide ID + token separately)',
          ),
          ParameterDefinition(
            key: 'webhookId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Webhook ID',
          ),
          ParameterDefinition(
            key: 'token',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Webhook Token',
          ),
          ParameterDefinition(
            key: 'content',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Message content',
            required: true,
          ),
          ParameterDefinition(
            key: 'username',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Override webhook username',
          ),
          ParameterDefinition(
            key: 'avatarUrl',
            type: ParameterType.url,
            defaultValue: '',
            hint: 'Override webhook avatar URL',
          ),
          ParameterDefinition(
            key: 'threadId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Send in specific thread',
          ),
          ParameterDefinition(
            key: 'wait',
            type: ParameterType.boolean,
            defaultValue: true,
            hint: 'Wait for message creation to complete',
          ),
          ParameterDefinition(
            key: 'componentV2',
            type: ParameterType.componentV2,
            defaultValue: null,
            hint: 'Attach Component V2 interactive elements (optional)',
          ),
        ];
      case BotCreatorActionType.editWebhook:
        return [
          ParameterDefinition(
            key: 'webhookUrl',
            type: ParameterType.url,
            defaultValue: '',
            hint: 'Full webhook URL (or provide ID + token separately)',
          ),
          ParameterDefinition(
            key: 'webhookId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Webhook ID',
          ),
          ParameterDefinition(
            key: 'token',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Webhook Token',
          ),
          ParameterDefinition(
            key: 'name',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New webhook name',
          ),
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Move to new channel',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Edit reason',
          ),
        ];
      case BotCreatorActionType.deleteWebhook:
        return [
          ParameterDefinition(
            key: 'webhookUrl',
            type: ParameterType.url,
            defaultValue: '',
            hint: 'Full webhook URL (or provide ID + token separately)',
          ),
          ParameterDefinition(
            key: 'webhookId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Webhook ID',
          ),
          ParameterDefinition(
            key: 'token',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Webhook Token',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Delete reason',
          ),
        ];
      case BotCreatorActionType.listWebhooks:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Fetch webhooks in channel (fallback to current channel)',
          ),
          ParameterDefinition(
            key: 'guildId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Or fetch all webhooks in guild',
          ),
        ];
      case BotCreatorActionType.getWebhook:
        return [
          ParameterDefinition(
            key: 'webhookUrl',
            type: ParameterType.url,
            defaultValue: '',
            hint: 'Full webhook URL (or provide ID + token separately)',
          ),
          ParameterDefinition(
            key: 'webhookId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Webhook ID',
            required: true,
          ),
          ParameterDefinition(
            key: 'token',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Webhook Token (required to get webhook without auth)',
          ),
        ];
      case BotCreatorActionType.updateAutoMod:
        return [
          ParameterDefinition(
            key: 'enabled',
            type: ParameterType.boolean,
            defaultValue: true,
            hint: 'Enable auto-moderation',
          ),
          ParameterDefinition(
            key: 'filterWords',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Blocked words',
          ),
          ParameterDefinition(
            key: 'allowedRoles',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Roles exempt from filtering',
          ),
          ParameterDefinition(
            key: 'maxMentions',
            type: ParameterType.number,
            defaultValue: 5,
            hint: 'Maximum mentions per message',
            minValue: 1,
            maxValue: 50,
          ),
        ];
      case BotCreatorActionType.httpRequest:
        return [
          ParameterDefinition(
            key: 'url',
            type: ParameterType.url,
            defaultValue: '',
            hint: 'Request URL (supports placeholders ((...)))',
            required: true,
          ),
          ParameterDefinition(
            key: 'method',
            type: ParameterType.string,
            defaultValue: 'GET',
            hint: 'GET/POST/PUT/PATCH/DELETE/HEAD (placeholder allowed)',
          ),
          ParameterDefinition(
            key: 'bodyMode',
            type: ParameterType.multiSelect,
            defaultValue: 'json',
            hint: 'Body format',
            options: ['json', 'text'],
          ),
          ParameterDefinition(
            key: 'bodyJson',
            type: ParameterType.map,
            defaultValue: <String, dynamic>{},
            hint: 'JSON body builder map',
          ),
          ParameterDefinition(
            key: 'bodyText',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Raw text body',
          ),
          ParameterDefinition(
            key: 'headers',
            type: ParameterType.map,
            defaultValue: <String, dynamic>{},
            hint: 'Custom headers',
          ),
          ParameterDefinition(
            key: 'saveBodyToGlobalVar',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Optional global var key to store response body',
          ),
          ParameterDefinition(
            key: 'saveStatusToGlobalVar',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Optional global var key to store status code',
          ),
          ParameterDefinition(
            key: 'extractJsonPath',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'JSON path to extract (ex: \$.data.access_token)',
          ),
          ParameterDefinition(
            key: 'saveJsonPathToGlobalVar',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Optional global var key to store extracted value',
          ),
        ];
      case BotCreatorActionType.setGlobalVariable:
        return [
          ParameterDefinition(
            key: 'key',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Global variable key',
            required: true,
          ),
          ParameterDefinition(
            key: 'valueType',
            type: ParameterType.string,
            defaultValue: 'string',
            hint: 'Value type: string or number',
            options: ['string', 'number'],
          ),
          ParameterDefinition(
            key: 'value',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Value (supports placeholders ((...)))',
          ),
          ParameterDefinition(
            key: 'numberValue',
            type: ParameterType.number,
            defaultValue: 0,
            hint: 'Numeric value when valueType=number',
          ),
        ];
      case BotCreatorActionType.getGlobalVariable:
        return [
          ParameterDefinition(
            key: 'key',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Global variable key',
            required: true,
          ),
          ParameterDefinition(
            key: 'storeAs',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Runtime variable alias (ex: token)',
          ),
        ];
      case BotCreatorActionType.removeGlobalVariable:
        return [
          ParameterDefinition(
            key: 'key',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Global variable key',
            required: true,
          ),
        ];
      case BotCreatorActionType.setScopedVariable:
        return [
          ParameterDefinition(
            key: 'scope',
            type: ParameterType.string,
            defaultValue: 'guild',
            hint: 'Scope: guild, user, channel, guildMember, message',
            options: ['guild', 'user', 'channel', 'guildMember', 'message'],
            required: true,
          ),
          ParameterDefinition(
            key: 'key',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Scoped variable key (must start with bc_)',
            required: true,
          ),
          ParameterDefinition(
            key: 'valueType',
            type: ParameterType.string,
            defaultValue: 'string',
            hint: 'Value type: string or number',
            options: ['string', 'number'],
          ),
          ParameterDefinition(
            key: 'value',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'String value (supports placeholders ((...)))',
          ),
          ParameterDefinition(
            key: 'numberValue',
            type: ParameterType.number,
            defaultValue: 0,
            hint: 'Numeric value when valueType=number',
          ),
        ];
      case BotCreatorActionType.getScopedVariable:
        return [
          ParameterDefinition(
            key: 'scope',
            type: ParameterType.string,
            defaultValue: 'guild',
            hint: 'Scope: guild, user, channel, guildMember, message',
            options: ['guild', 'user', 'channel', 'guildMember', 'message'],
            required: true,
          ),
          ParameterDefinition(
            key: 'key',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Scoped variable key (must start with bc_)',
            required: true,
          ),
          ParameterDefinition(
            key: 'storeAs',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Runtime variable alias (ex: guild.bc_score)',
          ),
        ];
      case BotCreatorActionType.removeScopedVariable:
        return [
          ParameterDefinition(
            key: 'scope',
            type: ParameterType.string,
            defaultValue: 'guild',
            hint: 'Scope: guild, user, channel, guildMember, message',
            options: ['guild', 'user', 'channel', 'guildMember', 'message'],
            required: true,
          ),
          ParameterDefinition(
            key: 'key',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Scoped variable key (must start with bc_)',
            required: true,
          ),
        ];
      case BotCreatorActionType.renameScopedVariable:
        return [
          ParameterDefinition(
            key: 'scope',
            type: ParameterType.string,
            defaultValue: 'guild',
            hint: 'Scope: guild, user, channel, guildMember, message',
            options: ['guild', 'user', 'channel', 'guildMember', 'message'],
            required: true,
          ),
          ParameterDefinition(
            key: 'oldKey',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Current key (must start with bc_)',
            required: true,
          ),
          ParameterDefinition(
            key: 'newKey',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New key (must start with bc_)',
            required: true,
          ),
        ];
      case BotCreatorActionType.runWorkflow:
        return [
          ParameterDefinition(
            key: 'workflowName',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Saved workflow name to execute',
            required: true,
          ),
          ParameterDefinition(
            key: 'entryPoint',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Optional entry point override (defaults to workflow entry)',
          ),
          ParameterDefinition(
            key: 'arguments',
            type: ParameterType.map,
            defaultValue: <String, dynamic>{},
            hint: 'Optional key/value arguments injected as ((arg.key))',
          ),
        ];
      case BotCreatorActionType.respondWithMessage:
        return [
          ParameterDefinition(
            key: 'content',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Response text (supports placeholders ((...)))',
            required: false,
          ),
          ParameterDefinition(
            key: 'embeds',
            type: ParameterType.embeds,
            defaultValue: <Map<String, dynamic>>[],
            hint: 'Optional embeds (same format as normal command reply)',
          ),
          ParameterDefinition(
            key: 'components',
            type: ParameterType.normalComponents,
            defaultValue: <String, dynamic>{},
            hint: 'Optional message components (buttons/select menus only).',
          ),
          ParameterDefinition(
            key: 'ephemeral',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Only visible to command author',
          ),
        ];
      case BotCreatorActionType.respondWithComponentV2:
        return [
          ParameterDefinition(
            key: 'content',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Optional text above the components',
          ),
          ParameterDefinition(
            key: 'components',
            type: ParameterType.componentV2,
            defaultValue: <String, dynamic>{},
            hint: 'Component V2 layout builder',
          ),
          ParameterDefinition(
            key: 'ephemeral',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Only visible to command author',
          ),
        ];
      case BotCreatorActionType.respondWithModal:
        return [
          ParameterDefinition(
            key: 'modal',
            type: ParameterType.modalDefinition,
            defaultValue: <String, dynamic>{},
            hint: 'Modal dialog definition',
            required: true,
          ),
        ];
      case BotCreatorActionType.editInteractionMessage:
        return [
          ParameterDefinition(
            key: 'content',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New text content (leave empty to keep current)',
          ),
          ParameterDefinition(
            key: 'components',
            type: ParameterType.componentV2,
            defaultValue: <String, dynamic>{},
            hint: 'New component layout (leave empty to keep current)',
          ),
          ParameterDefinition(
            key: 'clearComponents',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Remove all components from the message',
          ),
        ];
      case BotCreatorActionType.listenForButtonClick:
        return [
          ParameterDefinition(
            key: 'customId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Button customId to listen for (supports ((variables)))',
            required: true,
          ),
          ParameterDefinition(
            key: 'workflowName',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Workflow to run when button is clicked',
            required: true,
          ),
          ParameterDefinition(
            key: 'entryPoint',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Optional entry point override',
          ),
          ParameterDefinition(
            key: 'arguments',
            type: ParameterType.map,
            defaultValue: <String, dynamic>{},
            hint: 'Optional key/value arguments for workflow call',
          ),
          ParameterDefinition(
            key: 'ttlMinutes',
            type: ParameterType.number,
            defaultValue: 60,
            hint: 'Listener TTL in minutes (max 60)',
            minValue: 1,
            maxValue: 60,
          ),
          ParameterDefinition(
            key: 'oneShot',
            type: ParameterType.boolean,
            defaultValue: true,
            hint: 'Remove listener after first click',
          ),
        ];
      case BotCreatorActionType.listenForModalSubmit:
        return [
          ParameterDefinition(
            key: 'customId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Modal customId to listen for',
            required: true,
          ),
          ParameterDefinition(
            key: 'workflowName',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Workflow to run when modal is submitted',
            required: true,
          ),
          ParameterDefinition(
            key: 'entryPoint',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Optional entry point override',
          ),
          ParameterDefinition(
            key: 'arguments',
            type: ParameterType.map,
            defaultValue: <String, dynamic>{},
            hint: 'Optional key/value arguments for workflow call',
          ),
          ParameterDefinition(
            key: 'ttlMinutes',
            type: ParameterType.number,
            defaultValue: 60,
            hint: 'Listener TTL in minutes (max 60)',
            minValue: 1,
            maxValue: 60,
          ),
        ];
      case BotCreatorActionType.stopUnless:
        return [
          ParameterDefinition(
            key: 'condition.variable',
            type: ParameterType.string,
            defaultValue: '',
            hint:
                'Value to test — use ((variableName)) to inject a variable. E.g. ((message.content[0]))',
            required: true,
          ),
          ParameterDefinition(
            key: 'condition.operator',
            type: ParameterType.multiSelect,
            defaultValue: 'equals',
            hint: 'Comparison operator',
            options: _conditionOperators,
          ),
          ParameterDefinition(
            key: 'condition.value',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Value to compare against (can use ((variables)))',
          ),
        ];
      case BotCreatorActionType.ifBlock:
        return [
          ParameterDefinition(
            key: 'condition.variable',
            type: ParameterType.string,
            defaultValue: '',
            hint:
                'Value to test — use ((variableName)). E.g. ((message.content[0]))',
            required: true,
          ),
          ParameterDefinition(
            key: 'condition.operator',
            type: ParameterType.multiSelect,
            defaultValue: 'equals',
            hint: 'Comparison operator',
            options: _conditionOperators,
          ),
          ParameterDefinition(
            key: 'condition.value',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Value to compare against (can use ((variables)))',
          ),
          ParameterDefinition(
            key: 'thenActions',
            type: ParameterType.nestedActions,
            defaultValue: <Map<String, dynamic>>[],
            hint: 'THEN — actions to run when condition is TRUE',
          ),
          ParameterDefinition(
            key: 'elseActions',
            type: ParameterType.nestedActions,
            defaultValue: <Map<String, dynamic>>[],
            hint: 'ELSE — actions to run when condition is FALSE',
          ),
        ];
    }
  }

  Map<String, dynamic> get defaultParameters {
    if (parameterDefinitions.isEmpty) {
      // Fallback behavior if no explicit parameter defs defined for this type yet
      return {};
    }

    // Générer les paramètres par défaut à partir des définitions
    final Map<String, dynamic> params = {};
    for (final def in parameterDefinitions) {
      params[def.key] = def.defaultValue;
    }
    return params;
  }
}
