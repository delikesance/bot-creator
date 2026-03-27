import 'package:bot_creator/routes/app/builder/action_type_extension.dart';
import 'package:bot_creator/routes/app/builder/action_types.dart';
import 'package:bot_creator/types/action.dart';
import 'package:flutter_test/flutter_test.dart';

ParameterDefinition _findByKey(List<ParameterDefinition> defs, String key) {
  return defs.firstWhere(
    (def) => def.key == key,
    orElse: () => throw StateError('Missing parameter definition: $key'),
  );
}

void main() {
  group('action parameter definitions', () {
    test('editMessage exposes editable embeds and clearEmbeds', () {
      final defs = BotCreatorActionType.editMessage.parameterDefinitions;

      expect(_findByKey(defs, 'embeds').type, ParameterType.embeds);
      expect(_findByKey(defs, 'clearEmbeds').type, ParameterType.boolean);
      expect(_findByKey(defs, 'clearEmbeds').defaultValue, isFalse);
    });

    test('editInteractionMessage exposes editable embeds and clearEmbeds', () {
      final defs =
          BotCreatorActionType.editInteractionMessage.parameterDefinitions;

      expect(_findByKey(defs, 'embeds').type, ParameterType.embeds);
      expect(_findByKey(defs, 'clearEmbeds').type, ParameterType.boolean);
      expect(_findByKey(defs, 'clearEmbeds').defaultValue, isFalse);
    });

    test(
      'setScopedVariable value fields are conditionally visible by valueType',
      () {
        final defs =
            BotCreatorActionType.setScopedVariable.parameterDefinitions;
        expect(
          _findByKey(defs, 'value').visibleWhen?['valueType'],
          equals(<String>['string']),
        );
        expect(
          _findByKey(defs, 'numberValue').visibleWhen?['valueType'],
          equals(<String>['number']),
        );
        expect(
          _findByKey(defs, 'boolValue').visibleWhen?['valueType'],
          equals(<String>['boolean']),
        );
        expect(
          _findByKey(defs, 'jsonValue').visibleWhen?['valueType'],
          equals(<String>['json']),
        );
      },
    );

    test('createInvite channelId is optional to allow runtime fallback', () {
      final defs = BotCreatorActionType.createInvite.parameterDefinitions;
      expect(_findByKey(defs, 'channelId').required, isFalse);
    });
  });
}
