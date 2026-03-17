part of '../event_contexts.dart';

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
