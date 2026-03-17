part of '../event_contexts.dart';

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
