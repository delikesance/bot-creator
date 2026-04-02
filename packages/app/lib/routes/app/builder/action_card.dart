import 'dart:convert';

import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator/widgets/bdfd_editor_page.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/darcula.dart';
import 'package:flutter/material.dart';
import '../../../types/action.dart' show BotCreatorActionType;
import '../../../types/component.dart';
import '../../../routes/app/workflows.page.dart';
import '../../../routes/app/global.variables.dart';
import '../../../main.dart';
import '../../../utils/i18n.dart';
import '../../../widgets/component_v2_builder/component_v2_editor.dart';
import '../../../widgets/component_v2_builder/modal_builder.dart';
import '../../../widgets/component_v2_builder/normal_component_editor.dart';
import '../../../types/app_emoji.dart';
import '../../../widgets/variable_text_field.dart';
import '../../../widgets/response_embeds_editor.dart';
import 'action_types.dart';
import 'action_type_extension.dart';
import 'package:http/http.dart' as http;

enum _ActionCardMenuAction { moveUp, moveDown, remove }

class ActionCard extends StatelessWidget {
  static const List<String> _conditionOperators = <String>[
    'equals',
    'notEquals',
    'contains',
    'notContains',
    'startsWith',
    'endsWith',
    'greaterThan',
    'lessThan',
    'greaterOrEqual',
    'lessOrEqual',
    'isEmpty',
    'isNotEmpty',
    'matches',
  ];

  final ActionItem action;
  final int index;
  final int totalCount;
  final String actionKey;
  final List<VariableSuggestion> variableSuggestions;
  final List<AppEmoji>? emojiSuggestions;
  final int Function(String paramKey) fieldRefreshVersionOf;
  final Function(String key, dynamic value) onSuggestionSelected;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final Function(String key, dynamic value) onParameterChanged;
  final String? botIdForConfig;

  /// Opens a sub-action builder for nested blocks (IF/ELSE). Provided by the
  /// parent [ActionsBuilderPage]. When null, nested editing is disabled.
  final Future<List<Map<String, dynamic>>?> Function(
    List<Map<String, dynamic>> current,
    List<VariableSuggestion> suggestions,
  )?
  onEditNestedActions;

  const ActionCard({
    super.key,
    required this.action,
    required this.index,
    required this.totalCount,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
    required this.onParameterChanged,
    required this.onSuggestionSelected,
    required this.fieldRefreshVersionOf,
    required this.actionKey,
    required this.variableSuggestions,
    this.emojiSuggestions,
    this.botIdForConfig,
    this.onEditNestedActions,
  });

  Key _parameterInputKey(String paramKey) {
    final version = fieldRefreshVersionOf(paramKey);
    return ValueKey('param-input-${action.id}-$paramKey-v$version');
  }

