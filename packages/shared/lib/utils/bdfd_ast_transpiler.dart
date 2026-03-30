import 'dart:convert';
import 'dart:math' as math;

import 'package:bot_creator_shared/types/action.dart';

import 'bdfd_ast.dart';

enum BdfdTranspileDiagnosticSeverity { warning, error }

class BdfdTranspileDiagnostic {
  const BdfdTranspileDiagnostic({
    required this.message,
    this.severity = BdfdTranspileDiagnosticSeverity.error,
    this.start,
    this.end,
    this.functionName,
  });

  final String message;
  final BdfdTranspileDiagnosticSeverity severity;
  final int? start;
  final int? end;
  final String? functionName;
}

class BdfdTranspileResult {
  const BdfdTranspileResult({required this.actions, required this.diagnostics});

  final List<Action> actions;
  final List<BdfdTranspileDiagnostic> diagnostics;

  bool get hasErrors => diagnostics.any(
    (diagnostic) =>
        diagnostic.severity == BdfdTranspileDiagnosticSeverity.error,
  );
}

class BdfdAstTranspiler {
  BdfdTranspileResult transpile(BdfdScriptAst script) {
    final diagnostics = <BdfdTranspileDiagnostic>[];
    final transpiler = _BdfdAstTranspilationScope(diagnostics: diagnostics);
    final actions = transpiler.transpileScript(script);
    return BdfdTranspileResult(
      actions: List<Action>.unmodifiable(actions),
      diagnostics: List<BdfdTranspileDiagnostic>.unmodifiable(diagnostics),
    );
  }
}

class _BdfdAstTranspilationScope {
  _BdfdAstTranspilationScope({
    required List<BdfdTranspileDiagnostic> diagnostics,
  }) : _diagnostics = diagnostics;

  final List<BdfdTranspileDiagnostic> _diagnostics;
  final Map<String, String> _pendingHttpHeaders = <String, String>{};
  int _httpRequestCounter = 0;
  int _threadActionCounter = 0;
  int _permissionCheckCounter = 0;
  int _callWorkflowCounter = 0;
  String? _lastHttpRequestKey;
  String? _lastCallWorkflowKey;
  final List<Action> _deferredInlineActions = <Action>[];
  dynamic _jsonContext;
  bool _hasJsonContext = false;
  List<String> _textSplitParts = <String>[];
  String? _useChannelId;
  bool _suppressErrors = false;
  int _loopIterationIndex = 0;
  int _loopDepth = 0;
  Map<String, int> _loopVariables = <String, int>{};
  final Map<String, String> _tempVariables = <String, String>{};
  final List<Map<String, dynamic>> _pendingModalInputs =
      <Map<String, dynamic>>[];

  List<Action> transpileScript(BdfdScriptAst script) {
    return _transpileNodes(script.nodes);
  }

  List<Action> _transpileNodes(List<BdfdAstNode> nodes) {
    final actions = <Action>[];
    final pendingResponse = _PendingResponse();

    var index = 0;
    while (index < nodes.length) {
      final node = nodes[index];
      if (node is BdfdTextAst) {
        pendingResponse.appendContent(node.value);
        index += 1;
        continue;
      }

      if (node is! BdfdFunctionCallAst) {
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message: 'Unsupported AST node encountered during transpilation.',
            start: node.start,
            end: node.end,
          ),
        );
        index += 1;
        continue;
      }

      if (_isBlockIfSignature(node)) {
        final flushed = pendingResponse.buildAction(channelId: _useChannelId);
        if (flushed != null) {
          actions.add(flushed);
        }

        final consumed = _consumeIfBlock(nodes: nodes, startIndex: index);
        if (consumed == null) {
          index += 1;
          continue;
        }

        actions.add(consumed.action);
        index = consumed.nextIndex;
        continue;
      }

      if (_isBlockLoopSignature(node)) {
        final consumed = _consumeLoopBlock(nodes: nodes, startIndex: index);
        if (consumed == null) {
          index += 1;
          continue;
        }

        if (consumed.isCStyleLoop) {
          final extraNames = consumed.cStyleInit!.keys.toSet();
          if (_isResponseOnlyLoopBody(
            consumed.bodyNodes,
            extraInlineNames: extraNames,
          )) {
            _applyCStyleLoopBodyToResponse(
              bodyNodes: consumed.bodyNodes,
              initVars: consumed.cStyleInit!,
              condition: consumed.cStyleCondition!,
              update: consumed.cStyleUpdate!,
              response: pendingResponse,
            );
          } else {
            final flushed = pendingResponse.buildAction(
              channelId: _useChannelId,
            );
            if (flushed != null) {
              actions.add(flushed);
            }
            actions.addAll(
              _transpileCStyleLoop(
                bodyNodes: consumed.bodyNodes,
                initVars: consumed.cStyleInit!,
                condition: consumed.cStyleCondition!,
                update: consumed.cStyleUpdate!,
              ),
            );
          }
        } else if (_isResponseOnlyLoopBody(consumed.bodyNodes)) {
          _applyLoopBodyToResponse(
            bodyNodes: consumed.bodyNodes,
            iterations: consumed.iterations,
            response: pendingResponse,
          );
        } else {
          final flushed = pendingResponse.buildAction(channelId: _useChannelId);
          if (flushed != null) {
            actions.add(flushed);
          }
          final loopActions =
              consumed.precomputedActions ??
              _transpileLoopIterations(
                bodyNodes: consumed.bodyNodes,
                iterations: consumed.iterations,
              );
          actions.addAll(loopActions);
        }
        index = consumed.nextIndex;
        continue;
      }

      if (_isBlockTrySignature(node)) {
        final flushed = pendingResponse.buildAction(channelId: _useChannelId);
        if (flushed != null) {
          actions.add(flushed);
        }

        final consumed = _consumeTryCatchBlock(nodes: nodes, startIndex: index);
        if (consumed == null) {
          index += 1;
          continue;
        }

        actions.addAll(consumed.precomputedActions ?? const <Action>[]);
        index = consumed.nextIndex;
        continue;
      }

      if (_isStandaloneIfDelimiter(node.normalizedName)) {
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Unexpected ${node.name} without a matching surrounding block ${r'$if'}[] statement.',
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
        index += 1;
        continue;
      }

      if (_isStandaloneLoopDelimiter(node.normalizedName)) {
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Unexpected ${node.name} without a matching surrounding block ${r'$for'}[] statement.',
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
        index += 1;
        continue;
      }

      if (_isStandaloneTryDelimiter(node.normalizedName)) {
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Unexpected ${node.name} without a matching surrounding ${r'$try'} block.',
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
        index += 1;
        continue;
      }

      if (_applyResponseMutation(node, pendingResponse)) {
        actions.addAll(_drainDeferredInlineActions());
        index += 1;
        continue;
      }

      final isCheckUserPermsInlineCandidate =
          node.normalizedName == 'checkuserperms' ||
          node.normalizedName == 'checkusersperms';
      final hasTrailingTextNode =
          index + 1 < nodes.length && nodes[index + 1] is BdfdTextAst;
      final allowsTopLevelInline =
          !isCheckUserPermsInlineCandidate ||
          pendingResponse.hasPendingContent ||
          hasTrailingTextNode;
      final inlineReplacement =
          allowsTopLevelInline ? _stringifyInlineFunction(node) : null;
      if (inlineReplacement != null) {
        pendingResponse.appendContent(inlineReplacement);
        actions.addAll(_drainDeferredInlineActions());
        index += 1;
        continue;
      }

      if (_requiresPendingResponseFlush(node.normalizedName)) {
        final flushed = pendingResponse.buildAction(channelId: _useChannelId);
        if (flushed != null) {
          actions.add(flushed);
        }
      }

      final emitted = _transpileStandaloneFunction(node);
      actions.addAll(_drainDeferredInlineActions());
      if (emitted != null) {
        actions.add(emitted);
      }

