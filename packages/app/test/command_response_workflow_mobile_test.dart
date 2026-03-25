import 'package:bot_creator/routes/app/command.response_workflow.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildPage() {
    return const MaterialApp(
      home: CommandResponseWorkflowPage(
        initialWorkflow: <String, dynamic>{
          'conditional': <String, dynamic>{
            'whenTrueType': 'componentV2',
            'whenFalseType': 'componentV2',
          },
        },
        variableSuggestions: <VariableSuggestion>[],
      ),
    );
  }

  testWidgets('uses compact save action on small screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Save'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses text save action on wider screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOneWidget);
    expect(find.byTooltip('Save'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
