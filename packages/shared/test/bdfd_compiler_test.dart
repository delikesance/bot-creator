import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
    test('compiles runtime variable placeholders and scoped vars', () {
      final result = BdfdCompiler().compile(
        r'Hello $username$setUserVar[lastAuthor;$authorID]$getUserVar[lastAuthor]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(
        result.actions.first.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(
        result.actions.first.payload['content'],
        'Hello ((user.username))',
      );
      expect(result.actions[1].type, BotCreatorActionType.setScopedVariable);
      expect(result.actions[1].payload['scope'], 'user');
      expect(result.actions[1].payload['key'], 'lastAuthor');
      expect(result.actions[1].payload['value'], '((author.id))');
      expect(result.actions[2].payload['content'], '((user.bc_lastAuthor))');
    });

    test('compiles message[] helper for normal/slash fallback', () {
      final result = BdfdCompiler().compile(
        r'$reply[$message[1;text]|$message[text]|$message[>]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(
        result.actions.single.payload['content'],
        '((message.content[0]|opts.text))|((opts.text))|((last(split(message.content, " "))))',
      );
    });

    test('compiles message helper without brackets', () {
      final result = BdfdCompiler().compile(r'$reply[$message]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(result.actions.single.payload['content'], '((message.content))');
    });

    test('compiles getTimestampMs as runtime placeholder', () {
      final result = BdfdCompiler().compile(r'$reply[$getTimestampMs]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));

      final raw = result.actions.single.payload['content']?.toString() ?? '';
      expect(raw, '((getTimestampMs))');

      // Verify it resolves to a current-ish timestamp at runtime.
      final resolved = resolveTemplatePlaceholders(raw, <String, String>{});
      final value = int.tryParse(resolved);
      expect(value, isNotNull);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      expect(value! >= now - 1000, isTrue);
      expect(value <= now + 1000, isTrue);
    });

    test(
      'resolves sub with getTimestampMs and messageTimestamp at runtime',
      () {
        final result = BdfdCompiler().compile(
          r'$reply[Latency: $sub[$getTimestampMs;$messageTimestamp] ms]',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final compiled =
            result.actions.single.payload['content']?.toString() ?? '';
        final messageTimestamp =
            DateTime.now().toUtc().millisecondsSinceEpoch - 25;
        final resolved = resolveTemplatePlaceholders(compiled, <String, String>{
          'message.timestamp': messageTimestamp.toString(),
        });

        final match = RegExp(r'^Latency: (\d+) ms$').firstMatch(resolved);
        expect(match, isNotNull);
        expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(0));
      },
    );

    test('resolves ping compiled to bot.ping at runtime', () {
      final result = BdfdCompiler().compile(r'$reply[Ping: $ping ms]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));

      final compiled =
          result.actions.single.payload['content']?.toString() ?? '';
      // Verify the compiled output contains bot.ping reference
      expect(compiled, contains('bot.ping'));

      final resolved = resolveTemplatePlaceholders(compiled, <String, String>{
        'bot.ping': '52',
      });

      expect(resolved, 'Ping: 52 ms');
    });

    test('compiles channelSendMessage helper', () {
      final result = BdfdCompiler().compile(
        r'$channelSendMessage[123456789012345678;Hello!]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['channelId'], '123456789012345678');
      expect(result.actions.single.payload['content'], 'Hello!');
    });

    test('compiles mentionedChannels helper', () {
      final result = BdfdCompiler().compile(
        r'$reply[$mentionedChannels[1]|$mentionedChannels[1;yes]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(
        result.actions.single.payload['content'],
        '((message.mentions[0]))|((message.mentions[0]|channel.id))',
      );
    });

    test('compiles user identity helper functions without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$reply[$authorAvatar|$authorID|$authorOfMessage|$creationDate|$discriminator|$displayName|$displayName[123]|$getUserStatus|$getCustomStatus|$isAdmin|$isBooster|$isBot|$isUserDMEnabled|$nickname|$nickname[123]|$userAvatar|$userBadges|$userBanner|$userBannerColor|$userExists|$userID|$userInfo|$userJoined|$userJoinedDiscord|$username|$username[123]|$userPerms|$userServerAvatar|$findUser]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final content =
          result.actions.single.payload['content']?.toString() ?? '';
      expect(content, contains('((author.avatar))'));
      expect(content, contains('((author.id))'));
      expect(content, contains('((member.permissions))'));
      expect(content, contains('((user.id))'));
    });

    test('compiles changeUsername and changeUsernameWithID helpers', () {
      final result = BdfdCompiler().compile(
        r'$changeUsername[NewName]'
        r'$changeUsernameWithID[1234567890;AnotherName]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.updateSelfUser);
      expect(result.actions[0].payload['username'], 'NewName');
      expect(result.actions[1].type, BotCreatorActionType.ifBlock);
    });

    test('surfaces unsupported functions as compile errors', () {
      final result = BdfdCompiler().compile(r'$totallyFakeFunction[$authorID]');

      expect(result.hasErrors, isTrue);
      expect(result.actions, isEmpty);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$totallyFakeFunction');
      expect(
        result.diagnostics.single.stage,
        BdfdCompileDiagnosticStage.transpiler,
      );
    });

    test('treats unresolved no-arg dollar token as literal text', () {
      final result = BdfdCompiler().compile(r'$reply[$test]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(result.actions.single.payload['content'], r'$test');
    });

    test('preserves nested unsupported text functions as warnings only', () {
      final result = BdfdCompiler().compile(
        r'$description[Hello $unknownFunction[test]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.diagnostics.single.severity,
        BdfdCompileDiagnosticSeverity.warning,
      );
    });

    test('compiles BDFD http helpers to httpRequest and placeholders', () {
      final result = BdfdCompiler().compile(
        r'$httpAddHeader[content-type;application/x-www-form-urlencoded]'
        r'$httpPost[https://pastebin.com/api/api_post.php;api_option=paste]'
        r'$reply[$httpStatus|$httpResult]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.type, BotCreatorActionType.httpRequest);
      expect(result.actions.first.payload['method'], 'POST');
      expect(result.actions.first.payload['bodyText'], 'api_option=paste');
      expect(result.actions.first.payload['headers'], {
        'content-type': 'application/x-www-form-urlencoded',
      });
      expect(
        result.actions.last.payload['content'],
        '((http.status))|((http.body))',
      );
    });

    test('surfaces httpStatus before request as compile error', () {
      final result = BdfdCompiler().compile(r'$reply[$httpStatus]');

      expect(result.hasErrors, isTrue);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$httpStatus');
    });

    test('compiles awaitFunc to scoped awaited registration action', () {
      final result = BdfdCompiler().compile(
        r'$reply[What do you want me to say?]$awaitFunc[say]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions.last.type, BotCreatorActionType.setScopedVariable);
      expect(result.actions.last.payload['scope'], 'user');
      expect(result.actions.last.payload['key'], 'await_say');
      expect(result.actions.last.payload['valueType'], 'json');
      expect(
        (result.actions.last.payload['jsonValue'] as String),
        contains('"name":"say"'),
      );
    });

    test('compiles block if/elseif/else/endif and logical conditions', () {
      final result = BdfdCompiler().compile(
        r'$if[$or[((score))>10;((isAdmin))==true]==true]'
        r'Gold\n'
        r'$elseif[((score))==10]'
        r'Silver\n'
        r'$else\n'
        r'Bronze\n'
        r'$endif',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.ifBlock);

      final payload = result.actions.single.payload;
      expect(payload['condition.group'], 'or');

      final elseIfConditions = List<Map<String, dynamic>>.from(
        payload['elseIfConditions'] as List,
      );
      expect(elseIfConditions, hasLength(1));
      expect(elseIfConditions.single['condition.operator'], 'equals');
    });

    test('compiles stop to stopUnless action', () {
      final result = BdfdCompiler().compile(r'$stop');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.stopUnless);
      expect(result.actions.single.payload['condition.variable'], '1');
      expect(result.actions.single.payload['condition.value'], '0');
    });

    test('compiles json helper workflow without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{}]'
        r'$jsonArray[scores]'
        r'$jsonArrayAppend[scores;5]'
        r'$jsonArrayAppend[scores;8]'
        r'$jsonArrayAppend[scores;10]'
        r'$reply[Count=$jsonArrayCount[scores]|Top=$json[ scores;1 ]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(result.actions.single.payload['content'], 'Count=3|Top=8');
    });

    test('compiles invalid jsonParse without blocking diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{invalid}]'
        r'$reply[Value=$json[user;name]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'Value=');
    });

    test('compiles thread helpers without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$startThread[Cool Thread;123;;1440;yes]'
        r'$editThread[12345;Cool Thread 😎;no;!unchanged;!unchanged;5]'
        r'$threadAddMember[12345;999]'
        r'$threadRemoveMember[12345;999]'
        r'$reply[Thread created: $startThread[Second Thread;123;;60;yes]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(7));
      expect(result.actions[0].type, BotCreatorActionType.createThread);
      expect(result.actions[1].type, BotCreatorActionType.updateChannel);
      expect(result.actions[2].type, BotCreatorActionType.addThreadMember);
      expect(result.actions[3].type, BotCreatorActionType.removeThreadMember);
      expect(result.actions[4].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[4].payload['content'], '((thread.lastId))');
      expect(result.actions[5].type, BotCreatorActionType.createThread);
      expect(result.actions[6].type, BotCreatorActionType.respondWithMessage);
      expect(
        result.actions[6].payload['content'],
        'Thread created: ((thread.lastId))',
      );
    });

    test('compiles guard helpers without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$onlyIf[((score))>=5;Need at least five points]'
        r'$onlyForUsers[Nicky;Jeremy;Not authorized]'
        r'$onlyForChannels[333;Wrong channel]'
        r"$ignoreChannels[444;555;❌ That command can't be used in this channel!]"
        r'$onlyNSFW[NSFW channel only]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(5));
      expect(
        result.actions.every(
          (action) => action.type == BotCreatorActionType.ifBlock,
        ),
        isTrue,
      );
      expect(result.actions[0].payload['condition.operator'], 'greaterOrEqual');
      expect(
        result.actions[4].payload['condition.variable'],
        '((channel.nsfw))',
      );

      final ignoreThenActions = List<Map<String, dynamic>>.from(
        result.actions[3].payload['thenActions'] as List,
      );
      expect(ignoreThenActions[0]['type'], 'respondWithMessage');
      expect(
        ignoreThenActions[0]['payload']['content'],
        "❌ That command can't be used in this channel!",
      );
    });

    test('compiles for loop blocks into repeated actions', () {
      final result = BdfdCompiler().compile(
        r'$for[2]'
        r'$reply[Loop]'
        r'$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[1].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[0].payload['content'], 'Loop');
      expect(result.actions[1].payload['content'], 'Loop');
    });

    test('compiles permission and role guards without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$onlyPerms[manageMessages;kickMembers;Missing perms]'
        r'$onlyBotPerms[manageRoles]'
        r'$onlyAdmin[Admins only]'
        r'$checkUserPerms[1234567890;banMembers;Denied]'
        r'$onlyForRoles[Moderator;Role required]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(5));
      expect(
        result.actions.every(
          (action) => action.type == BotCreatorActionType.ifBlock,
        ),
        isTrue,
      );

      final onlyPermsConditions = List<Map<String, dynamic>>.from(
        result.actions[0].payload['condition.conditions'] as List,
      );
      expect(onlyPermsConditions.first['variable'], '((member.permissions))');

      final onlyBotPermsConditions = List<Map<String, dynamic>>.from(
        result.actions[1].payload['condition.conditions'] as List,
      );
      expect(onlyBotPermsConditions.first['variable'], '((bot.permissions))');

      expect(result.actions[2].payload['condition.group'], 'or');

      final checkUserPermsConditions = List<Map<String, dynamic>>.from(
        result.actions[3].payload['condition.conditions'] as List,
      );
      expect(result.actions[3].payload['condition.group'], 'or');
      final checkUserPermsSelfBranch = List<Map<String, dynamic>>.from(
        checkUserPermsConditions.first['conditions'] as List,
      );
      expect(checkUserPermsSelfBranch.first['variable'], '((author.id))');
      expect(checkUserPermsSelfBranch.first['value'], '1234567890');
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

      final onlyForRolesConditions = List<Map<String, dynamic>>.from(
        result.actions[4].payload['condition.conditions'] as List,
      );
      expect(onlyForRolesConditions.single['group'], 'or');
    });

    test('supports checkUsersPerms alias', () {
      final result = BdfdCompiler().compile(
        r'$checkUserPerms[1234567890;administrator;Denied]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.ifBlock);

      final conditions = List<Map<String, dynamic>>.from(
        result.actions[0].payload['condition.conditions'] as List,
      );
      expect(result.actions[0].payload['condition.group'], 'or');
      expect(conditions[1]['conditions'][0]['value'], 'administrator');
    });

    test('compiles wave 3 guards without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$onlyForIDs[111;Denied ID]'
        r'$onlyForRoleIDs[222;Denied role id]'
        r'$onlyForServers[333;Wrong server]'
        r'$onlyForCategories[444;Wrong category]'
        r'$onlyBotChannelPerms[$channelID;manageMessages;Bot missing perms]'
        r'$onlyIfMessageContains[$message;Hello;Hi;Missing text]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(6));
      expect(
        result.actions.every(
          (action) => action.type == BotCreatorActionType.ifBlock,
        ),
        isTrue,
      );

      final onlyForIdsConditions = List<Map<String, dynamic>>.from(
        result.actions[0].payload['condition.conditions'] as List,
      );
      expect(onlyForIdsConditions.single['variable'], '((author.id))');

      final onlyForRoleIdsConditions = List<Map<String, dynamic>>.from(
        result.actions[1].payload['condition.conditions'] as List,
      );
      expect(onlyForRoleIdsConditions.single['variable'], '((member.roles))');

      final onlyForServersConditions = List<Map<String, dynamic>>.from(
        result.actions[2].payload['condition.conditions'] as List,
      );
      expect(onlyForServersConditions.single['variable'], '((guild.id))');

      final onlyForCategoriesConditions = List<Map<String, dynamic>>.from(
        result.actions[3].payload['condition.conditions'] as List,
      );
      expect(
        onlyForCategoriesConditions.single['variable'],
        '((channel.parentId))',
      );

      final onlyBotChannelPermsConditions = List<Map<String, dynamic>>.from(
        result.actions[4].payload['condition.conditions'] as List,
      );
      expect(
        onlyBotChannelPermsConditions.single['variable'],
        '((bot.permissions))',
      );

      expect(result.actions[5].payload['condition.group'], 'and');
      final onlyIfContainsConditions = List<Map<String, dynamic>>.from(
        result.actions[5].payload['condition.conditions'] as List,
      );
      expect(onlyIfContainsConditions[0]['variable'], '((message.content))');
      expect(onlyIfContainsConditions[0]['value'], '(?i).*Hello.*');
      expect(onlyIfContainsConditions[1]['value'], '(?i).*Hi.*');
    });

    test('accepts BDFD wiki permission tokens in checkUserPerms', () {
      final result = BdfdCompiler().compile(
        r'$checkUserPerms[1234567890;admin;ban;slashcommands;Denied]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));

      final conditions = List<Map<String, dynamic>>.from(
        result.actions.single.payload['condition.conditions'] as List,
      );
      expect(result.actions.single.payload['condition.group'], 'or');
      final byIdConditions = List<Map<String, dynamic>>.from(
        conditions[1]['conditions'] as List,
      );
      expect(byIdConditions, hasLength(3));
      expect(byIdConditions[0]['value'], 'administrator');
      expect(byIdConditions[1]['value'], 'banmembers');
      expect(byIdConditions[2]['value'], 'useapplicationcommands');
    });

    test('supports inline checkUserPerms in plain text script content', () {
      final result = BdfdCompiler().compile(
        'Admin perms?: \$checkUserPerms[1234567890;administrator]\n',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.ifBlock);
      expect(result.actions[1].type, BotCreatorActionType.respondWithMessage);

      final content = result.actions[1].payload['content']?.toString() ?? '';
      expect(content, startsWith('Admin perms?: '));
      expect(content, contains('((message.bc_check_user_perms_0))'));
    });

    test('supports checkUserPerms with option user id placeholder', () {
      final result = BdfdCompiler().compile(
        r'$checkUserPerms[((opts.user.id));administrator;Denied]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final conditions = List<Map<String, dynamic>>.from(
        result.actions.single.payload['condition.conditions'] as List,
      );
      expect(
        conditions[1]['conditions'][0]['variable'],
        'permissions.byId.((opts.user.id))',
      );
      expect(conditions[1]['conditions'][0]['value'], 'administrator');
    });

    test('supports userPerms with explicit user id placeholder', () {
      final result = BdfdCompiler().compile(
        r'$reply[Perms: $userPerms[$authorID]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final content =
          result.actions.single.payload['content']?.toString() ?? '';
      expect(
        content,
        contains('((permissions.byId.((author.id))|member.permissions))'),
      );
    });

    test('resolves loop computed variables \$i and \$loopCount', () {
      final result = BdfdCompiler().compile(
        r'$for[3]$reply[$i is $loopCount]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].payload['content'], '0 is 1');
      expect(result.actions[1].payload['content'], '1 is 2');
      expect(result.actions[2].payload['content'], '2 is 3');
    });

    test('resolves \$loopIndex as alias for \$i', () {
      final result = BdfdCompiler().compile(
        r'$for[2]$reply[index=$loopIndex]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].payload['content'], 'index=0');
      expect(result.actions[1].payload['content'], 'index=1');
    });

    test('restores loop index after nested loops', () {
      final result = BdfdCompiler().compile(
        r'$for[2]$reply[outer=$i]$for[2]$reply[inner=$i]$endfor$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(6));
      expect(result.actions[0].payload['content'], 'outer=0');
      expect(result.actions[1].payload['content'], 'inner=0');
      expect(result.actions[2].payload['content'], 'inner=1');
      expect(result.actions[3].payload['content'], 'outer=1');
      expect(result.actions[4].payload['content'], 'inner=0');
      expect(result.actions[5].payload['content'], 'inner=1');
    });

    test('inlines response-only loop body into pending embed', () {
      final result = BdfdCompiler().compile(
        r'$title[Test]$for[3]$addField[Item $loopCount;val $i;yes]$endfor$color[#FF0000]$footer[Done]',
      );

      expect(result.hasErrors, isFalse);
      // Should produce a SINGLE respondWithMessage action with all fields.
      expect(result.actions, hasLength(1));
      final payload = result.actions.single.payload;
      expect(payload['embeds'], isList);
      final embeds = payload['embeds'] as List;
      expect(embeds, hasLength(1));
      final embed = embeds[0] as Map<String, dynamic>;
      expect(embed['title'], 'Test');
      expect(embed['color'], '#FF0000');
      expect(embed['footer'], containsPair('text', 'Done'));
      final fields = embed['fields'] as List;
      expect(fields, hasLength(3));
      expect(fields[0]['name'], 'Item 1');
      expect(fields[0]['value'], 'val 0');
      expect(fields[1]['name'], 'Item 2');
      expect(fields[1]['value'], 'val 1');
      expect(fields[2]['name'], 'Item 3');
      expect(fields[2]['value'], 'val 2');
    });

    test('inlines json-mutation loop then reads results in embed', () {
      final result = BdfdCompiler().compile(
        r'$jsonClear$jsonArray[n]$for[5]$jsonArrayAppend[n;$i]$endfor$title[Count: $jsonArrayCount[n]]$description[$jsonJoinArray[n;-]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final embed =
          (result.actions.single.payload['embeds'] as List)[0]
              as Map<String, dynamic>;
      expect(embed['title'], 'Count: 5');
      expect(embed['description'], '0-1-2-3-4');
    });

    test('C-style for loop with single variable', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0; i < 5; i++]$reply[$i]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(5));
      expect(result.actions[0].payload['content'], '0');
      expect(result.actions[1].payload['content'], '1');
      expect(result.actions[4].payload['content'], '4');
    });

    test('C-style for loop with two variables', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0, j = 10; i <= 3; i++, j--]$reply[$i-$j]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].payload['content'], '0-10');
      expect(result.actions[1].payload['content'], '1-9');
      expect(result.actions[2].payload['content'], '2-8');
      expect(result.actions[3].payload['content'], '3-7');
    });

    test('C-style for loop with += and -= updates', () {
      final result = BdfdCompiler().compile(
        r'$for[x = 0; x < 20; x += 5]$reply[$x]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].payload['content'], '0');
      expect(result.actions[1].payload['content'], '5');
      expect(result.actions[2].payload['content'], '10');
      expect(result.actions[3].payload['content'], '15');
    });

    test('C-style for loop with decrement', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 5; i > 0; i--]$reply[$i]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(5));
      expect(result.actions[0].payload['content'], '5');
      expect(result.actions[1].payload['content'], '4');
      expect(result.actions[4].payload['content'], '1');
    });

    test('C-style for loop respects max iteration limit', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0; i < 9999; i++]$reply[$i]$endfor',
      );

      expect(result.hasErrors, isFalse);
      // Capped at 100
      expect(result.actions, hasLength(100));
    });

    test('C-style for loop inlines into embed response', () {
      final result = BdfdCompiler().compile(
        r'$title[Countdown]$for[i = 3; i >= 1; i--]$addField[Step $i;Go;no]$endfor$color[#00FF00]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final embed =
          (result.actions.single.payload['embeds'] as List)[0]
              as Map<String, dynamic>;
      expect(embed['title'], 'Countdown');
      expect(embed['color'], '#00FF00');
      final fields = embed['fields'] as List;
      expect(fields, hasLength(3));
      expect(fields[0]['name'], 'Step 3');
      expect(fields[1]['name'], 'Step 2');
      expect(fields[2]['name'], 'Step 1');
    });

    test('C-style for loop with condition comparing two variables', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0, j = 3; i < j; i++]$reply[$i]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].payload['content'], '0');
      expect(result.actions[1].payload['content'], '1');
      expect(result.actions[2].payload['content'], '2');
    });

    test('C-style for loop reports diagnostic for invalid init', () {
      final result = BdfdCompiler().compile(
        r'$for[badstuff; i < 5; i++]$reply[x]$endfor',
      );

      expect(result.hasErrors, isTrue);
      expect(result.actions, isEmpty);
    });

    test('nested C-style loop restores variables', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0; i < 2; i++]$reply[outer=$i]$for[j = 10; j < 12; j++]$reply[inner=$j]$endfor$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(6));
      expect(result.actions[0].payload['content'], 'outer=0');
      expect(result.actions[1].payload['content'], 'inner=10');
      expect(result.actions[2].payload['content'], 'inner=11');
      expect(result.actions[3].payload['content'], 'outer=1');
      expect(result.actions[4].payload['content'], 'inner=10');
      expect(result.actions[5].payload['content'], 'inner=11');
    });

    test('simple runtime loop emits forLoop action for dynamic iterations', () {
      final result = BdfdCompiler().compile(
        r'$for[$args[2]]$reply[hello]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.forLoop);
      expect(result.actions.single.payload['mode'], 'simple');
      expect(result.actions.single.payload['iterations'], contains('(('));
      final bodyActions = result.actions.single.payload['bodyActions'] as List;
      expect(bodyActions, hasLength(1));
    });

    test('simple runtime loop with \$loop alias', () {
      final result = BdfdCompiler().compile(
        r'$loop[$args[1]]$reply[hi]$endloop',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.forLoop);
      expect(result.actions.single.payload['mode'], 'simple');
    });

    test(
      'C-style runtime loop emits forLoop action when condition has placeholder',
      () {
        final result = BdfdCompiler().compile(
          r'$for[i=0;i<$args[2];i++]$reply[$i]$endfor',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        final action = result.actions.single;
        expect(action.type, BotCreatorActionType.forLoop);
        expect(action.payload['mode'], 'cstyle');
        expect(action.payload['init'], 'i=0');
        expect(action.payload['condition'], contains('(('));
        expect(action.payload['update'], 'i++');
        expect(action.payload['varNames'], contains('i'));
        final bodyActions = action.payload['bodyActions'] as List;
        expect(bodyActions, hasLength(1));
        // Body should contain loop variable placeholder.
        final bodyPayload = bodyActions[0] as Map;
        final content = (bodyPayload['payload'] as Map)['content'] as String;
        expect(content, contains('((_loop.var.i))'));
      },
    );

    test('C-style runtime loop with runtime init value', () {
      final result = BdfdCompiler().compile(
        r'$for[i=$args[0];i<$args[2];i++]$reply[$i]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final action = result.actions.single;
      expect(action.type, BotCreatorActionType.forLoop);
      expect(action.payload['mode'], 'cstyle');
      expect(action.payload['init'], contains('(('));
    });

    test('static loops still unrolled at compile-time (backward compat)', () {
      final result = BdfdCompiler().compile(r'$for[3]$reply[x]$endfor');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      // Should NOT be a forLoop action – should be unrolled.
      for (final action in result.actions) {
        expect(action.type, isNot(BotCreatorActionType.forLoop));
      }
    });

    test(
      'runtime loop body uses ((_loop.index)) and ((_loop.count)) placeholders',
      () {
        final result = BdfdCompiler().compile(
          r'$for[$args[0]]$reply[$i is $loopCount]$endfor',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        final action = result.actions.single;
        expect(action.type, BotCreatorActionType.forLoop);
        final bodyActions = action.payload['bodyActions'] as List;
        final content = (bodyActions[0] as Map)['payload']['content'] as String;
        expect(content, contains('((_loop.index))'));
        expect(content, contains('((_loop.count))'));
      },
    );
  });

  group('temporary variables via \$var', () {
    test('set and retrieve a temporary variable', () {
      final result = BdfdCompiler().compile(
        r'$var[name;World]Hello $var[name]!',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'Hello World!');
    });

    test('overwrite a temporary variable', () {
      final result = BdfdCompiler().compile(
        r'$var[x;first]$var[x;second]Value: $var[x]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'Value: second');
    });

    test('multiple independent temporary variables', () {
      final result = BdfdCompiler().compile(
        r'$var[a;1]$var[b;2]$var[a]+$var[b]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], '1+2');
    });

    test('unknown temp var falls back to runtime placeholder', () {
      final result = BdfdCompiler().compile(r'Value: $var[unknown]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        'Value: ((global.bc_unknown))',
      );
    });

    test('temp var set produces no visible output', () {
      final result = BdfdCompiler().compile(r'$var[x;hello]$var[x]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'hello');
    });

    test('temp var with computed value from inline function', () {
      final result = BdfdCompiler().compile(
        r'$var[upper;$toUpperCase[hello]]Result: $var[upper]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'Result: HELLO');
    });

    test(
      'runtime inline math stays dynamic and branch-local temp vars do not leak',
      () {
        final result = BdfdCompiler().compile(
          r'$if[$isbot[$authorID]==false]'
          '\n'
          r' $enabledecimals[yes]'
          '\n'
          r' $var[toadd;$multi[$charcount[$message];0.5]]'
          '\n'
          r' $channelSendMessage[$channelID;$message, charcount $charcount[$message], after mult $var[toadd]]'
          '\n'
          r' $if[$var[toadd]>15]'
          '\n'
          r'  $channelSendMessage[$channelID;over 15, clmaped]'
          '\n'
          r'  $var[toadd;15]'
          '\n'
          r' $endif'
          '\n'
          r' $channelSendMessage[$channelID;you have been given $var[toadd] xp]'
          '\n'
          r' $setUserVar[xp;$calculate[$getUserVar[xp]+$var[toadd]]]'
          '\n'
          r' $channelSendMessage[$channelID;new xp $getUserVar[xp]]'
          '\n'
          r'$endif',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        expect(result.actions.single.type, BotCreatorActionType.ifBlock);

        final thenActions = List<Map<String, dynamic>>.from(
              result.actions.single.payload['thenActions'] as List,
            )
            .map((json) => Action.fromJson(Map<String, dynamic>.from(json)))
            .toList(growable: false);
        expect(thenActions.map((action) => action.type), <BotCreatorActionType>[
          BotCreatorActionType.sendMessage,
          BotCreatorActionType.ifBlock,
          BotCreatorActionType.sendMessage,
          BotCreatorActionType.setScopedVariable,
          BotCreatorActionType.sendMessage,
        ]);

        final previewContent = thenActions[0].payload['content'] as String;
        expect(previewContent, contains('((charcount['));
        expect(previewContent, contains('((multi['));

        final runtimeVariables = <String, String>{
          'message.content': 'bzbd',
          'author.isBot': 'false',
        };
        expect(
          resolveTemplatePlaceholders(previewContent, runtimeVariables),
          'bzbd, charcount 4, after mult 2',
        );

        final clampCondition =
            thenActions[1].payload['condition.variable'] as String;
        expect(
          resolveTemplatePlaceholders(clampCondition, runtimeVariables),
          '2',
        );

        final awardContent = thenActions[2].payload['content'] as String;
        expect(
          resolveTemplatePlaceholders(awardContent, runtimeVariables),
          'you have been given 2 xp',
        );

        final setXpValue = thenActions[3].payload['value'] as String;
        final resolvedXp = resolveTemplatePlaceholders(
          setXpValue,
          runtimeVariables,
        );
        expect(resolvedXp, '2');

        runtimeVariables['user.bc_xp'] = resolvedXp;
        final newXpContent = thenActions[4].payload['content'] as String;
        expect(
          resolveTemplatePlaceholders(newXpContent, runtimeVariables),
          'new xp 2',
        );
      },
    );

    test(
      'runtime uppercase keeps placeholder keys intact until resolution',
      () {
        final result = BdfdCompiler().compile(
          r'$reply[$toUpperCase[$username]]',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final content = result.actions.single.payload['content'] as String;
        expect(content, '((touppercase[((user.username))]))');
        expect(
          resolveTemplatePlaceholders(content, <String, String>{
            'user.username': 'niek dev',
          }),
          'NIEK DEV',
        );
      },
    );
  });

  group(r'$callWorkflow', () {
    test('simple call with name only', () {
      final result = BdfdCompiler().compile(r'$callWorkflow[myFlow]');
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runWorkflow);
      expect(result.actions[0].payload['workflowName'], 'myFlow');
      expect(result.actions[0].payload.containsKey('arguments'), isFalse);
    });

    test('call with positional arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;hello;world]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['workflowName'], 'myFlow');
      expect(result.actions[0].payload['arguments'], {
        '1': 'hello',
        '2': 'world',
      });
    });

    test('call with key=value arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;user=Alice;count=3]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['arguments'], {
        'user': 'Alice',
        'count': '3',
      });
    });

    test('call with mixed positional and key=value arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;hello;key=val]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['arguments'], {
        '1': 'hello',
        'key': 'val',
      });
    });

    test('missing workflow name emits diagnostic', () {
      final result = BdfdCompiler().compile(r'$callWorkflow[]');
      expect(result.actions, isEmpty);
      expect(result.diagnostics, isNotEmpty);
    });

    test('arguments can use inline BDFD functions', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;$toUpperCase[hello]]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['arguments'], {'1': 'HELLO'});
    });
  });

  group(r'$workflowResponse', () {
    test('produces placeholder with property path', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow]'
        '\n'
        r'Result: $workflowResponse[status.code]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(
        result.actions[1].payload['content'],
        contains('((workflow.response.status.code))'),
      );
    });

    test('produces placeholder without arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow]'
        '\n'
        r'Result: $workflowResponse',
      );
      expect(result.diagnostics, isEmpty);
      expect(
        result.actions[1].payload['content'],
        contains('((workflow.response))'),
      );
    });

    test('emits diagnostic when no preceding callWorkflow', () {
      final result = BdfdCompiler().compile(
        r'Response: $workflowResponse[data]',
      );
      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.first.message,
        contains('requires a preceding'),
      );
    });

    test('tracks latest callWorkflow across multiple calls', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[flowA]'
        '\n'
        r'$callWorkflow[flowB]'
        '\n'
        r'Result: $workflowResponse[output]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(3));
      // Both callWorkflow actions have distinct keys
      expect(result.actions[0].key, '_bdfd_callworkflow_0');
      expect(result.actions[1].key, '_bdfd_callworkflow_1');
      expect(
        result.actions[2].payload['content'],
        contains('((workflow.response.output))'),
      );
    });

    test('can use inline function in property argument', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow]'
        '\n'
        r'$workflowResponse[$toUpperCase[key]]',
      );
      expect(result.diagnostics, isEmpty);
      expect(
        result.actions[1].payload['content'],
        contains('((workflow.response.KEY))'),
      );
    });
  });

  group(r'$eval', () {
    test('emits runBdfdScript action with script content', () {
      final result = BdfdCompiler().compile(r'$eval[$username]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
      expect(result.actions[0].payload['scriptContent'], r'((user.username))');
    });

    test('passes through runtime placeholders in script content', () {
      final result = BdfdCompiler().compile(r'$eval[((opts.script))]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
      expect(result.actions[0].payload['scriptContent'], '((opts.script))');
    });

    test('flushes pending response before eval', () {
      final result = BdfdCompiler().compile(
        'Hello\n'
        r'$eval[$username]',
      );
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[0].payload['content'], contains('Hello'));
      expect(result.actions[1].type, BotCreatorActionType.runBdfdScript);
    });

    test('eval with complex BDFD content', () {
      final result = BdfdCompiler().compile(r'$eval[$reply[Hello $username]]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
    });

    test('eval with empty argument', () {
      final result = BdfdCompiler().compile(r'$eval[]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
      expect(result.actions[0].payload['scriptContent'], '');
    });
  });

  group(r'$debug', () {
    test('emits debugProfile action', () {
      final result = BdfdCompiler().compile(r'$debug');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.debugProfile);
    });

    test('flushes pending response before debug', () {
      final result = BdfdCompiler().compile(
        'Hello\n'
        r'$debug',
      );
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[0].payload['content'], contains('Hello'));
      expect(result.actions[1].type, BotCreatorActionType.debugProfile);
    });

    test('produces correct action sequence with other functions', () {
      final result = BdfdCompiler().compile(
        r'$debug'
        '\n'
        r'$reply[pong]',
      );
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.debugProfile);
      expect(result.actions[1].type, BotCreatorActionType.respondWithMessage);
    });

    test('carries compilation timing metadata', () {
      final result = BdfdCompiler().compile(r'$debug');
      expect(result.hasErrors, isFalse);
      final debugAction = result.actions[0];
      expect(debugAction.payload['compilationMs'], isA<int>());
      expect(debugAction.payload['sourceLength'], equals(6));
      expect(debugAction.payload['actionCount'], equals(1));
    });

    test('loop actions carry iteration metadata', () {
      final result = BdfdCompiler().compile(
        r'$debug'
        '\n'
        r'$for[3]'
        '\n'
        r'  $channelSendMessage[$channelID;iter $i]'
        '\n'
        r'$endfor',
      );
      expect(result.hasErrors, isFalse);
      // debugProfile + 3 sendMessage
      expect(result.actions, hasLength(4));
      expect(result.actions[0].type, BotCreatorActionType.debugProfile);
      for (var i = 1; i <= 3; i++) {
        final a = result.actions[i];
        expect(a.type, BotCreatorActionType.sendMessage);
        expect(a.payload['_debugLoopDepth'], equals(1));
        expect(a.payload['_debugLoopIteration'], equals(i - 1));
      }
    });
  });
}
