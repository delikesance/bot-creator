import 'package:bot_creator_shared/actions/executors/variables_executor.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

void main() {
  group('executeVariablesAction', () {
    test('appendArrayElement appends to a global root array', () async {
      final store = _MemoryBotDataStore();
      final results = <String, String>{};
      final variables = <String, String>{};

      final handled = await executeVariablesAction(
        type: BotCreatorActionType.appendArrayElement,
        store: store,
        botId: 'bot-1',
        payload: <String, dynamic>{
          'target': 'global',
          'key': 'scores',
          'valueType': 'number',
          'numberValue': '4',
        },
        resultKey: 'append',
        results: results,
        variables: variables,
        resolveValue: (input) => input,
        guildId: null,
        fallbackChannelId: null,
        interaction: null,
      );

      expect(handled, isTrue);
      expect(store.globalVariables['scores'], <dynamic>[4]);
      expect(results['append'], '[4]');
      expect(variables['global.scores'], '[4]');
      expect(variables['append.items'], '[4]');
      expect(variables['append.length'], '1');
    });

    test(
      'appendArrayElement and removeArrayElement support scoped JSON paths',
      () async {
        final store = _MemoryBotDataStore(
          scopedVariables: <String, Map<String, Map<String, dynamic>>>{
            'guild': <String, Map<String, dynamic>>{
              'guild-1': <String, dynamic>{
                'stats': <String, dynamic>{
                  'items': <Map<String, dynamic>>[
                    <String, dynamic>{'name': 'Alice'},
                  ],
                },
              },
            },
          },
        );
        final variables = <String, String>{'guildId': 'guild-1'};
        final appendResults = <String, String>{};

        await executeVariablesAction(
          type: BotCreatorActionType.appendArrayElement,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'target': 'scoped',
            'scope': 'guild',
            'key': 'stats',
            'path': r'$.items',
            'valueType': 'json',
            'jsonValue': '{"name":"Bob"}',
          },
          resultKey: 'appendScoped',
          results: appendResults,
          variables: variables,
          resolveValue: (input) => input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(
          store.scopedVariables['guild']?['guild-1']?['stats'],
          <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Alice'},
              <String, dynamic>{'name': 'Bob'},
            ],
          },
        );
        expect(variables['appendScoped.length'], '2');

        final removeResults = <String, String>{};
        await executeVariablesAction(
          type: BotCreatorActionType.removeArrayElement,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'target': 'scoped',
            'scope': 'guild',
            'key': 'stats',
            'path': r'$.items',
            'index': '0',
          },
          resultKey: 'removeScoped',
          results: removeResults,
          variables: variables,
          resolveValue: (input) => input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(
          store.scopedVariables['guild']?['guild-1']?['stats'],
          <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Bob'},
            ],
          },
        );
        expect(removeResults['removeScoped'], '[{"name":"Bob"}]');
        expect(variables['removeScoped.length'], '1');
        expect(variables['removeScoped.removed'], '{"name":"Alice"}');
      },
    );

    test(
      'queryArray filters, sorts, paginates and stores runtime aliases',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{};
        final variables = <String, String>{};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.queryArray,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'input':
                '{"items":[{"name":"Charlie","score":7},{"name":"Alice","score":12},{"name":"Bob","score":10}]}',
            'path': r'$.items',
            'filterTemplate': '{score}',
            'filterOperator': 'gte',
            'filterValue': '10',
            'sortTemplate': '{name}',
            'order': 'desc',
            'offset': '0',
            'limit': '1',
            'storeAs': 'topScores',
          },
          resultKey: 'query',
          results: results,
          variables: variables,
          resolveValue: (input) => input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(results['query'], '[{"name":"Bob","score":10}]');
        expect(variables['query.items'], '[{"name":"Bob","score":10}]');
        expect(variables['query.count'], '1');
        expect(variables['query.total'], '2');
        expect(variables['topScores'], '[{"name":"Bob","score":10}]');
      },
    );
  });
}

class _MemoryBotDataStore implements BotDataStore {
  _MemoryBotDataStore({
    Map<String, dynamic>? globalVariables,
    Map<String, Map<String, Map<String, dynamic>>>? scopedVariables,
  }) : globalVariables = globalVariables ?? <String, dynamic>{},
       scopedVariables =
           scopedVariables ?? <String, Map<String, Map<String, dynamic>>>{};

  final Map<String, dynamic> globalVariables;
  final Map<String, Map<String, Map<String, dynamic>>> scopedVariables;

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async =>
      Map<String, dynamic>.from(globalVariables);

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async =>
      globalVariables[key];

  @override
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value,
  ) async {
    globalVariables[key] = value;
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) async {
    if (!globalVariables.containsKey(oldKey)) {
      return;
    }
    globalVariables[newKey] = globalVariables.remove(oldKey);
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
    globalVariables.remove(key);
  }

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
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value,
  ) async {
    scopedVariables.putIfAbsent(scope, () => <String, Map<String, dynamic>>{});
    scopedVariables[scope]!.putIfAbsent(contextId, () => <String, dynamic>{});
    scopedVariables[scope]![contextId]![key] = value;
  }

  @override
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) async {
    final bucket = scopedVariables[scope]?[contextId];
    if (bucket == null || !bucket.containsKey(oldKey)) {
      return;
    }
    bucket[newKey] = bucket.remove(oldKey);
  }

  @override
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    scopedVariables[scope]?[contextId]?.remove(key);
  }

  @override
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  }) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic element,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<dynamic> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    throw UnsupportedError('Not used in these tests');
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
  }) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<Map<String, dynamic>?> getWorkflowByName(
    String botId,
    String name,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }
}
