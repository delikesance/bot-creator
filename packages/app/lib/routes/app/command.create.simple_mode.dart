part of 'command.create.dart';

extension _CommandCreateSimpleMode on _CommandCreatePageState {
  Map<String, dynamic> _normalizeSimpleConfig(Map<String, dynamic> input) {
    return {
      'deleteMessages': input['deleteMessages'] == true,
      'kickUser': input['kickUser'] == true,
      'banUser': input['banUser'] == true,
      'muteUser': input['muteUser'] == true,
      'addRole': input['addRole'] == true,
      'removeRole': input['removeRole'] == true,
      'sendMessage': input['sendMessage'] == true,
      'sendMessageText': (input['sendMessageText'] ?? '').toString(),
    };
  }

  void _applySimpleConfig(Map<String, dynamic> config) {
    final normalized = _normalizeSimpleConfig(config);
    _simpleDeleteMessages = normalized['deleteMessages'] == true;
    _simpleKickUser = normalized['kickUser'] == true;
    _simpleBanUser = normalized['banUser'] == true;
    _simpleMuteUser = normalized['muteUser'] == true;
    _simpleAddRole = normalized['addRole'] == true;
    _simpleRemoveRole = normalized['removeRole'] == true;
    _simpleSendMessage = normalized['sendMessage'] == true;
    _simpleSendMessageController.text =
        (normalized['sendMessageText'] ?? '').toString();
  }

  Map<String, dynamic> _currentSimpleConfig() {
    return _normalizeSimpleConfig({
      'deleteMessages': _simpleDeleteMessages,
      'kickUser': _simpleKickUser,
      'banUser': _simpleBanUser,
      'muteUser': _simpleMuteUser,
      'addRole': _simpleAddRole,
      'removeRole': _simpleRemoveRole,
      'sendMessage': _simpleSendMessage,
      'sendMessageText': _simpleSendMessageController.text,
    });
  }

  List<CommandOptionBuilder> _buildSimpleModeOptions() {
    final options = <CommandOptionBuilder>[];

    if (_requiresSimpleUserOption) {
      options.add(
        CommandOptionBuilder(
          type: CommandOptionType.user,
          name: 'user',
          description: AppStrings.t('cmd_simple_option_user_desc'),
          isRequired: true,
        ),
      );
    }

    if (_requiresSimpleRoleOption) {
      options.add(
        CommandOptionBuilder(
          type: CommandOptionType.role,
          name: 'role',
          description: AppStrings.t('cmd_simple_option_role_desc'),
          isRequired: true,
        ),
      );
    }

    if (_simpleDeleteMessages) {
      options.add(
        CommandOptionBuilder(
          type: CommandOptionType.integer,
          name: 'count',
          description: AppStrings.t('cmd_simple_option_count_desc'),
          isRequired: false,
          minValue: 1,
          maxValue: 100,
        ),
      );
    }

    return options;
  }

  List<Map<String, dynamic>> _buildSimpleModeActions() {
    final actions = <Map<String, dynamic>>[];

    Map<String, dynamic> makeAction({
      required String key,
      required String type,
      required Map<String, dynamic> payload,
    }) {
      return {
        'id': key,
        'type': type,
        'enabled': true,
        'key': key,
        'depend_on': <String>[],
        'error': {'mode': 'stop'},
        'payload': payload,
      };
    }

    if (_simpleDeleteMessages) {
      actions.add(
        makeAction(
          key: 'delete_messages',
          type: 'deleteMessages',
          payload: {'channelId': '', 'messageCount': '((opts.count | 1))'},
        ),
      );
    }

    if (_simpleKickUser) {
      actions.add(
        makeAction(
          key: 'kick_user',
          type: 'kickUser',
          payload: {'userId': '((opts.user.id))', 'reason': ''},
        ),
      );
    }

    if (_simpleBanUser) {
      actions.add(
        makeAction(
          key: 'ban_user',
          type: 'banUser',
          payload: {
            'userId': '((opts.user.id))',
            'reason': '',
            'deleteMessageDays': 0,
          },
        ),
      );
    }

    if (_simpleMuteUser) {
      actions.add(
        makeAction(
          key: 'mute_user',
          type: 'muteUser',
          payload: {
            'userId': '((opts.user.id))',
            'duration': '10m',
            'reason': '',
          },
        ),
      );
    }

    if (_simpleAddRole) {
      actions.add(
        makeAction(
          key: 'add_role',
          type: 'addRole',
          payload: {
            'userId': '((opts.user.id))',
            'roleId': '((opts.role.id))',
            'reason': '',
          },
        ),
      );
    }

    if (_simpleRemoveRole) {
      actions.add(
        makeAction(
          key: 'remove_role',
          type: 'removeRole',
          payload: {
            'userId': '((opts.user.id))',
            'roleId': '((opts.role.id))',
            'reason': '',
          },
        ),
      );
    }

    if (_simpleSendMessage) {
      actions.add(
        makeAction(
          key: 'send_message',
          type: 'sendMessage',
          payload: {
            'channelId': '',
            'content': _simpleSendMessageController.text.trim(),
          },
        ),
      );
    }

    return actions;
  }

