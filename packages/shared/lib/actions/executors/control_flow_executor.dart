import '../../types/action.dart';
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
      }
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

    default:
      return false;
  }
}
