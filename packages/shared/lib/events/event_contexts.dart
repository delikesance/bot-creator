import 'package:nyxx/nyxx.dart';

class EventExecutionContext {
  const EventExecutionContext({
    required this.eventName,
    required this.variables,
    required this.guildId,
    required this.channelId,
    required this.userId,
  });

  final String eventName;
  final Map<String, String> variables;
  final Snowflake? guildId;
  final Snowflake? channelId;
  final Snowflake? userId;
}

EventExecutionContext buildMessageCreateEventContext(MessageCreateEvent event) {
  final message = event.message;
  final author = message.author;
  final content = message.content;
  final words = content.trim().split(RegExp(r'\s+'));
  final mentionIds = message.mentions.map((u) => u.id.toString()).toList();
  final isBot = author is User ? author.isBot : false;
  final extra = <String, String>{
    'message.id': message.id.toString(),
    'message.content': content,
    'message.word.count': words.length.toString(),
    'message.isBot': isBot.toString(),
    'message.isSystem': (message.type != MessageType.normal).toString(),
    'message.type': message.type.value.toString(),
    'message.mentions': mentionIds.join(','),
    'message.mention.count': mentionIds.length.toString(),
    'author.id': author.id.toString(),
    'author.name': author.username,
    'author.username': author.username,
    'author.tag': author is User ? author.discriminator : '',
    'author.isBot': isBot.toString(),
    'author.avatar': author is User ? (author.avatar.url.toString()) : '',
  };
  for (var idx = 0; idx < words.length && idx < 10; idx++) {
    extra['message.content[$idx]'] = words[idx];
  }
  for (var idx = 0; idx < mentionIds.length && idx < 10; idx++) {
    extra['message.mentions[$idx]'] = mentionIds[idx];
  }
  return _baseEventContext(
    eventName: 'messageCreate',
    guildId: event.guildId,
    channelId: message.channelId,
    userId: author.id,
    extra: extra,
  );
}

EventExecutionContext buildMessageUpdateEventContext(MessageUpdateEvent event) {
  final message = event.message;
  final author = message.author;
  final content = message.content;
  final words = content.trim().split(RegExp(r'\s+'));
  final mentionIds = message.mentions.map((u) => u.id.toString()).toList();
  final isBot = author is User ? author.isBot : false;
  final extra = <String, String>{
    'message.id': message.id.toString(),
    'message.content': content,
    'message.oldContent': event.oldMessage?.content ?? '',
    'message.word.count': words.length.toString(),
    'message.isBot': isBot.toString(),
    'message.isSystem': (message.type != MessageType.normal).toString(),
    'message.type': message.type.value.toString(),
    'message.mentions': mentionIds.join(','),
    'message.mention.count': mentionIds.length.toString(),
    'author.id': author.id.toString(),
    'author.name': author.username,
    'author.username': author.username,
    'author.tag': author is User ? author.discriminator : '',
    'author.isBot': isBot.toString(),
    'author.avatar': author is User ? (author.avatar.url.toString()) : '',
  };
  for (var idx = 0; idx < words.length && idx < 10; idx++) {
    extra['message.content[$idx]'] = words[idx];
  }
  for (var idx = 0; idx < mentionIds.length && idx < 10; idx++) {
    extra['message.mentions[$idx]'] = mentionIds[idx];
  }
  return _baseEventContext(
    eventName: 'messageUpdate',
    guildId: event.guildId,
    channelId: message.channelId,
    userId: author.id,
    extra: extra,
  );
}

EventExecutionContext buildMessageDeleteEventContext(MessageDeleteEvent event) {
  final deleted = event.deletedMessage;
  return _baseEventContext(
    eventName: 'messageDelete',
    guildId: event.guildId,
    channelId: event.channelId,
    userId: deleted?.author.id,
    extra: <String, String>{
      'message.id': event.id.toString(),
      'message.content': deleted?.content ?? '',
      'author.id': deleted?.author.id.toString() ?? '',
      'author.name': deleted?.author.username ?? '',
      'author.username': deleted?.author.username ?? '',
      'author.tag':
          deleted?.author is User
              ? (deleted!.author as User).discriminator
              : '',
    },
  );
}

