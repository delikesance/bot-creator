import 'package:bot_creator/utils/i18n.dart';
import 'package:flutter/material.dart';

class BdfdCompatibleFunctionsPage extends StatefulWidget {
  const BdfdCompatibleFunctionsPage({super.key});

  @override
  State<BdfdCompatibleFunctionsPage> createState() =>
      _BdfdCompatibleFunctionsPageState();
}

class _BdfdCompatibleFunctionsPageState extends State<BdfdCompatibleFunctionsPage> {
  String _query = '';

  static const List<_FunctionCategory> _categories = [
    _FunctionCategory(
      titleKey: 'settings_compatibility_functions_category_guards',
      functions: [
        r'$onlyIf',
        r'$onlyForUsers',
        r'$onlyForIDs',
        r'$onlyForChannels',
        r'$ignoreChannels',
        r'$onlyNSFW',
        r'$onlyPerms',
        r'$onlyBotPerms',
        r'$onlyBotChannelPerms',
        r'$onlyAdmin',
        r'$checkUserPerms',
        r'$onlyForRoles',
        r'$onlyForRoleIDs',
        r'$onlyForServers',
        r'$onlyForCategories',
        r'$onlyIfMessageContains',
      ],
    ),
    _FunctionCategory(
      titleKey: 'settings_compatibility_functions_category_control',
      functions: [
        r'$if',
        r'$elseif',
        r'$else',
        r'$endif',
        r'$and',
        r'$or',
        r'$stop',
        r'$for',
        r'$loop',
        r'$endfor',
        r'$endloop',
      ],
    ),
    _FunctionCategory(
      titleKey: 'settings_compatibility_functions_category_messages',
      functions: [
        r'$reply',
        r'$sendMessage',
        r'$channelSendMessage',
        r'$message',
        r'$message[]',
        r'$mentionedChannels',
        r'$nomention',
      ],
    ),
    _FunctionCategory(
      titleKey: 'settings_compatibility_functions_category_embeds',
      functions: [
        r'$title',
        r'$description',
        r'$color',
        r'$footer',
        r'$thumbnail',
        r'$image',
        r'$author',
        r'$addField',
      ],
    ),
    _FunctionCategory(
      titleKey: 'settings_compatibility_functions_category_json',
      functions: [
        r'$jsonParse',
        r'$json',
        r'$jsonSet',
        r'$jsonSetString',
        r'$jsonUnset',
        r'$jsonClear',
        r'$jsonExists',
        r'$jsonStringify',
        r'$jsonPretty',
        r'$jsonArray',
        r'$jsonArrayCount',
        r'$jsonArrayIndex',
        r'$jsonArrayAppend',
        r'$jsonArrayPop',
        r'$jsonArrayShift',
        r'$jsonArrayUnshift',
        r'$jsonArraySort',
        r'$jsonArrayReverse',
        r'$jsonJoinArray',
      ],
    ),
    _FunctionCategory(
      titleKey: 'settings_compatibility_functions_category_http',
      functions: [
        r'$httpAddHeader',
        r'$httpGet',
        r'$httpPost',
        r'$httpPut',
        r'$httpDelete',
        r'$httpPatch',
        r'$httpStatus',
        r'$httpResult',
      ],
    ),
    _FunctionCategory(
      titleKey: 'settings_compatibility_functions_category_variables',
      functions: [
        r'$setUserVar',
        r'$setServerVar',
        r'$setGuildVar',
        r'$setChannelVar',
        r'$setMemberVar',
        r'$setGuildMemberVar',
        r'$setMessageVar',
        r'$getUserVar',
        r'$getServerVar',
        r'$getGuildVar',
        r'$getChannelVar',
        r'$getMemberVar',
        r'$getGuildMemberVar',
        r'$getMessageVar',
        r'$changeUsername',
        r'$changeUsernameWithID',
      ],
    ),
    _FunctionCategory(
      titleKey: 'settings_compatibility_functions_category_threads',
      functions: [
        r'$startThread',
        r'$editThread',
        r'$threadAddMember',
        r'$threadRemoveMember',
      ],
    ),
    _FunctionCategory(
      titleKey: 'settings_compatibility_functions_category_runtime',
      functions: [
        r'$userID',
        r'$username',
        r'$userTag',
        r'$userAvatar',
        r'$userBanner',
        r'$authorID',
        r'$authorOfMessage',
        r'$authorUsername',
        r'$authorTag',
        r'$authorAvatar',
        r'$authorBanner',
        r'$creationDate',
        r'$discriminator',
        r'$displayName',
        r'$displayName[]',
        r'$getUserStatus',
        r'$getCustomStatus',
        r'$isAdmin',
        r'$isBooster',
        r'$isBot',
        r'$isUserDMEnabled',
        r'$nickname',
        r'$nickname[]',
        r'$memberID',
        r'$memberNick',
        r'$userBadges',
        r'$userBannerColor',
        r'$userExists',
        r'$userInfo',
        r'$userJoined',
        r'$userJoinedDiscord',
        r'$userPerms',
        r'$userServerAvatar',
        r'$findUser',
        r'$guildID',
        r'$guildName',
        r'$guildIcon',
        r'$guildCount',
        r'$memberCount',
        r'$serverID',
        r'$serverName',
        r'$serverIcon',
        r'$channelID',
        r'$channelName',
        r'$channelType',
        r'$commandName',
        r'$commandType',
        r'$awaitFunc',
      ],
    ),
  ];

