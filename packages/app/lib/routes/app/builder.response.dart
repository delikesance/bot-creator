import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../types/action.dart' show BotCreatorActionType;
import '../../types/app_emoji.dart';
import 'builder/action_types.dart';
import 'builder/action_type_extension.dart';
import 'builder/action_card.dart';

export 'builder/action_types.dart';
export 'builder/action_type_extension.dart';
export 'builder/action_card.dart';

class ActionsBuilderPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialActions;
  final List<VariableSuggestion> variableSuggestions;
  final List<AppEmoji>? emojiSuggestions;
  final String? botIdForConfig;

  const ActionsBuilderPage({
    super.key,
    this.initialActions = const [],
    this.variableSuggestions = const [],
    this.emojiSuggestions,
    this.botIdForConfig,
  });

  @override
  State<ActionsBuilderPage> createState() => _ActionsBuilderPageState();
}

class _ActionsBuilderPageState extends State<ActionsBuilderPage> {
  final List<ActionItem> _actions = [];
  final Map<String, int> _fieldRefreshVersions = {};
  int _actionCounter = 0;
  String _desktopActionSearch = '';

  @override
  void initState() {
    super.initState();
    for (final action in widget.initialActions) {
      final item = ActionItem.fromJson(action);
      _actions.add(item);
      _actionCounter++;
    }
  }

  void _addAction(BotCreatorActionType type) {
    setState(() {
      _actions.add(
        ActionItem(
          id: 'action_${_actionCounter++}',
          type: type,
          parameters: Map.from(type.defaultParameters),
        ),
      );
    });
  }

  void _removeAction(String actionId) {
    setState(() {
      _actions.removeWhere((action) => action.id == actionId);
      _fieldRefreshVersions.removeWhere(
        (compositeKey, _) => compositeKey.startsWith('$actionId::'),
      );
    });
  }

  void _moveAction(int fromIndex, int toIndex) {
    if (fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= _actions.length ||
        toIndex >= _actions.length ||
        fromIndex == toIndex) {
      return;
    }

    setState(() {
      final action = _actions.removeAt(fromIndex);
      _actions.insert(toIndex, action);
    });
  }

  void _updateActionParameter(
    String actionId,
    String key,
    dynamic value, {
    bool forceFieldRefresh = false,
  }) {
    setState(() {
      final actionIndex = _actions.indexWhere(
        (action) => action.id == actionId,
      );
      if (actionIndex != -1) {
        if (key == '__enabled__') {
          _actions[actionIndex].enabled = value == true;
          return;
        }

        if (key == '__onErrorMode__') {
          _actions[actionIndex].onErrorMode =
              value == 'continue' ? 'continue' : 'stop';
          return;
        }

        _actions[actionIndex].parameters[key] = value;
        if (forceFieldRefresh) {
          final compositeKey = '$actionId::$key';
          _fieldRefreshVersions[compositeKey] =
              (_fieldRefreshVersions[compositeKey] ?? 0) + 1;
        }
      }
    });
  }

  void _saveActions() {
    for (final action in _actions) {
      for (final def in action.type.parameterDefinitions) {
        if (!def.required) {
          continue;
        }

        final value = action.parameters[def.key];
        if (value == null || (value is String && value.trim().isEmpty)) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Missing Required Field'),
                  content: Text(
                    '${action.type.displayName}: ${def.key} is required.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
          return;
        }
      }
    }

    final payload = _actions.map((action) => action.toJson()).toList();
    if (kDebugMode) {
      print('Saving actions payload: $payload');
    }
    Navigator.pop(context, payload);
  }

  String _resolvedActionResultKey(ActionItem action) {
    final raw = (action.parameters['key'] ?? action.id).toString().trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return action.type.name;
  }