EventExecutionContext buildGuildMemberAddEventContext(
  GuildMemberAddEvent event,
) {
  final member = event.member;
  final user = member.user;
  return _baseEventContext(
    eventName: 'guildMemberAdd',
    guildId: event.guildId,
    channelId: null,
    userId: member.id,
    extra: <String, String>{
      'member.id': member.id.toString(),
      'member.name': user?.username ?? '',
      'member.username': user?.username ?? '',
      'member.tag': user?.discriminator ?? '',
      'member.joinedAt': member.joinedAt.toIso8601String(),
    },
  );
}

EventExecutionContext buildGuildMemberRemoveEventContext(
  GuildMemberRemoveEvent event,
) {
  final user = event.user;
  return _baseEventContext(
    eventName: 'guildMemberRemove',
    guildId: event.guildId,
    channelId: null,
    userId: user.id,
    extra: <String, String>{
      'member.id': user.id.toString(),
      'member.name': user.username,
      'member.username': user.username,
      'member.tag': user.discriminator,
    },
  );
}

EventExecutionContext buildChannelUpdateEventContext(ChannelUpdateEvent event) {
  final channel = event.channel;
  final guildId = channel is GuildChannel ? channel.guildId : null;
  return _baseEventContext(
    eventName: 'channelUpdate',
    guildId: guildId,
    channelId: channel.id,
    userId: null,
    extra: <String, String>{
      'channel.id': channel.id.toString(),
      'channel.name': _getChannelName(channel),
      'channel.type': channel.type.toString(),
    },
  );
}

EventExecutionContext buildInviteCreateEventContext(InviteCreateEvent event) {
  final invite = event.invite;
  return _baseEventContext(
    eventName: 'inviteCreate',
    guildId: invite.guild?.id,
    channelId: invite.channel.id,
    userId: invite.inviter?.id,
    extra: <String, String>{
      'invite.code': invite.code,
      'invite.channelId': invite.channel.id.toString(),
      'invite.inviterId': invite.inviter?.id.toString() ?? '',
    },
  );
}

EventExecutionContext buildMessageReactionAddEventContext(
  MessageReactionAddEvent event,
) {
  final raw = event as dynamic;
  final emoji = raw.emoji;
  return _baseEventContext(
    eventName: 'messageReactionAdd',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: <String, String>{
      'message.id': _idString(raw.messageId),
      'reaction.emoji.name': (emoji?.name ?? '').toString(),
      'reaction.emoji.id': _idString(emoji?.id),
      'reaction.emoji.animated':
          ((emoji?.animated ?? false) == true).toString(),
    },
  );
}

EventExecutionContext buildMessageReactionRemoveEventContext(
  MessageReactionRemoveEvent event,
) {
  final raw = event as dynamic;
  final emoji = raw.emoji;
  return _baseEventContext(
    eventName: 'messageReactionRemove',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: <String, String>{
      'message.id': _idString(raw.messageId),
      'reaction.emoji.name': (emoji?.name ?? '').toString(),
      'reaction.emoji.id': _idString(emoji?.id),
      'reaction.emoji.animated':
          ((emoji?.animated ?? false) == true).toString(),
    },
  );
}

EventExecutionContext buildMessageReactionRemoveAllEventContext(
  MessageReactionRemoveAllEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'messageReactionRemoveAll',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: null,
    extra: <String, String>{'message.id': _idString(raw.messageId)},
  );
}

EventExecutionContext buildMessageReactionRemoveEmojiEventContext(
  MessageReactionRemoveEmojiEvent event,
) {
  final raw = event as dynamic;
  final emoji = raw.emoji;
  return _baseEventContext(
    eventName: 'messageReactionRemoveEmoji',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: null,
    extra: <String, String>{
      'message.id': _idString(raw.messageId),
      'reaction.emoji.name': (emoji?.name ?? '').toString(),
      'reaction.emoji.id': _idString(emoji?.id),
      'reaction.emoji.animated':
          ((emoji?.animated ?? false) == true).toString(),
    },
  );
}

