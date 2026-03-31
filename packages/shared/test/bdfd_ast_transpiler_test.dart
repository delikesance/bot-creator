import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdAstTranspiler', () {
    test('transpiles plain text into respondWithMessage', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(nodes: [BdfdTextAst('Hello world')]),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(result.actions.single.payload['content'], 'Hello world');
    });

    test(
      'transpiles embed-style functions into one respondWithMessage action',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$title',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('Server Info')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$description',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('Welcome back')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$color',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('#ffcc00')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addField',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('User')],
                  <BdfdAstNode>[BdfdTextAst('Jeremy')],
                  <BdfdAstNode>[BdfdTextAst('yes')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(1));

        final action = result.actions.single;
        final embeds = List<Map<String, dynamic>>.from(
          action.payload['embeds'] as List,
        );
        expect(action.type, BotCreatorActionType.respondWithMessage);
        expect(embeds, hasLength(1));
        expect(embeds.single['title'], 'Server Info');
        expect(embeds.single['description'], 'Welcome back');
        expect(embeds.single['color'], '#ffcc00');
        expect((embeds.single['fields'] as List).first, {
          'name': 'User',
          'value': 'Jeremy',
          'inline': true,
        });
      },
    );

    test('transpiles if blocks to ifBlock actions with nested branches', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))>=80')],
                <BdfdAstNode>[BdfdTextAst('great')],
                <BdfdAstNode>[BdfdTextAst('retry')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));

      final action = result.actions.single;
      expect(action.type, BotCreatorActionType.ifBlock);
      expect(action.payload['condition.variable'], '((score))');
      expect(action.payload['condition.operator'], 'greaterOrEqual');
      expect(action.payload['condition.value'], '80');

      final thenActions = List<Map<String, dynamic>>.from(
        action.payload['thenActions'] as List,
      );
      final elseActions = List<Map<String, dynamic>>.from(
        action.payload['elseActions'] as List,
      );
      expect(thenActions.single['type'], 'respondWithMessage');
      expect((thenActions.single['payload'] as Map)['content'], 'great');
      expect(elseActions.single['type'], 'respondWithMessage');
      expect((elseActions.single['payload'] as Map)['content'], 'retry');
    });

    test('transpiles for loop blocks by repeating body actions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$for',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('3')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$reply',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Ping')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$endfor'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(3));
      expect(
        result.actions.every(
          (action) => action.type == BotCreatorActionType.respondWithMessage,
        ),
        isTrue,
      );
      expect(result.actions[0].payload['content'], 'Ping');
      expect(result.actions[1].payload['content'], 'Ping');
      expect(result.actions[2].payload['content'], 'Ping');
    });

    test('supports nested loop blocks', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$for',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('2')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$loop',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('2')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$reply',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Nested')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$endloop'),
            BdfdFunctionCallAst(name: r'$endfor'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(4));
      expect(result.actions.first.payload['content'], 'Nested');
      expect(result.actions.last.payload['content'], 'Nested');
    });

    test('reports stray endfor delimiters', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(nodes: [BdfdFunctionCallAst(name: r'$endfor')]),
      );

      expect(result.actions, isEmpty);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.message, contains('Unexpected'));
      expect(result.diagnostics.single.functionName, r'$endfor');
    });

    test('flushes pending response before standalone action functions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdTextAst('Intro'),
            BdfdFunctionCallAst(
              name: r'$reply',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Immediate')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.payload['content'], 'Intro');
      expect(result.actions.last.payload['content'], 'Immediate');
    });

    test('reports unsupported functions as diagnostics', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$let',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('score')],
                <BdfdAstNode>[BdfdTextAst('10')],
              ],
            ),
          ],
        ),
      );

      expect(result.actions, isEmpty);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$let');
    });

    test(
      'renders supported nested variable functions inline without diagnostic',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$description',
                arguments: [
                  <BdfdAstNode>[
                    BdfdTextAst('Hello '),
                    BdfdFunctionCallAst(name: r'$username'),
                  ],
                ],
              ),
            ],
          ),
        );

        expect(result.actions, hasLength(1));
        expect(result.diagnostics, isEmpty);

        final embeds = List<Map<String, dynamic>>.from(
          result.actions.single.payload['embeds'] as List,
        );
        expect(embeds.single['description'], 'Hello ((user.username))');
      },
    );

    test('transpiles http requests and result placeholders', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$httpAddHeader',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('authorization')],
                <BdfdAstNode>[BdfdTextAst('Bearer token')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$httpGet',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://api.example.com/cat')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdTextAst('Image: '),
                  BdfdFunctionCallAst(
                    name: r'$httpResult',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('results')],
                      <BdfdAstNode>[BdfdTextAst('0')],
                      <BdfdAstNode>[BdfdTextAst('url')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.type, BotCreatorActionType.httpRequest);
      expect(result.actions.first.key, '_bdfd_http_0');
      expect(result.actions.first.payload['method'], 'GET');
      expect(result.actions.first.payload['headers'], {
        'authorization': 'Bearer token',
      });

      final embeds = List<Map<String, dynamic>>.from(
        result.actions.last.payload['embeds'] as List,
      );
      expect(
        embeds.single['description'],
        r'Image: ((http.body.$.results[0].url))',
      );
    });

    test('reports httpResult without preceding request as error', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$httpResult')],
              ],
            ),
          ],
        ),
      );

      expect(result.actions, hasLength(1));
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$httpResult');
      expect(
        result.diagnostics.single.severity,
        BdfdTranspileDiagnosticSeverity.error,
      );
    });

    test('transpiles block if with elseif/else delimiters', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))>10')],
              ],
            ),
            BdfdTextAst('gold'),
            BdfdFunctionCallAst(
              name: r'$elseif',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))==10')],
              ],
            ),
            BdfdTextAst('silver'),
            BdfdFunctionCallAst(name: r'$else'),
            BdfdTextAst('bronze'),
            BdfdFunctionCallAst(name: r'$endif'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.ifBlock);

      final payload = result.actions.single.payload;
      expect(payload['condition.operator'], 'greaterThan');
      expect(payload['condition.value'], '10');

      final elseIfConditions = List<Map<String, dynamic>>.from(
        payload['elseIfConditions'] as List,
      );
      expect(elseIfConditions, hasLength(1));
      expect(elseIfConditions.single['condition.operator'], 'equals');

      final thenActions = List<Map<String, dynamic>>.from(
        payload['thenActions'] as List,
      );
      final elseActions = List<Map<String, dynamic>>.from(
        payload['elseActions'] as List,
      );
      final elseIfActions = List<Map<String, dynamic>>.from(
        elseIfConditions.single['actions'] as List,
      );

      expect((thenActions.single['payload'] as Map)['content'], 'gold');
      expect((elseIfActions.single['payload'] as Map)['content'], 'silver');
      expect((elseActions.single['payload'] as Map)['content'], 'bronze');
    });

    test('transpiles logical and-conditions and stop action', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[BdfdTextAst(r'$and[((a))==1;((b))==2]==true')],
                <BdfdAstNode>[BdfdTextAst('ok')],
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$stop')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      final payload = result.actions.single.payload;
      expect(payload['condition.group'], 'and');
      final grouped = List<Map<String, dynamic>>.from(
        payload['condition.conditions'] as List,
      );
      expect(grouped, hasLength(2));

      final elseActions = List<Map<String, dynamic>>.from(
        payload['elseActions'] as List,
      );
      expect(elseActions.single['type'], 'stopUnless');
    });

    test('supports json parse/get/set/unset/stringify helpers', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"user":{"name":"Nia","age":16}}')],
              ],
            ),
            BdfdTextAst('Name='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('name')],
              ],
            ),
            BdfdTextAst(', Age='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('age')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonSet',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('age')],
                <BdfdAstNode>[BdfdTextAst('19')],
              ],
            ),
            BdfdTextAst(', NewAge='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('age')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonUnset',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('name')],
              ],
            ),
            BdfdTextAst(', HasName='),
            BdfdFunctionCallAst(
              name: r'$jsonExists',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('name')],
              ],
            ),
            BdfdTextAst(', JSON='),
            BdfdFunctionCallAst(name: r'$jsonStringify'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        'Name=Nia, Age=16, NewAge=19, HasName=false, JSON={"user":{"age":19}}',
      );
    });

    test('supports json array helpers', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"music":["A","B"]}')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonArrayAppend',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
                <BdfdAstNode>[BdfdTextAst('C')],
              ],
            ),
            BdfdTextAst('Count='),
            BdfdFunctionCallAst(
              name: r'$jsonArrayCount',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
              ],
            ),
            BdfdTextAst(', Removed='),
            BdfdFunctionCallAst(
              name: r'$jsonArrayShift',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
              ],
            ),
            BdfdTextAst(', Joined='),
            BdfdFunctionCallAst(
              name: r'$jsonJoinArray',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
                <BdfdAstNode>[BdfdTextAst(', ')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        'Count=3, Removed=A, Joined=B, C',
      );
    });

    test('transpiles startThread inline with returned ID placeholder', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdTextAst('New thread: '),
            BdfdFunctionCallAst(
              name: r'$startThread',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Cool Thread')],
                <BdfdAstNode>[BdfdTextAst('123')],
                <BdfdAstNode>[BdfdTextAst('')],
                <BdfdAstNode>[BdfdTextAst('1440')],
                <BdfdAstNode>[BdfdTextAst('yes')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.type, BotCreatorActionType.createThread);
      expect(result.actions.first.payload['name'], 'Cool Thread');
      expect(result.actions.first.payload['channelId'], '123');
      expect(
        result.actions.last.payload['content'],
        'New thread: ((thread.lastId))',
      );
    });

    test('transpiles editThread and thread member functions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$editThread',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('555')],
                <BdfdAstNode>[BdfdTextAst('Renamed')],
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('!unchanged')],
                <BdfdAstNode>[BdfdTextAst('!unchanged')],
                <BdfdAstNode>[BdfdTextAst('5')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$threadAddMember',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('555')],
                <BdfdAstNode>[BdfdTextAst('999')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$threadRemoveMember',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('555')],
                <BdfdAstNode>[BdfdTextAst('999')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].type, BotCreatorActionType.updateChannel);
      expect(result.actions[0].payload['channelId'], '555');
      expect(result.actions[0].payload['name'], 'Renamed');
      expect(result.actions[0].payload['archived'], false);
      expect(result.actions[0].payload['slowmode'], '5');
      expect(result.actions[1].type, BotCreatorActionType.addThreadMember);
      expect(result.actions[2].type, BotCreatorActionType.removeThreadMember);
    });

    test('transpiles guard helpers to ifBlock and stopUnless actions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyIf',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))>10')],
                <BdfdAstNode>[BdfdTextAst('Too low')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForUsers',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Nicky')],
                <BdfdAstNode>[BdfdTextAst('Jeremy')],
                <BdfdAstNode>[BdfdTextAst('Denied user')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForChannels',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('333')],
                <BdfdAstNode>[BdfdTextAst('Wrong channel')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$ignoreChannels',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('444')],
                <BdfdAstNode>[BdfdTextAst('555')],
                <BdfdAstNode>[
                  BdfdTextAst("❌ That command can't be used in this channel!"),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyNSFW',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('NSFW only')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(5));

      final onlyIfPayload = result.actions[0].payload;
      expect(result.actions[0].type, BotCreatorActionType.ifBlock);
      expect(onlyIfPayload['condition.operator'], 'greaterThan');
      final onlyIfElse = List<Map<String, dynamic>>.from(
        onlyIfPayload['elseActions'] as List,
      );
      expect(onlyIfElse, hasLength(2));
      expect(onlyIfElse[0]['type'], 'respondWithMessage');
      expect(onlyIfElse[1]['type'], 'stopUnless');

      final onlyForUsersPayload = result.actions[1].payload;
      expect(onlyForUsersPayload['condition.group'], 'or');
      final onlyForUsersConditions = List<Map<String, dynamic>>.from(
        onlyForUsersPayload['condition.conditions'] as List,
      );
      expect(onlyForUsersConditions, hasLength(2));
      expect(onlyForUsersConditions[0]['variable'], '((author.username))');
      expect(onlyForUsersConditions[0]['operator'], 'matches');
      expect(onlyForUsersConditions[1]['value'], '(?i)^Jeremy\$');

      final onlyForChannelsPayload = result.actions[2].payload;
      final onlyForChannelConditions = List<Map<String, dynamic>>.from(
        onlyForChannelsPayload['condition.conditions'] as List,
      );
      expect(onlyForChannelConditions.single['variable'], '((channel.id))');

      final ignorePayload = result.actions[3].payload;
      final ignoreThen = List<Map<String, dynamic>>.from(
        ignorePayload['thenActions'] as List,
      );
      expect(ignoreThen, hasLength(2));
      expect(ignoreThen[0]['type'], 'respondWithMessage');
      expect(
        ignoreThen[0]['payload']['content'],
        "❌ That command can't be used in this channel!",
      );
      expect(ignoreThen[1]['type'], 'stopUnless');

      final onlyNsfwPayload = result.actions[4].payload;
      expect(onlyNsfwPayload['condition.variable'], '((channel.nsfw))');
      expect(onlyNsfwPayload['condition.value'], 'true');
    });

    test('transpiles permission and role guard helpers', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyPerms',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('manageMessages')],
                <BdfdAstNode>[BdfdTextAst('kickMembers')],
                <BdfdAstNode>[BdfdTextAst('Missing perms')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyBotPerms',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('manageRoles')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyAdmin',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Admins only')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$checkUserPerms',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('<@1234567890>')],
                <BdfdAstNode>[BdfdTextAst('banMembers')],
                <BdfdAstNode>[BdfdTextAst('Denied')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForRoles',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Moderator')],
                <BdfdAstNode>[BdfdTextAst('Role required')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(5));

      final onlyPermsPayload = result.actions[0].payload;
      expect(onlyPermsPayload['condition.group'], 'and');
      final onlyPermsConditions = List<Map<String, dynamic>>.from(
        onlyPermsPayload['condition.conditions'] as List,
      );
      expect(onlyPermsConditions, hasLength(2));
      expect(onlyPermsConditions.first['variable'], '((member.permissions))');
      expect(onlyPermsConditions.first['value'], 'managemessages');

      final onlyBotPermsPayload = result.actions[1].payload;
      final onlyBotPermsConditions = List<Map<String, dynamic>>.from(
        onlyBotPermsPayload['condition.conditions'] as List,
      );
      expect(onlyBotPermsConditions.single['variable'], '((bot.permissions))');

      final onlyAdminPayload = result.actions[2].payload;
      expect(onlyAdminPayload['condition.group'], 'or');

      final checkUserPermsPayload = result.actions[3].payload;
      final checkUserPermsConditions = List<Map<String, dynamic>>.from(
        checkUserPermsPayload['condition.conditions'] as List,
      );
      expect(checkUserPermsPayload['condition.group'], 'or');
      final selfBranchConditions = List<Map<String, dynamic>>.from(
        checkUserPermsConditions.first['conditions'] as List,
      );
      expect(selfBranchConditions.first['variable'], '((author.id))');
      expect(selfBranchConditions.first['value'], '1234567890');
      expect(
        checkUserPermsConditions[1]['conditions'][0]['variable'],
        'permissions.byId.1234567890',
      );
      expect(
        checkUserPermsConditions[1]['conditions'][0]['value'],
        'banmembers',
      );
      expect(checkUserPermsConditions[2]['variable'], '1234567890');
      expect(checkUserPermsConditions[2]['operator'], 'equals');
      expect(checkUserPermsConditions[2]['value'], '((guild.ownerId))');

      final onlyForRolesPayload = result.actions[4].payload;
      final onlyForRolesConditions = List<Map<String, dynamic>>.from(
        onlyForRolesPayload['condition.conditions'] as List,
      );
      expect(onlyForRolesConditions.single['group'], 'or');
      final roleBranchConditions = List<Map<String, dynamic>>.from(
        onlyForRolesConditions.single['conditions'] as List,
      );
      expect(roleBranchConditions[0]['variable'], '((member.roles))');
      expect(roleBranchConditions[1]['variable'], '((member.roleNames))');
    });

    test('transpiles wave 3 guard helpers', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyForIDs',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('111')],
                <BdfdAstNode>[BdfdTextAst('Denied ID')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForRoleIDs',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('222')],
                <BdfdAstNode>[BdfdTextAst('Denied role id')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForServers',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('333')],
                <BdfdAstNode>[BdfdTextAst('Wrong server')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForCategories',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('444')],
                <BdfdAstNode>[BdfdTextAst('Wrong category')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyBotChannelPerms',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((channel.id))')],
                <BdfdAstNode>[BdfdTextAst('manageMessages')],
                <BdfdAstNode>[BdfdTextAst('Bot missing perms')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyIfMessageContains',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((message.content))')],
                <BdfdAstNode>[BdfdTextAst('Hello')],
                <BdfdAstNode>[BdfdTextAst('Hi')],
                <BdfdAstNode>[BdfdTextAst('Missing text')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(6));

      final onlyForIdsPayload = result.actions[0].payload;
      final onlyForIdsConditions = List<Map<String, dynamic>>.from(
        onlyForIdsPayload['condition.conditions'] as List,
      );
      expect(onlyForIdsConditions.single['variable'], '((author.id))');

      final onlyForRoleIdsPayload = result.actions[1].payload;
      final onlyForRoleIdsConditions = List<Map<String, dynamic>>.from(
        onlyForRoleIdsPayload['condition.conditions'] as List,
      );
      expect(onlyForRoleIdsConditions.single['variable'], '((member.roles))');

      final onlyForServersPayload = result.actions[2].payload;
      final onlyForServersConditions = List<Map<String, dynamic>>.from(
        onlyForServersPayload['condition.conditions'] as List,
      );
      expect(onlyForServersConditions.single['variable'], '((guild.id))');

      final onlyForCategoriesPayload = result.actions[3].payload;
      final onlyForCategoriesConditions = List<Map<String, dynamic>>.from(
        onlyForCategoriesPayload['condition.conditions'] as List,
      );
      expect(
        onlyForCategoriesConditions.single['variable'],
        '((channel.parentId))',
      );

      final onlyBotChannelPermsPayload = result.actions[4].payload;
      final onlyBotChannelPermsConditions = List<Map<String, dynamic>>.from(
        onlyBotChannelPermsPayload['condition.conditions'] as List,
      );
      expect(
        onlyBotChannelPermsConditions.single['variable'],
        '((bot.permissions))',
      );

      final onlyIfMessageContainsPayload = result.actions[5].payload;
      expect(onlyIfMessageContainsPayload['condition.group'], 'and');
      final containsConditions = List<Map<String, dynamic>>.from(
        onlyIfMessageContainsPayload['condition.conditions'] as List,
      );
      expect(containsConditions, hasLength(2));
      expect(containsConditions[0]['variable'], '((message.content))');
      expect(containsConditions[0]['operator'], 'matches');
      expect(containsConditions[0]['value'], '(?i).*Hello.*');
      expect(containsConditions[1]['value'], '(?i).*Hi.*');
    });

    test('normalizes BDFD wiki permission aliases', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyPerms',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('admin')],
                <BdfdAstNode>[BdfdTextAst('ban')],
                <BdfdAstNode>[BdfdTextAst('slashcommands')],
                <BdfdAstNode>[BdfdTextAst('Denied')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));

      final payload = result.actions.single.payload;
      final conditions = List<Map<String, dynamic>>.from(
        payload['condition.conditions'] as List,
      );
      final values = conditions
          .map((entry) => entry['value']?.toString() ?? '')
          .toList(growable: false);
      expect(values, contains('administrator'));
      expect(values, contains('banmembers'));
      expect(values, contains('useapplicationcommands'));
    });

    test('supports inline checkUserPerms boolean output', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$reply',
              arguments: [
                <BdfdAstNode>[
                  BdfdTextAst('Admin perms?: '),
                  BdfdFunctionCallAst(
                    name: r'$checkUserPerms',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('1234567890')],
                      <BdfdAstNode>[BdfdTextAst('administrator')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));

      expect(result.actions[0].type, BotCreatorActionType.ifBlock);
      expect(result.actions[1].type, BotCreatorActionType.respondWithMessage);

      final content = result.actions[1].payload['content']?.toString() ?? '';
      expect(content, startsWith('Admin perms?: '));
      expect(content, contains('((message.bc_check_user_perms_0))'));
    });

    test('supports inline message[] argument lookups', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$reply',
              arguments: [
                <BdfdAstNode>[
                  BdfdTextAst('First='),
                  BdfdFunctionCallAst(
                    name: r'$message',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('1')],
                    ],
                  ),
                  BdfdTextAst(', Last='),
                  BdfdFunctionCallAst(
                    name: r'$message',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('>')],
                    ],
                  ),
                  BdfdTextAst(', Slash='),
                  BdfdFunctionCallAst(
                    name: r'$message',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('text')],
                    ],
                  ),
                  BdfdTextAst(', Mixed='),
                  BdfdFunctionCallAst(
                    name: r'$message',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('1')],
                      <BdfdAstNode>[BdfdTextAst('text')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(
        result.actions.single.payload['content'],
        'First=((message.content[0])), Last=((last(split(message.content, " ")))), Slash=((opts.text)), Mixed=((message.content[0]|opts.text))',
      );
    });

    test('supports inline message without brackets', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$reply',
              arguments: [
                <BdfdAstNode>[
                  BdfdTextAst('Raw='),
                  BdfdFunctionCallAst(name: r'$message'),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(
        result.actions.single.payload['content'],
        'Raw=((message.content))',
      );
    });

    test('transpiles channelSendMessage to sendMessage action', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$channelSendMessage',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('123456789012345678')],
                <BdfdAstNode>[BdfdTextAst('Hello!')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['channelId'], '123456789012345678');
      expect(result.actions.single.payload['content'], 'Hello!');
    });

    test('resolves user identity helper functions inline', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$reply',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(name: r'$authorAvatar'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$authorID'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$authorOfMessage'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$creationDate'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$discriminator'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$displayName'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(
                    name: r'$displayName',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('123')],
                    ],
                  ),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$getUserStatus'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$getCustomStatus'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$isAdmin'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$isBooster'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$isBot'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$isUserDMEnabled'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$nickname'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(
                    name: r'$nickname',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('123')],
                    ],
                  ),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userAvatar'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userBadges'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userBanner'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userBannerColor'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userExists'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userID'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userInfo'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userJoined'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userJoinedDiscord'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$username'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(
                    name: r'$username',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('123')],
                    ],
                  ),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userPerms'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$userServerAvatar'),
                  BdfdTextAst('|'),
                  BdfdFunctionCallAst(name: r'$findUser'),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      final content =
          result.actions.single.payload['content']?.toString() ?? '';
      expect(content, contains('((author.avatar))'));
      expect(content, contains('((author.id))'));
      expect(content, contains('((target.message.author.id|author.id))'));
      expect(content, contains('((member.nick|author.username))'));
      expect(content, contains('((member.permissions))'));
      expect(content, contains('((member.avatar))'));
      expect(content, contains('((user.id))'));
    });

    test('transpiles changeUsername helpers to actions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$changeUsername',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('NewName')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$changeUsernameWithID',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('1234567890')],
                <BdfdAstNode>[BdfdTextAst('AnotherName')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.updateSelfUser);
      expect(result.actions[0].payload['username'], 'NewName');
      expect(result.actions[1].type, BotCreatorActionType.ifBlock);
    });

    test('supports inline mentionedChannels lookup', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$reply',
              arguments: [
                <BdfdAstNode>[
                  BdfdTextAst('Mention='),
                  BdfdFunctionCallAst(
                    name: r'$mentionedChannels',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('1')],
                    ],
                  ),
                  BdfdTextAst(', Fallback='),
                  BdfdFunctionCallAst(
                    name: r'$mentionedChannels',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('1')],
                      <BdfdAstNode>[BdfdTextAst('yes')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(
        result.actions.single.payload['content'],
        'Mention=((message.mentions[0])), Fallback=((message.mentions[0]|channel.id))',
      );
    });
  });

  group('embed helper functions', () {
    test(r'transpiles $addTimestamp without argument to "now"', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [BdfdFunctionCallAst(name: r'$addTimestamp')],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['timestamp'], 'now');
    });

    test(r'transpiles $addTimestamp with explicit value', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addTimestamp',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('2026-03-30T12:00:00Z')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['timestamp'], '2026-03-30T12:00:00Z');
    });

    test(r'transpiles $authorIcon standalone into author.icon_url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$author',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Jeremy')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$authorIcon',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/icon.png')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      final author = Map<String, dynamic>.from(embeds.single['author'] as Map);
      expect(author['name'], 'Jeremy');
      expect(author['icon_url'], 'https://example.com/icon.png');
    });

    test(r'transpiles $authorURL standalone into author.url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$author',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Jeremy')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$authorURL',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      final author = Map<String, dynamic>.from(embeds.single['author'] as Map);
      expect(author['name'], 'Jeremy');
      expect(author['url'], 'https://example.com');
    });

    test(r'transpiles $embeddedURL into embed url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$title',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Click me')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$embeddedURL',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['title'], 'Click me');
      expect(embeds.single['url'], 'https://example.com');
    });

    test(r'transpiles $footerIcon standalone into footer.icon_url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$footer',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('My footer')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$footerIcon',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/icon.png')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      final footer = Map<String, dynamic>.from(embeds.single['footer'] as Map);
      expect(footer['text'], 'My footer');
      expect(footer['icon_url'], 'https://example.com/icon.png');
    });

    test(r'transpiles $thumbnail into an embed thumbnail', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$thumbnail',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://embed-thumb.example.com')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['thumbnail'], {
        'url': 'https://embed-thumb.example.com',
      });
    });
  });

  group('ComponentV2 builder functions', () {
    test(
      r'transpiles $addContainer into a ComponentV2 container component',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addContainer',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('#ff0000')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(
          result.actions.single.type,
          BotCreatorActionType.respondWithComponentV2,
        );
        final items = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        expect(items.single['type'], 'container');
        expect(items.single['accentColor'], '#ff0000');
      },
    );

    test(r'transpiles $addSection into a ComponentV2 section component', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addSection',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Section text')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithComponentV2,
      );
      final items = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      expect(items.single['type'], 'section');
      expect(items.single['content'], 'Section text');
    });

    test(
      r'transpiles $addThumbnail into a ComponentV2 thumbnail component',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addThumbnail',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('https://example.com/thumb.png')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(
          result.actions.single.type,
          BotCreatorActionType.respondWithComponentV2,
        );
        final items = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        expect(items.single['type'], 'thumbnail');
        expect(items.single['url'], 'https://example.com/thumb.png');
      },
    );

    test(r'$addMediaGallery adds items to a new media gallery', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addMediaGallery',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/img1.png')],
                <BdfdAstNode>[BdfdTextAst('First image')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addMediaGallery',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/img2.png')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithComponentV2,
      );
      final items = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      expect(items, hasLength(1));
      expect(items.single['type'], 'mediaGallery');
      final galleryItems = List<Map<String, dynamic>>.from(
        items.single['items'] as List,
      );
      expect(galleryItems, hasLength(2));
      expect(galleryItems[0]['url'], 'https://example.com/img1.png');
      expect(galleryItems[0]['description'], 'First image');
      expect(galleryItems[1]['url'], 'https://example.com/img2.png');
      expect(galleryItems[1].containsKey('description'), isFalse);
    });

    test(
      r'$addMediaGallery starts a new gallery after a non-gallery component',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addMediaGallery',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('https://example.com/a.png')],
                ],
              ),
              BdfdFunctionCallAst(name: r'$addSeparator'),
              BdfdFunctionCallAst(
                name: r'$addMediaGallery',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('https://example.com/b.png')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        final items = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        // gallery, separator, gallery
        expect(items, hasLength(3));
        expect(items[0]['type'], 'mediaGallery');
        expect(items[1]['type'], 'separator');
        expect(items[2]['type'], 'mediaGallery');
        expect(
          (items[0]['items'] as List).single['url'],
          'https://example.com/a.png',
        );
        expect(
          (items[2]['items'] as List).single['url'],
          'https://example.com/b.png',
        );
      },
    );

    test(r'rich V2 components produce respondWithComponentV2 action type', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addTextDisplay',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Hello ComponentV2')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$addSeparator'),
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('cmd_ok')],
                <BdfdAstNode>[BdfdTextAst('OK')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithComponentV2,
      );
      final items = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      expect(items[0]['type'], 'textDisplay');
      expect(items[1]['type'], 'separator');
      expect(items[2]['type'], 'button');
    });

    test(
      r'pure buttons without rich V2 keep respondWithMessage action type',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addButton',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('no')],
                  <BdfdAstNode>[BdfdTextAst('cmd_a')],
                  <BdfdAstNode>[BdfdTextAst('Click')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(
          result.actions.single.type,
          BotCreatorActionType.respondWithMessage,
        );
      },
    );
  });

  group('ComponentV2 editing functions', () {
    test(r'$editButton modifies the button at given row/col position', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('cmd_a')],
                <BdfdAstNode>[BdfdTextAst('Alpha')],
                <BdfdAstNode>[BdfdTextAst('primary')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('cmd_b')],
                <BdfdAstNode>[BdfdTextAst('Beta')],
                <BdfdAstNode>[BdfdTextAst('secondary')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('yes')],
                <BdfdAstNode>[BdfdTextAst('cmd_c')],
                <BdfdAstNode>[BdfdTextAst('Gamma')],
                <BdfdAstNode>[BdfdTextAst('danger')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('1')],
                <BdfdAstNode>[BdfdTextAst('2')],
                <BdfdAstNode>[BdfdTextAst('BetaEdited')],
                <BdfdAstNode>[BdfdTextAst('success')],
                <BdfdAstNode>[BdfdTextAst('cmd_b_edited')],
                <BdfdAstNode>[BdfdTextAst('yes')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final buttons = components
          .where((c) => c['type'] == 'button')
          .toList(growable: false);
      // Row 1: Alpha (col 1), BetaEdited (col 2)
      // Row 2: Gamma (col 1)
      expect(buttons[0]['label'], 'Alpha');
      expect(buttons[1]['label'], 'BetaEdited');
      expect(buttons[1]['style'], 'success');
      expect(buttons[1]['customId'], 'cmd_b_edited');
      expect(buttons[1]['disabled'], true);
      expect(buttons[2]['label'], 'Gamma');
    });

    test(r'$editButton on a link-style button sets url not customId', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('https://old.example.com')],
                <BdfdAstNode>[BdfdTextAst('Visit')],
                <BdfdAstNode>[BdfdTextAst('link')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('1')],
                <BdfdAstNode>[BdfdTextAst('1')],
                <BdfdAstNode>[BdfdTextAst('Go')],
                <BdfdAstNode>[BdfdTextAst('link')],
                <BdfdAstNode>[BdfdTextAst('https://new.example.com')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final button = components.firstWhere((c) => c['type'] == 'button');
      expect(button['label'], 'Go');
      expect(button['url'], 'https://new.example.com');
      expect(button['customId'], '');
    });

    test(r'$editSelectMenu updates placeholder and disabled state', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$newSelectMenu',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_1')],
                <BdfdAstNode>[BdfdTextAst('Pick one')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editSelectMenu',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_1')],
                <BdfdAstNode>[BdfdTextAst('Updated placeholder')],
                <BdfdAstNode>[BdfdTextAst('2')],
                <BdfdAstNode>[BdfdTextAst('3')],
                <BdfdAstNode>[BdfdTextAst('yes')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final menu = components.firstWhere((c) => c['type'] == 'selectMenu');
      expect(menu['placeholder'], 'Updated placeholder');
      expect(menu['minValues'], 2);
      expect(menu['maxValues'], 3);
      expect(menu['disabled'], true);
    });

    test(
      r'$editSelectMenuOption updates the option at given 1-based index',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$newSelectMenu',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('menu_x')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addSelectMenuOption',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('Option A')],
                  <BdfdAstNode>[BdfdTextAst('val_a')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addSelectMenuOption',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('Option B')],
                  <BdfdAstNode>[BdfdTextAst('val_b')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$editSelectMenuOption',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('menu_x')],
                  <BdfdAstNode>[BdfdTextAst('2')],
                  <BdfdAstNode>[BdfdTextAst('Option B Edited')],
                  <BdfdAstNode>[BdfdTextAst('val_b_edited')],
                  <BdfdAstNode>[BdfdTextAst('A helpful description')],
                  <BdfdAstNode>[BdfdTextAst('yes')],
                  <BdfdAstNode>[BdfdTextAst('⭐')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        final components = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        final options = components
            .where((c) => c['type'] == 'selectMenuOption')
            .toList(growable: false);
        expect(options[0]['label'], 'Option A');
        expect(options[1]['label'], 'Option B Edited');
        expect(options[1]['value'], 'val_b_edited');
        expect(options[1]['description'], 'A helpful description');
        expect(options[1]['default'], true);
        expect(options[1]['emoji'], '⭐');
      },
    );

    test(r'$editSelectMenuOption with empty description clears the field', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$newSelectMenu',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_y')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addSelectMenuOption',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Opt')],
                <BdfdAstNode>[BdfdTextAst('v')],
                <BdfdAstNode>[BdfdTextAst('Original desc')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editSelectMenuOption',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_y')],
                <BdfdAstNode>[BdfdTextAst('1')],
                <BdfdAstNode>[],
                <BdfdAstNode>[],
                <BdfdAstNode>[BdfdTextAst('')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final opt = components.firstWhere((c) => c['type'] == 'selectMenuOption');
      expect(opt.containsKey('description'), isFalse);
    });
  });

  group('user/profile inline functions', () {
    test(r'$username without args resolves to ((user.username))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$username')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((user.username))');
    });

    test(r'$username[userID] resolves to ((user[id].username))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$username',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('123456')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((user[123456].username))');
    });

    test(r'$nickname without args resolves to ((member.nick))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$nickname')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((member.nick))');
    });

    test(r'$nickname[userID] resolves to ((member[id].nick))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$nickname',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('789')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((member[789].nick))');
    });

    test(r'$displayName without args resolves to fallback', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$displayName')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((member.nick|author.username))');
    });

    test(r'$displayName[userID] resolves to targeted fallback', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$displayName',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('456')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(
        embeds.single['description'],
        '((member[456].nick|user[456].username))',
      );
    });

    test(r'$authorAvatar resolves to ((author.avatar))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$authorAvatar')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((author.avatar))');
    });

    test(r'$authorID resolves to ((author.id))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$authorID')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((author.id))');
    });

    test(r'$findUser resolves to ((user.id))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$findUser')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((user.id))');
    });
  });
}
