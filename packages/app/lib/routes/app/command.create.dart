import 'dart:convert';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/builder.response.dart';
import 'package:bot_creator/routes/app/command_option_serialization.dart';
import 'package:bot_creator/routes/app/command_option_validation.dart';
import 'package:bot_creator/routes/app/workflow_docs.page.dart';
import 'package:bot_creator/types/app_emoji.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/app_emoji_api.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:bot_creator/utils/command_variable_catalog.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/simple_mode.dart';
import 'package:bot_creator/widgets/option_widget.dart';
import 'package:bot_creator/widgets/command_create_cards/basic_info_card.dart';
import 'package:bot_creator/widgets/command_create_cards/reply_card.dart';
import 'package:bot_creator/widgets/command_create_cards/actions_card.dart';
import 'package:bot_creator/widgets/response_embeds_editor.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyxx/nyxx.dart';

part 'command.create.variable_suggestions.dart';
part 'command.create.serialization.dart';
part 'command.create.simple_mode.dart';
part 'command.create.workflow.dart';
part 'command.create.validation.dart';

class CommandCreatePage extends StatefulWidget {
  final NyxxRest? client;
  final String? botId;
  final Snowflake id;
  const CommandCreatePage({
    super.key,
    this.client,
    this.botId,
    this.id = Snowflake.zero,
  });

  @override
  State<CommandCreatePage> createState() => _CommandCreatePageState();
}

class _CommandCreatePageState extends State<CommandCreatePage> {
  static const String _editorModeSimple = 'simple';
  static const String _editorModeAdvanced = 'advanced';
  static const String _rootWorkflowRoute = '__root__';

  String _commandName = "";
  String _commandDescription = "";
  ApplicationCommandType _commandType = ApplicationCommandType.chatInput;
  List<CommandOptionBuilder> _options = [];
  String _response = "";
  final TextEditingController _responseController = TextEditingController();
  String _responseType = 'normal';
  List<Map<String, dynamic>> _responseEmbeds = [];
  Map<String, dynamic> _responseComponents = {};
  Map<String, dynamic> _responseModal = {};
  List<Map<String, dynamic>> _actions = [];
  Map<String, dynamic> _responseWorkflow = _defaultWorkflow();
  Set<String> _persistedGlobalVariableNames = <String>{};
  Set<String> _scopedVariableSuggestionNames = {
    'guild.bc_key',
    'user.bc_key',
    'channel.bc_key',
    'guildMember.bc_key',
    'message.bc_key',
  };
  bool _isLoading = true;
  List<AppEmoji> _appEmojis = [];

  /// True when editing an existing command that couldn't be fully loaded
  /// (client offline AND no local `data` block). Disables editing UI.
  bool _isDataIncomplete = false;
  List<ApplicationIntegrationType> _integrationTypes = [
    ApplicationIntegrationType.guildInstall,
  ];
  List<InteractionContextType> _contexts = [InteractionContextType.guild];
  String _defaultMemberPermissions = '';
  String _editorMode = _editorModeSimple;
  bool _simpleModeLocked = false;
  bool _simpleDeleteMessages = false;
  bool _simpleKickUser = false;
  bool _simpleBanUser = false;
  bool _simpleUnbanUser = false;
  bool _simpleMuteUser = false;
  bool _simpleUnmuteUser = false;
  bool _simpleAddRole = false;
  bool _simpleRemoveRole = false;
  bool _simpleSendMessage = false;
  bool _simplePinMessage = false;
  bool _simpleUnpinMessage = false;
  bool _simpleCreateInvite = false;
  bool _simpleCreatePoll = false;
  final TextEditingController _simpleSendMessageController =
      TextEditingController();
  final TextEditingController _simpleActionReasonController =
      TextEditingController();
  final TextEditingController _simpleMuteDurationController =
      TextEditingController(text: '10m');
  final TextEditingController _simpleBanDeleteDaysController =
      TextEditingController(text: '0');
  final TextEditingController _simpleDeleteMessagesDefaultCountController =
      TextEditingController(text: '1');
  final TextEditingController _simpleInviteMaxAgeController =
      TextEditingController(text: '86400');
  final TextEditingController _simpleInviteMaxUsesController =
      TextEditingController(text: '0');
  final TextEditingController _simplePollAnswersController =
      TextEditingController(text: 'Yes\nNo');
  final TextEditingController _simplePollDurationHoursController =
      TextEditingController(text: '24');
  bool _simpleInviteTemporary = false;
  bool _simpleInviteUnique = false;
  bool _simplePollAllowMultiselect = false;
  Map<String, Map<String, dynamic>> _subcommandWorkflows =
      <String, Map<String, dynamic>>{};
  String _activeSubcommandRoute = _rootWorkflowRoute;
  bool _isApplyingWorkflowPayload = false;