EventExecutionContext buildMessagePollVoteAddEventContext(
  MessagePollVoteAddEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'messagePollVoteAdd',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: <String, String>{
      'message.id': _idString(raw.messageId),
      'poll.answer.id': (raw.answerId ?? '').toString(),
      'poll.question': (raw.question ?? '').toString(),
    },
  );
}

EventExecutionContext buildMessagePollVoteRemoveEventContext(
  MessagePollVoteRemoveEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'messagePollVoteRemove',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: <String, String>{
      'message.id': _idString(raw.messageId),
      'poll.answer.id': (raw.answerId ?? '').toString(),
      'poll.question': (raw.question ?? '').toString(),
    },
  );
}

EventExecutionContext buildTypingStartEventContext(TypingStartEvent event) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'typingStart',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: <String, String>{
      'typing.timestamp': (raw.timestamp ?? '').toString(),
      'typing.member.id': _idString(raw.member?.id),
      'typing.member.name': (raw.member?.user?.username ?? '').toString(),
    },
  );
}

EventExecutionContext buildUserUpdateEventContext(UserUpdateEvent event) {
  final raw = event as dynamic;
  final user = raw.user;
  return _baseEventContext(
    eventName: 'userUpdate',
    guildId: null,
    channelId: null,
    userId: _asSnowflake(user?.id),
    extra: <String, String>{
      'user.id': _idString(user?.id),
      'user.username': (user?.username ?? '').toString(),
      'user.avatar': (user?.avatar?.url?.toString() ?? '').toString(),
      'user.banner': (user?.banner?.url?.toString() ?? '').toString(),
      'user.accentColor': (user?.accentColor?.toString() ?? '').toString(),
    },
  );
}

EventExecutionContext buildVoiceStateUpdateEventContext(
  VoiceStateUpdateEvent event,
) {
  final raw = event as dynamic;
  final state = raw.state;
  return _baseEventContext(
    eventName: 'voiceStateUpdate',
    guildId: _asSnowflake(raw.guildId ?? state?.guildId),
    channelId: _asSnowflake(state?.channelId),
    userId: _asSnowflake(state?.userId),
    extra: <String, String>{
      'voice.channel.id': _idString(state?.channelId),
      'voice.user.id': _idString(state?.userId),
      'voice.state.sessionId': (state?.sessionId ?? '').toString(),
      'voice.selfMute': ((state?.isSelfMuted ?? false) == true).toString(),
      'voice.selfDeafen': ((state?.isSelfDeafened ?? false) == true).toString(),
      'voice.mute': ((state?.isMuted ?? false) == true).toString(),
      'voice.deafen': ((state?.isDeafened ?? false) == true).toString(),
    },
  );
}

EventExecutionContext buildVoiceServerUpdateEventContext(
  VoiceServerUpdateEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'voiceServerUpdate',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: null,
    extra: <String, String>{
      'voice.server.token': (raw.token ?? '').toString(),
      'voice.server.endpoint': (raw.endpoint ?? '').toString(),
    },
  );
}

EventExecutionContext buildVoiceChannelEffectSendEventContext(
  VoiceChannelEffectSendEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'voiceChannelEffectSend',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: <String, String>{
      'voice.effect.emoji': (raw.emoji?.name ?? '').toString(),
      'voice.effect.soundId': _idString(raw.soundId),
    },
  );
}

EventExecutionContext buildGuildRoleCreateEventContext(
  GuildRoleCreateEvent event,
) {
  final raw = event as dynamic;
  final role = raw.role;
  return _baseEventContext(
    eventName: 'guildRoleCreate',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: null,
    extra: <String, String>{
      'role.id': _idString(role?.id),
      'role.name': (role?.name ?? '').toString(),
      'role.color': (role?.colorValue ?? role?.color ?? '').toString(),
      'role.permissions': (role?.permissions?.value ?? '').toString(),
      'role.position': (role?.position ?? '').toString(),
      'role.mentionable': ((role?.isMentionable ?? false) == true).toString(),
      'role.hoist': ((role?.isHoisted ?? false) == true).toString(),
    },
  );
}

