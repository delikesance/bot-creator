import 'package:nyxx/nyxx.dart';

part 'events/channel_pins_update_event.dart';
part 'events/channel_update_event.dart';
part 'events/guild_audit_log_create_event.dart';
part 'events/guild_member_add_event.dart';
part 'events/guild_member_remove_event.dart';
part 'events/guild_role_create_event.dart';
part 'events/guild_role_delete_event.dart';
part 'events/guild_role_update_event.dart';
part 'events/invite_create_event.dart';
part 'events/invite_delete_event.dart';
part 'events/message_create_event.dart';
part 'events/message_delete_event.dart';
part 'events/message_poll_vote_add_event.dart';
part 'events/message_poll_vote_remove_event.dart';
part 'events/message_reaction_add_event.dart';
part 'events/message_reaction_remove_all_event.dart';
part 'events/message_reaction_remove_emoji_event.dart';
part 'events/message_reaction_remove_event.dart';
part 'events/message_update_event.dart';
part 'events/presence_update_event.dart';
part 'events/thread_create_event.dart';
part 'events/thread_delete_event.dart';
part 'events/thread_member_update_event.dart';
part 'events/thread_members_update_event.dart';
part 'events/thread_update_event.dart';
part 'events/typing_start_event.dart';
part 'events/user_update_event.dart';
part 'events/voice_channel_effect_send_event.dart';
part 'events/voice_server_update_event.dart';
part 'events/voice_state_update_event.dart';

class EventExecutionContext {
  const EventExecutionContext({
    required this.eventName,
    required this.variables,
    required this.guildId,
    required this.channelId,
    required this.userId,
  });

  final String eventName;
  final Map<String, String> variables;
  final Snowflake? guildId;
  final Snowflake? channelId;
  final Snowflake? userId;
}

Map<String, String> _threadExtra(dynamic thread) {
  return <String, String>{
    'thread.id': _idString(thread?.id),
    'thread.name': (thread?.name ?? '').toString(),
    'thread.parent.id': _idString(thread?.parentId),
    'thread.owner.id': _idString(thread?.ownerId),
    'thread.archived': ((thread?.isArchived ?? false) == true).toString(),
    'thread.locked': ((thread?.isLocked ?? false) == true).toString(),
    'thread.autoArchiveDuration':
        (thread?.autoArchiveDuration ?? '').toString(),
  };
}

Snowflake? _asSnowflake(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Snowflake) {
    return value;
  }
  if (value is int) {
    return Snowflake(value);
  }
  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

String _idString(dynamic value) {
  return _asSnowflake(value)?.toString() ?? (value?.toString() ?? '');
}

EventExecutionContext _baseEventContext({
  required String eventName,
  required Snowflake? guildId,
  required Snowflake? channelId,
  required Snowflake? userId,
  Map<String, String> extra = const <String, String>{},
}) {
  final now = DateTime.now();
  return EventExecutionContext(
    eventName: eventName,
    guildId: guildId,
    channelId: channelId,
    userId: userId,
    variables: <String, String>{
      'event.name': eventName,
      'timestamp': now.millisecondsSinceEpoch.toString(),
      'actualTime': now.toIso8601String(),
      'guildId': guildId?.toString() ?? '',
      'channelId': channelId?.toString() ?? '',
      'userId': userId?.toString() ?? '',
      ...extra,
    },
  );
}

String _getChannelName(Channel channel) {
  if (channel is GuildTextChannel) {
    return channel.name;
  }
  if (channel is GuildVoiceChannel) {
    return channel.name;
  }
  if (channel is ThreadsOnlyChannel) {
    return channel.name;
  }
  if (channel is GuildStageChannel) {
    return channel.name;
  }
  if (channel is DmChannel) {
    return 'DM';
  }
  return 'Unknown Channel';
}