      index += 1;
    }

    final trailingResponse = pendingResponse.buildAction(
      channelId: _useChannelId,
    );
    if (trailingResponse != null) {
      actions.add(trailingResponse);
    }

    if (_suppressErrors && actions.isNotEmpty) {
      return <Action>[
        Action(
          type: BotCreatorActionType.ifBlock,
          payload: <String, dynamic>{
            'condition.variable': '1',
            'condition.operator': 'equals',
            'condition.value': '1',
            'thenActions': actions.map((action) => action.toJson()).toList(),
            'elseIfConditions': const <Map<String, dynamic>>[],
            'elseActions': const <Map<String, dynamic>>[],
            'suppressErrors': true,
          },
        ),
      ];
    }

    return actions;
  }

  bool _isBlockIfSignature(BdfdFunctionCallAst node) {
    return node.normalizedName == 'if' && node.arguments.length <= 1;
  }

  bool _isStandaloneIfDelimiter(String normalizedName) {
    return normalizedName == 'elseif' ||
        normalizedName == 'else' ||
        normalizedName == 'endif';
  }

  bool _isBlockLoopSignature(BdfdFunctionCallAst node) {
    return (node.normalizedName == 'for' || node.normalizedName == 'loop') &&
        (node.arguments.length <= 1 || node.arguments.length == 3);
  }

  bool _isStandaloneLoopDelimiter(String normalizedName) {
    return normalizedName == 'endfor' || normalizedName == 'endloop';
  }

  bool _isBlockTrySignature(BdfdFunctionCallAst node) {
    return node.normalizedName == 'try' && node.arguments.isEmpty;
  }

  bool _isStandaloneTryDelimiter(String normalizedName) {
    return normalizedName == 'catch' ||
        normalizedName == 'endtry' ||
        normalizedName == 'error';
  }

  _ConsumedLoopBlock? _consumeTryCatchBlock({
    required List<BdfdAstNode> nodes,
    required int startIndex,
  }) {
    final tryNode = nodes[startIndex];
    if (tryNode is! BdfdFunctionCallAst || !_isBlockTrySignature(tryNode)) {
      return null;
    }

    final tryNodes = <BdfdAstNode>[];
    final catchNodes = <BdfdAstNode>[];
    List<BdfdAstNode> currentTarget = tryNodes;
    var hasCatchBranch = false;
    var nestingDepth = 0;

    for (var cursor = startIndex + 1; cursor < nodes.length; cursor++) {
      final currentNode = nodes[cursor];

      if (currentNode is BdfdFunctionCallAst) {
        final name = currentNode.normalizedName;

        if (_isBlockTrySignature(currentNode)) {
          nestingDepth += 1;
          currentTarget.add(currentNode);
          continue;
        }

        if (name == 'endtry') {
          if (nestingDepth > 0) {
            nestingDepth -= 1;
            currentTarget.add(currentNode);
            continue;
          }

          final tryActions = _transpileNodes(tryNodes);
          final catchActions = _transpileNodes(catchNodes);

          if (catchActions.isEmpty) {
            return _ConsumedLoopBlock(
              precomputedActions: tryActions,
              nextIndex: cursor + 1,
              bodyNodes: const <BdfdAstNode>[],
              iterations: 0,
            );
          }

          final wrappedActions = <Action>[
            Action(
              type: BotCreatorActionType.ifBlock,
              payload: <String, dynamic>{
                'condition.variable': '((error.message))',
                'condition.operator': 'isEmpty',
                'condition.value': '',
                'thenActions':
                    tryActions.map((action) => action.toJson()).toList(),
                'elseIfConditions': const <Map<String, dynamic>>[],
                'elseActions':
                    catchActions.map((action) => action.toJson()).toList(),
              },
            ),
          ];
          return _ConsumedLoopBlock(
            precomputedActions: wrappedActions,
            nextIndex: cursor + 1,
            bodyNodes: const <BdfdAstNode>[],
            iterations: 0,
          );
        }

        if (nestingDepth == 0 && name == 'catch') {
          if (hasCatchBranch) {
            _diagnostics.add(
              BdfdTranspileDiagnostic(
                message: 'Duplicate ${r'$catch'} in ${r'$try'} block.',
                start: currentNode.start,
                end: currentNode.end,
                functionName: currentNode.name,
              ),
            );
            continue;
          }
          hasCatchBranch = true;
          currentTarget = catchNodes;
          continue;
        }
      }

      currentTarget.add(currentNode);
    }

    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message: '${tryNode.name} not closed with ${r'$endtry'}.',
        start: tryNode.start,
        end: tryNode.end,
        functionName: tryNode.name,
      ),
    );

    return _ConsumedLoopBlock(
      precomputedActions: _transpileNodes(tryNodes),
      nextIndex: nodes.length,
      bodyNodes: const <BdfdAstNode>[],
      iterations: 0,
    );
  }

  _ConsumedIfBlock? _consumeIfBlock({
    required List<BdfdAstNode> nodes,
    required int startIndex,
  }) {
    final ifNode = nodes[startIndex];
    if (ifNode is! BdfdFunctionCallAst || !_isBlockIfSignature(ifNode)) {
      return null;
    }

    final thenNodes = <BdfdAstNode>[];
    final elseIfBranches = <_IfBranch>[];
    final elseNodes = <BdfdAstNode>[];

    List<BdfdAstNode> currentTarget = thenNodes;
    var hasElseBranch = false;
    var nestingDepth = 0;

    for (var cursor = startIndex + 1; cursor < nodes.length; cursor++) {
      final currentNode = nodes[cursor];

      if (currentNode is BdfdFunctionCallAst) {
        final name = currentNode.normalizedName;

        if (_isBlockIfSignature(currentNode)) {
          nestingDepth += 1;
          currentTarget.add(currentNode);
          continue;
        }

        if (name == 'endif') {
          if (nestingDepth > 0) {
            nestingDepth -= 1;
            currentTarget.add(currentNode);
            continue;
          }

          final action = _buildIfAction(
            ifNode: ifNode,
            thenNodes: thenNodes,
            elseIfBranches: elseIfBranches,
            elseNodes: elseNodes,
          );
          return _ConsumedIfBlock(action: action, nextIndex: cursor + 1);
        }

        if (nestingDepth == 0 && name == 'elseif') {
          if (hasElseBranch) {
            _diagnostics.add(
              BdfdTranspileDiagnostic(
                message:
                    'Found ${currentNode.name} after ${r'$else'} in if block.',
                start: currentNode.start,
                end: currentNode.end,
                functionName: currentNode.name,
              ),
            );
            continue;
          }

          final branch = _IfBranch(
            conditionNode: currentNode,
            nodes: <BdfdAstNode>[],
          );
          elseIfBranches.add(branch);
          currentTarget = branch.nodes;
          continue;
        }

        if (nestingDepth == 0 && name == 'else') {
          if (hasElseBranch) {
            _diagnostics.add(
              BdfdTranspileDiagnostic(
                message: 'Duplicate ${r'$else'} branch in if block.',
                start: currentNode.start,
                end: currentNode.end,
                functionName: currentNode.name,
              ),
            );
            continue;
          }
          hasElseBranch = true;
          currentTarget = elseNodes;
          continue;
        }
      }

      currentTarget.add(currentNode);
    }

    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message: '${ifNode.name} not closed with ${r'$endif'}.',
        start: ifNode.start,
        end: ifNode.end,
        functionName: ifNode.name,
      ),
    );
    return _ConsumedIfBlock(
      action: _buildIfAction(
        ifNode: ifNode,
        thenNodes: thenNodes,
        elseIfBranches: elseIfBranches,
        elseNodes: elseNodes,
      ),
      nextIndex: nodes.length,
    );
  }

  _ConsumedLoopBlock? _consumeLoopBlock({
    required List<BdfdAstNode> nodes,
    required int startIndex,
  }) {
    final loopNode = nodes[startIndex];
    if (loopNode is! BdfdFunctionCallAst || !_isBlockLoopSignature(loopNode)) {
      return null;
    }

    final loopBodyNodes = <BdfdAstNode>[];
    var nestingDepth = 0;

    for (var cursor = startIndex + 1; cursor < nodes.length; cursor++) {
      final currentNode = nodes[cursor];

      if (currentNode is BdfdFunctionCallAst) {
        final name = currentNode.normalizedName;

        if (_isBlockLoopSignature(currentNode)) {
          nestingDepth += 1;
          loopBodyNodes.add(currentNode);
          continue;
        }

        if (_isStandaloneLoopDelimiter(name)) {
          if (nestingDepth > 0) {
            nestingDepth -= 1;
            loopBodyNodes.add(currentNode);
            continue;
          }

          return _buildConsumedLoop(
            loopNode: loopNode,
            bodyNodes: loopBodyNodes,
            nextIndex: cursor + 1,
          );
        }
      }

      loopBodyNodes.add(currentNode);
    }

    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message:
            '${loopNode.name} not closed with ${r'$endfor'} or ${r'$endloop'}.',
        start: loopNode.start,
        end: loopNode.end,
        functionName: loopNode.name,
      ),
    );

    return _buildConsumedLoop(
      loopNode: loopNode,
      bodyNodes: loopBodyNodes,
      nextIndex: nodes.length,
    );
  }

  _ConsumedLoopBlock _buildConsumedLoop({
    required BdfdFunctionCallAst loopNode,
    required List<BdfdAstNode> bodyNodes,
    required int nextIndex,
  }) {
    // C-style for: $for[init; condition; update]
    if (loopNode.arguments.length == 3) {
      final initStr = _stringifyArgument(loopNode, 0);
      final condStr = _stringifyArgument(loopNode, 1).trim();
      final updateStr = _stringifyArgument(loopNode, 2);

      final initVars = _parseCStyleLoopInit(initStr, loopNode);
      if (initVars == null) {
        return _ConsumedLoopBlock(
          nextIndex: nextIndex,
          bodyNodes: bodyNodes,
          iterations: 0,
        );
      }

      if (!_validateCStyleCondition(condStr, initVars, loopNode)) {
        return _ConsumedLoopBlock(
          nextIndex: nextIndex,
          bodyNodes: bodyNodes,
          iterations: 0,
        );
      }

      return _ConsumedLoopBlock(
        nextIndex: nextIndex,
        bodyNodes: bodyNodes,
        iterations: 0,
        cStyleInit: initVars,
        cStyleCondition: condStr,
        cStyleUpdate: updateStr,
      );
    }

    // Simple for: $for[n]
    final iterations = _parseLoopIterations(loopNode);
    if (iterations == null) {
      return _ConsumedLoopBlock(
        nextIndex: nextIndex,
        bodyNodes: bodyNodes,
        iterations: 0,
      );
    }

    return _ConsumedLoopBlock(
      nextIndex: nextIndex,
      bodyNodes: bodyNodes,
      iterations: iterations,
    );
  }

  static final RegExp _cStyleConditionPattern = RegExp(
    r'^(\w+)\s*(<=|>=|<|>|==|!=)\s*(-?\w+)$',
  );

  Map<String, int>? _parseCStyleLoopInit(String raw, BdfdFunctionCallAst node) {
    final vars = <String, int>{};
    for (final part in raw.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex < 0) {
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Invalid loop init: expected "variable = value", got "$trimmed".',
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
        return null;
      }
      final name = trimmed.substring(0, eqIndex).trim().toLowerCase();
      final valueStr = trimmed.substring(eqIndex + 1).trim();
      final value = int.tryParse(valueStr);
      if (value == null) {
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Loop init variable "$name" must be an integer literal, got "$valueStr".',
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
        return null;
      }
      vars[name] = value;
    }
    if (vars.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'Loop init must declare at least one variable.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return vars;
  }

  bool _validateCStyleCondition(
    String raw,
    Map<String, int> initVars,
    BdfdFunctionCallAst node,
  ) {
    final match = _cStyleConditionPattern.firstMatch(raw);
    if (match == null) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              'Invalid loop condition: expected "variable op value", got "$raw".',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return false;
    }
    return true;
  }

  int _resolveCStyleOperand(String token, Map<String, int> vars) {
    final asVar = vars[token.toLowerCase()];
    if (asVar != null) return asVar;
    return int.tryParse(token) ?? 0;
  }

  bool _evaluateCStyleCondition(String raw, Map<String, int> vars) {
    final match = _cStyleConditionPattern.firstMatch(raw);
    if (match == null) return false;
    final left = _resolveCStyleOperand(match.group(1)!, vars);
    final op = match.group(2)!;
    final right = _resolveCStyleOperand(match.group(3)!, vars);
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

  void _applyCStyleLoopUpdate(String raw, Map<String, int> vars) {
    for (final part in raw.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.endsWith('++')) {
        final name =
            trimmed.substring(0, trimmed.length - 2).trim().toLowerCase();
        vars[name] = (vars[name] ?? 0) + 1;
      } else if (trimmed.endsWith('--')) {
        final name =
            trimmed.substring(0, trimmed.length - 2).trim().toLowerCase();
        vars[name] = (vars[name] ?? 0) - 1;
      } else if (trimmed.contains('+=')) {
        final sides = trimmed.split('+=');
        final name = sides[0].trim().toLowerCase();
        final value = int.tryParse(sides[1].trim()) ?? 0;
        vars[name] = (vars[name] ?? 0) + value;
      } else if (trimmed.contains('-=')) {
        final sides = trimmed.split('-=');
        final name = sides[0].trim().toLowerCase();
        final value = int.tryParse(sides[1].trim()) ?? 0;
        vars[name] = (vars[name] ?? 0) - value;
      } else if (trimmed.contains('*=')) {
        final sides = trimmed.split('*=');
        final name = sides[0].trim().toLowerCase();
        final value = int.tryParse(sides[1].trim()) ?? 1;
        vars[name] = (vars[name] ?? 0) * value;
      }
    }
  }

  List<Action> _transpileCStyleLoop({
    required List<BdfdAstNode> bodyNodes,
    required Map<String, int> initVars,
    required String condition,
    required String update,
  }) {
    if (bodyNodes.isEmpty) return const <Action>[];

    final previousIndex = _loopIterationIndex;
    final previousVars = Map<String, int>.from(_loopVariables);
    _loopDepth += 1;
    _loopVariables = Map<String, int>.from(initVars);

    final actions = <Action>[];
    var iterationCount = 0;

    while (_evaluateCStyleCondition(condition, _loopVariables) &&
        iterationCount < _maxSupportedLoopIterations) {
      _loopIterationIndex = iterationCount;
      actions.addAll(_transpileNodes(bodyNodes));
      _applyCStyleLoopUpdate(update, _loopVariables);
      iterationCount++;
    }

    _loopDepth -= 1;
    _loopIterationIndex = previousIndex;
    _loopVariables = previousVars;

    return actions;
  }

  void _applyCStyleLoopBodyToResponse({
    required List<BdfdAstNode> bodyNodes,
    required Map<String, int> initVars,
    required String condition,
    required String update,
    required _PendingResponse response,
  }) {
    if (bodyNodes.isEmpty) return;

    final previousIndex = _loopIterationIndex;
    final previousVars = Map<String, int>.from(_loopVariables);
    _loopDepth += 1;
    _loopVariables = Map<String, int>.from(initVars);

    var iterationCount = 0;

    while (_evaluateCStyleCondition(condition, _loopVariables) &&
        iterationCount < _maxSupportedLoopIterations) {
      _loopIterationIndex = iterationCount;
      for (final node in bodyNodes) {
        if (node is BdfdTextAst) {
          response.appendContent(node.value);
          continue;
        }
        if (node is! BdfdFunctionCallAst) continue;
        if (_applyResponseMutation(node, response)) continue;
        final inlineResult = _stringifyInlineFunction(node);
        if (inlineResult != null) {
          response.appendContent(inlineResult);
          continue;
        }
        final placeholder = _inlineRuntimePlaceholder(node);
        if (placeholder != null) {
          response.appendContent(placeholder);
          continue;
        }
        _transpileStandaloneFunction(node);
      }
      _applyCStyleLoopUpdate(update, _loopVariables);
      iterationCount++;
    }

    _loopDepth -= 1;
    _loopIterationIndex = previousIndex;
    _loopVariables = previousVars;
  }

  int? _parseLoopIterations(BdfdFunctionCallAst loopNode) {
    final raw = _stringifyArgument(loopNode, 0).trim();
    if (raw.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${loopNode.name} requires an iteration count.',
          start: loopNode.start,
          end: loopNode.end,
          functionName: loopNode.name,
        ),
      );
      return null;
    }

    final parsed = int.tryParse(raw);
    if (parsed == null) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              '${loopNode.name} iteration count must be an integer literal.',
          start: loopNode.start,
          end: loopNode.end,
          functionName: loopNode.name,
        ),
      );
      return null;
    }

    if (parsed < 0) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${loopNode.name} iteration count must be non-negative.',
          start: loopNode.start,
          end: loopNode.end,
          functionName: loopNode.name,
        ),
      );
      return null;
    }

    if (parsed > _maxSupportedLoopIterations) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              '${loopNode.name} iteration count $parsed exceeds limit $_maxSupportedLoopIterations and will be capped.',
          severity: BdfdTranspileDiagnosticSeverity.warning,
          start: loopNode.start,
          end: loopNode.end,
          functionName: loopNode.name,
        ),
      );
      return _maxSupportedLoopIterations;
    }

    return parsed;
  }

  List<Action> _transpileLoopIterations({
    required List<BdfdAstNode> bodyNodes,
    required int iterations,
  }) {
    if (iterations <= 0 || bodyNodes.isEmpty) {
      return const <Action>[];
    }

    final previousIndex = _loopIterationIndex;
    _loopDepth += 1;
    final actions = <Action>[];
    for (var index = 0; index < iterations; index++) {
      _loopIterationIndex = index;
      actions.addAll(_transpileNodes(bodyNodes));
    }
    _loopDepth -= 1;
    _loopIterationIndex = previousIndex;
    return actions;
  }

  /// Returns `true` when every node in [bodyNodes] is either plain text,
  /// an inline-only function, or a response-mutation function.  In that case
  /// the loop body can be unrolled directly into the current pending response
  /// instead of flushing the response and creating separate actions.
  bool _isResponseOnlyLoopBody(
    List<BdfdAstNode> bodyNodes, {
    Set<String>? extraInlineNames,
  }) {
    for (final node in bodyNodes) {
      if (node is BdfdTextAst) continue;
      if (node is! BdfdFunctionCallAst) return false;
      final name = node.normalizedName;
      if (_isInlineOnlyFunction(name)) continue;
      if (_inlineRuntimeVariables.containsKey(name)) continue;
      if (_isResponseMutationFunction(name)) continue;
      // JSON helpers that mutate compile-time state only (no action produced).
      if (_isJsonMutationFunction(name)) continue;
      if (extraInlineNames != null && extraInlineNames.contains(name)) continue;
      return false;
    }
    return true;
  }

  bool _isResponseMutationFunction(String normalizedName) {
    switch (normalizedName) {
      case 'nomention':
      case 'title':
      case 'description':
      case 'color':
      case 'footer':
      case 'footericon':
      case 'thumbnail':
      case 'image':
      case 'author':
      case 'authoricon':
      case 'authorurl':
      case 'addfield':
      case 'addtimestamp':
      case 'embeddedurl':
      case 'addcontainer':
      case 'addsection':
      case 'addthumbnail':
      case 'addbutton':
      case 'addselectmenuoption':
      case 'newselectmenu':
      case 'editselectmenu':
      case 'editselectmenuoption':
      case 'editbutton':
      case 'removeallcomponents':
      case 'removebuttons':
      case 'removecomponent':
      case 'addseparator':
      case 'addtextdisplay':
      case 'ephemeral':
      case 'allowmention':
      case 'allowusermentions':
      case 'tts':
      case 'removelinks':
      case 'allowrolementions':
      case 'suppresserrors':
      case 'embedsuppresserrors':
        return true;
      default:
        return false;
    }
  }

  bool _isJsonMutationFunction(String normalizedName) {
    switch (normalizedName) {
      case 'jsonparse':
      case 'jsonset':
      case 'jsonsetstring':
      case 'jsonunset':
      case 'jsonclear':
      case 'jsonarray':
      case 'jsonarrayappend':
      case 'jsonarrayunshift':
      case 'jsonarraysort':
      case 'jsonarrayreverse':
        return true;
      default:
        return false;
    }
  }

  /// Applies the loop body's mutations directly to [response] for each
  /// iteration, without flushing or creating separate actions.
  void _applyLoopBodyToResponse({
    required List<BdfdAstNode> bodyNodes,
    required int iterations,
    required _PendingResponse response,
  }) {
    if (iterations <= 0 || bodyNodes.isEmpty) return;

    final previousIndex = _loopIterationIndex;
    _loopDepth += 1;
    for (var index = 0; index < iterations; index++) {
      _loopIterationIndex = index;
      for (final node in bodyNodes) {
        if (node is BdfdTextAst) {
          response.appendContent(node.value);
          continue;
        }
        if (node is! BdfdFunctionCallAst) continue;
        if (_applyResponseMutation(node, response)) continue;
        // Inline function or runtime variable — resolve and append.
        final inlineResult = _stringifyInlineFunction(node);
        if (inlineResult != null) {
          response.appendContent(inlineResult);
          continue;
        }
        final placeholder = _inlineRuntimePlaceholder(node);
        if (placeholder != null) {
          response.appendContent(placeholder);
          continue;
        }
        // JSON mutation functions — apply side-effect only.
        _transpileStandaloneFunction(node);
      }
    }
    _loopDepth -= 1;
    _loopIterationIndex = previousIndex;
  }

  Action _buildIfAction({
    required BdfdFunctionCallAst ifNode,
    required List<BdfdAstNode> thenNodes,
    required List<_IfBranch> elseIfBranches,
    required List<BdfdAstNode> elseNodes,
  }) {
    final condition = _parseCondition(_stringifyArgument(ifNode, 0), ifNode);
    final thenActions = _transpileNodes(thenNodes);
    final elseActions = _transpileNodes(elseNodes);

    final elseIfPayload = elseIfBranches
        .map((branch) {
          final elseIfCondition = _parseCondition(
            _stringifyArgument(branch.conditionNode, 0),
            branch.conditionNode,
          );
          return <String, dynamic>{
            ...elseIfCondition.toPayload(prefix: 'condition.'),
            'actions':
                _transpileNodes(
                  branch.nodes,
                ).map((action) => action.toJson()).toList(),
          };
        })
        .toList(growable: false);

    return Action(
      type: BotCreatorActionType.ifBlock,
      payload: <String, dynamic>{
        ...condition.toPayload(prefix: 'condition.'),
        'thenActions': thenActions.map((action) => action.toJson()).toList(),
        'elseIfConditions': elseIfPayload,
        'elseActions': elseActions.map((action) => action.toJson()).toList(),
      },
    );
  }

  bool _applyResponseMutation(
    BdfdFunctionCallAst node,
    _PendingResponse response,
  ) {
    switch (node.normalizedName) {
      case 'nomention':
        response._allowMentions = false;
        return true;
      case 'title':
        response.ensureEmbed()['title'] = _stringifyArgument(node, 0);
        return true;
      case 'description':
        response.ensureEmbed()['description'] = _stringifyArgument(node, 0);
        return true;
      case 'color':
        response.ensureEmbed()['color'] = _stringifyArgument(node, 0);
        return true;
      case 'footer':
        final footer = <String, dynamic>{'text': _stringifyArgument(node, 0)};
        final iconUrl = _stringifyArgument(node, 1);
        if (iconUrl.isNotEmpty) {
          footer['icon_url'] = iconUrl;
        }
        response.ensureEmbed()['footer'] = footer;
        return true;
      case 'thumbnail':
        response.ensureEmbed()['thumbnail'] = <String, dynamic>{
          'url': _stringifyArgument(node, 0),
        };
        return true;
      case 'image':
        response.ensureEmbed()['image'] = <String, dynamic>{
          'url': _stringifyArgument(node, 0),
        };
        return true;
      case 'author':
        final author = <String, dynamic>{'name': _stringifyArgument(node, 0)};
        final iconUrl = _stringifyArgument(node, 1);
        final url = _stringifyArgument(node, 2);
        if (iconUrl.isNotEmpty) {
          author['icon_url'] = iconUrl;
        }
        if (url.isNotEmpty) {
          author['url'] = url;
        }
        response.ensureEmbed()['author'] = author;
        return true;
      case 'addfield':
        final field = <String, dynamic>{
          'name': _stringifyArgument(node, 0),
          'value': _stringifyArgument(node, 1),
          'inline': _parseBooleanLike(_stringifyArgument(node, 2)),
        };
        response.ensureEmbedFields().add(field);
        return true;
      case 'addtimestamp':
        final timestamp = _stringifyArgument(node, 0);
        response.ensureEmbed()['timestamp'] =
            timestamp.isEmpty ? 'now' : timestamp;
        return true;
      case 'authoricon':
        final embed = response.ensureEmbed();
        final author =
            (embed['author'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        author['icon_url'] = _stringifyArgument(node, 0);
        embed['author'] = author;
        return true;
      case 'authorurl':
        final embed = response.ensureEmbed();
        final author =
            (embed['author'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        author['url'] = _stringifyArgument(node, 0);
        embed['author'] = author;
        return true;
      case 'embeddedurl':
        response.ensureEmbed()['url'] = _stringifyArgument(node, 0);
        return true;
      case 'footericon':
        final embed = response.ensureEmbed();
        final footer =
            (embed['footer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        footer['icon_url'] = _stringifyArgument(node, 0);
        embed['footer'] = footer;
        return true;
      case 'addcontainer':
        response.ensureEmbed()['container'] = <String, dynamic>{
          'color': _stringifyArgument(node, 0),
        };
        return true;
      case 'addsection':
        response.ensureEmbed()['section'] = <String, dynamic>{
          'content': _stringifyArgument(node, 0),
        };
        return true;
      case 'addthumbnail':
        response.ensureEmbed()['thumbnail'] = <String, dynamic>{
          'url': _stringifyArgument(node, 0),
        };
        return true;
      case 'addbutton':
        final newRow = _parseBooleanLike(_stringifyArgument(node, 0));
        final interactionIdOrUrl = _stringifyArgument(node, 1);
        final label = _stringifyArgument(node, 2);
        final style = _stringifyArgument(node, 3).trim().toLowerCase();
        final disabled = _parseBooleanLike(_stringifyArgument(node, 4));
        final emoji = _stringifyArgument(node, 5);
        final messageId = _stringifyArgument(node, 6);
        response.addButton(
          newRow: newRow,
          interactionIdOrUrl: interactionIdOrUrl,
          label: label,
          style: style.isEmpty ? 'primary' : style,
          disabled: disabled,
          emoji: emoji,
          messageId: messageId,
        );
        return true;
      case 'addselectmenuoption':
        final menuId = response._currentSelectMenuId ?? '';
        final label = _stringifyArgument(node, 0);
        final value = _stringifyArgument(node, 1);
        final description = _stringifyArgument(node, 2);
        final isDefault = _parseBooleanLike(_stringifyArgument(node, 3));
        final emoji = _stringifyArgument(node, 4);
        response.addSelectMenuOption(
          menuId: menuId,
          label: label,
          value: value,
          description: description,
          isDefault: isDefault,
          emoji: emoji,
        );
        return true;
      case 'newselectmenu':
        final customId = _stringifyArgument(node, 0);
        final placeholder = _stringifyArgument(node, 1);
        final minValues = _stringifyArgument(node, 2);
        final maxValues = _stringifyArgument(node, 3);
        final disabled = _parseBooleanLike(_stringifyArgument(node, 4));
        response._currentSelectMenuId = customId;
        response.addComponent(<String, dynamic>{
          'type': 'selectMenu',
          'customId': customId,
          if (placeholder.isNotEmpty) 'placeholder': placeholder,
          if (minValues.isNotEmpty) 'minValues': int.tryParse(minValues) ?? 1,
          if (maxValues.isNotEmpty) 'maxValues': int.tryParse(maxValues) ?? 1,
          'disabled': disabled,
        });
        return true;
      case 'editselectmenu':
        return true;
      case 'editselectmenuoption':
        return true;
      case 'editbutton':
        return true;
      case 'removeallcomponents':
        response.clearComponents();
        return true;
      case 'removebuttons':
        response.clearButtons();
        return true;
      case 'removecomponent':
        final customId = _stringifyArgument(node, 0);
        response.removeComponent(customId);
        return true;
      case 'addseparator':
        response.addComponent(<String, dynamic>{
          'type': 'separator',
          'spacing': _stringifyArgument(node, 0),
          'divider': _parseBooleanLike(
            _stringifyArgument(node, 1).isEmpty
                ? 'yes'
                : _stringifyArgument(node, 1),
          ),
        });
        return true;
      case 'addtextdisplay':
        response.addComponent(<String, dynamic>{
          'type': 'textDisplay',
          'content': _stringifyArgument(node, 0),
        });
        return true;
      case 'ephemeral':
        response._ephemeral = true;
        return true;
      case 'allowmention':
        response._allowMentions = true;
        return true;
      case 'allowusermentions':
        response._allowUserMentions = true;
        return true;
      case 'tts':
        response._tts = true;
        return true;
      case 'removelinks':
        response._removeLinks = true;
        return true;
      case 'allowrolementions':
        response._allowRoleMentions = true;
        return true;
      case 'suppresserrors':
        _suppressErrors = true;
        return true;
      case 'embedsuppresserrors':
        _suppressErrors = true;
        return true;
      default:
        return false;
    }
  }

  Action? _transpileStandaloneFunction(BdfdFunctionCallAst node) {
    switch (node.normalizedName) {
      case 'if':
        return _transpileIf(node);
      case 'onlyif':
        return _transpileOnlyIf(node);
      case 'onlyforusers':
        return _transpileOnlyForUsers(node);
      case 'onlyforchannels':
        return _transpileOnlyForChannels(node);
      case 'onlyforroles':
        return _transpileOnlyForRoles(node);
      case 'onlyforids':
        return _transpileOnlyForIds(node);
      case 'onlyforroleids':
        return _transpileOnlyForRoleIds(node);
      case 'onlyforservers':
        return _transpileOnlyForServers(node);
      case 'onlyforcategories':
        return _transpileOnlyForCategories(node);
      case 'ignorechannels':
        return _transpileIgnoreChannels(node);
      case 'onlynsfw':
        return _transpileOnlyNsfw(node);
      case 'onlyadmin':
        return _transpileOnlyAdmin(node);
      case 'onlyperms':
        return _transpileOnlyPerms(node, bot: false);
      case 'onlybotperms':
        return _transpileOnlyPerms(node, bot: true);
      case 'onlybotchannelperms':
        return _transpileOnlyBotChannelPerms(node);
      case 'checkuserperms':
      case 'checkusersperms':
        return _transpileCheckUserPerms(node);
      case 'onlyifmessagecontains':
        return _transpileOnlyIfMessageContains(node);
      case 'stop':
        return _buildForcedStopAction();
      case 'sendmessage':
      case 'reply':
        final content = _stringifyArgument(node, 0);
        return _buildRespondWithMessageAction(content: content);
      case 'channelsendmessage':
        return _buildChannelSendMessageAction(node);
      case 'changeusername':
        return _buildChangeUsernameAction(node);
      case 'changeusernamewithid':
        return _buildChangeUsernameWithIdAction(node);
      case 'startthread':
        return _buildStartThreadAction(node);
      case 'editthread':
        return _buildEditThreadAction(node);
      case 'threadaddmember':
        return _buildThreadMemberAction(node, add: true);
      case 'threadremovemember':
        return _buildThreadMemberAction(node, add: false);
      case 'httpaddheader':
        _storePendingHttpHeader(node);
        return null;
      case 'httpget':
        return _buildHttpRequestAction(method: 'GET', node: node);
      case 'httppost':
        return _buildHttpRequestAction(method: 'POST', node: node);
      case 'httpput':
        return _buildHttpRequestAction(method: 'PUT', node: node);
      case 'httpdelete':
        return _buildHttpRequestAction(method: 'DELETE', node: node);
      case 'httppatch':
        return _buildHttpRequestAction(method: 'PATCH', node: node);
      case 'setuservar':
        return _buildSetScopedVariableAction(scope: 'user', node: node);
      case 'setservervar':
      case 'setguildvar':
        return _buildSetScopedVariableAction(scope: 'guild', node: node);
      case 'setchannelvar':
        return _buildSetScopedVariableAction(scope: 'channel', node: node);
      case 'setmembervar':
      case 'setguildmembervar':
        return _buildSetScopedVariableAction(scope: 'guildMember', node: node);
      case 'setmessagevar':
        return _buildSetScopedVariableAction(scope: 'message', node: node);
      case 'awaitfunc':
        return _buildAwaitFuncAction(node);
      case 'jsonparse':
        _jsonParse(node);
        return null;
      case 'jsonset':
        _jsonSet(node, forceString: false);
        return null;
      case 'jsonsetstring':
        _jsonSet(node, forceString: true);
        return null;
      case 'jsonunset':
        _jsonUnset(node);
        return null;
      case 'jsonclear':
        _jsonClear();
        return null;
      case 'jsonarray':
        _jsonArray(node);
        return null;
      case 'jsonarrayappend':
        _jsonArrayAppend(node);
        return null;
      case 'jsonarrayunshift':
        _jsonArrayUnshift(node);
        return null;
      case 'jsonarraysort':
        _jsonArraySort(node);
        return null;
      case 'jsonarrayreverse':
        _jsonArrayReverse(node);
        return null;
      // Moderation actions
      case 'ban':
        return _buildBanAction(node);
      case 'banid':
        return _buildBanIdAction(node);
      case 'unban':
        return _buildUnbanAction(node);
      case 'unbanid':
        return _buildUnbanIdAction(node);
      case 'kick':
        return _buildKickAction(node);
      case 'kickmention':
        return _buildKickMentionAction(node);
      case 'timeout':
        return _buildTimeoutAction(node);
      case 'mute':
        return _buildMuteAction(node);
      case 'untimeout':
        return _buildUntimeoutAction(node);
      case 'unmute':
        return _buildUnmuteAction(node);
      case 'clear':
        return _buildClearAction(node);
      // Role actions
      case 'giverole':
        return _buildGiveRoleAction(node);
      case 'giveroles':
        final giveRolesActions = _buildMultiRoleAction(node, give: true);
        if (giveRolesActions.isNotEmpty) {
          _deferredInlineActions.addAll(giveRolesActions);
        }
        return null;
      case 'rolegrant':
        final roleGrantActions = _buildRoleGrantAction(node);
        if (roleGrantActions.isNotEmpty) {
          _deferredInlineActions.addAll(roleGrantActions);
        }
        return null;
      case 'takerole':
        return _buildTakeRoleAction(node);
      case 'takeroles':
        final takeRolesActions = _buildMultiRoleAction(node, give: false);
        if (takeRolesActions.isNotEmpty) {
          _deferredInlineActions.addAll(takeRolesActions);
        }
        return null;
      case 'createrole':
        return _buildCreateRoleAction(node);
      case 'deleterole':
        return _buildDeleteRoleAction(node);
      case 'colorrole':
        return _buildColorRoleAction(node);
      case 'modifyrole':
        return _buildModifyRoleAction(node);
      case 'modifyroleperms':
        return _buildModifyRolePermsAction(node);
      case 'setuserroles':
        return _buildSetUserRolesAction(node);
      // Message actions
      case 'deletemessage':
        return _buildDeleteMessageAction(node);
      case 'deletein':
        return _buildDeleteInAction(node);
      case 'dm':
        return _buildDmAction(node);
      case 'editmessage':
        return _buildEditMessageAction(node);
      case 'editin':
        return _buildEditInAction(node);
      case 'editembedin':
        return _buildEditEmbedInAction(node);
      case 'pinmessage':
        return _buildPinMessageAction(node);
      case 'unpinmessage':
        return _buildUnpinMessageAction(node);
      case 'publishmessage':
        return _buildPublishMessageAction(node);
      case 'replyin':
        return _buildReplyInAction(node);
      case 'sendembedmessage':
        return _buildSendEmbedMessageAction(node);
      case 'usechannel':
        return _buildUseChannelAction(node);
      // Channel actions
      case 'createchannel':
        return _buildCreateChannelAction(node);
      case 'deletechannels':
      case 'deletechannelsbyname':
        return _buildDeleteChannelsAction(node);
      case 'modifychannel':
        return _buildModifyChannelAction(node);
      case 'editchannelperms':
        return _buildEditChannelPermsAction(node);
      case 'modifychannelperms':
        return _buildModifyChannelPermsAction(node);
      case 'slowmode':
        return _buildSlowmodeAction(node);
      // Reaction actions
      case 'addreactions':
        return _buildAddReactionsAction(node);
      case 'addcmdreactions':
        return _buildAddCmdReactionsAction(node);
      case 'addmessagereactions':
        return _buildAddMessageReactionsAction(node);
      case 'clearreactions':
        return _buildClearReactionsAction(node);
      // Emoji actions
      case 'addemoji':
        return _buildAddEmojiAction(node);
      case 'removeemoji':
        return _buildRemoveEmojiAction(node);
      // Webhook actions
      case 'webhooksend':
        return _buildWebhookSendAction(node);
      case 'webhookcreate':
        return _buildWebhookCreateAction(node);
      case 'webhookdelete':
        return _buildWebhookDeleteAction(node);
      // Modal action
      case 'newmodal':
        return _buildNewModalAction(node);
      case 'addtextinput':
        _pendingModalInputs.add(<String, dynamic>{
          'label': _stringifyArgument(node, 0),
          'style': _stringifyArgument(node, 1),
          'customId': _stringifyArgument(node, 2),
          'required': _parseBooleanLike(
            _stringifyArgument(node, 3).isEmpty
                ? 'yes'
                : _stringifyArgument(node, 3),
          ),
          if (_stringifyArgument(node, 4).isNotEmpty)
            'value': _stringifyArgument(node, 4),
          if (_stringifyArgument(node, 5).isNotEmpty)
            'placeholder': _stringifyArgument(node, 5),
          if (_stringifyArgument(node, 6).isNotEmpty)
            'minLength': int.tryParse(_stringifyArgument(node, 6)) ?? 0,
          if (_stringifyArgument(node, 7).isNotEmpty)
            'maxLength': int.tryParse(_stringifyArgument(node, 7)) ?? 4000,
        });
        return null;
      // Defer action
      case 'defer':
        return Action(
          type: BotCreatorActionType.respondWithMessage,
          payload: const <String, dynamic>{
            'content': '',
            'deferred': true,
            'ephemeral': false,
          },
        );
      // Cooldown actions
      case 'cooldown':
        return _buildCooldownAction(node, scope: 'user');
      case 'globalcooldown':
        return _buildCooldownAction(node, scope: 'global');
      case 'servercooldown':
        return _buildCooldownAction(node, scope: 'guild');
      case 'changecooldowntime':
        return _buildChangeCooldownTimeAction(node);
      // Variable operations
      case 'setvar':
        // BDFD wiki: $setVar[Variable name;New value;(User ID)]
        final svUserId =
            node.arguments.length > 2 ? _stringifyArgument(node, 2).trim() : '';
        return _buildSetScopedVariableAction(
          scope: svUserId.isNotEmpty ? 'user' : 'global',
          node: node,
        );
      case 'resetuservar':
        return _buildResetScopedVariableAction(scope: 'user', node: node);
      case 'resetservervar':
      case 'resetguildvar':
        return _buildResetScopedVariableAction(scope: 'guild', node: node);
      case 'resetchannelvar':
        return _buildResetScopedVariableAction(scope: 'channel', node: node);
      case 'resetmembervar':
      case 'resetguildmembervar':
        return _buildResetScopedVariableAction(
          scope: 'guildMember',
          node: node,
        );
      // Text split state
      case 'textsplit':
        _textSplitState(node);
        return null;
      // Blacklist guards
      case 'blacklistids':
        return _transpileBlacklistIds(node);
      case 'blacklistroles':
        return _transpileBlacklistRoles(node);
      case 'blacklistrolesids':
      case 'blacklistroleids':
        return _transpileBlacklistRoleIds(node);
      case 'blacklistservers':
        return _transpileBlacklistServers(node);
      case 'blacklistusers':
        return _transpileBlacklistUsers(node);
      // Bot actions
      case 'botleave':
        return Action(
          type: BotCreatorActionType.updateGuild,
          payload: const <String, dynamic>{'leave': true},
        );
      case 'bottyping':
        return Action(
          type: BotCreatorActionType.sendMessage,
          payload: const <String, dynamic>{
            'targetType': 'typing',
            'channelId': '((channel.id))',
          },
        );
      // Close/new ticket scaffolding
      case 'closeticket':
        // BDFD wiki: $closeTicket[Error message] — error message is sent when
        // the channel is not a ticket.
        final ctErrorMsg = _stringifyArgument(node, 0).trim();
        return Action(
          type: BotCreatorActionType.updateChannel,
          payload: <String, dynamic>{
            'channelId': '((channel.id))',
            'archived': true,
            'locked': true,
            if (ctErrorMsg.isNotEmpty) 'errorMessage': ctErrorMsg,
          },
        );
      case 'newticket':
        return _buildNewTicketAction(node);
      // Args check
      case 'argscheck':
        return _buildArgsCheckAction(node);
      // Workflow call
      case 'callworkflow':
        return _buildCallWorkflowAction(node);
      default:
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Unsupported BDFD function for action transpilation: ${node.name}.',
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
        return null;
    }
  }

  Action _transpileIf(BdfdFunctionCallAst node) {
    final condition = _parseCondition(_stringifyArgument(node, 0), node);
    final thenActions = _transpileBranchArgument(node, 1);
    final elseActions = _transpileBranchArgument(node, 2);

    return Action(
      type: BotCreatorActionType.ifBlock,
      payload: <String, dynamic>{
        ...condition.toPayload(prefix: 'condition.'),
        'thenActions': thenActions.map((action) => action.toJson()).toList(),
        'elseIfConditions': const <Map<String, dynamic>>[],
        'elseActions': elseActions.map((action) => action.toJson()).toList(),
      },
    );
  }

  Action _transpileOnlyIf(BdfdFunctionCallAst node) {
    final condition = _parseCondition(_stringifyArgument(node, 0), node);
    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(
        message: _stringifyArgument(node, 1),
      ),
    );
  }

  Action? _transpileOnlyForUsers(BdfdFunctionCallAst node) {
    final guard = _extractGuardValuesAndMessage(node);
    if (guard.values.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one username.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.values
          .map(
            (username) => _ParsedCondition(
              left: '((author.username))',
              operator: 'matches',
              right:
                  '(?i)^${RegExp.escape(username)}'
                  r'$',
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForIds(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one user ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((author.id))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForChannels(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one channel ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((channel.id))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForRoles(BdfdFunctionCallAst node) {
    final guard = _extractGuardValuesAndMessage(node);
    if (guard.values.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one role name.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.values
          .map(
            (name) => _ParsedCondition.logical(
              group: 'or',
              conditions: <_ParsedCondition>[
                _ParsedCondition(
                  left: '((member.roles))',
                  operator: 'contains',
                  right: name,
                ),
                _ParsedCondition(
                  left: '((member.roleNames))',
                  operator: 'contains',
                  right: name,
                ),
              ],
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForRoleIds(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one role ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((member.roles))',
              operator: 'contains',
              right: id,
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForServers(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one server ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((guild.id))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForCategories(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one category ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((channel.parentId))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileIgnoreChannels(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one channel ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((channel.id))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  Action _transpileOnlyNsfw(BdfdFunctionCallAst node) {
    const condition = _ParsedCondition(
      left: '((channel.nsfw))',
      operator: 'equals',
      right: 'true',
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(
        message: _stringifyArgument(node, 0),
      ),
    );
  }

  Action _transpileOnlyAdmin(BdfdFunctionCallAst node) {
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: const <_ParsedCondition>[
        _ParsedCondition(
          left: '((member.isAdmin))',
          operator: 'equals',
          right: 'true',
        ),
        _ParsedCondition(
          left: '((member.permissions))',
          operator: 'contains',
          right: 'administrator',
        ),
        _ParsedCondition(
          left: '((author.id))',
          operator: 'equals',
          right: '((guild.ownerId))',
        ),
      ],
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(
        message: _stringifyArgument(node, 0),
      ),
    );
  }

  Action? _transpileOnlyPerms(BdfdFunctionCallAst node, {required bool bot}) {
    final extracted = _extractPermissionGuardArgs(node);
    if (extracted.permissions.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one permission value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final source = bot ? '((bot.permissions))' : '((member.permissions))';
    final condition = _ParsedCondition.logical(
      group: 'and',
      conditions: extracted.permissions
          .map(
            (permission) => _ParsedCondition(
              left: source,
              operator: 'contains',
              right: permission,
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: extracted.message),
    );
  }

  Action? _transpileOnlyBotChannelPerms(BdfdFunctionCallAst node) {
    if (node.arguments.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one permission value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final firstArgumentRaw = _stringifyArgument(node, 0).trim();
    final firstArgumentPermission = _normalizePermissionToken(firstArgumentRaw);
    final firstLooksLikePermission = _looksLikePermissionToken(
      firstArgumentPermission,
    );

    String channelId;
    int permissionsStartAt;
    if (firstLooksLikePermission) {
      channelId = '((channel.id))';
      permissionsStartAt = 0;
    } else {
      final normalizedChannel = _normalizeDiscordIdToken(firstArgumentRaw);
      channelId =
          normalizedChannel.isEmpty ? '((channel.id))' : normalizedChannel;
      permissionsStartAt = 1;
    }

    final extracted = _extractPermissionGuardArgs(
      node,
      startAt: permissionsStartAt,
    );
    if (extracted.permissions.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one permission value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final conditions = <_ParsedCondition>[];
    if (channelId != '((channel.id))') {
      conditions.add(
        _ParsedCondition(
          left: '((channel.id))',
          operator: 'equals',
          right: channelId,
        ),
      );
    }
    conditions.addAll(
      extracted.permissions.map(
        (permission) => _ParsedCondition(
          left: '((bot.permissions))',
          operator: 'contains',
          right: permission,
        ),
      ),
    );

    final condition = _ParsedCondition.logical(
      group: 'and',
      conditions: conditions,
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: extracted.message),
    );
  }

  Action? _transpileCheckUserPerms(BdfdFunctionCallAst node) {
    final parsed = _buildCheckUserPermsCondition(node);
    if (parsed == null) {
      return null;
    }

    return _buildGuardIfAction(
      condition: parsed.condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: parsed.message),
    );
  }

  _CheckUserPermsParsed? _buildCheckUserPermsCondition(
    BdfdFunctionCallAst node,
  ) {
    final userId = _normalizeDiscordIdToken(_stringifyArgument(node, 0));
    if (userId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a user ID as first argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final extracted = _extractPermissionGuardArgs(node, startAt: 1);
    if (extracted.permissions.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one permission value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final selfMemberBranch = _ParsedCondition.logical(
      group: 'and',
      conditions: <_ParsedCondition>[
        _ParsedCondition(
          left: '((author.id))',
          operator: 'equals',
          right: userId,
        ),
        ...extracted.permissions.map(
          (permission) => _ParsedCondition(
            left: '((member.permissions))',
            operator: 'contains',
            right: permission,
          ),
        ),
      ],
    );

    final byIdBranch = _ParsedCondition.logical(
      group: 'and',
      conditions: extracted.permissions
          .map(
            (permission) => _ParsedCondition(
              left: 'permissions.byId.$userId',
              operator: 'contains',
              right: permission,
            ),
          )
          .toList(growable: false),
    );

    final ownerBranch = _ParsedCondition(
      left: userId,
      operator: 'equals',
      right: '((guild.ownerId))',
    );

    return _CheckUserPermsParsed(
      condition: _ParsedCondition.logical(
        group: 'or',
        conditions: <_ParsedCondition>[
          selfMemberBranch,
          byIdBranch,
          ownerBranch,
        ],
      ),
      message: extracted.message,
    );
  }

  Action? _transpileOnlyIfMessageContains(BdfdFunctionCallAst node) {
    final parsed = _extractMessageContainsArgs(node);
    if (parsed.words.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one word to match.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'and',
      conditions: parsed.words
          .map(
            (word) => _ParsedCondition(
              left: parsed.message,
              operator: 'matches',
              right: '(?i).*${RegExp.escape(word)}.*',
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: parsed.errorMessage),
    );
  }

  _MessageContainsArgs _extractMessageContainsArgs(BdfdFunctionCallAst node) {
    final defaultMessage = '((message.content))';
    if (node.arguments.isEmpty) {
      return const _MessageContainsArgs(
        message: '((message.content))',
        words: <String>[],
        errorMessage: '',
      );
    }

    final rawMessage = _stringifyArgument(node, 0).trim();
    final message = rawMessage.isEmpty ? defaultMessage : rawMessage;

    if (node.arguments.length == 1) {
      return _MessageContainsArgs(
        message: message,
        words: const <String>[],
        errorMessage: '',
      );
    }

    final words = <String>[];
    var errorMessage = '';
    final hasErrorMessage =
        node.arguments.length >= 3 &&
        _looksLikeLikelyErrorMessage(_stringifyNodes(node.arguments.last));
    final wordsEndExclusive =
        hasErrorMessage ? node.arguments.length - 1 : node.arguments.length;

    for (var index = 1; index < wordsEndExclusive; index++) {
      final word = _stringifyArgument(node, index).trim();
      if (word.isNotEmpty) {
        words.add(word);
      }
    }

    if (hasErrorMessage) {
      errorMessage = _stringifyNodes(node.arguments.last).trim();
    }

    return _MessageContainsArgs(
      message: message,
      words: words,
      errorMessage: errorMessage,
    );
  }

  Action _buildGuardIfAction({
    required _ParsedCondition condition,
    required List<Action> thenActions,
    required List<Action> elseActions,
  }) {
    return Action(
      type: BotCreatorActionType.ifBlock,
      payload: <String, dynamic>{
        ...condition.toPayload(prefix: 'condition.'),
        'thenActions': thenActions.map((action) => action.toJson()).toList(),
        'elseIfConditions': const <Map<String, dynamic>>[],
        'elseActions': elseActions.map((action) => action.toJson()).toList(),
      },
    );
  }

  Action _buildForcedStopAction() {
    return Action(
      type: BotCreatorActionType.stopUnless,
      payload: const <String, dynamic>{
        'condition.variable': '1',
        'condition.operator': 'equals',
        'condition.value': '0',
      },
    );
  }

  List<Action> _buildGuardFailureActions({required String message}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return <Action>[_buildForcedStopAction()];
    }
    return <Action>[
      _buildRespondWithMessageAction(content: trimmed),
      _buildForcedStopAction(),
    ];
  }

  _GuardIdsAndMessage _extractGuardIdsAndMessage(BdfdFunctionCallAst node) {
    if (node.arguments.isEmpty) {
      return const _GuardIdsAndMessage(ids: <String>[], message: '');
    }

    if (node.arguments.length == 1) {
      return _GuardIdsAndMessage(
        ids: _extractIdArguments(node.arguments),
        message: '',
      );
    }

    final idArguments = node.arguments.sublist(0, node.arguments.length - 1);
    return _GuardIdsAndMessage(
      ids: _extractIdArguments(idArguments),
      message: _stringifyNodes(node.arguments.last),
    );
  }

  _GuardValuesAndMessage _extractGuardValuesAndMessage(
    BdfdFunctionCallAst node,
  ) {
    if (node.arguments.isEmpty) {
      return const _GuardValuesAndMessage(values: <String>[], message: '');
    }

    if (node.arguments.length == 1) {
      return _GuardValuesAndMessage(
        values: _extractValueArguments(node.arguments),
        message: '',
      );
    }

    final lastArgument = _stringifyNodes(node.arguments.last);
    final hasMessage = _looksLikeLikelyErrorMessage(lastArgument);
    final valueArguments =
        hasMessage
            ? node.arguments.sublist(0, node.arguments.length - 1)
            : node.arguments;
    return _GuardValuesAndMessage(
      values: _extractValueArguments(valueArguments),
      message: hasMessage ? lastArgument : '',
    );
  }

  List<String> _extractValueArguments(List<List<BdfdAstNode>> arguments) {
    final values = <String>{};
    for (final argument in arguments) {
      final raw = _stringifyNodes(argument).trim();
      if (raw.isNotEmpty) {
        values.add(raw);
      }
    }
    return values.toList(growable: false);
  }

  bool _looksLikeLikelyErrorMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    if (trimmed.contains(RegExp(r'\s'))) {
      return true;
    }

    return trimmed.contains('!') ||
        trimmed.contains('?') ||
        trimmed.contains('`') ||
        trimmed.contains('❌') ||
        trimmed.contains('✅');
  }

  List<String> _extractIdArguments(List<List<BdfdAstNode>> arguments) {
    final ids = <String>{};
    for (final argument in arguments) {
      final raw = _stringifyNodes(argument);
      final parts = raw.split(RegExp(r'[\s,]+'));
      for (final part in parts) {
        final normalized = _normalizeDiscordIdToken(part);
        if (normalized.isNotEmpty) {
          ids.add(normalized);
        }
      }
    }
    return ids.toList(growable: false);
  }

  String _normalizeDiscordIdToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final digits =
        RegExp(r'\d+').allMatches(trimmed).map((m) => m.group(0)!).join();
    if (digits.isNotEmpty) {
      return digits;
    }
    return trimmed;
  }

  _PermissionGuardArgs _extractPermissionGuardArgs(
    BdfdFunctionCallAst node, {
    int startAt = 0,
  }) {
    final permissions = <String>[];
    var message = '';

    for (var index = startAt; index < node.arguments.length; index++) {
      final rawArgument = _stringifyNodes(node.arguments[index]).trim();
      if (rawArgument.isEmpty) {
        continue;
      }

      final parts = rawArgument
          .split(RegExp(r'[\s,]+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);

      final isLastArgument = index == node.arguments.length - 1;
      final normalizedParts = parts
          .map(_normalizePermissionToken)
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      final allPartsArePermissions =
          normalizedParts.isNotEmpty &&
          normalizedParts.every(_looksLikePermissionToken);

      if (isLastArgument && !allPartsArePermissions) {
        message = rawArgument;
        break;
      }

      permissions.addAll(normalizedParts);
    }

    return _PermissionGuardArgs(
      permissions: permissions.toSet().toList(growable: false),
      message: message,
    );
  }

  bool _looksLikePermissionToken(String normalized) {
    if (normalized.isEmpty) {
      return false;
    }
    if (RegExp(r'^\d+$').hasMatch(normalized)) {
      return true;
    }
    return _knownBdfdPermissionTokens.contains(normalized);
  }

  String _normalizePermissionToken(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (normalized.isEmpty) {
      return '';
    }
    return _permissionTokenAliases[normalized] ?? normalized;
  }

  List<Action> _transpileBranchArgument(BdfdFunctionCallAst node, int index) {
    if (index >= node.arguments.length) {
      return const <Action>[];
    }

    return transpileScript(BdfdScriptAst(nodes: node.arguments[index]));
  }

  _ParsedCondition _parseCondition(
    String expression,
    BdfdFunctionCallAst node,
  ) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'IF condition cannot be empty.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return const _ParsedCondition(
        left: '',
        operator: 'isNotEmpty',
        right: '',
      );
    }

    final logical = _parseLogicalCondition(trimmed, node);
    if (logical != null) {
      return logical;
    }

    return _parseSimpleCondition(trimmed);
  }

  _ParsedCondition _parseSimpleCondition(String trimmed) {
    const symbolOperators = <String, String>{
      '>=': 'greaterOrEqual',
      '<=': 'lessOrEqual',
      '==': 'equals',
      '!=': 'notEquals',
      '>': 'greaterThan',
      '<': 'lessThan',
    };

    for (final entry in symbolOperators.entries) {
      final splitIndex = trimmed.indexOf(entry.key);
      if (splitIndex <= 0) {
        continue;
      }
      final left = trimmed.substring(0, splitIndex).trim();
      final right = trimmed.substring(splitIndex + entry.key.length).trim();
      return _ParsedCondition(left: left, operator: entry.value, right: right);
    }

    const wordOperators = <String, String>{
      ' notcontains ': 'notContains',
      ' contains ': 'contains',
      ' startswith ': 'startsWith',
      ' endswith ': 'endsWith',
    };

    final lowered = ' ${trimmed.toLowerCase()} ';
    for (final entry in wordOperators.entries) {
      final index = lowered.indexOf(entry.key);
      if (index < 0) {
        continue;
      }
      final left = trimmed.substring(0, index).trim();
      final right = trimmed.substring(index + entry.key.trim().length).trim();
      return _ParsedCondition(left: left, operator: entry.value, right: right);
    }

    return _ParsedCondition(left: trimmed, operator: 'isNotEmpty', right: '');
  }

  _ParsedCondition? _parseLogicalCondition(
    String expression,
    BdfdFunctionCallAst node,
  ) {
    final lowered = expression.toLowerCase();
    String? group;
    if (lowered.startsWith(r'$and[')) {
      group = 'and';
    } else if (lowered.startsWith(r'$or[')) {
      group = 'or';
    }

    if (group == null) {
      return null;
    }

    final bracketStart = expression.indexOf('[');
    if (bracketStart < 0) {
      return null;
    }

    final bracketEnd = _findMatchingBracketIndex(expression, bracketStart);
    if (bracketEnd < 0) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} has an invalid logical condition syntax.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final body = expression.substring(bracketStart + 1, bracketEnd);
    final trailing = expression.substring(bracketEnd + 1).trim();
    final conditionStrings = _splitTopLevel(body, ';')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);

    if (conditionStrings.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one condition.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    var negate = false;
    if (trailing.isNotEmpty) {
      final comparison = _parseBooleanComparison(trailing);
      if (comparison == null) {
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Unable to parse logical condition trailing comparator "$trailing"; assuming true.',
            severity: BdfdTranspileDiagnosticSeverity.warning,
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
      } else {
        negate = !comparison;
      }
    }

    final parsedConditions = conditionStrings
        .map(_parseSimpleCondition)
        .toList(growable: false);

    return _ParsedCondition.logical(
      group: group,
      conditions: parsedConditions,
      negate: negate,
    );
  }

  int _findMatchingBracketIndex(String value, int openIndex) {
    var depth = 0;
    for (var index = openIndex; index < value.length; index++) {
      final char = value[index];
      if (char == '[') {
        depth += 1;
      } else if (char == ']') {
        depth -= 1;
        if (depth == 0) {
          return index;
        }
      }
    }
    return -1;
  }

  List<String> _splitTopLevel(String value, String separator) {
    final items = <String>[];
    var bracketDepth = 0;
    var lastStart = 0;

    for (var index = 0; index < value.length; index++) {
      final char = value[index];
      if (char == '[') {
        bracketDepth += 1;
        continue;
      }
      if (char == ']') {
        if (bracketDepth > 0) {
          bracketDepth -= 1;
        }
        continue;
      }
      if (char == separator && bracketDepth == 0) {
        items.add(value.substring(lastStart, index));
        lastStart = index + 1;
      }
    }

    items.add(value.substring(lastStart));
    return items;
  }

  bool? _parseBooleanComparison(String trailing) {
    final normalized = trailing.replaceAll(' ', '').toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    if (normalized.startsWith('==')) {
      return _parseBooleanToken(normalized.substring(2));
    }
    if (normalized.startsWith('!=')) {
      final compared = _parseBooleanToken(normalized.substring(2));
      if (compared == null) {
        return null;
      }
      return !compared;
    }

    return null;
  }

  bool? _parseBooleanToken(String value) {
    switch (value) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
      default:
        return null;
    }
  }

  String _stringifyArgument(BdfdFunctionCallAst node, int index) {
    if (index >= node.arguments.length) {
      return '';
    }
    return _stringifyNodes(node.arguments[index]);
  }

  String _stringifyNodes(List<BdfdAstNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      if (node is BdfdTextAst) {
        buffer.write(node.value);
        continue;
      }

      if (node is BdfdFunctionCallAst) {
        final inlineReplacement = _stringifyInlineFunction(node);
        if (inlineReplacement != null) {
          buffer.write(inlineReplacement);
          continue;
        }

        if (_isInlineOnlyFunction(node.normalizedName)) {
          continue;
        }

        final rebuilt = _rebuildFunctionSource(node);
        buffer.write(rebuilt);
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Nested BDFD function ${node.name} was preserved as raw text in this transpilation pass.',
            severity: BdfdTranspileDiagnosticSeverity.warning,
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
      }
    }
    return buffer.toString();
  }

  String? _stringifyInlineFunction(BdfdFunctionCallAst node) {
    // C-style loop variables take precedence (e.g. $i, $j in a for loop).
    if (_loopDepth > 0 && node.arguments.isEmpty) {
      final loopVar = _loopVariables[node.normalizedName];
      if (loopVar != null) return loopVar.toString();
    }
    switch (node.normalizedName) {
      case 'startthread':
        final action = _buildStartThreadAction(node);
        if (action != null) {
          _deferredInlineActions.add(action);
        }
        return _shouldReturnStartThreadId(node) ? '((thread.lastId))' : '';
      case 'editthread':
        final action = _buildEditThreadAction(node);
        if (action != null) {
          _deferredInlineActions.add(action);
        }
        return '';
      case 'threadaddmember':
        final action = _buildThreadMemberAction(node, add: true);
        if (action != null) {
          _deferredInlineActions.add(action);
        }
        return '';
      case 'threadremovemember':
        final action = _buildThreadMemberAction(node, add: false);
        if (action != null) {
          _deferredInlineActions.add(action);
        }
        return '';
      case 'checkuserperms':
      case 'checkusersperms':
        return _inlineCheckUserPerms(node);
      case 'message':
      case 'args':
        return _inlineMessageArgument(node);
      case 'i':
      case 'loopindex':
      case 'loopiteration':
        return _loopDepth > 0 ? _loopIterationIndex.toString() : '0';
      case 'loopcount':
        return _loopDepth > 0 ? (_loopIterationIndex + 1).toString() : '0';
      case 'mentionedchannels':
        return _inlineMentionedChannels(node);
      case 'username':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((user[$userId].username))';
          }
        }
        return _inlineRuntimeVariables['username'];
      case 'nickname':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((member[$userId].nick))';
          }
        }
        return _inlineRuntimeVariables['nickname'];
      case 'displayname':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((member[$userId].nick|user[$userId].username))';
          }
        }
        return _inlineRuntimeVariables['displayname'];
      // Parametric channel/guild lookups
      case 'channelid':
        if (node.arguments.isNotEmpty) {
          final channelName = _stringifyArgument(node, 0).trim();
          if (channelName.isNotEmpty) {
            return '((channel[$channelName].id))';
          }
        }
        return _inlineRuntimeVariables['channelid'];
      case 'guildid':
        if (node.arguments.isNotEmpty) {
          final guildName = _stringifyArgument(node, 0).trim();
          if (guildName.isNotEmpty) {
            return '((guild[$guildName].id))';
          }
        }
        return _inlineRuntimeVariables['guildid'];
      case 'roleid':
        final roleName = _stringifyArgument(node, 0).trim();
        if (roleName.isNotEmpty) {
          return '((role[$roleName].id))';
        }
        return '';
      case 'rolename':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].name))';
        }
        return '';
      case 'roleinfo':
        final roleId = _stringifyArgument(node, 0).trim();
        final property = _stringifyArgument(node, 1).trim();
        if (roleId.isNotEmpty) {
          if (property.isNotEmpty) {
            return '((role[$roleId].$property))';
          }
          return '((role[$roleId].info))';
        }
        return '';
      case 'roleexists':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].exists))';
        }
        return 'false';
      case 'roleperms':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].permissions))';
        }
        return '';
      case 'roleposition':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].position))';
        }
        return '';
      case 'getrolecolor':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].color))';
        }
        return '';
      case 'ishoisted':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].hoist))';
        }
        return 'false';
      case 'ismentionable':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].mentionable))';
        }
        return 'false';
      case 'findrole':
        final roleName = _stringifyArgument(node, 0).trim();
        if (roleName.isNotEmpty) {
          return '((role[$roleName].id))';
        }
        return '';
      case 'hasrole':
        final userId = _stringifyArgument(node, 0).trim();
        final roleId = _stringifyArgument(node, 1).trim();
        if (roleId.isNotEmpty) {
          return '((member[$userId].hasRole[$roleId]))';
        }
        if (userId.isNotEmpty) {
          return '((member.hasRole[$userId]))';
        }
        return 'false';
      case 'userswithrole':
        final uwrRoleId = _stringifyArgument(node, 0).trim();
        if (uwrRoleId.isNotEmpty) {
          return '((role[$uwrRoleId].memberCount))';
        }
        return '0';
      // Parametric user info lookups
      case 'useravatar':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((user[$userId].avatar))';
          }
        }
        return _inlineRuntimeVariables['useravatar'];
      case 'userbanner':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((user[$userId].banner))';
          }
        }
        return _inlineRuntimeVariables['userbanner'];
      // Mentioned helper with index
      case 'mentioned':
        if (node.arguments.isNotEmpty) {
          final indexRaw = _stringifyArgument(node, 0).trim();
          final index = int.tryParse(indexRaw);
          if (index != null && index >= 1) {
            return '((message.mentions[${index - 1}]))';
          }
        }
        return '((message.mentions[0]))';
      // Reactions
      case 'getreactions':
        final emoji = _stringifyArgument(node, 0).trim();
        if (emoji.isNotEmpty) {
          return '((message.reactions[$emoji]))';
        }
        return '((message.reactions))';
      case 'userreacted':
        final userId = _stringifyArgument(node, 0).trim();
        final emoji = _stringifyArgument(node, 1).trim();
        return '((message.reactions[$emoji].includes[$userId]))';
      // Emoji info
      case 'customemoji':
        final emojiName = _stringifyArgument(node, 0).trim();
        if (emojiName.isNotEmpty) {
          return '((emoji[$emojiName]))';
        }
        return '';
      case 'emotecount':
      case 'emojicount':
        return '((guild.emojiCount))';
      case 'emojiexists':
        final emojiName = _stringifyArgument(node, 0).trim();
        if (emojiName.isNotEmpty) {
          return '((emoji[$emojiName].exists))';
        }
        return 'false';
      case 'emojiname':
        final emojiId = _stringifyArgument(node, 0).trim();
        if (emojiId.isNotEmpty) {
          return '((emoji[$emojiId].name))';
        }
        return '';
      case 'isemojianimated':
        final emojiId = _stringifyArgument(node, 0).trim();
        if (emojiId.isNotEmpty) {
          return '((emoji[$emojiId].animated))';
        }
        return 'false';
      // Webhook info
      case 'webhookavatarurl':
        return '((webhook.avatarURL))';
      case 'webhookcolor':
        return '((webhook.color))';
      case 'webhookdescription':
        return '((webhook.description))';
      case 'webhookfooter':
        return '((webhook.footer))';
      case 'webhooktitle':
        return '((webhook.title))';
      case 'webhookusername':
        return '((webhook.username))';
      case 'webhookcontent':
        return '((webhook.content))';
      // Ticket
      case 'isticket':
        return '((channel.isTicket))';
      // getMessage
      case 'getmessage':
        return _inlineGetMessage(node);
      // $c - comment function, returns empty
      case 'c':
        return '';
      default:
        break;
    }

    final placeholder = _inlineRuntimePlaceholder(node);
    if (placeholder != null) {
      return placeholder;
    }

    switch (node.normalizedName) {
      // JSON functions
      case 'json':
        return _jsonGet(node);
      case 'jsonexists':
        return _jsonExists(node);
      case 'jsonstringify':
        return _jsonStringify();
      case 'jsonpretty':
        return _jsonPretty(node);
      case 'jsonarraycount':
        return _jsonArrayCount(node);
      case 'jsonarrayindex':
        return _jsonArrayIndex(node);
      case 'jsonjoinarray':
        return _jsonJoinArray(node);
      case 'jsonarraypop':
        return _jsonArrayPop(node);
      case 'jsonarrayshift':
        return _jsonArrayShift(node);
      // HTTP results
      case 'httpstatus':
        return _latestHttpStatusPlaceholder(node);
      case 'httpresult':
        return _latestHttpResultPlaceholder(node);
      // Variable getters
      case 'getuservar':
        return _scopedVariablePlaceholder('user', _stringifyArgument(node, 0));
      case 'getservervar':
      case 'getguildvar':
        return _scopedVariablePlaceholder('guild', _stringifyArgument(node, 0));
      case 'getchannelvar':
        return _scopedVariablePlaceholder(
          'channel',
          _stringifyArgument(node, 0),
        );
      case 'getmembervar':
      case 'getguildmembervar':
        return _scopedVariablePlaceholder(
          'guildMember',
          _stringifyArgument(node, 0),
        );
      case 'getmessagevar':
        return _scopedVariablePlaceholder(
          'message',
          _stringifyArgument(node, 0),
        );
      case 'getvar':
        // BDFD wiki: $getVar[Variable name;(User ID)]
        final gvUserId =
            node.arguments.length > 1 ? _stringifyArgument(node, 1).trim() : '';
        if (gvUserId.isNotEmpty) {
          return _scopedVariablePlaceholder(
            'user',
            _stringifyArgument(node, 0),
          );
        }
        return _scopedVariablePlaceholder(
          'global',
          _stringifyArgument(node, 0),
        );
      case 'var':
        if (node.arguments.length >= 2) {
          final key = _stringifyArgument(node, 0).trim();
          final value = _stringifyArgument(node, 1);
          if (key.isNotEmpty) {
            _tempVariables[key] = value;
          }
          return '';
        }
        final tvKey = _stringifyArgument(node, 0).trim();
        if (tvKey.isNotEmpty && _tempVariables.containsKey(tvKey)) {
          return _tempVariables[tvKey]!;
        }
        return _scopedVariablePlaceholder(
          'global',
          _stringifyArgument(node, 0),
        );
      case 'varexists':
        final key = _stringifyArgument(node, 0).trim();
        if (key.isNotEmpty) {
          return '((variables.exists[$key]))';
        }
        return 'false';
      case 'varexisterror':
        return '';
      case 'getleaderboardposition':
        return '((leaderboard.position))';
      case 'getleaderboardvalue':
        return '((leaderboard.value))';
      case 'globaluserleaderboard':
        final guVarName = _stringifyArgument(node, 0).trim();
        final guSort = _stringifyArgument(node, 1).trim();
        return '((globalUserLeaderboard[$guVarName${guSort.isNotEmpty ? ';$guSort' : ''}]))';
      case 'serverleaderboard':
        final slVarName = _stringifyArgument(node, 0).trim();
        final slSort = _stringifyArgument(node, 1).trim();
        return '((serverLeaderboard[$slVarName${slSort.isNotEmpty ? ';$slSort' : ''}]))';
      case 'userleaderboard':
        final ulVarName = _stringifyArgument(node, 0).trim();
        final ulSort = _stringifyArgument(node, 1).trim();
        return '((userLeaderboard[$ulVarName${ulSort.isNotEmpty ? ';$ulSort' : ''}]))';
      case 'getcooldown':
        final cooldownType = _stringifyArgument(node, 0).trim();
        if (cooldownType.isNotEmpty) {
          return '((cooldown[$cooldownType].remaining))';
        }
        return '((cooldown.remaining))';
      // Workflow response
      case 'workflowresponse':
        return _latestWorkflowResponsePlaceholder(node);
      // Text manipulation (compile-time)
      case 'replacetext':
        return _inlineReplaceText(node);
      case 'tolowercase':
        return _stringifyArgument(node, 0).toLowerCase();
      case 'touppercase':
        return _stringifyArgument(node, 0).toUpperCase();
      case 'totitlecase':
        return _inlineTitleCase(_stringifyArgument(node, 0));
      case 'charcount':
        return _stringifyArgument(node, 0).length.toString();
      case 'bytecount':
        return utf8.encode(_stringifyArgument(node, 0)).length.toString();
      case 'linescount':
        final text = _stringifyArgument(node, 0);
        return text.isEmpty ? '0' : text.split('\n').length.toString();
      case 'croptext':
        return _inlineCropText(node);
      case 'trimcontent':
        return _stringifyArgument(node, 0).trim();
      case 'trimspace':
        return _stringifyArgument(node, 0).trim();
      case 'unescape':
        return _stringifyArgument(node, 0);
      case 'repeatmessage':
        return _inlineRepeatMessage(node);
      case 'removecontains':
        return _inlineRemoveContains(node);
      case 'numberseparator':
        return _inlineNumberSeparator(node);
      case 'splittext':
        return _inlineSplitText(node);
      case 'editsplittext':
        return _inlineEditSplitText(node);
      case 'gettextsplitindex':
        return _inlineGetTextSplitIndex(node);
      case 'gettextsplitlength':
        return _textSplitParts.length.toString();
      case 'joinsplittext':
        return _inlineJoinSplitText(node);
      case 'removesplittextelement':
        return _inlineRemoveSplitTextElement(node);
      // Math functions (compile-time)
      case 'calculate':
        return _inlineCalculate(node);
      case 'ceil':
        return _inlineMathUnary(node, (v) => v.ceil());
      case 'floor':
        return _inlineMathUnary(node, (v) => v.floor());
      case 'round':
        return _inlineMathUnary(node, (v) => v.round());
      case 'sqrt':
        return _inlineMathUnaryDouble(node, math.sqrt);
      case 'max':
        return _inlineMathBinary(node, math.max);
      case 'min':
        return _inlineMathBinary(node, math.min);
      case 'modulo':
        return _inlineMathBinaryOp(node, (a, b) => b != 0 ? a % b : 0);
      case 'multi':
        return _inlineMathBinaryOp(node, (a, b) => a * b);
      case 'divide':
        return _inlineMathBinaryOp(node, (a, b) => b != 0 ? a / b : 0);
      case 'sub':
        return _inlineMathBinaryOp(node, (a, b) => a - b);
      case 'sum':
        return _inlineSum(node);
      case 'sort':
        return _inlineSort(node);
      // Boolean check functions (compile-time)
      case 'isboolean':
        return _inlineIsBoolean(node);
      case 'isinteger':
        return _inlineIsInteger(node);
      case 'isnumber':
        return _inlineIsNumber(node);
      case 'isvalidhex':
        return _inlineIsValidHex(node);
      case 'checkcondition':
        return _inlineCheckCondition(node);
      case 'checkcontains':
        return _inlineCheckContains(node);
      // Random functions (compile-time)
      case 'random':
        return _inlineRandom(node);
      case 'randomstring':
        return _inlineRandomString(node);
      case 'randomtext':
        return _inlineRandomText(node);
      // Date/Time functions (compile-time current time)
      case 'date':
        return _inlineDate();
      case 'day':
        return DateTime.now().toUtc().day.toString();
      case 'hour':
        return DateTime.now().toUtc().hour.toString();
      case 'minute':
        return DateTime.now().toUtc().minute.toString();
      case 'month':
        return DateTime.now().toUtc().month.toString();
      case 'second':
        return DateTime.now().toUtc().second.toString();
      case 'year':
        return DateTime.now().toUtc().year.toString();
      case 'time':
        final now = DateTime.now().toUtc();
        return '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}:'
            '${now.second.toString().padLeft(2, '0')}';
      case 'gettimestamp':
        return (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000)
            .toString();
      // Misc inline
      case 'getserverinvite':
        return '((guild.invite))';
      case 'getinviteinfo':
        return '((invite.info))';
      case 'hostingexpiretime':
        return '((hosting.expireTime))';
      case 'premiumexpiretime':
        return '((premium.expireTime))';
      case 'randomcategoryid':
        return '((random.categoryId))';
      case 'randomchannelid':
        return '((random.channelId))';
      case 'randomguildid':
        return '((random.guildId))';
      case 'randommention':
        return '((random.mention))';
      case 'randomroleid':
        return '((random.roleId))';
      case 'randomuser':
        return '((random.user))';
      case 'randomuserid':
        return '((random.userId))';
      // Parameterized inline functions (wiki requires arguments)
      case 'getbanreason':
        // BDFD wiki: $getBanReason[User ID;(Guild ID)]
        final brUserId = _stringifyArgument(node, 0).trim();
        if (brUserId.isNotEmpty) {
          final brGuildId = _stringifyArgument(node, 1).trim();
          if (brGuildId.isNotEmpty) {
            return '((ban.reason[$brUserId;$brGuildId]))';
          }
          return '((ban.reason[$brUserId]))';
        }
        return _inlineRuntimeVariables['getbanreason'];
      case 'isbanned':
        // BDFD wiki: $isBanned[User ID]
        final ibUserId = _stringifyArgument(node, 0).trim();
        if (ibUserId.isNotEmpty) {
          return '((member[$ibUserId].isBanned))';
        }
        return _inlineRuntimeVariables['isbanned'];
      case 'istimedout':
        // BDFD wiki: $isTimedOut[User ID]
        final itUserId = _stringifyArgument(node, 0).trim();
        if (itUserId.isNotEmpty) {
          return '((member[$itUserId].isTimedOut))';
        }
        return _inlineRuntimeVariables['istimedout'];
      case 'getslowmode':
        // BDFD wiki: $getSlowmode[(Channel ID)]
        if (node.arguments.isNotEmpty) {
          final smChannelId = _stringifyArgument(node, 0).trim();
          if (smChannelId.isNotEmpty) {
            return '((channel[$smChannelId].rateLimitPerUser))';
          }
        }
        return _inlineRuntimeVariables['getslowmode'];
      case 'isnsfw':
        // BDFD wiki: $isNSFW[Channel ID]
        final nsfwChannelId = _stringifyArgument(node, 0).trim();
        if (nsfwChannelId.isNotEmpty) {
          return '((channel[$nsfwChannelId].nsfw))';
        }
        return _inlineRuntimeVariables['isnsfw'];
      case 'ismentioned':
        // BDFD wiki: $isMentioned[User ID]
        final imUserId = _stringifyArgument(node, 0).trim();
        if (imUserId.isNotEmpty) {
          return '((message.isMentioned[$imUserId]))';
        }
        return _inlineRuntimeVariables['ismentioned'];
      case 'ismessageedited':
        // BDFD wiki: $isMessageEdited[Channel ID;Message ID]
        final meChannelId = _stringifyArgument(node, 0).trim();
        final meMessageId = _stringifyArgument(node, 1).trim();
        if (meChannelId.isNotEmpty && meMessageId.isNotEmpty) {
          return '((message[$meChannelId;$meMessageId].isEdited))';
        }
        return _inlineRuntimeVariables['ismessageedited'];
      case 'getattachments':
        // BDFD wiki: $getAttachments[Index]
        final attIndex = _stringifyArgument(node, 0).trim();
        if (attIndex.isNotEmpty) {
          return '((message.attachments[$attIndex]))';
        }
        return _inlineRuntimeVariables['getattachments'];
      case 'getembeddata':
        // BDFD wiki: $getEmbedData[Channel ID;Message ID;Embed index;Embed property]
        final edChannelId = _stringifyArgument(node, 0).trim();
        final edMessageId = _stringifyArgument(node, 1).trim();
        final edIndex = _stringifyArgument(node, 2).trim();
        final edProperty = _stringifyArgument(node, 3).trim();
        if (edChannelId.isNotEmpty && edMessageId.isNotEmpty) {
          return '((message[$edChannelId;$edMessageId].embeds[${edIndex.isEmpty ? '0' : edIndex}]${edProperty.isNotEmpty ? '.$edProperty' : ''}))';
        }
        return _inlineRuntimeVariables['getembeddata'];
      // eval - return the argument as-is (limited compile-time support)
      case 'eval':
        return _stringifyArgument(node, 0);
      default:
        return null;
    }
  }

  String? _inlineRuntimePlaceholder(BdfdFunctionCallAst node) {
    return _inlineRuntimeVariables[node.normalizedName];
  }

  bool _isInlineOnlyFunction(String normalizedName) {
    if (_loopDepth > 0 && _loopVariables.containsKey(normalizedName)) {
      return true;
    }
    switch (normalizedName) {
      case 'json':
      case 'jsonexists':
      case 'jsonstringify':
      case 'jsonpretty':
      case 'jsonarraycount':
      case 'jsonarrayindex':
      case 'jsonjoinarray':
      case 'jsonarraypop':
      case 'jsonarrayshift':
      case 'startthread':
      case 'editthread':
      case 'threadaddmember':
      case 'threadremovemember':
      case 'checkuserperms':
      case 'checkusersperms':
      case 'message':
      case 'args':
      case 'i':
      case 'loopindex':
      case 'loopiteration':
      case 'loopcount':
      case 'mentionedchannels':
      case 'httpstatus':
      case 'httpresult':
      case 'getuservar':
      case 'getservervar':
      case 'getguildvar':
      case 'getchannelvar':
      case 'getmembervar':
      case 'getguildmembervar':
      case 'getmessagevar':
      case 'getvar':
      case 'var':
      case 'varexists':
      case 'varexisterror':
      case 'workflowresponse':
      case 'getleaderboardposition':
      case 'getleaderboardvalue':
      case 'getcooldown':
      // Text manipulation
      case 'replacetext':
      case 'tolowercase':
      case 'touppercase':
      case 'totitlecase':
      case 'charcount':
      case 'bytecount':
      case 'linescount':
      case 'croptext':
      case 'trimcontent':
      case 'trimspace':
      case 'unescape':
      case 'repeatmessage':
      case 'removecontains':
      case 'numberseparator':
      case 'splittext':
      case 'editsplittext':
      case 'gettextsplitindex':
      case 'gettextsplitlength':
      case 'joinsplittext':
      case 'removesplittextelement':
      // Math
      case 'calculate':
      case 'ceil':
      case 'floor':
      case 'round':
      case 'sqrt':
      case 'max':
      case 'min':
      case 'modulo':
      case 'multi':
      case 'divide':
      case 'sub':
      case 'sum':
      case 'sort':
      // Boolean checks
      case 'isboolean':
      case 'isinteger':
      case 'isnumber':
      case 'isvalidhex':
      case 'checkcondition':
      case 'checkcontains':
      // Random
      case 'random':
      case 'randomstring':
      case 'randomtext':
      // Date/Time
      case 'date':
      case 'day':
      case 'hour':
      case 'minute':
      case 'month':
      case 'second':
      case 'year':
      case 'time':
      case 'gettimestamp':
      // Parametric lookups
      case 'channelid':
      case 'guildid':
      case 'roleid':
      case 'rolename':
      case 'roleinfo':
      case 'roleexists':
      case 'roleperms':
      case 'roleposition':
      case 'getrolecolor':
      case 'ishoisted':
      case 'ismentionable':
      case 'findrole':
      case 'hasrole':
      case 'userswithrole':
      case 'useravatar':
      case 'userbanner':
      case 'mentioned':
      case 'getreactions':
      case 'userreacted':
      case 'customemoji':
      case 'emotecount':
      case 'emojicount':
      case 'emojiexists':
      case 'emojiname':
      case 'isemojianimated':
      case 'webhookavatarurl':
      case 'webhookcolor':
      case 'webhookdescription':
      case 'webhookfooter':
      case 'webhooktitle':
      case 'webhookusername':
      case 'webhookcontent':
      case 'isticket':
      case 'getmessage':
      case 'c':
      case 'eval':
      case 'globaluserleaderboard':
      case 'serverleaderboard':
      case 'userleaderboard':
      case 'getserverinvite':
      case 'getinviteinfo':
      case 'hostingexpiretime':
      case 'premiumexpiretime':
      case 'randomcategoryid':
      case 'randomchannelid':
      case 'randomguildid':
      case 'randommention':
      case 'randomroleid':
      case 'randomuser':
      case 'randomuserid':
        return true;
      default:
        return _inlineRuntimeVariables.containsKey(normalizedName);
    }
  }

  bool _requiresPendingResponseFlush(String normalizedName) {
    switch (normalizedName) {
      case 'sendmessage':
      case 'reply':
      case 'channelsendmessage':
      case 'onlyif':
      case 'onlyforusers':
      case 'onlyforchannels':
      case 'onlyforroles':
      case 'onlyforids':
      case 'onlyforroleids':
      case 'onlyforservers':
      case 'onlyforcategories':
      case 'ignorechannels':
      case 'onlynsfw':
      case 'onlyadmin':
      case 'onlyperms':
      case 'onlybotperms':
      case 'onlybotchannelperms':
      case 'checkuserperms':
      case 'checkusersperms':
      case 'onlyifmessagecontains':
      case 'startthread':
      case 'editthread':
      case 'threadaddmember':
      case 'threadremovemember':
      case 'if':
      case 'stop':
      case 'httpget':
      case 'httppost':
      case 'httpput':
      case 'httpdelete':
      case 'httppatch':
      case 'setuservar':
      case 'setservervar':
      case 'setguildvar':
      case 'setchannelvar':
      case 'setmembervar':
      case 'setguildmembervar':
      case 'setmessagevar':
      case 'setvar':
      case 'awaitfunc':
      case 'changeusername':
      case 'changeusernamewithid':
      // Moderation
      case 'ban':
      case 'banid':
      case 'unban':
      case 'unbanid':
      case 'kick':
      case 'kickmention':
      case 'timeout':
      case 'mute':
      case 'untimeout':
      case 'unmute':
      case 'clear':
      // Roles
      case 'giverole':
      case 'giveroles':
      case 'rolegrant':
      case 'takerole':
      case 'takeroles':
      case 'createrole':
      case 'deleterole':
      case 'colorrole':
      case 'modifyrole':
      case 'modifyroleperms':
      case 'setuserroles':
      // Messages
      case 'deletemessage':
      case 'deletein':
      case 'dm':
      case 'editmessage':
      case 'editin':
      case 'editembedin':
      case 'pinmessage':
      case 'unpinmessage':
      case 'publishmessage':
      case 'replyin':
      case 'sendembedmessage':
      case 'usechannel':
      // Channels
      case 'createchannel':
      case 'deletechannels':
      case 'deletechannelsbyname':
      case 'modifychannel':
      case 'editchannelperms':
      case 'modifychannelperms':
      case 'slowmode':
      // Reactions
      case 'addreactions':
      case 'addcmdreactions':
      case 'addmessagereactions':
      case 'clearreactions':
      // Emoji
      case 'addemoji':
      case 'removeemoji':
      // Webhooks
      case 'webhooksend':
      case 'webhookcreate':
      case 'webhookdelete':
      // Modal
      case 'newmodal':
      case 'defer':
      // Cooldown
      case 'cooldown':
      case 'globalcooldown':
      case 'servercooldown':
      case 'changecooldowntime':
      // Variable reset
      case 'resetuservar':
      case 'resetservervar':
      case 'resetguildvar':
      case 'resetchannelvar':
      case 'resetmembervar':
      case 'resetguildmembervar':
      // Blacklist
      case 'blacklistids':
      case 'blacklistroles':
      case 'blacklistrolesids':
      case 'blacklistroleids':
      case 'blacklistservers':
      case 'blacklistusers':
      // Bot actions
      case 'botleave':
      case 'bottyping':
      // Ticket
      case 'closeticket':
      case 'newticket':
      // Args check
      case 'argscheck':
      // Workflow call
      case 'callworkflow':
        return true;
      default:
        return false;
    }
  }

  List<Action> _drainDeferredInlineActions() {
    if (_deferredInlineActions.isEmpty) {
      return const <Action>[];
    }
    final drained = List<Action>.from(_deferredInlineActions);
    _deferredInlineActions.clear();
    return drained;
  }

  Action? _buildStartThreadAction(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();
    final channelId = _stringifyArgument(node, 1).trim();
    final messageId = _stringifyArgument(node, 2).trim();
    final archiveDurationRaw = _stringifyArgument(node, 3).trim();
    final archiveDuration = _normalizeThreadArchiveDuration(archiveDurationRaw);

    if (name.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a thread name.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    return Action(
      type: BotCreatorActionType.createThread,
      key: '_bdfd_thread_${_threadActionCounter++}',
      payload: <String, dynamic>{
        'name': name,
        'channelId': channelId,
        'messageId': messageId,
        'autoArchiveDuration': archiveDuration.toString(),
        'type': 'public',
      },
    );
  }

  Action? _buildEditThreadAction(BdfdFunctionCallAst node) {
    final threadId = _stringifyArgument(node, 0).trim();
    if (threadId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a thread ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final name = _normalizeThreadOptional(_stringifyArgument(node, 1));
    final archived = _normalizeThreadOptionalBool(_stringifyArgument(node, 2));
    final archiveDurationRaw = _normalizeThreadOptional(
      _stringifyArgument(node, 3),
    );
    final locked = _normalizeThreadOptionalBool(_stringifyArgument(node, 4));
    final slowmode = _normalizeThreadOptional(_stringifyArgument(node, 5));

    return Action(
      type: BotCreatorActionType.updateChannel,
      payload: <String, dynamic>{
        'channelId': threadId,
        if (name != null) 'name': name,
        if (archived != null) 'archived': archived,
        if (archiveDurationRaw != null)
          'autoArchiveDuration':
              _normalizeThreadArchiveDuration(archiveDurationRaw).toString(),
        if (locked != null) 'locked': locked,
        if (slowmode != null) 'slowmode': slowmode,
      },
    );
  }

  Action? _buildThreadMemberAction(
    BdfdFunctionCallAst node, {
    required bool add,
  }) {
    final threadId = _stringifyArgument(node, 0).trim();
    final userId = _stringifyArgument(node, 1).trim();
    if (threadId.isEmpty || userId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires both thread ID and user ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    return Action(
      type:
          add
              ? BotCreatorActionType.addThreadMember
              : BotCreatorActionType.removeThreadMember,
      payload: <String, dynamic>{'threadId': threadId, 'userId': userId},
    );
  }

  int _normalizeThreadArchiveDuration(String raw) {
    const allowed = <int>[60, 1440, 4320, 10080];
    final parsed = int.tryParse(raw.trim()) ?? 60;
    return allowed.reduce(
      (prev, curr) =>
          (curr - parsed).abs() < (prev - parsed).abs() ? curr : prev,
    );
  }

  bool _shouldReturnStartThreadId(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 4).trim().toLowerCase();
    return raw == 'true' || raw == 'yes' || raw == '1' || raw == 'on';
  }

  String? _normalizeThreadOptional(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == '!unchanged') {
      return null;
    }
    return trimmed;
  }

  bool? _normalizeThreadOptionalBool(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty || normalized == '!unchanged') {
      return null;
    }
    if (normalized == 'true' ||
        normalized == 'yes' ||
        normalized == '1' ||
        normalized == 'on') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == 'no' ||
        normalized == '0' ||
        normalized == 'off') {
      return false;
    }
    return null;
  }

  void _jsonParse(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 0).trim();
    if (raw.isEmpty) {
      _hasJsonContext = false;
      _jsonContext = null;
      return;
    }

    try {
      _jsonContext = jsonDecode(raw);
      _hasJsonContext = true;
    } catch (_) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} received invalid JSON input.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
    }
  }

  String _jsonGet(BdfdFunctionCallAst node) {
    if (!_hasJsonContext) {
      return '';
    }
    final segments = _jsonPathSegments(node);
    final value = _jsonGetPathValue(segments);
    return _jsonStringifyValue(value);
  }

  void _jsonSet(BdfdFunctionCallAst node, {required bool forceString}) {
    final pathLength = node.arguments.length - 1;
    if (pathLength < 1) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one key and one value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return;
    }

    final pathSegments = _jsonPathSegments(node, endExclusive: pathLength);
    final rawValue = _stringifyArgument(node, pathLength);
    final value = forceString ? rawValue : _coerceJsonPrimitive(rawValue);
    _jsonSetPathValue(pathSegments, value);
  }

  void _jsonUnset(BdfdFunctionCallAst node) {
    if (!_hasJsonContext) {
      return;
    }
    final segments = _jsonPathSegments(node);
    if (segments.isEmpty) {
      _jsonClear();
      return;
    }
    _jsonRemovePathValue(segments);
  }

  void _jsonClear() {
    _jsonContext = null;
    _hasJsonContext = false;
  }

  String _jsonExists(BdfdFunctionCallAst node) {
    if (!_hasJsonContext) {
      return '';
    }
    final segments = _jsonPathSegments(node);
    final exists = _jsonPathExists(segments);
    return exists ? 'true' : 'false';
  }

  String _jsonStringify() {
    if (!_hasJsonContext) {
      return '';
    }
    return jsonEncode(_jsonContext);
  }

  String _jsonPretty(BdfdFunctionCallAst node) {
    if (!_hasJsonContext) {
      return '';
    }
    final indentRaw = _stringifyArgument(node, 0).trim();
    final indent = int.tryParse(indentRaw);
    final spaces = (indent == null || indent < 0) ? 2 : indent;
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(_jsonContext).replaceAll('  ', ' ' * spaces);
  }

  void _jsonArray(BdfdFunctionCallAst node) {
    final segments = _jsonPathSegments(node);
    _jsonSetPathValue(segments, <dynamic>[]);
  }

  String _jsonArrayCount(BdfdFunctionCallAst node) {
    if (!_hasJsonContext) {
      return '';
    }
    final value = _jsonGetPathValue(_jsonPathSegments(node));
    if (value is List) {
      return value.length.toString();
    }
    return '0';
  }

  String _jsonArrayIndex(BdfdFunctionCallAst node) {
    if (!_hasJsonContext) {
      return '';
    }
    if (node.arguments.length < 2) {
      return '-1';
    }

    final path = _jsonPathSegments(
      node,
      endExclusive: node.arguments.length - 1,
    );
    final list = _jsonGetPathValue(path);
    if (list is! List) {
      return '-1';
    }

    final expected = _coerceJsonPrimitive(
      _stringifyArgument(node, node.arguments.length - 1),
    );
    final index = list.indexWhere((item) => item == expected);
    return index.toString();
  }

  void _jsonArrayAppend(BdfdFunctionCallAst node) {
    if (node.arguments.length < 2) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a key path and a value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return;
    }

    final path = _jsonPathSegments(
      node,
      endExclusive: node.arguments.length - 1,
    );
    final value = _coerceJsonPrimitive(
      _stringifyArgument(node, node.arguments.length - 1),
    );
    final list = _jsonEnsureArray(path);
    list.add(value);
  }

  String _jsonArrayPop(BdfdFunctionCallAst node) {
    final list = _jsonEnsureArray(_jsonPathSegments(node));
    if (list.isEmpty) {
      return '';
    }
    final removed = list.removeLast();
    return _jsonStringifyValue(removed);
  }

  String _jsonArrayShift(BdfdFunctionCallAst node) {
    final list = _jsonEnsureArray(_jsonPathSegments(node));
    if (list.isEmpty) {
      return '';
    }
    final removed = list.removeAt(0);
    return _jsonStringifyValue(removed);
  }

  void _jsonArrayUnshift(BdfdFunctionCallAst node) {
    if (node.arguments.length < 2) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a key path and a value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return;
    }

    final path = _jsonPathSegments(
      node,
      endExclusive: node.arguments.length - 1,
    );
    final value = _coerceJsonPrimitive(
      _stringifyArgument(node, node.arguments.length - 1),
    );
    final list = _jsonEnsureArray(path);
    list.insert(0, value);
  }

  void _jsonArraySort(BdfdFunctionCallAst node) {
    final list = _jsonEnsureArray(_jsonPathSegments(node));
    list.sort((left, right) {
      final leftNumber = left is num ? left : num.tryParse(left.toString());
      final rightNumber = right is num ? right : num.tryParse(right.toString());
      if (leftNumber != null && rightNumber != null) {
        return leftNumber.compareTo(rightNumber);
      }
      if (leftNumber != null) {
        return -1;
      }
      if (rightNumber != null) {
        return 1;
      }
      return left.toString().compareTo(right.toString());
    });
  }

  void _jsonArrayReverse(BdfdFunctionCallAst node) {
    final list = _jsonEnsureArray(_jsonPathSegments(node));
    final reversed = list.reversed.toList(growable: false);
    list
      ..clear()
      ..addAll(reversed);
  }

  String _jsonJoinArray(BdfdFunctionCallAst node) {
    if (!_hasJsonContext) {
      return '';
    }
    if (node.arguments.isEmpty) {
      return '';
    }

    final separator = _stringifyArgument(node, node.arguments.length - 1);
    final path = _jsonPathSegments(
      node,
      endExclusive: node.arguments.length - 1,
    );
    final value = _jsonGetPathValue(path);
    if (value is! List) {
      return '';
    }
    return value.map(_jsonStringifyValue).join(separator);
  }

  List<dynamic> _jsonEnsureArray(List<Object> path) {
    final existing = _jsonGetPathValue(path);
    if (existing is List<dynamic>) {
      return existing;
    }
    _jsonSetPathValue(path, <dynamic>[]);
    final resolved = _jsonGetPathValue(path);
    if (resolved is List<dynamic>) {
      return resolved;
    }
    return <dynamic>[];
  }

  List<Object> _jsonPathSegments(
    BdfdFunctionCallAst node, {
    int startInclusive = 0,
    int? endExclusive,
  }) {
    final end = endExclusive ?? node.arguments.length;
    final segments = <Object>[];
    for (var index = startInclusive; index < end; index++) {
      final raw = _stringifyArgument(node, index).trim();
      if (raw.isEmpty) {
        continue;
      }
      final numeric = int.tryParse(raw);
      if (numeric != null) {
        segments.add(numeric);
      } else {
        segments.add(raw);
      }
    }
    return segments;
  }

  dynamic _coerceJsonPrimitive(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.toLowerCase() == 'true') {
      return true;
    }
    if (trimmed.toLowerCase() == 'false') {
      return false;
    }
    if (trimmed.toLowerCase() == 'null') {
      return null;
    }
    final asInt = int.tryParse(trimmed);
    if (asInt != null) {
      return asInt;
    }
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null) {
      return asDouble;
    }
    return raw;
  }

  String _jsonStringifyValue(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return jsonEncode(value);
  }

  bool _jsonPathExists(List<Object> path) {
    if (!_hasJsonContext) {
      return false;
    }
    if (path.isEmpty) {
      return true;
    }

    dynamic current = _jsonContext;
    for (final segment in path) {
      if (segment is String) {
        if (current is! Map || !current.containsKey(segment)) {
          return false;
        }
        current = current[segment];
        continue;
      }
      if (segment is int) {
        if (current is! List || segment < 0 || segment >= current.length) {
          return false;
        }
        current = current[segment];
      }
    }
    return true;
  }

  dynamic _jsonGetPathValue(List<Object> path) {
    if (!_hasJsonContext) {
      return null;
    }
    dynamic current = _jsonContext;
    for (final segment in path) {
      if (segment is String) {
        if (current is! Map || !current.containsKey(segment)) {
          return null;
        }
        current = current[segment];
        continue;
      }
      if (segment is int) {
        if (current is! List || segment < 0 || segment >= current.length) {
          return null;
        }
        current = current[segment];
      }
    }
    return current;
  }

  void _jsonSetPathValue(List<Object> path, dynamic value) {
    if (path.isEmpty) {
      _jsonContext = value;
      _hasJsonContext = true;
      return;
    }

    if (!_hasJsonContext || _jsonContext == null) {
      _jsonContext = path.first is int ? <dynamic>[] : <String, dynamic>{};
      _hasJsonContext = true;
    }

    dynamic current = _jsonContext;
    for (var index = 0; index < path.length - 1; index++) {
      final segment = path[index];
      final next = path[index + 1];
      if (segment is String) {
        if (current is! Map) {
          return;
        }
        final existing = current[segment];
        if (existing == null) {
          current[segment] = next is int ? <dynamic>[] : <String, dynamic>{};
        }
        current = current[segment];
        continue;
      }

      if (segment is int) {
        if (current is! List || segment < 0) {
          return;
        }
        while (current.length <= segment) {
          current.add(null);
        }
        if (current[segment] == null) {
          current[segment] = next is int ? <dynamic>[] : <String, dynamic>{};
        }
        current = current[segment];
      }
    }

    final last = path.last;
    if (last is String) {
      if (current is Map) {
        current[last] = value;
      }
      return;
    }
    if (last is int) {
      if (current is! List || last < 0) {
        return;
      }
      while (current.length <= last) {
        current.add(null);
      }
      current[last] = value;
    }
  }

  void _jsonRemovePathValue(List<Object> path) {
    if (!_hasJsonContext) {
      return;
    }
    if (path.isEmpty) {
      _jsonClear();
      return;
    }

    dynamic current = _jsonContext;
    for (var index = 0; index < path.length - 1; index++) {
      final segment = path[index];
      if (segment is String) {
        if (current is! Map || !current.containsKey(segment)) {
          return;
        }
        current = current[segment];
        continue;
      }
      if (segment is int) {
        if (current is! List || segment < 0 || segment >= current.length) {
          return;
        }
        current = current[segment];
      }
    }

    final last = path.last;
    if (last is String) {
      if (current is Map) {
        current.remove(last);
      }
      return;
    }
    if (last is int) {
      if (current is List && last >= 0 && last < current.length) {
        current.removeAt(last);
      }
    }
  }

  void _storePendingHttpHeader(BdfdFunctionCallAst node) {
    final headerName = _stringifyArgument(node, 0).trim();
    final headerValue = _stringifyArgument(node, 1);
    if (headerName.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'HTTP header name cannot be empty.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return;
    }
    _pendingHttpHeaders[headerName] = headerValue;
  }

  Action _buildHttpRequestAction({
    required String method,
    required BdfdFunctionCallAst node,
  }) {
    final url = _stringifyArgument(node, 0).trim();
    if (url.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'HTTP request URL cannot be empty for ${node.name}.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
    }

    final key = '_bdfd_http_${_httpRequestCounter++}';
    _lastHttpRequestKey = key;
    final body = _stringifyArgument(node, 1);
    final headers = Map<String, dynamic>.from(_pendingHttpHeaders);
    _pendingHttpHeaders.clear();

    return Action(
      type: BotCreatorActionType.httpRequest,
      key: key,
      payload: <String, dynamic>{
        'url': url,
        'method': method,
        'bodyMode': 'text',
        'bodyText': body,
        'bodyJson': const <String, dynamic>{},
        'headers': headers,
        'saveBodyToGlobalVar': '',
        'saveStatusToGlobalVar': '',
        'extractJsonPath': '',
      },
    );
  }

  String? _latestHttpStatusPlaceholder(BdfdFunctionCallAst node) {
    if (_requireLatestHttpRequestKey(node) == null) {
      return null;
    }
    return '((http.status))';
  }

  String? _latestHttpResultPlaceholder(BdfdFunctionCallAst node) {
    if (_requireLatestHttpRequestKey(node) == null) {
      return null;
    }

    final jsonPath = _buildHttpResultJsonPath(node);
    if (jsonPath == null || jsonPath.isEmpty) {
      return '((http.body))';
    }
    return '((http.body.$jsonPath))';
  }

  String? _requireLatestHttpRequestKey(BdfdFunctionCallAst node) {
    final requestKey = _lastHttpRequestKey;
    if (requestKey != null && requestKey.isNotEmpty) {
      return requestKey;
    }
    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message:
            '${node.name} requires a preceding HTTP request in the same BDFD script.',
        start: node.start,
        end: node.end,
        functionName: node.name,
      ),
    );
    return null;
  }

  String? _buildHttpResultJsonPath(BdfdFunctionCallAst node) {
    if (node.arguments.isEmpty) {
      return null;
    }

    final segments = <String>[];
    for (var index = 0; index < node.arguments.length; index++) {
      final rawSegment = _stringifyArgument(node, index).trim();
      if (rawSegment.isEmpty) {
        continue;
      }

      if (index == 0) {
        segments.add(rawSegment);
        continue;
      }

      final numericIndex = int.tryParse(rawSegment);
      if (numericIndex != null) {
        final current = segments.isEmpty ? r'$' : segments.removeLast();
        segments.add('$current[$numericIndex]');
        continue;
      }

      segments.add(rawSegment);
    }

    if (segments.isEmpty) {
      return null;
    }
    return r'$.' + segments.join('.');
  }

  Action _buildSetScopedVariableAction({
    required String scope,
    required BdfdFunctionCallAst node,
  }) {
    final key = _normalizeScopedVariableKey(_stringifyArgument(node, 0));
    final value = _stringifyArgument(node, 1);
    if (key.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'Scoped variable name cannot be empty for ${node.name}.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
    }

    return Action(
      type: BotCreatorActionType.setScopedVariable,
      payload: <String, dynamic>{
        'scope': scope,
        'key': key,
        'valueType': 'string',
        'value': value,
      },
    );
  }

  Action _buildAwaitFuncAction(BdfdFunctionCallAst node) {
    final awaitNameRaw = _stringifyArgument(node, 0).trim();
    final awaitName = _normalizeAwaitName(awaitNameRaw);
    if (awaitName.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'Await function name cannot be empty for ${node.name}.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
    }

    var userId = _stringifyArgument(node, 1).trim();
    var channelId = _stringifyArgument(node, 2).trim();

    if (userId.startsWith('(')) {
      userId = userId.substring(1).trim();
    }
    if (userId.endsWith(')')) {
      userId = userId.substring(0, userId.length - 1).trim();
    }
    if (channelId.startsWith('(')) {
      channelId = channelId.substring(1).trim();
    }
    if (channelId.endsWith(')')) {
      channelId = channelId.substring(0, channelId.length - 1).trim();
    }

    final payloadMap = <String, String>{
      'name': awaitName,
      'userId': userId.isEmpty ? '((author.id))' : userId,
      'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    return Action(
      type: BotCreatorActionType.setScopedVariable,
      payload: <String, dynamic>{
        'scope': 'user',
        'key': 'await_$awaitName',
        'valueType': 'json',
        'jsonValue': jsonEncode(payloadMap),
      },
    );
  }

  String _inlineCheckUserPerms(BdfdFunctionCallAst node) {
    final parsed = _buildCheckUserPermsCondition(node);
    if (parsed == null) {
      return '';
    }

    final key = 'check_user_perms_${_permissionCheckCounter++}';
    _deferredInlineActions.add(
      _buildGuardIfAction(
        condition: parsed.condition,
        thenActions: <Action>[
          _buildSetScopedVariableActionRaw(
            scope: 'message',
            key: key,
            value: 'true',
          ),
        ],
        elseActions: <Action>[
          _buildSetScopedVariableActionRaw(
            scope: 'message',
            key: key,
            value: 'false',
          ),
        ],
      ),
    );

    return _scopedVariablePlaceholder('message', key);
  }

  String _inlineMessageArgument(BdfdFunctionCallAst node) {
    final first = _stringifyArgument(node, 0).trim();
    final second = _stringifyArgument(node, 1).trim();

    if (first.isEmpty && second.isEmpty) {
      return '((message.content))';
    }

    final messageExpression = _messageArgumentExpression(first);
    final optionSource =
        second.isNotEmpty ? second : (messageExpression == null ? first : '');
    final optionExpression = _optionExpression(optionSource);

    if (messageExpression != null && optionExpression != null) {
      return '(($messageExpression|$optionExpression))';
    }
    if (messageExpression != null) {
      return '(($messageExpression))';
    }
    if (optionExpression != null) {
      return '(($optionExpression))';
    }

    return '((message.content))';
  }

  String? _messageArgumentExpression(String rawIndex) {
    final trimmed = rawIndex.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed == '>') {
      return 'last(split(message.content, " "))';
    }

    final parsedIndex = int.tryParse(trimmed);
    if (parsedIndex == null || parsedIndex < 0) {
      return null;
    }

    if (parsedIndex == 0) {
      return 'args.0';
    }

    final zeroBasedIndex = parsedIndex - 1;
    return 'message.content[$zeroBasedIndex]';
  }

  String? _optionExpression(String rawOptionName) {
    final trimmed = rawOptionName.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final normalized =
        trimmed.startsWith('opts.') ? trimmed.substring(5) : trimmed;
    if (normalized.isEmpty) {
      return null;
    }

    return 'opts.$normalized';
  }

  String _inlineMentionedChannels(BdfdFunctionCallAst node) {
    final mentionRaw = _stringifyArgument(node, 0).trim();
    final mentionNumber = int.tryParse(mentionRaw);
    if (mentionNumber == null || mentionNumber <= 0) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a positive mention number.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return '';
    }

    final zeroBasedIndex = mentionNumber - 1;
    final mentionExpression = 'message.mentions[$zeroBasedIndex]';
    final returnCurrentRaw = _stringifyArgument(node, 1).trim();
    final returnCurrent =
        returnCurrentRaw.isNotEmpty && _parseBooleanLike(returnCurrentRaw);

    if (returnCurrent) {
      return '(($mentionExpression|channel.id))';
    }
    return '(($mentionExpression))';
  }

  Action _buildSetScopedVariableActionRaw({
    required String scope,
    required String key,
    required String value,
  }) {
    return Action(
      type: BotCreatorActionType.setScopedVariable,
      payload: <String, dynamic>{
        'scope': scope,
        'key': key,
        'valueType': 'string',
        'value': value,
      },
    );
  }

  String _normalizeAwaitName(String raw) {
    final lowered = raw.trim().toLowerCase();
    if (lowered.isEmpty) {
      return '';
    }
    return lowered.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  String _scopedVariablePlaceholder(String scope, String rawKey) {
    final key = _normalizeScopedVariableKey(rawKey);
    if (key.isEmpty) {
      return '';
    }
    return '(($scope.bc_$key))';
  }

  String _normalizeScopedVariableKey(String rawKey) {
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('bc_')) {
      return trimmed.substring(3);
    }
    return trimmed;
  }

  String _rebuildFunctionSource(BdfdFunctionCallAst node) {
    final functionName =
        node.name.startsWith(r'$') ? node.name : '${r'$'}${node.name}';

    if (node.arguments.isEmpty) {
      return functionName;
    }

    final arguments = node.arguments.map(_stringifyNodes).join(';');
    return '$functionName[$arguments]';
  }

  Action _buildRespondWithMessageAction({
    String content = '',
    List<Map<String, dynamic>> embeds = const <Map<String, dynamic>>[],
  }) {
    return Action(
      type: BotCreatorActionType.respondWithMessage,
      payload: <String, dynamic>{
        'content': content,
        'embeds': embeds,
        'components': const <String, dynamic>{},
        'ephemeral': false,
      },
    );
  }

  Action? _buildChannelSendMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final content = _stringifyArgument(node, 1);

    if (channelId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a channel ID as first argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    if (content.trim().isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires message content as second argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    return Action(
      type: BotCreatorActionType.sendMessage,
      payload: <String, dynamic>{
        'targetType': 'channel',
        'channelId': channelId,
        'content': content,
      },
    );
  }

  Action? _buildChangeUsernameAction(BdfdFunctionCallAst node) {
    final username = _stringifyArgument(node, 0).trim();
    if (username.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a username.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    return Action(
      type: BotCreatorActionType.updateSelfUser,
      payload: <String, dynamic>{'username': username},
    );
  }

  Action? _buildChangeUsernameWithIdAction(BdfdFunctionCallAst node) {
    final targetId = _stringifyArgument(node, 0).trim();
    final username = _stringifyArgument(node, 1).trim();

    if (targetId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a user ID as first argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    if (username.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a username as second argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final updateAction = Action(
      type: BotCreatorActionType.updateSelfUser,
      payload: <String, dynamic>{'username': username},
    );

    final condition = _ParsedCondition(
      left: targetId,
      operator: 'equals',
      right: '((user.id))',
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: <Action>[updateAction],
      elseActions: const <Action>[],
    );
  }

  // ── Moderation action builders ──────────────────────────────────────

  Action _buildBanAction(BdfdFunctionCallAst node) {
    return Action(
      type: BotCreatorActionType.banUser,
      payload: <String, dynamic>{
        'userId': '((message.mentions[0]|author.id))',
        'reason': '',
        'deleteMessageDays': 0,
      },
    );
  }

  Action _buildBanIdAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $banID takes no args — the user ID is extracted from the
    // last word of the author's message at runtime.
    return Action(
      type: BotCreatorActionType.banUser,
      payload: <String, dynamic>{
        'userId': '((message.args.last))',
        'reason': '',
        'deleteMessageDays': 0,
      },
    );
  }

  Action _buildUnbanAction(BdfdFunctionCallAst node) {
    return Action(
      type: BotCreatorActionType.unbanUser,
      payload: <String, dynamic>{'userId': '((message.mentions[0]|author.id))'},
    );
  }

  Action _buildUnbanIdAction(BdfdFunctionCallAst node) {
    final userId = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.unbanUser,
      payload: <String, dynamic>{
        'userId': userId.isEmpty ? '((message.mentions[0]))' : userId,
      },
    );
  }

  Action _buildKickAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $kick always kicks the command author, not a mentioned user.
    return Action(
      type: BotCreatorActionType.kickUser,
      payload: <String, dynamic>{'userId': '((author.id))', 'reason': ''},
    );
  }

  Action _buildKickMentionAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $kickMention[Reason] kicks the mentioned user with a reason.
    final reason = _stringifyArgument(node, 0);
    return Action(
      type: BotCreatorActionType.kickUser,
      payload: <String, dynamic>{
        'userId': '((message.mentions[0]))',
        'reason': reason,
      },
    );
  }

  Action _buildTimeoutAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $timeout[Duration;(User ID)]
    // arg 0 = duration (required), arg 1 = user ID (optional).
    final duration = _stringifyArgument(node, 0).trim();
    final userId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.muteUser,
      payload: <String, dynamic>{
        'userId': userId.isEmpty ? '((message.mentions[0]))' : userId,
        'duration': duration,
        'reason': '',
      },
    );
  }

  Action _buildUntimeoutAction(BdfdFunctionCallAst node) {
    final userId = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.unmuteUser,
      payload: <String, dynamic>{
        'userId': userId.isEmpty ? '((message.mentions[0]))' : userId,
      },
    );
  }

  Action _buildMuteAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $mute[Muted Role Name] — DEPRECATED.
    // Assigns the named role to the mentioned user.
    final roleName = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{
        'userId': '((message.mentions[0]))',
        'roleName': roleName,
      },
    );
  }

  Action _buildUnmuteAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $unmute[Muted Role Name] — DEPRECATED.
    // Removes the named role from the mentioned user.
    final roleName = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.removeRole,
      payload: <String, dynamic>{
        'userId': '((message.mentions[0]))',
        'roleName': roleName,
      },
    );
  }

  Action _buildClearAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $clear takes no args — count from the author's message
    // content at runtime.
    return Action(
      type: BotCreatorActionType.deleteMessages,
      payload: <String, dynamic>{
        'channelId': '((channel.id))',
        'count': '((message.args[0]))',
      },
    );
  }

  // ── Role action builders ──────────────────────────────────────────

  Action _buildGiveRoleAction(BdfdFunctionCallAst node) {
    final firstArg = _stringifyArgument(node, 0).trim();
    final secondArg = _stringifyArgument(node, 1).trim();
    final hasSecondArg = secondArg.isNotEmpty;
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{
        'userId': hasSecondArg ? firstArg : '((message.mentions[0]|author.id))',
        'roleId': hasSecondArg ? secondArg : firstArg,
      },
    );
  }

  Action _buildTakeRoleAction(BdfdFunctionCallAst node) {
    final firstArg = _stringifyArgument(node, 0).trim();
    final secondArg = _stringifyArgument(node, 1).trim();
    final hasSecondArg = secondArg.isNotEmpty;
    return Action(
      type: BotCreatorActionType.removeRole,
      payload: <String, dynamic>{
        'userId': hasSecondArg ? firstArg : '((message.mentions[0]|author.id))',
        'roleId': hasSecondArg ? secondArg : firstArg,
      },
    );
  }

  /// $giveRoles[Role ID;Role ID;...] / $takeRoles[Role ID;Role ID;...]
  List<Action> _buildMultiRoleAction(
    BdfdFunctionCallAst node, {
    required bool give,
  }) {
    final actions = <Action>[];
    for (var i = 0; i < node.arguments.length; i++) {
      final roleId = _stringifyArgument(node, i).trim();
      if (roleId.isEmpty) continue;
      actions.add(
        Action(
          type:
              give
                  ? BotCreatorActionType.addRole
                  : BotCreatorActionType.removeRole,
          payload: <String, dynamic>{
            'userId': '((message.mentions[0]|author.id))',
            'roleId': roleId,
          },
        ),
      );
    }
    return actions;
  }

  List<Action> _buildRoleGrantAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $roleGrant[User ID;+/-Role ID;...]
    final userId = _stringifyArgument(node, 0).trim();
    if (userId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a user ID as first argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return const <Action>[];
    }
    final actions = <Action>[];
    for (var i = 1; i < node.arguments.length; i++) {
      final raw = _stringifyArgument(node, i).trim();
      if (raw.isEmpty) continue;
      final isRemove = raw.startsWith('-');
      final isAdd = raw.startsWith('+');
      final roleId = (isRemove || isAdd) ? raw.substring(1).trim() : raw;
      if (roleId.isEmpty) continue;
      actions.add(
        Action(
          type:
              isRemove
                  ? BotCreatorActionType.removeRole
                  : BotCreatorActionType.addRole,
          payload: <String, dynamic>{'userId': userId, 'roleId': roleId},
        ),
      );
    }
    return actions;
  }

  Action? _buildCreateRoleAction(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();
    if (name.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a role name.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final color = _stringifyArgument(node, 1);
    final hoist = _parseBooleanLike(_stringifyArgument(node, 2));
    final mentionable = _parseBooleanLike(_stringifyArgument(node, 3));
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{
        'createNew': true,
        'name': name,
        if (color.isNotEmpty) 'color': color,
        'hoist': hoist,
        'mentionable': mentionable,
      },
    );
  }

  Action? _buildDeleteRoleAction(BdfdFunctionCallAst node) {
    final roleId = _stringifyArgument(node, 0).trim();
    if (roleId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a role ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.removeRole,
      payload: <String, dynamic>{'roleId': roleId, 'deleteRole': true},
    );
  }

  Action? _buildColorRoleAction(BdfdFunctionCallAst node) {
    final roleId = _stringifyArgument(node, 0).trim();
    final color = _stringifyArgument(node, 1).trim();
    if (roleId.isEmpty || color.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a role ID and color.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{'roleId': roleId, 'updateColor': color},
    );
  }

  Action? _buildModifyRoleAction(BdfdFunctionCallAst node) {
    final roleId = _stringifyArgument(node, 0).trim();
    if (roleId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a role ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final name = _stringifyArgument(node, 1);
    final color = _stringifyArgument(node, 2);
    final hoist = _stringifyArgument(node, 3);
    final mentionable = _stringifyArgument(node, 4);
    final position = _stringifyArgument(node, 5);
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{
        'roleId': roleId,
        'modify': true,
        if (name.isNotEmpty) 'name': name,
        if (color.isNotEmpty) 'color': color,
        if (hoist.isNotEmpty) 'hoist': _parseBooleanLike(hoist),
        if (mentionable.isNotEmpty)
          'mentionable': _parseBooleanLike(mentionable),
        if (position.isNotEmpty) 'position': int.tryParse(position),
      },
    );
  }

  Action? _buildModifyRolePermsAction(BdfdFunctionCallAst node) {
    final roleId = _stringifyArgument(node, 0).trim();
    if (roleId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a role ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final permissions = <String>[];
    for (var i = 1; i < node.arguments.length; i++) {
      final perm = _stringifyArgument(node, i).trim();
      if (perm.isNotEmpty) {
        permissions.add(_normalizePermissionToken(perm));
      }
    }
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{
        'roleId': roleId,
        'modifyPermissions': permissions,
      },
    );
  }

  Action? _buildSetUserRolesAction(BdfdFunctionCallAst node) {
    final userId = _stringifyArgument(node, 0).trim();
    if (userId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a user ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final roleIds = <String>[];
    for (var i = 1; i < node.arguments.length; i++) {
      final roleId = _stringifyArgument(node, i).trim();
      if (roleId.isNotEmpty) {
        roleIds.add(roleId);
      }
    }
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{'userId': userId, 'setRoles': roleIds},
    );
  }

  // ── Message action builders ──────────────────────────────────────

  Action? _buildDeleteMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.deleteMessages,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
      },
    );
  }

  Action? _buildDeleteInAction(BdfdFunctionCallAst node) {
    final delay = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.deleteMessages,
      payload: <String, dynamic>{
        'channelId': '((channel.id))',
        'messageId': '((message.id))',
        'delay': delay,
      },
    );
  }

  Action _buildDmAction(BdfdFunctionCallAst node) {
    final userIdArg = _stringifyArgument(node, 0).trim();
    final contentArg = _stringifyArgument(node, 1);
    final isContentOnlyMode = userIdArg.isEmpty || node.arguments.isEmpty;
    return Action(
      type: BotCreatorActionType.sendMessage,
      payload: <String, dynamic>{
        'targetType': 'dm',
        'userId': isContentOnlyMode ? '((author.id))' : userIdArg,
        'content': isContentOnlyMode ? '' : contentArg,
      },
    );
  }

  Action? _buildEditMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    final content = _stringifyArgument(node, 2);
    return Action(
      type: BotCreatorActionType.editMessage,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId,
        'content': content,
      },
    );
  }

  Action? _buildEditInAction(BdfdFunctionCallAst node) {
    final delay = _stringifyArgument(node, 0).trim();
    final content = _stringifyArgument(node, 1);
    return Action(
      type: BotCreatorActionType.editMessage,
      payload: <String, dynamic>{
        'channelId': '((channel.id))',
        'messageId': '((message.id))',
        'content': content,
        'delay': delay,
      },
    );
  }

  Action? _buildEditEmbedInAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    final title = _stringifyArgument(node, 2);
    final description = _stringifyArgument(node, 3);
    final color = _stringifyArgument(node, 4);
    return Action(
      type: BotCreatorActionType.editMessage,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId,
        'embeds': <Map<String, dynamic>>[
          <String, dynamic>{
            if (title.isNotEmpty) 'title': title,
            if (description.isNotEmpty) 'description': description,
            if (color.isNotEmpty) 'color': color,
          },
        ],
      },
    );
  }

  Action _buildPinMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.pinMessage,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
      },
    );
  }

  Action _buildUnpinMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.unpinMessage,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
      },
    );
  }

  Action _buildPublishMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.sendMessage,
      payload: <String, dynamic>{
        'targetType': 'crosspost',
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
      },
    );
  }

  Action _buildReplyInAction(BdfdFunctionCallAst node) {
    final delay = _stringifyArgument(node, 0).trim();
    final content = _stringifyArgument(node, 1);
    return Action(
      type: BotCreatorActionType.sendMessage,
      payload: <String, dynamic>{
        'targetType': 'reply',
        'channelId': '((channel.id))',
        'messageId': '((message.id))',
        'content': content,
        'delay': delay,
      },
    );
  }

  Action _buildSendEmbedMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final title = _stringifyArgument(node, 1);
    final description = _stringifyArgument(node, 2);
    final color = _stringifyArgument(node, 3);
    return Action(
      type: BotCreatorActionType.sendMessage,
      payload: <String, dynamic>{
        'targetType': 'channel',
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'content': '',
        'embeds': <Map<String, dynamic>>[
          <String, dynamic>{
            if (title.isNotEmpty) 'title': title,
            if (description.isNotEmpty) 'description': description,
            if (color.isNotEmpty) 'color': color,
          },
        ],
      },
    );
  }

  Action? _buildUseChannelAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    if (channelId.isNotEmpty) {
      _useChannelId = channelId;
    }
    return null;
  }

  // ── Channel action builders ──────────────────────────────────────

  Action? _buildCreateChannelAction(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();
    if (name.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a channel name.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final type = _stringifyArgument(node, 1).trim().toLowerCase();
    final categoryId = _stringifyArgument(node, 2).trim();
    return Action(
      type: BotCreatorActionType.createChannel,
      payload: <String, dynamic>{
        'name': name,
        'type': type.isEmpty ? 'text' : type,
        if (categoryId.isNotEmpty) 'parentId': categoryId,
      },
    );
  }

  Action? _buildDeleteChannelsAction(BdfdFunctionCallAst node) {
    // $deleteChannels[Channel ID] - deletes by ID
    // $deleteChannelsByName[Channel name;...] - deletes by name(s)
    final isByName = node.normalizedName == 'deletechannelsbyname';
    final channelIds = <String>[];
    for (var i = 0; i < node.arguments.length; i++) {
      final arg = _stringifyArgument(node, i).trim();
      if (arg.isNotEmpty) {
        channelIds.add(arg);
      }
    }
    if (channelIds.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              '${node.name} requires at least one channel ${isByName ? 'name' : 'ID'}.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.removeChannel,
      payload: <String, dynamic>{
        if (isByName)
          'channelNames': channelIds
        else
          'channelId': channelIds.first,
      },
    );
  }

  Action? _buildModifyChannelAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    if (channelId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a channel ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final name = _stringifyArgument(node, 1);
    final topic = _stringifyArgument(node, 2);
    final position = _stringifyArgument(node, 3);
    final nsfw = _stringifyArgument(node, 4);
    return Action(
      type: BotCreatorActionType.updateChannel,
      payload: <String, dynamic>{
        'channelId': channelId,
        if (name.isNotEmpty) 'name': name,
        if (topic.isNotEmpty) 'topic': topic,
        if (position.isNotEmpty) 'position': int.tryParse(position),
        if (nsfw.isNotEmpty) 'nsfw': _parseBooleanLike(nsfw),
      },
    );
  }

  Action? _buildEditChannelPermsAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final roleOrUserId = _stringifyArgument(node, 1).trim();
    if (channelId.isEmpty || roleOrUserId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a channel ID and role/user ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final permissions = <String>[];
    for (var i = 2; i < node.arguments.length; i++) {
      final perm = _stringifyArgument(node, i).trim();
      if (perm.isNotEmpty) {
        permissions.add(_normalizePermissionToken(perm));
      }
    }
    return Action(
      type: BotCreatorActionType.editChannelPermissions,
      payload: <String, dynamic>{
        'channelId': channelId,
        'targetId': roleOrUserId,
        'permissions': permissions,
      },
    );
  }

  /// BDFD wiki: $modifyChannelPerms[Channel ID;Permissions;User/Role ID]
  /// Arg order differs from $editChannelPerms: permissions come before the
  /// target ID.
  Action? _buildModifyChannelPermsAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final permissionsRaw = _stringifyArgument(node, 1).trim();
    final targetId = _stringifyArgument(node, 2).trim();
    if (channelId.isEmpty || targetId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a channel ID and a user/role ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final permissions = <String>[];
    if (permissionsRaw.isNotEmpty) {
      for (final token in permissionsRaw.split(';')) {
        final perm = token.trim();
        if (perm.isNotEmpty) {
          permissions.add(_normalizePermissionToken(perm));
        }
      }
    }
    // Also collect any extra arguments beyond arg 2 as additional permissions.
    for (var i = 3; i < node.arguments.length; i++) {
      final perm = _stringifyArgument(node, i).trim();
      if (perm.isNotEmpty) {
        permissions.add(_normalizePermissionToken(perm));
      }
    }
    return Action(
      type: BotCreatorActionType.editChannelPermissions,
      payload: <String, dynamic>{
        'channelId': channelId,
        'targetId': targetId,
        'permissions': permissions,
      },
    );
  }

  Action _buildSlowmodeAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final seconds = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.updateChannel,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'rateLimitPerUser': int.tryParse(seconds) ?? 0,
      },
    );
  }

  // ── Reaction action builders ──────────────────────────────────────

  Action _buildAddReactionsAction(BdfdFunctionCallAst node) {
    final emojis = <String>[];
    for (var index = 0; index < node.arguments.length; index++) {
      final emoji = _stringifyArgument(node, index).trim();
      if (emoji.isNotEmpty) {
        emojis.add(emoji);
      }
    }
    return Action(
      type: BotCreatorActionType.addReaction,
      payload: <String, dynamic>{
        'channelId': '((channel.id))',
        'messageId': '((message.id))',
        'emojis': emojis,
      },
    );
  }

  Action _buildAddCmdReactionsAction(BdfdFunctionCallAst node) {
    final emojis = <String>[];
    for (var index = 0; index < node.arguments.length; index++) {
      final emoji = _stringifyArgument(node, index).trim();
      if (emoji.isNotEmpty) {
        emojis.add(emoji);
      }
    }
    return Action(
      type: BotCreatorActionType.addReaction,
      payload: <String, dynamic>{
        'channelId': '((channel.id))',
        'messageId': '((trigger.message.id|message.id))',
        'emojis': emojis,
      },
    );
  }

  Action _buildAddMessageReactionsAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    final emojis = <String>[];
    for (var index = 2; index < node.arguments.length; index++) {
      final emoji = _stringifyArgument(node, index).trim();
      if (emoji.isNotEmpty) {
        emojis.add(emoji);
      }
    }
    return Action(
      type: BotCreatorActionType.addReaction,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
        'emojis': emojis,
      },
    );
  }

  Action _buildClearReactionsAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.clearAllReactions,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
      },
    );
  }

  // ── Emoji action builders ──────────────────────────────────────

  Action? _buildAddEmojiAction(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();
    final imageUrl = _stringifyArgument(node, 1).trim();
    if (name.isEmpty || imageUrl.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a name and image URL.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.createEmoji,
      payload: <String, dynamic>{'name': name, 'imageUrl': imageUrl},
    );
  }

  Action? _buildRemoveEmojiAction(BdfdFunctionCallAst node) {
    final emojiId = _stringifyArgument(node, 0).trim();
    if (emojiId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires an emoji ID or name.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.deleteEmoji,
      payload: <String, dynamic>{'emojiId': emojiId},
    );
  }

  // ── Webhook action builders ──────────────────────────────────────

  Action _buildWebhookSendAction(BdfdFunctionCallAst node) {
    final webhookUrl = _stringifyArgument(node, 0).trim();
    final content = _stringifyArgument(node, 1);
    final username = _stringifyArgument(node, 2);
    final avatarUrl = _stringifyArgument(node, 3);
    return Action(
      type: BotCreatorActionType.sendWebhook,
      payload: <String, dynamic>{
        'webhookUrl': webhookUrl,
        'content': content,
        if (username.isNotEmpty) 'username': username,
        if (avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      },
    );
  }

  Action _buildWebhookCreateAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final name = _stringifyArgument(node, 1).trim();
    final avatarUrl = _stringifyArgument(node, 2);
    return Action(
      type: BotCreatorActionType.sendWebhook,
      payload: <String, dynamic>{
        'createWebhook': true,
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'name': name,
        if (avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      },
    );
  }

  Action _buildWebhookDeleteAction(BdfdFunctionCallAst node) {
    final webhookUrl = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.deleteWebhook,
      payload: <String, dynamic>{'webhookUrl': webhookUrl},
    );
  }

  // ── Modal action builder ──────────────────────────────────────

  Action _buildNewModalAction(BdfdFunctionCallAst node) {
    final customId = _stringifyArgument(node, 0).trim();
    final title = _stringifyArgument(node, 1).trim();
    final inputs = List<Map<String, dynamic>>.from(_pendingModalInputs);
    _pendingModalInputs.clear();
    return Action(
      type: BotCreatorActionType.respondWithModal,
      payload: <String, dynamic>{
        'customId': customId,
        'title': title,
        'components': inputs,
      },
    );
  }

  // ── Cooldown action builders ──────────────────────────────────

  Action _buildCooldownAction(
    BdfdFunctionCallAst node, {
    required String scope,
  }) {
    final duration = _stringifyArgument(node, 0).trim();
    final errorMessage = _stringifyArgument(node, 1);
    final cooldownKey = 'cooldown_${scope}_${node.normalizedName}';

    final checkCondition = _ParsedCondition(
      left: '(($scope.bc_$cooldownKey))',
      operator: 'isEmpty',
      right: '',
    );

    final setAction = Action(
      type: BotCreatorActionType.setScopedVariable,
      payload: <String, dynamic>{
        'scope': scope == 'global' ? 'user' : scope,
        'key': cooldownKey,
        'valueType': 'string',
        'value': duration,
        'ttl': duration,
      },
    );

    final failureActions =
        errorMessage.trim().isEmpty
            ? <Action>[_buildForcedStopAction()]
            : <Action>[
              _buildRespondWithMessageAction(content: errorMessage),
              _buildForcedStopAction(),
            ];

    return Action(
      type: BotCreatorActionType.ifBlock,
      payload: <String, dynamic>{
        ...checkCondition.toPayload(prefix: 'condition.'),
        'thenActions': <Map<String, dynamic>>[setAction.toJson()],
        'elseIfConditions': const <Map<String, dynamic>>[],
        'elseActions': failureActions.map((action) => action.toJson()).toList(),
      },
    );
  }

  Action? _buildChangeCooldownTimeAction(BdfdFunctionCallAst node) {
    final cooldownType = _stringifyArgument(node, 0).trim();
    final duration = _stringifyArgument(node, 1).trim();
    if (cooldownType.isEmpty || duration.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a cooldown type and new duration.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.setScopedVariable,
      payload: <String, dynamic>{
        'scope': 'user',
        'key': 'cooldown_$cooldownType',
        'valueType': 'string',
        'value': duration,
        'ttl': duration,
      },
    );
  }

  // ── Variable reset builders ──────────────────────────────────

  Action _buildResetScopedVariableAction({
    required String scope,
    required BdfdFunctionCallAst node,
  }) {
    final key = _normalizeScopedVariableKey(_stringifyArgument(node, 0));
    return Action(
      type: BotCreatorActionType.removeScopedVariable,
      payload: <String, dynamic>{'scope': scope, 'key': key},
    );
  }

  // ── Blacklist guard builders ──────────────────────────────────

  Action? _transpileBlacklistIds(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      return null;
    }
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((author.id))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  Action? _transpileBlacklistRoles(BdfdFunctionCallAst node) {
    final guard = _extractGuardValuesAndMessage(node);
    if (guard.values.isEmpty) {
      return null;
    }
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.values
          .map(
            (name) => _ParsedCondition(
              left: '((member.roleNames))',
              operator: 'contains',
              right: name,
            ),
          )
          .toList(growable: false),
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  Action? _transpileBlacklistRoleIds(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      return null;
    }
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((member.roles))',
              operator: 'contains',
              right: id,
            ),
          )
          .toList(growable: false),
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  Action? _transpileBlacklistServers(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      return null;
    }
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((guild.id))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  Action? _transpileBlacklistUsers(BdfdFunctionCallAst node) {
    final guard = _extractGuardValuesAndMessage(node);
    if (guard.values.isEmpty) {
      return null;
    }
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.values
          .map(
            (username) => _ParsedCondition(
              left: '((author.username))',
              operator: 'matches',
              right:
                  '(?i)^${RegExp.escape(username)}'
                  r'$',
            ),
          )
          .toList(growable: false),
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  // ── Ticket builder ──────────────────────────────────────────

  Action _buildNewTicketAction(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();
    final categoryId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.createChannel,
      payload: <String, dynamic>{
        'name': name.isEmpty ? 'ticket-((user.username))' : name,
        'type': 'text',
        if (categoryId.isNotEmpty) 'parentId': categoryId,
        'isTicket': true,
      },
    );
  }

  // ── Args check builder ──────────────────────────────────────

  Action? _buildArgsCheckAction(BdfdFunctionCallAst node) {
    final operatorRaw = _stringifyArgument(node, 0).trim();
    final count = _stringifyArgument(node, 1).trim();
    final errorMessage = _stringifyArgument(node, 2);

    if (count.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires an operator and count.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    String operator;
    if (operatorRaw == '>' || operatorRaw == '>=') {
      operator = operatorRaw == '>=' ? 'greaterOrEqual' : 'greaterThan';
    } else if (operatorRaw == '<' || operatorRaw == '<=') {
      operator = operatorRaw == '<=' ? 'lessOrEqual' : 'lessThan';
    } else {
      operator = 'greaterOrEqual';
    }

    final condition = _ParsedCondition(
      left: '((message.argCount))',
      operator: operator,
      right: count,
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: errorMessage),
    );
  }

  // ── Inline computation helpers ──────────────────────────────────

  // ── Workflow call builder ─────────────────────────────────────

  Action? _buildCallWorkflowAction(BdfdFunctionCallAst node) {
    final workflowName = _stringifyArgument(node, 0).trim();
    if (workflowName.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a workflow name as first argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final arguments = <String, dynamic>{};
    for (var i = 1; i < node.arguments.length; i++) {
      final raw = _stringifyArgument(node, i);
      final equalsIndex = raw.indexOf('=');
      if (equalsIndex > 0) {
        final key = raw.substring(0, equalsIndex).trim();
        final value = raw.substring(equalsIndex + 1);
        if (key.isNotEmpty) {
          arguments[key] = value;
          continue;
        }
      }
      arguments['$i'] = raw;
    }

    final key = '_bdfd_callworkflow_${_callWorkflowCounter++}';
    _lastCallWorkflowKey = key;

    return Action(
      type: BotCreatorActionType.runWorkflow,
      key: key,
      payload: <String, dynamic>{
        'workflowName': workflowName,
        if (arguments.isNotEmpty) 'arguments': arguments,
      },
    );
  }

  String? _latestWorkflowResponsePlaceholder(BdfdFunctionCallAst node) {
    final requestKey = _lastCallWorkflowKey;
    if (requestKey == null || requestKey.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              '${node.name} requires a preceding \$callWorkflow in the same BDFD script.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    if (node.arguments.isEmpty) {
      return '((workflow.response))';
    }

    final property = _stringifyArgument(node, 0).trim();
    if (property.isEmpty) {
      return '((workflow.response))';
    }
    return '((workflow.response.$property))';
  }

  // ── Inline computation helpers ──────────────────────────────────

  String _inlineReplaceText(BdfdFunctionCallAst node) {
    final text = _stringifyArgument(node, 0);
    final sample = _stringifyArgument(node, 1);
    final replacement = _stringifyArgument(node, 2);
    final amountRaw = _stringifyArgument(node, 3).trim();
    final amount = int.tryParse(amountRaw) ?? 1;

    if (sample.isEmpty) {
      return text;
    }

    if (amount == -1) {
      return text.replaceAll(sample, replacement);
    }

    var result = text;
    var count = 0;
    while (count < amount) {
      final index = result.indexOf(sample);
      if (index < 0) {
        break;
      }
      result =
          result.substring(0, index) +
          replacement +
          result.substring(index + sample.length);
      count++;
    }
    return result;
  }

  String _inlineTitleCase(String text) {
    if (text.isEmpty) {
      return '';
    }
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) {
            return word;
          }
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _inlineCropText(BdfdFunctionCallAst node) {
    final text = _stringifyArgument(node, 0);
    final lengthRaw = _stringifyArgument(node, 1).trim();
    final suffix = _stringifyArgument(node, 2);
    final length = int.tryParse(lengthRaw) ?? text.length;
    if (length >= text.length) {
      return text;
    }
    return text.substring(0, length) + suffix;
  }

  String _inlineRepeatMessage(BdfdFunctionCallAst node) {
    final text = _stringifyArgument(node, 0);
    final countRaw = _stringifyArgument(node, 1).trim();
    final count = int.tryParse(countRaw) ?? 1;
    if (count <= 0) {
      return '';
    }
    if (count > 100) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} repeat count capped at 100.',
          severity: BdfdTranspileDiagnosticSeverity.warning,
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return text * 100;
    }
    return text * count;
  }

  String _inlineRemoveContains(BdfdFunctionCallAst node) {
    var text = _stringifyArgument(node, 0);
    for (var i = 1; i < node.arguments.length; i++) {
      final target = _stringifyArgument(node, i);
      if (target.isNotEmpty) {
        text = text.replaceAll(target, '');
      }
    }
    return text;
  }

  String _inlineNumberSeparator(BdfdFunctionCallAst node) {
    final numberRaw = _stringifyArgument(node, 0).trim();
    final separator = _stringifyArgument(node, 1);
    final sep = separator.isEmpty ? ',' : separator;
    final parts = numberRaw.split('.');
    final intPart = parts[0];

    final buffer = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0 && intPart[i] != '-') {
        buffer.write(sep);
      }
      buffer.write(intPart[i]);
      count++;
    }

    final result = buffer.toString().split('').reversed.join();
    if (parts.length > 1) {
      return '$result.${parts[1]}';
    }
    return result;
  }

  void _textSplitState(BdfdFunctionCallAst node) {
    final text = _stringifyArgument(node, 0);
    final separator = _stringifyArgument(node, 1);
    _textSplitParts = text.split(separator);
  }

  String _inlineSplitText(BdfdFunctionCallAst node) {
    final indexRaw = _stringifyArgument(node, 0).trim();
    final index = int.tryParse(indexRaw);
    if (index == null || index < 1 || index > _textSplitParts.length) {
      return '';
    }
    return _textSplitParts[index - 1];
  }

  String _inlineEditSplitText(BdfdFunctionCallAst node) {
    final indexRaw = _stringifyArgument(node, 0).trim();
    final value = _stringifyArgument(node, 1);
    final index = int.tryParse(indexRaw);
    if (index == null || index < 1 || index > _textSplitParts.length) {
      return '';
    }
    _textSplitParts[index - 1] = value;
    return '';
  }

  String _inlineGetTextSplitIndex(BdfdFunctionCallAst node) {
    final value = _stringifyArgument(node, 0);
    final index = _textSplitParts.indexOf(value);
    return index >= 0 ? (index + 1).toString() : '-1';
  }

  String _inlineJoinSplitText(BdfdFunctionCallAst node) {
    final separator = _stringifyArgument(node, 0);
    return _textSplitParts.join(separator);
  }

  String _inlineRemoveSplitTextElement(BdfdFunctionCallAst node) {
    final indexRaw = _stringifyArgument(node, 0).trim();
    final index = int.tryParse(indexRaw);
    if (index != null && index >= 1 && index <= _textSplitParts.length) {
      _textSplitParts.removeAt(index - 1);
    }
    return '';
  }

  // ── Math inline helpers ──────────────────────────────────────

  String _inlineCalculate(BdfdFunctionCallAst node) {
    final expression = _stringifyArgument(node, 0).trim();
    if (expression.isEmpty) {
      return '0';
    }
    final result = _evaluateSimpleMathExpression(expression);
    if (result == null) {
      return '((calculate[$expression]))';
    }
    if (result == result.roundToDouble() && result.abs() < 1e15) {
      return result.toInt().toString();
    }
    return result.toString();
  }

  double? _evaluateSimpleMathExpression(String expression) {
    final cleaned = expression.replaceAll(' ', '');
    if (cleaned.isEmpty) {
      return null;
    }

    final directNum = double.tryParse(cleaned);
    if (directNum != null) {
      return directNum;
    }

    final twoOperandPattern = RegExp(
      r'^(-?[\d.]+)\s*([+\-*/%^])\s*(-?[\d.]+)$',
    );
    final match = twoOperandPattern.firstMatch(cleaned);
    if (match == null) {
      return null;
    }

    final left = double.tryParse(match.group(1)!);
    final operator = match.group(2)!;
    final right = double.tryParse(match.group(3)!);
    if (left == null || right == null) {
      return null;
    }

    switch (operator) {
      case '+':
        return left + right;
      case '-':
        return left - right;
      case '*':
        return left * right;
      case '/':
        return right != 0 ? left / right : 0;
      case '%':
        return right != 0 ? left % right : 0;
      case '^':
        return math.pow(left, right).toDouble();
      default:
        return null;
    }
  }

  String _inlineMathUnary(
    BdfdFunctionCallAst node,
    int Function(double) operation,
  ) {
    final raw = _stringifyArgument(node, 0).trim();
    final value = double.tryParse(raw);
    if (value == null) {
      return '((${node.normalizedName}[$raw]))';
    }
    return operation(value).toString();
  }

  String _inlineMathUnaryDouble(
    BdfdFunctionCallAst node,
    double Function(double) operation,
  ) {
    final raw = _stringifyArgument(node, 0).trim();
    final value = double.tryParse(raw);
    if (value == null) {
      return '((${node.normalizedName}[$raw]))';
    }
    final result = operation(value);
    if (result == result.roundToDouble() && result.abs() < 1e15) {
      return result.toInt().toString();
    }
    return result.toString();
  }

  String _inlineMathBinary(
    BdfdFunctionCallAst node,
    num Function(num, num) operation,
  ) {
    final aRaw = _stringifyArgument(node, 0).trim();
    final bRaw = _stringifyArgument(node, 1).trim();
    final a = num.tryParse(aRaw);
    final b = num.tryParse(bRaw);
    if (a == null || b == null) {
      return '((${node.normalizedName}[$aRaw;$bRaw]))';
    }
    final result = operation(a, b);
    if (result is double &&
        result == result.roundToDouble() &&
        result.abs() < 1e15) {
      return result.toInt().toString();
    }
    return result.toString();
  }

  String _inlineMathBinaryOp(
    BdfdFunctionCallAst node,
    num Function(num, num) operation,
  ) {
    final aRaw = _stringifyArgument(node, 0).trim();
    final bRaw = _stringifyArgument(node, 1).trim();
    final a = num.tryParse(aRaw);
    final b = num.tryParse(bRaw);
    if (a == null || b == null) {
      return '((${node.normalizedName}[$aRaw;$bRaw]))';
    }
    final result = operation(a, b);
    if (result is double &&
        result == result.roundToDouble() &&
        result.abs() < 1e15) {
      return result.toInt().toString();
    }
    return result.toString();
  }

  String _inlineSum(BdfdFunctionCallAst node) {
    num total = 0;
    for (var i = 0; i < node.arguments.length; i++) {
      final raw = _stringifyArgument(node, i).trim();
      final value = num.tryParse(raw);
      if (value == null) {
        final args = List.generate(
          node.arguments.length,
          (j) => _stringifyArgument(node, j).trim(),
        ).join(';');
        return '((sum[$args]))';
      }
      total += value;
    }
    if (total is double &&
        total == total.roundToDouble() &&
        total.abs() < 1e15) {
      return total.toInt().toString();
    }
    return total.toString();
  }

  String _inlineSort(BdfdFunctionCallAst node) {
    final values = <String>[];
    for (var i = 0; i < node.arguments.length; i++) {
      final raw = _stringifyArgument(node, i).trim();
      if (raw.isNotEmpty) {
        values.add(raw);
      }
    }
    final allNumeric = values.every((v) => num.tryParse(v) != null);
    if (allNumeric) {
      values.sort((a, b) => num.parse(a).compareTo(num.parse(b)));
    } else {
      values.sort();
    }
    return values.join(';');
  }

  // ── Boolean check helpers ──────────────────────────────────────

  String _inlineIsBoolean(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 0).trim().toLowerCase();
    const booleans = {'true', 'false', 'yes', 'no', '1', '0', 'on', 'off'};
    return booleans.contains(raw) ? 'true' : 'false';
  }

  String _inlineIsInteger(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 0).trim();
    return int.tryParse(raw) != null ? 'true' : 'false';
  }

  String _inlineIsNumber(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 0).trim();
    return num.tryParse(raw) != null ? 'true' : 'false';
  }

  String _inlineIsValidHex(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 0).trim();
    final cleaned = raw.startsWith('#') ? raw.substring(1) : raw;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleaned) ? 'true' : 'false';
  }

  String _inlineCheckCondition(BdfdFunctionCallAst node) {
    final expression = _stringifyArgument(node, 0).trim();
    if (expression.isEmpty) {
      return 'false';
    }
    final condition = _parseSimpleCondition(expression);
    return _evaluateConditionStatically(condition) ? 'true' : 'false';
  }

  bool _evaluateConditionStatically(_ParsedCondition condition) {
    switch (condition.operator) {
      case 'equals':
        return condition.left == condition.right;
      case 'notEquals':
        return condition.left != condition.right;
      case 'contains':
        return condition.left.contains(condition.right);
      case 'notContains':
        return !condition.left.contains(condition.right);
      case 'startsWith':
        return condition.left.startsWith(condition.right);
      case 'endsWith':
        return condition.left.endsWith(condition.right);
      case 'isNotEmpty':
        return condition.left.isNotEmpty;
      default:
        final leftNum = num.tryParse(condition.left);
        final rightNum = num.tryParse(condition.right);
        if (leftNum != null && rightNum != null) {
          switch (condition.operator) {
            case 'greaterThan':
              return leftNum > rightNum;
            case 'lessThan':
              return leftNum < rightNum;
            case 'greaterOrEqual':
              return leftNum >= rightNum;
            case 'lessOrEqual':
              return leftNum <= rightNum;
          }
        }
        return false;
    }
  }

  String _inlineCheckContains(BdfdFunctionCallAst node) {
    final text = _stringifyArgument(node, 0);
    for (var i = 1; i < node.arguments.length; i++) {
      final target = _stringifyArgument(node, i);
      if (target.isNotEmpty && text.contains(target)) {
        return 'true';
      }
    }
    return 'false';
  }

  // ── Random helpers ──────────────────────────────────────────

  String _inlineRandom(BdfdFunctionCallAst node) {
    final minRaw = _stringifyArgument(node, 0).trim();
    final maxRaw = _stringifyArgument(node, 1).trim();
    final minVal = int.tryParse(minRaw) ?? 0;
    final maxVal = int.tryParse(maxRaw) ?? 100;
    if (minVal >= maxVal) {
      return minVal.toString();
    }
    final random = math.Random();
    return (minVal + random.nextInt(maxVal - minVal + 1)).toString();
  }

  String _inlineRandomString(BdfdFunctionCallAst node) {
    final lengthRaw = _stringifyArgument(node, 0).trim();
    final chars = _stringifyArgument(node, 1);
    final length = int.tryParse(lengthRaw) ?? 10;
    final effectiveLength = length.clamp(1, 1000);
    const defaultChars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final charSet = chars.isEmpty ? defaultChars : chars;
    final random = math.Random();
    final buffer = StringBuffer();
    for (var i = 0; i < effectiveLength; i++) {
      buffer.write(charSet[random.nextInt(charSet.length)]);
    }
    return buffer.toString();
  }

  String _inlineRandomText(BdfdFunctionCallAst node) {
    if (node.arguments.isEmpty) {
      return '';
    }
    final random = math.Random();
    final index = random.nextInt(node.arguments.length);
    return _stringifyArgument(node, index);
  }

  // ── Date helper ──────────────────────────────────────────

  String _inlineDate() {
    final now = DateTime.now().toUtc();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ── getMessage helper ──────────────────────────────────────

  String _inlineGetMessage(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    final property = _stringifyArgument(node, 2).trim();
    if (channelId.isEmpty || messageId.isEmpty) {
      return '((message.content))';
    }
    if (property.isNotEmpty) {
      return '((getMessage[$channelId;$messageId].$property))';
    }
    return '((getMessage[$channelId;$messageId].content))';
  }
}

