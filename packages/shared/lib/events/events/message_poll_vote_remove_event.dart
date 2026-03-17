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
    extra: <String, String>{
      'message.id': _idString(raw.messageId),
      'poll.answer.id': (raw.answerId ?? '').toString(),
      'poll.question': (raw.question ?? '').toString(),
    },
  );
}