  @override
  Widget build(BuildContext context) {
    final compactHeader = MediaQuery.of(context).size.width < 420;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(action.type.icon, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.type.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Action ${index + 1}/$totalCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (compactHeader)
                  PopupMenuButton<_ActionCardMenuAction>(
                    tooltip: 'Action options',
                    onSelected: (value) async {
                      if (value == _ActionCardMenuAction.moveUp &&
                          onMoveUp != null) {
                        onMoveUp!();
                      } else if (value == _ActionCardMenuAction.moveDown &&
                          onMoveDown != null) {
                        onMoveDown!();
                      } else if (value == _ActionCardMenuAction.remove) {
                        await _confirmAndRemoveAction(context);
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem<_ActionCardMenuAction>(
                            value: _ActionCardMenuAction.moveUp,
                            enabled: onMoveUp != null,
                            child: const Row(
                              children: [
                                Icon(Icons.arrow_upward),
                                SizedBox(width: 8),
                                Text('Move up'),
                              ],
                            ),
                          ),
                          PopupMenuItem<_ActionCardMenuAction>(
                            value: _ActionCardMenuAction.moveDown,
                            enabled: onMoveDown != null,
                            child: const Row(
                              children: [
                                Icon(Icons.arrow_downward),
                                SizedBox(width: 8),
                                Text('Move down'),
                              ],
                            ),
                          ),
                          PopupMenuItem<_ActionCardMenuAction>(
                            value: _ActionCardMenuAction.remove,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remove action',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                  )
                else ...[
                  IconButton(
                    onPressed: onMoveUp,
                    tooltip: 'Move up',
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    onPressed: onMoveDown,
                    tooltip: 'Move down',
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  IconButton(
                    onPressed: () => _confirmAndRemoveAction(context),
                    tooltip: 'Remove action',
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (index > 0 || index < totalCount - 1)
              Text(
                'Tip: use arrows to change action order.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            if (index > 0 || index < totalCount - 1) const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('action-key-${action.id}'),
              initialValue: actionKey,
              decoration: const InputDecoration(
                labelText: 'Action Key',
                border: OutlineInputBorder(),
              ),
              onChanged: (newValue) => onParameterChanged('key', newValue),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enabled'),
                    value: action.enabled,
                    onChanged:
                        (value) => onParameterChanged('__enabled__', value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: action.onErrorMode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'On Error',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'stop', child: Text('Stop')),
                      DropdownMenuItem(
                        value: 'continue',
                        child: Text('Continue'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onParameterChanged('__onErrorMode__', value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (action.type == BotCreatorActionType.httpRequest)
              ..._buildHttpRequestFields(context)
            else
              ...action.type.parameterDefinitions
                  .where(_shouldShowParameter)
                  .map((paramDef) {
                    final currentValue = action.parameters[paramDef.key];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildParameterField(
                        context,
                        paramDef,
                        currentValue,
                      ),
                    );
                  }),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndRemoveAction(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog.adaptive(
            title: const Text('Remove action'),
            content: const Text(
              'This action will be removed from the workflow. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'Remove',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      onRemove();
    }
  }

  // Parses a JSON response and returns a flat list of JSON Path dot notations.
  // Includes the root path (`$`) so top-level arrays can be selected directly.
  List<String> _extractPaths(dynamic data, [String currentPath = '\$']) {
    List<String> paths =
        currentPath == r'$' ? <String>[currentPath] : <String>[];
    if (data is Map) {
      for (final key in data.keys) {
        final newPath = '$currentPath.$key';
        paths.add(newPath);
        paths.addAll(_extractPaths(data[key], newPath));
      }
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        final newPath = '$currentPath[$i]';
        paths.add(newPath);
        paths.addAll(_extractPaths(data[i], newPath));
      }
    }
    return paths;
  }

  void _showTestRequestModal(BuildContext context) {
    bool isLoading = true;
    int? statusCode;
    String? responseBody;
    String? errorMessage;
    List<String>? newPaths;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1e1e1e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (isLoading) {
              // Fire the request on first build frame using Futures
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  final urlStr = action.parameters['url']?.toString() ?? '';
                  if (urlStr.isEmpty) throw 'Please provide a valid URL.';

                  // Fallback for placeholders: the request might just fail, but we'll try to execute it as-is
                  final uri = Uri.parse(urlStr);
                  final method =
                      (action.parameters['method']?.toString() ?? 'GET')
                          .toUpperCase();

                  final rawHeadersMap = action.parameters['headers'];
                  final Map<String, String> requestHeaders = {};
                  if (rawHeadersMap is Map) {
                    for (final entry in rawHeadersMap.entries) {
                      requestHeaders[entry.key.toString()] =
                          entry.value?.toString() ?? '';
                    }
                  }

                  http.Response response;
                  if (method == 'POST') {
                    final dynamic bodyData =
                        action.parameters['bodyMode'] == 'json'
                            ? jsonEncode(action.parameters['bodyJson'])
                            : action.parameters['bodyText'];
                    if (action.parameters['bodyMode'] == 'json' &&
                        !requestHeaders.containsKey('Content-Type')) {
                      requestHeaders['Content-Type'] = 'application/json';
                    }
                    response = await http.post(
                      uri,
                      headers: requestHeaders,
                      body: bodyData,
                    );
                  } else if (method == 'PUT') {
                    final dynamic bodyData =
                        action.parameters['bodyMode'] == 'json'
                            ? jsonEncode(action.parameters['bodyJson'])
                            : action.parameters['bodyText'];
                    if (action.parameters['bodyMode'] == 'json' &&
                        !requestHeaders.containsKey('Content-Type')) {
                      requestHeaders['Content-Type'] = 'application/json';
                    }
                    response = await http.put(
                      uri,
                      headers: requestHeaders,
                      body: bodyData,
                    );
                  } else if (method == 'PATCH') {
                    final dynamic bodyData =
                        action.parameters['bodyMode'] == 'json'
                            ? jsonEncode(action.parameters['bodyJson'])
                            : action.parameters['bodyText'];
                    if (action.parameters['bodyMode'] == 'json' &&
                        !requestHeaders.containsKey('Content-Type')) {
                      requestHeaders['Content-Type'] = 'application/json';
                    }
                    response = await http.patch(
                      uri,
                      headers: requestHeaders,
                      body: bodyData,
                    );
                  } else if (method == 'DELETE') {
                    response = await http.delete(uri, headers: requestHeaders);
                  } else {
                    response = await http.get(uri, headers: requestHeaders);
                  }

                  statusCode = response.statusCode;
                  responseBody = response.body;

                  try {
                    final decodedJson = jsonDecode(responseBody!);
                    newPaths = _extractPaths(decodedJson);
                    // Update parameter so the extractJsonPath combobox actually uses the new paths
                    if (newPaths != null && newPaths!.isNotEmpty) {
                      onParameterChanged('_cachedJsonPaths', newPaths!);
                    }
                  } catch (_) {
                    // Not valid JSON to parse paths from, ignore.
                  }

                  setModalState(() => isLoading = false);
                } catch (e) {
                  setModalState(() {
                    isLoading = false;
                    errorMessage = e.toString();
                  });
                }
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, controller) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Test Request Results',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.grey),
                      if (isLoading)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (errorMessage != null)
                        Expanded(
                          child: SingleChildScrollView(
                            controller: controller,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.5),
                                ),
                              ),
                              child: SelectableText(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    statusCode != null &&
                                            statusCode! >= 200 &&
                                            statusCode! < 300
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      statusCode != null &&
                                              statusCode! >= 200 &&
                                              statusCode! < 300
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                              child: Text(
                                'Status: $statusCode',
                                style: TextStyle(
                                  color:
                                      statusCode != null &&
                                              statusCode! >= 200 &&
                                              statusCode! < 300
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (newPaths != null && newPaths!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: Text(
                                  '${newPaths!.length} paths parsed',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Response Body (Raw):',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xff2b2b2b),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: SingleChildScrollView(
                              controller: controller,
                              child: HighlightView(
                                responseBody ?? '',
                                language: 'json',
                                theme: darculaTheme,
                                textStyle: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _buildHttpRequestFields(BuildContext context) {
    final defs = action.type.parameterDefinitions;
    ParameterDefinition? defFor(String key) => defs
        .cast<ParameterDefinition?>()
        .firstWhere((d) => d?.key == key, orElse: () => null);

    Widget fieldFor(String key) {
      final pd = defFor(key);
      if (pd == null) return const SizedBox.shrink();
      final currentValue = action.parameters[pd.key];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildParameterField(context, pd, currentValue),
      );
    }

    final method =
        (action.parameters['method']?.toString() ?? 'GET').toUpperCase();
    final bodyMode =
        (action.parameters['bodyMode']?.toString() ?? 'json').toLowerCase();
    final showBody = method != 'GET' && method != 'HEAD';

    return [
      fieldFor('url'),
      fieldFor('method'),
      fieldFor('headers'),
      if (showBody) ...[
        fieldFor('bodyMode'),
        if (bodyMode == 'text') fieldFor('bodyText') else fieldFor('bodyJson'),
      ],
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          title: const Text('Store results in global variables'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 4),
          children: [
            fieldFor('saveBodyToGlobalVar'),
            fieldFor('saveStatusToGlobalVar'),
          ],
        ),
      ),
      fieldFor('extractJsonPath'),
      Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showTestRequestModal(context),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send Test Request & Auto-Detect Routes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.blueAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    ];
  }

  /// Whether a parameter should be rendered based on the current action state.
  /// Used to toggle between normal message fields and componentV2 fields.
  bool _shouldShowParameter(ParameterDefinition paramDef) {
    final visibleWhen = paramDef.visibleWhen;
    if (visibleWhen != null && visibleWhen.isNotEmpty) {
      for (final entry in visibleWhen.entries) {
        final current =
            (action.parameters[entry.key] ?? '')
                .toString()
                .trim()
                .toLowerCase();
        final allowed =
            entry.value
                .map((value) => value.trim().toLowerCase())
                .where((value) => value.isNotEmpty)
                .toSet();
        if (allowed.isNotEmpty && !allowed.contains(current)) {
          return false;
        }
      }
    }

    if (action.type == BotCreatorActionType.sendMessage) {
      final mode = (action.parameters['messageMode'] ?? 'normal').toString();
      if (mode == 'componentV2') {
        // In componentV2 mode, hide normal-message fields.
        if (paramDef.key == 'embeds' || paramDef.key == 'components') {
          return false;
        }
      } else {
        // In normal mode, hide componentV2 field.
        if (paramDef.key == 'componentV2') return false;
      }
    }
    return true;
  }

  String _inputModeKey(String parameterKey) => '${parameterKey}InputMode';

  bool _supportsDynamicInputMode(ParameterType type) {
    return type == ParameterType.multiSelect ||
        type == ParameterType.boolean ||
        type == ParameterType.userId ||
        type == ParameterType.channelId ||
        type == ParameterType.messageId ||
        type == ParameterType.roleId;
  }

  String _resolveInputMode(ParameterDefinition paramDef) {
    final stored =
        (action.parameters[_inputModeKey(paramDef.key)] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    return stored == 'dynamic' ? 'dynamic' : 'literal';
  }

  bool _coerceBoolValue(dynamic value, bool fallback) {
    if (value is bool) {
      return value;
    }
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return fallback;
  }

  Widget _buildInputModeToggle(
    ParameterDefinition paramDef,
    String currentMode,
  ) {
    if (!_supportsDynamicInputMode(paramDef.type)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Literal'),
            selected: currentMode == 'literal',
            onSelected:
                (_) =>
                    onParameterChanged(_inputModeKey(paramDef.key), 'literal'),
          ),
          ChoiceChip(
            label: const Text('Dynamic'),
            selected: currentMode == 'dynamic',
            onSelected:
                (_) =>
                    onParameterChanged(_inputModeKey(paramDef.key), 'dynamic'),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterField(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    final inputMode = _resolveInputMode(paramDef);
    final useDynamicInput =
        _supportsDynamicInputMode(paramDef.type) && inputMode == 'dynamic';

    switch (paramDef.type) {
      case ParameterType.boolean:
        if (useDynamicInput) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatParameterName(paramDef.key),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              _buildInputModeToggle(paramDef, inputMode),
              VariableTextField(
                key: _parameterInputKey(paramDef.key),
                label: 'Expression',
                initialValue:
                    (currentValue ?? paramDef.defaultValue).toString(),
                hint:
                    _localizeHint(paramDef.hint) ??
                    'true/false or ((variable))',
                suggestions: variableSuggestions,
                onChanged:
                    (newValue) => onParameterChanged(paramDef.key, newValue),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputModeToggle(paramDef, inputMode),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatParameterName(paramDef.key),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Switch(
                  value: _coerceBoolValue(
                    currentValue,
                    _coerceBoolValue(paramDef.defaultValue, false),
                  ),
                  onChanged:
                      (newValue) => onParameterChanged(paramDef.key, newValue),
                ),
              ],
            ),
          ],
        );

      case ParameterType.number:
        return _NumberParameterField(
          paramDef: paramDef,
          currentValue: currentValue,
          onParameterChanged: onParameterChanged,
          variableSuggestions: variableSuggestions,
          paramKey: paramDef.key,
        );

      case ParameterType.list:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatParameterName(paramDef.key),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed:
                      () => _showListEditor(context, paramDef, currentValue),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentValue is List && currentValue.isNotEmpty)
                    ...currentValue.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${entry.key + 1}. ${entry.value}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    })
                  else
                    Text(
                      'No items - tap edit to add',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

      case ParameterType.elseIfBranches:
        return _buildElseIfBranchesField(paramDef, currentValue);

      case ParameterType.multiSelect:
        if (useDynamicInput) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatParameterName(paramDef.key),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              _buildInputModeToggle(paramDef, inputMode),
              VariableTextField(
                key: _parameterInputKey(paramDef.key),
                label: 'Expression',
                initialValue:
                    (currentValue ?? paramDef.defaultValue).toString(),
                hint:
                    _localizeHint(paramDef.hint) ??
                    'Dynamic value (supports ((...)))',
                suggestions: variableSuggestions,
                onChanged:
                    (newValue) => onParameterChanged(paramDef.key, newValue),
              ),
            ],
          );
        }
        final options = paramDef.options ?? const <String>[];
        final rawValue = (currentValue ?? paramDef.defaultValue).toString();
        final selectedValue =
            options.contains(rawValue)
                ? rawValue
                : (options.isNotEmpty ? options.first : rawValue);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            _buildInputModeToggle(paramDef, inputMode),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: selectedValue,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: _localizeHint(paramDef.hint),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items:
                  paramDef.options?.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(option, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.duration:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              decoration: InputDecoration(
                hintText: _localizeHint(paramDef.hint) ?? 'e.g., 5m, 1h, 30s',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixText: 's/m/h/d',
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.url:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: _localizeHint(paramDef.hint) ?? 'https://example.com',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.link, size: 20),
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.userId:
      case ParameterType.channelId:
      case ParameterType.messageId:
      case ParameterType.roleId:
        if (useDynamicInput) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatParameterName(paramDef.key),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              _buildInputModeToggle(paramDef, inputMode),
              VariableTextField(
                key: _parameterInputKey(paramDef.key),
                label: 'Expression',
                initialValue:
                    (currentValue ?? paramDef.defaultValue).toString(),
                hint:
                    _localizeHint(paramDef.hint) ??
                    'Dynamic ${paramDef.type.name} (supports ((...)))',
                suggestions: variableSuggestions,
                onChanged:
                    (newValue) => onParameterChanged(paramDef.key, newValue),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            _buildInputModeToggle(paramDef, inputMode),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              decoration: InputDecoration(
                hintText:
                    _localizeHint(paramDef.hint) ??
                    'Enter ${paramDef.type.name}',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(_getIconForIdType(paramDef.type), size: 20),
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
          ],
        );

      case ParameterType.emoji:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: _parameterInputKey(paramDef.key),
                    initialValue:
                        (currentValue ?? paramDef.defaultValue).toString(),
                    decoration: InputDecoration(
                      hintText:
                          _localizeHint(paramDef.hint) ??
                          'Enter emoji or :name:',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.emoji_emotions, size: 20),
                    ),
                    onChanged:
                        (newValue) =>
                            onParameterChanged(paramDef.key, newValue),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    currentValue?.toString() ?? '😀',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.color:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: _parameterInputKey(paramDef.key),
                    initialValue:
                        (currentValue ?? paramDef.defaultValue).toString(),
                    decoration: InputDecoration(
                      hintText:
                          _localizeHint(paramDef.hint) ??
                          '#FFFFFF or rgb(255,255,255)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.color_lens, size: 20),
                    ),
                    onChanged:
                        (newValue) =>
                            onParameterChanged(paramDef.key, newValue),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap:
                      () => _showColorPicker(context, paramDef, currentValue),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _parseColor(currentValue?.toString() ?? '#000000'),
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.map:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatParameterName(paramDef.key),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed:
                      () => _showMapEditor(context, paramDef, currentValue),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildMapPreview(paramDef.key, currentValue),
            ),
          ],
        );

      case ParameterType.embeds:
        final embeds =
            (currentValue is List)
                ? List<Map<String, dynamic>>.from(
                  currentValue.whereType<Map>().map(
                    (embed) => Map<String, dynamic>.from(
                      embed.map(
                        (key, value) => MapEntry(key.toString(), value),
                      ),
                    ),
                  ),
                )
                : <Map<String, dynamic>>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ResponseEmbedsEditor(
              embeds: embeds,
              variableSuggestions: variableSuggestions,
              emojiSuggestions: emojiSuggestions,
              onChanged: (updated) {
                onParameterChanged(paramDef.key, updated);
              },
            ),
          ],
        );

      case ParameterType.nestedActions:
        final nestedList =
            currentValue is List
                ? currentValue
                    .whereType<Map>()
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList()
                : <Map<String, dynamic>>[];
        final blockLabel =
            _localizeHint(paramDef.hint) ?? _formatParameterName(paramDef.key);
        final blockColor =
            paramDef.key == 'thenActions' ? Colors.green : Colors.orange;

        Future<void> openNestedEditor() async {
          if (onEditNestedActions == null) {
            return;
          }

          final result = await onEditNestedActions!(
            nestedList,
            variableSuggestions,
          );
          if (result != null) {
            onParameterChanged(paramDef.key, result);
          }
        }

        return _buildNestedActionsEditor(
          nestedList: nestedList,
          blockLabel: blockLabel,
          blockColor: blockColor,
          icon:
              paramDef.key == 'thenActions'
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
          onEdit: openNestedEditor,
        );

      case ParameterType.componentV2:
        final compDef =
            currentValue is Map<String, dynamic>
                ? ComponentV2Definition.fromJson(currentValue)
                : currentValue is Map
                ? ComponentV2Definition.fromJson(
                  Map<String, dynamic>.from(
                    currentValue.map((k, v) => MapEntry(k.toString(), v)),
                  ),
                )
                : ComponentV2Definition();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ComponentV2EditorWidget(
              definition: compDef,
              variableSuggestions: variableSuggestions,
              botIdForConfig: botIdForConfig,
              onChanged: (updated) {
                onParameterChanged(paramDef.key, updated.toJson());
              },
            ),
          ],
        );

      case ParameterType.normalComponents:
        final compDef =
            currentValue is Map<String, dynamic>
                ? ComponentV2Definition.fromJson(currentValue)
                : currentValue is Map
                ? ComponentV2Definition.fromJson(
                  Map<String, dynamic>.from(
                    currentValue.map((k, v) => MapEntry(k.toString(), v)),
                  ),
                )
                : ComponentV2Definition();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            NormalComponentEditorWidget(
              definition: compDef,
              variableSuggestions: variableSuggestions,
              botIdForConfig: botIdForConfig,
              onChanged: (updated) {
                onParameterChanged(paramDef.key, updated.toJson());
              },
            ),
          ],
        );

      case ParameterType.modalDefinition:
        final modalDef =
            currentValue is Map<String, dynamic>
                ? ModalDefinition.fromJson(currentValue)
                : currentValue is Map
                ? ModalDefinition.fromJson(
                  Map<String, dynamic>.from(
                    currentValue.map((k, v) => MapEntry(k.toString(), v)),
                  ),
                )
                : ModalDefinition();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ModalBuilderWidget(
              modal: modalDef,
              variableSuggestions: variableSuggestions,
              botIdForConfig: botIdForConfig,
              onChanged: (updated) {
                onParameterChanged(paramDef.key, updated.toJson());
              },
            ),
          ],
        );

