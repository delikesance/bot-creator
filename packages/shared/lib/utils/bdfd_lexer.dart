enum BdfdTokenType { text, function, openBracket, closeBracket, semicolon, eof }

class BdfdToken {
  const BdfdToken({
    required this.type,
    required this.lexeme,
    required this.start,
    required this.end,
    required this.line,
    required this.column,
  });

  final BdfdTokenType type;
  final String lexeme;
  final int start;
  final int end;
  final int line;
  final int column;

  @override
  String toString() {
    return 'BdfdToken(type: $type, lexeme: $lexeme, start: $start, end: $end, line: $line, column: $column)';
  }
}

class BdfdLexerDiagnostic {
  const BdfdLexerDiagnostic({
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

  @override
  String toString() {
    return 'BdfdLexerDiagnostic(message: $message, start: $start, end: $end, line: $line, column: $column)';
  }
}

class BdfdLexerResult {
  const BdfdLexerResult({required this.tokens, required this.diagnostics});

  final List<BdfdToken> tokens;
  final List<BdfdLexerDiagnostic> diagnostics;

  bool get hasErrors => diagnostics.isNotEmpty;
}

class BdfdLexer {
  BdfdLexerResult tokenize(String source) {
    final scanner = _BdfdScanner(source);
    return scanner.scan();
  }
}

class _BdfdScanner {
  _BdfdScanner(this.source);

  final String source;
  final List<BdfdToken> _tokens = <BdfdToken>[];
  final List<BdfdLexerDiagnostic> _diagnostics = <BdfdLexerDiagnostic>[];
  final List<_BdfdBracketFrame> _bracketStack = <_BdfdBracketFrame>[];

  int _index = 0;
  int _line = 1;
  int _column = 1;
  bool _mayOpenArgumentList = false;

  BdfdLexerResult scan() {
    while (!_isAtEnd) {
      final char = _peek();

      if (_isFunctionStart()) {
        _scanFunction();
        continue;
      }

      if (char == '[' && _mayOpenArgumentList) {
        _scanOpenBracket();
        continue;
      }

      if (char == ']') {
        _scanCloseBracket();
        continue;
      }

      if (char == ';' && _bracketStack.isNotEmpty) {
        _scanSemicolon();
        continue;
      }

      _scanText();
    }

    for (final frame in _bracketStack) {
      _diagnostics.add(
        BdfdLexerDiagnostic(
          message: 'Unclosed bracket for function ${frame.functionLexeme}.',
          start: frame.start,
          end: frame.end,
          line: frame.line,
          column: frame.column,
        ),
      );
    }

    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.eof,
        lexeme: '',
        start: _index,
        end: _index,
        line: _line,
        column: _column,
      ),
    );

    return BdfdLexerResult(
      tokens: List<BdfdToken>.unmodifiable(_tokens),
      diagnostics: List<BdfdLexerDiagnostic>.unmodifiable(_diagnostics),
    );
  }

  bool get _isAtEnd => _index >= source.length;

  String _peek() => source[_index];

  String _peekNext() => (_index + 1) < source.length ? source[_index + 1] : '';

  bool _isFunctionStart() {
    if (_isAtEnd || _peek() != r'$') {
      return false;
    }
    final next = _peekNext();
    return _isIdentifierStart(next);
  }

  bool _isIdentifierStart(String value) {
    if (value.isEmpty) {
      return false;
    }
    final codeUnit = value.codeUnitAt(0);
    return (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        value == '_';
  }

  bool _isIdentifierPart(String value) {
    if (value.isEmpty) {
      return false;
    }
    final codeUnit = value.codeUnitAt(0);
    return _isIdentifierStart(value) || (codeUnit >= 48 && codeUnit <= 57);
  }

  String _advance() {
    final char = source[_index];
    _index += 1;
    if (char == '\n') {
      _line += 1;
      _column = 1;
    } else {
      _column += 1;
    }
    return char;
  }

  void _scanFunction() {
    final start = _index;
    final line = _line;
    final column = _column;
    final buffer = StringBuffer();

    buffer.write(_advance());
    while (!_isAtEnd && _isIdentifierPart(_peek())) {
      buffer.write(_advance());
    }

    final lexeme = buffer.toString();
    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.function,
        lexeme: lexeme,
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
    _mayOpenArgumentList = true;
  }

  void _scanOpenBracket() {
    final start = _index;
    final line = _line;
    final column = _column;
    _advance();
    final previousFunction =
        _tokens.isNotEmpty ? _tokens.last.lexeme : r'$unknown';
    _bracketStack.add(
      _BdfdBracketFrame(
        functionLexeme: previousFunction,
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.openBracket,
        lexeme: '[',
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
    _mayOpenArgumentList = false;
  }

  void _scanCloseBracket() {
    final start = _index;
    final line = _line;
    final column = _column;
    _advance();

    if (_bracketStack.isEmpty) {
      _diagnostics.add(
        BdfdLexerDiagnostic(
          message: 'Unexpected closing bracket.',
          start: start,
          end: _index,
          line: line,
          column: column,
        ),
      );
    } else {
      _bracketStack.removeLast();
    }

    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.closeBracket,
        lexeme: ']',
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
    _mayOpenArgumentList = false;
  }

  void _scanSemicolon() {
    final start = _index;
    final line = _line;
    final column = _column;
    _advance();
    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.semicolon,
        lexeme: ';',
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
    _mayOpenArgumentList = false;
  }

  void _scanText() {
    final start = _index;
    final line = _line;
    final column = _column;
    final buffer = StringBuffer();
    _mayOpenArgumentList = false;

    while (!_isAtEnd) {
      if (_isFunctionStart()) {
        break;
      }

      final char = _peek();
      if (char == ']' || (char == ';' && _bracketStack.isNotEmpty)) {
        break;
      }
      if (char == '[' && _mayOpenArgumentList) {
        break;
      }

      buffer.write(_advance());
    }

    if (buffer.isEmpty) {
      return;
    }

    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.text,
        lexeme: buffer.toString(),
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
  }
}

class _BdfdBracketFrame {
  const _BdfdBracketFrame({
    required this.functionLexeme,
    required this.start,
    required this.end,
    required this.line,
    required this.column,
  });

  final String functionLexeme;
  final int start;
  final int end;
  final int line;
  final int column;
}
