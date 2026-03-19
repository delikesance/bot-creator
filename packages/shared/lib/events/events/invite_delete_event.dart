part of '../event_contexts.dart';

EventExecutionContext buildInviteDeleteEventContext(InviteDeleteEvent event) {
  final raw = event as dynamic;
  final invite = raw.invite;
  return _baseEventContext(
    eventName: 'inviteDelete',
    guildId: _asSnowflake(invite?.guild?.id ?? raw.guildId),
    channelId: _asSnowflake(invite?.channel?.id ?? raw.channelId),
    userId: _asSnowflake(invite?.inviter?.id),
    extra: _inviteExtra(
      code: (invite?.code ?? raw.code ?? '').toString(),
      channelId: _idString(invite?.channel?.id ?? raw.channelId),
      inviterId: _idString(invite?.inviter?.id),
    ),
  );
}
