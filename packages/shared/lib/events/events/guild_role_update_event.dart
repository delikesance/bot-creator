part of '../event_contexts.dart';

EventExecutionContext buildGuildRoleUpdateEventContext(
  GuildRoleUpdateEvent event,
) {
  final raw = event as dynamic;
  final role = raw.role;
  return _baseEventContext(
    eventName: 'guildRoleUpdate',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: null,
    extra: <String, String>{
      'role.id': _idString(role?.id),
      'role.name': (role?.name ?? '').toString(),
      'role.color': (role?.colorValue ?? role?.color ?? '').toString(),
      'role.permissions': (role?.permissions?.value ?? '').toString(),
      'role.position': (role?.position ?? '').toString(),
      'role.mentionable': ((role?.isMentionable ?? false) == true).toString(),
      'role.hoist': ((role?.isHoisted ?? false) == true).toString(),
    },
  );
}
