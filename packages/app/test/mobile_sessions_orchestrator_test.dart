import 'package:bot_creator/utils/mobile_sessions_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileSessionsOrchestrator', () {
    test('serializes concurrent operations in call order', () async {
      final orchestrator = MobileSessionsOrchestrator();
      final events = <String>[];

      Future<void> op(String label, int delayMs) async {
        await orchestrator.runSerialized(() async {
          events.add('start:$label');
          await Future<void>.delayed(Duration(milliseconds: delayMs));
          events.add('end:$label');
        });
      }

      await Future.wait<void>(<Future<void>>[
        op('A', 20),
        op('B', 5),
        op('C', 1),
      ]);

      expect(events, <String>[
        'start:A',
        'end:A',
        'start:B',
        'end:B',
        'start:C',
        'end:C',
      ]);
    });

    test('continues queue after an operation throws', () async {
      final orchestrator = MobileSessionsOrchestrator();
      final events = <String>[];

      await expectLater(
        orchestrator.runSerialized(() async {
          events.add('first');
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );

      await orchestrator.runSerialized(() async {
        events.add('second');
      });

      expect(events, <String>['first', 'second']);
    });
  });
}
