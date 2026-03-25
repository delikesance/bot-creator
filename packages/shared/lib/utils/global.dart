import 'package:nyxx/nyxx.dart';

import 'command_autocomplete.dart';

const String discordUrl = "https://discord.com/api/v10";
const Duration runtimeFetchCacheTtl = Duration(seconds: 20);

class _RuntimeCacheEntry<T> {
  const _RuntimeCacheEntry({required this.value, required this.expiresAt});

  final T value;
  final DateTime expiresAt;
}

final Map<String, _RuntimeCacheEntry<User>> _runtimeUserCache =
    <String, _RuntimeCacheEntry<User>>{};
final Map<String, _RuntimeCacheEntry<Member>> _runtimeMemberCache =
    <String, _RuntimeCacheEntry<Member>>{};
final Map<String, _RuntimeCacheEntry<Guild>> _runtimeGuildCache =
    <String, _RuntimeCacheEntry<Guild>>{};
final Map<String, _RuntimeCacheEntry<Channel>> _runtimeChannelCache =
    <String, _RuntimeCacheEntry<Channel>>{};

T? _runtimeCacheGet<T>(Map<String, _RuntimeCacheEntry<T>> cache, String key) {
  final entry = cache[key];
  if (entry == null) {
    return null;
  }
  if (entry.expiresAt.isBefore(DateTime.now())) {
    cache.remove(key);
    return null;
  }
  return entry.value;
}

void _runtimeCacheSet<T>(
  Map<String, _RuntimeCacheEntry<T>> cache,
  String key,
  T value,
) {
  cache[key] = _RuntimeCacheEntry<T>(
    value: value,
    expiresAt: DateTime.now().add(runtimeFetchCacheTtl),
  );
}

Future<T?> _runtimeFetchWithCache<T>({
  required Map<String, _RuntimeCacheEntry<T>> cache,
  required String key,
  required Future<T?> Function() fetch,
}) async {
  final cached = _runtimeCacheGet(cache, key);
  if (cached != null) {
    return cached;
  }

  final fetched = await fetch();
  if (fetched != null) {
    _runtimeCacheSet(cache, key, fetched);
  }
  return fetched;
}

Snowflake? _asSnowflake(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Snowflake) {
    return value;
  }
  if (value is int) {
    return Snowflake(value);
  }
  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<User?> _fetchUserCached(dynamic client, Snowflake userId) async {
  return _runtimeFetchWithCache<User>(
    cache: _runtimeUserCache,
    key: userId.toString(),
    fetch: () async {
      try {
        final fetched = await client.users.fetch(userId);
        return fetched is User ? fetched : null;
      } catch (_) {
        return null;
      }
    },
  );
}

Future<Member?> _fetchMemberCached(
  Interaction interaction, {
  required Snowflake guildId,
  required Snowflake userId,
}) async {
  final cacheKey = '${guildId.toString()}:${userId.toString()}';
  return _runtimeFetchWithCache<Member>(
    cache: _runtimeMemberCache,
    key: cacheKey,
    fetch: () async {
      try {
        final dynamic guild = (interaction as dynamic).guild;
        final fetched = await guild?.members?.fetch(userId);
        if (fetched is Member) {
          return fetched;
        }
      } catch (_) {}

      try {
        final dynamic client = interaction.manager.client;
        final dynamic guild = await client.guilds.fetch(guildId);
        final fetched = await guild?.members?.fetch(userId);
        if (fetched is Member) {
          return fetched;
        }
      } catch (_) {}

      return null;
    },
  );
}

Future<Guild?> _fetchGuildCached(dynamic client, Snowflake guildId) async {
  return _runtimeFetchWithCache<Guild>(
    cache: _runtimeGuildCache,
    key: guildId.toString(),
    fetch: () async {
      try {
        final dynamic fetched = await client.guilds.fetch(
          guildId,
          withCounts: true,
        );
        if (fetched is Guild) {
          return fetched;
        }
      } catch (_) {}

      try {
        final dynamic fetched = await client.guilds.fetch(guildId);
        if (fetched is Guild) {
          return fetched;
        }
      } catch (_) {}
      return null;
    },
  );
}