  static Map<String, dynamic> _defaultWorkflow() {
    return {
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
        'whenTrueEmbeds': <Map<String, dynamic>>[],
        'whenFalseEmbeds': <Map<String, dynamic>>[],
        'whenTrueNormalComponents': <String, dynamic>{},
        'whenFalseNormalComponents': <String, dynamic>{},
        'whenTrueComponents': <String, dynamic>{},
        'whenFalseComponents': <String, dynamic>{},
        'whenTrueModal': <String, dynamic>{},
        'whenFalseModal': <String, dynamic>{},
      },
    };
  }

  bool get _isSimpleMode => _editorMode == _editorModeSimple;

  bool get _supportsCommandDescription =>
      _commandType == ApplicationCommandType.chatInput;

  bool get _supportsCommandOptions =>
      _commandType == ApplicationCommandType.chatInput;

  bool get _supportsSimpleMode =>
      _commandType == ApplicationCommandType.chatInput;

  String get _effectiveCommandDescription =>
      _supportsCommandDescription ? _commandDescription : '';

  bool _isHierarchyOptionType(CommandOptionType type) {
    return type == CommandOptionType.subCommand ||
        type == CommandOptionType.subCommandGroup;
  }

  bool _containsHierarchyOption(List<CommandOptionBuilder> options) {
    for (final option in options) {
      if (_isHierarchyOptionType(option.type)) {
        return true;
      }
      final nested = option.options;
      if (nested != null &&
          nested.isNotEmpty &&
          _containsHierarchyOption(nested)) {
        return true;
      }
    }
    return false;
  }

  List<String> _collectSubcommandRoutes(List<CommandOptionBuilder> options) {
    final routes = <String>[];

    for (final option in options) {
      final name = option.name.trim();
      if (name.isEmpty) {
        continue;
      }

      if (option.type == CommandOptionType.subCommand) {
        routes.add(name);
        continue;
      }

      if (option.type == CommandOptionType.subCommandGroup) {
        final children = option.options ?? <CommandOptionBuilder>[];
        for (final child in children) {
          if (child.type != CommandOptionType.subCommand) {
            continue;
          }
          final childName = child.name.trim();
          if (childName.isEmpty) {
            continue;
          }
          routes.add('$name/$childName');
        }
      }
    }

    return routes;
  }

  Map<String, dynamic> _cloneJsonMap(Map<String, dynamic> source) {
    return cloneJsonMap(source);
  }

  List<Map<String, dynamic>> _cloneJsonListOfMaps(
    List<Map<String, dynamic>> source,
  ) {
    return List<Map<String, dynamic>>.from(
      (jsonDecode(jsonEncode(source)) as List).whereType<Map>().map(
        (entry) => Map<String, dynamic>.from(entry),
      ),
    );
  }

  Map<String, dynamic> _buildResponsePayloadFromEditor() {
    return {
      'mode': _responseEmbeds.isNotEmpty ? 'embed' : 'text',
      'type': _responseType,
      'text': _responseController.text,
      'embed':
          _responseEmbeds.isNotEmpty
              ? Map<String, dynamic>.from(_responseEmbeds.first)
              : {'title': '', 'description': '', 'url': ''},
      'embeds': _cloneJsonListOfMaps(_responseEmbeds.take(10).toList()),
      'components': _cloneJsonMap(_responseComponents),
      'modal': _cloneJsonMap(_responseModal),
      'workflow': _normalizeWorkflow(_cloneJsonMap(_responseWorkflow)),
    };
  }

  Map<String, dynamic> _buildCurrentWorkflowPayload() {
    return {
      'response': _buildResponsePayloadFromEditor(),
      'actions': _cloneJsonListOfMaps(_actions),
    };
  }

  Map<String, dynamic> _buildDefaultWorkflowPayload() {
    return {
      'response': {
        'mode': 'text',
        'type': 'normal',
        'text': '',
        'embed': {'title': '', 'description': '', 'url': ''},
        'embeds': <Map<String, dynamic>>[],
        'components': <String, dynamic>{},
        'modal': <String, dynamic>{},
        'workflow': _defaultWorkflow(),
      },
      'actions': <Map<String, dynamic>>[],
    };
  }

  void _applyWorkflowPayloadToEditor(Map<String, dynamic> payload) {
    final response = Map<String, dynamic>.from(
      (payload['response'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    var embeds = _normalizeEmbedsPayload(response['embeds']);
    if (embeds.isEmpty) {
      final legacyEmbed = Map<String, dynamic>.from(
        (response['embed'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final hasLegacyEmbed =
          (legacyEmbed['title']?.toString().isNotEmpty ?? false) ||
          (legacyEmbed['description']?.toString().isNotEmpty ?? false) ||
          (legacyEmbed['url']?.toString().isNotEmpty ?? false);
      if (hasLegacyEmbed) {
        embeds = <Map<String, dynamic>>[
          {
            'title': legacyEmbed['title']?.toString() ?? '',
            'description': legacyEmbed['description']?.toString() ?? '',
            'url': legacyEmbed['url']?.toString() ?? '',
          },
        ];
      }
    }

    final actions = List<Map<String, dynamic>>.from(
      (payload['actions'] as List?)?.whereType<Map>().map(
            (entry) => Map<String, dynamic>.from(entry),
          ) ??
          const <Map<String, dynamic>>[],
    );

    final text = (response['text'] ?? '').toString();
    _isApplyingWorkflowPayload = true;
    _responseType = (response['type'] ?? 'normal').toString();
    _response = text;
    if (_responseController.text != text) {
      _responseController.text = text;
    }
    _responseEmbeds = embeds.take(10).toList(growable: false);
    _responseComponents = Map<String, dynamic>.from(
      (response['components'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    _responseModal = Map<String, dynamic>.from(
      (response['modal'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    _responseWorkflow = _normalizeWorkflow(
      Map<String, dynamic>.from(
        (response['workflow'] as Map?)?.cast<String, dynamic>() ??
            _defaultWorkflow(),
      ),
    );
    _actions = actions;
    _isApplyingWorkflowPayload = false;
  }

  Map<String, Map<String, dynamic>> _normalizeStoredSubcommandWorkflows(
    dynamic raw,
  ) {
    if (raw is! Map) {
      return <String, Map<String, dynamic>>{};
    }

    final normalized = <String, Map<String, dynamic>>{};
    raw.forEach((key, value) {
      if (value is! Map) {
        return;
      }
      final route = key.toString().trim();
      if (route.isEmpty) {
        return;
      }
      normalized[route] = Map<String, dynamic>.from(
        value.cast<String, dynamic>(),
      );
    });

    return normalized;
  }

  void _persistActiveSubcommandWorkflow() {
    if (_activeSubcommandRoute == _rootWorkflowRoute) {
      return;
    }
    if (!_subcommandWorkflows.containsKey(_activeSubcommandRoute)) {
      return;
    }

    _subcommandWorkflows[_activeSubcommandRoute] =
        _buildCurrentWorkflowPayload();
  }

  void _syncSubcommandWorkflowRoutes() {
    final routes = _collectSubcommandRoutes(_options);
    if (routes.isEmpty) {
      _subcommandWorkflows = <String, Map<String, dynamic>>{};
      _activeSubcommandRoute = _rootWorkflowRoute;
      return;
    }

    final hadExistingWorkflows = _subcommandWorkflows.isNotEmpty;
    _persistActiveSubcommandWorkflow();

    final next = <String, Map<String, dynamic>>{};
    for (final route in routes) {
      final existing = _subcommandWorkflows[route];
      if (existing != null) {
        next[route] = _cloneJsonMap(existing);
      } else {
        next[route] =
            (!hadExistingWorkflows && next.isEmpty)
                ? _buildCurrentWorkflowPayload()
                : _buildDefaultWorkflowPayload();
      }
    }

    _subcommandWorkflows = next;
    if (!_subcommandWorkflows.containsKey(_activeSubcommandRoute)) {
      _activeSubcommandRoute = routes.first;
    }

    final activePayload = _subcommandWorkflows[_activeSubcommandRoute];
    if (activePayload != null) {
      _applyWorkflowPayloadToEditor(activePayload);
    }
  }

  void _switchActiveSubcommandRoute(String route) {
    if (route == _activeSubcommandRoute) {
      return;
    }
    _persistActiveSubcommandWorkflow();
    _activeSubcommandRoute = route;
    final payload = _subcommandWorkflows[route];
    if (payload != null) {
      _applyWorkflowPayloadToEditor(payload);
    }
  }

  String _workflowRouteLabel(String route) {
    final parts = route.split('/');
    if (parts.length == 2) {
      return '/$_commandName ${parts[0]} ${parts[1]}';
    }
    return '/$_commandName $route';
  }

  Widget _buildSubcommandWorkflowSelectorCard() {
    if (_subcommandWorkflows.isEmpty) {
      return const SizedBox.shrink();
    }

    final routes = _subcommandWorkflows.keys.toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'SubCommand Workflow',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose which subcommand you are configuring.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue:
                  routes.contains(_activeSubcommandRoute)
                      ? _activeSubcommandRoute
                      : routes.first,
              decoration: const InputDecoration(
                labelText: 'Target subcommand',
                border: OutlineInputBorder(),
              ),
              items: routes
                  .map(
                    (route) => DropdownMenuItem<String>(
                      value: route,
                      child: Text(_workflowRouteLabel(route)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _switchActiveSubcommandRoute(value);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _applyOptionsUpdate(List<CommandOptionBuilder> options) {
    _options = options;
    if (_containsHierarchyOption(_options)) {
      _editorMode = _editorModeAdvanced;
      _simpleModeLocked = true;
    } else if (!_supportsSimpleMode) {
      _editorMode = _editorModeAdvanced;
      _simpleModeLocked = true;
    } else {
      _simpleModeLocked = _editorMode == _editorModeAdvanced;
    }
    _syncSubcommandWorkflowRoutes();
  }

  CommandOptionBuilder _buildOptionFromApplicationOption(dynamic source) {
    final option = CommandOptionBuilder(
      type: source.type as CommandOptionType,
      name: source.name.toString(),
      description: source.description?.toString() ?? '',
      isRequired: source.isRequired == true,
      minValue: source.minValue as num?,
      maxValue: source.maxValue as num?,
      nameLocalizations: source.nameLocalizations as Map<Locale, String>?,
      descriptionLocalizations:
          source.descriptionLocalizations as Map<Locale, String>?,
    );
    option.hasAutocomplete = source.hasAutocomplete == true;
    if (option.hasAutocomplete == true &&
        commandOptionSupportsAutocomplete(option.type)) {
      setCommandOptionAutocompleteConfig(option, <String, dynamic>{
        'enabled': true,
        'workflow': '',
        'entryPoint': 'main',
        'arguments': <String, dynamic>{},
      });
    }

    final rawChoices = source.choices;
    if (rawChoices is List &&
        rawChoices.isNotEmpty &&
        option.hasAutocomplete != true) {
      option.choices = rawChoices
          .map(
            (choice) => CommandOptionChoiceBuilder(
              name: choice.name.toString(),
              value: choice.value,
            ),
          )
          .toList(growable: false);
    }

    final rawOptions = source.options;
    if (rawOptions is List && rawOptions.isNotEmpty) {
      option.options = rawOptions
          .map(_buildOptionFromApplicationOption)
          .toList(growable: false);
    }

    return option;
  }

  List<CommandOptionBuilder> get _effectiveOptions {
    if (!_supportsCommandOptions) {
      return <CommandOptionBuilder>[];
    }
    return _isSimpleMode ? _buildSimpleModeOptions() : _options;
  }

  List<Map<String, dynamic>> get _effectiveActions =>
      _isSimpleMode ? _buildSimpleModeActions() : _actions;

  String? get _botIdForConfig =>
      widget.client?.user.id.toString() ?? widget.botId;

  @override
  void initState() {
    super.initState();
    _responseController.text = _response;
    _responseController.addListener(() {
      _response = _responseController.text;
      if (!_isApplyingWorkflowPayload) {
        _persistActiveSubcommandWorkflow();
      }
      if (mounted && !_isApplyingWorkflowPayload) {
        setState(() {});
      }
    });
    _init();
    // Initialize any necessary data or state
  }

  @override
  void dispose() {
    _responseController.dispose();
    _simpleSendMessageController.dispose();
    _simpleActionReasonController.dispose();
    _simpleMuteDurationController.dispose();
    _simpleBanDeleteDaysController.dispose();
    _simpleDeleteMessagesDefaultCountController.dispose();
    _simpleInviteMaxAgeController.dispose();
    _simpleInviteMaxUsesController.dispose();
    _simplePollAnswersController.dispose();
    _simplePollDurationHoursController.dispose();
    super.dispose();
  }

  void _applyStateUpdate(VoidCallback callback) {
    if (!mounted) {
      return;
    }
    setState(callback);
  }

  void _openDocumentationCenter() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder:
            (_) => const WorkflowDocumentationPage(
              initialSearch: 'commandType target opts template variables',
            ),
      ),
    );
  }

  Future<void> _init() async {
    await AppAnalytics.logScreenView(
      screenName: "CommandCreatePage",
      screenClass: "CommandCreatePage",
      parameters: {
        "command_id": widget.id.toString(),
        "command_name": widget.id.isZero ? "New Command" : _commandName,
        "is_new_command": widget.id.isZero ? "true" : "false",
        "client_id": widget.client?.user.id.toString() ?? "unknown",
      },
    );

    await _refreshPersistedVariableNames();

    // Load application emojis silently for autocomplete
    try {
      final bid = _botIdForConfig;
      if (bid != null) {
        final token = (await appManager.getApp(bid))['token'] as String?;
        if (token != null && token.isNotEmpty) {
          final emojis = await AppEmojiApi.listEmojis(token, bid);
          if (mounted) setState(() => _appEmojis = emojis);
        }
      }
    } catch (_) {}

    // first let's check if the command is already created or not
    if (!widget.id.isZero) {
      ApplicationCommand? command;
      try {
        final commandsList = await widget.client?.commands.list(
          withLocalizations: true,
        );
        command = commandsList?.cast<ApplicationCommand?>().firstWhere(
          (c) => c?.id == widget.id,
          orElse: () => null,
        );
      } catch (_) {}

      try {
        command ??= await widget.client?.commands.fetch(widget.id);
      } catch (_) {}

      // check if we also have the command in the database
      final botId = _botIdForConfig;
      if (botId == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final commandData = await appManager.getAppCommand(
        botId,
        widget.id.toString(),
      );
      // let's set the command data to the fields
      final data = commandData["data"];
      if (data != null) {
        final normalized = appManager.normalizeCommandData(
          Map<String, dynamic>.from(commandData),
        );
        final normalizedData = Map<String, dynamic>.from(
          normalized["data"] ?? const {},
        );
        final persistedEditorMode =
            (normalizedData['editorMode'] ?? _editorModeAdvanced)
                .toString()
                .toLowerCase();
        final editorMode =
            persistedEditorMode == _editorModeSimple
                ? _editorModeSimple
                : _editorModeAdvanced;
        final simpleConfig = _normalizeSimpleConfig(
          Map<String, dynamic>.from(
            (normalizedData['simpleConfig'] as Map?)?.cast<String, dynamic>() ??
                const {},
          ),
        );
        final response = Map<String, dynamic>.from(
          (normalizedData["response"] as Map?)?.cast<String, dynamic>() ??
              const {},
        );
        final embeds =
            (response['embeds'] is List)
                ? List<Map<String, dynamic>>.from(
                  (response['embeds'] as List).whereType<Map>().map(
                    (embed) => Map<String, dynamic>.from(
                      embed.map(
                        (key, value) => MapEntry(key.toString(), value),
                      ),
                    ),
                  ),
                )
                : <Map<String, dynamic>>[];

        if (embeds.isEmpty) {
          final legacyEmbed = Map<String, dynamic>.from(
            (response['embed'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          final hasLegacyEmbed =
              (legacyEmbed['title']?.toString().isNotEmpty ?? false) ||
              (legacyEmbed['description']?.toString().isNotEmpty ?? false) ||
              (legacyEmbed['url']?.toString().isNotEmpty ?? false);
          if (hasLegacyEmbed) {
            embeds.add({
              'title': legacyEmbed['title']?.toString() ?? '',
              'description': legacyEmbed['description']?.toString() ?? '',
              'url': legacyEmbed['url']?.toString() ?? '',
            });
          }
        }

        if (!mounted) return;
        setState(() {
          _editorMode = editorMode;
          final savedType = _commandTypeFromText(
            (normalizedData['commandType'] ?? commandData['type'] ?? '')
                .toString(),
          );
          _commandType = savedType ?? _commandType;
          if (!_supportsSimpleMode) {
            _editorMode = _editorModeAdvanced;
          }
          _simpleModeLocked = _editorMode == _editorModeAdvanced;
          _applySimpleConfig(simpleConfig);
          _responseType = (response['type'] ?? 'normal').toString();
          _response = (response["text"] ?? "").toString();
          _responseController.text = _response;
          _responseEmbeds = embeds.take(10).toList();
          _responseComponents = Map<String, dynamic>.from(
            (response['components'] as Map?)?.cast<String, dynamic>() ??
                const {},
          );
          _responseModal = Map<String, dynamic>.from(
            (response['modal'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          _responseWorkflow = _normalizeWorkflow(
            Map<String, dynamic>.from(
              (response['workflow'] as Map?)?.cast<String, dynamic>() ??
                  _defaultWorkflow(),
            ),
          );
          _actions = List<Map<String, dynamic>>.from(
            (normalizedData["actions"] as List?)?.whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(e),
                ) ??
                const [],
          );
          _subcommandWorkflows = _normalizeStoredSubcommandWorkflows(
            normalizedData['subcommandWorkflows'],
          );
          _activeSubcommandRoute =
              (normalizedData['activeSubcommandRoute'] ?? _rootWorkflowRoute)
                  .toString();
          final storedOptions = normalizedData['options'];
          if (storedOptions is List) {
            _options = deserializeCommandOptions(storedOptions);
          }
          if (_subcommandWorkflows.containsKey(_activeSubcommandRoute)) {
            final activePayload = _subcommandWorkflows[_activeSubcommandRoute];
            if (activePayload != null) {
              _applyWorkflowPayloadToEditor(activePayload);
            }
          }
          _defaultMemberPermissions =
              (normalizedData['defaultMemberPermissions'] ?? '')
                  .toString()
                  .trim();
        });
      } else {
        // No local data found for this existing command — default to advanced
        if (!mounted) return;
        setState(() {
          _editorMode = _editorModeAdvanced;
          _simpleModeLocked = true;
        });
      }
      // ── Safety net: always terminate loading even if Discord is offline ──
      if (command == null) {
        // Load minimal fields from local storage so the read-only banner can
        // display the command name/description even without a Discord connection.
        final localName = commandData['name']?.toString() ?? '';
        final localDescription = commandData['description']?.toString() ?? '';
        // The command is incomplete only when the full `data` block is absent.
        // If the data block exists, the command can be edited locally offline.
        final hasFullLocalData = data != null;
        if (!mounted) return;
        setState(() {
          if (localName.isNotEmpty) {
            _commandName = localName;
          }
          if (localDescription.isNotEmpty) {
            _commandDescription = localDescription;
          }
          final localType = _commandTypeFromText(
            (commandData['type'] ?? '').toString(),
          );
          if (localType != null) {
            _commandType = localType;
          }
          _isLoading = false;
          _isDataIncomplete = !hasFullLocalData;
        });
        return;
      }

      final currentCommand = command;
      if (!mounted) return;
      setState(() {
        _commandName = currentCommand.name;
        _commandDescription = currentCommand.description;
        _commandType = currentCommand.type;
        final storedOptions =
            data is Map
                ? Map<String, dynamic>.from(
                  data.cast<String, dynamic>(),
                )['options']
                : null;
        if (storedOptions is List) {
          _options = deserializeCommandOptions(storedOptions);
        } else if (currentCommand.options != null) {
          _options = currentCommand.options!
              .map(_buildOptionFromApplicationOption)
              .toList(growable: false);
        } else {
          _options = [];
        }
        _integrationTypes =
            currentCommand.integrationTypes.map((e) {
              if (e == ApplicationIntegrationType.guildInstall) {
                return ApplicationIntegrationType.guildInstall;
              } else if (e == ApplicationIntegrationType.userInstall) {
                return ApplicationIntegrationType.userInstall;
              } else {
                return ApplicationIntegrationType.guildInstall;
              }
            }).toList();
        _contexts = [];
        if (currentCommand.contexts != null) {
          _contexts = currentCommand.contexts!.toList();
        } else {
          // legacy defaults to guild
          _contexts = [InteractionContextType.guild];
        }
        if (_defaultMemberPermissions.isEmpty &&
            currentCommand.defaultMemberPermissions != null) {
          _defaultMemberPermissions =
              currentCommand.defaultMemberPermissions!.value.toString();
        }
        if (!_supportsSimpleMode) {
          _editorMode = _editorModeAdvanced;
          _simpleModeLocked = true;
        }
        if (_containsHierarchyOption(_options)) {
          _editorMode = _editorModeAdvanced;
          _simpleModeLocked = true;
        }
        _syncSubcommandWorkflowRoutes();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrCreate() async {
    // check if any field is empty
    if (_commandName.isEmpty ||
        (_supportsCommandDescription && _commandDescription.isEmpty)) {
      final dialog = AlertDialog(
        title: Text(AppStrings.t('error')),
        content: Text(AppStrings.t('cmd_error_fill_fields')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(AppStrings.t('ok')),
          ),
        ],
      );
      showDialog(context: context, builder: (context) => dialog);
      return;
    }

    final simpleValidationError =
        _isSimpleMode
            ? validateSimpleModeConfig(
              _simpleModeConfig,
              translate: AppStrings.t,
            )
            : null;
    if (simpleValidationError != null) {
      final dialog = AlertDialog(
        title: Text(AppStrings.t('error')),
        content: Text(simpleValidationError),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(AppStrings.t('ok')),
          ),
        ],
      );
      showDialog(context: context, builder: (context) => dialog);
      return;
    }

    _persistActiveSubcommandWorkflow();

    final effectiveOptions = _effectiveOptions;
    final effectiveActions = _effectiveActions;

    final commandData = _buildCommandDataPayload(
      effectiveActions: effectiveActions,
    );

    final client = widget.client;
    final botId = _botIdForConfig;
    if (botId == null) {
      final dialog = AlertDialog(
        title: const Text('Error'),
        content: const Text('Missing bot id for local command save.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      );
      showDialog(context: context, builder: (context) => dialog);
      return;
    }

    Future<void> saveLocal(String commandId) async {
      final localPayload = <String, dynamic>{
        'name': _commandName,
        'description': _effectiveCommandDescription,
        'type': _commandTypeToText(_commandType),
        'id': commandId,
        'updatedAt': DateTime.now().toIso8601String(),
        'data': commandData,
      };
      if (widget.id.isZero) {
        localPayload['createdAt'] = DateTime.now().toIso8601String();
      }
      await appManager.saveAppCommand(botId, commandId, localPayload);
    }

    if (client == null) {
      final localCommandId =
          widget.id.isZero
              ? DateTime.now().microsecondsSinceEpoch.toString()
              : widget.id.toString();
      await saveLocal(localCommandId);
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      return;
    }

    try {
      if (widget.id.isZero) {
        // Create a new command
        final ApplicationCommandBuilder commandBuilder;
        if (_commandType == ApplicationCommandType.user) {
          commandBuilder = ApplicationCommandBuilder.user(name: _commandName);
        } else if (_commandType == ApplicationCommandType.message) {
          commandBuilder = ApplicationCommandBuilder.message(
            name: _commandName,
          );
        } else {
          commandBuilder = ApplicationCommandBuilder.chatInput(
            name: _commandName,
            description: _commandDescription,
            options: effectiveOptions,
          );
        }

        final parsedPermissions = _parseDefaultMemberPermissions(
          _defaultMemberPermissions,
        );
        commandBuilder.defaultMemberPermissions = parsedPermissions;

        commandBuilder.integrationTypes = _integrationTypes;
        if (_contexts.isNotEmpty) {
          commandBuilder.contexts = _contexts;
        }
        await createCommand(client, commandBuilder, data: commandData);
      } else {
        // Update the existing command
        final ApplicationCommandUpdateBuilder commandBuilder;
        if (_commandType == ApplicationCommandType.user) {
          commandBuilder = ApplicationCommandUpdateBuilder.user(
            name: _commandName,
          );
        } else if (_commandType == ApplicationCommandType.message) {
          commandBuilder = ApplicationCommandUpdateBuilder.message(
            name: _commandName,
          );
        } else {
          commandBuilder = ApplicationCommandUpdateBuilder.chatInput(
            name: _commandName,
            description: _commandDescription,
          );
        }
        final parsedPermissions = _parseDefaultMemberPermissions(
          _defaultMemberPermissions,
        );
        commandBuilder.defaultMemberPermissions = parsedPermissions;
        commandBuilder.integrationTypes = _integrationTypes;
        if (_contexts.isNotEmpty) {
          commandBuilder.contexts = _contexts;
        } else {
          commandBuilder.contexts = [];
        }
        if (_commandType == ApplicationCommandType.chatInput) {
          if (effectiveOptions.isNotEmpty) {
            commandBuilder.options = effectiveOptions;
          } else {
            commandBuilder.options = [];
          }
        }

        await updateCommand(
          client,
          widget.id,
          commandBuilder: commandBuilder,
          data: commandData,
        );
      }
      Navigator.pop(context);
    } catch (e) {
      final localCommandId =
          widget.id.isZero
              ? DateTime.now().microsecondsSinceEpoch.toString()
              : widget.id.toString();
      await saveLocal(localCommandId);
      final errorText = 'Saved locally. Discord sync failed: $e';
      final dialog = AlertDialog(
        title: const Text("Error"),
        content: Text(errorText),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("OK"),
          ),
        ],
      );
      showDialog(context: context, builder: (context) => dialog);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        actions: [
          IconButton(
            tooltip: 'Import command payload',
            onPressed: _importCommandPayload,
            icon: const Icon(Icons.content_paste_go_outlined),
          ),
          IconButton(
            tooltip: 'Export command payload',
            onPressed: _showCommandExportOptions,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            onPressed: _openDocumentationCenter,
            tooltip: AppStrings.t('cmd_show_variables'),
            icon: const Icon(Icons.info_outline),
          ),
          if (widget.id.isZero && !_isDataIncomplete)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: AppStrings.t('cmd_create_tooltip'),
              onPressed: () {
                if (_validateCommandInputs()) {
                  _updateOrCreate();
                }
              },
            ),
          if (!_isDataIncomplete)
            IconButton(
              icon: Icon(widget.id.isZero ? Icons.cancel : Icons.save),
              tooltip:
                  widget.id.isZero
                      ? AppStrings.t('cancel')
                      : AppStrings.t('cmd_create_tooltip'),
              onPressed: () async {
                if (widget.id.isZero) {
                  Navigator.pop(context);
                } else {
                  if (_validateCommandInputs()) {
                    _updateOrCreate();
                    AppAnalytics.logEvent(
                      name: "update_command",
                      parameters: {
                        "command_name": _commandName,
                        "command_id": widget.id.toString(),
                      },
                    );
                  }
                }
              },
            ),
          if (!widget.id.isZero)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: AppStrings.t('cmd_delete_tooltip'),
              onPressed: () async {
                final botId = _botIdForConfig;
                if (botId == null) {
                  return;
                }

                final remoteClient = widget.client;
                if (remoteClient != null) {
                  try {
                    await remoteClient.commands.delete(widget.id);
                  } catch (e) {
                    final message = e.toString();
                    final alreadyDeleted =
                        message.contains('10063') ||
                        message.contains('Unknown application command') ||
                        message.contains('404');
                    if (!alreadyDeleted) {
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Discord delete failed. Local delete applied. $e',
                          ),
                        ),
                      );
                    }
                  }
                }

                await appManager.deleteAppCommand(botId, widget.id.toString());
                if (!mounted) {
                  return;
                }
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentMaxWidth =
              constraints.maxWidth >= 1200
                  ? 980.0
                  : (constraints.maxWidth >= 900 ? 860.0 : 680.0);

          return Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      widget.id.isZero
                          ? "Create a new command"
                          : "Update command",
                      style: const TextStyle(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else if (_isDataIncomplete) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppStrings.t('cmd_offline_incomplete_warning'),
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.terminal),
                          title: Text(
                            _commandName.isNotEmpty
                                ? _commandName
                                : widget.id.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle:
                              _commandDescription.isNotEmpty
                                  ? Text(_commandDescription)
                                  : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.menu_book_outlined),
                            tooltip: AppStrings.t('cmd_show_variables'),
                            onPressed: _openDocumentationCenter,
                          ),
                        ),
                      ),
                    ] else
                      Form(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BasicInfoCard(
                              commandName: _commandName,
                              commandDescription: _commandDescription,
                              commandType: _commandType,
                              canEditCommandType: widget.id.isZero,
                              showDescriptionField: _supportsCommandDescription,
                              integrationTypes: _integrationTypes,
                              contexts: _contexts,
                              onNameChanged: (val) {
                                setState(() {
                                  _commandName = val;
                                });
                              },
                              onDescriptionChanged: (val) {
                                setState(() {
                                  _commandDescription = val;
                                });
                              },
                              onCommandTypeChanged: (val) {
                                setState(() {
                                  _persistActiveSubcommandWorkflow();
                                  _commandType = val;
                                  if (!_supportsSimpleMode) {
                                    _editorMode = _editorModeAdvanced;
                                  }
                                  _simpleModeLocked =
                                      _editorMode == _editorModeAdvanced;
                                  if (_commandType !=
                                      ApplicationCommandType.chatInput) {
                                    _subcommandWorkflows =
                                        <String, Map<String, dynamic>>{};
                                    _activeSubcommandRoute = _rootWorkflowRoute;
                                  } else {
                                    _syncSubcommandWorkflowRoutes();
                                  }
                                });
                              },
                              onIntegrationTypesChanged: (val) {
                                setState(() {
                                  _integrationTypes = val;
                                });
                              },
                              onContextsChanged: (val) {
                                setState(() {
                                  _contexts = val;
                                });
                              },
                              onDefaultMemberPermissionsChanged: (value) {
                                setState(() {
                                  _defaultMemberPermissions = value;
                                });
                              },
                              defaultMemberPermissions:
                                  _defaultMemberPermissions,
                              nameValidator: _validateName,
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _openDocumentationCenter,
                                icon: const Icon(Icons.menu_book_outlined),
                                label: Text(AppStrings.t('cmd_show_variables')),
                              ),
                            ),
                            if (_supportsSimpleMode) ...[
                              _buildEditorModeCard(context),
                              const SizedBox(height: 12),
                            ],
                            if (_isSimpleMode) ...[
                              _buildSimpleActionsCard(),
                              const SizedBox(height: 12),
                              _buildSimpleResponseCard(),
                            ] else ...[
                              if (_subcommandWorkflows.isNotEmpty) ...[
                                _buildSubcommandWorkflowSelectorCard(),
                                const SizedBox(height: 12),
                              ],
                              ReplyCard(
                                responseType: _responseType,
                                onResponseTypeChanged: (type) {
                                  setState(() {
                                    _responseType = type;
                                    _persistActiveSubcommandWorkflow();
                                  });
                                },
                                responseController: _responseController,
                                variableSuggestionBar:
                                    _buildVariableSuggestionBar(
                                      _responseController,
                                    ),
                                responseEmbeds: _responseEmbeds,
                                onEmbedsChanged: (embeds) {
                                  setState(() {
                                    _responseEmbeds = embeds;
                                    _persistActiveSubcommandWorkflow();
                                  });
                                },
                                responseComponents: _responseComponents,
                                onComponentsChanged: (components) {
                                  setState(() {
                                    _responseComponents = components;
                                    _persistActiveSubcommandWorkflow();
                                  });
                                },
                                responseModal: _responseModal,
                                onModalChanged: (modal) {
                                  setState(() {
                                    _responseModal = modal;
                                    _persistActiveSubcommandWorkflow();
                                  });
                                },
                                responseWorkflow: _responseWorkflow,
                                normalizeWorkflow: _normalizeWorkflow,
                                variableSuggestions: _actionVariableSuggestions,
                                emojiSuggestions: _appEmojis,
                                botIdForConfig: _botIdForConfig,
                                onWorkflowChanged: (workflow) {
                                  setState(() {
                                    _responseWorkflow = workflow;
                                    _persistActiveSubcommandWorkflow();
                                  });
                                },
                                workflowSummary: _workflowSummary(),
                                activeRouteLabel:
                                    _subcommandWorkflows.isNotEmpty
                                        ? _workflowRouteLabel(
                                          _activeSubcommandRoute,
                                        )
                                        : null,
                                activeRouteIsGrouped:
                                    _subcommandWorkflows.isNotEmpty &&
                                    _activeSubcommandRoute.contains('/'),
                              ),
                              if (_supportsCommandOptions) ...[
                                const SizedBox(height: 16),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'Command Options',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Slash-command parameters',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        OptionWidget(
                                          initialOptions: _options,
                                          onChange: (options) {
                                            setState(() {
                                              _applyOptionsUpdate(options);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              ActionsCard(
                                actions: _actions,
                                onActionsChanged: (val) {
                                  setState(() {
                                    _actions = val;
                                    _persistActiveSubcommandWorkflow();
                                  });
                                },
                                actionVariableSuggestions:
                                    _actionVariableSuggestions,
                                emojiSuggestions: _appEmojis,
                                botIdForConfig: _botIdForConfig,
                                activeRouteLabel:
                                    _subcommandWorkflows.isNotEmpty
                                        ? _workflowRouteLabel(
                                          _activeSubcommandRoute,
                                        )
                                        : null,
                                activeRouteIsGrouped:
                                    _subcommandWorkflows.isNotEmpty &&
                                    _activeSubcommandRoute.contains('/'),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
