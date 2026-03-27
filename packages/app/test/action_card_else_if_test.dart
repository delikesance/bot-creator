import 'package:bot_creator/routes/app/builder/action_card.dart';
import 'package:bot_creator/routes/app/builder/action_types.dart';
import 'package:bot_creator/types/action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildActionCardHarness({
  required ActionItem action,
  required List<VariableSuggestion> suggestions,
  Future<List<Map<String, dynamic>>?> Function(
    List<Map<String, dynamic>> current,
    List<VariableSuggestion> suggestions,
  )?
  onEditNestedActions,
}) {
  return MaterialApp(
    home: StatefulBuilder(
      builder: (context, setState) {
        return Scaffold(
          body: SingleChildScrollView(
            child: ActionCard(
              action: action,
              index: 0,
              totalCount: 1,
              actionKey: 'if_action',
              variableSuggestions: suggestions,
              emojiSuggestions: null,
              fieldRefreshVersionOf: (_) => 0,
              onSuggestionSelected: (key, value) {
                setState(() {
                  action.parameters[key] = value;
                });
              },
              onRemove: () {},
              onParameterChanged: (key, value) {
                setState(() {
                  action.parameters[key] = value;
                });
              },
              onEditNestedActions: onEditNestedActions,
            ),
          ),
        );
      },
    ),
  );
}

Finder _textFieldWithin(Key key) {
  return find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextFormField),
  );
}

void main() {
  Finder nestedEditButtonForLabel(String label) {
    return find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Ink)).first,
      matching: find.text('Edit (0)'),
    );
  }

  group('ActionCard ELSE IF editor', () {
    testWidgets('adds, edits and removes ELSE IF branches', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final action = ActionItem(
        id: 'if_1',
        type: BotCreatorActionType.ifBlock,
        parameters: <String, dynamic>{
          'condition.variable': '((score))',
          'condition.operator': 'equals',
          'condition.value': '100',
          'thenActions': <Map<String, dynamic>>[],
          'elseIfConditions': <Map<String, dynamic>>[],
          'elseActions': <Map<String, dynamic>>[],
        },
      );

      await tester.pumpWidget(
        _buildActionCardHarness(
          action: action,
          suggestions: const <VariableSuggestion>[
            VariableSuggestion(
              name: 'score',
              kind: VariableSuggestionKind.numeric,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ELSE IF 1'), findsNothing);
      expect(action.parameters['elseIfConditions'], isEmpty);

      await tester.ensureVisible(find.text('Add ELSE IF'));
      await tester.tap(find.text('Add ELSE IF'));
      await tester.pumpAndSettle();

      expect(find.text('ELSE IF 1'), findsOneWidget);
      expect(action.parameters['elseIfConditions'], hasLength(1));
      expect(
        action.parameters['elseIfConditions'][0]['condition.operator'],
        'equals',
      );

      await tester.enterText(
        _textFieldWithin(const ValueKey('elseif-if_action-0-variable')),
        '((score))',
      );
      await tester.pump();

      await tester.enterText(
        _textFieldWithin(const ValueKey('elseif-if_action-0-value')),
        '75',
      );
      await tester.pump();

      expect(
        action.parameters['elseIfConditions'][0]['condition.variable'],
        '((score))',
      );
      expect(action.parameters['elseIfConditions'][0]['condition.value'], '75');

      await tester.ensureVisible(find.byTooltip('Remove ELSE IF'));
      await tester.tap(find.byTooltip('Remove ELSE IF'));
      await tester.pumpAndSettle();

      expect(find.text('ELSE IF 1'), findsNothing);
      expect(action.parameters['elseIfConditions'], isEmpty);
    });

    testWidgets('edits ELSE IF nested actions through callback', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final action = ActionItem(
        id: 'if_2',
        type: BotCreatorActionType.ifBlock,
        parameters: <String, dynamic>{
          'condition.variable': '((score))',
          'condition.operator': 'equals',
          'condition.value': '100',
          'thenActions': <Map<String, dynamic>>[],
          'elseIfConditions': <Map<String, dynamic>>[
            <String, dynamic>{
              'condition.variable': '((score))',
              'condition.operator': 'greaterThan',
              'condition.value': '75',
              'actions': <Map<String, dynamic>>[],
            },
          ],
          'elseActions': <Map<String, dynamic>>[],
        },
      );
      var callbackCalls = 0;

      await tester.pumpWidget(
        _buildActionCardHarness(
          action: action,
          suggestions: const <VariableSuggestion>[
            VariableSuggestion(
              name: 'score',
              kind: VariableSuggestionKind.numeric,
            ),
          ],
          onEditNestedActions: (current, suggestions) async {
            callbackCalls++;
            expect(current, isEmpty);
            expect(suggestions.map((item) => item.name), contains('score'));
            return <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'sendMessage',
                'payload': <String, dynamic>{'content': 'good enough'},
              },
            ];
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ELSE IF 1 — actions'), findsOneWidget);
      expect(find.text('No actions in this branch yet.'), findsWidgets);

      final nestedEditButton = nestedEditButtonForLabel('ELSE IF 1 — actions');
      await tester.ensureVisible(nestedEditButton);
      await tester.tap(nestedEditButton);
      await tester.pumpAndSettle();

      expect(callbackCalls, 1);
      expect(action.parameters['elseIfConditions'][0]['actions'], hasLength(1));
      expect(
        action.parameters['elseIfConditions'][0]['actions'][0]['type'],
        'sendMessage',
      );
      expect(find.text('Edit (1)'), findsOneWidget);
      expect(find.text('sendMessage'), findsOneWidget);
    });
  });
}
