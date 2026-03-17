part of '../event_contexts.dart';

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
