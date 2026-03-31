import '../../types/action.dart';
import '../../utils/bdfd_compiler.dart';
import '../../utils/workflow_call.dart';

bool _evaluateCondition({
  required String leftValue,
  required String operator,
  required String rightValue,
}) {
  final op = operator.toLowerCase().trim();
  switch (op) {
    case 'equals':
    case '==':
      return leftValue == rightValue;
    case 'notequals':
    case '!=':
      return leftValue != rightValue;
    case 'contains':
      return leftValue.contains(rightValue);
    case 'notcontains':
      return !leftValue.contains(rightValue);
    case 'startswith':
      return leftValue.startsWith(rightValue);
    case 'endswith':
      return leftValue.endsWith(rightValue);
    case 'greaterthan':
    case '>':
      return (num.tryParse(leftValue) ?? 0) > (num.tryParse(rightValue) ?? 0);
    case 'lessthan':
    case '<':
      return (num.tryParse(leftValue) ?? 0) < (num.tryParse(rightValue) ?? 0);
    case 'greaterorequal':
    case '>=':
      return (num.tryParse(leftValue) ?? 0) >= (num.tryParse(rightValue) ?? 0);
    case 'lessorequal':
    case '<=':
      return (num.tryParse(leftValue) ?? 0) <= (num.tryParse(rightValue) ?? 0);
    case 'isempty':
      return leftValue.trim().isEmpty;
    case 'isnotempty':
      return leftValue.trim().isNotEmpty;
    case 'matches':
      try {
        return RegExp(rightValue, caseSensitive: false).hasMatch(leftValue);
      } catch (_) {
        return false;
      }
    default:
      return false;
  }
}

bool _parseBooleanFlag(dynamic value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'on';
}

bool _evaluateConditionFromPayload({
  required Map<String, dynamic> payload,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
}) {
  final rawGroup =
      (payload['condition.group'] ?? payload['group'] ?? '').toString().trim();
  if (rawGroup.isNotEmpty) {
    final group = rawGroup.toLowerCase();
    final rawConditions =
        payload['condition.conditions'] ?? payload['conditions'];
    final conditionList = <Map<String, dynamic>>[];
    if (rawConditions is List) {
      for (final item in rawConditions) {
        if (item is Map) {
          conditionList.add(Map<String, dynamic>.from(item));
        }
      }
    }

    var groupResult = group == 'and';
    for (final condition in conditionList) {
      final passed = _evaluateConditionFromPayload(
        payload: condition,
        variables: variables,
        resolveValue: resolveValue,
      );
      if (group == 'and') {
        groupResult = groupResult && passed;
      } else {
        groupResult = groupResult || passed;
      }
    }

    final negate = _parseBooleanFlag(
      payload['condition.negate'] ?? payload['negate'],
    );
    return negate ? !groupResult : groupResult;
  }

  final rawConditionVariable =
      (payload['condition.variable'] ?? payload['variable'] ?? '').toString();
  final conditionOperator =
      resolveValue(
        (payload['condition.operator'] ?? payload['operator'] ?? 'equals')
            .toString(),
      ).trim();
  final conditionValue = resolveValue(
    (payload['condition.value'] ?? payload['value'] ?? '').toString(),
  );
  final leftValue = _resolveConditionLeftValue(
    rawConditionVariable,
    variables,
    resolveValue,
  );

  return _evaluateCondition(
    leftValue: leftValue,
    operator: conditionOperator,
    rightValue: conditionValue,
  );
}