Future<Channel?> _fetchChannelCached(
  dynamic client,
  Snowflake channelId,
) async {
  return _runtimeFetchWithCache<Channel>(
    cache: _runtimeChannelCache,
    key: channelId.toString(),
    fetch: () async {
      try {
        final fetched = await client.channels.fetch(channelId);
        return fetched is Channel ? fetched : null;
      } catch (_) {
        return null;
      }
    },
  );
}

Future<User> getDiscordUser(String botToken) async {
  try {
    final client = await Nyxx.connectRest(botToken);
    return await client.user.fetch();
  } catch (e) {
    throw Exception("Failed to fetch user: $e");
  }
}

String makeAvatarUrl(
  String userId, {
  String? avatarId,
  bool isAnimated = false,
  String legacyFormat = "webp",
  String? discriminator,
}) {
  if (avatarId == null || avatarId.isEmpty) {
    if (discriminator != null) {
      return "https://cdn.discordapp.com/embed/avatars/${int.parse(discriminator) % 5}.png";
    }
    return "https://cdn.discordapp.com/embed/avatars/${(int.parse(userId) >> 22) % 6}.png";
  }
  if (isAnimated && legacyFormat == "gif") {
    return "https://cdn.discordapp.com/avatars/$userId/$avatarId.gif?size=1024";
  }

  if (avatarId == "0") {
    if (discriminator != null) {
      return "https://cdn.discordapp.com/embed/avatars/${int.parse(discriminator) % 5}.png";
    }
    return "https://cdn.discordapp.com/embed/avatars/${(int.parse(userId) >> 22) % 6}.png";
  }
  return "https://cdn.discordapp.com/avatars/$userId/$avatarId.$legacyFormat?size=1024";
}

String makeBannerUrl(
  String userId, {
  String? bannerId,
  bool isAnimated = false,
  String legacyFormat = "webp",
}) {
  if (bannerId == null || bannerId.isEmpty || bannerId == '0') {
    return '';
  }

  if (isAnimated && legacyFormat == 'gif') {
    return "https://cdn.discordapp.com/banners/$userId/$bannerId.gif?size=1024";
  }

  return "https://cdn.discordapp.com/banners/$userId/$bannerId.$legacyFormat?size=1024";
}

String makeGuildIcon(String guildId, String? iconId) {
  if (guildId == "DM" || iconId == null || iconId.isEmpty) {
    return "https://cdn.discordapp.com/embed/avatars/0.png";
  }
  return "https://cdn.discordapp.com/icons/$guildId/$iconId.webp?size=1024";
}

Map<String, String> extractChannelRuntimeDetails(dynamic channel) {
  if (channel == null) {
    return const <String, String>{};
  }

  final details = <String, String>{
    'channel.kind': channel.runtimeType.toString(),
  };

  void _trySet(String key, Object? Function() accessor) {
    try {
      final value = accessor();
      final str = (value ?? '').toString();
      if (str.isNotEmpty) {
        details[key] = str;
      }
    } catch (_) {
      // Property not available on this channel type — skip.
    }
  }

  _trySet('channel.topic', () => channel.topic);
  _trySet('channel.parentId', () => _asSnowflake(channel.parentId));
  _trySet('channel.position', () => channel.position);
  _trySet('channel.nsfw', () => ((channel.isNsfw ?? false) == true).toString());
  _trySet('channel.slowmode', () => channel.rateLimitPerUser);
  _trySet('channel.bitrate', () => channel.bitrate);
  _trySet('channel.userLimit', () => channel.userLimit);
  _trySet('channel.categoryId', () => _asSnowflake(channel.parentId));
  _trySet(
    'channel.thread.archived',
    () => ((channel.isArchived ?? false) == true).toString(),
  );
  _trySet(
    'channel.thread.locked',
    () => ((channel.isLocked ?? false) == true).toString(),
  );
  _trySet('channel.thread.ownerId', () => _asSnowflake(channel.ownerId));
  _trySet(
    'channel.thread.autoArchiveDuration',
    () => channel.autoArchiveDuration,
  );

  return details;
}

