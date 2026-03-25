import 'package:bot_creator_shared/bot/bot_template.dart';

/// All built-in templates available in the template gallery.
const List<BotTemplate> builtInTemplates = [
  welcomeTemplate,
  moderationTemplate,
  utilityTemplate,
  funTemplate,
];

// ─────────────────────────────────────────────────────────────────────────────
// Welcome Bot
// ─────────────────────────────────────────────────────────────────────────────

const welcomeTemplate = BotTemplate(
  id: 'welcome',
  nameKey: 'template_welcome_name',
  descriptionKey: 'template_welcome_description',
  iconCodePoint: 0xe7f2, // Icons.waving_hand
  category: 'community',
  intents: {'guildMembers': true, 'messageContent': true},
  commands: [
    BotTemplateCommand(
      name: 'hello',
      description: 'Say hello to the bot',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'advanced',
        'simpleConfig': {},
        'defaultMemberPermissions': '',
        'response': {
          'mode': 'embed',
          'text': '',
          'type': 'normal',
          'embed': {
            'title': '👋 Hello {{user.username}}!',
            'description':
                'Welcome to **{{guild.name}}**! We are glad to have you here.',
            'color': 5793266,
          },
          'embeds': [
            {
              'title': '👋 Hello {{user.username}}!',
              'description':
                  'Welcome to **{{guild.name}}**! We are glad to have you here.',
              'color': 5793266,
            },
          ],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'public',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
    BotTemplateCommand(
      name: 'serverinfo',
      description: 'Display information about this server',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'advanced',
        'simpleConfig': {},
        'defaultMemberPermissions': '',
        'response': {
          'mode': 'embed',
          'text': '',
          'type': 'normal',
          'embed': {
            'title': '📊 {{guild.name}}',
            'description':
                '**Members:** {{guild.memberCount}}\n**Created:** {{guild.id}}',
            'color': 3447003,
          },
          'embeds': [
            {
              'title': '📊 {{guild.name}}',
              'description':
                  '**Members:** {{guild.memberCount}}\n**Created:** {{guild.id}}',
              'color': 3447003,
            },
          ],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'public',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
  ],
  workflows: [
    {
      'name': 'welcome_message',
      'workflowType': 'event',
      'entryPoint': 'main',
      'arguments': <Map<String, dynamic>>[],
      'eventTrigger': {'category': 'members', 'event': 'guildMemberAdd'},
      'actions': [
        {
          'type': 'sendMessage',
          'enabled': true,
          'payload': {
            'channelId': '{{guild.systemChannelId}}',
            'content':
                '🎉 Welcome to **{{guild.name}}**, {{event.user.mention}}! You are member #{{guild.memberCount}}.',
          },
        },
      ],
    },
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Moderation Bot
// ─────────────────────────────────────────────────────────────────────────────

const moderationTemplate = BotTemplate(
  id: 'moderation',
  nameKey: 'template_moderation_name',
  descriptionKey: 'template_moderation_description',
  iconCodePoint: 0xe8e8, // Icons.shield
  category: 'moderation',
  intents: {'guildMembers': true, 'messageContent': true},
  commands: [
    BotTemplateCommand(
      name: 'ban',
      description: 'Ban a member from the server',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'simple',
        'simpleConfig': {'banUser': true, 'actionReason': '{{option.reason}}'},
        'defaultMemberPermissions': '4',
        'options': [
          {
            'type': 'user',
            'name': 'target',
            'description': 'User to ban',
            'required': true,
          },
          {
            'type': 'string',
            'name': 'reason',
            'description': 'Reason for banning',
            'required': false,
          },
        ],
        'response': {
          'mode': 'text',
          'text': '🔨 {{option.target.username}} has been banned.',
          'type': 'normal',
          'embed': {'title': '', 'description': '', 'url': ''},
          'embeds': <Map<String, dynamic>>[],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'ephemeral',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
    BotTemplateCommand(
      name: 'kick',
      description: 'Kick a member from the server',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'simple',
        'simpleConfig': {'kickUser': true, 'actionReason': '{{option.reason}}'},
        'defaultMemberPermissions': '2',
        'options': [
          {
            'type': 'user',
            'name': 'target',
            'description': 'User to kick',
            'required': true,
          },
          {
            'type': 'string',
            'name': 'reason',
            'description': 'Reason for kick',
            'required': false,
          },
        ],
        'response': {
          'mode': 'text',
          'text': '👢 {{option.target.username}} has been kicked.',
          'type': 'normal',
          'embed': {'title': '', 'description': '', 'url': ''},
          'embeds': <Map<String, dynamic>>[],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'ephemeral',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
    BotTemplateCommand(
      name: 'mute',
      description: 'Timeout a member',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'simple',
        'simpleConfig': {
          'muteUser': true,
          'muteDuration': '600',
          'actionReason': '{{option.reason}}',
        },
        'defaultMemberPermissions': '1099511627776',
        'options': [
          {
            'type': 'user',
            'name': 'target',
            'description': 'User to mute',
            'required': true,
          },
          {
            'type': 'string',
            'name': 'reason',
            'description': 'Reason for mute',
            'required': false,
          },
        ],
        'response': {
          'mode': 'text',
          'text': '🔇 {{option.target.username}} has been muted.',
          'type': 'normal',
          'embed': {'title': '', 'description': '', 'url': ''},
          'embeds': <Map<String, dynamic>>[],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'ephemeral',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
    BotTemplateCommand(
      name: 'clear',
      description: 'Delete multiple messages at once',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'simple',
        'simpleConfig': {
          'deleteMessages': true,
          'deleteMessagesDefaultCount': '{{option.amount}}',
        },
        'defaultMemberPermissions': '8192',
        'options': [
          {
            'type': 'integer',
            'name': 'amount',
            'description': 'Number of messages to delete (1-100)',
            'required': true,
            'min_value': 1,
            'max_value': 100,
          },
        ],
        'response': {
          'mode': 'text',
          'text': '🗑️ Deleted {{option.amount}} message(s).',
          'type': 'normal',
          'embed': {'title': '', 'description': '', 'url': ''},
          'embeds': <Map<String, dynamic>>[],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'ephemeral',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Utility Bot
// ─────────────────────────────────────────────────────────────────────────────

const utilityTemplate = BotTemplate(
  id: 'utility',
  nameKey: 'template_utility_name',
  descriptionKey: 'template_utility_description',
  iconCodePoint: 0xe86c, // Icons.build
  category: 'utility',
  intents: {'messageContent': true},
  commands: [
    BotTemplateCommand(
      name: 'ping',
      description: 'Check if the bot is online',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'advanced',
        'simpleConfig': {},
        'defaultMemberPermissions': '',
        'response': {
          'mode': 'text',
          'text': '🏓 Pong!',
          'type': 'normal',
          'embed': {'title': '', 'description': '', 'url': ''},
          'embeds': <Map<String, dynamic>>[],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'public',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
    BotTemplateCommand(
      name: 'avatar',
      description: 'Display a user\'s avatar',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'advanced',
        'simpleConfig': {},
        'defaultMemberPermissions': '',
        'options': [
          {
            'type': 'user',
            'name': 'user',
            'description': 'User to show the avatar of',
            'required': false,
          },
        ],
        'response': {
          'mode': 'embed',
          'text': '',
          'type': 'normal',
          'embed': {
            'title': '🖼️ {{option.user.username ?? user.username}}\'s avatar',
            'image': '{{option.user.avatarUrl ?? user.avatarUrl}}',
            'color': 3447003,
          },
          'embeds': [
            {
              'title':
                  '🖼️ {{option.user.username ?? user.username}}\'s avatar',
              'image': '{{option.user.avatarUrl ?? user.avatarUrl}}',
              'color': 3447003,
            },
          ],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'public',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
    BotTemplateCommand(
      name: 'say',
      description: 'Make the bot send a message',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'advanced',
        'simpleConfig': {},
        'defaultMemberPermissions': '8',
        'options': [
          {
            'type': 'string',
            'name': 'message',
            'description': 'The message to send',
            'required': true,
          },
          {
            'type': 'channel',
            'name': 'channel',
            'description': 'Channel to send the message in',
            'required': false,
          },
        ],
        'response': {
          'mode': 'text',
          'text': '✅ Message sent!',
          'type': 'normal',
          'embed': {'title': '', 'description': '', 'url': ''},
          'embeds': <Map<String, dynamic>>[],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'ephemeral',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [
          {
            'type': 'sendMessage',
            'enabled': true,
            'payload': {
              'channelId': '{{option.channel.id ?? channel.id}}',
              'content': '{{option.message}}',
            },
          },
        ],
      },
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Fun Bot
// ─────────────────────────────────────────────────────────────────────────────

const funTemplate = BotTemplate(
  id: 'fun',
  nameKey: 'template_fun_name',
  descriptionKey: 'template_fun_description',
  iconCodePoint: 0xe7f3, // Icons.emoji_emotions
  category: 'fun',
  intents: {'messageContent': true},
  commands: [
    BotTemplateCommand(
      name: 'coinflip',
      description: 'Flip a coin — heads or tails',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'advanced',
        'simpleConfig': {},
        'defaultMemberPermissions': '',
        'response': {
          'mode': 'text',
          'text': '',
          'type': 'normal',
          'embed': {'title': '', 'description': '', 'url': ''},
          'embeds': <Map<String, dynamic>>[],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'public',
            'onError': 'edit_error',
            'conditional': {
              'enabled': true,
              'variable': '{{random.bool}}',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '🪙 **Heads!**',
              'whenFalseText': '🪙 **Tails!**',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
    BotTemplateCommand(
      name: 'poll',
      description: 'Create a quick poll',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'simple',
        'simpleConfig': {
          'createPoll': true,
          'pollDurationHours': '24',
          'pollAllowMultiselect': false,
        },
        'defaultMemberPermissions': '',
        'options': [
          {
            'type': 'string',
            'name': 'question',
            'description': 'The poll question',
            'required': true,
          },
        ],
        'response': {
          'mode': 'text',
          'text': '📊 Poll created!',
          'type': 'normal',
          'embed': {'title': '', 'description': '', 'url': ''},
          'embeds': <Map<String, dynamic>>[],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'public',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
    BotTemplateCommand(
      name: '8ball',
      description: 'Ask the magic 8-ball a question',
      data: {
        'version': 1,
        'commandType': 'chatInput',
        'editorMode': 'advanced',
        'simpleConfig': {},
        'defaultMemberPermissions': '',
        'options': [
          {
            'type': 'string',
            'name': 'question',
            'description': 'Your question',
            'required': true,
          },
        ],
        'response': {
          'mode': 'embed',
          'text': '',
          'type': 'normal',
          'embed': {
            'title': '🎱 Magic 8-Ball',
            'description':
                '**Q:** {{option.question}}\n**A:** {{random.choice:Yes!|No.|Maybe...|Ask again later.|Definitely!|I doubt it.|Without a doubt.|Better not tell you now.}}',
            'color': 1752220,
          },
          'embeds': [
            {
              'title': '🎱 Magic 8-Ball',
              'description':
                  '**Q:** {{option.question}}\n**A:** {{random.choice:Yes!|No.|Maybe...|Ask again later.|Definitely!|I doubt it.|Without a doubt.|Better not tell you now.}}',
              'color': 1752220,
            },
          ],
          'components': {},
          'modal': {},
          'workflow': {
            'autoDeferIfActions': true,
            'visibility': 'public',
            'onError': 'edit_error',
            'conditional': {
              'enabled': false,
              'variable': '',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '',
              'whenFalseText': '',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
              'whenTrueNormalComponents': {},
              'whenFalseNormalComponents': {},
              'whenTrueComponents': {},
              'whenFalseComponents': {},
              'whenTrueModal': {},
              'whenFalseModal': {},
            },
          },
        },
        'actions': [],
      },
    ),
  ],
);