String _resolveConditionLeftValue(
  String rawConditionVariable,
  Map<String, String> variables,
  String Function(String input) resolveValue,
) {
  final raw = rawConditionVariable.trim();
  if (raw.isEmpty) {
    return '';
  }

  if (variables.containsKey(raw)) {
    return variables[raw] ?? '';
  }

  final wrappedMatch = RegExp(r'^\(\((.+)\)\)$').firstMatch(raw);
  if (wrappedMatch != null) {
    final wrappedKey = (wrappedMatch.group(1) ?? '').trim();
    if (wrappedKey.isNotEmpty && variables.containsKey(wrappedKey)) {
      return variables[wrappedKey] ?? '';
    }
  }

  final resolved = resolveValue(raw).trim();
  if (variables.containsKey(resolved)) {
    return variables[resolved] ?? '';
  }

  return resolved;
}

List<Action> _decodeActionList(dynamic branchRaw) {
  final branchActions = <Action>[];
  if (branchRaw is! List) {
    return branchActions;
  }

  for (final item in branchRaw) {
    if (item is Map) {
      branchActions.add(Action.fromJson(Map<String, dynamic>.from(item)));
    }
  }

  return branchActions;
}

Future<bool> executeControlFlowAction({
  required BotCreatorActionType type,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
  required void Function(String message)? onLog,
  required Set<String> activeWorkflowStack,
  required Future<Map<String, dynamic>?> Function(String workflowName)
  getWorkflowByName,
  required Future<Map<String, String>> Function(List<Action> actions)
  executeActions,
}) async {
  switch (type) {
    case BotCreatorActionType.runBdfdScript:
      final bdfdSource = resolveValue(
        (payload['scriptContent'] ?? '').toString(),
      );
      if (bdfdSource.trim().isEmpty) {
        results[resultKey] = 'BDFD_EMPTY';
        return true;
      }

      final compileResult = BdfdCompiler().compile(bdfdSource);
      if (compileResult.hasErrors) {
        final summary = compileResult.diagnostics
            .where((d) => d.severity == BdfdCompileDiagnosticSeverity.error)
            .take(5)
            .map((d) => d.message)
            .join('; ');
        throw Exception('BDFD compile error: $summary');
      }

      if (compileResult.actions.isEmpty) {
        results[resultKey] = 'BDFD_NO_ACTIONS';
        return true;
      }

      final bdfdResults = await executeActions(compileResult.actions);
      for (final entry in bdfdResults.entries) {
        results['$resultKey.${entry.key}'] = entry.value;
      }
      if (bdfdResults.containsKey('__stopped__')) {
        results['__stopped__'] = 'true';
      }
      results[resultKey] = 'BDFD_OK';
      return true;

    case BotCreatorActionType.runWorkflow:
      final workflowName =
          resolveValue((payload['workflowName'] ?? '').toString()).trim();
      if (workflowName.isEmpty) {
        throw Exception('workflowName is required for runWorkflow');
      }

      final workflow = await getWorkflowByName(workflowName);
      if (workflow == null) {
        throw Exception('Workflow not found: $workflowName');
      }

      final requestedEntryPoint =
          resolveValue((payload['entryPoint'] ?? '').toString()).trim();
      final workflowEntryPoint = normalizeWorkflowEntryPoint(
        requestedEntryPoint,
        fallback: normalizeWorkflowEntryPoint(workflow['entryPoint']),
      );
      final workflowArgDefinitions = parseWorkflowArgumentDefinitions(
        workflow['arguments'],
      );
      final workflowCallArguments = resolveWorkflowCallArguments(
        payload['arguments'],
        resolveValue,
      );

      final stackKey =
          '${workflowName.toLowerCase()}::${workflowEntryPoint.toLowerCase()}';
      if (activeWorkflowStack.contains(stackKey)) {
        throw Exception(
          'Workflow recursion detected for "$workflowName" (entry: $workflowEntryPoint)',
        );
      }

      applyWorkflowInvocationContext(
        variables: variables,
        workflowName: workflowName,
        entryPoint: workflowEntryPoint,
        definitions: workflowArgDefinitions,
        providedArguments: workflowCallArguments,
      );

      final workflowActions = List<Action>.from(
        ((workflow['actions'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((json) => Action.fromJson(Map<String, dynamic>.from(json))),
      );

      activeWorkflowStack.add(stackKey);
      late final Map<String, String> workflowResults;
      try {
        workflowResults = await executeActions(workflowActions);
      } finally {
        activeWorkflowStack.remove(stackKey);
      }

      for (final entry in workflowResults.entries) {
        results['$resultKey.${entry.key}'] = entry.value;
        variables['workflow.response.${entry.key}'] = entry.value;
      }
      variables['workflow.response'] = 'WORKFLOW_OK:$workflowEntryPoint';
      results[resultKey] = 'WORKFLOW_OK:$workflowEntryPoint';
      return true;

    case BotCreatorActionType.stopUnless:
      final rawConditionVariable =
          (payload['condition.variable'] ?? '').toString();
      final conditionVariable = resolveValue(rawConditionVariable).trim();
      final conditionOperator =
          resolveValue(
            (payload['condition.operator'] ?? 'equals').toString(),
          ).trim();
      final conditionValue = resolveValue(
        (payload['condition.value'] ?? '').toString(),
      );

      final leftValue = _resolveConditionLeftValue(
        rawConditionVariable,
        variables,
        resolveValue,
      );
      final conditionPassed = _evaluateCondition(
        leftValue: leftValue,
        operator: conditionOperator,
        rightValue: conditionValue,
      );
      results[resultKey] = conditionPassed ? 'PASSED' : 'STOPPED';
      if (!conditionPassed) {
        onLog?.call(
          'Action $resultKey stopped workflow: "$conditionVariable" $conditionOperator "$conditionValue" failed (actual: "$leftValue")',
        );
        results['__stopped__'] = 'true';
      }
      return true;

    case BotCreatorActionType.ifBlock:
      final conditionPassed = _evaluateConditionFromPayload(
        payload: payload,
        variables: variables,
        resolveValue: resolveValue,
      );

      final rawThen = payload['thenActions'];
      final rawElse = payload['elseActions'];
      dynamic branchRaw = rawThen;
      var branchResult = 'IF_TRUE';

      if (!conditionPassed) {
        branchRaw = rawElse;
        branchResult = 'IF_FALSE';

        final rawElseIfConditions = payload['elseIfConditions'];
        if (rawElseIfConditions is List) {
          for (var index = 0; index < rawElseIfConditions.length; index++) {
            final entry = rawElseIfConditions[index];
            if (entry is! Map) {
              continue;
            }

            final elseIf = Map<String, dynamic>.from(entry);
            final elseIfPassed = _evaluateConditionFromPayload(
              payload: elseIf,
              variables: variables,
              resolveValue: resolveValue,
            );
            if (!elseIfPassed) {
              continue;
            }

            branchRaw = elseIf['actions'];
            branchResult = 'ELSE_IF_${index + 1}';
            break;
          }
        }
      }

      final branchActions = _decodeActionList(branchRaw);

      results[resultKey] = branchResult;
      if (branchActions.isEmpty) {
        return true;
      }

      final branchResults = await executeActions(branchActions);
      for (final entry in branchResults.entries) {
        results['$resultKey.${entry.key}'] = entry.value;
      }
      if (branchResults.containsKey('__stopped__')) {
        results['__stopped__'] = 'true';
      }
      return true;

    case BotCreatorActionType.forLoop:
      final mode = (payload['mode'] ?? 'simple').toString();
      final maxIterations = (payload['maxIterations'] as int?) ?? 100;

      if (mode == 'cstyle') {
        return _executeCStyleForLoop(
          payload: payload,
          resultKey: resultKey,
          results: results,
          variables: variables,
          resolveValue: resolveValue,
          executeActions: executeActions,
          maxIterations: maxIterations,
        );
      }

      // Simple runtime loop: iterations is a template string.
      final rawIterations =
          resolveValue((payload['iterations'] ?? '0').toString()).trim();
      final iterations = int.tryParse(rawIterations) ?? 0;
      final capped = iterations > maxIterations ? maxIterations : iterations;
      final bodyActionsRaw = payload['bodyActions'];
      final templateActions = _decodeActionList(bodyActionsRaw);

      if (capped <= 0 || templateActions.isEmpty) {
        results[resultKey] = 'LOOP_0';
        return true;
      }

      for (var i = 0; i < capped; i++) {
        variables['_loop.index'] = i.toString();
        variables['_loop.count'] = (i + 1).toString();

        final iterActions = _cloneActionsWithLoopVars(
          templateActions,
          loopVars: <String, String>{
            '_loop.index': i.toString(),
            '_loop.count': (i + 1).toString(),
          },
        );
        final iterResults = await executeActions(iterActions);
        for (final entry in iterResults.entries) {
          results['$resultKey.iter$i.${entry.key}'] = entry.value;
        }
        if (iterResults.containsKey('__stopped__')) {
          results['__stopped__'] = 'true';
          break;
        }
      }
      variables.remove('_loop.index');
      variables.remove('_loop.count');
      results[resultKey] = 'LOOP_$capped';
      return true;

    default:
      return false;
  }
}

/// Executes a C-style runtime for loop.
Future<bool> _executeCStyleForLoop({
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
  required Future<Map<String, String>> Function(List<Action> actions)
  executeActions,
  required int maxIterations,
}) async {
  final initRaw = resolveValue((payload['init'] ?? '').toString());
  final conditionTemplate = (payload['condition'] ?? '').toString();
  final updateTemplate = (payload['update'] ?? '').toString();
  final varNames = List<String>.from(payload['varNames'] ?? const <String>[]);
  final bodyActionsRaw = payload['bodyActions'];
  final templateActions = _decodeActionList(bodyActionsRaw);

  // Parse init: "i=0, j=10" where values may now be runtime-resolved.
  final loopVars = <String, int>{};
  for (final part in initRaw.split(',')) {
    final eqIndex = part.indexOf('=');
    if (eqIndex < 0) continue;
    final name = part.substring(0, eqIndex).trim().toLowerCase();
    final valueStr = resolveValue(part.substring(eqIndex + 1).trim());
    loopVars[name] = int.tryParse(valueStr) ?? 0;
  }

  if (templateActions.isEmpty) {
    results[resultKey] = 'LOOP_0';
    return true;
  }

  var iterationCount = 0;

  while (iterationCount < maxIterations) {
    final resolvedCondition = _resolveLoopExpression(
      conditionTemplate,
      loopVars,
      resolveValue,
    );
    if (!_evaluateSimpleCondition(resolvedCondition)) break;

    for (final entry in loopVars.entries) {
      variables['_loop.var.${entry.key}'] = entry.value.toString();
    }
    variables['_loop.index'] = iterationCount.toString();
    variables['_loop.count'] = (iterationCount + 1).toString();

    final iterActions = _cloneActionsWithLoopVars(
      templateActions,
      loopVars: <String, String>{
        for (final entry in loopVars.entries)
          '_loop.var.${entry.key}': entry.value.toString(),
        '_loop.index': iterationCount.toString(),
        '_loop.count': (iterationCount + 1).toString(),
      },
    );
    final iterResults = await executeActions(iterActions);
    for (final entry in iterResults.entries) {
      results['$resultKey.iter$iterationCount.${entry.key}'] = entry.value;
    }
    if (iterResults.containsKey('__stopped__')) {
      results['__stopped__'] = 'true';
      break;
    }

    _applyRuntimeCStyleUpdate(updateTemplate, loopVars, resolveValue);
    iterationCount++;
  }

  for (final name in varNames) {
    variables.remove('_loop.var.$name');
  }
  variables.remove('_loop.index');
  variables.remove('_loop.count');
  results[resultKey] = 'LOOP_$iterationCount';
  return true;
}

List<Action> _cloneActionsWithLoopVars(
  List<Action> templateActions, {
  required Map<String, String> loopVars,
}) {
  return templateActions.map((action) {
    final resolvedPayload = _resolvePayloadLoopVars(action.payload, loopVars);
    return Action(
      type: action.type,
      key: action.key,
      payload: resolvedPayload,
      enabled: action.enabled,
    );
  }).toList();
}

Map<String, dynamic> _resolvePayloadLoopVars(
  Map<String, dynamic> payload,
  Map<String, String> loopVars,
) {
  return payload.map((key, value) {
    if (value is String) {
      return MapEntry(key, _substituteLoopPlaceholders(value, loopVars));
    }
    if (value is List) {
      return MapEntry(
        key,
        value.map((item) {
          if (item is String) {
            return _substituteLoopPlaceholders(item, loopVars);
          }
          if (item is Map) {
            return _resolvePayloadLoopVars(
              Map<String, dynamic>.from(item),
              loopVars,
            );
          }
          return item;
        }).toList(),
      );
    }
    if (value is Map) {
      return MapEntry(
        key,
        _resolvePayloadLoopVars(Map<String, dynamic>.from(value), loopVars),
      );
    }
    return MapEntry(key, value);
  });
}

String _substituteLoopPlaceholders(String input, Map<String, String> loopVars) {
  var result = input;
  for (final entry in loopVars.entries) {
    result = result.replaceAll('((${entry.key}))', entry.value);
  }
  return result;
}

String _resolveLoopExpression(
  String template,
  Map<String, int> loopVars,
  String Function(String input) resolveValue,
) {
  var result = template;
  for (final entry in loopVars.entries) {
    result = result.replaceAll(
      '((_loop.var.${entry.key}))',
      entry.value.toString(),
    );
  }
  return resolveValue(result);
}

bool _evaluateSimpleCondition(String resolved) {
  final pattern = RegExp(r'^(-?\d+)\s*(<=|>=|<|>|==|!=)\s*(-?\d+)$');
  final match = pattern.firstMatch(resolved.trim());
  if (match == null) return false;
  final left = int.tryParse(match.group(1)!) ?? 0;
  final op = match.group(2)!;
  final right = int.tryParse(match.group(3)!) ?? 0;
  switch (op) {
    case '<':
      return left < right;
    case '<=':
      return left <= right;
    case '>':
      return left > right;
    case '>=':
      return left >= right;
    case '==':
      return left == right;
    case '!=':
      return left != right;
    default:
      return false;
  }
}

void _applyRuntimeCStyleUpdate(
  String raw,
  Map<String, int> vars,
  String Function(String input) resolveValue,
) {
  for (final part in raw.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final resolved = _resolveLoopExpression(trimmed, vars, resolveValue);
    if (resolved.endsWith('++')) {
      final name =
          resolved.substring(0, resolved.length - 2).trim().toLowerCase();
      vars[name] = (vars[name] ?? 0) + 1;
    } else if (resolved.endsWith('--')) {
      final name =
          resolved.substring(0, resolved.length - 2).trim().toLowerCase();
      vars[name] = (vars[name] ?? 0) - 1;
    } else if (resolved.contains('+=')) {
      final sides = resolved.split('+=');
      final name = sides[0].trim().toLowerCase();
      final value = int.tryParse(sides[1].trim()) ?? 0;
      vars[name] = (vars[name] ?? 0) + value;
    } else if (resolved.contains('-=')) {
      final sides = resolved.split('-=');
      final name = sides[0].trim().toLowerCase();
      final value = int.tryParse(sides[1].trim()) ?? 0;
      vars[name] = (vars[name] ?? 0) - value;
    } else if (resolved.contains('*=')) {
      final sides = resolved.split('*=');
      final name = sides[0].trim().toLowerCase();
      final value = int.tryParse(sides[1].trim()) ?? 1;
      vars[name] = (vars[name] ?? 0) * value;
    }
  }
}
