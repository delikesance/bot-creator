part of 'command.create.dart';

extension _CommandCreateSimpleMode on _CommandCreatePageState {
  SimpleModeConfig get _simpleModeConfig => SimpleModeConfig(
    deleteMessages: _simpleDeleteMessages,
    kickUser: _simpleKickUser,
    banUser: _simpleBanUser,
    unbanUser: _simpleUnbanUser,
    muteUser: _simpleMuteUser,
    unmuteUser: _simpleUnmuteUser,
    addRole: _simpleAddRole,
    removeRole: _simpleRemoveRole,
    sendMessage: _simpleSendMessage,
    pinMessage: _simplePinMessage,
    unpinMessage: _simpleUnpinMessage,
    createInvite: _simpleCreateInvite,
    createPoll: _simpleCreatePoll,
    sendMessageText: _simpleSendMessageController.text,
    actionReason: _simpleActionReasonController.text,
    muteDuration: _simpleMuteDurationController.text,
    banDeleteMessageDays: _simpleBanDeleteDaysController.text,
    deleteMessagesDefaultCount: _simpleDeleteMessagesDefaultCountController.text,
    inviteMaxAge: _simpleInviteMaxAgeController.text,
    inviteMaxUses: _simpleInviteMaxUsesController.text,
    inviteTemporary: _simpleInviteTemporary,
    inviteUnique: _simpleInviteUnique,
    pollAnswersText: _simplePollAnswersController.text,
    pollDurationHours: _simplePollDurationHoursController.text,
    pollAllowMultiselect: _simplePollAllowMultiselect,
  );

  Map<String, dynamic> _normalizeSimpleConfig(Map<String, dynamic> input) {
    return normalizeSimpleModeConfigMap(input);
  }

  void _applySimpleConfig(Map<String, dynamic> config) {
    final normalized = SimpleModeConfig.fromJson(_normalizeSimpleConfig(config));
    _simpleDeleteMessages = normalized.deleteMessages;
    _simpleKickUser = normalized.kickUser;
    _simpleBanUser = normalized.banUser;
    _simpleUnbanUser = normalized.unbanUser;
    _simpleMuteUser = normalized.muteUser;
    _simpleUnmuteUser = normalized.unmuteUser;
    _simpleAddRole = normalized.addRole;
    _simpleRemoveRole = normalized.removeRole;
    _simpleSendMessage = normalized.sendMessage;
    _simplePinMessage = normalized.pinMessage;
    _simpleUnpinMessage = normalized.unpinMessage;
    _simpleCreateInvite = normalized.createInvite;
    _simpleCreatePoll = normalized.createPoll;
    _simpleSendMessageController.text = normalized.sendMessageText;
    _simpleActionReasonController.text = normalized.actionReason;
    _simpleMuteDurationController.text = normalized.muteDuration;
    _simpleBanDeleteDaysController.text = normalized.banDeleteMessageDays;
    _simpleDeleteMessagesDefaultCountController.text =
        normalized.deleteMessagesDefaultCount;
    _simpleInviteMaxAgeController.text = normalized.inviteMaxAge;
    _simpleInviteMaxUsesController.text = normalized.inviteMaxUses;
    _simpleInviteTemporary = normalized.inviteTemporary;
    _simpleInviteUnique = normalized.inviteUnique;
    _simplePollAnswersController.text = normalized.pollAnswersText;
    _simplePollDurationHoursController.text = normalized.pollDurationHours;
    _simplePollAllowMultiselect = normalized.pollAllowMultiselect;
  }

  Map<String, dynamic> _currentSimpleConfig() {
    return _simpleModeConfig.toJson();
  }

  List<CommandOptionBuilder> _buildSimpleModeOptions() {
    return buildSimpleModeOptions(_simpleModeConfig, translate: AppStrings.t);
  }