Map<String, String> extractGuildRuntimeDetails(dynamic guild) {
  if (guild == null) {
    return const <String, String>{};
  }

  final details = <String, String>{'guild.kind': guild.runtimeType.toString()};

  void _trySet(String key, Object? Function() accessor) {
    try {
      final value = accessor();
      final str = (value ?? '').toString();
      if (str.isNotEmpty) {
        details[key] = str;
      }
    } catch (_) {
      // Property not available on this guild type — skip.
    }
  }

  List<String> featureList = const <String>[];
  try {
    final featuresRaw = guild.features;
    if (featuresRaw is Iterable) {
      featureList = featuresRaw
          .map((value) => value.toString())
          .toList(growable: false);
    }
  } catch (_) {}

  _trySet('guild.ownerId', () => _asSnowflake(guild.ownerId));
  _trySet('guild.description', () => guild.description);
  _trySet('guild.vanityUrlCode', () => guild.vanityUrlCode);
  _trySet('guild.preferredLocale', () => guild.preferredLocale);
  _trySet('guild.verificationLevel', () => guild.verificationLevel);
  _trySet('guild.mfaLevel', () => guild.mfaLevel);
  _trySet('guild.nsfwLevel', () => guild.nsfwLevel);
  _trySet('guild.premiumTier', () => guild.premiumTier);
  _trySet(
    'guild.premiumSubscriptionCount',
    () => guild.premiumSubscriptionCount,
  );
  details['guild.features'] = featureList.join(',');
  details['guild.features.count'] = featureList.length.toString();
  _trySet(
    'guild.memberCount',
    () => guild.memberCount ?? guild.approximateMemberCount,
  );

  details.removeWhere((key, value) => value.isEmpty);
  return details;
}

