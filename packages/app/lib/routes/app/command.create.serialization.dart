part of 'command.create.dart';

extension _CommandCreateSerialization on _CommandCreatePageState {
  Map<String, dynamic> _buildCommandDataPayload({
    required List<Map<String, dynamic>> effectiveActions,
  }) {
    _persistActiveSubcommandWorkflow();

    final hasSubcommandWorkflows = _subcommandWorkflows.isNotEmpty;
    final fallbackRoute =
        _subcommandWorkflows.containsKey(_activeSubcommandRoute)
            ? _activeSubcommandRoute
            : (hasSubcommandWorkflows
                ? _subcommandWorkflows.keys.first
                : _CommandCreatePageState._rootWorkflowRoute);

    final fallbackPayload =
        hasSubcommandWorkflows ? _subcommandWorkflows[fallbackRoute] : null;

    final responsePayload =
        fallbackPayload != null
            ? Map<String, dynamic>.from(
              (fallbackPayload['response'] as Map?)?.cast<String, dynamic>() ??
                  _buildResponsePayloadFromEditor(),
            )
            : _buildResponsePayloadFromEditor();

    final actionsPayload =
        fallbackPayload != null
            ? List<Map<String, dynamic>>.from(
              (fallbackPayload['actions'] as List?)?.whereType<Map>().map(
                    (entry) => Map<String, dynamic>.from(entry),
                  ) ??
                  const <Map<String, dynamic>>[],
            )
            : effectiveActions;

    return {
      'version': 1,
      'commandType': _commandTypeToText(_commandType),
      'editorMode': _editorMode,
      'legacyModeEnabled': _legacyModeEnabled,
      'legacyPrefixOverride': _legacyPrefixOverride.trim(),
      'legacyResponseTarget': _legacyResponseTarget,
      'simpleConfig': _currentSimpleConfig(),
      'defaultMemberPermissions': _defaultMemberPermissions.trim(),
      if (_supportsCommandOptions && _effectiveOptions.isNotEmpty)
        'options': _serializeOptions(_effectiveOptions),
      'response': responsePayload,
      'actions': actionsPayload,
      if (hasSubcommandWorkflows)
        'subcommandWorkflows': cloneSubcommandWorkflowPayloads(
          _subcommandWorkflows,
        ),
      if (hasSubcommandWorkflows)
        'activeSubcommandRoute': _activeSubcommandRoute,
    };
  }

  List<Map<String, dynamic>> _serializeOptions(
    List<CommandOptionBuilder> options,
  ) {
    return serializeCommandOptions(options);
  }

  String _normalizeScopedKeyForImport(String rawKey) {
    final key = rawKey.trim();
    if (key.isEmpty) {
      return key;
    }
    if (key.startsWith('bc_') && key.length > 3) {
      return key.substring(3);
    }
    return key;
  }

  String _toScopedReferenceName(String rawKey) {
    final key = rawKey.trim();
    if (key.isEmpty) {
      return key;
    }
    return key.startsWith('bc_') ? key : 'bc_$key';
  }

