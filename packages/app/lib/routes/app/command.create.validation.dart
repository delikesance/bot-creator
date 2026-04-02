part of 'command.create.dart';

extension _CommandCreateValidation on _CommandCreatePageState {
  String? _validateOptionsForLevel(
    List<CommandOptionBuilder> options, {
    required int level,
    required CommandOptionType? parentType,
  }) => validateOptionsForLevel(options, level: level, parentType: parentType);

  String? _validateName(String? value) {
    if (value!.isEmpty) {
      return 'Please enter a command name';
    }
    if (value.length > 32) {
      return 'Command name must be at most 32 characters long';
    }
    if (value.contains(' ')) {
      return 'Command name cannot contain spaces';
    }
    if (value.contains(RegExp(r'[^a-zA-Z0-9_]'))) {
      return 'Command name can only contain letters, numbers, and underscores';
    }
    if (value.startsWith('_')) {
      return 'Command name cannot start with an underscore';
    }
    if (value.startsWith('!')) {
      return 'Command name cannot start with an exclamation mark';
    }
    if (value.startsWith('/')) {
      return 'Command name cannot start with a slash';
    }
    if (value.startsWith('#')) {
      return 'Command name cannot start with a hash';
    }
    if (value.startsWith('@')) {
      return 'Command name cannot start with an at sign';
    }
    if (value.startsWith('&')) {
      return 'Command name cannot start with an ampersand';
    }
    if (value.startsWith('%')) {
      return 'Command name cannot start with a percent sign';
    }
    return null;
  }

  bool _validateCommandInputs() {
    final nameError = _validateName(_commandName);
    if (nameError != null) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(AppStrings.t('error')),
              content: Text(nameError),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppStrings.t('ok')),
                ),
              ],
            ),
      );
      return false;
    }

    if (_supportsCommandOptions) {
      final optionsError = _validateOptionsForLevel(
        _effectiveOptions,
        level: 0,
        parentType: null,
      );
      if (optionsError != null) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(AppStrings.t('error')),
                content: Text(optionsError),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppStrings.t('ok')),
                  ),
                ],
              ),
        );
        return false;
      }
    }

    if (_isBdfdScriptMode) {
      if (_bdfdScriptController.text.trim().isEmpty) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(AppStrings.t('error')),
                content: Text(AppStrings.t('cmd_bdfd_script_empty_error')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppStrings.t('ok')),
                  ),
                ],
              ),
        );
        return false;
      }
    }

    if (!_isBdfdScriptMode && _legacyModeEnabled) {
      if (_commandType != ApplicationCommandType.chatInput) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(AppStrings.t('error')),
                content: const Text(
                  'Legacy mode is only available for chat input commands.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppStrings.t('ok')),
                  ),
                ],
              ),
        );
        return false;
      }

      if (_responseType == 'modal') {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(AppStrings.t('error')),
                content: const Text(
                  'Modal responses are not supported in legacy command mode.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppStrings.t('ok')),
                  ),
                ],
              ),
        );
        return false;
      }
    }

    if (!_isBdfdScriptMode && _legacyOnlyLocalCommand) {
      if (!_legacyModeEnabled) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(AppStrings.t('error')),
                content: const Text(
                  'Legacy-only commands require legacy mode to be enabled.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppStrings.t('ok')),
                  ),
                ],
              ),
        );
        return false;
      }

      if (!_canToggleLegacyOnlyLocal) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(AppStrings.t('error')),
                content: const Text(
                  'Legacy-only mode can only be used for new commands or existing local commands.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppStrings.t('ok')),
                  ),
                ],
              ),
        );
        return false;
      }
    }

    return true;
  }

  Permissions? _parseDefaultMemberPermissions(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) {
      throw Exception(
        'Invalid default member permissions bitfield. Use a positive integer or leave empty.',
      );
    }
    return Permissions(parsed);
  }
}