class _PendingResponse {
  final StringBuffer _content = StringBuffer();
  final Map<String, dynamic> _embed = <String, dynamic>{};
  final List<Map<String, dynamic>> _components = <Map<String, dynamic>>[];
  bool _ephemeral = false;
  bool _tts = false;
  bool _removeLinks = false;
  bool _allowMentions = true;
  bool _allowUserMentions = true;
  bool _allowRoleMentions = false;
  String? _currentSelectMenuId;

  bool get hasPendingContent =>
      _content.toString().isNotEmpty ||
      _embed.isNotEmpty ||
      _components.isNotEmpty;

  void appendContent(String value) {
    _content.write(value);
  }

  Map<String, dynamic> ensureEmbed() => _embed;

  void addComponent(Map<String, dynamic> component) {
    _components.add(component);
  }

  void addButton({
    required bool newRow,
    required String interactionIdOrUrl,
    required String label,
    required String style,
    bool disabled = false,
    String emoji = '',
    String messageId = '',
  }) {
    _components.add(<String, dynamic>{
      'type': 'button',
      'newRow': newRow,
      'customId': style != 'link' ? interactionIdOrUrl : '',
      'url': style == 'link' ? interactionIdOrUrl : '',
      'label': label,
      'style': style,
      'disabled': disabled,
      if (emoji.isNotEmpty) 'emoji': emoji,
      if (messageId.isNotEmpty) 'messageId': messageId,
    });
  }

