import 'dart:async';
import 'dart:convert';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/runner_client.dart';
import 'package:bot_creator/utils/runner_settings.dart';
import 'package:flutter/material.dart';

enum _VariableMode { global, scoped }

enum _VariablesSource { local, runner }

class GlobalVariablesPage extends StatefulWidget {
  const GlobalVariablesPage({super.key, required this.botId});

  final String botId;

  @override
  State<GlobalVariablesPage> createState() => _GlobalVariablesPageState();
}

class _GlobalVariablesPageState extends State<GlobalVariablesPage> {
  static const List<String> _scopes = <String>[
    'guild',
    'user',
    'channel',
    'guildMember',
    'message',
  ];

  Map<String, dynamic> _globalVariables = <String, dynamic>{};
  List<Map<String, dynamic>> _scopedDefinitions = <Map<String, dynamic>>[];
  _VariableMode _mode = _VariableMode.global;
  _VariablesSource _source = _VariablesSource.local;
  List<RunnerConnectionConfig> _runners = const [];
  String? _activeRunnerId;
  RunnerClient? _runnerClient;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  bool get _isScopedMode => _mode == _VariableMode.scoped;
  bool get _isRunnerMode => _source == _VariablesSource.runner;

  Future<void> _init() async {
    final runners = await RunnerSettings.getRunners();
    final active = await RunnerSettings.getConfig();
    if (!mounted) return;
    setState(() {
      _runners = runners;
      _activeRunnerId = active?.id;
      _source =
          active == null ? _VariablesSource.local : _VariablesSource.runner;
      _runnerClient = active?.createClient();
    });
    await _load();
  }

  dynamic _parseLooseVariableValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final number = num.tryParse(trimmed);
    if (number != null) {
      return number;
    }

    if (trimmed == 'true') {
      return true;
    }
    if (trimmed == 'false') {
      return false;
    }