Future<Map<String, String>> generateKeyValues(
  Interaction<ApplicationCommandInteractionData> interaction,
) async {
  PartialGuild? guild = interaction.guild;
  final guildId = _asSnowflake((interaction as dynamic).guildId) ?? guild?.id;
  if (guild is! Guild && guildId != null) {
    final fetched = await _fetchGuildCached(
      interaction.manager.client,
      guildId,
    );
    if (fetched != null) {
      guild = fetched;
    }
  }

  PartialChannel? channel = interaction.channel;
  final channelId =
      _asSnowflake((interaction as dynamic).channelId) ?? channel?.id;
  if (channel is! Channel && channelId != null) {
    final fetched = await _fetchChannelCached(
      interaction.manager.client,
      channelId,
    );
    if (fetched != null) {
      channel = fetched;
    }
  }

  Member? user = interaction.member;
  final invokingUserId =
      _asSnowflake(interaction.user?.id) ??
      _asSnowflake(interaction.member?.id);
  if (user == null && guildId != null && invokingUserId != null) {
    user = await _fetchMemberCached(
      interaction,
      guildId: guildId,
      userId: invokingUserId,
    );
  }
  if (user == null && interaction.member != null) {
    user = interaction.member;
  }
  final guildName = (guild is Guild) ? guild.name : "DM";
  final userName = user?.user?.username ?? "Unknown User";
  final guildCount = (guild is Guild) ? guild.approximateMemberCount : 0;
  String channelName = getChannelName(channel);
  String channelType = channel is Channel ? channel.type.toString() : "DM";

  String userAvatarUrl = "https://cdn.discordapp.com/embed/avatars/0.png";
  String userBannerUrl = '';
  String memberAvatarUrl = userAvatarUrl;

  if (user != null) {
    if (user.user != null) {
      final userFinal = user.user!;
      userAvatarUrl = makeAvatarUrl(
        userFinal.id.toString(),
        avatarId: userFinal.avatar.hash,
        isAnimated: userFinal.avatar.isAnimated,
        legacyFormat: "webp",
        discriminator: userFinal.discriminator,
      );

      try {
        final dynamic dynamicUser = userFinal;
        final dynamic userBanner = dynamicUser.banner;
        userBannerUrl = makeBannerUrl(
          userFinal.id.toString(),
          bannerId: userBanner?.hash?.toString(),
          isAnimated: userBanner?.isAnimated == true,
          legacyFormat: "webp",
        );
      } catch (_) {}
    }

    try {
      final dynamic dynamicMember = user;
      final dynamic memberAvatar = dynamicMember.avatar;
      final memberAvatarHash = memberAvatar?.hash?.toString() ?? '';
      if (memberAvatarHash.isNotEmpty && user.user != null) {
        final userFinal = user.user!;
        memberAvatarUrl = makeAvatarUrl(
          userFinal.id.toString(),
          avatarId: memberAvatarHash,
          isAnimated: memberAvatar?.isAnimated == true,
          legacyFormat: "webp",
          discriminator: userFinal.discriminator,
        );
      }
    } catch (_) {}
  }

  Map<String, String> listOfArgs = {
    "userName": userName,
    "userId": user?.id.toString() ?? "Unknown User",
    "userUsername": user?.user?.username ?? "Unknown User",
    "userTag": user?.user?.discriminator ?? "Unknown User",
    "userAvatar": userAvatarUrl,
    "userBanner": userBannerUrl,
    "user.id": user?.id.toString() ?? "Unknown User",
    "user.username": user?.user?.username ?? "Unknown User",
    "user.tag": user?.user?.discriminator ?? "Unknown User",
    "user.avatar": userAvatarUrl,
    "user.banner": userBannerUrl,
    "member.id": user?.id.toString() ?? "Unknown User",
    "member.nick": user?.nick ?? '',
    "member.avatar": memberAvatarUrl,
    "interaction.member.id": user?.id.toString() ?? "Unknown User",
    "interaction.member.nick": user?.nick ?? '',
    "interaction.member.avatar": memberAvatarUrl,
    "author.id": user?.id.toString() ?? "Unknown User",
    "author.username": user?.user?.username ?? "Unknown User",
    "author.tag": user?.user?.discriminator ?? "Unknown User",
    "author.avatar": userAvatarUrl,
    "author.banner": userBannerUrl,
    "interaction.user.id": user?.id.toString() ?? "Unknown User",
    "interaction.user.username": user?.user?.username ?? "Unknown User",
    "interaction.user.tag": user?.user?.discriminator ?? "Unknown User",
    "interaction.user.avatar": userAvatarUrl,
    "interaction.user.banner": userBannerUrl,
    "guildName": guildName,
    "guild.name": guildName,
    "channelName": channelName,
    "channel.name": channelName,
    "channelType": channelType,
    "channel.type": channelType,
    "guildIcon": makeGuildIcon(
      guild?.id.toString() ?? "DM",
      (guild is Guild) ? guild.icon?.hash : null,
    ),
    "guildId": guild?.id.toString() ?? "DM",
    "guild.id": guild?.id.toString() ?? "DM",
    "channelId": channel?.id.toString() ?? "DM",
    "channel.id": channel?.id.toString() ?? "DM",
    "guildCount": guildCount.toString(),
    "guild.count": guildCount.toString(),
    "interaction.guild.id": guild?.id.toString() ?? "DM",
    "interaction.guild.name": guildName,
    "interaction.guild.icon": makeGuildIcon(
      guild?.id.toString() ?? "DM",
      (guild is Guild) ? guild.icon?.hash : null,
    ),
    "interaction.channel.id": channel?.id.toString() ?? "DM",
    "interaction.channel.name": channelName,
    "interaction.channel.type": channelType,
  };
  listOfArgs.addAll(extractChannelRuntimeDetails(channel));
  listOfArgs.addAll(extractGuildRuntimeDetails(guild));
  final command = interaction.data;
  listOfArgs["commandName"] = command.name;
  listOfArgs["commandId"] = command.id.toString();
  final commandType = command.type;
  final commandTypeName =
      commandType == ApplicationCommandType.user
          ? 'user'
          : commandType == ApplicationCommandType.message
          ? 'message'
          : 'chatInput';
  listOfArgs["commandType"] = commandTypeName;
  listOfArgs["commandTypeValue"] = commandType.value.toString();
  listOfArgs["command.type"] = commandTypeName;
  listOfArgs["interaction.command.type"] = commandTypeName;

  final targetId = command.targetId;
  if (targetId != null) {
    listOfArgs["target.id"] = targetId.toString();
    listOfArgs["interaction.target.id"] = targetId.toString();
  }

  if (commandType == ApplicationCommandType.user && targetId != null) {
    final resolvedUser = command.resolved?.users?[targetId];
    User? targetUser = resolvedUser;
    targetUser ??= await _fetchUserCached(interaction.manager.client, targetId);
    if (targetUser != null) {
      String targetBannerUrl = '';
      final dynamic dynamicTargetUser = targetUser;
      final dynamic targetBanner = dynamicTargetUser.banner;
      targetBannerUrl = makeBannerUrl(
        targetUser.id.toString(),
        bannerId: targetBanner?.hash?.toString(),
        isAnimated: targetBanner?.isAnimated == true,
        legacyFormat: "webp",
      );

      listOfArgs["target.user.id"] = targetUser.id.toString();
      listOfArgs["target.user.username"] = targetUser.username;
      listOfArgs["target.user.tag"] = targetUser.discriminator;
      listOfArgs["target.user.avatar"] = makeAvatarUrl(
        targetUser.id.toString(),
        avatarId: targetUser.avatar.hash,
        isAnimated: targetUser.avatar.isAnimated,
        legacyFormat: "webp",
        discriminator: targetUser.discriminator,
      );
      listOfArgs["target.user.banner"] = targetBannerUrl;
      listOfArgs["target.userName"] = targetUser.username;
      listOfArgs["target.userAvatar"] = listOfArgs["target.user.avatar"] ?? '';
    }

    Member? resolvedMember = command.resolved?.members?[targetId];
    if (resolvedMember == null) {
      final resolvedGuildId =
          _asSnowflake((interaction as dynamic).guildId) ??
          interaction.guild?.id;
      if (resolvedGuildId != null) {
        resolvedMember = await _fetchMemberCached(
          interaction,
          guildId: resolvedGuildId,
          userId: targetId,
        );
      }
    }
    if (resolvedMember != null) {
      listOfArgs["target.member.id"] = resolvedMember.id.toString();
      listOfArgs["target.member.nick"] = resolvedMember.nick ?? '';
    }
  }

  if (commandType == ApplicationCommandType.message && targetId != null) {
    final resolvedMessage = command.resolved?.messages?[targetId];
    if (resolvedMessage != null) {
      listOfArgs["target.message.id"] = resolvedMessage.id.toString();
      listOfArgs["target.message.channelId"] =
          resolvedMessage.channelId.toString();
      listOfArgs["target.messageId"] = resolvedMessage.id.toString();

      if (resolvedMessage is Message) {
        listOfArgs["target.message.content"] = resolvedMessage.content;
        listOfArgs["target.message.author.id"] =
            resolvedMessage.author.id.toString();
        listOfArgs["target.messageContent"] = resolvedMessage.content;
      }
    }
  }

  if (interaction.data.options is List<InteractionOption>) {
    final options = interaction.data.options as List<InteractionOption>;
    for (final option in options) {
      if (option.type == CommandOptionType.subCommand) {
        listOfArgs[option.name] = option.value.toString();
        final subOptions = option.options as List<InteractionOption>;
        for (final subOption in subOptions) {
          final subKeyValues = await generateKeyValuesFromInteractionOption(
            subOption,
            interaction,
          );
          // let's prefix them with opts to avoid conflicts
          // with other keys
          for (final entry in subKeyValues.entries) {
            listOfArgs["opts.${entry.key}"] = entry.value;
          }
        }
      } else if (option.type == CommandOptionType.subCommandGroup) {
        listOfArgs[option.name] = option.value.toString();
        final subCommandsOptions = option.options as List<InteractionOption>;
        for (final subCommandOption in subCommandsOptions) {
          final subOptions =
              subCommandOption.options as List<InteractionOption>;
          for (final subOption in subOptions) {
            final subKeyValues = await generateKeyValuesFromInteractionOption(
              subOption,
              interaction,
            );
            // let's prefix them with opts to avoid conflicts
            // with other keys
            for (final entry in subKeyValues.entries) {
              listOfArgs["opts.${entry.key}"] = entry.value;
            }
          }
        }
      } else {
        final keyValues = await generateKeyValuesFromInteractionOption(
          option,
          interaction,
        );
        // let's prefix them with opts to avoid conflicts
        // with other keys
        for (final entry in keyValues.entries) {
          listOfArgs["opts.${entry.key}"] = entry.value;
        }
      }
    }
  }
  return listOfArgs;
}

