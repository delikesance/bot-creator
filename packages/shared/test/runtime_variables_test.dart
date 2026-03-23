import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:test/test.dart';

void main() {
  group('hydrateRuntimeVariables', () {
    test(
      'injects typed global and scoped variables with compatibility aliases',
      () async {
        final store = _FakeBotDataStore(
          globalVariables: <String, dynamic>{
            'enabled': true,
            'count': 3,
            'meta': <String, dynamic>{'mode': 'strict'},
          },
          scopedVariables: <String, Map<String, Map<String, dynamic>>>{
            'guild': <String, Map<String, dynamic>>{
              'guild-1': <String, dynamic>{'score': 9},
            },
            'channel': <String, Map<String, dynamic>>{
              'channel-1': <String, dynamic>{'topic': 'alerts'},
            },
            'user': <String, Map<String, dynamic>>{
              'user-1': <String, dynamic>{'locale': 'en'},
            },
            'guildMember': <String, Map<String, dynamic>>{
              'guild-1:user-1': <String, dynamic>{'rank': 'mod'},
            },
            'message': <String, Map<String, dynamic>>{
              'message-1': <String, dynamic>{'seen': false},
            },
          },
        );

        final runtimeVariables = <String, String>{};
        await hydrateRuntimeVariables(
          store: store,
          botId: 'bot-1',
          runtimeVariables: runtimeVariables,
          guildContextId: 'guild-1',
          channelContextId: 'channel-1',
          userContextId: 'user-1',
          messageContextId: 'message-1',
        );

        expect(runtimeVariables['global.enabled'], 'true');
        expect(runtimeVariables['global.count'], '3');
        expect(runtimeVariables['global.meta'], '{"mode":"strict"}');
        expect(runtimeVariables['guild.score'], '9');
        expect(runtimeVariables['guild.bc_score'], '9');
        expect(runtimeVariables['channel.topic'], 'alerts');
        expect(runtimeVariables['channel.bc_topic'], 'alerts');
        expect(runtimeVariables['user.locale'], 'en');
        expect(runtimeVariables['user.bc_locale'], 'en');
        expect(runtimeVariables['guildMember.rank'], 'mod');
        expect(runtimeVariables['guildMember.bc_rank'], 'mod');
        expect(runtimeVariables['message.seen'], 'false');
        expect(runtimeVariables['message.bc_seen'], 'false');
      },
    );
  });
}

class _FakeBotDataStore implements BotDataStore {
  _FakeBotDataStore({
    required this.globalVariables,
    required this.scopedVariables,
  });

  final Map<String, dynamic> globalVariables;
  final Map<String, Map<String, Map<String, dynamic>>> scopedVariables;

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async =>
      Map<String, dynamic>.from(globalVariables);

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async =>
      globalVariables[key];

  @override
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  ) async {
    return Map<String, dynamic>.from(
      scopedVariables[scope]?[contextId] ?? const <String, dynamic>{},
    );
  }

  @override
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    return scopedVariables[scope]?[contextId]?[key];
  }

  @override
  Future<Map<String, dynamic>?> getWorkflowByName(String botId, String name) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    element,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<Map<String, dynamic>> queryScopedArray(
    String botId,
    String scope,
    String contextId,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
    String? filter,
  }) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  }) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> setGlobalVariable(String botId, String key, value) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    value,
  ) {
    throw UnsupportedError('Not used in this test');
  }
}
