import 'bdfd_ast.dart';
import 'bdfd_lexer.dart';

class BdfdParserDiagnostic {
  const BdfdParserDiagnostic({
    required this.message,
    required this.start,
    required this.end,
    required this.line,
    required this.column,
  });

  final String message;
  final int start;
  final int end;
  final int line;
  final int column;
}

class BdfdParserResult {
  const BdfdParserResult({required this.ast, required this.diagnostics});

  final BdfdScriptAst ast;
  final List<BdfdParserDiagnostic> diagnostics;

  bool get hasErrors => diagnostics.isNotEmpty;
}

class BdfdParser {
  BdfdParserResult parseTokens(List<BdfdToken> tokens) {
    final parser = _BdfdTokenParser(tokens);
    return parser.parse();
  }
}

class _BdfdTokenParser {
  _BdfdTokenParser(this.tokens);

  final List<BdfdToken> tokens;
  final List<BdfdParserDiagnostic> _diagnostics = <BdfdParserDiagnostic>[];

  int _index = 0;

  BdfdParserResult parse() {
    final nodes = _parseNodesUntil(const <BdfdTokenType>{BdfdTokenType.eof});
    return BdfdParserResult(
      ast: BdfdScriptAst(nodes: List<BdfdAstNode>.unmodifiable(nodes)),
      diagnostics: List<BdfdParserDiagnostic>.unmodifiable(_diagnostics),
    );
  }

  List<BdfdAstNode> _parseNodesUntil(Set<BdfdTokenType> terminators) {
    final nodes = <BdfdAstNode>[];

    while (!_isAtEnd && !terminators.contains(_current.type)) {
      final node = _parseNode();
      if (node != null) {
        nodes.add(node);
        continue;
      }

      final token = _advance();
      _diagnostics.add(
        BdfdParserDiagnostic(
          message: 'Unexpected token ${token.type.name} while parsing script.',
          start: token.start,
          end: token.end,
          line: token.line,
          column: token.column,
        ),
      );
    }

    return nodes;
  }

  BdfdAstNode? _parseNode() {
    if (_match(BdfdTokenType.text)) {
      final token = _previous;
      return BdfdTextAst(token.lexeme, start: token.start, end: token.end);
    }

    if (_match(BdfdTokenType.function)) {
      return _parseFunctionCall(_previous);
    }

    return null;
  }

  BdfdFunctionCallAst _parseFunctionCall(BdfdToken functionToken) {
    switch (_normalizedFunctionName(functionToken.lexeme)) {
      case 'checkuserperms':
        return _parseCheckUserPerms(functionToken);
      case 'ignorechannels':
        return _parseIgnoreChannels(functionToken);
      case 'onlyadmin':
        return _parseOnlyAdmin(functionToken);
      case 'onlybotchannelperms':
        return _parseOnlyBotChannelPerms(functionToken);
      case 'onlybotperms':
        return _parseOnlyBotPerms(functionToken);
      case 'onlyforcategories':
        return _parseOnlyForCategories(functionToken);
      case 'onlyforchannels':
        return _parseOnlyForChannels(functionToken);
      case 'onlyforids':
        return _parseOnlyForIDs(functionToken);
      case 'onlyforroles':
        return _parseOnlyForRoles(functionToken);
      case 'onlyforroleids':
        return _parseOnlyForRoleIDs(functionToken);
      case 'onlyforservers':
        return _parseOnlyForServers(functionToken);
      case 'onlyforusers':
        return _parseOnlyForUsers(functionToken);
      case 'onlyif':
        return _parseOnlyIf(functionToken);
      case 'onlyifmessagecontains':
        return _parseOnlyIfMessageContains(functionToken);
      case 'onlynsfw':
        return _parseOnlyNSFW(functionToken);
      case 'onlyperms':
        return _parseOnlyPerms(functionToken);
      case 'for':
        return _parseFor(functionToken);
      case 'loop':
        return _parseLoop(functionToken);
      case 'endfor':
        return _parseEndFor(functionToken);
      case 'endloop':
        return _parseEndLoop(functionToken);
      default:
        return _parseGenericFunctionCall(functionToken);
    }
  }

  String _normalizedFunctionName(String lexeme) {
    final trimmed = lexeme.trim();
    if (trimmed.startsWith(r'$')) {
      return trimmed.substring(1).toLowerCase();
    }
    return trimmed.toLowerCase();
  }

  BdfdFunctionCallAst _parseCheckUserPerms(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseIgnoreChannels(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyAdmin(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyBotChannelPerms(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyBotPerms(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyForCategories(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyForChannels(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyForIDs(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyForRoles(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyForRoleIDs(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyForServers(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyForUsers(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyIf(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyIfMessageContains(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyNSFW(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseOnlyPerms(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseFor(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseLoop(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseEndFor(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseEndLoop(BdfdToken functionToken) =>
      _parseGenericFunctionCall(functionToken);

  BdfdFunctionCallAst _parseGenericFunctionCall(BdfdToken functionToken) {
    final arguments = <List<BdfdAstNode>>[];
    var end = functionToken.end;

    if (_match(BdfdTokenType.openBracket)) {
      final openBracket = _previous;
      final currentArgument = <BdfdAstNode>[];

      while (!_isAtEnd && !_check(BdfdTokenType.closeBracket)) {
        if (_match(BdfdTokenType.semicolon)) {
          arguments.add(List<BdfdAstNode>.unmodifiable(currentArgument));
          currentArgument.clear();
          continue;
        }

        if (_check(BdfdTokenType.eof)) {
          break;
        }

        final node = _parseNode();
        if (node != null) {
          currentArgument.add(node);
          end = node.end ?? end;
          continue;
        }

        final token = _advance();
        _diagnostics.add(
          BdfdParserDiagnostic(
            message:
                'Unexpected token ${token.type.name} inside arguments for ${functionToken.lexeme}.',
            start: token.start,
            end: token.end,
            line: token.line,
            column: token.column,
          ),
        );
      }

      arguments.add(List<BdfdAstNode>.unmodifiable(currentArgument));

      if (_match(BdfdTokenType.closeBracket)) {
        end = _previous.end;
      } else {
        _diagnostics.add(
          BdfdParserDiagnostic(
            message: 'Expected closing bracket for ${functionToken.lexeme}.',
            start: openBracket.start,
            end: openBracket.end,
            line: openBracket.line,
            column: openBracket.column,
          ),
        );
      }
    }

    return BdfdFunctionCallAst(
      name: functionToken.lexeme,
      arguments: List<List<BdfdAstNode>>.unmodifiable(arguments),
      start: functionToken.start,
      end: end,
    );
  }

  bool get _isAtEnd => _current.type == BdfdTokenType.eof;

  BdfdToken get _current => tokens[_index];

  BdfdToken get _previous => tokens[_index - 1];

  bool _check(BdfdTokenType type) => !_isAtEnd && _current.type == type;

  bool _match(BdfdTokenType type) {
    if (!_check(type)) {
      return false;
    }
    _advance();
    return true;
  }

  BdfdToken _advance() {
    if (!_isAtEnd) {
      _index += 1;
    }
    return tokens[_index - 1];
  }
}