Future<Map<String, String>> generateKeyValuesFromInteractionOption(
  InteractionOption value,
  Interaction<ApplicationCommandInteractionData> interaction,
) async {
  final client = interaction.manager.client;
  switch (value.type) {
    case CommandOptionType.string:
      return {value.name: value.value.toString()};
    case CommandOptionType.integer:
      return {value.name: value.value.toString()};
    case CommandOptionType.boolean:
      return {value.name: value.value.toString()};
    case CommandOptionType.user:
      final userId = Snowflake(int.parse(value.value.toString()));
      final user = await _fetchUserCached(client, userId);
      if (user == null) {
        return {
          value.name: value.value.toString(),
          "${value.name}.id": userId.toString(),
        };
      }
      return {
        value.name: user.username,
        "${value.name}.id": user.id.toString(),
        "${value.name}.username": user.username,
        "${value.name}.tag": user.discriminator,
        "${value.name}.avatar": makeAvatarUrl(
          user.id.toString(),
          avatarId: user.avatar.hash,
          isAnimated: user.avatar.isAnimated,
          legacyFormat: "webp",
          discriminator: user.discriminator,
        ),
        "${value.name}.banner": makeBannerUrl(
          user.id.toString(),
          bannerId: (user as dynamic).banner?.hash?.toString(),
          isAnimated: (user as dynamic).banner?.isAnimated == true,
          legacyFormat: "webp",
        ),
      };
    case CommandOptionType.channel:
      final channelId = Snowflake(int.parse(value.value.toString()));
      final channel = await _fetchChannelCached(client, channelId);
      if (channel == null) {
        return {
          value.name: channelId.toString(),
          "${value.name}.id": channelId.toString(),
          "${value.name}.type": 'unknown',
        };
      }
      return {
        value.name: getChannelName(channel),
        "${value.name}.id": channel.id.toString(),
        "${value.name}.type": channel.type.toString(),
      };
    case CommandOptionType.role:
      final role = await interaction.guild?.roles.fetch(
        value.value as Snowflake,
      );
      return {
        value.name: role?.name ?? "Unknown Role",
        "${value.name}.id": role?.id.toString() ?? "Unknown Role",
      };
    case CommandOptionType.mentionable:
      final mentionableId = Snowflake(int.parse(value.value.toString()));
      final mentionable = await _fetchUserCached(client, mentionableId);
      if (mentionable == null) {
        return {
          value.name: mentionableId.toString(),
          "${value.name}.id": mentionableId.toString(),
        };
      }
      return {
        value.name: mentionable.username,
        "${value.name}.id": mentionable.id.toString(),
        "${value.name}.username": mentionable.username,
        "${value.name}.tag": mentionable.discriminator,
        "${value.name}.avatar": makeAvatarUrl(
          mentionable.id.toString(),
          avatarId: mentionable.avatar.hash,
          isAnimated: mentionable.avatar.isAnimated,
          legacyFormat: "webp",
          discriminator: mentionable.discriminator,
        ),
        "${value.name}.banner": makeBannerUrl(
          mentionable.id.toString(),
          bannerId: (mentionable as dynamic).banner?.hash?.toString(),
          isAnimated: (mentionable as dynamic).banner?.isAnimated == true,
          legacyFormat: "webp",
        ),
      };
    case CommandOptionType.number:
      return {value.name: value.value.toString()};
  }
  return {value.name: value.value.toString()};
}