  void addSelectMenuOption({
    required String menuId,
    required String label,
    required String value,
    String description = '',
    bool isDefault = false,
    String emoji = '',
  }) {
    _components.add(<String, dynamic>{
      'type': 'selectMenuOption',
      'menuId': menuId,
      'label': label,
      'value': value,
      if (description.isNotEmpty) 'description': description,
      'default': isDefault,
      if (emoji.isNotEmpty) 'emoji': emoji,
    });
  }

  void clearComponents() {
    _components.clear();
  }

  void clearButtons() {
    _components.removeWhere((component) => component['type'] == 'button');
  }

  void removeComponent(String customId) {
    _components.removeWhere(
      (component) =>
          component['customId'] == customId || component['menuId'] == customId,
    );
  }

  List<Map<String, dynamic>> ensureEmbedFields() {
    final current = _embed['fields'];
    if (current is List<Map<String, dynamic>>) {
      return current;
    }
    if (current is List) {
      final casted = current
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: true);
      _embed['fields'] = casted;
      return casted;
    }
    final fields = <Map<String, dynamic>>[];
    _embed['fields'] = fields;
    return fields;
  }

  Action? buildAction({String? channelId}) {
    var content = _content.toString();
    final hasEmbed = _embed.isNotEmpty;
    final hasComponents = _components.isNotEmpty;
    if (content.trim().isEmpty && !hasEmbed && !hasComponents) {
      return null;
    }

    // $removeLinks: strip all URLs from the bot response content.
    if (_removeLinks) {
      content = content.replaceAll(RegExp(r'https?://[^\s]+'), '');
    }

    final embeds =
        hasEmbed
            ? <Map<String, dynamic>>[_cloneMap(_embed)]
            : <Map<String, dynamic>>[];
    final components =
        hasComponents
            ? List<Map<String, dynamic>>.from(_components.map(_cloneMap))
            : <Map<String, dynamic>>[];
    final ephemeral = _ephemeral;
    final tts = _tts;
    final allowMentions = _allowMentions;
    final allowUserMentions = _allowUserMentions;
    final allowRoleMentions = _allowRoleMentions;
    _content.clear();
    _embed.clear();
    _components.clear();
    _ephemeral = false;
    _tts = false;
    _removeLinks = false;
    _allowMentions = true;
    _allowUserMentions = true;
    _allowRoleMentions = false;

    return Action(
      type: BotCreatorActionType.respondWithMessage,
      payload: <String, dynamic>{
        'content': content,
        'embeds': embeds,
        'components':
            components.isEmpty
                ? const <String, dynamic>{}
                : <String, dynamic>{'items': components},
        'ephemeral': ephemeral,
        if (tts) 'tts': true,
        if (!allowMentions) 'allowMentions': false,
        if (!allowUserMentions) 'allowUserMentions': false,
        if (allowRoleMentions) 'allowRoleMentions': true,
        if (channelId != null && channelId.isNotEmpty) 'channelId': channelId,
      },
    );
  }

  Map<String, dynamic> _cloneMap(Map<String, dynamic> value) {
    return value.map((key, entryValue) {
      if (entryValue is Map) {
        return MapEntry(key, _cloneMap(Map<String, dynamic>.from(entryValue)));
      }
      if (entryValue is List) {
        return MapEntry(
          key,
          entryValue
              .map((item) {
                if (item is Map) {
                  return _cloneMap(Map<String, dynamic>.from(item));
                }
                return item;
              })
              .toList(growable: false),
        );
      }
      return MapEntry(key, entryValue);
    });
  }
}

