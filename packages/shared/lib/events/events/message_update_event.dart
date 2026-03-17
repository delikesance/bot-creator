part of '../event_contexts.dart';

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
