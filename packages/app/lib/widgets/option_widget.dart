import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart' hide Builder;
import 'package:bot_creator/main.dart';

import '../routes/app/command_option_serialization.dart';
import '../types/variable_suggestion.dart';
import 'variable_text_field.dart';

class OptionWidget extends StatefulWidget {
  final Function(List<CommandOptionBuilder>) onChange;
  final List<CommandOptionBuilder>? initialOptions;
  final String? botIdForConfig;
  final List<VariableSuggestion> variableSuggestions;

  const OptionWidget({
    super.key,
    required this.onChange,
    this.initialOptions,
    this.botIdForConfig,
    this.variableSuggestions = const <VariableSuggestion>[],
  });

  @override
  OptionWidgetState createState() => OptionWidgetState();
}

class OptionWidgetState extends State<OptionWidget> {
  static const List<CommandOptionType> _leafOptionTypes = <CommandOptionType>[
    CommandOptionType.string,
    CommandOptionType.integer,
    CommandOptionType.boolean,
    CommandOptionType.user,
    CommandOptionType.channel,
    CommandOptionType.role,
    CommandOptionType.mentionable,
    CommandOptionType.number,
    CommandOptionType.attachment,
  ];

  static const List<CommandOptionType> _hierarchyOptionTypes =
      <CommandOptionType>[
        CommandOptionType.subCommand,
        CommandOptionType.subCommandGroup,
      ];

