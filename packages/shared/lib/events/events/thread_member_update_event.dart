part of '../event_contexts.dart';

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