EventExecutionContext buildGuildRoleUpdateEventContext(
  GuildRoleUpdateEvent event,
) {
  final raw = event as dynamic;
  final role = raw.role;
  return _baseEventContext(
    eventName: 'guildRoleUpdate',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: null,
    extra: <String, String>{
      'role.id': _idString(role?.id),
      'role.name': (role?.name ?? '').toString(),
      'role.color': (role?.colorValue ?? role?.color ?? '').toString(),
      'role.permissions': (role?.permissions?.value ?? '').toString(),
      'role.position': (role?.position ?? '').toString(),
      'role.mentionable': ((role?.isMentionable ?? false) == true).toString(),
      'role.hoist': ((role?.isHoisted ?? false) == true).toString(),
    },
  );
}

EventExecutionContext buildGuildRoleDeleteEventContext(
  GuildRoleDeleteEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'guildRoleDelete',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: null,
    extra: <String, String>{'role.id': _idString(raw.roleId)},
  );
}

EventExecutionContext buildChannelPinsUpdateEventContext(
  ChannelPinsUpdateEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'channelPinsUpdate',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: null,
    extra: <String, String>{
      'channel.lastPinTimestamp': (raw.lastPinTimestamp ?? '').toString(),
    },
  );
}

EventExecutionContext buildThreadCreateEventContext(ThreadCreateEvent event) {
  final raw = event as dynamic;
  final thread = raw.thread;
  return _baseEventContext(
    eventName: 'threadCreate',
    guildId: _asSnowflake(raw.guildId ?? thread?.guildId),
    channelId: _asSnowflake(thread?.id),
    userId: _asSnowflake(thread?.ownerId),
    extra: _threadExtra(thread),
  );
}

EventExecutionContext buildThreadUpdateEventContext(ThreadUpdateEvent event) {
  final raw = event as dynamic;
  final thread = raw.thread;
  return _baseEventContext(
    eventName: 'threadUpdate',
    guildId: _asSnowflake(raw.guildId ?? thread?.guildId),
    channelId: _asSnowflake(thread?.id),
    userId: _asSnowflake(thread?.ownerId),
    extra: _threadExtra(thread),
  );
}

EventExecutionContext buildThreadDeleteEventContext(ThreadDeleteEvent event) {
  final raw = event as dynamic;
  final thread = raw.thread;
  return _baseEventContext(
    eventName: 'threadDelete',
    guildId: _asSnowflake(raw.guildId ?? thread?.guildId),
    channelId: _asSnowflake(thread?.id ?? raw.threadId),
    userId: _asSnowflake(thread?.ownerId),
    extra: _threadExtra(thread),
  );
}

EventExecutionContext buildThreadMemberUpdateEventContext(
  ThreadMemberUpdateEvent event,
) {
  final raw = event as dynamic;
  final member = raw.member;
  return _baseEventContext(
    eventName: 'threadMemberUpdate',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.threadId ?? member?.id),
    userId: _asSnowflake(member?.userId),
    extra: <String, String>{
      'thread.id': _idString(raw.threadId ?? member?.id),
      'member.id': _idString(member?.userId),
    },
  );
}

EventExecutionContext buildThreadMembersUpdateEventContext(
  ThreadMembersUpdateEvent event,
) {
  final raw = event as dynamic;
  final added = (raw.addedMembers as List?) ?? const [];
  final removed = (raw.removedMemberIds as List?) ?? const [];
  return _baseEventContext(
    eventName: 'threadMembersUpdate',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.threadId),
    userId: null,
    extra: <String, String>{
      'thread.id': _idString(raw.threadId),
      'thread.members.added.count': added.length.toString(),
      'thread.members.removed.count': removed.length.toString(),
    },
  );
}

EventExecutionContext buildInviteDeleteEventContext(InviteDeleteEvent event) {
  final raw = event as dynamic;
  final invite = raw.invite;
  return _baseEventContext(
    eventName: 'inviteDelete',
    guildId: _asSnowflake(invite?.guild?.id ?? raw.guildId),
    channelId: _asSnowflake(invite?.channel?.id ?? raw.channelId),
    userId: _asSnowflake(invite?.inviter?.id),
    extra: <String, String>{
      'invite.code': (invite?.code ?? raw.code ?? '').toString(),
      'invite.channelId': _idString(invite?.channel?.id ?? raw.channelId),
      'invite.inviterId': _idString(invite?.inviter?.id),
    },
  );
}

