import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:test/test.dart';

void main() {
  test('BotConfig.fromJson preserves typed global and scoped variables', () {
    final config = BotConfig.fromJson(<String, dynamic>{
      'token': 'discord-token',
      'globalVariables': <String, dynamic>{
        'enabled': true,
        'count': 7,
        'meta': <String, dynamic>{'mode': 'strict'},
      },
      'scopedVariables': <String, dynamic>{
        'guild': <String, dynamic>{
          'guild-1': <String, dynamic>{'score': 9},
        },
        'user': <String, dynamic>{
          'user-1': <String, dynamic>{
            'prefs': <String, dynamic>{'lang': 'en'},
          },
        },
      },
    });

    expect(config.globalVariables['enabled'], isTrue);
    expect(config.globalVariables['count'], 7);
    expect(config.globalVariables['meta'], <String, dynamic>{'mode': 'strict'});
    expect(config.scopedVariables['guild']?['guild-1']?['score'], 9);
    expect(
      config.scopedVariables['user']?['user-1']?['prefs'],
      <String, dynamic>{'lang': 'en'},
    );
  });
}
