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
      case BotCreatorActionType.calculate:
        return 'Calculate';
      case BotCreatorActionType.getMessage:
        return 'Get Message';
      case BotCreatorActionType.unpinMessage:
        return 'Unpin Message';
      case BotCreatorActionType.createPoll:
        return 'Create Poll';
      case BotCreatorActionType.endPoll:
        return 'End Poll';
      case BotCreatorActionType.createInvite:
        return 'Create Invite';
      case BotCreatorActionType.deleteInvite:
        return 'Delete Invite';
      case BotCreatorActionType.getInvite:
        return 'Get Invite';
      case BotCreatorActionType.moveToVoiceChannel:
        return 'Move to Voice Channel';
      case BotCreatorActionType.disconnectFromVoice:
        return 'Disconnect from Voice';
      case BotCreatorActionType.serverMuteMember:
        return 'Server Mute Member';
      case BotCreatorActionType.serverDeafenMember:
        return 'Server Deafen Member';
      case BotCreatorActionType.createEmoji:
        return 'Create Emoji';
      case BotCreatorActionType.updateEmoji:
        return 'Update Emoji';
      case BotCreatorActionType.deleteEmoji:
        return 'Delete Emoji';
      case BotCreatorActionType.createAutoModRule:
        return 'Create AutoMod Rule';
      case BotCreatorActionType.deleteAutoModRule:
        return 'Delete AutoMod Rule';
      case BotCreatorActionType.listAutoModRules:
        return 'List AutoMod Rules';
      case BotCreatorActionType.getGuildOnboarding:
        return 'Get Guild Onboarding';
      case BotCreatorActionType.updateGuildOnboarding:
        return 'Update Guild Onboarding';
      case BotCreatorActionType.updateSelfUser:
        return 'Update Self User (Bot Profile)';
      case BotCreatorActionType.createThread:
        return 'Create Thread';
      case BotCreatorActionType.editChannelPermissions:
        return 'Edit Channel Permissions';
      case BotCreatorActionType.deleteChannelPermission:
        return 'Delete Channel Permission';
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
      case BotCreatorActionType.calculate:
        return Icons.calculate;
      case BotCreatorActionType.getMessage:
        return Icons.message;
      case BotCreatorActionType.unpinMessage:
        return Icons.push_pin_outlined;
      case BotCreatorActionType.createPoll:
        return Icons.poll;
      case BotCreatorActionType.endPoll:
        return Icons.stop_circle;
      case BotCreatorActionType.createInvite:
        return Icons.link;
      case BotCreatorActionType.deleteInvite:
        return Icons.link_off;
      case BotCreatorActionType.getInvite:
        return Icons.manage_search;
      case BotCreatorActionType.moveToVoiceChannel:
        return Icons.headset;
      case BotCreatorActionType.disconnectFromVoice:
        return Icons.headset_off;
      case BotCreatorActionType.serverMuteMember:
        return Icons.mic_off;
      case BotCreatorActionType.serverDeafenMember:
        return Icons.hearing_disabled;
      case BotCreatorActionType.createEmoji:
        return Icons.add_reaction;
      case BotCreatorActionType.updateEmoji:
        return Icons.edit_notifications;
      case BotCreatorActionType.deleteEmoji:
        return Icons.no_photography;
      case BotCreatorActionType.createAutoModRule:
        return Icons.security;
      case BotCreatorActionType.deleteAutoModRule:
        return Icons.gpp_bad;
      case BotCreatorActionType.listAutoModRules:
        return Icons.verified_user;
      case BotCreatorActionType.getGuildOnboarding:
        return Icons.waving_hand;
      case BotCreatorActionType.updateGuildOnboarding:
        return Icons.manage_accounts;
      case BotCreatorActionType.updateSelfUser:
        return Icons.account_circle;
      case BotCreatorActionType.createThread:
        return Icons.forum;
      case BotCreatorActionType.editChannelPermissions:
        return Icons.lock_open;
      case BotCreatorActionType.deleteChannelPermission:
        return Icons.lock_reset;
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
            key: 'targetType',
            type: ParameterType.multiSelect,
            defaultValue: 'channel',
            hint: 'Send to a channel or directly to a user (DM)',
            options: ['channel', 'user'],
          ),
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint:
                'Target channel (required when targetType=channel; leave empty for current channel)',
          ),
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'User to DM (required when targetType=user)',
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
            key: 'tts',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Text-to-speech',
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
            type: ParameterType.multiSelect,
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
            type: ParameterType.multiSelect,
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
            type: ParameterType.multiSelect,
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
            type: ParameterType.multiSelect,
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
            type: ParameterType.multiSelect,
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
            type: ParameterType.multiSelect,
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

      // ─── Math & Calculation ─────────────────────────────────────────────
      case BotCreatorActionType.calculate:
        return [
          ParameterDefinition(
            key: 'operation',
            type: ParameterType.multiSelect,
            defaultValue: 'add',
            hint: 'Math operation to perform',
            options: [
              'add',
              'subtract',
              'multiply',
              'divide',
              'modulo',
              'power',
              'sqrt',
              'abs',
              'floor',
              'ceil',
              'round',
              'negate',
              'min',
              'max',
              'log',
              'random',
              'randomFloat',
            ],
            required: true,
          ),
          ParameterDefinition(
            key: 'operandA',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'First operand (supports ((variables)))',
            required: true,
          ),
          ParameterDefinition(
            key: 'operandB',
            type: ParameterType.string,
            defaultValue: '',
            hint:
                'Second operand (required for binary ops; for random = max; for log = base)',
          ),
        ];

      // ─── Message management ───────────────────────────────────────────────
      case BotCreatorActionType.getMessage:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel containing the message (optional: current channel)',
          ),
          ParameterDefinition(
            key: 'messageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint: 'Message ID to fetch',
            required: true,
          ),
        ];

      case BotCreatorActionType.unpinMessage:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel containing the message (optional: current channel)',
          ),
          ParameterDefinition(
            key: 'messageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint: 'Message to unpin',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      // ─── Polls ────────────────────────────────────────────────────────────
      case BotCreatorActionType.createPoll:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel to send the poll in (optional: current channel)',
          ),
          ParameterDefinition(
            key: 'question',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Poll question',
            required: true,
          ),
          ParameterDefinition(
            key: 'answers',
            type: ParameterType.list,
            defaultValue: <String>['Yes', 'No'],
            hint: 'Poll answers (max 10)',
            required: true,
          ),
          ParameterDefinition(
            key: 'durationHours',
            type: ParameterType.number,
            defaultValue: 24,
            hint: 'Poll duration in hours (1–168)',
            minValue: 1,
            maxValue: 168,
          ),
          ParameterDefinition(
            key: 'allowMultiselect',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Allow multiple answers to be selected',
          ),
        ];

      case BotCreatorActionType.endPoll:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel containing the poll (optional: current channel)',
          ),
          ParameterDefinition(
            key: 'messageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint: 'Message ID of the poll to end',
            required: true,
          ),
        ];

      // ─── Invitations ──────────────────────────────────────────────────────
      case BotCreatorActionType.createInvite:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel to create invite for',
            required: true,
          ),
          ParameterDefinition(
            key: 'maxAge',
            type: ParameterType.number,
            defaultValue: 86400,
            hint: 'Expiry in seconds (0 = never)',
            minValue: 0,
          ),
          ParameterDefinition(
            key: 'maxUses',
            type: ParameterType.number,
            defaultValue: 0,
            hint: 'Max uses (0 = unlimited)',
            minValue: 0,
          ),
          ParameterDefinition(
            key: 'temporary',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Kick member if they leave before getting a role',
          ),
          ParameterDefinition(
            key: 'unique',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Guarantee a unique invite code',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      case BotCreatorActionType.deleteInvite:
        return [
          ParameterDefinition(
            key: 'inviteCode',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Invite code to delete (e.g. abc123)',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      case BotCreatorActionType.getInvite:
        return [
          ParameterDefinition(
            key: 'inviteCode',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Invite code to look up (e.g. abc123)',
            required: true,
          ),
        ];

      // ─── Voice management ─────────────────────────────────────────────────
      case BotCreatorActionType.moveToVoiceChannel:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'Member to move',
            required: true,
          ),
          ParameterDefinition(
            key: 'targetChannelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Destination voice channel',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      case BotCreatorActionType.disconnectFromVoice:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'Member to disconnect from voice',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      case BotCreatorActionType.serverMuteMember:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'Member to server-mute or unmute',
            required: true,
          ),
          ParameterDefinition(
            key: 'mute',
            type: ParameterType.boolean,
            defaultValue: true,
            hint: 'true = mute, false = unmute',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      case BotCreatorActionType.serverDeafenMember:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'Member to server-deafen or undeafen',
            required: true,
          ),
          ParameterDefinition(
            key: 'deaf',
            type: ParameterType.boolean,
            defaultValue: true,
            hint: 'true = deafen, false = undeafen',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      // ─── Emoji management ─────────────────────────────────────────────────
      case BotCreatorActionType.createEmoji:
        return [
          ParameterDefinition(
            key: 'name',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Emoji name (alphanumeric + underscores)',
            required: true,
          ),
          ParameterDefinition(
            key: 'imageUrl',
            type: ParameterType.url,
            defaultValue: '',
            hint: 'URL of the image to use as emoji (PNG/JPEG/GIF, max 256KB)',
          ),
          ParameterDefinition(
            key: 'imageBase64',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Base64-encoded image data (alternative to imageUrl)',
          ),
          ParameterDefinition(
            key: 'roles',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Role IDs that can use this emoji (empty = everyone)',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      case BotCreatorActionType.updateEmoji:
        return [
          ParameterDefinition(
            key: 'emojiId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Emoji ID to update',
            required: true,
          ),
          ParameterDefinition(
            key: 'name',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New emoji name',
          ),
          ParameterDefinition(
            key: 'roles',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'New list of role IDs (empty = no change)',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      case BotCreatorActionType.deleteEmoji:
        return [
          ParameterDefinition(
            key: 'emojiId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Emoji ID to delete',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      // ─── AutoMod management ───────────────────────────────────────────────
      case BotCreatorActionType.createAutoModRule:
        return [
          ParameterDefinition(
            key: 'name',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Rule name',
            required: true,
          ),
          ParameterDefinition(
            key: 'triggerType',
            type: ParameterType.multiSelect,
            defaultValue: 'keyword',
            hint: 'What triggers the rule',
            options: ['keyword', 'spam', 'keywordPreset', 'mentionSpam'],
            required: true,
          ),
          ParameterDefinition(
            key: 'keywords',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Blocked keywords (for keyword trigger)',
          ),
          ParameterDefinition(
            key: 'regexPatterns',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Regex patterns to match (for keyword trigger)',
          ),
          ParameterDefinition(
            key: 'allowedWords',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Words exempt from filtering',
          ),
          ParameterDefinition(
            key: 'keywordPresets',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint:
                'Presets: profanity, sexualContent, slurs (for keywordPreset trigger)',
          ),
          ParameterDefinition(
            key: 'mentionTotalLimit',
            type: ParameterType.number,
            defaultValue: 5,
            hint: 'Max mentions per message (for mentionSpam trigger)',
            minValue: 1,
            maxValue: 50,
          ),
          ParameterDefinition(
            key: 'actionType',
            type: ParameterType.multiSelect,
            defaultValue: 'block_message',
            hint: 'Action to take when rule is triggered',
            options: ['block_message', 'send_alert_message', 'timeout'],
          ),
          ParameterDefinition(
            key: 'alertChannelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel for alert messages (for send_alert_message action)',
          ),
          ParameterDefinition(
            key: 'timeoutDuration',
            type: ParameterType.number,
            defaultValue: 60,
            hint: 'Timeout duration in seconds (for timeout action)',
            minValue: 1,
          ),
          ParameterDefinition(
            key: 'exemptRoles',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Role IDs exempt from this rule',
          ),
          ParameterDefinition(
            key: 'exemptChannels',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Channel IDs exempt from this rule',
          ),
          ParameterDefinition(
            key: 'enabled',
            type: ParameterType.boolean,
            defaultValue: true,
            hint: 'Enable the rule immediately',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      case BotCreatorActionType.deleteAutoModRule:
        return [
          ParameterDefinition(
            key: 'ruleId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'AutoMod rule ID to delete',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      case BotCreatorActionType.listAutoModRules:
        return [];

      // ─── Guild Onboarding ─────────────────────────────────────────────────
      case BotCreatorActionType.getGuildOnboarding:
        return [];

      case BotCreatorActionType.updateGuildOnboarding:
        return [
          ParameterDefinition(
            key: 'enabled',
            type: ParameterType.boolean,
            defaultValue: true,
            hint: 'Enable or disable guild onboarding',
          ),
        ];

      // ─── Self user ────────────────────────────────────────────────────────
      case BotCreatorActionType.updateSelfUser:
        return [
          ParameterDefinition(
            key: 'username',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New bot username (leave empty to keep current)',
          ),
          ParameterDefinition(
            key: 'avatarUrl',
            type: ParameterType.url,
            defaultValue: '',
            hint: 'URL of new avatar image (PNG/JPEG/GIF)',
          ),
          ParameterDefinition(
            key: 'avatarBase64',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Base64-encoded avatar image (alternative to avatarUrl)',
          ),
        ];

      // ─── Thread management ────────────────────────────────────────────────
      case BotCreatorActionType.createThread:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Parent channel (optional: current channel)',
          ),
          ParameterDefinition(
            key: 'name',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Thread name',
            required: true,
          ),
          ParameterDefinition(
            key: 'type',
            type: ParameterType.multiSelect,
            defaultValue: 'public',
            hint:
                'Thread type (ignored when creating from an existing message)',
            options: ['public', 'private'],
          ),
          ParameterDefinition(
            key: 'messageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint: 'Create thread on this message (optional)',
          ),
          ParameterDefinition(
            key: 'autoArchiveDuration',
            type: ParameterType.multiSelect,
            defaultValue: '1440',
            hint: 'Auto-archive after inactivity (minutes)',
            options: ['60', '1440', '4320', '10080'],
          ),
          ParameterDefinition(
            key: 'slowmode',
            type: ParameterType.number,
            defaultValue: 0,
            hint: 'Slowmode in seconds (0 = off)',
            minValue: 0,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      // ─── Channel permissions ──────────────────────────────────────────────
      case BotCreatorActionType.editChannelPermissions:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel to edit permissions for',
            required: true,
          ),
          ParameterDefinition(
            key: 'targetId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'User or Role ID to set overwrite for',
            required: true,
          ),
          ParameterDefinition(
            key: 'targetType',
            type: ParameterType.multiSelect,
            defaultValue: 'member',
            hint: 'Whether targetId is a member or role',
            options: ['member', 'role'],
            required: true,
          ),
          ParameterDefinition(
            key: 'allow',
            type: ParameterType.string,
            defaultValue: '0',
            hint: 'Permissions bitmask to allow (integer as string)',
          ),
          ParameterDefinition(
            key: 'deny',
            type: ParameterType.string,
            defaultValue: '0',
            hint: 'Permissions bitmask to deny (integer as string)',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
          ),
        ];

      case BotCreatorActionType.deleteChannelPermission:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel to delete permission overwrite from',
            required: true,
          ),
          ParameterDefinition(
            key: 'targetId',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'User or Role ID whose overwrite to delete',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Audit log reason',
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