  void _addSuggestionIfMissing(
    Map<String, VariableSuggestion> bucket,
    String name,
    VariableSuggestionKind kind,
  ) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    bucket.putIfAbsent(
      trimmed,
      () => VariableSuggestion(name: trimmed, kind: kind),
    );
  }

  void _addActionOutputSuggestions(
    Map<String, VariableSuggestion> bucket,
    ActionItem action,
    String resultKey,
  ) {
    final type = action.type;

    if (type == BotCreatorActionType.httpRequest) {
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.status',
        VariableSuggestionKind.numeric,
      );
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.body',
        VariableSuggestionKind.nonNumeric,
      );
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.jsonPath',
        VariableSuggestionKind.nonNumeric,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.status',
        VariableSuggestionKind.numeric,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.body',
        VariableSuggestionKind.nonNumeric,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.jsonPath',
        VariableSuggestionKind.nonNumeric,
      );
    }

    if (type == BotCreatorActionType.appendArrayElement) {
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.items',
        VariableSuggestionKind.unknown,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.items',
        VariableSuggestionKind.unknown,
      );
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.length',
        VariableSuggestionKind.numeric,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.length',
        VariableSuggestionKind.numeric,
      );
    }

    if (type == BotCreatorActionType.removeArrayElement) {
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.items',
        VariableSuggestionKind.unknown,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.items',
        VariableSuggestionKind.unknown,
      );
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.length',
        VariableSuggestionKind.numeric,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.length',
        VariableSuggestionKind.numeric,
      );
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.removed',
        VariableSuggestionKind.unknown,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.removed',
        VariableSuggestionKind.unknown,
      );
    }

    if (type == BotCreatorActionType.queryArray ||
        type == BotCreatorActionType.listScopedVariableIndex) {
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.items',
        VariableSuggestionKind.unknown,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.items',
        VariableSuggestionKind.unknown,
      );
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.count',
        VariableSuggestionKind.numeric,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.count',
        VariableSuggestionKind.numeric,
      );
      _addSuggestionIfMissing(
        bucket,
        'action.$resultKey.total',
        VariableSuggestionKind.numeric,
      );
      _addSuggestionIfMissing(
        bucket,
        '$resultKey.total',
        VariableSuggestionKind.numeric,
      );
    }
  }

  List<VariableSuggestion> _buildMergedVariableSuggestions() {
    final merged = <String, VariableSuggestion>{};
    for (final item in widget.variableSuggestions) {
      final normalizedName = item.name.trim();
      if (normalizedName.isEmpty) {
        continue;
      }
      merged.putIfAbsent(
        normalizedName,
        () => VariableSuggestion(name: normalizedName, kind: item.kind),
      );
    }

    for (final action in _actions) {
      final resultKey = _resolvedActionResultKey(action);
      _addSuggestionIfMissing(
        merged,
        resultKey,
        VariableSuggestionKind.unknown,
      );
      _addSuggestionIfMissing(
        merged,
        'action.$resultKey',
        VariableSuggestionKind.unknown,
      );
      _addActionOutputSuggestions(merged, action, resultKey);
    }

    return merged.values.toList(growable: false);
  }

  void _showAddActionDialog() {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 700;
    final availableActionTypes = BotCreatorActionType.values.toList(
      growable: false,
    );
    String searchQuery = '';

    Widget selectorContent(
      BuildContext dialogContext,
      void Function(void Function()) setDialogState,
    ) {
      final actionsByCategory = <String, List<BotCreatorActionType>>{};

      for (final actionType in availableActionTypes) {
        if (searchQuery.isNotEmpty &&
            !actionType.displayName.toLowerCase().contains(
              searchQuery.toLowerCase(),
            )) {
          continue;
        }
        final category = _getCategoryForAction(actionType);
        actionsByCategory.putIfAbsent(category, () => <BotCreatorActionType>[]);
        actionsByCategory[category]!.add(actionType);
      }

      for (final entry in actionsByCategory.entries) {
        entry.value.sort((a, b) => a.displayName.compareTo(b.displayName));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search actions...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setDialogState(() {
                searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                actionsByCategory.isEmpty
                    ? const Center(child: Text('No actions match your search.'))
                    : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...actionsByCategory.entries.map(
                            (entry) =>
                                _buildActionCategory(entry.key, entry.value),
                          ),
                        ],
                      ),
                    ),
          ),
          const SizedBox(height: 12),
          if (isMobile)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ),
        ],
      );
    }

    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          return FractionallySizedBox(
            heightFactor: 0.92,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return selectorContent(context, setDialogState);
                },
              ),
            ),
          );
        },
      );
      return;
    }

    final maxHeight = mediaQuery.size.height * 0.8;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Action'),
              content: SizedBox(
                width: 620,
                height: maxHeight,
                child: selectorContent(context, setDialogState),
              ),
            );
          },
        );
      },
    );
  }

  String _getCategoryForAction(BotCreatorActionType type) {
    switch (type) {
      case BotCreatorActionType.sendMessage:
      case BotCreatorActionType.editMessage:
      case BotCreatorActionType.deleteMessages:
      case BotCreatorActionType.pinMessage:
        return 'Messages';
      case BotCreatorActionType.addReaction:
      case BotCreatorActionType.removeReaction:
      case BotCreatorActionType.clearAllReactions:
        return 'Reactions';
      case BotCreatorActionType.createChannel:
      case BotCreatorActionType.updateChannel:
      case BotCreatorActionType.removeChannel:
        return 'Channels';
      case BotCreatorActionType.banUser:
      case BotCreatorActionType.unbanUser:
      case BotCreatorActionType.kickUser:
      case BotCreatorActionType.muteUser:
      case BotCreatorActionType.unmuteUser:
      case BotCreatorActionType.addRole:
      case BotCreatorActionType.removeRole:
        return 'Moderation';
      case BotCreatorActionType.sendComponentV2:
      case BotCreatorActionType.editComponentV2:
        return 'Components';
      case BotCreatorActionType.sendWebhook:
      case BotCreatorActionType.editWebhook:
      case BotCreatorActionType.deleteWebhook:
      case BotCreatorActionType.listWebhooks:
      case BotCreatorActionType.getWebhook:
        return 'Webhooks';
      case BotCreatorActionType.updateGuild:
      case BotCreatorActionType.updateAutoMod:
      case BotCreatorActionType.listMembers:
      case BotCreatorActionType.getMember:
        return 'Guild & Members';
      case BotCreatorActionType.httpRequest:
      case BotCreatorActionType.setGlobalVariable:
      case BotCreatorActionType.getGlobalVariable:
      case BotCreatorActionType.removeGlobalVariable:
      case BotCreatorActionType.setScopedVariable:
      case BotCreatorActionType.getScopedVariable:
      case BotCreatorActionType.removeScopedVariable:
      case BotCreatorActionType.renameScopedVariable:
      case BotCreatorActionType.listScopedVariableIndex:
      case BotCreatorActionType.appendArrayElement:
      case BotCreatorActionType.removeArrayElement:
      case BotCreatorActionType.queryArray:
        return 'HTTP & Variables';
      case BotCreatorActionType.runWorkflow:
        return 'Workflows';
      case BotCreatorActionType.stopUnless:
      case BotCreatorActionType.ifBlock:
        return 'Logic & Flow';
      // ── Interactions ──
      case BotCreatorActionType.respondWithMessage:
      case BotCreatorActionType.respondWithComponentV2:
      case BotCreatorActionType.editInteractionMessage:
        return 'Interactions';
      case BotCreatorActionType.respondWithModal:
      case BotCreatorActionType.listenForButtonClick:
      case BotCreatorActionType.listenForSelectMenu:
      case BotCreatorActionType.listenForModalSubmit:
      case BotCreatorActionType.respondWithAutocomplete:
        return 'Interactions';
      case BotCreatorActionType.calculate:
        return 'Logic & Flow';
      case BotCreatorActionType.getMessage:
      case BotCreatorActionType.unpinMessage:
      case BotCreatorActionType.createPoll:
      case BotCreatorActionType.endPoll:
        return 'Messages';
      case BotCreatorActionType.createInvite:
      case BotCreatorActionType.deleteInvite:
      case BotCreatorActionType.getInvite:
      case BotCreatorActionType.createThread:
      case BotCreatorActionType.editChannelPermissions:
      case BotCreatorActionType.deleteChannelPermission:
        return 'Channels';
      case BotCreatorActionType.moveToVoiceChannel:
      case BotCreatorActionType.disconnectFromVoice:
      case BotCreatorActionType.serverMuteMember:
      case BotCreatorActionType.serverDeafenMember:
      case BotCreatorActionType.createAutoModRule:
      case BotCreatorActionType.deleteAutoModRule:
      case BotCreatorActionType.listAutoModRules:
        return 'Moderation';
      case BotCreatorActionType.createEmoji:
      case BotCreatorActionType.updateEmoji:
      case BotCreatorActionType.deleteEmoji:
      case BotCreatorActionType.getGuildOnboarding:
      case BotCreatorActionType.updateGuildOnboarding:
      case BotCreatorActionType.updateSelfUser:
        return 'Guild & Members';
    }
  }

  Widget _buildActionCategory(
    String categoryName,
    List<BotCreatorActionType> actions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            categoryName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        ...actions.map((type) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 2),
            child: ListTile(
              dense: true,
              leading: Icon(
                type.icon,
                size: 20,
                color: _getCategoryColor(categoryName),
              ),
              title: Text(
                type.displayName,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                _getActionDescription(type),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _addAction(type);
              },
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Messages':
        return Colors.green;
      case 'Reactions':
        return Colors.orange;
      case 'Channels':
        return Colors.blue;
      case 'Moderation':
        return Colors.red;
      case 'Components':
        return Colors.purple;
      case 'Webhooks':
        return Colors.teal;
      case 'Guild & Members':
        return Colors.indigo;
      case 'Utilities':
        return Colors.brown;
      case 'HTTP & Variables':
        return Colors.cyan;
      case 'Workflows':
        return Colors.deepPurple;
      case 'Logic & Flow':
        return Colors.pink;
      case 'Interactions':
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }

  String _getActionDescription(BotCreatorActionType type) {
    switch (type) {
      case BotCreatorActionType.sendMessage:
        return 'Send a message to a channel';
      case BotCreatorActionType.editMessage:
        return 'Edit an existing message';
      case BotCreatorActionType.deleteMessages:
        return 'Delete multiple messages';
      case BotCreatorActionType.pinMessage:
        return 'Pin a message in a channel';
      case BotCreatorActionType.addReaction:
        return 'Add emoji reaction to message';
      case BotCreatorActionType.removeReaction:
        return 'Remove specific reaction';
      case BotCreatorActionType.clearAllReactions:
        return 'Clear all reactions from message';
      case BotCreatorActionType.createChannel:
        return 'Create a new channel';
      case BotCreatorActionType.updateChannel:
        return 'Update channel settings';
      case BotCreatorActionType.removeChannel:
        return 'Delete a channel';
      case BotCreatorActionType.banUser:
        return 'Ban user from server';
      case BotCreatorActionType.unbanUser:
        return 'Remove ban from user';
      case BotCreatorActionType.kickUser:
        return 'Kick user from server';
      case BotCreatorActionType.muteUser:
        return 'Temporarily mute user';
      case BotCreatorActionType.unmuteUser:
        return 'Remove mute from user';
      case BotCreatorActionType.addRole:
        return 'Add a role to a user';
      case BotCreatorActionType.removeRole:
        return 'Remove a role from a user';
      case BotCreatorActionType.sendComponentV2:
        return 'Send interactive components';
      case BotCreatorActionType.editComponentV2:
        return 'Edit existing components';
      case BotCreatorActionType.sendWebhook:
        return 'Send message via webhook';
      case BotCreatorActionType.editWebhook:
        return 'Modify webhook settings';
      case BotCreatorActionType.deleteWebhook:
        return 'Delete a webhook';
      case BotCreatorActionType.listWebhooks:
        return 'List all webhooks';
      case BotCreatorActionType.getWebhook:
        return 'Get webhook information';
      case BotCreatorActionType.updateGuild:
        return 'Update server settings';
      case BotCreatorActionType.updateAutoMod:
        return 'Configure auto-moderation';
      case BotCreatorActionType.listMembers:
        return 'List server members';
      case BotCreatorActionType.getMember:
        return 'Get member information';
      case BotCreatorActionType.httpRequest:
        return 'Send HTTP request with dynamic URL, method, headers and body';
      case BotCreatorActionType.setGlobalVariable:
        return 'Create or update a global variable for this bot';
      case BotCreatorActionType.getGlobalVariable:
        return 'Read a global variable and inject into runtime variables';
      case BotCreatorActionType.removeGlobalVariable:
        return 'Delete a global variable';
      case BotCreatorActionType.setScopedVariable:
        return 'Create or update a scoped variable (guild/user/channel/guildMember/message)';
      case BotCreatorActionType.getScopedVariable:
        return 'Read a scoped variable and inject into runtime variables';
      case BotCreatorActionType.removeScopedVariable:
        return 'Delete a scoped variable';
      case BotCreatorActionType.renameScopedVariable:
        return 'Rename a scoped variable key';
      case BotCreatorActionType.listScopedVariableIndex:
        return 'List indexed scoped values sorted by value with offset and limit';
      case BotCreatorActionType.appendArrayElement:
        return 'Append a new element into a global or scoped JSON array';
      case BotCreatorActionType.removeArrayElement:
        return 'Remove one element from a global or scoped JSON array by index';
      case BotCreatorActionType.queryArray:
        return 'Filter, sort and page any runtime JSON array';
      case BotCreatorActionType.runWorkflow:
        return 'Execute a saved workflow (supports entry point + arguments)';
      case BotCreatorActionType.respondWithMessage:
        return 'Reply to command with a normal message';
      case BotCreatorActionType.respondWithComponentV2:
        return 'Reply to command with buttons/select menus';
      case BotCreatorActionType.respondWithModal:
        return 'Show a modal dialog to the user';
      case BotCreatorActionType.editInteractionMessage:
        return 'Edit the deferred or original interaction response';
      case BotCreatorActionType.listenForButtonClick:
        return 'Register a workflow to run when a button is clicked';
      case BotCreatorActionType.listenForSelectMenu:
        return 'Register a workflow to run when a select menu is used';
      case BotCreatorActionType.listenForModalSubmit:
        return 'Register a workflow to run when a modal is submitted';
      case BotCreatorActionType.respondWithAutocomplete:
        return 'Reply to a Discord autocomplete interaction with up to 25 dynamic choices';
      case BotCreatorActionType.stopUnless:
        return 'Stop the workflow if a condition is not met (guard/filter)';
      case BotCreatorActionType.ifBlock:
        return 'Conditional branching: run different actions based on a condition';
      case BotCreatorActionType.calculate:
        return 'Perform math operations and store result';
      case BotCreatorActionType.getMessage:
        return 'Fetch a message and expose its fields';
      case BotCreatorActionType.unpinMessage:
        return 'Unpin a message in a channel';
      case BotCreatorActionType.createPoll:
        return 'Create a poll message in a channel';
      case BotCreatorActionType.endPoll:
        return 'End an active poll message immediately';
      case BotCreatorActionType.createInvite:
        return 'Create a new invite link for a channel';
      case BotCreatorActionType.deleteInvite:
        return 'Delete an existing invite by code';
      case BotCreatorActionType.getInvite:
        return 'Fetch invite information by code';
      case BotCreatorActionType.moveToVoiceChannel:
        return 'Move a member to a specific voice channel';
      case BotCreatorActionType.disconnectFromVoice:
        return 'Disconnect a member from voice';
      case BotCreatorActionType.serverMuteMember:
        return 'Server-mute or unmute a member';
      case BotCreatorActionType.serverDeafenMember:
        return 'Server-deafen or undeafen a member';
      case BotCreatorActionType.createEmoji:
        return 'Create a guild emoji from image data';
      case BotCreatorActionType.updateEmoji:
        return 'Update guild emoji name or role access';
      case BotCreatorActionType.deleteEmoji:
        return 'Delete a guild emoji';
      case BotCreatorActionType.createAutoModRule:
        return 'Create a guild auto-moderation rule';
      case BotCreatorActionType.deleteAutoModRule:
        return 'Delete an auto-moderation rule';
      case BotCreatorActionType.listAutoModRules:
        return 'List all auto-moderation rules in guild';
      case BotCreatorActionType.getGuildOnboarding:
        return 'Fetch current guild onboarding configuration';
      case BotCreatorActionType.updateGuildOnboarding:
        return 'Update guild onboarding configuration';
      case BotCreatorActionType.updateSelfUser:
        return 'Update current bot user profile (username/avatar)';
      case BotCreatorActionType.createThread:
        return 'Create a thread in a supported text channel';
      case BotCreatorActionType.editChannelPermissions:
        return 'Create or update channel permission overwrites';
      case BotCreatorActionType.deleteChannelPermission:
        return 'Delete a channel permission overwrite';
    }
  }

  Widget _buildEmptyState({required bool isDesktop}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_task, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No actions yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            isDesktop
                ? 'Choose an action from the Action Library on the left.'
                : 'Tap the + button to add your first action',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildActionList({
    required EdgeInsetsGeometry padding,
    required double maxContentWidth,
    required bool isDesktop,
  }) {
    if (_actions.isEmpty) {
      return _buildEmptyState(isDesktop: isDesktop);
    }

    final mergedVariableSuggestions = _buildMergedVariableSuggestions();

    return ListView.builder(
      padding: padding,
      itemCount: _actions.length,
      itemBuilder: (context, index) {
        final action = _actions[index];
        final computedActionKey =
            (action.parameters['key'] ?? action.id).toString().trim();

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: ActionCard(
              key: ValueKey('action-card-${action.id}-$index'),
              action: action,
              index: index,
              totalCount: _actions.length,
              actionKey:
                  computedActionKey.isNotEmpty
                      ? computedActionKey
                      : action.type.name,
              onRemove: () => _removeAction(action.id),
              onMoveUp: index > 0 ? () => _moveAction(index, index - 1) : null,
              onMoveDown:
                  index < _actions.length - 1
                      ? () => _moveAction(index, index + 1)
                      : null,
              variableSuggestions: mergedVariableSuggestions,
              emojiSuggestions: widget.emojiSuggestions,
              botIdForConfig: widget.botIdForConfig,
              fieldRefreshVersionOf:
                  (paramKey) =>
                      _fieldRefreshVersions['${action.id}::$paramKey'] ?? 0,
              onSuggestionSelected:
                  (key, value) => _updateActionParameter(
                    action.id,
                    key,
                    value,
                    forceFieldRefresh: true,
                  ),
              onParameterChanged:
                  (key, value) => _updateActionParameter(action.id, key, value),
              onEditNestedActions: (current, suggestions) async {
                return await Navigator.push<List<Map<String, dynamic>>>(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ActionsBuilderPage(
                          initialActions: current,
                          variableSuggestions: suggestions,
                          botIdForConfig: widget.botIdForConfig,
                        ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopActionLibrary() {
    final allActions = BotCreatorActionType.values.toList(growable: false);
    final filteredByCategory = <String, List<BotCreatorActionType>>{};

    for (final actionType in allActions) {
      if (_desktopActionSearch.isNotEmpty &&
          !actionType.displayName.toLowerCase().contains(
            _desktopActionSearch.toLowerCase(),
          )) {
        continue;
      }

      final category = _getCategoryForAction(actionType);
      filteredByCategory.putIfAbsent(category, () => <BotCreatorActionType>[]);
      filteredByCategory[category]!.add(actionType);
    }

    for (final entry in filteredByCategory.entries) {
      entry.value.sort((a, b) => a.displayName.compareTo(b.displayName));
    }

    final sortedEntries = filteredByCategory.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    return SafeArea(
      right: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Action Library',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add blocks to your workflow',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _desktopActionSearch = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search actions...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child:
                      sortedEntries.isEmpty
                          ? const Center(child: Text('No actions found.'))
                          : ListView(
                            children: [
                              for (final entry in sortedEntries) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _getCategoryColor(entry.key),
                                    ),
                                  ),
                                ),
                                ...entry.value.map(
                                  (type) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: OutlinedButton.icon(
                                      onPressed: () => _addAction(type),
                                      icon: Icon(type.icon, size: 18),
                                      label: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          type.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ],
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileLayout = MediaQuery.of(context).size.width < 900;

    Widget saveButton() {
      return ElevatedButton.icon(
        onPressed: _saveActions,
        icon: const Icon(Icons.save),
        label: Text('Save ${_actions.length} Actions'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    }

    Widget mobileBody() {
      return Column(
        children: [
          Expanded(
            child: _buildActionList(
              padding: const EdgeInsets.all(16),
              maxContentWidth: double.infinity,
              isDesktop: false,
            ),
          ),
          if (_actions.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(width: double.infinity, child: saveButton()),
              ),
            ),
        ],
      );
    }

    Widget desktopBody() {
      return Row(
        children: [
          SizedBox(width: 340, child: _buildDesktopActionLibrary()),
          VerticalDivider(width: 1, color: Colors.grey.shade800),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildActionList(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    maxContentWidth: 980,
                    isDesktop: true,
                  ),
                ),
                if (_actions.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: SizedBox(
                            width: double.infinity,
                            child: saveButton(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actions Builder'),
        actions: [
          IconButton(
            onPressed: _saveActions,
            icon: const Icon(Icons.save),
            tooltip: 'Save Actions',
          ),
        ],
      ),
      body: isMobileLayout ? mobileBody() : desktopBody(),
      floatingActionButton:
          isMobileLayout
              ? FloatingActionButton(
                onPressed: _showAddActionDialog,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}
