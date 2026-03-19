part of '../event_contexts.dart';

EventExecutionContext buildMessagePollVoteRemoveEventContext(
  MessagePollVoteRemoveEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'messagePollVoteRemove',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: _pollVoteExtra(raw),
  );
}