  List<Map<String, dynamic>> _normalizeImportedScopedActionKeys(
    List<Map<String, dynamic>> actions,
  ) {
    return actions
        .map((raw) {
          final action = Map<String, dynamic>.from(raw);
          final type = (action['type'] ?? '').toString().trim();
          if (type != 'setScopedVariable' &&
              type != 'getScopedVariable' &&
              type != 'removeScopedVariable' &&
              type != 'renameScopedVariable') {
            return action;
          }

          final payload = Map<String, dynamic>.from(
            (action['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          if (type == 'renameScopedVariable') {
            payload['oldKey'] = _normalizeScopedKeyForImport(
              (payload['oldKey'] ?? '').toString(),
            );
            payload['newKey'] = _normalizeScopedKeyForImport(
              (payload['newKey'] ?? '').toString(),
            );
          } else {
            payload['key'] = _normalizeScopedKeyForImport(
              (payload['key'] ?? '').toString(),
            );
          }

          action['payload'] = payload;
          return action;
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _buildCommandSharePayload() {
    final effectiveOptions = _effectiveOptions;
    final effectiveActions = _effectiveActions;
    final commandData = _buildCommandDataPayload(
      effectiveActions: effectiveActions,
    );

    return <String, dynamic>{
      'version': 1,
      'type': 'bot_creator_command',
      'command': <String, dynamic>{
        'name': _commandName,
        'commandType': _commandTypeToText(_commandType),
        'description': _effectiveCommandDescription,
        'integrationTypes': _integrationTypes
            .map(_integrationTypeToText)
            .toList(growable: false),
        'contexts': _contexts.map(_contextTypeToText).toList(growable: false),
        'options': _serializeOptions(effectiveOptions),
        'data': commandData,
      },
    };
  }

  String _integrationTypeToText(ApplicationIntegrationType type) {
    if (type == ApplicationIntegrationType.guildInstall) {
      return 'guildInstall';
    }
    if (type == ApplicationIntegrationType.userInstall) {
      return 'userInstall';
    }
    return 'guildInstall';
  }

  ApplicationIntegrationType? _integrationTypeFromText(String text) {
    final normalized = text.trim().toLowerCase();
    switch (normalized) {
      case 'guildinstall':
        return ApplicationIntegrationType.guildInstall;
      case 'userinstall':
        return ApplicationIntegrationType.userInstall;
      default:
        return null;
    }
  }

  String _commandTypeToText(ApplicationCommandType type) {
    if (type == ApplicationCommandType.user) {
      return 'user';
    }
    if (type == ApplicationCommandType.message) {
      return 'message';
    }
    return 'chatInput';
  }

  ApplicationCommandType? _commandTypeFromText(String text) {
    final normalized = text.trim().toLowerCase();
    switch (normalized) {
      case 'chatinput':
      case 'chat_input':
      case 'chat-input':
      case 'slash':
        return ApplicationCommandType.chatInput;
      case 'user':
      case 'usercommand':
      case 'user_command':
      case 'user-command':
        return ApplicationCommandType.user;
      case 'message':
      case 'messagecommand':
      case 'message_command':
      case 'message-command':
        return ApplicationCommandType.message;
      default:
        return null;
    }
  }

  String _contextTypeToText(InteractionContextType type) {
    if (type == InteractionContextType.guild) {
      return 'guild';
    }
    if (type == InteractionContextType.botDm) {
      return 'botDm';
    }
    if (type == InteractionContextType.privateChannel) {
      return 'privateChannel';
    }
    return 'guild';
  }

  InteractionContextType? _contextTypeFromText(String text) {
    final normalized = text.trim().toLowerCase();
    switch (normalized) {
      case 'guild':
        return InteractionContextType.guild;
      case 'botdm':
        return InteractionContextType.botDm;
      case 'privatechannel':
        return InteractionContextType.privateChannel;
      default:
        return null;
    }
  }

  Future<void> _copyCommandPayload({required bool asBase64}) async {
    final payload = _buildCommandSharePayload();
    final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
    final text = asBase64 ? base64Encode(utf8.encode(jsonText)) : jsonText;
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          asBase64 ? 'Command copied as Base64.' : 'Command copied as JSON.',
        ),
      ),
    );
  }

  Future<void> _showCommandExportOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.data_object_outlined),
                title: const Text('Export command as JSON'),
                subtitle: const Text('Copy readable JSON to clipboard'),
                onTap: () async {
                  Navigator.pop(context);
                  await _copyCommandPayload(asBase64: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Export command as Base64'),
                subtitle: const Text(
                  'Copy compact Base64 payload to clipboard',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _copyCommandPayload(asBase64: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importCommandPayload() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final initialText = (clipboard?.text ?? '').trim();
    final controller = TextEditingController(text: initialText);

    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import command'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Paste a command payload (JSON or Base64).'),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Command payload',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    if (shouldImport != true) {
      return;
    }

    final rawInput = controller.text.trim();
    if (rawInput.isEmpty) {
      return;
    }

    dynamic decoded;
    try {
      if (rawInput.startsWith('{') || rawInput.startsWith('[')) {
        decoded = jsonDecode(rawInput);
      } else {
        final jsonText = utf8.decode(base64Decode(rawInput));
        decoded = jsonDecode(jsonText);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid command payload format.')),
      );
      return;
    }

    if (decoded is! Map) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid command payload structure.')),
      );
      return;
    }

    final map = Map<String, dynamic>.from(decoded);
    final commandRoot =
        map['command'] is Map
            ? Map<String, dynamic>.from(
              (map['command'] as Map).cast<String, dynamic>(),
            )
            : map;

    final commandDataRaw =
        commandRoot['data'] is Map
            ? Map<String, dynamic>.from(
              (commandRoot['data'] as Map).cast<String, dynamic>(),
            )
            : commandRoot;

    final normalizedData = appManager.normalizeCommandData(<String, dynamic>{
      'data': commandDataRaw,
    });
    final normalizedPayload = Map<String, dynamic>.from(
      normalizedData['data'] as Map? ?? const {},
    );

    final response = Map<String, dynamic>.from(
      (normalizedPayload['response'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );

    final optionsRaw =
        (commandRoot['options'] as List?) ??
        (commandDataRaw['options'] as List?) ??
        const [];
    final importedOptions = optionsRaw
        .whereType<Map>()
        .map(
          (entry) => deserializeCommandOption(Map<String, dynamic>.from(entry)),
        )
        .toList(growable: false);

    final integrationTypeNames =
        ((commandRoot['integrationTypes'] as List?) ?? const [])
            .map((entry) => entry.toString())
            .toSet();
    final importedIntegrationTypes = integrationTypeNames
        .map(_integrationTypeFromText)
        .whereType<ApplicationIntegrationType>()
        .toList(growable: false);

    final contextNames =
        ((commandRoot['contexts'] as List?) ?? const [])
            .map((entry) => entry.toString())
            .toSet();
    final importedContexts = contextNames
        .map(_contextTypeFromText)
        .whereType<InteractionContextType>()
        .toList(growable: false);

    final importedType = _commandTypeFromText(
      (commandRoot['commandType'] ?? normalizedPayload['commandType'] ?? '')
          .toString(),
    );

    if (!mounted) {
      return;
    }
    _applyStateUpdate(() {
      _commandName = (commandRoot['name'] ?? '').toString();
      _commandDescription = (commandRoot['description'] ?? '').toString();
      _commandType = importedType ?? ApplicationCommandType.chatInput;

      final persistedEditorMode =
          (normalizedPayload['editorMode'] ??
                  _CommandCreatePageState._editorModeAdvanced)
              .toString()
              .toLowerCase();
      _editorMode =
          persistedEditorMode == _CommandCreatePageState._editorModeSimple
              ? _CommandCreatePageState._editorModeSimple
              : _CommandCreatePageState._editorModeAdvanced;
      if (!_supportsSimpleMode) {
        _editorMode = _CommandCreatePageState._editorModeAdvanced;
        _legacyModeEnabled = false;
      }
      _simpleModeLocked =
          _editorMode == _CommandCreatePageState._editorModeAdvanced;
      _legacyModeEnabled = normalizedPayload['legacyModeEnabled'] == true;
      _legacyPrefixOverride =
          (normalizedPayload['legacyPrefixOverride'] ?? '').toString();
      final importedLegacyResponseTarget =
          (normalizedPayload['legacyResponseTarget'] ?? 'reply').toString();
      _legacyResponseTarget =
          importedLegacyResponseTarget == 'channelSend'
              ? 'channelSend'
              : 'reply';

      final simpleConfig = _normalizeSimpleConfig(
        Map<String, dynamic>.from(
          (normalizedPayload['simpleConfig'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
      );
      _applySimpleConfig(simpleConfig);

      _defaultMemberPermissions =
          (normalizedPayload['defaultMemberPermissions'] ?? '')
              .toString()
              .trim();

      _responseType = (response['type'] ?? 'normal').toString();
      if (_legacyModeEnabled && _responseType == 'modal') {
        _responseType = 'normal';
      }
      _response = (response['text'] ?? '').toString();
      _responseController.text = _response;
      _responseEmbeds = _normalizeEmbedsPayload(response['embeds']);
      _responseComponents = Map<String, dynamic>.from(
        (response['components'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      _responseModal = Map<String, dynamic>.from(
        (response['modal'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      _responseWorkflow = _normalizeWorkflow(
        Map<String, dynamic>.from(
          (response['workflow'] as Map?)?.cast<String, dynamic>() ??
              _CommandCreatePageState._defaultWorkflow(),
        ),
      );

      _actions = _normalizeImportedScopedActionKeys(
        List<Map<String, dynamic>>.from(
          (normalizedPayload['actions'] as List?)?.whereType<Map>().map(
                (entry) => Map<String, dynamic>.from(entry),
              ) ??
              const <Map<String, dynamic>>[],
        ),
      );

      final importedSubcommandWorkflows = _normalizeStoredSubcommandWorkflows(
        normalizedPayload['subcommandWorkflows'],
      );
      _subcommandWorkflows =
          importedSubcommandWorkflows
              .map(
                (route, workflowPayload) => MapEntry(route, {
                  'response': Map<String, dynamic>.from(
                    (workflowPayload['response'] as Map?)
                            ?.cast<String, dynamic>() ??
                        const <String, dynamic>{},
                  ),
                  'actions': _normalizeImportedScopedActionKeys(
                    List<Map<String, dynamic>>.from(
                      (workflowPayload['actions'] as List?)
                              ?.whereType<Map>()
                              .map(
                                (entry) => Map<String, dynamic>.from(entry),
                              ) ??
                          const <Map<String, dynamic>>[],
                    ),
                  ),
                }),
              )
              .cast<String, Map<String, dynamic>>();
      _activeSubcommandRoute =
          (normalizedPayload['activeSubcommandRoute'] ??
                  _CommandCreatePageState._rootWorkflowRoute)
              .toString();

      if (_supportsCommandOptions && importedOptions.isNotEmpty) {
        _options = importedOptions;
      }
      if (importedIntegrationTypes.isNotEmpty) {
        _integrationTypes = importedIntegrationTypes;
      }
      if (importedContexts.isNotEmpty) {
        _contexts = importedContexts;
      }

      _syncSubcommandWorkflowRoutes();

      _isDataIncomplete = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Command imported into editor.')),
    );
  }
}
