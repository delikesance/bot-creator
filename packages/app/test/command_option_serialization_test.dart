import 'package:bot_creator/routes/app/command_option_serialization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxx/nyxx.dart';

void main() {
  group('command option serialization', () {
    test('serializes and deserializes nested subcommand tree', () {
      final option = CommandOptionBuilder(
          type: CommandOptionType.subCommandGroup,
          name: 'admin',
          description: 'Admin tools',
          isRequired: false,
        )
        ..options = <CommandOptionBuilder>[
          CommandOptionBuilder(
              type: CommandOptionType.subCommand,
              name: 'ban',
              description: 'Ban a member',
              isRequired: false,
            )
            ..options = <CommandOptionBuilder>[
              CommandOptionBuilder(
                type: CommandOptionType.user,
                name: 'target',
                description: 'Target user',
                isRequired: true,
              ),
              CommandOptionBuilder(
                  type: CommandOptionType.integer,
                  name: 'days',
                  description: 'Delete days',
                  isRequired: false,
                  minValue: 0,
                  maxValue: 7,
                )
                ..choices = <CommandOptionChoiceBuilder>[
                  CommandOptionChoiceBuilder(name: 'One', value: 1),
                  CommandOptionChoiceBuilder(name: 'Seven', value: 7),
                ],
            ],
        ];

      final serialized = serializeCommandOption(option);
      final deserialized = deserializeCommandOption(serialized);

      expect(serialized['type'], 'subCommandGroup');
      expect((serialized['options'] as List).length, 1);

      expect(deserialized.type, CommandOptionType.subCommandGroup);
      expect(deserialized.name, 'admin');
      expect(deserialized.options, isNotNull);
      expect(deserialized.options!.length, 1);

      final subcommand = deserialized.options!.first;
      expect(subcommand.type, CommandOptionType.subCommand);
      expect(subcommand.name, 'ban');
      expect(subcommand.options, isNotNull);
      expect(subcommand.options!.length, 2);

      final integerOption = subcommand.options![1];
      expect(integerOption.type, CommandOptionType.integer);
      expect(integerOption.minValue, 0);
      expect(integerOption.maxValue, 7);
      expect(integerOption.choices, isNotNull);
      expect(integerOption.choices!.map((choice) => choice.value), <Object?>[
        1,
        7,
      ]);
    });

    test('serializes and deserializes option list recursively', () {
      final options = <CommandOptionBuilder>[
        CommandOptionBuilder(
            type: CommandOptionType.subCommand,
            name: 'ping',
            description: 'Ping route',
            isRequired: false,
          )
          ..options = <CommandOptionBuilder>[
            CommandOptionBuilder(
              type: CommandOptionType.string,
              name: 'message',
              description: 'Reply message',
              isRequired: false,
            ),
          ],
      ];

      final serialized = serializeCommandOptions(options);
      final deserialized = deserializeCommandOptions(serialized);

      expect(deserialized.length, 1);
      expect(deserialized.first.type, CommandOptionType.subCommand);
      expect(deserialized.first.options, isNotNull);
      expect(deserialized.first.options!.single.name, 'message');
    });

    test('clones subcommand workflow payloads deeply', () {
      final original = <String, Map<String, dynamic>>{
        'admin/ban': <String, dynamic>{
          'response': <String, dynamic>{'type': 'normal', 'text': 'done'},
          'actions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'logAction',
              'payload': <String, dynamic>{'key': 'value'},
            },
          ],
        },
      };

      final cloned = cloneSubcommandWorkflowPayloads(original);
      final clonedRoute = Map<String, dynamic>.from(cloned['admin/ban'] as Map);
      final clonedResponse = Map<String, dynamic>.from(
        clonedRoute['response'] as Map,
      );

      clonedResponse['text'] = 'mutated';

      expect(
        (original['admin/ban']!['response'] as Map<String, dynamic>)['text'],
        'done',
      );
    });
  });
}
