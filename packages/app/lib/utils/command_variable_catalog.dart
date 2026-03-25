import 'package:bot_creator/types/variable_suggestion.dart';

class CommandVariableCatalogEntry {
  const CommandVariableCatalogEntry({
    required this.name,
    required this.description,
    required this.kind,
  });

  final String name;
  final String description;
  final VariableSuggestionKind kind;
}

const List<CommandVariableCatalogEntry> commandBuiltinVariableCatalog =
    <CommandVariableCatalogEntry>[
      CommandVariableCatalogEntry(
        name: 'guildName',
        description: 'Name of the guild.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'guildId',
        description: 'ID of the guild.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'channelName',
        description: 'Name of the current channel.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'channelId',
        description: 'ID of the current channel.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'userName',
        description: 'Display name of the user who invoked the command.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'userId',
        description: 'ID of the user who invoked the command.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'userTag',
        description: 'Discord tag or discriminator of the invoking user.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'userAvatar',
        description: 'Avatar URL of the invoking user.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'userBanner',
        description: 'Banner URL of the invoking user when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'author.username',
        description: 'Structured alias for the invoking author username.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'author.avatar',
        description: 'Structured alias for the invoking author avatar URL.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'author.banner',
        description: 'Structured alias for the invoking author banner URL.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'member.nick',
        description: 'Guild nickname of the invoking member when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'member.avatar',
        description: 'Guild member avatar URL when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'channel.name',
        description: 'Structured alias for channel name.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'channel.type',
        description: 'Structured alias for channel type.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'channel.topic',
        description: 'Channel topic when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'channel.parentId',
        description: 'Parent/category channel ID when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'channel.nsfw',
        description: 'Whether channel is marked NSFW.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'channel.slowmode',
        description: 'Slowmode rate limit in seconds when available.',
        kind: VariableSuggestionKind.numeric,
      ),
      CommandVariableCatalogEntry(
        name: 'guild.name',
        description: 'Structured alias for guild name.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'guild.count',
        description: 'Structured alias for approximate guild member count.',
        kind: VariableSuggestionKind.numeric,
      ),
      CommandVariableCatalogEntry(
        name: 'guild.ownerId',
        description: 'Guild owner ID when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'guild.description',
        description: 'Guild description when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'guild.features',
        description: 'Comma-separated list of enabled guild features.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'guild.features.count',
        description: 'Number of enabled guild features.',
        kind: VariableSuggestionKind.numeric,
      ),
      CommandVariableCatalogEntry(
        name: 'guildIcon',
        description: 'Guild icon URL when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'guildCount',
        description: 'Approximate member count of the guild.',
        kind: VariableSuggestionKind.numeric,
      ),
      CommandVariableCatalogEntry(
        name: 'commandName',
        description: 'Registered name of the executed command.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'commandId',
        description: 'Discord ID of the executed command.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'commandType',
        description: 'Normalized command type: chatInput, user, or message.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'commandTypeValue',
        description: 'Raw Discord numeric value of the command type.',
        kind: VariableSuggestionKind.numeric,
      ),
      CommandVariableCatalogEntry(
        name: 'command.type',
        description: 'Alias of commandType for portable conditions.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'interaction.command.type',
        description: 'Nested alias of the current Discord command type.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'interaction.command.route',
        description: 'Resolved subcommand route such as admin/ban.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'interaction.customId',
        description: 'Custom ID for component interactions.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'modal.customId',
        description: 'Custom ID for modal submit interactions.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'interaction.user.username',
        description: 'Structured alias for interaction author username.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'interaction.user.banner',
        description: 'Structured alias for interaction author banner URL.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'interaction.channel.name',
        description: 'Structured alias for interaction channel name.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'interaction.guild.name',
        description: 'Structured alias for interaction guild name.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'autocomplete.query',
        description: 'Focused autocomplete input currently typed by the user.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'autocomplete.optionName',
        description: 'Option name currently requesting dynamic autocomplete.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'autocomplete.optionType',
        description: 'Option type currently requesting autocomplete.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.id',
        description: 'Selected target ID for user or message commands.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.user.id',
        description: 'Target user ID for user commands.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.user.username',
        description: 'Username of the selected target user.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.user.tag',
        description:
            'Discord tag or discriminator of the selected target user.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.user.avatar',
        description: 'Avatar URL of the selected target user.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.user.banner',
        description: 'Banner URL of the selected target user when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.userName',
        description: 'Shortcut alias for the selected target user name.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.userAvatar',
        description: 'Shortcut alias for the selected target user avatar.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.member.id',
        description: 'Guild member ID of the selected target when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.member.nick',
        description: 'Guild nickname of the selected target when available.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.message.id',
        description: 'ID of the selected target message.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.message.channelId',
        description: 'Channel ID containing the selected target message.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.message.content',
        description: 'Content of the selected target message when resolved.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.message.author.id',
        description: 'Author ID of the selected target message when resolved.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.messageId',
        description: 'Shortcut alias for the selected target message ID.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'target.messageContent',
        description: 'Shortcut alias for the selected target message content.',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      CommandVariableCatalogEntry(
        name: 'opts',
        description:
            'Root container for slash-command options and resolved values.',
        kind: VariableSuggestionKind.unknown,
      ),
    ];

const List<String> commandTemplateReferenceVariables = <String>[
  'commandName',
  'commandId',
  'commandType',
  'commandTypeValue',
  'command.type',
  'interaction.command.type',
  'interaction.command.route',
  'interaction.customId',
  'modal.customId',
  'modal.<inputCustomId>',
  'opts.<option>',
  'opts.<option>.id',
  'opts.<option>.username',
  'opts.<option>.tag',
  'opts.<option>.avatar',
  'opts.<option>.banner',
  'autocomplete.query',
  'autocomplete.optionName',
  'autocomplete.optionType',
  'target.id',
  'target.user.id',
  'target.user.username',
  'target.user.avatar',
  'target.user.banner',
  'target.message.id',
  'target.message.content',
  'target.message.author.id',
  'global.<key>',
  'workflow.name',
  'workflow.entryPoint',
  'arg.<key>',
  'action.<key>',
];

const List<String> interactionCommandReferenceVariables = <String>[
  'commandType',
  'interaction.command.type',
  'interaction.command.route',
  'autocomplete.*',
  'opts.*',
  'target.user.*',
  'target.message.*',
];

List<String> get commandBuiltinVariableNames => commandBuiltinVariableCatalog
    .map((entry) => entry.name)
    .toList(growable: false);

List<String> get commandBuiltinVariableDocumentationLines =>
    commandBuiltinVariableCatalog
        .map((entry) => '${entry.name}: ${entry.description}')
        .toList(growable: false);

List<VariableSuggestion> get builtinCommandVariableSuggestions =>
    commandBuiltinVariableCatalog
        .map((entry) => VariableSuggestion(name: entry.name, kind: entry.kind))
        .toList(growable: false);
