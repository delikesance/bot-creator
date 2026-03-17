part of '../event_contexts.dart';

EventExecutionContext buildPresenceUpdateEventContext(
  PresenceUpdateEvent event,
) {
  final user = event.user;
  final fullUser = user is User ? user : null;
  final activities = event.activities ?? const <Activity>[];
  final firstActivity = activities.isNotEmpty ? activities.first : null;
  return _baseEventContext(
    eventName: 'presenceUpdate',
    guildId: event.guildId,
    channelId: null,
    userId: user?.id,
    extra: <String, String>{
      'user.id': user?.id.toString() ?? '',
      'user.name': fullUser?.username ?? '',
      'user.username': fullUser?.username ?? '',
      'user.tag': fullUser?.discriminator ?? '',
      'user.avatar': fullUser?.avatar.url.toString() ?? '',
      'presence.status': event.status?.value.toString() ?? '',
      'presence.activity.count': activities.length.toString(),
      'presence.activity[0].name': firstActivity?.name ?? '',
      'presence.activity[0].type': firstActivity?.type.value.toString() ?? '',
      'presence.activity[0].details': firstActivity?.details ?? '',
      'presence.activity[0].state': firstActivity?.state ?? '',
      'presence.activity[0].url': firstActivity?.url?.toString() ?? '',
      'presence.client.desktop':
          event.clientStatus?.desktop?.value.toString() ?? '',
      'presence.client.mobile':
          event.clientStatus?.mobile?.value.toString() ?? '',
      'presence.client.web': event.clientStatus?.web?.value.toString() ?? '',
    },
  );
}
