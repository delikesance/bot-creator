part of '../event_contexts.dart';

EventExecutionContext buildVoiceStateUpdateEventContext(
  VoiceStateUpdateEvent event,
) {
  final raw = event as dynamic;
  final state = raw.state;
  return _baseEventContext(
    eventName: 'voiceStateUpdate',
    guildId: _asSnowflake(raw.guildId ?? state?.guildId),
    channelId: _asSnowflake(state?.channelId),
    userId: _asSnowflake(state?.userId),
    extra: <String, String>{
      'voice.channel.id': _idString(state?.channelId),
      'voice.user.id': _idString(state?.userId),
      'voice.state.sessionId': (state?.sessionId ?? '').toString(),
      'voice.selfMute': ((state?.isSelfMuted ?? false) == true).toString(),
      'voice.selfDeafen': ((state?.isSelfDeafened ?? false) == true).toString(),
      'voice.mute': ((state?.isMuted ?? false) == true).toString(),
      'voice.deafen': ((state?.isDeafened ?? false) == true).toString(),
    },
  );
}
