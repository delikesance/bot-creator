import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
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
      expect(result.actions.single.type, BotCreatorActionType.respondWithMessage);
      expect(
        result.actions.single.payload['content'],
        '((message.content[0]|opts.text))|((opts.text))|((last(split(message.content, " "))))',
      );
    });

    test('compiles message helper without brackets', () {
      final result = BdfdCompiler().compile(r'$reply[$message]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.respondWithMessage);
      expect(result.actions.single.payload['content'], '((message.content))');
    });

    test('compiles channelSendMessage helper', () {
      final result = BdfdCompiler().compile(
        r'$channelSendMessage[123456789012345678;Hello!]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(
        result.actions.single.payload['channelId'],
        '123456789012345678',
      );
      expect(result.actions.single.payload['content'], 'Hello!');
    });

    test('compiles mentionedChannels helper', () {
      final result = BdfdCompiler().compile(
        r'$reply[$mentionedChannels[1]|$mentionedChannels[1;yes]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.respondWithMessage);
      expect(
        result.actions.single.payload['content'],
        '((message.mentions[0]))|((message.mentions[0]|channel.id))',
      );
    });

    test('compiles user identity helper functions without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$reply[$authorAvatar|$authorID|$authorOfMessage|$creationDate|$discriminator|$displayName|$displayName[123]|$getUserStatus|$getCustomStatus|$isAdmin|$isBooster|$isBot|$isUserDMEnabled|$nickname|$nickname[123]|$userAvatar|$userBadges|$userBanner|$userBannerColor|$userExists|$userID|$userInfo|$userJoined|$userJoinedDiscord|$username|$username[123]|$userPerms|$userServerAvatar|$findUser]'
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final content = result.actions.single.payload['content']?.toString() ?? '';
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
      final result = BdfdCompiler().compile(r'$ban[$authorID]');

      expect(result.hasErrors, isTrue);
      expect(result.actions, isEmpty);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$ban');
      expect(
        result.diagnostics.single.stage,
        BdfdCompileDiagnosticStage.transpiler,
      );
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
        r'$ignoreChannels[444;555;❌ That command can\'t be used in this channel!]'
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
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.ifBlock);
      expect(result.actions[1].type, BotCreatorActionType.ifBlock);

      final firstConditions = List<Map<String, dynamic>>.from(
        result.actions[0].payload['condition.conditions'] as List,
      );
      final secondConditions = List<Map<String, dynamic>>.from(
        result.actions[1].payload['condition.conditions'] as List,
      );
      expect(firstConditions[1]['conditions'][0]['value'], 'administrator');
      expect(secondConditions[1]['conditions'][0]['value'], 'administrator');
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
  });
}
