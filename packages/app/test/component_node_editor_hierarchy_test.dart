import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_node_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a [ComponentNodeEditor] in a minimal [MaterialApp] for widget tests.
Widget _buildEditor({
  required ComponentNode node,
  int depth = 0,
  VoidCallback? onMoveUp,
  VoidCallback? onMoveDown,
  ValueChanged<ComponentNode>? onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ComponentNodeEditor(
          node: node,
          depth: depth,
          onChanged: onChanged ?? (_) {},
          onRemove: () {},
          onMoveUp: onMoveUp,
          onMoveDown: onMoveDown,
          variableSuggestions: const <VariableSuggestion>[],
        ),
      ),
    ),
  );
}

void main() {
  group('ComponentNodeEditor – nesting depth visual indicator', () {
    testWidgets('root node (depth 0) does NOT show depth badge', (
      tester,
    ) async {
      await tester.pumpWidget(_buildEditor(node: ButtonNode(), depth: 0));
      await tester.pumpAndSettle();

      // Badge shows 'L<depth>' for depth > 0; at depth 0 it should not appear.
      expect(find.text('L0'), findsNothing);
    });

    testWidgets('child node (depth 1) shows "L1" badge', (tester) async {
      await tester.pumpWidget(_buildEditor(node: ButtonNode(), depth: 1));
      await tester.pumpAndSettle();

      expect(find.text('L1'), findsOneWidget);
    });

    testWidgets('deeply nested node (depth 3) shows "L3" badge', (
      tester,
    ) async {
      await tester.pumpWidget(_buildEditor(node: TextDisplayNode(), depth: 3));
      await tester.pumpAndSettle();

      expect(find.text('L3'), findsOneWidget);
    });
  });

  group('ComponentNodeEditor – move up/down controls', () {
    testWidgets('no move controls shown when callbacks are null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEditor(node: ButtonNode(), onMoveUp: null, onMoveDown: null),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Move up'), findsNothing);
      expect(find.byTooltip('Move down'), findsNothing);
    });

    testWidgets('move-up arrow shown when onMoveUp is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEditor(node: ButtonNode(), onMoveUp: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Move up'), findsOneWidget);
    });

    testWidgets('move-down arrow shown when onMoveDown is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEditor(node: ButtonNode(), onMoveDown: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Move down'), findsOneWidget);
    });

    testWidgets('tapping move-up calls the callback', (tester) async {
      int called = 0;
      await tester.pumpWidget(
        _buildEditor(node: ButtonNode(), onMoveUp: () => called++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Move up'));
      await tester.pumpAndSettle();

      expect(called, 1);
    });

    testWidgets('tapping move-down calls the callback', (tester) async {
      int called = 0;
      await tester.pumpWidget(
        _buildEditor(node: ButtonNode(), onMoveDown: () => called++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Move down'));
      await tester.pumpAndSettle();

      expect(called, 1);
    });

    testWidgets('both move controls shown when both callbacks are provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEditor(
          node: ButtonNode(),
          onMoveUp: () {},
          onMoveDown: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Move up'), findsOneWidget);
      expect(find.byTooltip('Move down'), findsOneWidget);
    });
  });

  group('ComponentNodeEditor – ActionRow child ordering', () {
    testWidgets(
      'ActionRow with two children shows move-down on first, move-up on second',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final row = ActionRowNode();
        row.components = [ButtonNode(), ButtonNode()];
        ComponentNode currentNode = row;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return ComponentNodeEditor(
                      node: currentNode,
                      depth: 0,
                      onChanged: (n) => setState(() => currentNode = n),
                      onRemove: () {},
                      variableSuggestions: const [],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // First child (depth 1): no move-up, has move-down.
        // Second child (depth 1): has move-up, no move-down.
        // (Two depth badges 'L1' should exist, one for each child.)
        expect(find.text('L1'), findsNWidgets(2));

        // There should be one move-down (for the first child) and one move-up
        // (for the second child), but not two of each.
        expect(find.byTooltip('Move down'), findsOneWidget);
        expect(find.byTooltip('Move up'), findsOneWidget);
      },
    );
  });

  group('ComponentNodeEditor – remove tooltip', () {
    testWidgets('remove button has "Remove" tooltip', (tester) async {
      await tester.pumpWidget(_buildEditor(node: ButtonNode()));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Remove'), findsOneWidget);
    });
  });
}
