import 'package:nyxx/nyxx.dart';

bool isHierarchyOptionType(CommandOptionType type) {
  return type == CommandOptionType.subCommand ||
      type == CommandOptionType.subCommandGroup;
}

bool isLeafOptionType(CommandOptionType type) {
  return !isHierarchyOptionType(type);
}

/// Validates a list of [CommandOptionBuilder] entries according to Discord's
/// slash-command hierarchy rules.
///
/// Call with [level] = 0 and [parentType] = null for the root option list.
/// Returns a human-readable error message string, or `null` if valid.
String? validateOptionsForLevel(
  List<CommandOptionBuilder> options, {
  required int level,
  required CommandOptionType? parentType,
}) {
  if (options.length > 25) {
    return 'Each option level supports at most 25 entries.';
  }

  if (level == 0) {
    final hasHierarchy = options.any(
      (option) => isHierarchyOptionType(option.type),
    );
    final hasLeaf = options.any((option) => isLeafOptionType(option.type));
    if (hasHierarchy && hasLeaf) {
      return 'Top-level options cannot mix subcommands/groups with regular options.';
    }
  }

  if (parentType == CommandOptionType.subCommandGroup &&
      options.any((option) => option.type != CommandOptionType.subCommand)) {
    return 'A SubCommandGroup can only contain SubCommand options.';
  }

  if (parentType == CommandOptionType.subCommand &&
      options.any((option) => isHierarchyOptionType(option.type))) {
    return 'A SubCommand cannot contain nested SubCommand or SubCommandGroup.';
  }

  final seenNames = <String>{};
  for (final option in options) {
    final optionName = option.name.trim();
    if (optionName.isEmpty) {
      return 'Every option must have a name.';
    }
    if (!seenNames.add(optionName)) {
      return 'Duplicate option name "$optionName" at the same level.';
    }
    if (option.description.trim().isEmpty) {
      return 'Every option must have a description.';
    }

    final nestedOptions = option.options ?? <CommandOptionBuilder>[];
    if (isLeafOptionType(option.type) && nestedOptions.isNotEmpty) {
      return 'Regular options cannot contain nested options.';
    }

    if (option.type == CommandOptionType.subCommand ||
        option.type == CommandOptionType.subCommandGroup) {
      if (option.isRequired == true) {
        return 'SubCommand and SubCommandGroup cannot be marked as required.';
      }
      if (option.choices?.isNotEmpty == true) {
        return 'SubCommand and SubCommandGroup cannot define choices.';
      }
      if (option.minValue != null || option.maxValue != null) {
        return 'SubCommand and SubCommandGroup cannot define min/max values.';
      }
    }

    if (option.type == CommandOptionType.subCommandGroup && level > 0) {
      return 'SubCommandGroup is only allowed at the top level.';
    }

    if (option.type == CommandOptionType.subCommand && level > 1) {
      return 'SubCommand nesting depth exceeds Discord limits.';
    }

    if (option.type == CommandOptionType.subCommandGroup) {
      final nestedError = validateOptionsForLevel(
        nestedOptions,
        level: level + 1,
        parentType: CommandOptionType.subCommandGroup,
      );
      if (nestedError != null) return nestedError;
    } else if (option.type == CommandOptionType.subCommand) {
      final nestedError = validateOptionsForLevel(
        nestedOptions,
        level: level + 1,
        parentType: CommandOptionType.subCommand,
      );
      if (nestedError != null) return nestedError;
    }
  }

  return null;
}