class _GuardIdsAndMessage {
  const _GuardIdsAndMessage({required this.ids, required this.message});

  final List<String> ids;
  final String message;
}

class _GuardValuesAndMessage {
  const _GuardValuesAndMessage({required this.values, required this.message});

  final List<String> values;
  final String message;
}

class _MessageContainsArgs {
  const _MessageContainsArgs({
    required this.message,
    required this.words,
    required this.errorMessage,
  });

  final String message;
  final List<String> words;
  final String errorMessage;
}

class _PermissionGuardArgs {
  const _PermissionGuardArgs({
    required this.permissions,
    required this.message,
  });

  final List<String> permissions;
  final String message;
}

class _CheckUserPermsParsed {
  const _CheckUserPermsParsed({required this.condition, required this.message});

  final _ParsedCondition condition;
  final String message;
}

class _ParsedCondition {
  const _ParsedCondition({
    required this.left,
    required this.operator,
    required this.right,
  }) : group = null,
       conditions = const <_ParsedCondition>[],
       negate = false;

  const _ParsedCondition.logical({
    required this.group,
    required this.conditions,
    this.negate = false,
  }) : left = '',
       operator = '',
       right = '';

  final String left;
  final String operator;
  final String right;
  final String? group;
  final List<_ParsedCondition> conditions;
  final bool negate;

