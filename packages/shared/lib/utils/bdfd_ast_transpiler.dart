import 'dart:convert';

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
  String? _lastHttpRequestKey;
  final List<Action> _deferredInlineActions = <Action>[];
  dynamic _jsonContext;
  bool _hasJsonContext = false;

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
        final flushed = pendingResponse.buildAction();
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
        final flushed = pendingResponse.buildAction();
        if (flushed != null) {
          actions.add(flushed);
        }

        final consumed = _consumeLoopBlock(nodes: nodes, startIndex: index);
        if (consumed == null) {
          index += 1;
          continue;
        }

        actions.addAll(consumed.actions);
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
        final inlineReplacement = allowsTopLevelInline
          ? _stringifyInlineFunction(node)
          : null;
      if (inlineReplacement != null) {
        pendingResponse.appendContent(inlineReplacement);
        actions.addAll(_drainDeferredInlineActions());
        index += 1;
        continue;
      }

      if (_requiresPendingResponseFlush(node.normalizedName)) {
        final flushed = pendingResponse.buildAction();
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

    final trailingResponse = pendingResponse.buildAction();
    if (trailingResponse != null) {
      actions.add(trailingResponse);
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
        node.arguments.length <= 1;
  }

  bool _isStandaloneLoopDelimiter(String normalizedName) {
    return normalizedName == 'endfor' || normalizedName == 'endloop';
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

          final iterations = _parseLoopIterations(loopNode);
          if (iterations == null) {
            return _ConsumedLoopBlock(actions: const <Action>[], nextIndex: cursor + 1);
          }

          return _ConsumedLoopBlock(
            actions: _transpileLoopIterations(
              bodyNodes: loopBodyNodes,
              iterations: iterations,
            ),
            nextIndex: cursor + 1,
          );
        }
      }

      loopBodyNodes.add(currentNode);
    }

    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message: '${loopNode.name} not closed with ${r'$endfor'} or ${r'$endloop'}.',
        start: loopNode.start,
        end: loopNode.end,
        functionName: loopNode.name,
      ),
    );

    final iterations = _parseLoopIterations(loopNode);
    if (iterations == null) {
      return _ConsumedLoopBlock(actions: const <Action>[], nextIndex: nodes.length);
    }

    return _ConsumedLoopBlock(
      actions: _transpileLoopIterations(
        bodyNodes: loopBodyNodes,
        iterations: iterations,
      ),
      nextIndex: nodes.length,
    );
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
          message: '${loopNode.name} iteration count must be an integer literal.',
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

    final actions = <Action>[];
    for (var index = 0; index < iterations; index++) {
      actions.addAll(_transpileNodes(bodyNodes));
    }
    return actions;
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
              right: '(?i)^${RegExp.escape(username)}' r'$',
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
      channelId = normalizedChannel.isEmpty ? '((channel.id))' : normalizedChannel;
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

    final condition = _ParsedCondition.logical(group: 'and', conditions: conditions);

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
        conditions: <_ParsedCondition>[selfMemberBranch, byIdBranch, ownerBranch],
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
      elseActions: _buildGuardFailureActions(
        message: parsed.errorMessage,
      ),
    );
  }

  _MessageContainsArgs _extractMessageContainsArgs(BdfdFunctionCallAst node) {
    final defaultMessage = '((message.content))';
    if (node.arguments.isEmpty) {
      return const _MessageContainsArgs(message: '((message.content))', words: <String>[], errorMessage: '');
    }

    final rawMessage = _stringifyArgument(node, 0).trim();
    final message = rawMessage.isEmpty ? defaultMessage : rawMessage;

    if (node.arguments.length == 1) {
      return _MessageContainsArgs(message: message, words: const <String>[], errorMessage: '');
    }

    final words = <String>[];
    var errorMessage = '';
    final hasErrorMessage =
      node.arguments.length >= 3 &&
      _looksLikeLikelyErrorMessage(_stringifyNodes(node.arguments.last));
    final wordsEndExclusive = hasErrorMessage
        ? node.arguments.length - 1
        : node.arguments.length;

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

  _GuardValuesAndMessage _extractGuardValuesAndMessage(BdfdFunctionCallAst node) {
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
    final valueArguments = hasMessage
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
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
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
        return _inlineMessageArgument(node);
      case 'mentionedchannels':
        return _inlineMentionedChannels(node);
      default:
        break;
    }

    final placeholder = _inlineRuntimePlaceholder(node);
    if (placeholder != null) {
      return placeholder;
    }

    switch (node.normalizedName) {
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
      case 'httpstatus':
        return _latestHttpStatusPlaceholder(node);
      case 'httpresult':
        return _latestHttpResultPlaceholder(node);
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
      default:
        return null;
    }
  }

  String? _inlineRuntimePlaceholder(BdfdFunctionCallAst node) {
    return _inlineRuntimeVariables[node.normalizedName];
  }

  bool _isInlineOnlyFunction(String normalizedName) {
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
      case 'awaitfunc':
      case 'changeusername':
      case 'changeusernamewithid':
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
    final optionSource = second.isNotEmpty
      ? second
      : (messageExpression == null ? first : '');
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
    if (parsedIndex == null || parsedIndex <= 0) {
      return null;
    }

    final zeroBasedIndex = parsedIndex - 1;
    return 'message.content[$zeroBasedIndex]';
  }

  String? _optionExpression(String rawOptionName) {
    final trimmed = rawOptionName.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final normalized = trimmed.startsWith('opts.')
        ? trimmed.substring(5)
        : trimmed;
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
}