    if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
        (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        trimmed == 'null') {
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        return raw;
      }
    }

    return raw;
  }

  String _formatVariableValue(dynamic value) {
    if (value == null) {
      return 'null';
    }
    if (value is List || value is Map) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  }

  String _toScopedReferenceKey(String rawKey) {
    final key = rawKey.trim();
    if (key.isEmpty) {
      return key;
    }
    if (key.startsWith('bc_') && key.length > 3) {
      return key.substring(3);
    }
    return key;
  }

  String _toLegacyScopedReferenceKey(String rawKey) {
    final key = _toScopedReferenceKey(rawKey);
    if (key.isEmpty) {
      return key;
    }
    return 'bc_$key';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isScopedMode) {
        final defs =
            _isRunnerMode
                ? await _requireRunnerClient().getScopedVariableDefinitions(
                  widget.botId,
                )
                : await appManager.getScopedVariableDefinitions(widget.botId);
        if (!mounted) return;
        setState(() {
          _scopedDefinitions = defs;
          _loading = false;
        });
      } else {
        final vars =
            _isRunnerMode
                ? await _requireRunnerClient().getGlobalVariables(widget.botId)
                : await appManager.getGlobalVariables(widget.botId);
        if (!mounted) return;
        setState(() {
          _globalVariables = Map<String, dynamic>.from(vars);
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  RunnerClient _requireRunnerClient() {
    final client = _runnerClient;
    if (client == null) {
      throw StateError('Source Runner sélectionnée sans connexion active.');
    }
    return client;
  }

  Future<void> _switchSource(String sourceId) async {
    if (sourceId == 'local') {
      setState(() {
        _source = _VariablesSource.local;
        _error = null;
      });
      await _load();
      return;
    }

    final runner = _runners.where((r) => r.id == sourceId).firstOrNull;
    if (runner == null) {
      return;
    }

    setState(() {
      _source = _VariablesSource.runner;
      _activeRunnerId = sourceId;
      _runnerClient = runner.createClient();
      _error = null;
    });
    await _load();
  }

  // ─── Global variable add / edit ───────────────────────────────────────────

  Future<void> _editGlobalVariable({String? key}) async {
    final keyCtrl = TextEditingController(text: key ?? '');
    final valueCtrl = TextEditingController(
      text: key != null ? _formatVariableValue(_globalVariables[key]) : '',
    );

    final save = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              key == null
                  ? AppStrings.t('globals_add')
                  : AppStrings.t('globals_edit'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyCtrl,
                  enabled: key == null,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('globals_key'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueCtrl,
                  maxLines: 4,
                  minLines: 1,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('globals_value'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppStrings.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppStrings.t('app_save')),
              ),
            ],
          ),
    );

    if (save != true) return;
    final nextKey = keyCtrl.text.trim();
    if (nextKey.isEmpty) return;

    final parsed = _parseLooseVariableValue(valueCtrl.text);
    if (_isRunnerMode) {
      await _requireRunnerClient().setGlobalVariable(
        widget.botId,
        nextKey,
        parsed,
      );
    } else {
      await appManager.setGlobalVariable(widget.botId, nextKey, parsed);
    }
    await _load();
  }

  Future<void> _deleteGlobalVariable(String key) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog.adaptive(
                title: const Text('Supprimer la variable globale'),
                content: Text('Supprimer "$key" ?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(AppStrings.t('cancel')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      AppStrings.t('delete'),
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
    if (!shouldDelete) {
      return;
    }

    if (_isRunnerMode) {
      await _requireRunnerClient().removeGlobalVariable(widget.botId, key);
    } else {
      await appManager.removeGlobalVariable(widget.botId, key);
    }
    await _load();
  }

  // ─── Scoped variable definition add / edit ────────────────────────────────
  // Only key + scope + defaultValue — NO contextId (that's runtime/SQLite).

  Future<void> _editScopedDefinition({Map<String, dynamic>? existing}) async {
    final oldKey = existing?['key']?.toString();
    final keyCtrl = TextEditingController(text: oldKey ?? '');
    final valueCtrl = TextEditingController(
      text: _formatVariableValue(existing?['defaultValue']),
    );
    String scope =
        (existing?['scope']?.toString().isNotEmpty == true
            ? existing!['scope'].toString()
            : null) ??
        _scopes.first;

    final save = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setInner) => AlertDialog(
                  title: Text(
                    existing == null
                        ? AppStrings.t('globals_add')
                        : AppStrings.t('globals_edit'),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: scope,
                        decoration: const InputDecoration(
                          labelText: 'Scope',
                          border: OutlineInputBorder(),
                        ),
                        items: _scopes
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(s),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (v) {
                          if (v != null) setInner(() => scope = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: keyCtrl,
                        decoration: InputDecoration(
                          labelText: AppStrings.t('globals_key'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: valueCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Default value',
                          hintText: 'Optional',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(AppStrings.t('cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(AppStrings.t('app_save')),
                    ),
                  ],
                ),
          ),
    );

    if (save != true) return;
    final newKey = keyCtrl.text.trim();
    if (newKey.isEmpty) return;

    // If the key was renamed, delete the old entry first.
    if (oldKey != null && oldKey != newKey) {
      if (_isRunnerMode) {
        await _requireRunnerClient().removeScopedVariableDefinition(
          widget.botId,
          oldKey,
          scope: existing?['scope']?.toString(),
        );
      } else {
        await appManager.removeScopedVariableDefinition(
          widget.botId,
          oldKey,
          scope: existing?['scope']?.toString(),
        );
      }
    }

    final parsed = _parseLooseVariableValue(valueCtrl.text);
    if (_isRunnerMode) {
      await _requireRunnerClient().setScopedVariableDefinition(
        widget.botId,
        newKey,
        scope,
        parsed,
      );
    } else {
      await appManager.setScopedVariableDefinition(
        widget.botId,
        newKey,
        scope,
        parsed,
      );
    }
    await _load();
  }

  Future<void> _deleteScopedDefinition(String key) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog.adaptive(
                title: const Text('Supprimer la variable scopée'),
                content: Text('Supprimer "$key" ?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(AppStrings.t('cancel')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      AppStrings.t('delete'),
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
    if (!shouldDelete) {
      return;
    }

    final existing = _scopedDefinitions
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (entry) => (entry?['key'] ?? '').toString() == key,
          orElse: () => null,
        );
    if (_isRunnerMode) {
      await _requireRunnerClient().removeScopedVariableDefinition(
        widget.botId,
        key,
        scope: existing?['scope']?.toString(),
      );
    } else {
      await appManager.removeScopedVariableDefinition(
        widget.botId,
        key,
        scope: existing?['scope']?.toString(),
      );
    }
    await _load();
  }

  // ─── Explorer: shows SQLite runtime data for a given scoped key ───────────

  Future<void> _exploreScopedKey(String key, String scope) async {
    final values =
        _isRunnerMode
            ? await _requireRunnerClient().listScopedValuesForKey(
              widget.botId,
              scope,
              key,
            )
            : await appManager.listScopedValuesForKey(widget.botId, scope, key);

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder:
                (ctx, scrollCtrl) => SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text('Données runtime — "$key"'),
                        subtitle: Text(
                          'Scope: $scope · ${values.length} contexte(s) trouvé(s)',
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child:
                            values.isEmpty
                                ? const Center(
                                  child: Text(
                                    'Aucune donnée runtime.\nCette clé sera peuplée par le bot à l\'exécution.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                                : ListView.separated(
                                  controller: scrollCtrl,
                                  itemCount: values.length,
                                  separatorBuilder:
                                      (_, _) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final entry = values.entries.elementAt(i);
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                      subtitle: Text(
                                        entry.value?.toString() ?? '',
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Text('Mode', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 12),
          SegmentedButton<_VariableMode>(
            segments: const [
              ButtonSegment<_VariableMode>(
                value: _VariableMode.global,
                label: Text('Global'),
              ),
              ButtonSegment<_VariableMode>(
                value: _VariableMode.scoped,
                label: Text('Scoped'),
              ),
            ],
            selected: <_VariableMode>{_mode},
            onSelectionChanged: (selection) async {
              final next = selection.first;
              if (next == _mode) return;
              setState(() => _mode = next);
              await _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceToggle() {
    if (_runners.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Row(
          children: [
            Text('Source', style: TextStyle(fontSize: 13)),
            SizedBox(width: 12),
            Chip(label: Text('Local')),
          ],
        ),
      );
    }

    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: 'local', child: Text('Local')),
      ..._runners.map(
        (runner) => DropdownMenuItem<String>(
          value: runner.id,
          child: Text('Runner: ${runner.name}'),
        ),
      ),
    ];
    final value =
        _source == _VariablesSource.local
            ? 'local'
            : (_activeRunnerId ?? 'local');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Text('Source', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue:
                  items.any((entry) => entry.value == value) ? value : 'local',
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              items: items,
              onChanged: (next) {
                if (next == null) return;
                unawaited(_switchSource(next));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalList() {
    if (_globalVariables.isEmpty) {
      return Center(child: Text(AppStrings.t('globals_empty')));
    }
    return ListView.separated(
      itemCount: _globalVariables.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final entry = _globalVariables.entries.elementAt(i);
        return ListTile(
          title: Text(entry.key),
          subtitle: Text(
            entry.value?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                onPressed: () => _editGlobalVariable(key: entry.key),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: () => _deleteGlobalVariable(entry.key),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScopedList() {
    if (_scopedDefinitions.isEmpty) {
      return const Center(
        child: Text(
          'Aucune variable scopée définie.\nElles sont créées automatiquement au premier accès.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: _scopedDefinitions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final def = _scopedDefinitions[i];
        final key = def['key']?.toString() ?? '';
        final scope = def['scope']?.toString() ?? '';
        final defaultValue = def['defaultValue']?.toString() ?? '';
        final refKey = _toScopedReferenceKey(key);
        final legacyRefKey = _toLegacyScopedReferenceKey(key);

        return ListTile(
          title: Text(key),
          subtitle: Row(
            children: [
              Chip(
                label: Text(scope, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  refKey == legacyRefKey
                      ? 'ref: $scope.$refKey'
                      : 'ref: $scope.$refKey (legacy: $scope.$legacyRefKey)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              if (defaultValue.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '= ${_formatVariableValue(defaultValue)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          trailing: Wrap(
            spacing: 0,
            children: [
              IconButton(
                icon: const Icon(Icons.travel_explore, size: 20),
                tooltip: 'Explorer les données runtime',
                onPressed: () => _exploreScopedKey(key, scope),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _editScopedDefinition(existing: def),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _deleteScopedDefinition(key),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('globals_title'))),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () =>
                _isScopedMode ? _editScopedDefinition() : _editGlobalVariable(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        top: false,
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    _buildSourceToggle(),
                    _buildModeToggle(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Material(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child:
                          _isScopedMode
                              ? _buildScopedList()
                              : _buildGlobalList(),
                    ),
                  ],
                ),
      ),
    );
  }
}