  Map<String, dynamic> toPayload({required String prefix}) {
    final conditionGroup = group;
    if (conditionGroup == null) {
      return <String, dynamic>{
        '${prefix}variable': left,
        '${prefix}operator': operator,
        '${prefix}value': right,
      };
    }

    return <String, dynamic>{
      '${prefix}group': conditionGroup,
      '${prefix}negate': negate,
      '${prefix}conditions': conditions
          .map((condition) => condition.toPayload(prefix: ''))
          .toList(growable: false),
      '${prefix}variable': '',
      '${prefix}operator': 'equals',
      '${prefix}value': '',
    };
  }
}

class _IfBranch {
  _IfBranch({required this.conditionNode, required this.nodes});

  final BdfdFunctionCallAst conditionNode;
  final List<BdfdAstNode> nodes;
}

class _ConsumedIfBlock {
  const _ConsumedIfBlock({required this.action, required this.nextIndex});

  final Action action;
  final int nextIndex;
}

class _ConsumedLoopBlock {
  const _ConsumedLoopBlock({
    this.precomputedActions,
    required this.nextIndex,
    required this.bodyNodes,
    required this.iterations,
    this.cStyleInit,
    this.cStyleCondition,
    this.cStyleUpdate,
  });

  /// Pre-computed actions (used by try/catch blocks that reuse this class).
  final List<Action>? precomputedActions;
  final int nextIndex;
  final List<BdfdAstNode> bodyNodes;
  final int iterations;

