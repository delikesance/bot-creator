part of 'command.create.dart';

extension _CommandCreateVariableSuggestions on _CommandCreatePageState {
  Future<void> _refreshPersistedVariableNames() async {
    final botId = _botIdForConfig;
    if (botId == null || botId.trim().isEmpty) {
      return;
    }

    try {
      final globals = await appManager.getGlobalVariables(botId);
      _persistedGlobalVariableNames =
          globals.keys
              .map((key) => 'global.$key')
              .where((name) => name.trim().isNotEmpty)
              .toSet();

      final scopedDefinitions = await appManager.getScopedVariableDefinitions(
        botId,
      );
      final scopedNames = <String>{};
      for (final definition in scopedDefinitions) {
        final scope = (definition['scope'] ?? '').toString().trim();
        final storageKey = (definition['key'] ?? '').toString().trim();
        if (scope.isEmpty || storageKey.isEmpty) {
          continue;
        }
        scopedNames.add('$scope.${_toScopedReferenceName(storageKey)}');
      }
      _scopedVariableSuggestionNames =
          scopedNames.isEmpty
              ? <String>{
                'guild.key',
                'user.key',
                'channel.key',
                'guildMember.key',
                'message.key',
              }
              : scopedNames;
    } catch (_) {
      // Keep editor resilient if local persistence is temporarily unavailable.
      _persistedGlobalVariableNames = <String>{};
      _scopedVariableSuggestionNames = <String>{
        'guild.key',
        'user.key',
        'channel.key',
        'guildMember.key',
        'message.key',
      };
    }

    _applyStateUpdate(() {});
  }

  List<String> get _variableNames {
    final base = commandBuiltinVariableNames.toList(growable: true);

    for (final option in _effectiveOptions) {
      final optionName = option.name;
      if (optionName.isEmpty) {
        continue;
      }

      base.add('opts.$optionName');

      switch (option.type) {
        case CommandOptionType.user:
        case CommandOptionType.mentionable:
          base.addAll([
            'opts.$optionName.id',
            'opts.$optionName.username',
            'opts.$optionName.tag',
            'opts.$optionName.avatar',
            'opts.$optionName.banner',
          ]);
          break;
        case CommandOptionType.channel:
          base.addAll(['opts.$optionName.id', 'opts.$optionName.type']);
          break;
        case CommandOptionType.role:
          base.add('opts.$optionName.id');
          break;
        default:
          break;
      }
    }

    base.addAll(_actionOutputVariableNames());
    base.addAll(_persistedGlobalVariableNames);
    base.addAll(_scopedVariableSuggestionNames);

    return base.toSet().toList(growable: false)..sort();
  }

