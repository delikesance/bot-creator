part of '../event_contexts.dart';

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
