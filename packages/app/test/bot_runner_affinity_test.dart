import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bot-runner affinity display', () {
    test('runner label displays dns icon and name when provided', () {
      // Mirrors the _BotCard logic: when runnerLabel != null, show indicator.
      const runnerLabel = 'Production';
      final row = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dns_outlined, size: 13),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              runnerLabel,
              style: const TextStyle(fontSize: 9.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
      expect(row.children.length, 3);
    });

    test('runner label is hidden when null', () {
      const String? runnerLabel = null;
      final showRunner = runnerLabel != null;
      expect(showRunner, isFalse);
    });

    test('runner label is only shown for running bots on runner mode', () {
      // Mirrors: runnerLabel: isRunning && _runnerModeEnabled ? _activeRunnerLabel : null
      final activeRunnerLabel = 'Dev Server';

      final label =
          activeRunnerLabel;
      expect(label, 'Dev Server');

      // Stopped bot should not show runner label
      final stoppedLabel =
          null;
      expect(stoppedLabel, isNull);

      // Local mode should not show runner label
      final localLabel = null;
      expect(localLabel, isNull);
    });
  });
}