  String _resolveActionKey(Map<String, dynamic> action, int index) {
    final rootKey = (action['key'] ?? '').toString().trim();
    if (rootKey.isNotEmpty) {
      return rootKey;
    }

    final parameters = Map<String, dynamic>.from(
      (action['parameters'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final parametersKey = (parameters['key'] ?? '').toString().trim();
    if (parametersKey.isNotEmpty) {
      return parametersKey;
    }

    final payload = Map<String, dynamic>.from(
      (action['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final payloadKey = (payload['key'] ?? '').toString().trim();
    if (payloadKey.isNotEmpty) {
      return payloadKey;
    }

    return 'action_$index';
  }

  String _readActionStringParameter(Map<String, dynamic> action, String key) {
    final rootValue = (action[key] ?? '').toString().trim();
    if (rootValue.isNotEmpty) {
      return rootValue;
    }

    final parameters = Map<String, dynamic>.from(
      (action['parameters'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final parametersValue = (parameters[key] ?? '').toString().trim();
    if (parametersValue.isNotEmpty) {
      return parametersValue;
    }

    final payload = Map<String, dynamic>.from(
      (action['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return (payload[key] ?? '').toString().trim();
  }

  bool _looksLikeTemplateValue(String value) {
    return value.contains('((') || value.contains('))');
  }

  String _resolveActionStoreAlias(Map<String, dynamic> action) {
    final type = (action['type'] ?? '').toString().trim();
    final explicitStoreAs = _readActionStringParameter(action, 'storeAs');
    if (explicitStoreAs.isNotEmpty &&
        !_looksLikeTemplateValue(explicitStoreAs)) {
      return explicitStoreAs;
    }

    if (type == 'getGlobalVariable') {
      final key = _readActionStringParameter(action, 'key');
      if (key.isNotEmpty && !_looksLikeTemplateValue(key)) {
        return 'global.$key';
      }
    }

    if (type == 'getScopedVariable') {
      final scope = _readActionStringParameter(action, 'scope');
      final key = _readActionStringParameter(action, 'key');
      if (scope.isNotEmpty && key.isNotEmpty) {
        if (!_looksLikeTemplateValue(scope) && !_looksLikeTemplateValue(key)) {
          return '$scope.${_toScopedReferenceName(key)}';
        }
      }
    }

    return '';
  }

  List<Map<String, dynamic>> _flattenActionTree(
    List<Map<String, dynamic>> actions,
  ) {
    final flattened = <Map<String, dynamic>>[];

    void visit(List<Map<String, dynamic>> current) {
      for (final rawAction in current) {
        final action = Map<String, dynamic>.from(rawAction);
        flattened.add(action);

        final payload = Map<String, dynamic>.from(
          (action['payload'] as Map?)?.cast<String, dynamic>() ??
              (action['parameters'] as Map?)?.cast<String, dynamic>() ??
              const {},
        );

        for (final branchKey in const ['thenActions', 'elseActions']) {
          final nestedRaw = payload[branchKey];
          if (nestedRaw is! List) {
            continue;
          }

          final nested = nestedRaw
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList(growable: false);
          if (nested.isNotEmpty) {
            visit(nested);
          }
        }

        final elseIfRaw = payload['elseIfConditions'];
        if (elseIfRaw is List) {
          for (final entry in elseIfRaw.whereType<Map>()) {
            final elseIf = Map<String, dynamic>.from(entry);
            final nestedRaw = elseIf['actions'];
            if (nestedRaw is! List) {
              continue;
            }

            final nested = nestedRaw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false);
            if (nested.isNotEmpty) {
              visit(nested);
            }
          }
        }
      }
    }

    visit(actions);
    return flattened;
  }

  List<String> _actionOutputVariableNames() {
    final outputVariables = <String>{};

    final actions = _flattenActionTree(_effectiveActions);
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      final actionKey = _resolveActionKey(action, i);
      if (actionKey.isEmpty) {
        continue;
      }

      outputVariables.add('action.$actionKey');

      final type = (action['type'] ?? '').toString();
      if (type == 'deleteMessages') {
        outputVariables.addAll([
          'action.$actionKey.count',
          '$actionKey.count',
          'action.$actionKey.deleteItself',
          '$actionKey.deleteItself',
        ]);
      }

      if (type == 'httpRequest') {
        outputVariables.addAll([
          'action.$actionKey.status',
          'action.$actionKey.body',
          'action.$actionKey.jsonPath',
          '$actionKey.status',
          '$actionKey.body',
          '$actionKey.jsonPath',
        ]);
      }

      if (type == 'appendArrayElement') {
        outputVariables.addAll([
          'action.$actionKey.items',
          '$actionKey.items',
          'action.$actionKey.length',
          '$actionKey.length',
        ]);
      }

      if (type == 'removeArrayElement') {
        outputVariables.addAll([
          'action.$actionKey.items',
          '$actionKey.items',
          'action.$actionKey.length',
          '$actionKey.length',
          'action.$actionKey.removed',
          '$actionKey.removed',
        ]);
      }

      if (type == 'queryArray' || type == 'listScopedVariableIndex') {
        outputVariables.addAll([
          'action.$actionKey.items',
          '$actionKey.items',
          'action.$actionKey.count',
          '$actionKey.count',
          'action.$actionKey.total',
          '$actionKey.total',
        ]);
      }

      final storeAlias = _resolveActionStoreAlias(action);
      if (storeAlias.isNotEmpty) {
        outputVariables.add(storeAlias);
      }
    }

    return outputVariables.toList(growable: false)..sort();
  }

  List<VariableSuggestion> get _actionVariableSuggestions {
    final suggestionsByName = <String, VariableSuggestion>{};

    void addSuggestion(String name, {required VariableSuggestionKind kind}) {
      final existing = suggestionsByName[name];
      if (existing == null) {
        suggestionsByName[name] = VariableSuggestion(name: name, kind: kind);
        return;
      }

      if (existing.kind == VariableSuggestionKind.numeric ||
          existing.kind == kind) {
        return;
      }

      if (kind == VariableSuggestionKind.numeric) {
        suggestionsByName[name] = VariableSuggestion(name: name, kind: kind);
      }
    }

    for (final suggestion in builtinCommandVariableSuggestions) {
      addSuggestion(suggestion.name, kind: suggestion.kind);
    }

    for (final option in _effectiveOptions) {
      final optionName = option.name.trim();
      if (optionName.isEmpty) {
        continue;
      }

      addSuggestion('opts.$optionName', kind: VariableSuggestionKind.unknown);

      switch (option.type) {
        case CommandOptionType.integer:
        case CommandOptionType.number:
          addSuggestion(
            'opts.$optionName',
            kind: VariableSuggestionKind.numeric,
          );
          break;
        case CommandOptionType.user:
        case CommandOptionType.mentionable:
          addSuggestion(
            'opts.$optionName.id',
            kind: VariableSuggestionKind.nonNumeric,
          );
          addSuggestion(
            'opts.$optionName.username',
            kind: VariableSuggestionKind.nonNumeric,
          );
          addSuggestion(
            'opts.$optionName.tag',
            kind: VariableSuggestionKind.nonNumeric,
          );
          addSuggestion(
            'opts.$optionName.avatar',
            kind: VariableSuggestionKind.nonNumeric,
          );
          addSuggestion(
            'opts.$optionName.banner',
            kind: VariableSuggestionKind.nonNumeric,
          );
          break;
        case CommandOptionType.channel:
          addSuggestion(
            'opts.$optionName.id',
            kind: VariableSuggestionKind.nonNumeric,
          );
          addSuggestion(
            'opts.$optionName.type',
            kind: VariableSuggestionKind.nonNumeric,
          );
          break;
        case CommandOptionType.role:
          addSuggestion(
            'opts.$optionName.id',
            kind: VariableSuggestionKind.nonNumeric,
          );
          break;
        default:
          break;
      }
    }

    final actions = _flattenActionTree(_effectiveActions);
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      final actionKey = _resolveActionKey(action, i);
      if (actionKey.isEmpty) {
        continue;
      }
      addSuggestion(actionKey, kind: VariableSuggestionKind.unknown);
      addSuggestion('action.$actionKey', kind: VariableSuggestionKind.unknown);

      final type = (action['type'] ?? '').toString();
      if (type == 'httpRequest') {
        addSuggestion(
          'action.$actionKey.status',
          kind: VariableSuggestionKind.numeric,
        );
        addSuggestion(
          'action.$actionKey.body',
          kind: VariableSuggestionKind.nonNumeric,
        );
        addSuggestion(
          'action.$actionKey.jsonPath',
          kind: VariableSuggestionKind.nonNumeric,
        );
        addSuggestion(
          '$actionKey.status',
          kind: VariableSuggestionKind.numeric,
        );
        addSuggestion(
          '$actionKey.body',
          kind: VariableSuggestionKind.nonNumeric,
        );
        addSuggestion(
          '$actionKey.jsonPath',
          kind: VariableSuggestionKind.nonNumeric,
        );
      }

      if (type == 'appendArrayElement') {
        addSuggestion(
          'action.$actionKey.items',
          kind: VariableSuggestionKind.unknown,
        );
        addSuggestion('$actionKey.items', kind: VariableSuggestionKind.unknown);
        addSuggestion(
          'action.$actionKey.length',
          kind: VariableSuggestionKind.numeric,
        );
        addSuggestion(
          '$actionKey.length',
          kind: VariableSuggestionKind.numeric,
        );
      }

      if (type == 'removeArrayElement') {
        addSuggestion(
          'action.$actionKey.items',
          kind: VariableSuggestionKind.unknown,
        );
        addSuggestion('$actionKey.items', kind: VariableSuggestionKind.unknown);
        addSuggestion(
          'action.$actionKey.length',
          kind: VariableSuggestionKind.numeric,
        );
        addSuggestion(
          '$actionKey.length',
          kind: VariableSuggestionKind.numeric,
        );
        addSuggestion(
          'action.$actionKey.removed',
          kind: VariableSuggestionKind.unknown,
        );
        addSuggestion(
          '$actionKey.removed',
          kind: VariableSuggestionKind.unknown,
        );
      }

      if (type == 'queryArray' || type == 'listScopedVariableIndex') {
        addSuggestion(
          'action.$actionKey.items',
          kind: VariableSuggestionKind.unknown,
        );
        addSuggestion('$actionKey.items', kind: VariableSuggestionKind.unknown);
        addSuggestion(
          'action.$actionKey.count',
          kind: VariableSuggestionKind.numeric,
        );
        addSuggestion('$actionKey.count', kind: VariableSuggestionKind.numeric);
        addSuggestion(
          'action.$actionKey.total',
          kind: VariableSuggestionKind.numeric,
        );
        addSuggestion('$actionKey.total', kind: VariableSuggestionKind.numeric);
      }

      final storeAlias = _resolveActionStoreAlias(action);
      if (storeAlias.isNotEmpty) {
        addSuggestion(storeAlias, kind: VariableSuggestionKind.unknown);
      }
    }

    addSuggestion('workflow.name', kind: VariableSuggestionKind.nonNumeric);
    addSuggestion(
      'workflow.entryPoint',
      kind: VariableSuggestionKind.nonNumeric,
    );
    addSuggestion('workflow.args', kind: VariableSuggestionKind.nonNumeric);
    addSuggestion('arg.yourArg', kind: VariableSuggestionKind.unknown);
    addSuggestion('workflow.arg.yourArg', kind: VariableSuggestionKind.unknown);
    for (final functionName in const <String>[
      'length(source)',
      'at(source, 0)',
      'slice(source, 0, 10)',
      'join(source, ", ")',
      'formatEach(source, "{value}", ", ")',
      'embedFields(source, "{name}", "{value}", true)',
      'avatar(interaction.user.avatar, "webp", 1024)',
      'banner(interaction.user.banner, "png", 512)',
      'coin()',
      'random()',
      'randomchoice("a", "b", "c")',
      'randomint(1, 100)',
    ]) {
      addSuggestion(functionName, kind: VariableSuggestionKind.unknown);
    }

    for (final name in _persistedGlobalVariableNames) {
      addSuggestion(name, kind: VariableSuggestionKind.unknown);
    }

    for (final name in _scopedVariableSuggestionNames) {
      addSuggestion(name, kind: VariableSuggestionKind.unknown);
    }

    final suggestions = suggestionsByName.values.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    return suggestions;
  }

  String _currentVariableQuery(TextEditingController controller) {
    final selection = controller.selection;
    final cursor = selection.baseOffset;
    if (cursor < 0) {
      return '';
    }

    final beforeCursor = controller.text.substring(0, cursor);
    final start = beforeCursor.lastIndexOf('((');
    if (start == -1) {
      return '';
    }

    final alreadyClosed = beforeCursor.substring(start).contains('))');
    if (alreadyClosed) {
      return '';
    }

    final raw = beforeCursor.substring(start + 2);
    final parts = raw.split('|');
    return parts.last.trimLeft();
  }

  void _insertVariable(TextEditingController controller, String variableName) {
    final selection = controller.selection;
    final cursor = selection.baseOffset;
    if (cursor < 0) {
      return;
    }

    final beforeCursor = controller.text.substring(0, cursor);
    final afterCursor = controller.text.substring(cursor);
    final start = beforeCursor.lastIndexOf('((');
    if (start == -1) {
      final token = '(($variableName))';
      final nextText = '$beforeCursor$token$afterCursor';
      final nextCursor = beforeCursor.length + token.length;
      controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextCursor),
      );
      return;
    }

    final rawInner = beforeCursor.substring(start + 2);
    final parts = rawInner.split('|');
    final prefixParts =
        parts.length > 1 ? parts.sublist(0, parts.length - 1) : <String>[];
    final previous =
        prefixParts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final merged = [...previous, variableName];
    final inner = merged.join(' | ');

    final newBefore = '${beforeCursor.substring(0, start)}(($inner))';
    final nextText = '$newBefore$afterCursor';
    final nextCursor = newBefore.length;

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
  }

  Widget _buildVariableSuggestionBar(TextEditingController controller) {
    final query = _currentVariableQuery(controller).trim();
    final cursor = controller.selection.baseOffset;
    if (cursor < 0) {
      return const SizedBox.shrink();
    }

    final beforeCursor = controller.text.substring(0, cursor);
    final start = beforeCursor.lastIndexOf('((');
    if (start == -1) {
      return const SizedBox.shrink();
    }

    final inner = beforeCursor.substring(start + 2);
    final inFallbackMode = inner.contains('|');

    if (query.isEmpty && !inFallbackMode) {
      return const SizedBox.shrink();
    }

    final suggestions =
        _variableNames
            .where((name) => name.toLowerCase().contains(query.toLowerCase()))
            .take(8)
            .toList();

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inFallbackMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Fallback mode: next variable is used if previous is empty.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  suggestions
                      .map(
                        (name) => ActionChip(
                          label: Text('(($name))'),
                          onPressed: () => _insertVariable(controller, name),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