class _PendingResponse {
  final StringBuffer _content = StringBuffer();
  final Map<String, dynamic> _embed = <String, dynamic>{};

  bool get hasPendingContent =>
      _content.toString().isNotEmpty || _embed.isNotEmpty;

  void appendContent(String value) {
    _content.write(value);
  }

  Map<String, dynamic> ensureEmbed() => _embed;

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

  Action? buildAction() {
    final content = _content.toString();
    final hasEmbed = _embed.isNotEmpty;
    if (content.trim().isEmpty && !hasEmbed) {
      return null;
    }

    final embeds =
        hasEmbed
            ? <Map<String, dynamic>>[_cloneMap(_embed)]
            : <Map<String, dynamic>>[];
    _content.clear();
    _embed.clear();

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
  const _CheckUserPermsParsed({
    required this.condition,
    required this.message,
  });

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
  const _ConsumedLoopBlock({required this.actions, required this.nextIndex});

  final List<Action> actions;
  final int nextIndex;
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
  'creationdate': '((user.createdAt))',
  'discriminator': '((author.tag))',
  'displayname': '((member.nick|author.username))',
  'getuserstatus': '((user.status))',
  'getcustomstatus': '((user.customStatus))',
  'isadmin': '((member.isAdmin))',
  'isbooster': '((member.isBooster))',
  'isbot': '((author.isBot))',
  'isuserdmenabled': '((user.dmEnabled))',
  'nickname': '((member.nick))',
  'memberid': '((member.id))',
  'membernick': '((member.nick))',
  'userperms': '((member.permissions))',
  'guildid': '((guild.id))',
  'guildname': '((guild.name))',
  'guildicon': '((guild.icon))',
  'guildcount': '((guild.count))',
  'membercount': '((guild.count))',
  'serverid': '((guild.id))',
  'servername': '((guild.name))',
  'servericon': '((guild.icon))',
  'channelid': '((channel.id))',
  'channelname': '((channel.name))',
  'channeltype': '((channel.type))',
  'userbadges': '((user.badges))',
  'userbannercolor': '((user.bannerColor))',
  'userexists': '((user.exists))',
  'userinfo': '((user.info))',
  'userjoined': '((member.joinedAt))',
  'userjoineddiscord': '((user.createdAt))',
  'userserveravatar': '((member.avatar))',
  'finduser': '((user.id))',
  'commandname': '((commandName))',
  'commandtype': '((commandType))',
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