    static final Map<String, String> _botCreatorSupportedMap =
      _buildBotCreatorSupportedMap();
    static final Map<String, String> _bdfdReferenceMap =
      _buildBdfdReferenceMap();

    static final Set<String> _botCreatorSupported =
      _botCreatorSupportedMap.keys.toSet();
    static final Set<String> _bdfdReference = _bdfdReferenceMap.keys.toSet();

  List<String> _filtered(List<String> values) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return values;
    }
    return values.where((value) => value.toLowerCase().contains(query)).toList();
  }

  List<String> _sortedFromMap(Set<String> keys, Map<String, String> source) {
    final list = keys
        .map((key) => source[key] ?? key)
        .toSet()
        .toList(growable: false);
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Map<String, String> _buildBotCreatorSupportedMap() {
    final map = <String, String>{};
    for (final category in _categories) {
      for (final function in category.functions) {
        final canonical = _canonicalFunctionName(function);
        map.putIfAbsent(canonical, () => function);
      }
    }
    return map;
  }

  static Map<String, String> _parseFunctionMap(String raw) {
    final map = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith(r'$')) {
        continue;
      }
      final canonical = _canonicalFunctionName(trimmed);
      map.putIfAbsent(canonical, () => trimmed);
    }
    return map;
  }

  static Map<String, String> _buildBdfdReferenceMap() {
    final map = _parseFunctionMap(_bdfdReferenceRaw);
    for (final rawName in _forceBothSupportFunctions) {
      final canonical = _canonicalFunctionName(rawName);
      map.putIfAbsent(canonical, () => rawName);
    }
    return map;
  }

  static String _canonicalFunctionName(String raw) {
    var value = raw.trim().toLowerCase();
    if (!value.startsWith(r'$')) {
      value = '\$$value';
    }
    if (value.endsWith('[]')) {
      value = value.substring(0, value.length - 2);
    }
    return _canonicalAliases[value] ?? value;
  }

  @override
  Widget build(BuildContext context) {
    final supportedByBoth = _sortedFromMap(
      _botCreatorSupported.intersection(_bdfdReference),
      _botCreatorSupportedMap,
    );
    final botCreatorOnly = _sortedFromMap(
      _botCreatorSupported.difference(_bdfdReference),
      _botCreatorSupportedMap,
    );
    final missingInBotCreator = _sortedFromMap(
      _bdfdReference.difference(_botCreatorSupported),
      _bdfdReferenceMap,
    );

    final visibleBoth = _filtered(supportedByBoth);
    final visibleBotOnly = _filtered(botCreatorOnly);
    final visibleMissing = _filtered(missingInBotCreator);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('settings_compatibility_functions_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.t('settings_compatibility_functions_matrix_subtitle'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.tr('settings_compatibility_functions_count_bot_creator', params: {
                      'count': _botCreatorSupported.length.toString(),
                    }),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.tr('settings_compatibility_functions_count_bdfd', params: {
                      'count': _bdfdReference.length.toString(),
                    }),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.tr('settings_compatibility_functions_count_both', params: {
                      'count': supportedByBoth.length.toString(),
                    }),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.tr('settings_compatibility_functions_count_missing', params: {
                      'count': missingInBotCreator.length.toString(),
                    }),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.tr('settings_compatibility_functions_count_bot_only', params: {
                      'count': botCreatorOnly.length.toString(),
                    }),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: AppStrings.t('settings_compatibility_functions_search_hint'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.t('settings_compatibility_functions_matrix_note'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StatusSectionCard(
            title: AppStrings.t('settings_compatibility_functions_section_both'),
            color: Theme.of(context).colorScheme.primaryContainer,
            textColor: Theme.of(context).colorScheme.onPrimaryContainer,
            functions: visibleBoth,
          ),
          const SizedBox(height: 12),
          _StatusSectionCard(
            title: AppStrings.t('settings_compatibility_functions_section_bot_only'),
            color: Theme.of(context).colorScheme.tertiaryContainer,
            textColor: Theme.of(context).colorScheme.onTertiaryContainer,
            functions: visibleBotOnly,
            subtitle: AppStrings.t('settings_compatibility_functions_section_bot_only_note'),
          ),
          const SizedBox(height: 12),
          _StatusSectionCard(
            title: AppStrings.t('settings_compatibility_functions_section_missing'),
            color: Theme.of(context).colorScheme.errorContainer,
            textColor: Theme.of(context).colorScheme.onErrorContainer,
            functions: visibleMissing,
          ),
        ],
      ),
    );
  }
}

