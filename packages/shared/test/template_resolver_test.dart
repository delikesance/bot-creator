import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('resolveTemplatePlaceholders', () {
    test(
      'resolves direct keys case-insensitively with exact-match priority',
      () {
        final resolved = resolveTemplatePlaceholders('Hello ((UserName))', {
          'UserName': 'Jeremy',
          'username': 'Fallback',
        });

        expect(resolved, 'Hello Jeremy');
      },
    );

    test(
      'resolves JSON-path placeholders with case-insensitive source lookup',
      () {
        final resolved = resolveTemplatePlaceholders(
          r'Count: ((MyHttp.Body.$.items[0].count))',
          <String, String>{'myHttp.body': '{"items":[{"count":3}]}'},
        );

        expect(resolved, 'Count: 3');
      },
    );

    test(
      'keeps fallback at top level without splitting function arguments',
      () {
        final resolved = resolveTemplatePlaceholders(
          'Players: ((join(scores.\$, "|")|fallback))',
          <String, String>{'scores': '["Alice","Bob"]', 'fallback': 'nobody'},
        );

        expect(resolved, 'Players: Alice|Bob');
      },
    );

    test('serializes slice results back to JSON text', () {
      final resolved = resolveTemplatePlaceholders(
        'Slice: ((slice(scores.\$, 1, 3)))',
        <String, String>{'scores': '["A","B","C","D"]'},
      );

      expect(resolved, 'Slice: ["B","C"]');
    });

    test('formats array items with nested object placeholders', () {
      final resolved = resolveTemplatePlaceholders(
        'Rows: ((formatEach(scores.\$, "{profile.name}:{score}", ", ")))',
        <String, String>{
          'scores':
              '[{"profile":{"name":"Alice"},"score":7},{"profile":{"name":"Bob"},"score":12}]',
        },
      );

      expect(resolved, 'Rows: Alice:7, Bob:12');
    });

    test('returns empty string for invalid JSON paths or missing values', () {
      final resolved = resolveTemplatePlaceholders(
        'Value=((payload.\$.items[99].name))',
        <String, String>{'payload': '{"items":[{"name":"Alpha"}]}'},
      );

      expect(resolved, 'Value=');
    });
  });

  group('resolveTemplateExpressionValue', () {
    test('supports length and at helpers for arrays', () {
      expect(
        resolveTemplateExpressionValue('length(scores.\$)', <String, String>{
          'scores': '[3,5,8]',
        }),
        3,
      );

      expect(
        resolveTemplateExpressionValue('at(scores.\$, 1)', <String, String>{
          'scores': '[3,5,8]',
        }),
        5,
      );
    });

    test('builds embed field payloads from object arrays', () {
      final resolved = resolveTemplateExpressionValue(
        'embedFields(scores.\$, "{name}", "{score}", true)',
        <String, String>{
          'scores': '[{"name":"Alice","score":7},{"name":"Bob","score":12}]',
        },
      );

      expect(resolved, <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Alice', 'value': '7', 'inline': true},
        <String, dynamic>{'name': 'Bob', 'value': '12', 'inline': true},
      ]);
    });
  });
}
