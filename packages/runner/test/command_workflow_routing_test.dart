import 'package:bot_creator_runner/command_workflow_routing.dart';
import 'package:test/test.dart';

void main() {
  group('resolveSubcommandRoute', () {
    test('returns null when options are absent', () {
      expect(resolveSubcommandRoute(null), isNull);
      expect(resolveSubcommandRoute(const <dynamic>[]), isNull);
    });

    test('returns subcommand route for top-level subcommand', () {
      final options = <Map<String, dynamic>>[
        {
          'type': 'subCommand',
          'name': 'ban',
          'options': <Map<String, dynamic>>[
            {'type': 'user', 'name': 'target'},
          ],
        },
      ];

      expect(resolveSubcommandRoute(options), 'ban');
    });

    test('returns grouped route for subcommand group', () {
      final options = <Map<String, dynamic>>[
        {
          'type': 'subCommandGroup',
          'name': 'admin',
          'options': <Map<String, dynamic>>[
            {
              'type': 'subCommand',
              'name': 'kick',
              'options': <Map<String, dynamic>>[
                {'type': 'user', 'name': 'target'},
              ],
            },
          ],
        },
      ];

      expect(resolveSubcommandRoute(options), 'admin/kick');
    });

    test('supports enum-like type strings with prefixes', () {
      final options = <Map<String, dynamic>>[
        {
          'type': 'CommandOptionType.subCommandGroup',
          'name': 'ticket',
          'options': <Map<String, dynamic>>[
            {
              'type': 'ApplicationCommandOptionType.subCommand',
              'name': 'status',
            },
          ],
        },
      ];

      expect(resolveSubcommandRoute(options), 'ticket/status');
    });

    test('supports numeric Discord option type values', () {
      final options = <Map<String, dynamic>>[
        {
          'type': 2,
          'name': 'ticket',
          'options': <Map<String, dynamic>>[
            {'type': 1, 'name': 'logchannel'},
          ],
        },
      ];

      expect(resolveSubcommandRoute(options), 'ticket/logchannel');
    });

    test('ignores non-subcommand option trees', () {
      final options = <Map<String, dynamic>>[
        {'type': 'string', 'name': 'query'},
        {
          'type': 'subCommandGroup',
          'name': 'admin',
          'options': <Map<String, dynamic>>[
            {'type': 'string', 'name': 'query'},
          ],
        },
      ];

      expect(resolveSubcommandRoute(options), isNull);
    });
  });

  group('resolveSubcommandWorkflowPayload', () {
    test('returns payload for matching route', () {
      final commandValue = <String, dynamic>{
        'subcommandWorkflows': <String, dynamic>{
          'admin/kick': <String, dynamic>{
            'response': <String, dynamic>{'type': 'normal', 'text': 'kicked'},
            'actions': <Map<String, dynamic>>[
              <String, dynamic>{'type': 'logAction'},
            ],
          },
        },
      };

      final payload = resolveSubcommandWorkflowPayload(
        commandValue,
        'admin/kick',
      );

      expect(payload, isNotNull);
      expect(payload!['response'], isA<Map<String, dynamic>>());
      expect((payload['response'] as Map<String, dynamic>)['text'], 'kicked');
      expect(payload['actions'], isA<List<Map<String, dynamic>>>());
    });

    test('returns null when route is blank or missing', () {
      final commandValue = <String, dynamic>{
        'subcommandWorkflows': <String, dynamic>{
          'ban': <String, dynamic>{'response': <String, dynamic>{}},
        },
      };

      expect(resolveSubcommandWorkflowPayload(commandValue, ''), isNull);
      expect(resolveSubcommandWorkflowPayload(commandValue, 'kick'), isNull);
    });

    test('returns null when subcommandWorkflows is absent', () {
      final commandValue = <String, dynamic>{
        'response': <String, dynamic>{'text': 'legacy'},
      };

      expect(resolveSubcommandWorkflowPayload(commandValue, 'ban'), isNull);
    });
  });
}