  /// C-style for loop fields (non-null when [isCStyleLoop] is true).
  final Map<String, int>? cStyleInit;
  final String? cStyleCondition;
  final String? cStyleUpdate;

  bool get isCStyleLoop => cStyleInit != null;
}

bool _parseBooleanLike(String raw) {
  final normalized = raw.trim().toLowerCase();
  return normalized == 'yes' ||
      normalized == 'true' ||
      normalized == '1' ||
      normalized == 'on';
}

const int _maxSupportedLoopIterations = 100;

const Map<String, String> _inlineRuntimeVariables = <String, String>{
  // ── User / author info ── (resolved via generateKeyValues / _messageContentExtra / buildInteractionCreateEventContext)
  'userid': '((user.id))',
  'username': '((user.username))',
  'usertag': '((user.tag))',
  'useravatar': '((user.avatar))',
  'userbanner': '((user.banner))',
  'authorid': '((author.id))',
  'authorofmessage': '((target.message.author.id|author.id))',
  'authorusername': '((author.username))',
  'authortag': '((author.tag))',
  'authoravatar': '((author.avatar))',
  'authorbanner': '((author.banner))',
  'discriminator': '((author.tag))',
  'displayname': '((member.nick|author.username))',
  'isadmin': '((member.isAdmin))',
  'isbot': '((author.isBot))',
  'nickname': '((member.nick))',
  'memberid': '((member.id))',
  'membernick': '((member.nick))',
  'userperms': '((member.permissions))',
  'userserveravatar': '((member.avatar))',
  'finduser': '((user.id))',
  'creationdate': '((user.createdAt))',
  'userjoineddiscord': '((user.createdAt))',
  'isbooster': '((member.isBooster))',
  'userbannercolor': '((user.bannerColor))',
  'userjoined': '((member.joinedAt))',
  // ── User info — not yet resolved (need runtime support) ──
  'getuserstatus': '((user.status))',
  'getcustomstatus': '((user.customStatus))',
  'isuserdmenabled': '((user.dmEnabled))',
  'userbadges': '((user.badges))',
  'userexists': '((user.exists))',
  'userinfo': '((user.info))',
  'hypesquad': '((user.hypesquad))',
  // ── Guild / server info ── (resolved via generateKeyValues + extractGuildRuntimeDetails)
  'guildid': '((guild.id))',
  'guildname': '((guild.name))',
  'guildicon': '((guildIcon))',
  'guildcount': '((guild.count))',
  'membercount': '((guild.memberCount))',
  'allmemberscount': '((guild.memberCount))',
  'memberscount': '((guild.memberCount))',
  'getmemberscount': '((guild.memberCount))',
  'serverid': '((guild.id))',
  'servername': '((guild.name))',
  'servericon': '((guildIcon))',
  'serverdescription': '((guild.description))',
  'serverowner': '((guild.ownerId))',
  'serververificationlvl': '((guild.verificationLevel))',
  'serververificationlevel': '((guild.verificationLevel))',
  'serverboostcount': '((guild.premiumSubscriptionCount))',
  'serverfeatures': '((guild.features))',
  'servervanityurl': '((guild.vanityUrlCode))',
  'boostcount': '((guild.premiumSubscriptionCount))',
  'boostlevel': '((guild.premiumTier))',
  'guildbanner': '((guild.banner))',
  'serverbanner': '((guild.banner))',
  'serversplash': '((guild.splash))',
  'afktimeout': '((guild.afkTimeout))',
  'stickercount': '((guild.stickerCount))',
  'rolenames': '((guild.roleNames))',
  'rolecount': '((guild.roleCount))',
  // ── Guild info — not yet resolved (need runtime support) ──
  'guildexists': '((guild.exists))',
  'onlinemembers': '((guild.onlineMembers))',
  'serveremojis': '((guild.emojis))',
  'serverinfo': '((guild.info))',
  'serverregion': '((guild.region))',
  // ── Channel info ── (resolved via generateKeyValues + extractChannelRuntimeDetails)
  'channelid': '((channel.id))',
  'channelname': '((channel.name))',
  'channeltype': '((channel.type))',
  'channeltopic': '((channel.topic))',
  'channelposition': '((channel.position))',
  'parentid': '((channel.parentId))',
  'categoryid': '((channel.parentId))',
  'channelcategoryid': '((channel.parentId))',
  'ruleschannelid': '((guild.rulesChannelId))',
  'systemchannelid': '((guild.systemChannelId))',
  'afkchannelid': '((guild.afkChannelId))',
  'getslowmode': '((channel.slowmode))',
  'voiceuserlimit': '((channel.userLimit))',
  'isnsfw': '((channel.nsfw))',
  'channelnsfw': '((channel.nsfw))',
  'findchannel': '((channel.id))',
  // ── Channel info — not yet resolved (need runtime support) ──
  'channelcount': '((guild.channelCount))',
  'channelexists': '((channel.exists))',
  'channelnames': '((guild.channelNames))',
  'channelidfromname': '((channel.idByName))',
  'categorycount': '((guild.categoryCount))',
  'categorychannels': '((channel.parent.channels))',
  'dmchannelid': '((user.dmChannelId))',
  'lastmessageid': '((channel.lastMessageId))',
  'lastpintimestamp': '((channel.lastPinTimestamp))',
  'usersinchannel': '((channel.userCount))',
  'serverchannelexists': '((channel.exists))',
  // ── Bot info ── (resolved via extractBotRuntimeDetails + runner gateway)
  'servercount': '((bot.guildCount))',
  'servernames': '((bot.guildNames))',
  'botid': '((bot.id))',
  'botname': '((bot.username))',
  'botcount': '((bot.guildCount))',
  'ping': '((bot.ping))',
  'uptime': '((bot.uptime))',
  'shardid': '((bot.shardId))',
  'getbotinvite': '((bot.invite))',
  'scriptlanguage': 'BDFD',
  // ── Bot info — not yet resolved ──
  'botownerid': '((bot.ownerId))',
  'botcommands': '((bot.commands))',
  'executiontime': '((execution.time))',
  'nodeversion': '((bot.nodeVersion))',
  'slashcommandscount': '((bot.slashCommandsCount))',
  'commandscount': '((bot.commandsCount))',
  // ── Command / interaction context ── (resolved via generateKeyValues / runner)
  'commandname': '((commandName))',
  'commandtype': '((commandType))',
  'commandtrigger': '((commandName))',
  'customid': '((interaction.customId))',
  'slashid': '((interaction.id))',
  // ── Command — not yet resolved ──
  'commandfolder': '((command.folder))',
  'input': '((interaction.input))',
  // ── Message info ── (resolved via _messageContentExtra)
  'messageid': '((message.id))',
  'messagetype': '((message.type))',
  'mentioned': '((message.mentions[0]))',
  'messageurl': '((message.url))',
  'messagetimestamp': '((message.timestamp))',
  'repliedmessageid': '((message.referencedMessage.id))',
  'ismessageedited': '((message.isEdited))',
  'messageeditedtimestamp': '((message.editedTimestamp))',
  'getattachments': '((message.attachments))',
  'url': '((message.url))',
  'mentionedroles': '((message.roleMentions))',
  // ── Message info — not yet resolved (need runtime support) ──
  'ismentioned': '((message.isMentioned))',
  'nomentionmessage': '((message.cleanContent))',
  'getembeddata': '((message.embeds))',
  // ── Role info ── (resolved via extractMemberRuntimeDetails + extractGuildRuntimeDetails)
  'userroles': '((member.roles))',
  // ── Role info — not yet resolved (need runtime support) ──
  'highestrole': '((member.highestRole))',
  'lowestrole': '((member.lowestRole))',
  'highestrolewithperms': '((member.highestRoleWithPerms))',
  'lowestrolewithperms': '((member.lowestRoleWithPerms))',
  // ── Thread info — not yet resolved ──
  'threadmessagecount': '((thread.messageCount))',
  'threadusercount': '((thread.memberCount))',
  // ── Moderation query — not yet resolved ──
  'isbanned': '((target.isBanned))',
  'istimedout': '((target.isTimedOut))',
  'getbanreason': '((target.banReason))',
  // ── Error handling ── (only available in try/catch context)
  'error': '((error.message))',
  // ── Misc ──
  'argcount': '((args.count))',
  'isslash': '((interaction.isSlash))',
  'enabled': '((command.enabled))',
  'variablescount': '((variables.count))',
  // ── No-op compatibility (return empty string) ──
  'alternativeparsing': '',
  'disableinnerspaceremoval': '',
  'disablespecialescaping': '',
  'enabledecimals': '',
  'optoff': '',
  'ignorelinks': '',
  'botlistdescription': '',
  'botlisthide': '',
  'botnode': '',
  'deletecommand': '',
  'registerguildcommands': '',
  'unregisterguildcommands': '',
};

