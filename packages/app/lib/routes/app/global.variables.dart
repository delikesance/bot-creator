import 'dart:convert';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:flutter/material.dart';

enum _VariableMode { global, scoped }

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isScopedMode => _mode == _VariableMode.scoped;

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
    return key.startsWith('bc_') ? key : 'bc_$key';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (_isScopedMode) {
      final defs = await appManager.getScopedVariableDefinitions(widget.botId);
      if (!mounted) return;
      setState(() {
        _scopedDefinitions = defs;
        _loading = false;
      });
    } else {
      final vars = await appManager.getGlobalVariables(widget.botId);
      if (!mounted) return;
      setState(() {
        _globalVariables = Map<String, dynamic>.from(vars);
        _loading = false;
      });
    }
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

    await appManager.setGlobalVariable(
      widget.botId,
      nextKey,
      _parseLooseVariableValue(valueCtrl.text),
    );
    await _load();
  }

  Future<void> _deleteGlobalVariable(String key) async {
    await appManager.removeGlobalVariable(widget.botId, key);
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
    String valueType =
        (existing?['valueType']?.toString().isNotEmpty == true
            ? existing!['valueType'].toString()
            : null) ??
        'string';

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
                      DropdownButtonFormField<String>(
                        initialValue: valueType,
                        decoration: const InputDecoration(
                          labelText: 'Value Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'string',
                            child: Text('String'),
                          ),
                          DropdownMenuItem(
                            value: 'number',
                            child: Text('Number'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setInner(() => valueType = v);
                        },
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
      await appManager.removeScopedVariableDefinition(
        widget.botId,
        oldKey,
        scope: existing?['scope']?.toString(),
      );
    }

    await appManager.setScopedVariableDefinition(
      widget.botId,
      newKey,
      scope,
      _parseLooseVariableValue(valueCtrl.text),
      valueType: valueType,
    );
    await _load();
  }

  Future<void> _deleteScopedDefinition(String key) async {
    final existing = _scopedDefinitions
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (entry) => (entry?['key'] ?? '').toString() == key,
          orElse: () => null,
        );
    await appManager.removeScopedVariableDefinition(
      widget.botId,
      key,
      scope: existing?['scope']?.toString(),
    );
    await _load();
  }

  // ─── Explorer: shows SQLite runtime data for a given scoped key ───────────

  Future<void> _exploreScopedKey(String key, String scope) async {
    final values = await appManager.listScopedValuesForKey(
      widget.botId,
      scope,
      key,
    );

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
          'Aucune variable scoped définie.\nAppuyez sur + pour en ajouter une.',
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
        final valueType = def['valueType']?.toString() ?? 'string';
        final refKey = _toScopedReferenceKey(key);

        return ListTile(
          title: Text(key),
          subtitle: Row(
            children: [
              Chip(
                label: Text(scope, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 4),
              Chip(
                label: Text(valueType, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                backgroundColor:
                    valueType == 'number'
                        ? Colors.blue.withAlpha(40)
                        : Colors.grey.withAlpha(40),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ref: $scope.$refKey',
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
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildModeToggle(),
                  Expanded(
                    child:
                        _isScopedMode ? _buildScopedList() : _buildGlobalList(),
                  ),
                ],
              ),
    );
  }
}
