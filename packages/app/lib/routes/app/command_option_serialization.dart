import 'dart:convert';

import 'package:nyxx/nyxx.dart';

String commandOptionTypeToText(CommandOptionType type) {
  if (type == CommandOptionType.subCommand) return 'subCommand';
  if (type == CommandOptionType.subCommandGroup) return 'subCommandGroup';
  if (type == CommandOptionType.string) return 'string';
  if (type == CommandOptionType.integer) return 'integer';
  if (type == CommandOptionType.boolean) return 'boolean';
  if (type == CommandOptionType.user) return 'user';
  if (type == CommandOptionType.channel) return 'channel';
  if (type == CommandOptionType.role) return 'role';
  if (type == CommandOptionType.mentionable) return 'mentionable';
  if (type == CommandOptionType.number) return 'number';
  if (type == CommandOptionType.attachment) return 'attachment';
  return 'string';
}

CommandOptionType commandOptionTypeFromText(String text) {
  final normalized = text.trim().toLowerCase();
  switch (normalized) {
    case 'subcommand':
      return CommandOptionType.subCommand;
    case 'subcommandgroup':
      return CommandOptionType.subCommandGroup;
    case 'integer':
      return CommandOptionType.integer;
    case 'boolean':
      return CommandOptionType.boolean;
    case 'user':
      return CommandOptionType.user;
    case 'channel':
      return CommandOptionType.channel;
    case 'role':
      return CommandOptionType.role;
    case 'mentionable':
      return CommandOptionType.mentionable;
    case 'number':
      return CommandOptionType.number;
    case 'attachment':
      return CommandOptionType.attachment;
    case 'string':
    default:
      return CommandOptionType.string;
  }
}

Map<String, dynamic> serializeCommandOption(CommandOptionBuilder option) {
  return <String, dynamic>{
    'type': commandOptionTypeToText(option.type),
    'name': option.name,
    'description': option.description,
    'required': option.isRequired,
    if (option.minValue != null) 'minValue': option.minValue,
    if (option.maxValue != null) 'maxValue': option.maxValue,
    if (option.choices?.isNotEmpty == true)
      'choices': option.choices!
          .map((choice) => {'name': choice.name, 'value': choice.value})
          .toList(growable: false),
    if (option.options?.isNotEmpty == true)
      'options': serializeCommandOptions(option.options!),
  };
}

List<Map<String, dynamic>> serializeCommandOptions(
  List<CommandOptionBuilder> options,
) {
  return options.map(serializeCommandOption).toList(growable: false);
}

CommandOptionBuilder deserializeCommandOption(Map<String, dynamic> raw) {
  final option = CommandOptionBuilder(
    type: commandOptionTypeFromText((raw['type'] ?? '').toString()),
    name: (raw['name'] ?? '').toString(),
    description: (raw['description'] ?? '').toString(),
    isRequired: raw['required'] == true,
    minValue: raw['minValue'] as num?,
    maxValue: raw['maxValue'] as num?,
  );

  final choicesRaw = raw['choices'];
  if (choicesRaw is List) {
    option.choices = choicesRaw
        .whereType<Map>()
        .map(
          (choice) => CommandOptionChoiceBuilder(
            name: (choice['name'] ?? '').toString(),
            value: choice['value'],
          ),
        )
        .toList(growable: false);
  }

  final nestedOptionsRaw = raw['options'];
  if (nestedOptionsRaw is List) {
    option.options = nestedOptionsRaw
        .whereType<Map>()
        .map(
          (entry) => deserializeCommandOption(Map<String, dynamic>.from(entry)),
        )
        .toList(growable: false);
  }

  return option;
}

List<CommandOptionBuilder> deserializeCommandOptions(List<dynamic> rawOptions) {
  return rawOptions
      .whereType<Map>()
      .map(
        (entry) => deserializeCommandOption(Map<String, dynamic>.from(entry)),
      )
      .toList(growable: false);
}

Map<String, dynamic> cloneJsonMap(Map<String, dynamic> source) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
}

Map<String, dynamic> cloneSubcommandWorkflowPayloads(
  Map<String, Map<String, dynamic>> payloads,
) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(payloads)) as Map);
}
