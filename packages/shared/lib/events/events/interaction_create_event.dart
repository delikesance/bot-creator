part of '../event_contexts.dart';

dynamic _safeRead(dynamic object, dynamic Function() reader) {
  try {
    return reader();
  } catch (_) {
    return null;
  }
}

Map<String, String> buildInteractionRuntimeVariables(dynamic interaction) {
  final dynamic data = _safeRead(interaction, () => interaction?.data);
  final dynamic commandType = _safeRead(data, () => data?.type);
  final dynamic commandId = _safeRead(data, () => data?.id);
  final commandName = (_safeRead(data, () => data?.name) ?? '').toString();

  final customId = (_safeRead(data, () => data?.customId) ?? '').toString();
  final valuesRaw = _safeRead(data, () => data?.values);
  final values =
      valuesRaw is Iterable
          ? valuesRaw.map((value) => value.toString()).toList(growable: false)
          : const <String>[];

  final modalComponents = _safeRead(data, () => data?.components);
  final modalInputPairs = <String, String>{};
  if (modalComponents is Iterable) {
    for (final component in modalComponents) {
      final innerComponents = _safeRead(component, () => component.components);
      if (innerComponents is! Iterable) {
        continue;
      }
      for (final inner in innerComponents) {
        final key =
            (_safeRead(inner, () => inner.customId) ?? '').toString().trim();
        if (key.isEmpty) {
          continue;
        }
        final value = (_safeRead(inner, () => inner.value) ?? '').toString();
        modalInputPairs['modal.$key'] = value;
      }
    }
  }

  final userId =
      _idString(_safeRead(interaction, () => interaction?.user?.id)) != ''
          ? _idString(_safeRead(interaction, () => interaction?.user?.id))
          : _idString(_safeRead(interaction, () => interaction?.member?.user?.id));
  final channelId = _idString(
    _safeRead(interaction, () => interaction?.channelId) ??
        _safeRead(interaction, () => interaction?.channel?.id),
  );
  final guildId = _idString(
    _safeRead(interaction, () => interaction?.guildId) ??
        _safeRead(interaction, () => interaction?.guild?.id),
  );
  final messageId = _idString(_safeRead(interaction, () => interaction?.message?.id));

  final kind =
      interaction is MessageComponentInteraction
          ? ((values.isNotEmpty) ? 'select' : 'button')
          : interaction is ModalSubmitInteraction
          ? 'modal'
          : interaction is ApplicationCommandInteraction
          ? 'command'
          : interaction is ApplicationCommandAutocompleteInteraction
          ? 'autocomplete'
          : interaction.runtimeType.toString();

  return <String, String>{
    'interaction.kind': kind,
    'interaction.customId': customId,
    'interaction.values': values.join(','),
    'interaction.values.count': values.length.toString(),
    'interaction.guildId': guildId,
    'interaction.channelId': channelId,
    'interaction.userId': userId,
    'interaction.messageId': messageId,
    'interaction.command.name': commandName,
    'interaction.command.id': commandId?.toString() ?? '',
    'interaction.command.type': commandType?.toString() ?? '',
    'modal.customId': customId,
    ...modalInputPairs,
  };
}

EventExecutionContext buildInteractionCreateEventContext(
  InteractionCreateEvent event,
) {
  final interaction = event.interaction;
  final dynamic data = interaction.data;

  return _baseEventContext(
    eventName: 'interactionCreate',
    guildId: _asSnowflake(interaction.guildId),
    channelId: _asSnowflake(interaction.channelId),
    userId:
        _asSnowflake(interaction.user?.id) ??
        _asSnowflake(interaction.member?.user?.id),
    extra: <String, String>{
      ...buildInteractionRuntimeVariables(interaction),
      'interaction.id': interaction.id.toString(),
      'interaction.token': interaction.token,
      'interaction.applicationId': interaction.applicationId.toString(),
      'interaction.data.type': data?.type?.toString() ?? '',
    },
  );
}