      case ParameterType.bdfdScript:
        return _BdfdScriptParameterField(
          currentValue: (currentValue ?? paramDef.defaultValue).toString(),
          hint: _localizeHint(paramDef.hint),
          onChanged: (newValue) => onParameterChanged(paramDef.key, newValue),
        );

      default: // ParameterType.string and ParameterType.url and others
        if (paramDef.type == ParameterType.string &&
            paramDef.key == 'workflowName' &&
            botIdForConfig != null &&
            botIdForConfig!.trim().isNotEmpty) {
          return _WorkflowNameParameterField(
            label: _formatParameterName(paramDef.key),
            currentValue:
                (currentValue ?? paramDef.defaultValue).toString().trim(),
            hint: _localizeHint(paramDef.hint) ?? 'Saved workflow name',
            botId: botIdForConfig!,
            onChanged: (value) {
              onParameterChanged(paramDef.key, value);
            },
          );
        }

        if (botIdForConfig != null &&
            botIdForConfig!.trim().isNotEmpty &&
            _isVariableKeyParameter(action.type, paramDef.key)) {
          final currentScope = (action.parameters['scope'] ?? '').toString();
          final usesScopedKeys =
              action.type == BotCreatorActionType.setScopedVariable ||
              action.type == BotCreatorActionType.getScopedVariable ||
              action.type == BotCreatorActionType.removeScopedVariable ||
              action.type == BotCreatorActionType.renameScopedVariable ||
              action.type == BotCreatorActionType.listScopedVariableIndex ||
              action.type == BotCreatorActionType.appendArrayElement ||
              action.type == BotCreatorActionType.removeArrayElement;

          return _VariableKeyParameterField(
            label: _formatParameterName(paramDef.key),
            currentValue: (currentValue ?? paramDef.defaultValue).toString(),
            hint: _localizeHint(paramDef.hint) ?? 'Select variable key',
            botId: botIdForConfig!,
            scope: currentScope,
            scoped: usesScopedKeys,
            onChanged: (value) {
              onParameterChanged(paramDef.key, value.trim());
            },
          );
        }

