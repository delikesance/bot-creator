import 'dart:async';

import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/runner_client.dart';
import 'package:bot_creator/utils/runner_settings.dart';
import 'package:flutter/material.dart';

class CommandDashboardPage extends StatefulWidget {
  const CommandDashboardPage({super.key, required this.botId});

  final String botId;

  @override
  State<CommandDashboardPage> createState() => _CommandDashboardPageState();
}

class _CommandDashboardPageState extends State<CommandDashboardPage> {
  RunnerClient? _client;
  bool _loading = true;
  String? _error;
  bool _noRunner = false;

  int _hours = 24;

  int _totalAllTime = 0;
  List<_CommandCount> _commands = const [];
  List<_TimelineEntry> _timeline = const [];

  List<RunnerConnectionConfig> _runners = const [];
  String? _activeRunnerId;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final runners = await RunnerSettings.getRunners();
    final config = await RunnerSettings.getConfig();
    if (!mounted) return;
    setState(() {
      _runners = runners;
      _activeRunnerId = config?.id;
    });

    if (config == null) {
      setState(() {
        _noRunner = true;
        _loading = false;
      });
      return;
    }
    _client = config.createClient();
    await _fetchStats();
  }

  Future<void> _switchRunner(String runnerId) async {
    final runner = _runners.where((r) => r.id == runnerId).firstOrNull;
    if (runner == null) return;
    setState(() {
      _activeRunnerId = runnerId;
      _loading = true;
      _error = null;
    });
    _client = runner.createClient();
    await _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await _client!.getCommandStats(widget.botId, hours: _hours);
      if (!mounted) return;
      final rawCommands = json['commands'] as List? ?? [];
      final rawTimeline = json['timeline'] as List? ?? [];
      setState(() {
        _totalAllTime = (json['totalAllTime'] as num?)?.toInt() ?? 0;
        _commands =
            rawCommands
                .map(
                  (e) => _CommandCount(
                    name: e['command'] as String? ?? '?',
                    count: (e['count'] as num?)?.toInt() ?? 0,
                  ),
                )
                .toList()
              ..sort((a, b) => b.count.compareTo(a.count));
        _timeline =
            rawTimeline
                .map(
                  (e) => _TimelineEntry(
                    hour: e['hour'] as String? ?? '',
                    count: (e['count'] as num?)?.toInt() ?? 0,
                  ),
                )
                .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _setPeriod(int hours) {
    if (hours == _hours) return;
    _hours = hours;
    unawaited(_fetchStats());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_noRunner) {
      return _CenteredMessage(
        icon: Icons.cloud_off,
        text: AppStrings.t('dashboard_requires_runner'),
      );
    }

    if (_loading) {
      return _CenteredMessage(
        icon: Icons.hourglass_empty,
        text: AppStrings.t('dashboard_loading'),
      );
    }

    if (_error != null) {
      return _CenteredMessage(
        icon: Icons.error_outline,
        text: '${AppStrings.t('dashboard_error')}\n$_error',
      );
    }

    final periodTotal = _commands.fold<int>(0, (sum, c) => sum + c.count);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Runner source ──
        _RunnerSourceBanner(
          runners: _runners,
          activeRunnerId: _activeRunnerId,
          onRunnerChanged: _switchRunner,
        ),
        // ── Period selector ──
        Row(
          children: [
            for (final entry in [
              (24, 'dashboard_period_24h'),
              (168, 'dashboard_period_7d'),
              (720, 'dashboard_period_30d'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(AppStrings.t(entry.$2)),
                  selected: _hours == entry.$1,
                  onSelected: (_) => _setPeriod(entry.$1),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Total card ──
        _StatCard(
          icon: Icons.functions,
          label: AppStrings.t('dashboard_total'),
          value: _totalAllTime.toString(),
          subtitle: '$periodTotal in selected period',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 16),

        // ── Top commands ──
        Text(
          AppStrings.t('dashboard_top_commands'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_commands.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                AppStrings.t('dashboard_no_data'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ..._commands.map(
            (cmd) => _CommandRow(
              command: cmd,
              maxCount: _commands.first.count,
              colorScheme: colorScheme,
            ),
          ),
        const SizedBox(height: 24),

        // ── Timeline ──
        Text(
          AppStrings.t('dashboard_timeline'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_timeline.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                AppStrings.t('dashboard_no_data'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          SizedBox(height: 150, child: _TimelineChart(entries: _timeline)),
      ],
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _CommandCount {
  const _CommandCount({required this.name, required this.count});
  final String name;
  final int count;
}

class _TimelineEntry {
  const _TimelineEntry({required this.hour, required this.count});
  final String hour;
  final int count;
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.command,
    required this.maxCount,
    required this.colorScheme,
  });

  final _CommandCount command;
  final int maxCount;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount > 0 ? command.count / maxCount : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '/${command.name}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 18,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              command.count.toString(),
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineChart extends StatelessWidget {
  const _TimelineChart({required this.entries});
  final List<_TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final maxCount = entries.fold<int>(0, (m, e) => e.count > m ? e.count : m);
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth =
            entries.isNotEmpty
                ? (constraints.maxWidth / entries.length).clamp(4.0, 24.0)
                : 8.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children:
              entries.map((e) {
                final ratio = maxCount > 0 ? e.count / maxCount : 0.0;
                return Tooltip(
                  message:
                      '${e.hour}\n${e.count} ${AppStrings.t('dashboard_executions')}',
                  child: Container(
                    width: barWidth - 1,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    height: (ratio * (constraints.maxHeight - 16)).clamp(
                      2.0,
                      constraints.maxHeight - 16,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(
                        alpha: 0.3 + 0.7 * ratio,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }
}

class _RunnerSourceBanner extends StatelessWidget {
  const _RunnerSourceBanner({
    required this.runners,
    required this.activeRunnerId,
    required this.onRunnerChanged,
  });

  final List<RunnerConnectionConfig> runners;
  final String? activeRunnerId;
  final ValueChanged<String> onRunnerChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = runners.where((r) => r.id == activeRunnerId).firstOrNull;
    final label = active?.name ?? active?.url ?? '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.dns_outlined, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child:
                runners.length > 1
                    ? DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: activeRunnerId,
                        isDense: true,
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        items: [
                          for (final r in runners)
                            DropdownMenuItem(
                              value: r.id,
                              child: Text(
                                AppStrings.tr(
                                  'runner_source_label',
                                  params: {'name': r.name ?? r.url},
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) onRunnerChanged(v);
                        },
                      ),
                    )
                    : Text(
                      AppStrings.tr(
                        'runner_source_label',
                        params: {'name': label},
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
