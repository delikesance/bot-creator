part of '../event_contexts.dart';

EventExecutionContext buildMessageCreateEventContext(MessageCreateEvent event) {
  final message = event.message;
  return _baseEventContext(
    eventName: 'messageCreate',
    guildId: event.guildId,
    channelId: message.channelId,
    userId: message.author.id,
    extra: _messageContentExtra(message),
  );
}
