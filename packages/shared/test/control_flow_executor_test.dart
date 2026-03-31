import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:test/test.dart';

void main() {
  group('executeControlFlowAction ifBlock', () {
    test(
      'keeps legacy IF/ELSE behavior when no else-if branches exist',
      () async {
        final results = <String, String>{};
        final executed = <String>[];

        final handled = await executeControlFlowAction(
          type: BotCreatorActionType.ifBlock,
          payload: <String, dynamic>{
            'condition.variable': 'score',
            'condition.operator': 'greaterThan',
            'condition.value': '90',
            'thenActions': <Map<String, dynamic>>[],
            'elseActions': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'sendMessage',
                'payload': <String, dynamic>{'content': 'fallback'},
              },
            ],
          },
          resultKey: 'branch',
          results: results,
          variables: <String, String>{'score': '60'},
          resolveValue: (input) => input,
          onLog: null,
          activeWorkflowStack: <String>{},
          getWorkflowByName: (_) async => null,
          executeActions: (actions) async {
            executed.addAll(actions.map((action) => action.type.name));
            return <String, String>{'nested': 'ok'};
          },
        );

        expect(handled, isTrue);
        expect(results['branch'], 'IF_FALSE');
        expect(executed, <String>['sendMessage']);
        expect(results['branch.nested'], 'ok');
      },
    );

    test('executes the first matching else-if branch in order', () async {
      final results = <String, String>{};
      final executed = <String>[];

      final handled = await executeControlFlowAction(
        type: BotCreatorActionType.ifBlock,
        payload: <String, dynamic>{
          'condition.variable': 'score',
          'condition.operator': 'greaterThan',
          'condition.value': '90',
          'thenActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{},
            },
          ],
          'elseIfConditions': <Map<String, dynamic>>[
            <String, dynamic>{
              'condition.variable': 'score',
              'condition.operator': 'greaterThan',
              'condition.value': '80',
              'actions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'editMessage',
                  'payload': <String, dynamic>{},
                },
              ],
            },
            <String, dynamic>{
              'condition.variable': 'score',
              'condition.operator': 'greaterThan',
              'condition.value': '70',
              'actions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'addReaction',
                  'payload': <String, dynamic>{},
                },
              ],
            },
          ],
          'elseActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'removeReaction',
              'payload': <String, dynamic>{},
            },
          ],
        },
        resultKey: 'branch',
        results: results,
        variables: <String, String>{'score': '82'},
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          executed.addAll(actions.map((action) => action.type.name));
          return <String, String>{};
        },
      );

      expect(handled, isTrue);
      expect(results['branch'], 'ELSE_IF_1');
      expect(executed, <String>['editMessage']);
    });

    test('falls back to ELSE when no ELSE IF branch matches', () async {
      final results = <String, String>{};
      final executed = <String>[];

      final handled = await executeControlFlowAction(
        type: BotCreatorActionType.ifBlock,
        payload: <String, dynamic>{
          'condition.variable': 'score',
          'condition.operator': 'greaterThan',
          'condition.value': '90',
          'thenActions': <Map<String, dynamic>>[],
          'elseIfConditions': <Map<String, dynamic>>[
            <String, dynamic>{
              'condition.variable': 'score',
              'condition.operator': 'greaterThan',
              'condition.value': '80',
              'actions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'editMessage',
                  'payload': <String, dynamic>{},
                },
              ],
            },
          ],
          'elseActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'removeReaction',
              'payload': <String, dynamic>{},
            },
          ],
        },
        resultKey: 'branch',
        results: results,
        variables: <String, String>{'score': '50'},
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          executed.addAll(actions.map((action) => action.type.name));
          return <String, String>{};
        },
      );

      expect(handled, isTrue);
      expect(results['branch'], 'IF_FALSE');
      expect(executed, <String>['removeReaction']);
    });
  });

  group('executeControlFlowAction runBdfdScript', () {
    Future<bool> runBdfdScript({
      required Map<String, dynamic> payload,
      required Map<String, String> results,
      required List<String> executed,
      Map<String, String> variables = const <String, String>{},
    }) {
      return executeControlFlowAction(
        type: BotCreatorActionType.runBdfdScript,
        payload: payload,
        resultKey: 'bdfd',
        results: results,
        variables: Map<String, String>.of(variables),
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          executed.addAll(actions.map((action) => action.type.name));
          return <String, String>{'nested': 'ok'};
        },
      );
    }

    test('compiles and executes a simple BDFD script', () async {
      final results = <String, String>{};
      final executed = <String>[];

      final handled = await runBdfdScript(
        payload: <String, dynamic>{'scriptContent': r'Hello $username!'},
        results: results,
        executed: executed,
      );

      expect(handled, isTrue);
      expect(results['bdfd'], 'BDFD_OK');
      expect(executed, contains('respondWithMessage'));
    });

    test('returns BDFD_EMPTY for blank script', () async {
      final results = <String, String>{};
      final executed = <String>[];

      final handled = await runBdfdScript(
        payload: <String, dynamic>{'scriptContent': '   '},
        results: results,
        executed: executed,
      );

      expect(handled, isTrue);
      expect(results['bdfd'], 'BDFD_EMPTY');
      expect(executed, isEmpty);
    });

    test('returns BDFD_EMPTY when scriptContent is missing', () async {
      final results = <String, String>{};
      final executed = <String>[];

      final handled = await runBdfdScript(
        payload: <String, dynamic>{},
        results: results,
        executed: executed,
      );

      expect(handled, isTrue);
      expect(results['bdfd'], 'BDFD_EMPTY');
    });

    test('throws on compile error', () async {
      final results = <String, String>{};
      final executed = <String>[];

      expect(
        () => runBdfdScript(
          payload: <String, dynamic>{'scriptContent': r'$if['},
          results: results,
          executed: executed,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('BDFD compile error'),
          ),
        ),
      );
    });

    test('propagates nested results', () async {
      final results = <String, String>{};
      final executed = <String>[];

      await runBdfdScript(
        payload: <String, dynamic>{'scriptContent': 'Hello world!'},
        results: results,
        executed: executed,
      );

      expect(results['bdfd.nested'], 'ok');
    });

    test('propagates __stopped__ from nested execution', () async {
      final results = <String, String>{};

      await executeControlFlowAction(
        type: BotCreatorActionType.runBdfdScript,
        payload: <String, dynamic>{'scriptContent': 'Hello!'},
        resultKey: 'bdfd',
        results: results,
        variables: <String, String>{},
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          return <String, String>{'__stopped__': 'true'};
        },
      );

      expect(results['__stopped__'], 'true');
      expect(results['bdfd'], 'BDFD_OK');
    });
  });

  group('executeControlFlowAction forLoop', () {
    Future<bool> runForLoop({
      required Map<String, dynamic> payload,
      required Map<String, String> results,
      required List<List<Action>> executedBatches,
      Map<String, String> variables = const <String, String>{},
      String Function(String input)? resolveValue,
    }) {
      return executeControlFlowAction(
        type: BotCreatorActionType.forLoop,
        payload: payload,
        resultKey: 'loop',
        results: results,
        variables: Map<String, String>.of(variables),
        resolveValue: resolveValue ?? (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          executedBatches.add(actions);
          return <String, String>{'nested': 'ok'};
        },
      );
    }

    test('simple runtime loop executes N iterations', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runForLoop(
        payload: <String, dynamic>{
          'mode': 'simple',
          'iterations': '3',
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'iter ((_loop.index))'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, hasLength(3));
      expect(results['loop'], 'LOOP_3');
      // Verify loop placeholder was substituted.
      expect(batches[0][0].payload['content'], 'iter 0');
      expect(batches[1][0].payload['content'], 'iter 1');
      expect(batches[2][0].payload['content'], 'iter 2');
    });

    test(
      'simple runtime loop resolves iteration count via resolveValue',
      () async {
        final results = <String, String>{};
        final batches = <List<Action>>[];

        await runForLoop(
          payload: <String, dynamic>{
            'mode': 'simple',
            'iterations': '((message[2]))',
            'bodyActions': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'sendMessage',
                'payload': <String, dynamic>{'content': 'hello'},
              },
            ],
          },
          results: results,
          executedBatches: batches,
          resolveValue: (input) => input.replaceAll('((message[2]))', '2'),
        );

        expect(batches, hasLength(2));
        expect(results['loop'], 'LOOP_2');
      },
    );

    test('simple runtime loop caps at maxIterations', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runForLoop(
        payload: <String, dynamic>{
          'mode': 'simple',
          'iterations': '500',
          'maxIterations': 5,
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'x'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, hasLength(5));
      expect(results['loop'], 'LOOP_5');
    });

    test('simple runtime loop with 0 iterations produces LOOP_0', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runForLoop(
        payload: <String, dynamic>{
          'mode': 'simple',
          'iterations': '0',
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'x'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, isEmpty);
      expect(results['loop'], 'LOOP_0');
    });

    test('C-style runtime loop executes correctly', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runForLoop(
        payload: <String, dynamic>{
          'mode': 'cstyle',
          'init': 'i=0',
          'condition': '((_loop.var.i)) < 3',
          'update': 'i++',
          'varNames': <String>['i'],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'val=((_loop.var.i))'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, hasLength(3));
      expect(results['loop'], 'LOOP_3');
      expect(batches[0][0].payload['content'], 'val=0');
      expect(batches[1][0].payload['content'], 'val=1');
      expect(batches[2][0].payload['content'], 'val=2');
    });

    test('C-style runtime loop resolves runtime bound', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runForLoop(
        payload: <String, dynamic>{
          'mode': 'cstyle',
          'init': 'i=0',
          'condition': '((_loop.var.i)) < ((message[2]))',
          'update': 'i++',
          'varNames': <String>['i'],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': '((_loop.var.i))'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
        resolveValue: (input) => input.replaceAll('((message[2]))', '4'),
      );

      expect(batches, hasLength(4));
      expect(results['loop'], 'LOOP_4');
    });

    test('forLoop propagates __stopped__', () async {
      final results = <String, String>{};

      await executeControlFlowAction(
        type: BotCreatorActionType.forLoop,
        payload: <String, dynamic>{
          'mode': 'simple',
          'iterations': '5',
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'x'},
            },
          ],
        },
        resultKey: 'loop',
        results: results,
        variables: <String, String>{},
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          return <String, String>{'__stopped__': 'true'};
        },
      );

      expect(results['__stopped__'], 'true');
    });
  });
}
