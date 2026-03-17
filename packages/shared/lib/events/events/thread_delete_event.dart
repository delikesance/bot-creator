part of '../event_contexts.dart';

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
