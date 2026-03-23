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
  });
}