  Future<void> _switchToAdvancedMode() async {
    if (_simpleModeLocked || !_isSimpleMode) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(AppStrings.t('cmd_editor_mode_switch_adv_title')),
                content: Text(
                  AppStrings.t('cmd_editor_mode_switch_adv_content'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(AppStrings.t('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      AppStrings.t('cmd_editor_mode_switch_adv_confirm'),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    _applyStateUpdate(() {
      _editorMode = _CommandCreatePageState._editorModeAdvanced;
      _simpleModeLocked = true;
    });
  }

  Widget _buildSimpleActionToggle({
    required bool value,
    required String title,
    required String subtitle,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      onChanged: (next) => onChanged(next == true),
    );
  }

  Widget _buildEditorModeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t('cmd_editor_mode_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _isSimpleMode
                  ? AppStrings.t('cmd_editor_mode_simple_desc')
                  : AppStrings.t('cmd_editor_mode_advanced_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSimpleMode ? Icons.auto_awesome : Icons.tune,
                    color:
                        _isSimpleMode
                            ? const Color.fromRGBO(106, 15, 162, 1)
                            : Colors.blueGrey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isSimpleMode
                          ? AppStrings.t('cmd_editor_mode_simple')
                          : AppStrings.t('cmd_editor_mode_advanced'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSimpleMode) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _simpleModeLocked ? null : _switchToAdvancedMode,
                icon: const Icon(Icons.upgrade),
                label: Text(AppStrings.t('cmd_editor_mode_switch_adv')),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                AppStrings.t('cmd_editor_mode_locked'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleActionsCard() {
    final generatedOptionLabels = <String>[];
    if (_requiresSimpleUserOption) {
      generatedOptionLabels.add(AppStrings.t('cmd_simple_option_user'));
    }
    if (_requiresSimpleRoleOption) {
      generatedOptionLabels.add(AppStrings.t('cmd_simple_option_role'));
    }
    if (_simpleDeleteMessages) {
      generatedOptionLabels.add(AppStrings.t('cmd_simple_option_count'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t('cmd_simple_actions_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t('cmd_simple_actions_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _buildSimpleActionToggle(
              value: _simpleDeleteMessages,
              title: AppStrings.t('cmd_simple_action_delete'),
              subtitle: AppStrings.t('cmd_simple_action_delete_desc'),
              onChanged: (value) {
                _applyStateUpdate(() {
                  _simpleDeleteMessages = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleKickUser,
              title: AppStrings.t('cmd_simple_action_kick'),
              subtitle: AppStrings.t('cmd_simple_action_kick_desc'),
              onChanged: (value) {
                _applyStateUpdate(() {
                  _simpleKickUser = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleBanUser,
              title: AppStrings.t('cmd_simple_action_ban'),
              subtitle: AppStrings.t('cmd_simple_action_ban_desc'),
              onChanged: (value) {
                _applyStateUpdate(() {
                  _simpleBanUser = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleMuteUser,
              title: AppStrings.t('cmd_simple_action_mute'),
              subtitle: AppStrings.t('cmd_simple_action_mute_desc'),
              onChanged: (value) {
                _applyStateUpdate(() {
                  _simpleMuteUser = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleAddRole,
              title: AppStrings.t('cmd_simple_action_add_role'),
              subtitle: AppStrings.t('cmd_simple_action_add_role_desc'),
              onChanged: (value) {
                _applyStateUpdate(() {
                  _simpleAddRole = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleRemoveRole,
              title: AppStrings.t('cmd_simple_action_remove_role'),
              subtitle: AppStrings.t('cmd_simple_action_remove_role_desc'),
              onChanged: (value) {
                _applyStateUpdate(() {
                  _simpleRemoveRole = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleSendMessage,
              title: AppStrings.t('cmd_simple_action_send_message'),
              subtitle: AppStrings.t('cmd_simple_action_send_message_desc'),
              onChanged: (value) {
                _applyStateUpdate(() {
                  _simpleSendMessage = value;
                });
              },
            ),
            if (_simpleSendMessage) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _simpleSendMessageController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: AppStrings.t(
                    'cmd_simple_action_send_message_label',
                  ),
                  hintText: AppStrings.t('cmd_simple_action_send_message_hint'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (mounted) {
                    _applyStateUpdate(() {});
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
            Text(
              AppStrings.t('cmd_simple_generated_options'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (generatedOptionLabels.isEmpty)
              Text(
                AppStrings.t('cmd_simple_generated_none'),
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    generatedOptionLabels
                        .map((label) => Chip(label: Text(label)))
                        .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleResponseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t('cmd_simple_response_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t('cmd_simple_response_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _responseController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: AppStrings.t('cmd_simple_response_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            _buildVariableSuggestionBar(_responseController),
            const SizedBox(height: 12),
            Text(
              AppStrings.t('cmd_simple_response_embeds_title'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t('cmd_simple_response_embeds_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ResponseEmbedsEditor(
              embeds: _responseEmbeds,
              variableSuggestions: _actionVariableSuggestions,
              onChanged: (embeds) {
                _applyStateUpdate(() {
                  _responseEmbeds = embeds;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