const Set<String> _knownBdfdPermissionTokens = <String>{
  'addreactions',
  'administrator',
  'attachfiles',
  'banmembers',
  'changenickname',
  'connect',
  'createinstantinvite',
  'createprivatethreads',
  'createpublicthreads',
  'deafenmembers',
  'embedlinks',
  'kickmembers',
  'managechannels',
  'manageevents',
  'manageguild',
  'manageguildexpressions',
  'managemessages',
  'managenicknames',
  'manageroles',
  'managethreads',
  'managewebhooks',
  'mentioneveryone',
  'moderatemembers',
  'movemembers',
  'mutemembers',
  'priorityspeaker',
  'readmessagehistory',
  'requesttospeak',
  'sendmessages',
  'sendmessagesinthreads',
  'sendttsmessages',
  'sendvoicemessages',
  'speak',
  'stream',
  'useapplicationcommands',
  'useexternalemojis',
  'useexternalstickers',
  'usesoundboard',
  'usevoiceactivity',
  'viewauditlog',
  'viewchannel',
  'viewguildinsights',
};

const Map<String, String> _permissionTokenAliases = <String, String>{
  'admin': 'administrator',
  'ban': 'banmembers',
  'kick': 'kickmembers',
  'changenicknames': 'changenickname',
  'externalemojis': 'useexternalemojis',
  'externalstickers': 'useexternalstickers',
  'manageemojis': 'manageguildexpressions',
  'manageserver': 'manageguild',
  'readmessages': 'viewchannel',
  'slashcommands': 'useapplicationcommands',
  'tts': 'sendttsmessages',
  'usevad': 'usevoiceactivity',
  'voicedeafen': 'deafenmembers',
  'voicemute': 'mutemembers',
};
