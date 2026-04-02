import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/premium_capabilities.dart';
import 'package:bot_creator/widgets/subscription_page.dart';
import 'package:flutter/material.dart';

class SchedulerPage extends StatefulWidget {
  const SchedulerPage({super.key, required this.botId});

  final String botId;

  @override
  State<SchedulerPage> createState() => _SchedulerPageState();
}

class _SchedulerPageState extends State<SchedulerPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _triggers = const <Map<String, dynamic>>[];
  List<String> _workflowNames = const <String>[];

  bool get _hasSchedulerCapability =>
      PremiumCapabilities.hasCapability(PremiumCapability.schedulerTriggers);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final workflows = await appManager.getWorkflows(widget.botId);
    final workflowNames = workflows
      .map((entry) => (entry['name'] ?? '').toString().trim())
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList(growable: false)..sort();

    final triggers = await appManager.getScheduledTriggers(widget.botId);

    if (!mounted) {
      return;
    }

    setState(() {
      _workflowNames = workflowNames;
      _triggers = triggers;
      _loading = false;
    });
  }

  Future<void> _showEditor({Map<String, dynamic>? initial}) async {
    if (_workflowNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create at least one workflow before adding a schedule.',
          ),
        ),
      );
      return;
    }

    final labelCtrl = TextEditingController(
      text: (initial?['label'] ?? '').toString(),
    );
    final minutesCtrl = TextEditingController(
      text: ((initial?['everyMinutes'] ?? 60) as int).toString(),
    );
    var selectedWorkflow =
        ((initial?['workflowName'] ?? '').toString().trim().isNotEmpty)
            ? (initial!['workflowName'] as String)
            : _workflowNames.first;
    var enabled = initial == null ? true : initial['enabled'] != false;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setInnerState) {
            return AlertDialog.adaptive(
              title: Text(initial == null ? 'Add schedule' : 'Edit schedule'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedWorkflow,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Workflow',
                      border: OutlineInputBorder(),
                    ),
                    items: _workflowNames
                        .map(
                          (name) => DropdownMenuItem<String>(
                            value: name,
                            child: Text(name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setInnerState(() {
                        selectedWorkflow = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      hintText: 'Optional display label',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: minutesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Every (minutes)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    title: const Text('Enabled'),
                    onChanged: (value) {
                      setInnerState(() {
                        enabled = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(AppStrings.t('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(AppStrings.t('app_save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (save != true) {
      return;
    }

    final everyMinutes = int.tryParse(minutesCtrl.text.trim()) ?? 0;
    if (everyMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Every minutes must be greater than 0.')),
      );
      return;
    }

    try {
      await appManager.saveScheduledTrigger(
        widget.botId,
        workflowName: selectedWorkflow,
        everyMinutes: everyMinutes,
        enabled: enabled,
        triggerId:
            (initial?['id'] ?? '').toString().trim().isEmpty
                ? null
                : (initial?['id'] ?? '').toString(),
        label: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final text = error.toString();
      if (text.contains('scheduler_trigger_limit_reached')) {
        final limit = PremiumCapabilities.limitFor(
          PremiumCapability.schedulerTriggers,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scheduler limit reached ($limit).')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save schedule: $error')),
        );
      }
    }
  }

  Future<void> _deleteTrigger(Map<String, dynamic> trigger) async {
    final label =
        (trigger['label'] ?? trigger['workflowName'] ?? '').toString().trim();

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog.adaptive(
              title: const Text('Delete schedule'),
              content: Text('Delete "$label" schedule?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(AppStrings.t('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    AppStrings.t('delete'),
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm) {
      return;
    }

    await appManager.deleteScheduledTrigger(
      widget.botId,
      (trigger['id'] ?? '').toString(),
    );
    await _load();
  }

  Future<void> _toggleTrigger(Map<String, dynamic> trigger, bool value) async {
    await appManager.saveScheduledTrigger(
      widget.botId,
      workflowName: (trigger['workflowName'] ?? '').toString(),
      everyMinutes:
          int.tryParse((trigger['everyMinutes'] ?? '').toString()) ?? 60,
      enabled: value,
      triggerId: (trigger['id'] ?? '').toString(),
      label: (trigger['label'] ?? '').toString(),
    );
    await _load();
  }

  Widget _buildUpsellCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Premium Scheduler',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Run workflows automatically every X minutes with up to 10 active schedules.',
            ),
            const SizedBox(height: 12),
            if (PremiumCapabilities.canShowPurchaseUI)
              FilledButton.icon(
                onPressed: () async {
                  await SubscriptionPage.show(context);
                  if (!mounted) {
                    return;
                  }
                  await _load();
                },
                icon: const Icon(Icons.workspace_premium_rounded),
                label: Text(AppStrings.t('premium_card_button')),
              )
            else
              Text(
                AppStrings.t('subscription_unavailable_platform'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final limit = PremiumCapabilities.limitFor(
      PremiumCapability.schedulerTriggers,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduler'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton:
          _hasSchedulerCapability
              ? FloatingActionButton.extended(
                onPressed: () => _showEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Add trigger'),
              )
              : null,
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (!_hasSchedulerCapability) _buildUpsellCard(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Text(
                          'Triggers: ${_triggers.length}${limit > 0 ? ' / $limit' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        _triggers.isEmpty
                            ? const Center(
                              child: Text('No scheduled triggers yet.'),
                            )
                            : ListView.separated(
                              itemCount: _triggers.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final trigger = _triggers[index];
                                final label =
                                    (trigger['label'] ??
                                            trigger['workflowName'] ??
                                            '')
                                        .toString();
                                final workflowName =
                                    (trigger['workflowName'] ?? '').toString();
                                final everyMinutes =
                                    int.tryParse(
                                      (trigger['everyMinutes'] ?? '')
                                          .toString(),
                                    ) ??
                                    60;
                                final enabled = trigger['enabled'] != false;
                                return ListTile(
                                  title: Text(label),
                                  subtitle: Text(
                                    'Workflow: $workflowName • Every $everyMinutes min',
                                  ),
                                  leading: Switch.adaptive(
                                    value: enabled,
                                    onChanged:
                                        _hasSchedulerCapability
                                            ? (value) =>
                                                _toggleTrigger(trigger, value)
                                            : null,
                                  ),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit',
                                        onPressed:
                                            _hasSchedulerCapability
                                                ? () => _showEditor(
                                                  initial: trigger,
                                                )
                                                : null,
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: AppStrings.t('delete'),
                                        onPressed:
                                            _hasSchedulerCapability
                                                ? () => _deleteTrigger(trigger)
                                                : null,
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
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
