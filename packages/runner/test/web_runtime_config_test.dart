import 'package:bot_creator_runner/web_runtime_config.dart';
import 'package:test/test.dart';

void main() {
  group('validateRunnerWebConfiguration', () {
    test('allows loopback host without an API token', () {
      expect(
        validateRunnerWebConfiguration(host: '127.0.0.1', apiToken: ''),
        isNull,
      );
      expect(
        validateRunnerWebConfiguration(host: 'localhost', apiToken: ''),
        isNull,
      );
      expect(
        validateRunnerWebConfiguration(host: '[::1]', apiToken: ''),
        isNull,
      );
    });

    test('rejects non-loopback host without an API token', () {
      expect(
        validateRunnerWebConfiguration(host: '0.0.0.0', apiToken: ''),
        isNotNull,
      );
    });
  });
}
