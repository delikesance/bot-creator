import 'dart:convert';

import 'package:bot_creator/utils/normalize_command_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: simulate save-then-reload by JSON round-tripping.
Map<String, dynamic> roundTrip(Map<String, dynamic> input) {
  final normalized = normalizeCommandData(input);
  return Map<String, dynamic>.from(
    (jsonDecode(jsonEncode(normalized)) as Map).cast<String, dynamic>(),
  );
}

Map<String, dynamic> _makeCommand({
  Map<String, dynamic>? data,
  String type = 'chatInput',
}) {
  return {'name': 'ticket', 'type': type, 'data': data ?? {}};
}

Map<String, dynamic> _routePayload(String text) {
  return {
    'response': {
      'mode': 'text',
      'text': text,
      'type': 'normal',
      'embed': {'title': '', 'description': '', 'url': ''},
      'embeds': [],
    },
    'actions': [],
  };
}

void main() {
  group('normalizeCommandData – subcommandWorkflows preservation', () {
    test('preserves subcommandWorkflows through normalization', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': 'global', 'type': 'normal'},
          'subcommandWorkflows': {
            'config/status': _routePayload('STATUS CHANNEL'),
            'config/logchannel': _routePayload('LOG CHANNEL'),
          },
          'activeSubcommandRoute': 'config/status',
        },
      );

      final result = normalizeCommandData(command);
      final data = result['data'] as Map<String, dynamic>;

      expect(data.containsKey('subcommandWorkflows'), isTrue);
      final workflows = data['subcommandWorkflows'] as Map<String, dynamic>;
      expect(
        workflows.keys,
        containsAll(['config/status', 'config/logchannel']),
      );
    });

    test('preserves subcommandWorkflows through JSON round-trip', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': 'global', 'type': 'normal'},
          'subcommandWorkflows': {
            'config/status': _routePayload('STATUS CHANNEL'),
            'config/logchannel': _routePayload('LOG CHANNEL !'),
          },
          'activeSubcommandRoute': 'config/logchannel',
        },
      );

      final reloaded = roundTrip(command);
      final data = reloaded['data'] as Map<String, dynamic>;
      final workflows = data['subcommandWorkflows'] as Map<String, dynamic>;

      expect(workflows.length, 2);
      final statusPayload = workflows['config/status'] as Map<String, dynamic>;
      final logPayload = workflows['config/logchannel'] as Map<String, dynamic>;

      expect((statusPayload['response'] as Map)['text'], 'STATUS CHANNEL');
      expect((logPayload['response'] as Map)['text'], 'LOG CHANNEL !');
    });

    test('per-route payloads are independent – no cross-contamination', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': 'fallback', 'type': 'normal'},
          'subcommandWorkflows': {
            'route/a': _routePayload('AAA'),
            'route/b': _routePayload('BBB'),
          },
          'activeSubcommandRoute': 'route/a',
        },
      );

      final result = normalizeCommandData(command);
      final workflows =
          result['data']['subcommandWorkflows'] as Map<String, dynamic>;

      // Mutate route/a payload in the result
      (workflows['route/a'] as Map)['response']['text'] = 'MUTATED';

      // route/b must be unaffected
      expect((workflows['route/b'] as Map)['response']['text'], 'BBB');
    });
  });

  group('normalizeCommandData – activeSubcommandRoute', () {
    test('keeps activeSubcommandRoute when it exists in workflows', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': '', 'type': 'normal'},
          'subcommandWorkflows': {
            'config/status': _routePayload('S'),
            'config/logchannel': _routePayload('L'),
          },
          'activeSubcommandRoute': 'config/logchannel',
        },
      );

      final result = normalizeCommandData(command);
      expect(result['data']['activeSubcommandRoute'], 'config/logchannel');
    });

    test('falls back to first route when activeSubcommandRoute is invalid', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': '', 'type': 'normal'},
          'subcommandWorkflows': {
            'config/status': _routePayload('S'),
            'config/logchannel': _routePayload('L'),
          },
          'activeSubcommandRoute': 'config/nonexistent',
        },
      );

      final result = normalizeCommandData(command);
      // Should fall back to first key
      expect(result['data']['activeSubcommandRoute'], 'config/status');
    });

    test('falls back to first route when activeSubcommandRoute is missing', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': '', 'type': 'normal'},
          'subcommandWorkflows': {'help': _routePayload('HELP')},
        },
      );

      final result = normalizeCommandData(command);
      expect(result['data']['activeSubcommandRoute'], 'help');
    });

    test('empty string when no subcommandWorkflows exist', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': '', 'type': 'normal'},
        },
      );

      final result = normalizeCommandData(command);
      expect(result['data'].containsKey('activeSubcommandRoute'), isFalse);
    });
  });

  group('normalizeCommandData – edge cases for subcommandWorkflows', () {
    test('filters out empty route keys', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': '', 'type': 'normal'},
          'subcommandWorkflows': {
            '': _routePayload('EMPTY'),
            '  ': _routePayload('WHITESPACE'),
            'valid/route': _routePayload('OK'),
          },
          'activeSubcommandRoute': 'valid/route',
        },
      );

      final result = normalizeCommandData(command);
      final workflows =
          result['data']['subcommandWorkflows'] as Map<String, dynamic>;
      expect(workflows.length, 1);
      expect(workflows.containsKey('valid/route'), isTrue);
    });

    test('skips non-Map payloads in subcommandWorkflows', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': '', 'type': 'normal'},
          'subcommandWorkflows': {
            'good': _routePayload('OK'),
            'bad_string': 'not a map',
            'bad_number': 42,
            'bad_null': null,
          },
          'activeSubcommandRoute': 'good',
        },
      );

      final result = normalizeCommandData(command);
      final workflows =
          result['data']['subcommandWorkflows'] as Map<String, dynamic>;
      expect(workflows.length, 1);
      expect(workflows.containsKey('good'), isTrue);
    });

    test('deep cloning – mutation of original does not affect normalized', () {
      final originalPayload = _routePayload('ORIGINAL');
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': '', 'type': 'normal'},
          'subcommandWorkflows': {'route': originalPayload},
          'activeSubcommandRoute': 'route',
        },
      );

      final result = normalizeCommandData(command);

      // Mutate original input
      (originalPayload['response'] as Map)['text'] = 'MUTATED';

      // Normalized result must be unaffected
      final workflows =
          result['data']['subcommandWorkflows'] as Map<String, dynamic>;
      final routePayload = workflows['route'] as Map<String, dynamic>;
      expect((routePayload['response'] as Map)['text'], 'ORIGINAL');
    });

    test('no subcommandWorkflows key when map is empty after filtering', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': '', 'type': 'normal'},
          'subcommandWorkflows': {'': _routePayload('EMPTY')},
        },
      );

      final result = normalizeCommandData(command);
      expect(result['data'].containsKey('subcommandWorkflows'), isFalse);
      expect(result['data'].containsKey('activeSubcommandRoute'), isFalse);
    });
  });

  group('normalizeCommandData – legacy data without subcommandWorkflows', () {
    test('normalizes legacy command without subcommandWorkflows', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': 'Hello World', 'type': 'normal'},
          'actions': [
            {'type': 'reply', 'value': 'Hi'},
          ],
        },
      );

      final result = normalizeCommandData(command);
      final data = result['data'] as Map<String, dynamic>;

      expect(data['response']['text'], 'Hello World');
      expect(data.containsKey('subcommandWorkflows'), isFalse);
      expect((data['actions'] as List).length, 1);
    });

    test('normalizes legacy string response', () {
      final command = _makeCommand(data: {'response': 'plain text response'});

      final result = normalizeCommandData(command);
      expect(result['data']['response']['text'], 'plain text response');
      expect(result['data']['response']['mode'], 'text');
    });

    test('normalizes command with no data at all', () {
      final command = {'name': 'test'};

      final result = normalizeCommandData(command);
      expect(result['data'], isA<Map>());
      expect(result['data']['response']['text'], '');
      expect(result['type'], 'chatInput');
    });
  });

  group('normalizeCommandData – command types', () {
    test('recognizes user command type', () {
      final command = _makeCommand(data: {'commandType': 'user_command'});
      expect(normalizeCommandData(command)['type'], 'user');
    });

    test('recognizes message command type', () {
      final command = _makeCommand(data: {'commandType': 'messageCommand'});
      expect(normalizeCommandData(command)['type'], 'message');
    });

    test('defaults unknown type to chatInput', () {
      final command = _makeCommand(data: {'commandType': 'unknownType'});
      expect(normalizeCommandData(command)['type'], 'chatInput');
    });
  });

  group('normalizeCommandData – embeds', () {
    test('migrates legacy single embed into embeds list', () {
      final command = _makeCommand(
        data: {
          'response': {
            'mode': 'text',
            'text': '',
            'type': 'normal',
            'embed': {'title': 'My Title', 'description': 'Desc', 'url': ''},
            'embeds': [],
          },
        },
      );

      final result = normalizeCommandData(command);
      final embeds = result['data']['response']['embeds'] as List;
      expect(embeds.length, 1);
      expect(embeds[0]['title'], 'My Title');
      expect(result['data']['response']['mode'], 'embed');
    });

    test('limits embeds to 10', () {
      final command = _makeCommand(
        data: {
          'response': {
            'mode': 'embed',
            'text': '',
            'type': 'normal',
            'embeds': List.generate(
              15,
              (i) => {'title': 'Embed $i', 'description': '', 'url': ''},
            ),
          },
        },
      );

      final result = normalizeCommandData(command);
      final embeds = result['data']['response']['embeds'] as List;
      expect(embeds.length, 10);
    });
  });

  group('normalizeCommandData – options preservation', () {
    test('preserves serialized options including autocomplete metadata', () {
      final command = _makeCommand(
        data: {
          'options': [
            {
              'type': 'string',
              'name': 'country',
              'description': 'Country',
              'required': false,
              'autocomplete': {
                'enabled': true,
                'workflow': 'country_search',
                'entryPoint': 'main',
                'arguments': {'dataset': 'countries'},
              },
            },
            {
              'type': 'integer',
              'name': 'limit',
              'description': 'Limit',
              'required': false,
              'choices': [
                {'name': 'Five', 'value': 5},
              ],
            },
          ],
        },
      );

      final result = normalizeCommandData(command);
      final options = result['data']['options'] as List<dynamic>;

      expect(options.length, 2);
      expect(options.first, <String, dynamic>{
        'type': 'string',
        'name': 'country',
        'description': 'Country',
        'required': false,
        'autocomplete': {
          'enabled': true,
          'workflow': 'country_search',
          'entryPoint': 'main',
          'arguments': {'dataset': 'countries'},
        },
      });
      expect((options.last as Map<String, dynamic>)['choices'], [
        {'name': 'Five', 'value': 5},
      ]);
    });

    test('preserves expanded simple mode config fields', () {
      final command = _makeCommand(
        data: {
          'editorMode': 'simple',
          'simpleConfig': {
            'deleteMessages': true,
            'unbanUser': true,
            'unmuteUser': true,
            'pinMessage': true,
            'createInvite': true,
            'createPoll': true,
            'actionReason': 'Routine moderation',
            'deleteMessagesDefaultCount': '25',
            'muteDuration': '2h',
            'banDeleteMessageDays': '3',
            'inviteMaxAge': '3600',
            'inviteMaxUses': '5',
            'inviteTemporary': true,
            'inviteUnique': true,
            'pollAnswersText': 'Yes\nNo\nMaybe',
            'pollDurationHours': '12',
            'pollAllowMultiselect': true,
          },
        },
      );

      final result = normalizeCommandData(command);
      final simpleConfig = Map<String, dynamic>.from(
        result['data']['simpleConfig'] as Map,
      );

      expect(simpleConfig['deleteMessages'], isTrue);
      expect(simpleConfig['unbanUser'], isTrue);
      expect(simpleConfig['unmuteUser'], isTrue);
      expect(simpleConfig['pinMessage'], isTrue);
      expect(simpleConfig['createInvite'], isTrue);
      expect(simpleConfig['createPoll'], isTrue);
      expect(simpleConfig['actionReason'], 'Routine moderation');
      expect(simpleConfig['deleteMessagesDefaultCount'], '25');
      expect(simpleConfig['muteDuration'], '2h');
      expect(simpleConfig['banDeleteMessageDays'], '3');
      expect(simpleConfig['inviteMaxAge'], '3600');
      expect(simpleConfig['inviteMaxUses'], '5');
      expect(simpleConfig['inviteTemporary'], isTrue);
      expect(simpleConfig['inviteUnique'], isTrue);
      expect(simpleConfig['pollAnswersText'], 'Yes\nNo\nMaybe');
      expect(simpleConfig['pollDurationHours'], '12');
      expect(simpleConfig['pollAllowMultiselect'], isTrue);
    });
  });

  group('normalizeCommandData – legacy command fields', () {
    test('preserves legacy command mode fields', () {
      final command = _makeCommand(
        data: {
          'legacyModeEnabled': true,
          'legacyPrefixOverride': '((guild.bc_prefix | !))',
          'legacyResponseTarget': 'channelSend',
        },
      );

      final result = normalizeCommandData(command);
      final data = Map<String, dynamic>.from(result['data'] as Map);

      expect(data['legacyModeEnabled'], isTrue);
      expect(data['legacyPrefixOverride'], '((guild.bc_prefix | !))');
      expect(data['legacyResponseTarget'], 'channelSend');
    });

    test('defaults legacy response target to reply', () {
      final command = _makeCommand(data: {'legacyModeEnabled': true});

      final result = normalizeCommandData(command);
      final data = Map<String, dynamic>.from(result['data'] as Map);
      expect(data['legacyResponseTarget'], 'reply');
    });
  });

  group('normalizeCommandData – idempotency', () {
    test('double normalization produces identical output', () {
      final command = _makeCommand(
        data: {
          'response': {'mode': 'text', 'text': 'stable', 'type': 'normal'},
          'subcommandWorkflows': {'config/status': _routePayload('STATUS')},
          'activeSubcommandRoute': 'config/status',
          'actions': [
            {'type': 'reply', 'value': 'done'},
          ],
        },
      );

      final first = normalizeCommandData(command);
      final second = normalizeCommandData(
        Map<String, dynamic>.from(
          (jsonDecode(jsonEncode(first)) as Map).cast<String, dynamic>(),
        ),
      );

      expect(jsonEncode(first), jsonEncode(second));
    });
  });
}
