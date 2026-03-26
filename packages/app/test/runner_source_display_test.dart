import 'package:bot_creator/utils/runner_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Runner source display logic', () {
    test('RunnerConnectionConfig label prefers name over url', () {
      const withName = RunnerConnectionConfig(
        id: 'r1',
        url: 'https://runner.example.com',
        name: 'Production',
      );
      final label = withName.name ?? withName.url;
      expect(label, 'Production');
    });

    test('RunnerConnectionConfig label falls back to url', () {
      const withoutName = RunnerConnectionConfig(
        id: 'r2',
        url: 'https://runner.example.com',
      );
      final label = withoutName.name ?? withoutName.url;
      expect(label, 'https://runner.example.com');
    });

    test('multiple runners can be identified by id', () {
      final runners = [
        const RunnerConnectionConfig(
          id: 'r1',
          url: 'https://prod.example.com',
          name: 'Production',
        ),
        const RunnerConnectionConfig(
          id: 'r2',
          url: 'https://dev.example.com',
          name: 'Dev',
        ),
      ];

      final selectedId = 'r2';
      final active = runners.where((r) => r.id == selectedId).firstOrNull;
      expect(active, isNotNull);
      expect(active!.name, 'Dev');
    });

    test('firstOrNull returns null for unknown id', () {
      final runners = [
        const RunnerConnectionConfig(id: 'r1', url: 'https://a.com'),
      ];

      final active = runners.where((r) => r.id == 'unknown').firstOrNull;
      expect(active, isNull);
    });

    test('createClient produces a client from config', () {
      const config = RunnerConnectionConfig(
        id: 'r1',
        url: 'https://runner.example.com',
        apiToken: 'tok',
      );
      final client = config.createClient();
      expect(client, isNotNull);
    });
  });
}
