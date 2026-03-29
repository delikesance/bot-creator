import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdLexer', () {
    List<String> summarizeTokens(BdfdLexerResult result) {
      return result.tokens
          .map((token) => '${token.type.name}:${token.lexeme}')
          .toList(growable: false);
    }

    test('tokenizes plain text as a single text token', () {
      final result = BdfdLexer().tokenize('Hello from Bot Creator');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), ['text:Hello from Bot Creator', 'eof:']);
    });

    test('tokenizes standalone BDFD commands without arguments', () {
      final result = BdfdLexer().tokenize(r'$nomention Hello');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$nomention',
        'text: Hello',
        'eof:',
      ]);
    });

    test('tokenizes bracketed commands and separators', () {
      final result = BdfdLexer().tokenize(r'$description[Hello;World]');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$description',
        'openBracket:[',
        'text:Hello',
        'semicolon:;',
        'text:World',
        'closeBracket:]',
        'eof:',
      ]);
    });

    test('tokenizes nested functions inside arguments', () {
      final result = BdfdLexer().tokenize(
        r'$if[$hasPerms[$authorID;administrator]==true;yes;no]',
      );

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$if',
        'openBracket:[',
        r'function:$hasPerms',
        'openBracket:[',
        r'function:$authorID',
        'semicolon:;',
        'text:administrator',
        'closeBracket:]',
        'text:==true',
        'semicolon:;',
        'text:yes',
        'semicolon:;',
        'text:no',
        'closeBracket:]',
        'eof:',
      ]);
    });

    test('reports unexpected closing brackets', () {
      final result = BdfdLexer().tokenize('Hello ]');

      expect(summarizeTokens(result), [
        'text:Hello ',
        'closeBracket:]',
        'eof:',
      ]);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.first.message, 'Unexpected closing bracket.');
      expect(result.diagnostics.first.line, 1);
      expect(result.diagnostics.first.column, 7);
    });

    test('reports unclosed bracket diagnostics at the opening location', () {
      final result = BdfdLexer().tokenize(r'$title[Line 1');

      expect(result.hasErrors, isTrue);
      expect(result.diagnostics, hasLength(1));
      expect(
        result.diagnostics.first.message,
        r'Unclosed bracket for function $title.',
      );
      expect(result.diagnostics.first.column, 7);
    });

    test('tracks token line and column across multiline scripts', () {
      final result = BdfdLexer().tokenize('before\n\$title[after]');
      final functionToken = result.tokens.firstWhere(
        (token) => token.type == BdfdTokenType.function,
      );

      expect(functionToken.line, 2);
      expect(functionToken.column, 1);
    });
  });
}