        if (paramDef.key == 'extractJsonPath' &&
            action.type == BotCreatorActionType.httpRequest) {
          final cachedPaths =
              action.parameters['_cachedJsonPaths'] as List<dynamic>? ?? [];
          final stringPaths = cachedPaths.map((e) => e.toString()).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatParameterName(paramDef.key),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return stringPaths;
                  }
                  return stringPaths.where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (String selection) {
                  onParameterChanged(paramDef.key, selection);
                },
                fieldViewBuilder: (
                  context,
                  controller,
                  focusNode,
                  onEditingComplete,
                ) {
                  if (controller.text != (currentValue?.toString() ?? '') &&
                      controller.text.isEmpty) {
                    controller.text = currentValue?.toString() ?? '';
                  }
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete: () {
                      onParameterChanged(paramDef.key, controller.text);
                      onEditingComplete();
                    },
                    onChanged: (val) {
                      onParameterChanged(paramDef.key, val);
                    },
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: _localizeHint(paramDef.hint),
                      suffixIcon:
                          stringPaths.isNotEmpty
                              ? const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.blueAccent,
                              )
                              : null,
                    ),
                  );
                },
              ),
            ],
          );
        }

        if (action.type == BotCreatorActionType.respondWithAutocomplete &&
            const <String>{
              'items',
              'labelTemplate',
              'valueTemplate',
            }.contains(paramDef.key)) {
          return VariableTextField(
            key: _parameterInputKey(paramDef.key),
            label: _formatParameterName(paramDef.key),
            initialValue: (currentValue ?? paramDef.defaultValue).toString(),
            hint: _localizeHint(paramDef.hint),
            suggestions: variableSuggestions,
            onChanged: (newValue) => onParameterChanged(paramDef.key, newValue),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _formatParameterName(paramDef.key),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (paramDef.required)
                  const Text(
                    ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              maxLines: paramDef.key.toLowerCase().contains('content') ? 3 : 1,
              decoration: InputDecoration(
                hintText: _localizeHint(paramDef.hint),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );
    }
  }

  Widget _buildElseIfBranchesField(
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    final branches = _normalizeElseIfBranches(currentValue);
    final label =
        _localizeHint(paramDef.hint) ?? _formatParameterName(paramDef.key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                final updated = <Map<String, dynamic>>[
                  ...branches,
                  <String, dynamic>{
                    'condition.variable': '',
                    'condition.operator': 'equals',
                    'condition.value': '',
                    'actions': <Map<String, dynamic>>[],
                  },
                ];
                onParameterChanged(paramDef.key, updated);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add ELSE IF'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (branches.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.06),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No ELSE IF branches yet. Add one to test more conditions before ELSE.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          )
        else
          ...branches.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == branches.length - 1 ? 0 : 12,
              ),
              child: _buildElseIfBranchCard(
                paramKey: paramDef.key,
                branchIndex: entry.key,
                branch: entry.value,
                branches: branches,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildElseIfBranchCard({
    required String paramKey,
    required int branchIndex,
    required Map<String, dynamic> branch,
    required List<Map<String, dynamic>> branches,
  }) {
    final blockColor = Colors.amber.shade700;
    final variableValue = (branch['condition.variable'] ?? '').toString();
    final operatorValue = (branch['condition.operator'] ?? 'equals').toString();
    final conditionValue = (branch['condition.value'] ?? '').toString();
    final nestedActions = _normalizeNestedActions(branch['actions']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: blockColor.withValues(alpha: 0.05),
        border: Border.all(color: blockColor.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, color: blockColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ELSE IF ${branchIndex + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: blockColor,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove ELSE IF',
                onPressed: () {
                  final updated = _cloneElseIfBranches(branches)
                    ..removeAt(branchIndex);
                  onParameterChanged(paramKey, updated);
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 760;
              final variableField = VariableTextField(
                key: ValueKey('elseif-$actionKey-$branchIndex-variable'),
                label: 'Condition Variable',
                initialValue: variableValue,
                hint: 'Use ((variableName)) or a runtime value',
                suggestions: variableSuggestions,
                onChanged: (value) {
                  final updated = _cloneElseIfBranches(branches);
                  updated[branchIndex]['condition.variable'] = value;
                  onParameterChanged(paramKey, updated);
                },
              );
              final operatorField = SizedBox(
                width: isCompact ? double.infinity : 170,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('elseif-$actionKey-$branchIndex-operator'),
                  initialValue:
                      _conditionOperators.contains(operatorValue)
                          ? operatorValue
                          : 'equals',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Operator',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _conditionOperators
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option,
                          child: Text(option, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    final updated = _cloneElseIfBranches(branches);
                    updated[branchIndex]['condition.operator'] =
                        value ?? 'equals';
                    onParameterChanged(paramKey, updated);
                  },
                ),
              );
              final valueField = VariableTextField(
                key: ValueKey('elseif-$actionKey-$branchIndex-value'),
                label: 'Condition Value',
                initialValue: conditionValue,
                hint: 'Value to compare against',
                suggestions: variableSuggestions,
                onChanged: (value) {
                  final updated = _cloneElseIfBranches(branches);
                  updated[branchIndex]['condition.value'] = value;
                  onParameterChanged(paramKey, updated);
                },
              );

              if (isCompact) {
                return Column(
                  children: [
                    variableField,
                    const SizedBox(height: 8),
                    operatorField,
                    const SizedBox(height: 8),
                    valueField,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: variableField),
                  const SizedBox(width: 8),
                  operatorField,
                  const SizedBox(width: 8),
                  Expanded(flex: 4, child: valueField),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          _buildNestedActionsEditor(
            nestedList: nestedActions,
            blockLabel: 'ELSE IF ${branchIndex + 1} — actions',
            blockColor: blockColor,
            icon: Icons.subdirectory_arrow_right,
            onEdit: () async {
              if (onEditNestedActions == null) {
                return;
              }

              final result = await onEditNestedActions!(
                nestedActions,
                variableSuggestions,
              );
              if (result == null) {
                return;
              }

              final updated = _cloneElseIfBranches(branches);
              updated[branchIndex]['actions'] = result;
              onParameterChanged(paramKey, updated);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNestedActionsEditor({
    required List<Map<String, dynamic>> nestedList,
    required String blockLabel,
    required Color blockColor,
    required IconData icon,
    required Future<void> Function() onEdit,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;

        final editButton = FilledButton.tonalIcon(
          onPressed: onEditNestedActions == null ? null : onEdit,
          icon: const Icon(Icons.edit, size: 15),
          label: Text(
            isCompact
                ? 'Edit ${nestedList.length}'
                : 'Edit (${nestedList.length})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: blockColor.withValues(alpha: 0.16),
            foregroundColor: blockColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        );

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onEditNestedActions == null ? null : onEdit,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              decoration: BoxDecoration(
                border: Border.all(color: blockColor.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(10),
                color: blockColor.withValues(alpha: 0.05),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCompact) ...[
                      Row(
                        children: [
                          Icon(icon, color: blockColor, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              blockLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blockColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: editButton),
                    ] else
                      Row(
                        children: [
                          Icon(icon, color: blockColor, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              blockLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blockColor,
                              ),
                            ),
                          ),
                          editButton,
                        ],
                      ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: blockColor.withValues(alpha: 0.08),
                      ),
                      child:
                          nestedList.isEmpty
                              ? Text(
                                'No actions in this branch yet.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...nestedList
                                      .take(3)
                                      .map(
                                        (a) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.arrow_right,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  a['type']?.toString() ?? '?',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  if (nestedList.length > 3)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 20),
                                      child: Text(
                                        '… and ${nestedList.length - 3} more',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _normalizeNestedActions(dynamic raw) {
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _normalizeElseIfBranches(dynamic raw) {
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Map>()
        .map((entry) {
          final branch = Map<String, dynamic>.from(entry);
          return <String, dynamic>{
            'condition.variable':
                (branch['condition.variable'] ?? '').toString(),
            'condition.operator':
                (branch['condition.operator'] ?? 'equals').toString(),
            'condition.value': (branch['condition.value'] ?? '').toString(),
            'actions': _normalizeNestedActions(branch['actions']),
          };
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _cloneElseIfBranches(
    List<Map<String, dynamic>> branches,
  ) {
    return branches
        .map(
          (branch) => <String, dynamic>{
            'condition.variable':
                (branch['condition.variable'] ?? '').toString(),
            'condition.operator':
                (branch['condition.operator'] ?? 'equals').toString(),
            'condition.value': (branch['condition.value'] ?? '').toString(),
            'actions': _normalizeNestedActions(branch['actions']),
          },
        )
        .toList(growable: true);
  }

  List<Widget> _buildVariableSuggestionsForParam({
    required String paramKey,
    required dynamic value,
    bool isNumericField = false,
  }) {
    final rawValue = value?.toString() ?? '';
    final query = _extractPlaceholderQuery(rawValue);
    if (query == null) {
      return const [];
    }

    final normalizedQuery = query.trim().toLowerCase();
    final filteredByKind =
        isNumericField
            ? variableSuggestions.where(
              (item) => item.isNumeric || item.isUnknown,
            )
            : variableSuggestions;

    final dedupedByName = <String, VariableSuggestion>{};
    for (final item in filteredByKind) {
      final normalizedName = item.name.trim();
      if (normalizedName.isEmpty) {
        continue;
      }
      dedupedByName.putIfAbsent(
        normalizedName,
        () => VariableSuggestion(name: normalizedName, kind: item.kind),
      );
    }

    final suggestions =
        dedupedByName.values
            .where(
              (item) =>
                  normalizedQuery.isEmpty ||
                  item.name.toLowerCase().contains(normalizedQuery),
            )
            .toList();

    if (!isNumericField) {
      suggestions.addAll(
        _buildContextualArraySuggestions(
          normalizedQuery: normalizedQuery,
          baseSuggestions: dedupedByName.values,
        ),
      );
    }

    final uniqueSuggestions = <String, VariableSuggestion>{};
    for (final item in suggestions) {
      uniqueSuggestions[item.name] = item;
    }
    final topSuggestions = uniqueSuggestions.values.take(8).toList();

    if (topSuggestions.isEmpty) {
      return const [];
    }

    return [
      const SizedBox(height: 8),
      Text(
        isNumericField
            ? 'Dynamic numeric suggestions'
            : 'Dynamic variable suggestions',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            topSuggestions
                .map(
                  (item) => ActionChip(
                    label: Text('((${item.name}))'),
                    onPressed: () {
                      final nextValue = _insertVariableInOpenPlaceholder(
                        rawValue,
                        item.name,
                      );
                      onSuggestionSelected(paramKey, nextValue);
                    },
                  ),
                )
                .toList(),
      ),
    ];
  }

  List<VariableSuggestion> _buildContextualArraySuggestions({
    required String normalizedQuery,
    required Iterable<VariableSuggestion> baseSuggestions,
  }) {
    final query = normalizedQuery.trim();
    if (query.isEmpty) {
      return const [];
    }

    final baseQuery =
        query.endsWith('.') ? query.substring(0, query.length - 1) : query;
    if (baseQuery.isEmpty) {
      return const [];
    }

    final matchingBases =
        baseSuggestions
            .where((item) => item.name.toLowerCase() == baseQuery)
            .map((item) => item.name)
            .toSet();

    if (matchingBases.isEmpty) {
      return const [];
    }

    final generated = <VariableSuggestion>[];
    for (final base in matchingBases) {
      generated.add(
        VariableSuggestion(
          name: '$base.items',
          kind: VariableSuggestionKind.unknown,
        ),
      );
      generated.add(
        VariableSuggestion(
          name: '$base.display',
          kind: VariableSuggestionKind.nonNumeric,
        ),
      );
      generated.add(
        VariableSuggestion(
          name: '$base.count',
          kind: VariableSuggestionKind.numeric,
        ),
      );
      generated.add(
        VariableSuggestion(
          name: '$base.total',
          kind: VariableSuggestionKind.numeric,
        ),
      );
      for (var index = 0; index < 5; index++) {
        generated.add(
          VariableSuggestion(
            name: '$base.$index',
            kind: VariableSuggestionKind.unknown,
          ),
        );
      }
    }

    return generated;
  }

  String? _extractPlaceholderQuery(String input) {
    final start = input.lastIndexOf('((');
    if (start == -1) {
      return null;
    }

    final afterStart = input.substring(start + 2);
    if (afterStart.contains('))')) {
      return null;
    }

    final parts = afterStart.split('|');
    return parts.last.trimLeft();
  }

  String _insertVariableInOpenPlaceholder(String input, String variableName) {
    final start = input.lastIndexOf('((');
    if (start == -1) {
      return '(($variableName))';
    }

    final beforeStart = input.substring(0, start);
    final afterStart = input.substring(start + 2);

    if (afterStart.contains('))')) {
      return input;
    }

    final parts = afterStart.split('|');
    final prefixParts =
        parts.length > 1 ? parts.sublist(0, parts.length - 1) : <String>[];
    final previous = prefixParts
        .map((entry) => entry.trim())
        .where((e) => e.isNotEmpty);
    final merged = [...previous, variableName];
    final inner = merged.join(' | ');

    return '$beforeStart(($inner))';
  }

  // Méthodes utilitaires
  void _showListEditor(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    final maxHeight = MediaQuery.of(context).size.height * 0.55;
    final List<String> items = List<String>.from(currentValue ?? []);
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Edit ${_formatParameterName(paramDef.key)}'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: maxHeight,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  hintText: 'Add new item',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty) {
                                    setDialogState(() {
                                      items.add(value.trim());
                                      controller.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                if (controller.text.trim().isNotEmpty) {
                                  setDialogState(() {
                                    items.add(controller.text.trim());
                                    controller.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(items[index]),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      () => setDialogState(
                                        () => items.removeAt(index),
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        onParameterChanged(paramDef.key, items);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Choose ${_formatParameterName(paramDef.key)}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        '#FF0000',
                        '#00FF00',
                        '#0000FF',
                        '#FFFF00',
                        '#FF00FF',
                        '#00FFFF',
                        '#000000',
                        '#FFFFFF',
                        '#808080',
                        '#FFA500',
                        '#800080',
                        '#008000',
                      ].map((colorHex) {
                        return GestureDetector(
                          onTap: () {
                            onParameterChanged(paramDef.key, colorHex);
                            Navigator.pop(dialogContext);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _parseColor(colorHex),
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showMapEditor(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    if (paramDef.key == 'headers') {
      _showHeadersEditor(context, paramDef, currentValue);
      return;
    }
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    final rawMap =
        (currentValue is Map)
            ? Map<String, dynamic>.from(currentValue.cast<String, dynamic>())
            : <String, dynamic>{};

    // We start in edit mode but with validation checking
    showDialog(
      context: context,
      builder: (dialogContext) {
        final TextEditingController jsonController = TextEditingController(
          text: const JsonEncoder.withIndent('  ').convert(rawMap),
        );
        String? errorMessage;
        bool isPreviewMode = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void validateJson(String text) {
              if (text.trim().isEmpty) {
                setDialogState(() => errorMessage = null);
                return;
              }
              try {
                final decoded = jsonDecode(text);
                if (decoded is! Map) {
                  setDialogState(
                    () => errorMessage = 'Root must be a JSON object {...}',
                  );
                } else {
                  setDialogState(() => errorMessage = null);
                }
              } catch (e) {
                setDialogState(() => errorMessage = e.toString());
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text('Edit ${_formatParameterName(paramDef.key)}'),
                  ),
                  IconButton(
                    icon: Icon(isPreviewMode ? Icons.code : Icons.visibility),
                    tooltip:
                        isPreviewMode
                            ? 'Edit Raw JSON'
                            : 'Preview Highlighted JSON',
                    onPressed: () {
                      if (!isPreviewMode) {
                        // Before switching to preview, format the JSON to ensure it's pretty
                        try {
                          final decoded = jsonDecode(
                            jsonController.text.trim(),
                          );
                          if (decoded is Map) {
                            jsonController.text = const JsonEncoder.withIndent(
                              '  ',
                            ).convert(decoded);
                          }
                        } catch (_) {}
                      }
                      setDialogState(() => isPreviewMode = !isPreviewMode);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_align_left),
                    tooltip: 'Format JSON',
                    onPressed: () {
                      try {
                        final decoded = jsonDecode(jsonController.text.trim());
                        if (decoded is Map) {
                          setDialogState(() {
                            jsonController.text = const JsonEncoder.withIndent(
                              '  ',
                            ).convert(decoded);
                            errorMessage = null;
                          });
                        }
                      } catch (e) {
                        setDialogState(
                          () => errorMessage = 'Cannot format: Invalid JSON',
                        );
                      }
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isPreviewMode)
                      Text(
                        'JSON object editor (supports nested objects/arrays)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          isPreviewMode
                              ? Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: SingleChildScrollView(
                                  child: HighlightView(
                                    jsonController.text.trim().isEmpty
                                        ? '{}'
                                        : jsonController.text,
                                    language: 'json',
                                    theme: darculaTheme,
                                    padding: const EdgeInsets.all(12),
                                    textStyle: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                              : TextField(
                                controller: jsonController,
                                maxLines: null,
                                expands: true,
                                keyboardType: TextInputType.multiline,
                                onChanged: validateJson,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                  errorText: errorMessage,
                                ),
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      errorMessage != null
                          ? null
                          : () {
                            try {
                              final text = jsonController.text.trim();
                              if (text.isEmpty) {
                                onParameterChanged(
                                  paramDef.key,
                                  <String, dynamic>{},
                                );
                                Navigator.pop(dialogContext);
                                return;
                              }
                              final decoded = jsonDecode(text);
                              if (decoded is! Map) {
                                setDialogState(
                                  () =>
                                      errorMessage =
                                          'Root must be a JSON object',
                                );
                                return;
                              }

                              onParameterChanged(
                                paramDef.key,
                                Map<String, dynamic>.from(decoded),
                              );
                              Navigator.pop(dialogContext);
                            } catch (error) {
                              setDialogState(
                                () => errorMessage = error.toString(),
                              );
                            }
                          },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMapPreview(String key, dynamic currentValue) {
    if (currentValue is Map && currentValue.isNotEmpty) {
      if (key == 'headers') {
        final entries = currentValue.entries.toList();
        final preview = entries
            .take(6)
            .map((entry) {
              final headerKey = entry.key.toString();
              final headerValue = entry.value?.toString() ?? '';
              return '$headerKey: $headerValue';
            })
            .join('\n');
        final extraCount = entries.length - 6;
        return SelectableText(
          extraCount > 0 ? '$preview\n… ($extraCount more)' : preview,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        );
      }

      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xff2b2b2b), // darcula background
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(8),
        child: HighlightView(
          const JsonEncoder.withIndent('  ').convert(currentValue),
          language: 'json',
          theme: darculaTheme,
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      );
    }

    return Text(
      key == 'headers'
          ? 'No headers - tap edit to add'
          : 'No properties - tap edit to configure',
      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
    );
  }

  void _showHeadersEditor(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    final Map<String, dynamic> rawMap =
        (currentValue is Map)
            ? Map<String, dynamic>.from(currentValue.cast<String, dynamic>())
            : <String, dynamic>{};

    final List<Map<String, TextEditingController>> headers =
        rawMap.entries
            .map(
              (entry) => {
                'keyController': TextEditingController(text: entry.key),
                'valueController': TextEditingController(
                  text: entry.value?.toString() ?? '',
                ),
              },
            )
            .toList();

    if (headers.isEmpty) {
      headers.add({
        'keyController': TextEditingController(),
        'valueController': TextEditingController(),
      });
    }

    final pasteController = TextEditingController();

    const commonHeaders = [
      'Authorization',
      'Content-Type',
      'Accept',
      'User-Agent',
      'Cache-Control',
      'Host',
      'Connection',
      'Origin',
      'Referer',
      'X-Requested-With',
      'Access-Control-Allow-Origin',
    ];

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Edit ${_formatParameterName(paramDef.key)}'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: maxHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HTTP Headers (Key/Value pairs)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: headers.length,
                            itemBuilder: (context, index) {
                              final keyController =
                                  headers[index]['keyController']!;
                              final valueController =
                                  headers[index]['valueController']!;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Autocomplete<String>(
                                        optionsBuilder: (
                                          TextEditingValue textEditingValue,
                                        ) {
                                          if (textEditingValue.text == '') {
                                            return commonHeaders;
                                          }
                                          return commonHeaders.where((
                                            String option,
                                          ) {
                                            return option
                                                .toLowerCase()
                                                .contains(
                                                  textEditingValue.text
                                                      .toLowerCase(),
                                                );
                                          });
                                        },
                                        onSelected: (String selection) {
                                          keyController.text = selection;
                                        },
                                        fieldViewBuilder: (
                                          context,
                                          controller,
                                          focusNode,
                                          onEditingComplete,
                                        ) {
                                          // Sync initial value since Autocomplete creates its own controller initially empty
                                          if (controller.text !=
                                                  keyController.text &&
                                              controller.text.isEmpty) {
                                            controller.text =
                                                keyController.text;
                                          }
                                          controller.addListener(() {
                                            keyController.text =
                                                controller.text;
                                          });

                                          return TextField(
                                            controller: controller,
                                            focusNode: focusNode,
                                            onEditingComplete:
                                                onEditingComplete,
                                            decoration: const InputDecoration(
                                              hintText: 'Key',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 6,
                                      child: TextField(
                                        controller: valueController,
                                        decoration: const InputDecoration(
                                          hintText: 'Value',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        maxLines: null,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          if (headers.length > 1) {
                                            headers.removeAt(index);
                                          } else {
                                            keyController.clear();
                                            valueController.clear();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  headers.add({
                                    'keyController': TextEditingController(),
                                    'valueController': TextEditingController(),
                                  });
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add header'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  for (final entry in headers) {
                                    entry['keyController']!.clear();
                                    entry['valueController']!.clear();
                                  }
                                  // Keep at least one empty row
                                  if (headers.length > 1) {
                                    headers.removeRange(1, headers.length);
                                  }
                                });
                              },
                              child: const Text('Clear all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        Text(
                          'Bulk import (Paste headers like Key: Value)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: pasteController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Authorization: Bearer ...\nAccept: application/json',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final raw = pasteController.text.trim();
                                if (raw.isEmpty) {
                                  return;
                                }
                                final lines = raw.split(RegExp(r'\r?\n'));
                                setDialogState(() {
                                  // Remove empty rows if any
                                  headers.removeWhere(
                                    (entry) =>
                                        entry['keyController']!.text
                                            .trim()
                                            .isEmpty &&
                                        entry['valueController']!.text
                                            .trim()
                                            .isEmpty,
                                  );

                                  for (final line in lines) {
                                    final separatorIndex = line.indexOf(':');
                                    if (separatorIndex <= 0) {
                                      continue;
                                    }
                                    final key =
                                        line
                                            .substring(0, separatorIndex)
                                            .trim();
                                    final value =
                                        line
                                            .substring(separatorIndex + 1)
                                            .trim();
                                    if (key.isEmpty) {
                                      continue;
                                    }
                                    headers.add({
                                      'keyController': TextEditingController(
                                        text: key,
                                      ),
                                      'valueController': TextEditingController(
                                        text: value,
                                      ),
                                    });
                                  }
                                  pasteController.clear();

                                  // Add empty row if everything is clear
                                  if (headers.isEmpty) {
                                    headers.add({
                                      'keyController': TextEditingController(),
                                      'valueController':
                                          TextEditingController(),
                                    });
                                  }
                                });
                              },
                              child: const Text('Import'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final Map<String, dynamic> result = {};
                        for (final entry in headers) {
                          final key = entry['keyController']!.text.trim();
                          final value = entry['valueController']!.text.trim();
                          if (key.isNotEmpty) {
                            result[key] = value;
                          }
                        }
                        onParameterChanged(paramDef.key, result);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  IconData _getIconForIdType(ParameterType type) {
    switch (type) {
      case ParameterType.userId:
        return Icons.person;
      case ParameterType.channelId:
        return Icons.tag;
      case ParameterType.messageId:
        return Icons.message;
      case ParameterType.roleId:
        return Icons.admin_panel_settings;
      default:
        return Icons.tag;
    }
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(
          int.parse(colorString.substring(1), radix: 16) + 0xFF000000,
        );
      }
      return Colors.black;
    } catch (e) {
      return Colors.black;
    }
  }

  String _formatParameterName(String key) {
    if (action.type == BotCreatorActionType.calculate) {
      final operation =
          (action.parameters['operation'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
      final isRandom = operation == 'random' || operation == 'randomfloat';
      if (isRandom && key == 'operandA') {
        return AppStrings.currentLocale == AppLocale.fr ? 'Minimum' : 'Minimum';
      }
      if (isRandom && key == 'operandB') {
        return AppStrings.currentLocale == AppLocale.fr ? 'Maximum' : 'Maximum';
      }
    }

    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String? _localizeHint(String? hint) {
    final raw = (hint ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    if (AppStrings.currentLocale != AppLocale.fr) {
      return raw;
    }

    const direct = <String, String>{
      'Math operation to perform': 'Opération mathématique à effectuer',
      'Comparison operator': 'Opérateur de comparaison',
      'Message content': 'Contenu du message',
      'Audit log reason': 'Raison du journal d\'audit',
      'Global variable key': 'Clé de variable globale',
      'Scoped variable key (bc_ optional)':
          'Clé de variable scopée (bc_ optionnel)',
      'Saved workflow name to execute': 'Nom du workflow enregistré à exécuter',
      'Optional entry point override (defaults to workflow entry)':
          'Surcharge optionnelle du point d\'entrée (par défaut: entrée du workflow)',
      'Optional key/value arguments for workflow call':
          'Arguments clé/valeur optionnels pour l\'appel du workflow',
      'Optional key/value arguments injected as ((arg.key))':
          'Arguments clé/valeur optionnels injectés comme ((arg.key))',
      'Only visible to command author':
          'Visible uniquement pour l\'auteur de la commande',
      'Modal dialog definition': 'Définition du modal',
      'Body format': 'Format du body',
      'Custom headers': 'En-têtes personnalisés',
      'Raw text body': 'Body texte brut',
      'JSON body builder map': 'Map du body JSON',
      'Request URL (supports placeholders ((...)))':
          'URL de requête (supporte les placeholders ((...)))',
      'Value type: string or number': 'Type de valeur : string ou number',
      'Numeric value when valueType=number':
          'Valeur numérique quand valueType=number',
      'String value (supports placeholders ((...)))':
          'Valeur texte (supporte les placeholders ((...)))',
      'Runtime variable alias (ex: token)':
          'Alias de variable runtime (ex: token)',
      'Runtime variable alias (ex: guild.score)':
          'Alias de variable runtime (ex: guild.score)',
      'Listener TTL in minutes (max 60)': 'TTL du listener en minutes (max 60)',
      'Remove listener after first click':
          'Supprimer le listener après le premier clic',
      'Button customId to listen for (supports ((variables)))':
          'customId du bouton à écouter (supporte ((variables)))',
      'Modal customId to listen for': 'customId du modal à écouter',
      'Workflow to run when button is clicked':
          'Workflow à exécuter au clic sur le bouton',
      'Workflow to run when modal is submitted':
          'Workflow à exécuter à la soumission du modal',
      'Optional text above the components':
          'Texte optionnel au-dessus des composants',
      'Component V2 layout builder': 'Constructeur de layout Component V2',
      'Enable or disable guild onboarding':
          'Activer ou désactiver l\'onboarding serveur',
    };

    final directValue = direct[raw];
    if (directValue != null) {
      return directValue;
    }

    var text = raw;
    const replacements = <MapEntry<String, String>>[
      MapEntry('Optional:', 'Optionnel :'),
      MapEntry('required', 'requis'),
      MapEntry('Channel', 'Salon'),
      MapEntry('channel', 'salon'),
      MapEntry('User', 'Utilisateur'),
      MapEntry('user', 'utilisateur'),
      MapEntry('Role', 'Rôle'),
      MapEntry('role', 'rôle'),
      MapEntry('reason', 'raison'),
      MapEntry('Reason', 'Raison'),
      MapEntry('Delete', 'Supprimer'),
      MapEntry('delete', 'supprimer'),
      MapEntry('Create', 'Créer'),
      MapEntry('create', 'créer'),
      MapEntry('Update', 'Mettre à jour'),
      MapEntry('update', 'mettre à jour'),
      MapEntry('New ', 'Nouveau '),
      MapEntry('new ', 'nouveau '),
      MapEntry('supports placeholders', 'supporte les placeholders'),
      MapEntry('supports ((variables))', 'supporte ((variables))'),
      MapEntry('leave empty', 'laisser vide'),
      MapEntry('current channel', 'salon actuel'),
      MapEntry('Max ', 'Max '),
      MapEntry('max ', 'max '),
      MapEntry('Min ', 'Min '),
      MapEntry('min ', 'min '),
    ];

    for (final replacement in replacements) {
      text = text.replaceAll(replacement.key, replacement.value);
    }
    return text;
  }

  bool _isVariableKeyParameter(BotCreatorActionType type, String paramKey) {
    switch (type) {
      case BotCreatorActionType.setGlobalVariable:
      case BotCreatorActionType.getGlobalVariable:
      case BotCreatorActionType.removeGlobalVariable:
        return paramKey == 'key';
      case BotCreatorActionType.setScopedVariable:
      case BotCreatorActionType.getScopedVariable:
      case BotCreatorActionType.removeScopedVariable:
      case BotCreatorActionType.listScopedVariableIndex:
      case BotCreatorActionType.appendArrayElement:
      case BotCreatorActionType.removeArrayElement:
        return paramKey == 'key';
      case BotCreatorActionType.renameScopedVariable:
        return paramKey == 'oldKey' || paramKey == 'newKey';
      default:
        return false;
    }
  }
}

class _VariableKeyParameterField extends StatefulWidget {
  final String label;
  final String currentValue;
  final String hint;
  final String botId;
  final String scope;
  final bool scoped;
  final ValueChanged<String> onChanged;

  const _VariableKeyParameterField({
    required this.label,
    required this.currentValue,
    required this.hint,
    required this.botId,
    required this.scope,
    required this.scoped,
    required this.onChanged,
  });

  @override
  State<_VariableKeyParameterField> createState() =>
      _VariableKeyParameterFieldState();
}

class _VariableKeyParameterFieldState
    extends State<_VariableKeyParameterField> {
  List<String> _keys = const [];
  bool _loading = false;

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

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  @override
  void didUpdateWidget(covariant _VariableKeyParameterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.botId != widget.botId ||
        oldWidget.scoped != widget.scoped ||
        oldWidget.scope != widget.scope) {
      _loadKeys();
    }
  }

  Future<void> _loadKeys() async {
    setState(() {
      _loading = true;
    });

    List<String> keys;
    if (widget.scoped) {
      final defs = await appManager.getScopedVariableDefinitions(widget.botId);
      final scope = widget.scope.trim();
      keys = defs
          .where(
            (def) =>
                scope.isEmpty ||
                (def['scope'] ?? '').toString().trim() == scope,
          )
          .map((def) => (def['key'] ?? '').toString().trim())
          .where((k) => k.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } else {
      final globals = await appManager.getGlobalVariables(widget.botId);
      keys = globals.keys
          .map((k) => k.toString().trim())
          .where((k) => k.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }

    keys.sort();
    if (!mounted) {
      return;
    }
    setState(() {
      _keys = keys;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimmedCurrent = widget.currentValue.trim();
    final items = <String>{
      ..._keys,
      if (trimmedCurrent.isNotEmpty) trimmedCurrent,
    }.toList(growable: false)..sort();

    final selectedValue =
        trimmedCurrent.isNotEmpty && items.contains(trimmedCurrent)
            ? trimmedCurrent
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            const Text(
              '(static)',
              style: TextStyle(fontSize: 11, color: Colors.orangeAccent),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'variableKeyDropdown_${widget.scoped}_${widget.scope}_${widget.currentValue}_${items.length}',
                ),
                initialValue: selectedValue,
                isExpanded: true,
                items: items
                    .map((key) {
                      final canonicalRef = _toScopedReferenceKey(key);
                      final legacyRef = _toLegacyScopedReferenceKey(key);
                      final scopedLabel =
                          canonicalRef == legacyRef
                              ? '$key  (ref: $canonicalRef)'
                              : '$key  (ref: $canonicalRef, legacy: $legacyRef)';
                      return DropdownMenuItem<String>(
                        value: key,
                        child: Text(
                          widget.scoped ? scopedLabel : key,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })
                    .toList(growable: false),
                onChanged:
                    _loading
                        ? null
                        : (value) {
                          widget.onChanged((value ?? '').trim());
                        },
                decoration: InputDecoration(
                  hintText: widget.hint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  helperText:
                      _loading
                          ? 'Loading keys...'
                          : (items.isEmpty
                              ? 'No saved keys found. Keys are created automatically on first access.'
                              : (widget.scoped
                                  ? 'Select a stored key (bc_ prefix is optional)'
                                  : 'Select a saved key')),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Refresh keys',
              onPressed: _loading ? null : _loadKeys,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GlobalVariablesPage(botId: widget.botId),
              ),
            );
            await _loadKeys();
          },
          icon: const Icon(Icons.storage),
          label: const Text('Manage Variable Keys'),
        ),
      ],
    );
  }
}

class _WorkflowNameParameterField extends StatefulWidget {
  final String label;
  final String currentValue;
  final String hint;
  final String botId;
  final ValueChanged<String> onChanged;

  const _WorkflowNameParameterField({
    required this.label,
    required this.currentValue,
    required this.hint,
    required this.botId,
    required this.onChanged,
  });

  @override
  State<_WorkflowNameParameterField> createState() =>
      _WorkflowNameParameterFieldState();
}

class _WorkflowNameParameterFieldState
    extends State<_WorkflowNameParameterField> {
  List<String> _workflowNames = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadWorkflows();
  }

  @override
  void didUpdateWidget(covariant _WorkflowNameParameterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.botId != widget.botId) {
      _loadWorkflows();
    }
  }

  Future<void> _loadWorkflows() async {
    setState(() {
      _loading = true;
    });
    final workflows = await appManager.getWorkflows(widget.botId);
    if (!mounted) {
      return;
    }
    final names = workflows
      .map((workflow) => (workflow['name'] ?? '').toString().trim())
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList(growable: false)..sort();
    setState(() {
      _workflowNames = names;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimmedCurrent = widget.currentValue.trim();
    final items = <String>{
      ..._workflowNames,
      if (trimmedCurrent.isNotEmpty) trimmedCurrent,
    }.toList(growable: false)..sort();

    final dropdownValue =
        trimmedCurrent.isNotEmpty && items.contains(trimmedCurrent)
            ? trimmedCurrent
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'workflowNameDropdown_${widget.currentValue}_${items.length}',
                ),
                initialValue: dropdownValue,
                isExpanded: true,
                items:
                    items
                        .map(
                          (name) => DropdownMenuItem<String>(
                            value: name,
                            child: Text(name),
                          ),
                        )
                        .toList(),
                onChanged:
                    _loading
                        ? null
                        : (value) {
                          widget.onChanged((value ?? '').trim());
                        },
                decoration: InputDecoration(
                  hintText: widget.hint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  helperText:
                      _loading
                          ? 'Loading workflows...'
                          : (_workflowNames.isEmpty
                              ? 'No saved workflows found'
                              : 'Select a saved workflow'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Refresh workflows',
              onPressed: _loading ? null : _loadWorkflows,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('workflowNameInput_${widget.currentValue}'),
          initialValue: trimmedCurrent,
          decoration: const InputDecoration(
            labelText: 'Or type workflow name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) => widget.onChanged(value.trim()),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkflowsPage(botId: widget.botId),
              ),
            );
            await _loadWorkflows();
          },
          icon: const Icon(Icons.account_tree),
          label: const Text('Manage Workflows'),
        ),
      ],
    );
  }
}

// Widget stateful pour les champs numériques avec clamping en temps réel
class _NumberParameterField extends StatefulWidget {
  final ParameterDefinition paramDef;
  final dynamic currentValue;
  final Function(String key, dynamic value) onParameterChanged;
  final List<VariableSuggestion> variableSuggestions;
  final String paramKey;

  const _NumberParameterField({
    required this.paramDef,
    required this.currentValue,
    required this.onParameterChanged,
    required this.variableSuggestions,
    required this.paramKey,
  });

  @override
  State<_NumberParameterField> createState() => _NumberParameterFieldState();
}

class _NumberParameterFieldState extends State<_NumberParameterField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.currentValue ?? widget.paramDef.defaultValue).toString(),
    );
  }

  @override
  void didUpdateWidget(_NumberParameterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentValue != widget.currentValue) {
      _controller.text =
          (widget.currentValue ?? widget.paramDef.defaultValue).toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _getErrorMessage() {
    final numValue = int.tryParse(_controller.text);
    if (numValue != null) {
      if (widget.paramDef.minValue != null &&
          numValue < widget.paramDef.minValue!) {
        return 'Min: ${widget.paramDef.minValue}';
      } else if (widget.paramDef.maxValue != null &&
          numValue > widget.paramDef.maxValue!) {
        return 'Max: ${widget.paramDef.maxValue}';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _formatParameterName(widget.paramKey),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (widget.paramDef.required)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _controller,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            hintText: _localizeHint(widget.paramDef.hint),
            border: const OutlineInputBorder(),
            isDense: true,
            errorText: _getErrorMessage(),
            suffixText:
                widget.paramDef.minValue != null &&
                        widget.paramDef.maxValue != null
                    ? '${widget.paramDef.minValue}-${widget.paramDef.maxValue}'
                    : null,
          ),
          onChanged: (newValue) {
            final trimmed = newValue.trim();
            if (trimmed.isEmpty) {
              widget.onParameterChanged(widget.paramKey, '');
              setState(() {});
              return;
            }

            final intValue = int.tryParse(trimmed);
            if (intValue != null) {
              // Clamper aux limites min/max
              int finalValue = intValue;
              if (widget.paramDef.minValue != null &&
                  finalValue < widget.paramDef.minValue!) {
                finalValue = widget.paramDef.minValue!;
                _controller.text = finalValue.toString();
              }
              if (widget.paramDef.maxValue != null &&
                  finalValue > widget.paramDef.maxValue!) {
                finalValue = widget.paramDef.maxValue!;
                _controller.text = finalValue.toString();
              }
              widget.onParameterChanged(widget.paramKey, finalValue);
              setState(() {});
              return;
            }

            // Si allowDynamic est false, rejeter les valeurs non numériques
            if (!widget.paramDef.allowDynamic) {
              _controller.text =
                  (widget.currentValue ?? widget.paramDef.defaultValue)
                      .toString();
              setState(() {});
              return;
            }

            widget.onParameterChanged(widget.paramKey, trimmed);
            setState(() {});
          },
        ),
        if (widget.paramDef.allowDynamic)
          ..._buildVariableSuggestionsForParam(
            paramKey: widget.paramKey,
            value: widget.currentValue,
            isNumericField: true,
          ),
      ],
    );
  }

  String _formatParameterName(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .trim()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String? _localizeHint(String? hint) {
    if (hint == null) return null;
    try {
      return AppStrings.t(hint);
    } catch (_) {
      return hint;
    }
  }

  List<Widget> _buildVariableSuggestionsForParam({
    required String paramKey,
    required dynamic value,
    bool isNumericField = false,
  }) {
    final rawValue = value?.toString() ?? '';
    final query = _extractPlaceholderQuery(rawValue);
    if (query == null) {
      return const [];
    }

    final normalizedQuery = query.trim().toLowerCase();
    final filteredByKind =
        isNumericField
            ? widget.variableSuggestions.where(
              (item) => item.isNumeric || item.isUnknown,
            )
            : widget.variableSuggestions;

    final suggestions =
        filteredByKind
            .where(
              (item) =>
                  normalizedQuery.isEmpty ||
                  item.name.toLowerCase().contains(normalizedQuery),
            )
            .take(8)
            .toList();

    if (suggestions.isEmpty) {
      return const [];
    }

    return [
      const SizedBox(height: 8),
      Text(
        isNumericField
            ? 'Dynamic numeric suggestions'
            : 'Dynamic variable suggestions',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            suggestions
                .map(
                  (item) => ActionChip(
                    label: Text('((${item.name}))'),
                    onPressed: () {
                      final nextValue = _insertVariableInOpenPlaceholder(
                        rawValue,
                        item.name,
                      );
                      _controller.text = nextValue;
                      widget.onParameterChanged(widget.paramKey, nextValue);
                      setState(() {});
                    },
                  ),
                )
                .toList(),
      ),
    ];
  }

  String? _extractPlaceholderQuery(String input) {
    final start = input.lastIndexOf('((');
    if (start == -1) {
      return null;
    }

    final afterStart = input.substring(start + 2);
    if (afterStart.contains('))')) {
      return null;
    }

    final parts = afterStart.split('|');
    return parts.last.trimLeft();
  }

  String _insertVariableInOpenPlaceholder(String input, String variableName) {
    final start = input.lastIndexOf('((');
    if (start == -1) {
      return '(($variableName))';
    }

    final beforeStart = input.substring(0, start);
    final afterStart = input.substring(start + 2);

    if (afterStart.contains('))')) {
      return input;
    }

    return '$beforeStart(($variableName))';
  }
}

class _BdfdScriptParameterField extends StatefulWidget {
  const _BdfdScriptParameterField({
    required this.currentValue,
    required this.onChanged,
    this.hint,
  });

  final String currentValue;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  State<_BdfdScriptParameterField> createState() =>
      _BdfdScriptParameterFieldState();
}

class _BdfdScriptParameterFieldState extends State<_BdfdScriptParameterField> {
  late final TextEditingController _controller;
  final BdfdCompiler _compiler = BdfdCompiler();
  BdfdCompileResult? _compileResult;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
    _recompile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recompile() {
    final source = _controller.text;
    if (source.trim().isEmpty) {
      _compileResult = null;
      return;
    }
    _compileResult = _compiler.compile(source);
  }

  List<BdfdCompileDiagnostic> get _diagnostics =>
      _compileResult?.diagnostics ?? const <BdfdCompileDiagnostic>[];

  bool get _hasErrors => _diagnostics.any(
    (d) => d.severity == BdfdCompileDiagnosticSeverity.error,
  );

  String _formatDiagnostic(BdfdCompileDiagnostic d) {
    final loc =
        (d.line != null && d.column != null) ? 'L${d.line}:C${d.column} ' : '';
    return '$loc${d.message}';
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    final isEmpty = code.trim().isEmpty;
    final preview =
        isEmpty
            ? AppStrings.t('bdfd_editor_tap_hint')
            : code.length > 150
            ? '${code.substring(0, 150)}…'
            : code;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'BDFD Script',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const Text(
              ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push<String>(
              context,
              MaterialPageRoute<String>(
                builder: (_) => BdfdEditorPage(initialCode: _controller.text),
              ),
            );
            if (result != null && mounted) {
              _controller.text = result;
              setState(_recompile);
              widget.onChanged(result);
            }
          },
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
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
                      AppStrings.t('bdfd_editor_tap_hint'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
                if (!isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.grey.shade300,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildDiagnosticsPanel(),
      ],
    );
  }

  Widget _buildDiagnosticsPanel() {
    final diagnostics = _diagnostics;

    if (_controller.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (diagnostics.isEmpty) {
      return Container(
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
                style: TextStyle(fontSize: 12, color: Colors.green.shade800),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _hasErrors ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _hasErrors ? Colors.red.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t('cmd_bdfd_diagnostics_title'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          ...diagnostics.map((d) {
            final isError = d.severity == BdfdCompileDiagnosticSeverity.error;
            final icon =
                isError ? Icons.error_outline : Icons.warning_amber_rounded;
            final label = AppStrings.t(
              isError
                  ? 'cmd_bdfd_diagnostics_error'
                  : 'cmd_bdfd_diagnostics_warning',
            );
            final color =
                isError ? Colors.red.shade800 : Colors.orange.shade900;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$label: ${_formatDiagnostic(d)}',
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
