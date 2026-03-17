import 'package:flutter/material.dart';

enum _DocKind { event, action, template, runtime }

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
  final _DocKind kind;
  final String title;
  final String subtitle;
  final String summary;
  final List<_DocSection> sections;
  final List<String> variables;
  final String? example;
  final List<String> requiresIntent;
}

class WorkflowDocumentationPage extends StatefulWidget {
  const WorkflowDocumentationPage({super.key});

  @override
  State<WorkflowDocumentationPage> createState() =>
      _WorkflowDocumentationPageState();
}

class _WorkflowDocumentationPageState extends State<WorkflowDocumentationPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  _DocKind? _kindFilter;

  static const List<_DocEntry> _docs = <_DocEntry>[
    _DocEntry(
      id: 'event.messageCreate',
      kind: _DocKind.event,
      title: 'Event: messageCreate',
      subtitle: 'Triggered for each newly created message.',
      summary:
          'Use this event for moderation, keyword pipelines, auto-replies, command-style parsing, and analytics.',
      requiresIntent: <String>['Guild Messages', 'Message Content'],
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
          title: 'Best Use Cases',
          lines: <String>[
            'Detect commands typed without slash commands.',
            'Apply anti-spam filters before answering.',
            'Route to reusable workflows based on first word or mention.',
          ],
        ),
        _DocSection(
          title: 'Important Notes',
          lines: <String>[
            'If Message Content intent is off, content-dependent conditions can fail.',
            'message.content[index] is word-based and capped by runtime extraction.',
            'author.isBot can help avoid bot loops.',
          ],
        ),
      ],
      example:
          'Guard: ((message.isBot)) equals false\n'
          'Guard: ((message.content[0])) equals !ticket\n'
          'Then: runWorkflow -> ticket_manager entry=create',
    ),
    _DocEntry(
      id: 'event.messageReactionAdd',
      kind: _DocKind.event,
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
      kind: _DocKind.event,
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
      kind: _DocKind.event,
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
      kind: _DocKind.event,
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
      kind: _DocKind.event,
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
      kind: _DocKind.action,
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
      kind: _DocKind.action,
      title: 'Action: ifBlock',
      subtitle: 'Branch execution between THEN and ELSE nested action lists.',
      summary:
          'Use this to keep a single workflow while handling several outcomes based on runtime state.',
      sections: <_DocSection>[
        _DocSection(
          title: 'Execution Model',
          lines: <String>[
            'Condition is evaluated once.',
            'Only one branch (THEN or ELSE) executes.',
            'Nested actions can include runWorkflow, API calls, and interaction replies.',
          ],
        ),
      ],
    ),
    _DocEntry(
      id: 'action.runWorkflow',
      kind: _DocKind.action,
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
      kind: _DocKind.action,
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
    _DocEntry(
      id: 'template.variables',
      kind: _DocKind.template,
      title: 'Template Variables',
      subtitle: 'How dynamic placeholders are resolved.',
      summary:
          'Runtime resolves placeholders using current event/interaction context, workflow args, and global vars.',
      sections: <_DocSection>[
        _DocSection(
          title: 'Variable Sources',
          lines: <String>[
            'Event variables: event.*, message.*, reaction.*, voice.*, role.*, etc.',
            'Workflow variables: workflow.name, workflow.entryPoint, arg.*, workflow.arg.*',
            'Global variables: global.<key>',
            'Action outputs: action.<key> when available.',
          ],
        ),
      ],
      example:
          'Hello ((author.name)), your vote is ((poll.answer.id)).\n'
          'Current workflow: ((workflow.name))',
    ),
    _DocEntry(
      id: 'runtime.executionFlow',
      kind: _DocKind.runtime,
      title: 'Runtime Execution Flow',
      subtitle: 'How event workflows are selected and executed.',
      summary:
          'When an event arrives, runtime matches configured workflows by eventTrigger.event then executes actions with context variables.',
      sections: <_DocSection>[
        _DocSection(
          title: 'Pipeline',
          lines: <String>[
            '1) Receive gateway event.',
            '2) Build context variables map.',
            '3) Match workflows by event name.',
            '4) Merge global variables.',
            '5) Execute actions sequentially with conditions.',
          ],
        ),
        _DocSection(
          title: 'Parity Rule',
          lines: <String>[
            'Variables should be identical between local app runtime and runner runtime.',
            'Use same variable names in conditions to stay portable.',
          ],
        ),
      ],
    ),
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

  String _kindLabel(_DocKind kind) {
    switch (kind) {
      case _DocKind.event:
        return 'Event';
      case _DocKind.action:
        return 'Action';
      case _DocKind.template:
        return 'Template';
      case _DocKind.runtime:
        return 'Runtime';
    }
  }

  IconData _kindIcon(_DocKind kind) {
    switch (kind) {
      case _DocKind.event:
        return Icons.notifications_active_outlined;
      case _DocKind.action:
        return Icons.build_circle_outlined;
      case _DocKind.template:
        return Icons.data_object_outlined;
      case _DocKind.runtime:
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
      appBar: AppBar(title: const Text('Workflow Documentation')),
      body: Column(
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
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                hintText:
                    'Search event names, actions, variables, intents, or examples...',
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
                    label: const Text('All'),
                    selected: _kindFilter == null,
                    onSelected: (_) => setState(() => _kindFilter = null),
                  ),
                ),
                for (final kind in _DocKind.values)
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
                    ? const Center(
                      child: Text(
                        'No documentation entry matches your search.',
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(doc.subtitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(doc.summary),
          if (doc.requiresIntent.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const Text(
              'Required Intents',
              style: TextStyle(fontWeight: FontWeight.w700),
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
            const Text(
              'Available Variables',
              style: TextStyle(fontWeight: FontWeight.w700),
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
            const Text(
              'Example',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            _mono(doc.example!),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
