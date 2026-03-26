import 'package:bot_creator/routes/app/command.response_workflow.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildPage({Map<String, dynamic>? initialWorkflow}) {
    return MaterialApp(
      home: CommandResponseWorkflowPage(
        initialWorkflow: initialWorkflow ?? const <String, dynamic>{},
        variableSuggestions: const <VariableSuggestion>[],
      ),
    );
  }

  group('CommandResponseWorkflowPage – dirty state', () {
    testWidgets('title has no dirty indicator initially', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Response Workflow'), findsOneWidget);
      expect(find.text('Response Workflow •'), findsNothing);
    });

    testWidgets('toggling auto-defer marks page dirty', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Toggle the switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsWidgets);
      await tester.tap(switchFinder.first);
      await tester.pumpAndSettle();

      // Title should now show dirty indicator
      expect(find.text('Response Workflow •'), findsOneWidget);
      // Revert button should appear
      expect(find.byTooltip('Revert all changes'), findsOneWidget);
    });

    testWidgets('revert button restores initial state', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Toggle the switch to make dirty
      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder.first);
      await tester.pumpAndSettle();

      expect(find.text('Response Workflow •'), findsOneWidget);

      // Tap revert
      await tester.tap(find.byTooltip('Revert all changes'));
      await tester.pumpAndSettle();

      // Should be clean again
      expect(find.text('Response Workflow'), findsOneWidget);
      expect(find.text('Response Workflow •'), findsNothing);
      expect(find.byTooltip('Revert all changes'), findsNothing);
    });

    testWidgets('revert is not shown when state is clean', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Revert all changes'), findsNothing);
    });
  });

  group('CommandResponseWorkflowPage – discard confirmation', () {
    testWidgets('back on clean state pops without dialog', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CommandResponseWorkflowPage(
                        initialWorkflow: <String, dynamic>{},
                        variableSuggestions: <VariableSuggestion>[],
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // Tap the back button
      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // No dialog should appear — page should have popped
      expect(find.text('Unsaved changes'), findsNothing);
      // Should be back at the first page
      expect(find.text('Go'), findsOneWidget);
    });

    testWidgets('back on dirty state shows discard dialog', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Use a Navigator to be able to catch pop
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CommandResponseWorkflowPage(
                        initialWorkflow: <String, dynamic>{},
                        variableSuggestions: <VariableSuggestion>[],
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // Toggle the switch to make dirty
      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder.first);
      await tester.pumpAndSettle();

      // Tap the back button
      final backButton = find.byTooltip('Back');
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(find.text('Keep editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
    });
  });
}
