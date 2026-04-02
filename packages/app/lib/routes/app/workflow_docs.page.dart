import 'package:bot_creator/routes/app/doc_kind.dart';
import 'package:bot_creator/utils/command_variable_catalog.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:flutter/material.dart';

class _DocSection {
  const _DocSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

class _DocEntry {
  const _DocEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.sections,
    this.variables = const <String>[],
    this.example,
    this.requiresIntent = const <String>[],
  });

  final String id;
  final DocKind kind;
  final String title;
  final String subtitle;
  final String summary;
  final List<_DocSection> sections;
  final List<String> variables;
  final String? example;
  final List<String> requiresIntent;
}

class WorkflowDocumentationPage extends StatefulWidget {
  const WorkflowDocumentationPage({
    super.key,
    this.initialSearch = '',
    this.initialKind,
  });

  final String initialSearch;
  final DocKind? initialKind;

  @override
  State<WorkflowDocumentationPage> createState() =>
      _WorkflowDocumentationPageState();
}

class _WorkflowDocumentationPageState extends State<WorkflowDocumentationPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  DocKind? _kindFilter;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialSearch;
    _kindFilter = widget.initialKind;
  }

  _DocEntry _buildTemplateVariablesDoc() {
    return _DocEntry(
      id: 'template.variables',
      kind: DocKind.template,
      title: AppStrings.t('doc_template_variables_title'),
      subtitle: AppStrings.t('doc_template_variables_subtitle'),
      summary: AppStrings.t('doc_template_variables_summary'),
      variables: commandTemplateReferenceVariables,
      sections: <_DocSection>[
        _DocSection(
          title: AppStrings.t('doc_template_variables_section_sources_title'),
          lines: <String>[
            AppStrings.t('doc_template_variables_section_sources_l1'),
            AppStrings.t('doc_template_variables_section_sources_l2'),
            AppStrings.t('doc_template_variables_section_sources_l3'),
            AppStrings.t('doc_template_variables_section_sources_l4'),
            AppStrings.t('doc_template_variables_section_sources_l5'),
          ],
        ),
        _DocSection(
          title: AppStrings.t('doc_template_variables_section_builtin_title'),
          lines: commandBuiltinVariableDocumentationLines,
        ),
        _DocSection(
          title: AppStrings.t('doc_template_variables_section_types_title'),
          lines: <String>[
            AppStrings.t('doc_template_variables_section_types_l1'),
            AppStrings.t('doc_template_variables_section_types_l2'),
            AppStrings.t('doc_template_variables_section_types_l3'),
            AppStrings.t('doc_template_variables_section_types_l4'),
          ],
        ),
        _DocSection(
          title: AppStrings.t('doc_template_variables_section_fallbacks_title'),
          lines: <String>[
            AppStrings.t('doc_template_variables_section_fallbacks_l1'),
            AppStrings.t('doc_template_variables_section_fallbacks_l2'),
            AppStrings.t('doc_template_variables_section_fallbacks_l3'),
          ],
        ),
      ],
      example: AppStrings.t('doc_template_variables_example'),
    );
  }

  _DocEntry _buildTemplateFunctionsDoc() {
    return _DocEntry(
      id: 'template.functions',
      kind: DocKind.template,
      title: AppStrings.t('doc_template_functions_title'),
      subtitle: AppStrings.t('doc_template_functions_subtitle'),
      summary: AppStrings.t('doc_template_functions_summary'),
      sections: <_DocSection>[
        _DocSection(
          title: AppStrings.t('doc_template_functions_section_string_title'),
          lines: <String>[
            AppStrings.t('doc_template_functions_section_string_l1'),
            AppStrings.t('doc_template_functions_section_string_l2'),
            AppStrings.t('doc_template_functions_section_string_l3'),
            AppStrings.t('doc_template_functions_section_string_l4'),
          ],
        ),
        _DocSection(
          title: AppStrings.t('doc_template_functions_section_array_title'),
          lines: <String>[
            AppStrings.t('doc_template_functions_section_array_l1'),
            AppStrings.t('doc_template_functions_section_array_l2'),
            AppStrings.t('doc_template_functions_section_array_l3'),
            AppStrings.t('doc_template_functions_section_array_l4'),
          ],
        ),
        _DocSection(
          title: AppStrings.t('doc_template_functions_section_random_title'),
          lines: <String>[
            AppStrings.t('doc_template_functions_section_random_l1'),
            AppStrings.t('doc_template_functions_section_random_l2'),
          ],
        ),
        _DocSection(
          title: AppStrings.t('doc_template_functions_section_notes_title'),
          lines: <String>[
            AppStrings.t('doc_template_functions_section_notes_l1'),
            AppStrings.t('doc_template_functions_section_notes_l2'),
            AppStrings.t('doc_template_functions_section_notes_l3'),
            AppStrings.t('doc_template_functions_section_notes_l4'),
          ],
        ),
      ],
      example: AppStrings.t('doc_template_functions_example'),
    );
  }

  _DocEntry _buildTemplateAdvancedVariablesDoc() {
    return _DocEntry(
      id: 'template.advancedVariables',
      kind: DocKind.template,
      title: AppStrings.t('doc_template_advanced_variables_title'),
      subtitle: AppStrings.t('doc_template_advanced_variables_subtitle'),
      summary: AppStrings.t('doc_template_advanced_variables_summary'),
      variables: const <String>[
        'interaction.kind',
        'interaction.values',
        'interaction.values.count',
        'interaction.command.name',
        'interaction.command.id',
        'interaction.guildId',
        'interaction.channelId',
        'interaction.userId',
        'interaction.messageId',
        'channel.kind',
        'channel.position',
        'channel.bitrate',
        'channel.userLimit',
        'channel.categoryId',
        'channel.thread.archived',
        'channel.thread.locked',
        'channel.thread.ownerId',
        'channel.thread.autoArchiveDuration',
        'guild.kind',
        'user.id',
        'user.username',
        'user.tag',
        'user.avatar',
        'user.banner',
        'member.id',
      ],
      sections: <_DocSection>[
        _DocSection(
          title: AppStrings.t(
            'doc_template_advanced_variables_section_interaction_title',
          ),
          lines: <String>[
            AppStrings.t(
              'doc_template_advanced_variables_section_interaction_l1',
            ),
            AppStrings.t(
              'doc_template_advanced_variables_section_interaction_l2',
            ),
            AppStrings.t(
              'doc_template_advanced_variables_section_interaction_l3',
            ),
          ],
        ),
        _DocSection(
          title: AppStrings.t(
            'doc_template_advanced_variables_section_channel_guild_title',
          ),
          lines: <String>[
            AppStrings.t(
              'doc_template_advanced_variables_section_channel_guild_l1',
            ),
            AppStrings.t(
              'doc_template_advanced_variables_section_channel_guild_l2',
            ),
            AppStrings.t(
              'doc_template_advanced_variables_section_channel_guild_l3',
            ),
          ],
        ),
        _DocSection(
          title: AppStrings.t(
            'doc_template_advanced_variables_section_aliases_title',
          ),
          lines: <String>[
            AppStrings.t('doc_template_advanced_variables_section_aliases_l1'),
            AppStrings.t('doc_template_advanced_variables_section_aliases_l2'),
          ],
        ),
      ],
      example: AppStrings.t('doc_template_advanced_variables_example'),
    );
  }

  _DocEntry _buildRuntimeActionOutputsDoc() {
    return _DocEntry(
      id: 'runtime.actionOutputs',
      kind: DocKind.runtime,
      title: AppStrings.t('doc_runtime_action_outputs_title'),
      subtitle: AppStrings.t('doc_runtime_action_outputs_subtitle'),
      summary: AppStrings.t('doc_runtime_action_outputs_summary'),
      variables: const <String>[
        'action.<resultKey>',
        'action.<resultKey>.status',
        'action.<resultKey>.body',
        'action.<resultKey>.jsonPath',
        'action.<resultKey>.count',
        'action.<resultKey>.mode',
        'action.<resultKey>.deleteItself',
        'action.<resultKey>.deleteResponse',
        'action.<resultKey>.items',
        'action.<resultKey>.length',
        'action.<resultKey>.removed',
        'action.<resultKey>.total',
        '<resultKey>',
        '<resultKey>.status',
        '<resultKey>.body',
        '<resultKey>.jsonPath',
        '<resultKey>.count',
        '<resultKey>.items',
        '<resultKey>.length',
        '<resultKey>.removed',
        '<resultKey>.total',
        '<resultKey>.result',
        '<resultKey>.messageId',
      ],
      sections: <_DocSection>[
        _DocSection(
          title: AppStrings.t(
            'doc_runtime_action_outputs_section_patterns_title',
          ),
          lines: <String>[
            AppStrings.t('doc_runtime_action_outputs_section_patterns_l1'),
            AppStrings.t('doc_runtime_action_outputs_section_patterns_l2'),
            AppStrings.t('doc_runtime_action_outputs_section_patterns_l3'),
          ],
        ),
        _DocSection(
          title: AppStrings.t(
            'doc_runtime_action_outputs_section_common_fields_title',
          ),
          lines: <String>[
            AppStrings.t('doc_runtime_action_outputs_section_common_fields_l1'),
            AppStrings.t('doc_runtime_action_outputs_section_common_fields_l2'),
            AppStrings.t('doc_runtime_action_outputs_section_common_fields_l3'),
            AppStrings.t('doc_runtime_action_outputs_section_common_fields_l4'),
          ],
        ),
        _DocSection(
          title: AppStrings.t(
            'doc_runtime_action_outputs_section_caveats_title',
          ),
          lines: <String>[
            AppStrings.t('doc_runtime_action_outputs_section_caveats_l1'),
            AppStrings.t('doc_runtime_action_outputs_section_caveats_l2'),
            AppStrings.t('doc_runtime_action_outputs_section_caveats_l3'),
          ],
        ),
      ],
      example: AppStrings.t('doc_runtime_action_outputs_example'),
    );
  }

  _DocEntry _buildInteractionCommandsDoc() {
    return _DocEntry(
      id: 'runtime.interactionCommands',
      kind: DocKind.runtime,
      title: AppStrings.t('doc_interaction_commands_title'),
      subtitle: AppStrings.t('doc_interaction_commands_subtitle'),
      summary: AppStrings.t('doc_interaction_commands_summary'),
      variables: interactionCommandReferenceVariables,
      sections: <_DocSection>[
        _DocSection(
          title: AppStrings.t(
            'doc_interaction_commands_section_execution_title',
          ),
          lines: <String>[
            AppStrings.t('doc_interaction_commands_section_execution_l1'),
            AppStrings.t('doc_interaction_commands_section_execution_l2'),
            AppStrings.t('doc_interaction_commands_section_execution_l3'),
          ],
        ),
        _DocSection(
          title: AppStrings.t(
            'doc_interaction_commands_section_per_type_title',
          ),
          lines: <String>[
            AppStrings.t('doc_interaction_commands_section_per_type_l1'),
            AppStrings.t('doc_interaction_commands_section_per_type_l2'),
            AppStrings.t('doc_interaction_commands_section_per_type_l3'),
          ],
        ),
        _DocSection(
          title: AppStrings.t('doc_interaction_commands_section_builtin_title'),
          lines: commandBuiltinVariableDocumentationLines,
        ),
        _DocSection(
          title: AppStrings.t(
            'doc_interaction_commands_section_guidance_title',
          ),
          lines: <String>[
            AppStrings.t('doc_interaction_commands_section_guidance_l1'),
            AppStrings.t('doc_interaction_commands_section_guidance_l2'),
            AppStrings.t('doc_interaction_commands_section_guidance_l3'),
          ],
        ),
      ],
      example: AppStrings.t('doc_interaction_commands_example'),
    );
  }

  _DocEntry _buildMessageCreateDoc() {
    return _DocEntry(
      id: 'event.messageCreate',
      kind: DocKind.event,
      title: AppStrings.t('doc_event_message_create_title'),
      subtitle: AppStrings.t('doc_event_message_create_subtitle'),
      summary: AppStrings.t('doc_event_message_create_summary'),
      requiresIntent: <String>[
        AppStrings.t('doc_event_message_create_intent_1'),
        AppStrings.t('doc_event_message_create_intent_2'),
      ],
      variables: <String>[
        'event.name',
        'timestamp',
        'actualTime',
        'guildId',
        'channelId',
        'userId',
        'message.id',
        'message.content',
        'message.content[0]',
        'message.word.count',
        'message.isBot',
        'message.type',
        'message.mentions',
        'author.id',
        'author.name',
        'author.username',
        'author.tag',
        'author.avatar',
      ],
      sections: <_DocSection>[
        _DocSection(
          title: AppStrings.t('doc_common_section_best_use_cases'),
          lines: <String>[
            AppStrings.t('doc_event_message_create_best_use_l1'),
            AppStrings.t('doc_event_message_create_best_use_l2'),
            AppStrings.t('doc_event_message_create_best_use_l3'),
          ],
        ),
        _DocSection(
          title: AppStrings.t('doc_common_section_important_notes'),
          lines: <String>[
            AppStrings.t('doc_event_message_create_notes_l1'),
            AppStrings.t('doc_event_message_create_notes_l2'),
            AppStrings.t('doc_event_message_create_notes_l3'),
          ],
        ),
      ],
      example: AppStrings.t('doc_event_message_create_example'),
    );
  }

  _DocEntry _buildRuntimeExecutionFlowDoc() {
    return _DocEntry(
      id: 'runtime.executionFlow',
      kind: DocKind.runtime,
      title: AppStrings.t('doc_runtime_execution_flow_title'),
      subtitle: AppStrings.t('doc_runtime_execution_flow_subtitle'),
      summary: AppStrings.t('doc_runtime_execution_flow_summary'),
      sections: <_DocSection>[
        _DocSection(
          title: AppStrings.t(
            'doc_runtime_execution_flow_section_pipeline_title',
          ),
          lines: <String>[
            AppStrings.t('doc_runtime_execution_flow_section_pipeline_l1'),
            AppStrings.t('doc_runtime_execution_flow_section_pipeline_l2'),
            AppStrings.t('doc_runtime_execution_flow_section_pipeline_l3'),
            AppStrings.t('doc_runtime_execution_flow_section_pipeline_l4'),
            AppStrings.t('doc_runtime_execution_flow_section_pipeline_l5'),
          ],
        ),
        _DocSection(
          title: AppStrings.t(
            'doc_runtime_execution_flow_section_parity_title',
          ),
          lines: <String>[
            AppStrings.t('doc_runtime_execution_flow_section_parity_l1'),
            AppStrings.t('doc_runtime_execution_flow_section_parity_l2'),
          ],
        ),
      ],
    );
  }

  List<_DocEntry> get _docs => <_DocEntry>[
    _buildMessageCreateDoc(),
    _DocEntry(
      id: 'event.messageReactionAdd',
      kind: DocKind.event,
      title: 'Event: messageReactionAdd',
      subtitle: 'Triggered when a user adds a reaction to a message.',
      summary:
          'Ideal for button-like UX without components, vote systems, role menus, and lightweight approvals.',
      requiresIntent: <String>['Guild Message Reactions'],
      variables: <String>[
        'event.name',
        'guildId',
        'channelId',
        'userId',
        'message.id',
        'reaction.emoji.name',
        'reaction.emoji.id',
        'reaction.emoji.animated',
      ],
      sections: <_DocSection>[
        _DocSection(
          title: 'Best Use Cases',
          lines: <String>[
            'Approve/reject flows with unicode emoji.',
            'Multi-step polls using custom emoji IDs.',
            'Quick moderation signals from staff channels.',
          ],
        ),
        _DocSection(
          title: 'Important Notes',
          lines: <String>[
            'reaction.emoji.id can be empty for unicode emoji.',
            'Use reaction.emoji.name for generic matching.',
            'Use reaction.emoji.id for strict custom emoji matching.',
          ],
        ),
      ],
      example:
          'Guard: ((reaction.emoji.name)) equals ✅\n'
          'Action: addRole -> user=((userId)) role=((global.approvedRoleId))',
    ),
    _DocEntry(
      id: 'event.messagePollVoteAdd',
      kind: DocKind.event,
      title: 'Event: messagePollVoteAdd',
      subtitle: 'Triggered when a user votes on a poll answer.',
      summary:
          'Useful for score tracking, role assignment by poll option, and survey processing.',
      requiresIntent: <String>['Guild Messages'],
      variables: <String>[
        'event.name',
        'guildId',
        'channelId',
        'userId',
        'message.id',
        'poll.answer.id',
        'poll.question',
      ],
      sections: <_DocSection>[
        _DocSection(
          title: 'Best Use Cases',
          lines: <String>[
            'Map each answer id to a different action branch.',
            'Track poll participation per channel or user group.',
          ],
        ),
        _DocSection(
          title: 'Important Notes',
          lines: <String>[
            'poll.answer.id is the most stable key for routing.',
            'poll.question is optional and may be empty depending on payload.',
          ],
        ),
      ],
    ),
    _DocEntry(
      id: 'event.voiceStateUpdate',
      kind: DocKind.event,
      title: 'Event: voiceStateUpdate',
      subtitle: 'Triggered when voice state changes for a user.',
      summary:
          'Use this for auto-moderation in voice channels, attendance checks, and voice automation.',
      requiresIntent: <String>['Guilds'],
      variables: <String>[
        'event.name',
        'guildId',
        'channelId',
        'userId',
        'voice.channel.id',
        'voice.user.id',
        'voice.state.sessionId',
        'voice.selfMute',
        'voice.selfDeafen',
        'voice.mute',
        'voice.deafen',
      ],
      sections: <_DocSection>[
        _DocSection(
          title: 'Typical Automations',
          lines: <String>[
            'Detect self-mute/self-deafen policy violations.',
            'Trigger welcome message on voice join for support channels.',
            'Log leave/join patterns using channel changes.',
          ],
        ),
      ],
    ),
    _DocEntry(
      id: 'event.userUpdate',
      kind: DocKind.event,
      title: 'Event: userUpdate',
      subtitle: 'Triggered when user profile data changes.',
      summary:
          'Useful for profile-change auditing and username/avatar-driven triggers.',
      variables: <String>[
        'event.name',
        'user.id',
        'user.username',
        'user.avatar',
        'user.banner',
        'user.accentColor',
      ],
      sections: <_DocSection>[
        _DocSection(
          title: 'Important Notes',
          lines: <String>[
            'No channel context for this event in most cases.',
            'Prefer logging + moderation alerts over direct user-facing replies.',
          ],
        ),
      ],
    ),
    _DocEntry(
      id: 'event.guildAuditLogCreate',
      kind: DocKind.event,
      title: 'Event: guildAuditLogCreate',
      subtitle: 'Triggered when a new audit log entry is created.',
      summary: 'High-value event for administrative security monitoring.',
      variables: <String>[
        'event.name',
        'guildId',
        'auditLog.action',
        'auditLog.executorId',
        'auditLog.targetId',
      ],
      sections: <_DocSection>[
        _DocSection(
          title: 'Best Use Cases',
          lines: <String>[
            'Alert staff on sensitive actions (role delete, webhook create, ban, etc.).',
            'Route specific action types to dedicated workflows.',
          ],
        ),
      ],
    ),
    _DocEntry(
      id: 'action.stopUnless',
      kind: DocKind.action,
      title: 'Action: stopUnless',
      subtitle: 'Guard clause that stops workflow when condition fails.',
      summary:
          'Use it at the top of workflows to prevent unnecessary actions when context does not match.',
      sections: <_DocSection>[
        _DocSection(
          title: 'Supported Operators',
          lines: <String>[
            'equals, notEquals, contains, notContains, startsWith, endsWith',
            'greaterThan, lessThan, greaterOrEqual, lessOrEqual',
            'isEmpty, isNotEmpty, matches',
          ],
        ),
        _DocSection(
          title: 'Condition Variable Format',
          lines: <String>[
            'You can use raw keys: message.content[0]',
            'You can use wrapped variables: ((message.content[0]))',
            'Both are resolved by runtime.',
          ],
        ),
      ],
      example:
          'condition.variable = ((reaction.emoji.name))\n'
          'condition.operator = equals\n'
          'condition.value = ✅',
    ),
    _DocEntry(
      id: 'action.ifBlock',
      kind: DocKind.action,
      title: 'Action: ifBlock',
      subtitle:
          'Branch execution between THEN, ELSE IF and ELSE nested action lists.',
      summary:
          'Use this to keep a single workflow while handling several outcomes based on runtime state.',
      sections: <_DocSection>[
        _DocSection(
          title: 'Execution Model',
          lines: <String>[
            'Condition is evaluated once.',
            'The first matching branch executes: THEN, then ELSE IF blocks in order, then ELSE.',
            'Nested actions can include runWorkflow, API calls, and interaction replies.',
          ],
        ),
      ],
    ),
    _DocEntry(
      id: 'action.runWorkflow',
      kind: DocKind.action,
      title: 'Action: runWorkflow',
      subtitle: 'Calls another workflow with entry point and arguments.',
      summary:
          'Core composition primitive to split business logic into reusable units.',
      sections: <_DocSection>[
        _DocSection(
          title: 'Best Practices',
          lines: <String>[
            'Keep top-level workflow thin and delegate to domain workflows.',
            'Pass explicit arguments instead of relying on implicit globals.',
            'Use entry points to model sub-routines (create, close, assign, escalate).',
          ],
        ),
      ],
    ),
    _DocEntry(
      id: 'action.httpRequest',
      kind: DocKind.action,
      title: 'Action: httpRequest',
      subtitle: 'Executes an external HTTP call inside a workflow.',
      summary:
          'Use this for webhooks, internal APIs, moderation services, AI endpoints, and integrations.',
      sections: <_DocSection>[
        _DocSection(
          title: 'Reliability Checklist',
          lines: <String>[
            'Set explicit timeout and retries in your service layer when possible.',
            'Store API keys in globals or secure backend, never hardcode tokens.',
            'Validate status code and response body before next actions.',
          ],
        ),
      ],
    ),
    _buildTemplateVariablesDoc(),
    _buildTemplateFunctionsDoc(),
    _buildTemplateAdvancedVariablesDoc(),
    _buildInteractionCommandsDoc(),
    _buildRuntimeActionOutputsDoc(),
    _buildRuntimeExecutionFlowDoc(),
  ];

  List<_DocEntry> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _docs
        .where((doc) {
          if (_kindFilter != null && doc.kind != _kindFilter) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          final haystack =
              <String>[
                doc.title,
                doc.subtitle,
                doc.summary,
                ...doc.variables,
                ...doc.requiresIntent,
                ...doc.sections.expand(
                  (section) => <String>[section.title, ...section.lines],
                ),
              ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  String _kindLabel(DocKind kind) {
    switch (kind) {
      case DocKind.event:
        return AppStrings.t('doc_kind_event');
      case DocKind.action:
        return AppStrings.t('doc_kind_action');
      case DocKind.template:
        return AppStrings.t('doc_kind_template');
      case DocKind.runtime:
        return AppStrings.t('doc_kind_runtime');
    }
  }

  IconData _kindIcon(DocKind kind) {
    switch (kind) {
      case DocKind.event:
        return Icons.notifications_active_outlined;
      case DocKind.action:
        return Icons.build_circle_outlined;
      case DocKind.template:
        return Icons.data_object_outlined;
      case DocKind.runtime:
        return Icons.hub_outlined;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = _filtered;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('doc_center_title'))),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: AppStrings.t('doc_center_clear_search'),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  hintText: AppStrings.t('doc_center_search_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(AppStrings.t('doc_kind_all')),
                      selected: _kindFilter == null,
                      onSelected: (_) => setState(() => _kindFilter = null),
                    ),
                  ),
                  for (final kind in DocKind.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(_kindLabel(kind)),
                        selected: _kindFilter == kind,
                        onSelected: (_) => setState(() => _kindFilter = kind),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  docs.isEmpty
                      ? Center(
                        child: Text(
                          AppStrings.t('doc_center_empty'),
                          textAlign: TextAlign.center,
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(_kindIcon(doc.kind)),
                              title: Text(doc.title),
                              subtitle: Text(doc.subtitle),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) => _WorkflowDocDetailPage(doc: doc),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowDocDetailPage extends StatelessWidget {
  const _WorkflowDocDetailPage({required this.doc});

  final _DocEntry doc;

  Widget _mono(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(doc.subtitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(doc.summary),
            if (doc.requiresIntent.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                AppStrings.t('doc_required_intents'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: doc.requiresIntent
                    .map((intent) => Chip(label: Text(intent)))
                    .toList(growable: false),
              ),
            ],
            if (doc.variables.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                AppStrings.t('doc_available_variables'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              _mono(doc.variables.join('\n')),
            ],
            for (final section in doc.sections) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                section.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final line in section.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $line'),
                ),
            ],
            if (doc.example != null &&
                doc.example!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                AppStrings.t('doc_example'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              _mono(doc.example!),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
