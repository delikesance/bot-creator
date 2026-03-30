import 'package:flutter/material.dart';
import 'package:bot_creator/types/app_emoji.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/widgets/response_embeds_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_v2_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/normal_component_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/modal_builder.dart';
import 'package:bot_creator/widgets/variable_text_field.dart';
import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:bot_creator/widgets/bdfd_editor_page.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';

class CommandResponseWorkflowPage extends StatefulWidget {
  const CommandResponseWorkflowPage({
    super.key,
    required this.initialWorkflow,
    required this.variableSuggestions,
    this.botIdForConfig,
    this.emojiSuggestions,
  });

  final Map<String, dynamic> initialWorkflow;
  final List<VariableSuggestion> variableSuggestions;
  final String? botIdForConfig;
  final List<AppEmoji>? emojiSuggestions;

  @override
  State<CommandResponseWorkflowPage> createState() =>
      _CommandResponseWorkflowPageState();
}

class _CommandResponseWorkflowPageState
    extends State<CommandResponseWorkflowPage> {
  static const String _modeVisual = 'visual';
  static const String _modeBdfd = 'bdfd';

  late Map<String, dynamic> _initialSnapshot;
  late String _workflowMode;
  late bool _autoDeferIfActions;
  late String _visibility;
  late String _onError;
  late bool _conditionEnabled;
  late TextEditingController _variableController;
  late TextEditingController _bdfdScriptController;
  final BdfdCompiler _bdfdCompiler = BdfdCompiler();
  BdfdCompileResult? _bdfdCompileResult;
  late String _whenTrueType;
  late String _whenFalseType;
  late TextEditingController _whenTrueController;
  late TextEditingController _whenFalseController;
  late List<Map<String, dynamic>> _whenTrueEmbeds;
  late List<Map<String, dynamic>> _whenFalseEmbeds;
  late Map<String, dynamic> _whenTrueNormalComponents;
  late Map<String, dynamic> _whenFalseNormalComponents;
  late Map<String, dynamic> _whenTrueComponents;
  late Map<String, dynamic> _whenFalseComponents;
  late Map<String, dynamic> _whenTrueModal;
  late Map<String, dynamic> _whenFalseModal;

  List<Map<String, dynamic>> _normalizeEmbedsPayload(dynamic rawEmbeds) {
    if (rawEmbeds is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawEmbeds
        .whereType<Map>()
        .map((embed) {
          return Map<String, dynamic>.from(
            embed.map((key, value) => MapEntry(key.toString(), value)),
          );
        })
        .take(10)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final conditional = Map<String, dynamic>.from(
      (widget.initialWorkflow['conditional'] as Map?)
              ?.cast<String, dynamic>() ??
          const {},
    );

    _workflowMode =
        (widget.initialWorkflow['workflowMode']?.toString().toLowerCase() ==
                _modeBdfd)
            ? _modeBdfd
            : _modeVisual;
    _autoDeferIfActions = widget.initialWorkflow['autoDeferIfActions'] != false;
    _visibility =
        (widget.initialWorkflow['visibility']?.toString().toLowerCase() ==
                'ephemeral')
            ? 'ephemeral'
            : 'public';
    _onError = 'edit_error';
    _conditionEnabled = conditional['enabled'] == true;
    _variableController = TextEditingController(
      text: (conditional['variable'] ?? '').toString(),
    );
    _whenTrueType = (conditional['whenTrueType'] ?? 'normal').toString();
    _whenFalseType = (conditional['whenFalseType'] ?? 'normal').toString();
    _whenTrueController = TextEditingController(
      text: (conditional['whenTrueText'] ?? '').toString(),
    );
    _whenFalseController = TextEditingController(
      text: (conditional['whenFalseText'] ?? '').toString(),
    );
    _whenTrueEmbeds = _normalizeEmbedsPayload(conditional['whenTrueEmbeds']);
    _whenFalseEmbeds = _normalizeEmbedsPayload(conditional['whenFalseEmbeds']);
    _whenTrueNormalComponents = Map<String, dynamic>.from(
      (conditional['whenTrueNormalComponents'] as Map?)
              ?.cast<String, dynamic>() ??
          const {},
    );
    _whenFalseNormalComponents = Map<String, dynamic>.from(
      (conditional['whenFalseNormalComponents'] as Map?)
              ?.cast<String, dynamic>() ??
          const {},
    );
    _whenTrueComponents = Map<String, dynamic>.from(
      (conditional['whenTrueComponents'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
    _whenFalseComponents = Map<String, dynamic>.from(
      (conditional['whenFalseComponents'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
    _whenTrueModal = Map<String, dynamic>.from(
      (conditional['whenTrueModal'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
    _whenFalseModal = Map<String, dynamic>.from(
      (conditional['whenFalseModal'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
    _bdfdScriptController = TextEditingController(
      text: (widget.initialWorkflow['bdfdScriptContent'] ?? '').toString(),
    );
    if (_workflowMode == _modeBdfd &&
        _bdfdScriptController.text.trim().isNotEmpty) {
      _bdfdCompileResult = _bdfdCompiler.compile(_bdfdScriptController.text);
    }
    _initialSnapshot = _buildResult();
  }

  bool get _isDirty {
    final current = _buildResult();
    return current.toString() != _initialSnapshot.toString();
  }

  void _revert() {
    final conditional = Map<String, dynamic>.from(
      (_initialSnapshot['conditional'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
    setState(() {
      _workflowMode =
          (_initialSnapshot['workflowMode']?.toString().toLowerCase() ==
                  _modeBdfd)
              ? _modeBdfd
              : _modeVisual;
      _autoDeferIfActions = _initialSnapshot['autoDeferIfActions'] != false;
      _visibility =
          (_initialSnapshot['visibility']?.toString().toLowerCase() ==
                  'ephemeral')
              ? 'ephemeral'
              : 'public';
      _onError = 'edit_error';
      _conditionEnabled = conditional['enabled'] == true;
      _variableController.text = (conditional['variable'] ?? '').toString();
      _bdfdScriptController.text =
          (_initialSnapshot['bdfdScriptContent'] ?? '').toString();
      _bdfdCompileResult = null;
      _whenTrueType = (conditional['whenTrueType'] ?? 'normal').toString();
      _whenFalseType = (conditional['whenFalseType'] ?? 'normal').toString();
      _whenTrueController.text = (conditional['whenTrueText'] ?? '').toString();
      _whenFalseController.text =
          (conditional['whenFalseText'] ?? '').toString();
      _whenTrueEmbeds = _normalizeEmbedsPayload(conditional['whenTrueEmbeds']);
      _whenFalseEmbeds = _normalizeEmbedsPayload(
        conditional['whenFalseEmbeds'],
      );
      _whenTrueNormalComponents = Map<String, dynamic>.from(
        (conditional['whenTrueNormalComponents'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
      _whenFalseNormalComponents = Map<String, dynamic>.from(
        (conditional['whenFalseNormalComponents'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
      _whenTrueComponents = Map<String, dynamic>.from(
        (conditional['whenTrueComponents'] as Map?)?.cast<String, dynamic>() ??
            const {},
      );
      _whenFalseComponents = Map<String, dynamic>.from(
        (conditional['whenFalseComponents'] as Map?)?.cast<String, dynamic>() ??
            const {},
      );
      _whenTrueModal = Map<String, dynamic>.from(
        (conditional['whenTrueModal'] as Map?)?.cast<String, dynamic>() ??
            const {},
      );
      _whenFalseModal = Map<String, dynamic>.from(
        (conditional['whenFalseModal'] as Map?)?.cast<String, dynamic>() ??
            const {},
      );
    });
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog.adaptive(
            title: const Text('Unsaved changes'),
            content: const Text('You have unsaved changes. Discard them?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Discard',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ),
            ],
          ),
    );
    return discard == true;
  }

  @override
  void dispose() {
    _variableController.dispose();
    _whenTrueController.dispose();
    _whenFalseController.dispose();
    _bdfdScriptController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildResult() {
    return {
      'workflowMode': _workflowMode,
      'autoDeferIfActions': _autoDeferIfActions,
      'visibility': _visibility,
      'onError': _onError,
      'bdfdScriptContent': _bdfdScriptController.text,
      'conditional': {
        'enabled': _conditionEnabled,
        'variable': _variableController.text.trim(),
        'whenTrueType': _whenTrueType,
        'whenFalseType': _whenFalseType,
        'whenTrueText': _whenTrueController.text,
        'whenFalseText': _whenFalseController.text,
        'whenTrueEmbeds': _whenTrueEmbeds,
        'whenFalseEmbeds': _whenFalseEmbeds,
        'whenTrueNormalComponents': _whenTrueNormalComponents,
        'whenFalseNormalComponents': _whenFalseNormalComponents,
        'whenTrueComponents': _whenTrueComponents,
        'whenFalseComponents': _whenFalseComponents,
        'whenTrueModal': _whenTrueModal,
        'whenFalseModal': _whenFalseModal,
      },
    };
  }

  List<VariableSuggestion> _queryVariableSuggestions(String query) {
    final normalized = query.trim().toLowerCase();
    final all = widget.variableSuggestions;
    if (all.isEmpty) {
      return const <VariableSuggestion>[];
    }

    final filtered = all
      .where((suggestion) {
        if (normalized.isEmpty) {
          return true;
        }
        return suggestion.name.toLowerCase().contains(normalized);
      })
      .toList(growable: false)..sort((a, b) => a.name.compareTo(b.name));

    return filtered.take(12).toList(growable: false);
  }

  Widget _buildConditionVariableSuggestions() {
    if (widget.variableSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _variableController,
      builder: (context, value, _) {
        // Strip leading (( so the user can type (( and still get results.
        var query = value.text;
        if (query.startsWith('((')) {
          query = query.substring(2);
        }
        // Strip trailing )) when the placeholder is already closed.
        if (query.endsWith('))')) {
          query = query.substring(0, query.length - 2);
        }
        final suggestions = _queryVariableSuggestions(query);
        if (suggestions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dynamic variable suggestions',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map((suggestion) {
                    return ActionChip(
                      label: Text('((${suggestion.name}))'),
                      onPressed: () {
                        _variableController.text = '((${suggestion.name}))';
                        _variableController.selection = TextSelection.collapsed(
                          offset: _variableController.text.length,
                        );
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        );
      },
    );
  }

  bool get _isBdfdMode => _workflowMode == _modeBdfd;

  List<BdfdCompileDiagnostic> get _bdfdDiagnostics =>
      _bdfdCompileResult?.diagnostics ?? const <BdfdCompileDiagnostic>[];

  bool get _hasBdfdCompileErrors => _bdfdDiagnostics.any(
    (d) => d.severity == BdfdCompileDiagnosticSeverity.error,
  );

  void _refreshBdfdCompileResult() {
    final source = _bdfdScriptController.text;
    if (source.trim().isEmpty) {
      setState(() => _bdfdCompileResult = null);
      return;
    }
    setState(() => _bdfdCompileResult = _bdfdCompiler.compile(source));
  }

  String _formatBdfdDiagnostic(BdfdCompileDiagnostic d) {
    final loc =
        (d.line != null && d.column != null) ? 'L${d.line}:C${d.column} ' : '';
    return '$loc${d.message}';
  }

  Widget _buildWorkflowModeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t('workflow_mode_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t('workflow_mode_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected: !_isBdfdMode,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_tree_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(AppStrings.t('workflow_mode_visual')),
                    ],
                  ),
                  onSelected: (_) {
                    setState(() => _workflowMode = _modeVisual);
                  },
                ),
                ChoiceChip(
                  selected: _isBdfdMode,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.code_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(AppStrings.t('workflow_mode_bdfd')),
                    ],
                  ),
                  onSelected: (_) {
                    setState(() => _workflowMode = _modeBdfd);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    _isBdfdMode
                        ? Colors.orange.shade50
                        : Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _isBdfdMode
                          ? Colors.orange.shade200
                          : Colors.blueGrey.shade100,
                ),
              ),
              child: Text(
                AppStrings.t(
                  _isBdfdMode
                      ? 'workflow_mode_bdfd_note'
                      : 'workflow_mode_visual_note',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color:
                      _isBdfdMode
                          ? Colors.orange.shade800
                          : Colors.blueGrey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBdfdWorkflowEditorCard(BuildContext context) {
    final diagnostics = _bdfdDiagnostics;
    final code = _bdfdScriptController.text;
    final isEmpty = code.trim().isEmpty;
    final preview =
        isEmpty
            ? AppStrings.t('bdfd_editor_tap_hint')
            : code.length > 200
            ? '${code.substring(0, 200)}…'
            : code;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t('workflow_bdfd_editor_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t('workflow_bdfd_editor_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute<String>(
                    builder:
                        (_) => BdfdEditorPage(
                          initialCode: _bdfdScriptController.text,
                          title: AppStrings.t('workflow_bdfd_editor_title'),
                        ),
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    _bdfdScriptController.text = result;
                    _refreshBdfdCompileResult();
                  });
                }
              },
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF263238),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade600),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.code, size: 16, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.t('cmd_bdfd_script_label'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preview,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color:
                            isEmpty
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                      ),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!isEmpty) ...[
              if (diagnostics.isEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.t('cmd_bdfd_diagnostics_clean'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        _hasBdfdCompileErrors
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          _hasBdfdCompileErrors
                              ? Colors.red.shade200
                              : Colors.orange.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t('cmd_bdfd_diagnostics_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...diagnostics.map((d) {
                        final isError =
                            d.severity == BdfdCompileDiagnosticSeverity.error;
                        final icon =
                            isError
                                ? Icons.error_outline
                                : Icons.warning_amber_rounded;
                        final label = AppStrings.t(
                          isError
                              ? 'cmd_bdfd_diagnostics_error'
                              : 'cmd_bdfd_diagnostics_warning',
                        );
                        final color =
                            isError
                                ? Colors.red.shade800
                                : Colors.orange.shade900;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, size: 16, color: color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$label: ${_formatBdfdDiagnostic(d)}',
                                  style: TextStyle(fontSize: 12, color: color),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponseTypeSelector({
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    Widget chip({
      required String value,
      required String label,
      required IconData icon,
    }) {
      return ChoiceChip(
        selected: selected == value,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        onSelected: (_) => onChanged(value),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(value: 'normal', label: 'Normal', icon: Icons.message),
        chip(
          value: 'componentV2',
          label: 'Component',
          icon: Icons.dashboard_customize,
        ),
        chip(value: 'modal', label: 'Modal', icon: Icons.web_asset),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 420;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscardIfDirty()) {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Response Workflow${_isDirty ? ' •' : ''}'),
          actions: [
            if (_isDirty)
              IconButton(
                tooltip: 'Revert all changes',
                onPressed: _revert,
                icon: const Icon(Icons.undo),
              ),
            if (compact)
              IconButton(
                tooltip: 'Save',
                onPressed: () => Navigator.pop(context, _buildResult()),
                icon: const Icon(Icons.check),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(context, _buildResult()),
                child: const Text('Save'),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(compact ? 12 : 16),
            children: [
              _buildWorkflowModeCard(context),
              const SizedBox(height: 12),
              if (_workflowMode == _modeBdfd) ...[
                _buildBdfdWorkflowEditorCard(context),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deferred reply',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto defer if actions exist'),
                          subtitle: const Text(
                            'Acknowledge quickly, execute actions, then edit final response.',
                          ),
                          value: _autoDeferIfActions,
                          onChanged: (value) {
                            setState(() {
                              _autoDeferIfActions = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _visibility,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Visibility',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'public',
                              child: Text('Public'),
                            ),
                            DropdownMenuItem(
                              value: 'ephemeral',
                              child: Text(
                                'Ephemeral (only command user)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _visibility = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.info_outline),
                          title: Text('Error policy'),
                          subtitle: Text(
                            'When an action fails, edit the deferred message with an error.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conditional response (MVP)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable condition'),
                          subtitle: const Text(
                            'If variable exists and is not empty => use THEN text, otherwise ELSE text.',
                          ),
                          value: _conditionEnabled,
                          onChanged: (value) {
                            setState(() {
                              _conditionEnabled = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _variableController,
                          decoration: const InputDecoration(
                            labelText: 'Variable key (ex: opts.userId)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildConditionVariableSuggestions(),
                        const SizedBox(height: 16),
                        const Text(
                          'THEN Response',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildResponseTypeSelector(
                          selected: _whenTrueType,
                          onChanged: (value) {
                            setState(() {
                              _whenTrueType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_whenTrueType == 'normal') ...[
                          VariableTextField(
                            label: 'THEN response text (optional)',
                            controller: _whenTrueController,
                            maxLines: 3,
                            suggestions: widget.variableSuggestions,
                            emojiSuggestions: widget.emojiSuggestions,
                            onChanged: (_) {
                              if (mounted) {
                                setState(() {});
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          ResponseEmbedsEditor(
                            embeds: _whenTrueEmbeds,
                            variableSuggestions: widget.variableSuggestions,
                            emojiSuggestions: widget.emojiSuggestions,
                            onChanged: (embeds) {
                              setState(() {
                                _whenTrueEmbeds = embeds;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          NormalComponentEditorWidget(
                            definition: ComponentV2Definition.fromJson(
                              _whenTrueNormalComponents,
                            ),
                            onChanged: (def) {
                              setState(() {
                                _whenTrueNormalComponents = def.toJson();
                              });
                            },
                            variableSuggestions: widget.variableSuggestions,
                            botIdForConfig: widget.botIdForConfig,
                          ),
                        ] else if (_whenTrueType == 'componentV2') ...[
                          ComponentV2EditorWidget(
                            definition: ComponentV2Definition.fromJson(
                              _whenTrueComponents,
                            ),
                            onChanged: (def) {
                              setState(() {
                                _whenTrueComponents = def.toJson();
                              });
                            },
                            variableSuggestions: widget.variableSuggestions,
                            botIdForConfig: widget.botIdForConfig,
                          ),
                        ] else if (_whenTrueType == 'modal') ...[
                          ModalBuilderWidget(
                            modal: ModalDefinition.fromJson(_whenTrueModal),
                            onChanged: (def) {
                              setState(() {
                                _whenTrueModal = def.toJson();
                              });
                            },
                            variableSuggestions: widget.variableSuggestions,
                            botIdForConfig: widget.botIdForConfig,
                          ),
                        ],
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'ELSE Response',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildResponseTypeSelector(
                          selected: _whenFalseType,
                          onChanged: (value) {
                            setState(() {
                              _whenFalseType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_whenFalseType == 'normal') ...[
                          VariableTextField(
                            label: 'ELSE response text (optional)',
                            controller: _whenFalseController,
                            maxLines: 3,
                            suggestions: widget.variableSuggestions,
                            emojiSuggestions: widget.emojiSuggestions,
                            onChanged: (_) {
                              if (mounted) {
                                setState(() {});
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          ResponseEmbedsEditor(
                            embeds: _whenFalseEmbeds,
                            variableSuggestions: widget.variableSuggestions,
                            emojiSuggestions: widget.emojiSuggestions,
                            onChanged: (embeds) {
                              setState(() {
                                _whenFalseEmbeds = embeds;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          NormalComponentEditorWidget(
                            definition: ComponentV2Definition.fromJson(
                              _whenFalseNormalComponents,
                            ),
                            onChanged: (def) {
                              setState(() {
                                _whenFalseNormalComponents = def.toJson();
                              });
                            },
                            variableSuggestions: widget.variableSuggestions,
                            botIdForConfig: widget.botIdForConfig,
                          ),
                        ] else if (_whenFalseType == 'componentV2') ...[
                          ComponentV2EditorWidget(
                            definition: ComponentV2Definition.fromJson(
                              _whenFalseComponents,
                            ),
                            onChanged: (def) {
                              setState(() {
                                _whenFalseComponents = def.toJson();
                              });
                            },
                            variableSuggestions: widget.variableSuggestions,
                            botIdForConfig: widget.botIdForConfig,
                          ),
                        ] else if (_whenFalseType == 'modal') ...[
                          ModalBuilderWidget(
                            modal: ModalDefinition.fromJson(_whenFalseModal),
                            onChanged: (def) {
                              setState(() {
                                _whenFalseModal = def.toJson();
                              });
                            },
                            variableSuggestions: widget.variableSuggestions,
                            botIdForConfig: widget.botIdForConfig,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ], // end of visual mode else branch
            ],
          ),
        ),
      ),
    );
  }
}