EventExecutionContext buildGuildAuditLogCreateEventContext(
  GuildAuditLogCreateEvent event,
) {
  final raw = event as dynamic;
  final entry = raw.entry;
  return _baseEventContext(
    eventName: 'guildAuditLogCreate',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: _asSnowflake(entry?.userId),
    extra: <String, String>{
      'auditLog.action': (entry?.actionType ?? '').toString(),
      'auditLog.executorId': _idString(entry?.userId),
      'auditLog.targetId': _idString(entry?.targetId),
    },
  );
}

EventExecutionContext buildPresenceUpdateEventContext(
  PresenceUpdateEvent event,
) {
  final user = event.user;
  final fullUser = user is User ? user : null;
  final activities = event.activities ?? const <Activity>[];
  final firstActivity = activities.isNotEmpty ? activities.first : null;
  return _baseEventContext(
    eventName: 'presenceUpdate',
    guildId: event.guildId,
    channelId: null,
    userId: user?.id,
    extra: <String, String>{
      'user.id': user?.id.toString() ?? '',
      'user.name': fullUser?.username ?? '',
      'user.username': fullUser?.username ?? '',
      'user.tag': fullUser?.discriminator ?? '',
      'user.avatar': fullUser?.avatar.url.toString() ?? '',
      'presence.status': event.status?.value.toString() ?? '',
      'presence.activity.count': activities.length.toString(),
      'presence.activity[0].name': firstActivity?.name ?? '',
      'presence.activity[0].type': firstActivity?.type.value.toString() ?? '',
      'presence.activity[0].details': firstActivity?.details ?? '',
      'presence.activity[0].state': firstActivity?.state ?? '',
      'presence.activity[0].url': firstActivity?.url?.toString() ?? '',
      'presence.client.desktop':
          event.clientStatus?.desktop?.value.toString() ?? '',
      'presence.client.mobile':
          event.clientStatus?.mobile?.value.toString() ?? '',
      'presence.client.web': event.clientStatus?.web?.value.toString() ?? '',
    },
  );
}

Map<String, String> _threadExtra(dynamic thread) {
  return <String, String>{
    'thread.id': _idString(thread?.id),
    'thread.name': (thread?.name ?? '').toString(),
    'thread.parent.id': _idString(thread?.parentId),
    'thread.owner.id': _idString(thread?.ownerId),
    'thread.archived': ((thread?.isArchived ?? false) == true).toString(),
    'thread.locked': ((thread?.isLocked ?? false) == true).toString(),
    'thread.autoArchiveDuration':
        (thread?.autoArchiveDuration ?? '').toString(),
  };
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

String _idString(dynamic value) {
  return _asSnowflake(value)?.toString() ?? (value?.toString() ?? '');
}

EventExecutionContext _baseEventContext({
  required String eventName,
  required Snowflake? guildId,
  required Snowflake? channelId,
  required Snowflake? userId,
  Map<String, String> extra = const <String, String>{},
}) {
  final now = DateTime.now();
  return EventExecutionContext(
    eventName: eventName,
    guildId: guildId,
    channelId: channelId,
    userId: userId,
    variables: <String, String>{
      'event.name': eventName,
      'timestamp': now.millisecondsSinceEpoch.toString(),
      'actualTime': now.toIso8601String(),
      'guildId': guildId?.toString() ?? '',
      'channelId': channelId?.toString() ?? '',
      'userId': userId?.toString() ?? '',
      ...extra,
    },
  );
}

String _getChannelName(Channel channel) {
  if (channel is GuildTextChannel) {
    return channel.name;
  }
  if (channel is GuildVoiceChannel) {
    return channel.name;
  }
  if (channel is ThreadsOnlyChannel) {
    return channel.name;
  }
  if (channel is GuildStageChannel) {
    return channel.name;
  }
  if (channel is DmChannel) {
    return 'DM';
  }
  return 'Unknown Channel';
}