class _StatusSectionCard extends StatelessWidget {
  const _StatusSectionCard({
    required this.title,
    required this.color,
    required this.textColor,
    required this.functions,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Color color;
  final Color textColor;
  final List<String> functions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title (${functions.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (functions.isEmpty)
              Text(
                AppStrings.t('settings_compatibility_functions_empty'),
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: functions
                    .map(
                      (function) => Chip(
                        backgroundColor: color,
                        labelStyle: TextStyle(color: textColor),
                        label: Text(function),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _FunctionCategory {
  const _FunctionCategory({required this.titleKey, required this.functions});

  final String titleKey;
  final List<String> functions;
}

const String _bdfdReferenceRaw = r'''
Introduction
$addButton
$addSelectMenuOption
$addSeparator
$addTextDisplay
$addTextInput
$editButton
$editSelectMenu
$editSelectMenuOption
$newModal
$newSelectMenu
$removeAllComponents
$removeAllComponents[]
$removeButtons
$removeButtons[]
$removeComponent
$defer
$input
$addContainer
$addField
$addSection
$addThumbnail
$addTimestamp
$addTimestamp[]
$author
$authorIcon
$authorURL
$color
$description
$embeddedURL
$footer
$footerIcon
$image
$thumbnail
$title
$authorAvatar
$authorID
$authorOfMessage
$creationDate
$discriminator
$displayName
$displayName[]
$getUserStatus
$getCustomStatus
$isAdmin
$isBooster
$isBot
$isUserDMEnabled
$nickname
$nickname[]
$userAvatar
$userBadges
$userBanner
$userBannerColor
$userExists
$userID
$userInfo
$userJoined
$userJoinedDiscord
$username
$username[]
$userPerms
$userServerAvatar
$changeUsername
$changeUsernameWithID
$findUser
$ban
$ban[]
$banID
$banID[]
$clear
$clear[]
$getBanReason
$isBanned
$isTimedOut
$kick
$kick[]
$kickMention
$mute
$timeout
$unban
$unbanID
$unbanID[]
$unmute
$untimeout
$afkChannelID
$categoryChannels
$categoryCount
$categoryCount[]
$categoryID
$channelCount
$channelExists
$channelID
$channelID[]
$channelIDFromName
$channelName
$channelNames
$channelPosition
$channelPosition[]
$channelTopic
$channelTopic[]
$channelType
$createChannel
$deleteChannels
$deleteChannelsByName
$dmChannelID
$editChannelPerms
$findChannel
$getSlowmode
$isNSFW
$closeTicket
$isTicket
$newTicket
$lastMessageID
$lastPinTimestamp
$modifyChannel
$modifyChannelPerms
$parentID
$parentID[]
$rulesChannelID
$serverChannelExists
$slowmode
$systemChannelID
$voiceUserLimit
$allowRoleMentions
$colorRole
$createRole
$deleteRole
$findRole
$getRoleColor
$giveRole
$hasRole
$highestRole
$highestRole[]
$highestRoleWithPerms
$isHoisted
$isMentionable
$lowestRole
$lowestRole[]
$lowestRoleWithPerms
$mentionedRoles
$modifyRole
$modifyRolePerms
$roleCount
$roleExists
$roleGrant
$roleID
$roleInfo
$roleName
$roleNames
$rolePerms
$rolePosition
$setUserRoles
$takeRole
$userRoles
$allMembersCount
$awaitFunc
$botCommands
$botID
$botLeave
$botLeave[]
$botListDescription
$botListHide
$botNode
$botOwnerID
$botTyping
$commandFolder
$commandName
$commandTrigger
$commandsCount
$customID
$deletecommand
$enabled
$getBotInvite
$nodeVersion
$nodeVersion[]
$ping
$registerGuildCommands
$registerGuildCommands[]
$scriptLanguage
$shardID
$shardID[]
$slashCommandsCount
$slashID
$slashID[]
$serverCount
$serverNames
$serverNames[]
$executionTime
$unregisterGuildCommands
$unregisterGuildCommands[]
$uptime
$eval
$afkTimeout
$boostCount
$boostCount[]
$boostLevel
$getServerInvite
$getServerInvite[]
$getInviteInfo
$guildBanner
$guildExists
$guildID
$guildID[]
$hypesquad
$membersCount
$membersCount[]
$serverDescription
$serverDescription[]
$serverEmojis
$serverIcon
$serverIcon[]
$serverInfo
$serverName
$serverOwner
$serverOwner[]
$serverRegion
$serverVerificationLvl
$blackListIDs
$blackListRoles
$blackListRolesIDs
$blackListServers
$blackListUsers
$argCount
$argsCheck
$and
$checkCondition
$checkContains
$else
$elseif
$endif
$if
$isBoolean
$isInteger
$isNumber
$isSlash
$isValidHex
$or
$alternativeParsing
$byteCount
$c
$charCount
$cropText
$disableInnerSpaceRemoval
$disableSpecialEscaping
$editSplitText
$getTextSplitIndex
$getTextSplitLength
$joinSplitText
$mentionedChannels
$linesCount
$numberSeparator
$removeContains
$removeSplitTextElement
$repeatMessage
$replaceText
$splitText
$textSplit
$toLowercase
$toTitleCase
$toUppercase
$trimContent
$trimSpace
$unescape
$calculate
$ceil
$divide
$floor
$max
$min
$modulo
$multi
$round
$sort
$sqrt
$sub
$sum
$enableDecimals
$optOff
$random
$random[]
$randomCategoryID
$randomChannelID
$randomGuildID
$randomMention
$randomRoleID
$randomString
$randomText
$randomUser
$randomUserID
$date
$day
$getTimestamp
$getTimestamp[]
$hour
$hostingExpireTime
$hostingExpireTime[]
$messageEditedTimestamp
$minute
$month
$premiumExpireTime
$second
$time
$year
$changeCooldownTime
$cooldown
$getCooldown
$globalCooldown
$serverCooldown
$allowMention
$allowUserMentions
$channelSendMessage
$deleteIn
$deleteMessage
$dm
$dm[]
$editEmbedIn
$editIn
$editMessage
$ephemeral
$isMentioned
$mentioned
$nomention
$getAttachments
$getEmbedData
$getMessage
$isMessageEdited
$ignoreLinks
$message
$message[]
$messageID
$pinMessage
$pinMessage[]
$publishMessage
$reply
$reply[]
$replyIn
$repliedMessageID
$repliedMessageID[]
$removeLinks
$removeLinks[]
$noMentionMessage
$noMentionMessage[]
$sendEmbedMessage
$sendMessage
$unpinMessage
$useChannel
$tts
$url
$getChannelVar
$getLeaderboardPosition
$getLeaderboardValue
$getServerVar
$getUserVar
$getVar
$globalUserLeaderboard
$resetChannelVar
$resetServerVar
$resetUserVar
$serverLeaderboard
$setChannelVar
$setServerVar
$setUserVar
$setVar
$userLeaderboard
$var
$varExistError
$varExists
$variablesCount
$editThread
$startThread
$threadAddMember
$threadMessageCount
$threadRemoveMember
$threadUserCount
$addCmdReactions
$addMessageReactions
$addReactions
$clearReactions
$getReactions
$userReacted
$addEmoji
$customEmoji
$emoteCount
$emojiExists
$emojiName
$isEmojiAnimated
$removeEmoji
$webhookAvatarURL
$webhookColor
$webhookCreate
$webhookDelete
$webhookDescription
$webhookFooter
$webhookSend
$webhookTitle
$webhookUsername
$webhookContent
$catch
$endtry
$error
$suppressErrors
$suppressErrors[]
$try
$stop
$embedSuppressErrors
$checkUserPerms
$ignoreChannels
$onlyAdmin
$onlyBotChannelPerms
$onlyBotPerms
$onlyForCategories
$onlyForChannels
$onlyForIDs
$onlyForRoles
$onlyForRoleIDs
$onlyForServers
$onlyForUsers
$onlyIf
$onlyIfMessageContains
$onlyNSFW
$onlyPerms
''';

const Map<String, String> _canonicalAliases = <String, String>{
  r'$checkusersperms': r'$checkuserperms',
};

const Set<String> _forceBothSupportFunctions = <String>{
  r'$httpAddHeader',
  r'$httpGet',
  r'$httpPost',
  r'$httpPut',
  r'$httpDelete',
  r'$httpPatch',
  r'$httpStatus',
  r'$httpResult',
  r'$jsonParse',
  r'$json',
  r'$jsonSet',
  r'$jsonSetString',
  r'$jsonUnset',
  r'$jsonClear',
  r'$jsonExists',
  r'$jsonStringify',
  r'$jsonPretty',
  r'$jsonArray',
  r'$jsonArrayCount',
  r'$jsonArrayIndex',
  r'$jsonArrayAppend',
  r'$jsonArrayPop',
  r'$jsonArrayShift',
  r'$jsonArrayUnshift',
  r'$jsonArraySort',
  r'$jsonArrayReverse',
  r'$jsonJoinArray',
};
