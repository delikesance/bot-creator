import 'dart:convert';

import 'package:nyxx/nyxx.dart';

final Expando<Map<String, dynamic>> _autocompleteConfigExpando =
    Expando<Map<String, dynamic>>('command_option_autocomplete_config');

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

bool commandOptionSupportsAutocomplete(CommandOptionType type) {
  return type == CommandOptionType.string ||
      type == CommandOptionType.integer ||
      type == CommandOptionType.number;
}

Map<String, dynamic>? normalizeCommandOptionAutocompleteConfig(dynamic raw) {
  if (raw is! Map) {
    return null;
  }

  final source = Map<String, dynamic>.from(
    raw.map((key, value) => MapEntry(key.toString(), value)),
  );
  final workflow = (source['workflow'] ?? '').toString().trim();
  final entryPoint = (source['entryPoint'] ?? 'main').toString().trim();
  final arguments = <String, dynamic>{};

  if (source['arguments'] is Map) {
    final rawArguments = Map<String, dynamic>.from(
      (source['arguments'] as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    for (final entry in rawArguments.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      arguments[key] = entry.value;
    }
  }

  final enabled =
      source['enabled'] == true ||
      (source['enabled'] == null &&
          (workflow.isNotEmpty || arguments.isNotEmpty));

  if (!enabled && workflow.isEmpty && arguments.isEmpty) {
    return null;
  }

  return <String, dynamic>{
    'enabled': enabled,
    'workflow': workflow,
    'entryPoint': entryPoint.isEmpty ? 'main' : entryPoint,
    'arguments': arguments,
  };
}

Map<String, dynamic>? getCommandOptionAutocompleteConfig(
  CommandOptionBuilder option,
) {
  final config = _autocompleteConfigExpando[option];
  if (config != null) {
    return cloneJsonMap(config);
  }
  if (option.hasAutocomplete == true) {
    return <String, dynamic>{
      'enabled': true,
      'workflow': '',
      'entryPoint': 'main',
      'arguments': <String, dynamic>{},
    };
  }
  return null;
}

bool isCommandOptionAutocompleteEnabled(CommandOptionBuilder option) {
  final config = getCommandOptionAutocompleteConfig(option);
  return config != null && config['enabled'] == true;
}

void setCommandOptionAutocompleteConfig(
  CommandOptionBuilder option,
  Map<String, dynamic>? rawConfig,
) {
  final normalized = normalizeCommandOptionAutocompleteConfig(rawConfig);
  _autocompleteConfigExpando[option] =
      normalized == null ? null : cloneJsonMap(normalized);
  option.hasAutocomplete = normalized?['enabled'] == true;
  if (option.hasAutocomplete == true) {
    option.choices = null;
  }
}

Map<String, dynamic> serializeCommandOption(CommandOptionBuilder option) {
  final autocomplete = getCommandOptionAutocompleteConfig(option);
  return <String, dynamic>{
    'type': commandOptionTypeToText(option.type),
    'name': option.name,
    'description': option.description,
    'required': option.isRequired,
    if (option.minValue != null) 'minValue': option.minValue,
    if (option.maxValue != null) 'maxValue': option.maxValue,
    if (autocomplete != null) 'autocomplete': autocomplete,
    if (autocomplete == null && option.choices?.isNotEmpty == true)
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

  final autocompleteConfig = normalizeCommandOptionAutocompleteConfig(
    raw['autocomplete'],
  );
  if (autocompleteConfig != null) {
    setCommandOptionAutocompleteConfig(option, autocompleteConfig);
  } else {
    option.hasAutocomplete = raw['hasAutocomplete'] == true;
  }

  final choicesRaw = raw['choices'];
  if (choicesRaw is List && option.hasAutocomplete != true) {
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
