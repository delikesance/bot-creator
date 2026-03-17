part of '../event_contexts.dart';

EventExecutionContext buildInviteCreateEventContext(InviteCreateEvent event) {
  final invite = event.invite;
  return _baseEventContext(
    eventName: 'inviteCreate',
    guildId: invite.guild?.id,
    channelId: invite.channel.id,
    userId: invite.inviter?.id,
    extra: <String, String>{
      'invite.code': invite.code,
      'invite.channelId': invite.channel.id.toString(),
      'invite.inviterId': invite.inviter?.id.toString() ?? '',
    },
  );
}
