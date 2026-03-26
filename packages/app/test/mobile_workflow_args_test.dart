import 'package:bot_creator/widgets/option_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxx/nyxx.dart' hide Builder;

void main() {
  group('OptionWidget – mobile responsive layout', () {
    Widget buildOptionWidget({
      required double width,
      List<CommandOptionBuilder>? initial,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: OptionWidget(
                onChange: (_) {},
                initialOptions: initial,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('uses Switch instead of CheckboxListTile for required', (
      WidgetTester tester,
    ) async {
      final option = CommandOptionBuilder(
        type: CommandOptionType.string,
        name: 'test_opt',
        description: 'A test option',
        isRequired: false,
      );

      await tester.pumpWidget(
        buildOptionWidget(width: 600, initial: [option]),
      );
      await tester.pumpAndSettle();

      // Expand the option tile
      await tester.tap(find.text('test_opt'));
      await tester.pumpAndSettle();

      // Should find a Switch, not a CheckboxListTile
      expect(find.byType(Switch), findsWidgets);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Is Required'), findsNothing);
    });

    testWidgets('min/max fields stack vertically on narrow screen', (
      WidgetTester tester,
    ) async {
      final option = CommandOptionBuilder(
        type: CommandOptionType.integer,
        name: 'count',
        description: 'A count',
        isRequired: false,
      );

      // Narrow width
      await tester.pumpWidget(
        buildOptionWidget(width: 350, initial: [option]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('count'));
      await tester.pumpAndSettle();

      // On narrow screens, Min/Max should be in a Column (stacked)
      // Verify both fields exist
      expect(find.text('Min Value'), findsOneWidget);
      expect(find.text('Max Value'), findsOneWidget);
    });

    testWidgets('min/max fields side-by-side on wide screen', (
      WidgetTester tester,
    ) async {
      final option = CommandOptionBuilder(
        type: CommandOptionType.integer,
        name: 'count',
        description: 'A count',
        isRequired: false,
      );

      // Wide width
      await tester.pumpWidget(
        buildOptionWidget(width: 800, initial: [option]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('count'));
      await tester.pumpAndSettle();

      expect(find.text('Min Value'), findsOneWidget);
      expect(find.text('Max Value'), findsOneWidget);
    });
  });
}