Future<Map<String, String>> generateInteractionContextKeyValues(
  Interaction interaction,
) async {
  final dynamic raw = interaction;
  final guildId = _asSnowflake(raw.guildId ?? raw.guild?.id);
  final channelId = _asSnowflake(raw.channelId ?? raw.channel?.id);
  final messageId = _asSnowflake(raw.message?.id);

  User? user;
  final rawUser = raw.user;
  if (rawUser is User) {
    user = rawUser;
  } else {
    final memberUser = raw.member?.user;
    if (memberUser is User) {
      user = memberUser;
    }
  }

  final userId = _asSnowflake(user?.id ?? raw.member?.id);
  if (user == null && userId != null) {
    user = await _fetchUserCached(interaction.manager.client, userId);
  }

  Member? member;
  if (raw.member is Member) {
    member = raw.member as Member;
  }
  if (member == null && guildId != null && userId != null) {
    member = await _fetchMemberCached(
      interaction,
      guildId: guildId,
      userId: userId,
    );
  }

  Guild? guild;
  if (raw.guild is Guild) {
    guild = raw.guild as Guild;
  }
  if (guild == null && guildId != null) {
    guild = await _fetchGuildCached(interaction.manager.client, guildId);
  }

  Channel? channel;
  if (raw.channel is Channel) {
    channel = raw.channel as Channel;
  }
  if (channel == null && channelId != null) {
    channel = await _fetchChannelCached(interaction.manager.client, channelId);
  }

  final userIdText = userId?.toString() ?? '';
  final username = user?.username ?? member?.user?.username ?? '';
  final tag = user?.discriminator ?? member?.user?.discriminator ?? '';
  final userAvatarUrl =
      user == null
          ? ''
          : makeAvatarUrl(
            user.id.toString(),
            avatarId: user.avatar.hash,
            isAnimated: user.avatar.isAnimated,
            legacyFormat: 'webp',
            discriminator: user.discriminator,
          );
  String userBannerUrl = '';
  try {
    if (user != null) {
      userBannerUrl = makeBannerUrl(
        user.id.toString(),
        bannerId: (user as dynamic).banner?.hash?.toString(),
        isAnimated: (user as dynamic).banner?.isAnimated == true,
        legacyFormat: 'webp',
      );
    }
  } catch (_) {}

  String memberAvatarUrl = userAvatarUrl;
  try {
    final dynamic dynamicMember = member;
    final dynamic memberAvatar = dynamicMember?.avatar;
    final memberAvatarHash = memberAvatar?.hash?.toString() ?? '';
    if (memberAvatarHash.isNotEmpty && userIdText.isNotEmpty) {
      memberAvatarUrl = makeAvatarUrl(
        userIdText,
        avatarId: memberAvatarHash,
        isAnimated: memberAvatar?.isAnimated == true,
        legacyFormat: 'webp',
        discriminator: tag,
      );
    }
  } catch (_) {}

  final guildName = guild?.name ?? 'DM';
  final guildIcon = makeGuildIcon(
    guildId?.toString() ?? 'DM',
    guild?.icon?.hash,
  );
  final channelName = getChannelName(channel);
  final channelType = channel?.type.toString() ?? 'DM';

  return <String, String>{
    'interaction.guildId': guildId?.toString() ?? '',
    'interaction.channelId': channelId?.toString() ?? '',
    'interaction.messageId': messageId?.toString() ?? '',
    'interaction.userId': userIdText,
    'userName': username,
    'userId': userIdText,
    'userUsername': username,
    'userTag': tag,
    'userAvatar': userAvatarUrl,
    'userBanner': userBannerUrl,
    'user.id': userIdText,
    'user.username': username,
    'user.tag': tag,
    'user.avatar': userAvatarUrl,
    'user.banner': userBannerUrl,
    'author.id': userIdText,
    'author.username': username,
    'author.tag': tag,
    'author.avatar': userAvatarUrl,
    'author.banner': userBannerUrl,
    'interaction.user.id': userIdText,
    'interaction.user.username': username,
    'interaction.user.tag': tag,
    'interaction.user.avatar': userAvatarUrl,
    'interaction.user.banner': userBannerUrl,
    'member.id': userIdText,
    'member.nick': member?.nick ?? '',
    'member.avatar': memberAvatarUrl,
    'interaction.member.id': userIdText,
    'interaction.member.nick': member?.nick ?? '',
    'interaction.member.avatar': memberAvatarUrl,
    'guildName': guildName,
    'guildId': guildId?.toString() ?? '',
    'guildIcon': guildIcon,
    'guildCount': (guild?.approximateMemberCount ?? 0).toString(),
    'guild.name': guildName,
    'guild.id': guildId?.toString() ?? '',
    'guild.count': (guild?.approximateMemberCount ?? 0).toString(),
    'interaction.guild.name': guildName,
    'interaction.guild.id': guildId?.toString() ?? '',
    'interaction.guild.icon': guildIcon,
    'channelName': channelName,
    'channelId': channelId?.toString() ?? '',
    'channelType': channelType,
    'channel.name': channelName,
    'channel.id': channelId?.toString() ?? '',
    'channel.type': channelType,
    'interaction.channel.name': channelName,
    'interaction.channel.id': channelId?.toString() ?? '',
    'interaction.channel.type': channelType,
    ...extractChannelRuntimeDetails(channel),
    ...extractGuildRuntimeDetails(guild),
  };
}

InteractionOption? findFocusedOption(List<InteractionOption>? options) {
  return findFocusedInteractionOption(options);
}

String getChannelName(PartialChannel? channel) {
  if (channel is GuildTextChannel) {
    return channel.name;
  } else if (channel is GuildVoiceChannel) {
    return channel.name;
  } else if (channel is ThreadsOnlyChannel) {
    return channel.name;
  } else if (channel is GuildStageChannel) {
    return channel.name;
  } else if (channel is DmChannel) {
    return "DM";
  }
  return "Unknown Channel";
}