  final List<CommandOptionBuilder> options = <CommandOptionBuilder>[];
  List<String> _availableWorkflowNames = const [];
  bool _loadingWorkflows = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialOptions != null) {
      options.addAll(widget.initialOptions!);
      for (final option in options) {
        _normalizeForType(option);
      }
    }
    _loadAvailableWorkflows();
  }

  @override
  void didUpdateWidget(OptionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.botIdForConfig != oldWidget.botIdForConfig) {
      _loadAvailableWorkflows();
    }
  }

  Future<void> _loadAvailableWorkflows() async {
    final botId = widget.botIdForConfig;
    if (botId == null || botId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _availableWorkflowNames = const [];
          _loadingWorkflows = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loadingWorkflows = true);
    try {
      final workflows = await appManager.getWorkflows(botId);
      if (!mounted) return;
      final names = workflows
        .map((w) => (w['name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toList(growable: false)..sort();
      setState(() {
        _availableWorkflowNames = names;
        _loadingWorkflows = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingWorkflows = false);
    }
  }

  bool _isHierarchyType(CommandOptionType type) {
    return _hierarchyOptionTypes.contains(type);
  }

  bool _isNumericType(CommandOptionType type) {
    return type == CommandOptionType.integer ||
        type == CommandOptionType.number;
  }

  bool _supportsChoices(CommandOptionType type) {
    return type == CommandOptionType.string ||
        type == CommandOptionType.integer ||
        type == CommandOptionType.number;
  }

  bool _supportsAutocomplete(CommandOptionType type) {
    return commandOptionSupportsAutocomplete(type);
  }

  String _typeLabel(CommandOptionType type) {
    switch (type) {
      case CommandOptionType.string:
        return 'String';
      case CommandOptionType.integer:
        return 'Integer';
      case CommandOptionType.boolean:
        return 'Boolean';
      case CommandOptionType.user:
        return 'User';
      case CommandOptionType.channel:
        return 'Channel';
      case CommandOptionType.role:
        return 'Role';
      case CommandOptionType.mentionable:
        return 'Mentionable';
      case CommandOptionType.number:
        return 'Number';
      case CommandOptionType.attachment:
        return 'Attachment';
      case CommandOptionType.subCommand:
        return 'SubCommand';
      case CommandOptionType.subCommandGroup:
        return 'SubCommand Group';
    }
    return 'Unknown';
  }

  List<CommandOptionType> _allowedTypesForLevel({
    required CommandOptionType? parentType,
    required List<CommandOptionBuilder> siblings,
  }) {
    if (parentType == CommandOptionType.subCommandGroup) {
      return const <CommandOptionType>[CommandOptionType.subCommand];
    }

    if (parentType == CommandOptionType.subCommand) {
      return _leafOptionTypes;
    }

    final hasHierarchy = siblings.any((entry) => _isHierarchyType(entry.type));
    final hasLeaf = siblings.any((entry) => !_isHierarchyType(entry.type));

    if (hasHierarchy && !hasLeaf) {
      return _hierarchyOptionTypes;
    }

    if (hasLeaf && !hasHierarchy) {
      return _leafOptionTypes;
    }

    return <CommandOptionType>[..._leafOptionTypes, ..._hierarchyOptionTypes];
  }

  CommandOptionBuilder _buildDefaultOption(
    List<CommandOptionBuilder> target, {
    required CommandOptionType? parentType,
  }) {
    final allowedTypes = _allowedTypesForLevel(
      parentType: parentType,
      siblings: target,
    );
    final type = allowedTypes.first;
    final option = CommandOptionBuilder(
      name: 'option${target.length + 1}',
      description: 'Description for option ${target.length + 1}',
      type: type,
      isRequired: false,
    );
    _normalizeForType(option);
    return option;
  }

  void _normalizeForType(CommandOptionBuilder option) {
    final type = option.type;

    if (_isHierarchyType(type)) {
      option.isRequired = false;
      option.choices = null;
      option.minValue = null;
      option.maxValue = null;
      option.hasAutocomplete = null;
      setCommandOptionAutocompleteConfig(option, null);
      option.options ??= <CommandOptionBuilder>[];

      if (type == CommandOptionType.subCommand) {
        option.options = (option.options ?? <CommandOptionBuilder>[])
            .where((entry) => !_isHierarchyType(entry.type))
            .toList(growable: true);
      }

      if (type == CommandOptionType.subCommandGroup) {
        option.options = (option.options ?? <CommandOptionBuilder>[])
            .where((entry) => entry.type == CommandOptionType.subCommand)
            .toList(growable: true);
      }
      return;
    }

    option.options = null;

    if (!_supportsChoices(type)) {
      option.choices = null;
    }

    if (!_supportsAutocomplete(type)) {
      option.hasAutocomplete = null;
      setCommandOptionAutocompleteConfig(option, null);
    }

    if (option.hasAutocomplete == true) {
      option.choices = null;
    }

    if (!_isNumericType(type)) {
      option.minValue = null;
      option.maxValue = null;
    }
  }

  void _updateWidget() {
    widget.onChange(options);
  }

  String? _nameValidator(
    String? value,
    List<CommandOptionBuilder> levelOptions,
    CommandOptionBuilder current,
  ) {
    if (value == null || value.isEmpty) {
      return 'Please enter a name for the option';
    }

    if (value.length > 32) {
      return 'Option name must be at most 32 characters long';
    }

    if (value.contains(RegExp(r'[^a-zA-Z0-9_]'))) {
      return 'Option name can only contain letters, numbers, and underscores';
    }

    if (value.startsWith('_') ||
        value.startsWith('!') ||
        value.startsWith('/') ||
        value.startsWith('#') ||
        value.startsWith('@') ||
        value.startsWith('&') ||
        value.startsWith('%')) {
      return 'Option name starts with an unsupported character';
    }

    var duplicates = 0;
    for (final entry in levelOptions) {
      if (entry.name == value && !identical(entry, current)) {
        duplicates++;
      }
    }

    if (duplicates > 0) {
      return 'This name is already used at this level';
    }

    return null;
  }

  TextInputType _choiceKeyboardType(CommandOptionType type) {
    if (_isNumericType(type)) {
      return TextInputType.number;
    }
    return TextInputType.text;
  }

  Widget _buildOptionsLevel(
    List<CommandOptionBuilder> levelOptions, {
    required CommandOptionType? parentType,
    required int depth,
  }) {
    return Column(
      children: <Widget>[
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: levelOptions.length,
          itemBuilder: (BuildContext context, int index) {
            final option = levelOptions[index];
            final allowedTypes = _allowedTypesForLevel(
              parentType: parentType,
              siblings: levelOptions
                  .where((o) => o != option)
                  .toList(growable: false),
            );

            if (!allowedTypes.contains(option.type)) {
              option.type = allowedTypes.first;
              _normalizeForType(option);
            }

            return ExpansionTile(
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                option.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    levelOptions.removeAt(index);
                    _updateWidget();
                  });
                },
              ),
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(
                    left: depth > 0 ? 12 : 0,
                    right: 8,
                    bottom: 8,
                  ),
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: option.name,
                        maxLength: 32,
                        validator: (String? value) {
                          return _nameValidator(value, levelOptions, option);
                        },
                        onChanged: (String value) {
                          setState(() {
                            option.name = value;
                            _updateWidget();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLength: 100,
                        maxLines: 2,
                        minLines: 1,
                        initialValue: option.description,
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description for the option';
                          }
                          return null;
                        },
                        onChanged: (String value) {
                          setState(() {
                            option.description = value;
                            _updateWidget();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          const Text('Type'),
                          const Spacer(),
                          DropdownButton<CommandOptionType>(
                            value: option.type,
                            onChanged: (CommandOptionType? newValue) {
                              if (newValue == null) {
                                return;
                              }
                              setState(() {
                                option.type = newValue;
                                _normalizeForType(option);
                                _updateWidget();
                              });
                            },
                            items: allowedTypes
                                .map(
                                  (CommandOptionType type) =>
                                      DropdownMenuItem<CommandOptionType>(
                                        value: type,
                                        child: Text(_typeLabel(type)),
                                      ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!_isHierarchyType(option.type))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Text('Required'),
                              const Spacer(),
                              Switch(
                                value: option.isRequired ?? false,
                                onChanged: (bool value) {
                                  setState(() {
                                    option.isRequired = value;
                                    _updateWidget();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      if (!_isHierarchyType(option.type) &&
                          _supportsAutocomplete(option.type))
                        CheckboxListTile(
                          title: const Text('Dynamic Autocomplete'),
                          subtitle: const Text(
                            'Resolve choices from a workflow instead of static values.',
                          ),
                          value: isCommandOptionAutocompleteEnabled(option),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                setCommandOptionAutocompleteConfig(option, {
                                  'enabled': true,
                                  'mode': 'workflow',
                                  'workflow': '',
                                  'entryPoint': 'main',
                                  'arguments': <String, dynamic>{},
                                  'staticChoices': <Map<String, dynamic>>[],
                                });
                              } else {
                                setCommandOptionAutocompleteConfig(
                                  option,
                                  null,
                                );
                              }
                              _normalizeForType(option);
                              _updateWidget();
                            });
                          },
                        ),
                      if (isCommandOptionAutocompleteEnabled(
                        option,
                      )) ...<Widget>[
                        Builder(
                          builder: (context) {
                            final cfg =
                                getCommandOptionAutocompleteConfig(option) ??
                                <String, dynamic>{
                                  'enabled': true,
                                  'mode': 'workflow',
                                  'workflow': '',
                                  'entryPoint': 'main',
                                  'arguments': <String, dynamic>{},
                                  'staticChoices': <Map<String, dynamic>>[],
                                };
                            final currentMode =
                                (cfg['mode'] ?? 'workflow').toString() ==
                                        'static'
                                    ? 'static'
                                    : 'workflow';

                            Map<String, dynamic> updatedCfg([
                              Map<String, dynamic>? overrides,
                            ]) {
                              final base = Map<String, dynamic>.from(cfg);
                              if (overrides != null) base.addAll(overrides);
                              return base;
                            }

                            void saveConfig(Map<String, dynamic> newCfg) {
                              setState(() {
                                setCommandOptionAutocompleteConfig(
                                  option,
                                  newCfg,
                                );
                                _updateWidget();
                              });
                            }

                            // ── Mode selector ──────────────────────────────
                            final modeSelector = SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'workflow',
                                  label: Text('Workflow'),
                                  icon: Icon(Icons.account_tree_outlined),
                                ),
                                ButtonSegment(
                                  value: 'static',
                                  label: Text('Static Options'),
                                  icon: Icon(Icons.list_alt_outlined),
                                ),
                              ],
                              selected: {currentMode},
                              onSelectionChanged: (Set<String> selection) {
                                saveConfig(
                                  updatedCfg({'mode': selection.first}),
                                );
                              },
                            );

                            // ── Workflow panel ─────────────────────────────
                            Widget workflowPanel() {
                              final currentWorkflow =
                                  (cfg['workflow'] ?? '').toString().trim();
                              final dropdownValue =
                                  _availableWorkflowNames.contains(
                                        currentWorkflow,
                                      )
                                      ? currentWorkflow
                                      : null;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: dropdownValue,
                                          isExpanded: true,
                                          items:
                                              _availableWorkflowNames
                                                  .map(
                                                    (name) => DropdownMenuItem<
                                                      String
                                                    >(
                                                      value: name,
                                                      child: Text(name),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged:
                                              _loadingWorkflows
                                                  ? null
                                                  : (value) => saveConfig(
                                                    updatedCfg({
                                                      'workflow': value ?? '',
                                                    }),
                                                  ),
                                          decoration: InputDecoration(
                                            labelText: 'Autocomplete Workflow',
                                            border: const OutlineInputBorder(),
                                            helperText:
                                                _loadingWorkflows
                                                    ? 'Loading workflows…'
                                                    : (_availableWorkflowNames
                                                            .isEmpty
                                                        ? 'No saved workflows found'
                                                        : 'Select a saved workflow'),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        tooltip: 'Refresh workflows',
                                        onPressed:
                                            _loadingWorkflows
                                                ? null
                                                : _loadAvailableWorkflows,
                                        icon: const Icon(Icons.refresh),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    key: ValueKey(
                                      'ac_workflow_manual_$currentWorkflow',
                                    ),
                                    initialValue: currentWorkflow,
                                    decoration: const InputDecoration(
                                      labelText: 'Or type workflow name',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged:
                                        (v) => saveConfig(
                                          updatedCfg({'workflow': v}),
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey('ac_ep_${cfg['workflow']}'),
                                    decoration: const InputDecoration(
                                      labelText: 'Entry Point',
                                      border: OutlineInputBorder(),
                                    ),
                                    initialValue:
                                        (cfg['entryPoint'] ?? 'main')
                                            .toString(),
                                    onChanged:
                                        (v) => saveConfig(
                                          updatedCfg({
                                            'entryPoint':
                                                v.trim().isEmpty ? 'main' : v,
                                          }),
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (context) {
                                      final args = Map<String, dynamic>.from(
                                        cfg['arguments'] is Map
                                            ? (cfg['arguments'] as Map).map(
                                              (k, v) =>
                                                  MapEntry(k.toString(), v),
                                            )
                                            : const {},
                                      );
                                      final entries = args.entries.toList();

                                      void saveArgs(
                                        Map<String, dynamic> newArgs,
                                      ) {
                                        saveConfig(
                                          updatedCfg({'arguments': newArgs}),
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (entries.isNotEmpty)
                                            const Text(
                                              'Workflow Arguments',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          if (entries.isNotEmpty)
                                            const SizedBox(height: 4),
                                          ...List.generate(entries.length, (i) {
                                            final k = entries[i].key;
                                            final v =
                                                entries[i].value?.toString() ??
                                                '';
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: _responsiveRow(
                                                first: TextFormField(
                                                  key: ValueKey(
                                                    'arg_k_${option.name}_$i',
                                                  ),
                                                  initialValue: k,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Key',
                                                        border:
                                                            OutlineInputBorder(),
                                                        isDense: true,
                                                      ),
                                                  onChanged: (newKey) {
                                                    final updated = Map<
                                                      String,
                                                      dynamic
                                                    >.from(args);
                                                    updated.remove(k);
                                                    if (newKey
                                                        .trim()
                                                        .isNotEmpty) {
                                                      updated[newKey
                                                              .trim()] =
                                                          v;
                                                    }
                                                    saveArgs(updated);
                                                  },
                                                ),
                                                second: VariableTextField(
                                                  key: ValueKey(
                                                    'arg_v_${option.name}_$i',
                                                  ),
                                                  label: 'Value',
                                                  initialValue: v,
                                                  suggestions:
                                                      widget
                                                          .variableSuggestions,
                                                  hint:
                                                      'Use variables/templates if needed',
                                                  onChanged: (newVal) {
                                                    final updated = Map<
                                                      String,
                                                      dynamic
                                                    >.from(args);
                                                    updated[k] = newVal;
                                                    saveArgs(updated);
                                                  },
                                                ),
                                                trailing: IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  tooltip: 'Remove',
                                                  onPressed: () {
                                                    final updated = Map<
                                                      String,
                                                      dynamic
                                                    >.from(args)..remove(k);
                                                    saveArgs(updated);
                                                  },
                                                ),
                                              ),
                                            );
                                          }),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              final updated =
                                                  Map<String, dynamic>.from(
                                                    args,
                                                  );
                                              var idx = entries.length;
                                              var newKey = 'arg$idx';
                                              while (updated.containsKey(
                                                newKey,
                                              )) {
                                                idx++;
                                                newKey = 'arg$idx';
                                              }
                                              updated[newKey] = '';
                                              saveArgs(updated);
                                            },
                                            icon: const Icon(Icons.add),
                                            label: const Text('Add Argument'),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              );
                            }

                            // ── Static options panel ───────────────────────
                            Widget staticPanel() {
                              final staticChoices = <Map<String, dynamic>>[];
                              if (cfg['staticChoices'] is List) {
                                for (final raw
                                    in cfg['staticChoices'] as List) {
                                  if (raw is Map) {
                                    staticChoices.add(
                                      Map<String, dynamic>.from(
                                        raw.map(
                                          (k, v) => MapEntry(k.toString(), v),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }

                              void saveChoices(
                                List<Map<String, dynamic>> choices,
                              ) {
                                saveConfig(
                                  updatedCfg({'staticChoices': choices}),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Suggestions are filtered by what the user types.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...List.generate(staticChoices.length, (i) {
                                    final choice = staticChoices[i];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: _responsiveRow(
                                        firstFlex: 3,
                                        secondFlex: 3,
                                        first: TextFormField(
                                          key: ValueKey(
                                            'sc_name_${option.name}_$i',
                                          ),
                                          initialValue:
                                              (choice['name'] ?? '')
                                                  .toString(),
                                          decoration: InputDecoration(
                                            labelText: 'Label ${i + 1}',
                                            border:
                                                const OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          onChanged: (v) {
                                            final updated = List<
                                              Map<String, dynamic>
                                            >.from(staticChoices);
                                            updated[i] = {
                                              ...updated[i],
                                              'name': v,
                                            };
                                            saveChoices(updated);
                                          },
                                        ),
                                        second: TextFormField(
                                          key: ValueKey(
                                            'sc_val_${option.name}_$i',
                                          ),
                                          initialValue:
                                              (choice['value'] ?? '')
                                                  .toString(),
                                          decoration: InputDecoration(
                                            labelText: 'Value ${i + 1}',
                                            border:
                                                const OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          onChanged: (v) {
                                            final updated = List<
                                              Map<String, dynamic>
                                            >.from(staticChoices);
                                            updated[i] = {
                                              ...updated[i],
                                              'value': v,
                                            };
                                            saveChoices(updated);
                                          },
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          tooltip: 'Remove',
                                          onPressed: () {
                                            final updated = List<
                                                Map<String, dynamic>
                                              >.from(staticChoices)
                                              ..removeAt(i);
                                            saveChoices(updated);
                                          },
                                        ),
                                      ),
                                    );
                                  }),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        final updated = [
                                          ...staticChoices,
                                          {
                                            'name':
                                                'Option ${staticChoices.length + 1}',
                                            'value':
                                                'option_${staticChoices.length + 1}',
                                          },
                                        ];
                                        saveChoices(updated);
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Option'),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                modeSelector,
                                const SizedBox(height: 10),
                                if (currentMode == 'workflow')
                                  workflowPanel()
                                else
                                  staticPanel(),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_isNumericType(option.type)) ...<Widget>[
                        _responsiveRow(
                          first: TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Min Value',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            initialValue: option.minValue?.toString(),
                            onChanged: (String value) {
                              setState(() {
                                option.minValue =
                                    value.isEmpty
                                        ? null
                                        : num.tryParse(value);
                                _updateWidget();
                              });
                            },
                          ),
                          second: TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max Value',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            initialValue: option.maxValue?.toString(),
                            onChanged: (String value) {
                              setState(() {
                                option.maxValue =
                                    value.isEmpty
                                        ? null
                                        : num.tryParse(value);
                                _updateWidget();
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ExpansionTile(
                        title: const Text('Add Localizations'),
                        childrenPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        children: <Widget>[
                          DropdownButtonFormField<Locale>(
                            decoration: const InputDecoration(
                              labelText: 'Select Language',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: Locale.fr,
                            items: Locale.values
                                .map(
                                  (Locale locale) => DropdownMenuItem<Locale>(
                                    value: locale,
                                    child: Text(
                                      locale.toString().split('.').last,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (Locale? value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                option.nameLocalizations ??= <Locale, String>{};
                                option.descriptionLocalizations ??=
                                    <Locale, String>{};
                                option.nameLocalizations!.putIfAbsent(
                                  value,
                                  () => '',
                                );
                                option.descriptionLocalizations!.putIfAbsent(
                                  value,
                                  () => '',
                                );
                                _updateWidget();
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          if (option.nameLocalizations != null &&
                              option.nameLocalizations!.isNotEmpty)
                            ...option.nameLocalizations!.entries.map((entry) {
                              final locale = entry.key;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Text(
                                            locale.toString().split('.').last,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                option.nameLocalizations!
                                                    .remove(locale);
                                                option.descriptionLocalizations!
                                                    .remove(locale);
                                                _updateWidget();
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      TextFormField(
                                        decoration: const InputDecoration(
                                          labelText: 'Localized Name',
                                          isDense: true,
                                        ),
                                        initialValue:
                                            option.nameLocalizations![locale],
                                        onChanged: (String val) {
                                          setState(() {
                                            option.nameLocalizations![locale] =
                                                val;
                                            _updateWidget();
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        decoration: const InputDecoration(
                                          labelText: 'Localized Description',
                                          isDense: true,
                                        ),
                                        initialValue:
                                            option
                                                .descriptionLocalizations![locale],
                                        onChanged: (String val) {
                                          setState(() {
                                            option.descriptionLocalizations![locale] =
                                                val;
                                            _updateWidget();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_supportsChoices(option.type) &&
                          !isCommandOptionAutocompleteEnabled(
                            option,
                          )) ...<Widget>[
                        if (option.choices != null)
                          ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: option.choices?.length ?? 0,
                            itemBuilder: (
                              BuildContext context,
                              int choiceIndex,
                            ) {
                              return ExpansionTile(
                                title: Text(
                                  'Choice ${choiceIndex + 1}',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setState(() {
                                      option.choices!.removeAt(choiceIndex);
                                      _updateWidget();
                                    });
                                  },
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                children: <Widget>[
                                  TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Choice Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    initialValue:
                                        option.choices![choiceIndex].name,
                                    maxLength: 100,
                                    onChanged: (String value) {
                                      setState(() {
                                        option.choices![choiceIndex].name =
                                            value;
                                        _updateWidget();
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    keyboardType: _choiceKeyboardType(
                                      option.type,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Choice Value',
                                      border: OutlineInputBorder(),
                                    ),
                                    initialValue:
                                        option.choices![choiceIndex].value
                                            .toString(),
                                    maxLength: 100,
                                    onChanged: (String value) {
                                      setState(() {
                                        if (_isNumericType(option.type)) {
                                          option.choices![choiceIndex].value =
                                              num.tryParse(value) ?? 0;
                                        } else {
                                          option.choices![choiceIndex].value =
                                              value;
                                        }
                                        _updateWidget();
                                      });
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                option.choices ??=
                                    <CommandOptionChoiceBuilder>[];
                                option.choices!.add(
                                  CommandOptionChoiceBuilder(
                                    name:
                                        'Choice ${option.choices!.length + 1}',
                                    value:
                                        _isNumericType(option.type)
                                            ? 0
                                            : 'Value ${option.choices!.length + 1}',
                                  ),
                                );
                                _updateWidget();
                              });
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(Icons.add),
                                SizedBox(width: 8),
                                Text('Add Choice'),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_isHierarchyType(option.type)) ...<Widget>[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            option.type == CommandOptionType.subCommandGroup
                                ? 'SubCommands'
                                : 'SubCommand Options',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildOptionsLevel(
                            option.options ?? <CommandOptionBuilder>[],
                            parentType: option.type,
                            depth: depth + 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        if (levelOptions.length < 25)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  levelOptions.add(
                    _buildDefaultOption(levelOptions, parentType: parentType),
                  );
                  _updateWidget();
                });
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.add),
                  SizedBox(width: 8),
                  Text('Add Option'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _responsiveRow({
    required Widget first,
    required Widget second,
    Widget? trailing,
    int firstFlex = 1,
    int secondFlex = 1,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: first),
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: second),
                  if (trailing != null)
                    SizedBox(width: 40),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: firstFlex, child: first),
            const SizedBox(width: 6),
            Expanded(flex: secondFlex, child: second),
            if (trailing != null) trailing,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildOptionsLevel(options, parentType: null, depth: 0),
        const SizedBox(height: 10),
      ],
    );
  }
}