  List<Map<String, dynamic>> _buildSimpleModeActions() {
    return buildSimpleModeActions(_simpleModeConfig);
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

  Widget _buildSimpleActionSection({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildSimpleActionsCard() {
    final config = _simpleModeConfig;
    final generatedOptionLabels = buildSimpleModeGeneratedOptionLabels(
      config,
      translate: AppStrings.t,
    );

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
            _buildSimpleActionSection(
              title: AppStrings.t('cmd_simple_group_moderation_title'),
              description: AppStrings.t('cmd_simple_group_moderation_desc'),
              children: [
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
                  value: _simpleUnbanUser,
                  title: AppStrings.t('cmd_simple_action_unban'),
                  subtitle: AppStrings.t('cmd_simple_action_unban_desc'),
                  onChanged: (value) {
                    _applyStateUpdate(() {
                      _simpleUnbanUser = value;
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
                  value: _simpleUnmuteUser,
                  title: AppStrings.t('cmd_simple_action_unmute'),
                  subtitle: AppStrings.t('cmd_simple_action_unmute_desc'),
                  onChanged: (value) {
                    _applyStateUpdate(() {
                      _simpleUnmuteUser = value;
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
              ],
            ),
            const SizedBox(height: 12),
            _buildSimpleActionSection(
              title: AppStrings.t('cmd_simple_group_messages_title'),
              description: AppStrings.t('cmd_simple_group_messages_desc'),
              children: [
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
                _buildSimpleActionToggle(
                  value: _simplePinMessage,
                  title: AppStrings.t('cmd_simple_action_pin'),
                  subtitle: AppStrings.t('cmd_simple_action_pin_desc'),
                  onChanged: (value) {
                    _applyStateUpdate(() {
                      _simplePinMessage = value;
                    });
                  },
                ),
                _buildSimpleActionToggle(
                  value: _simpleUnpinMessage,
                  title: AppStrings.t('cmd_simple_action_unpin'),
                  subtitle: AppStrings.t('cmd_simple_action_unpin_desc'),
                  onChanged: (value) {
                    _applyStateUpdate(() {
                      _simpleUnpinMessage = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSimpleActionSection(
              title: AppStrings.t('cmd_simple_group_utility_title'),
              description: AppStrings.t('cmd_simple_group_utility_desc'),
              children: [
                _buildSimpleActionToggle(
                  value: _simpleCreateInvite,
                  title: AppStrings.t('cmd_simple_action_create_invite'),
                  subtitle: AppStrings.t('cmd_simple_action_create_invite_desc'),
                  onChanged: (value) {
                    _applyStateUpdate(() {
                      _simpleCreateInvite = value;
                    });
                  },
                ),
                _buildSimpleActionToggle(
                  value: _simpleCreatePoll,
                  title: AppStrings.t('cmd_simple_action_create_poll'),
                  subtitle: AppStrings.t('cmd_simple_action_create_poll_desc'),
                  onChanged: (value) {
                    _applyStateUpdate(() {
                      _simpleCreatePoll = value;
                    });
                  },
                ),
              ],
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
            if (config.hasAuditReasonAction) ...[
              const SizedBox(height: 12),
              Text(
                AppStrings.t('cmd_simple_execution_title'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.t('cmd_simple_execution_desc'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _simpleActionReasonController,
                decoration: InputDecoration(
                  labelText: AppStrings.t('cmd_simple_action_reason_label'),
                  hintText: AppStrings.t('cmd_simple_action_reason_hint'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (mounted) {
                    _applyStateUpdate(() {});
                  }
                },
              ),
            ],
            if (config.deleteMessages) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _simpleDeleteMessagesDefaultCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppStrings.t(
                    'cmd_simple_action_delete_default_count_label',
                  ),
                  hintText: AppStrings.t(
                    'cmd_simple_action_delete_default_count_hint',
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (mounted) {
                    _applyStateUpdate(() {});
                  }
                },
              ),
            ],
            if (config.banUser) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _simpleBanDeleteDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppStrings.t(
                    'cmd_simple_action_ban_delete_days_label',
                  ),
                  hintText: AppStrings.t(
                    'cmd_simple_action_ban_delete_days_hint',
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (mounted) {
                    _applyStateUpdate(() {});
                  }
                },
              ),
            ],
            if (config.muteUser) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _simpleMuteDurationController,
                decoration: InputDecoration(
                  labelText: AppStrings.t(
                    'cmd_simple_action_mute_duration_label',
                  ),
                  hintText: AppStrings.t(
                    'cmd_simple_action_mute_duration_hint',
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (mounted) {
                    _applyStateUpdate(() {});
                  }
                },
              ),
            ],
            if (config.createInvite) ...[
              const SizedBox(height: 12),
              Text(
                AppStrings.t('cmd_simple_invite_settings_title'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.t('cmd_simple_invite_settings_desc'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _simpleInviteMaxAgeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppStrings.t(
                          'cmd_simple_invite_max_age_label',
                        ),
                        hintText: AppStrings.t(
                          'cmd_simple_invite_max_age_hint',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (mounted) {
                          _applyStateUpdate(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _simpleInviteMaxUsesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppStrings.t(
                          'cmd_simple_invite_max_uses_label',
                        ),
                        hintText: AppStrings.t(
                          'cmd_simple_invite_max_uses_hint',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (mounted) {
                          _applyStateUpdate(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppStrings.t('cmd_simple_invite_temporary_label')),
                subtitle: Text(
                  AppStrings.t('cmd_simple_invite_temporary_desc'),
                ),
                value: _simpleInviteTemporary,
                onChanged: (value) {
                  _applyStateUpdate(() {
                    _simpleInviteTemporary = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppStrings.t('cmd_simple_invite_unique_label')),
                subtitle: Text(AppStrings.t('cmd_simple_invite_unique_desc')),
                value: _simpleInviteUnique,
                onChanged: (value) {
                  _applyStateUpdate(() {
                    _simpleInviteUnique = value;
                  });
                },
              ),
            ],
            if (config.createPoll) ...[
              const SizedBox(height: 12),
              Text(
                AppStrings.t('cmd_simple_poll_settings_title'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.t('cmd_simple_poll_settings_desc'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _simplePollAnswersController,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: AppStrings.t('cmd_simple_poll_answers_label'),
                  hintText: AppStrings.t('cmd_simple_poll_answers_hint'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (mounted) {
                    _applyStateUpdate(() {});
                  }
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _simplePollDurationHoursController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppStrings.t('cmd_simple_poll_duration_label'),
                  hintText: AppStrings.t('cmd_simple_poll_duration_hint'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (mounted) {
                    _applyStateUpdate(() {});
                  }
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppStrings.t('cmd_simple_poll_multiselect_label')),
                subtitle: Text(
                  AppStrings.t('cmd_simple_poll_multiselect_desc'),
                ),
                value: _simplePollAllowMultiselect,
                onChanged: (value) {
                  _applyStateUpdate(() {
                    _simplePollAllowMultiselect = value;
                  });
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
            DropdownButtonFormField<String>(
              initialValue: _responseType,
              decoration: InputDecoration(
                labelText: AppStrings.t('cmd_simple_response_visibility_label'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'normal',
                  child: Text(
                    AppStrings.t('cmd_simple_response_visibility_public'),
                  ),
                ),
                DropdownMenuItem(
                  value: 'ephemeral',
                  child: Text(
                    AppStrings.t('cmd_simple_response_visibility_ephemeral'),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _applyStateUpdate(() {
                  _responseType = value;
                });
              },
            ),
            const SizedBox(height: 8),
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
