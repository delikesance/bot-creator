import 'dart:convert';

import 'package:bot_creator_shared/bot/bot_data_store.dart';

bool _isInvalidContextId(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == 'unknown user' ||
      normalized == 'dm';
}

String? _normalizeContextId(String? value) {
  final trimmed = (value ?? '').trim();
  return _isInvalidContextId(trimmed) ? null : trimmed;
}

String _normalizeScopedStorageKey(String key) {
  final trimmed = key.trim();
  if (trimmed.startsWith('bc_') && trimmed.length > 3) {
    return trimmed.substring(3);
  }
  return trimmed;
}

bool _isMissingOrEmptyValue(dynamic value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  return false;
}

List<String> _legacyContextIdsForScope(
  String scope,
  String? canonicalContextId,
) {
  switch (scope) {
    case 'user':
      return const <String>['Unknown User'];
    case 'guild':
    case 'channel':
      return const <String>['DM'];
    case 'guildMember':
      final parts = (canonicalContextId ?? '').split(':');
      final guild = parts.isNotEmpty ? parts.first.trim() : '';
      final user = parts.length > 1 ? parts[1].trim() : '';
      return <String>{
        'DM:Unknown User',
        if (guild.isNotEmpty) '$guild:Unknown User',
        if (user.isNotEmpty) 'DM:$user',
      }.toList(growable: false);
    default:
      return const <String>[];
  }
}

String stringifyRuntimeVariableValue(dynamic value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is List || value is Map) {
    return jsonEncode(value);
  }
  return value.toString();
}

Future<void> injectGlobalRuntimeVariables({
  required BotDataStore store,
  required String botId,
  required Map<String, String> runtimeVariables,
}) async {
  final globalVars = await store.getGlobalVariables(botId);
  for (final entry in globalVars.entries) {
    runtimeVariables['global.${entry.key}'] = stringifyRuntimeVariableValue(
      entry.value,
    );
  }
}

Future<void> injectScopedRuntimeVariables({
  required BotDataStore store,
  required String botId,
  required String scope,
  required String? contextId,
  required Map<String, String> runtimeVariables,
  List<String> legacyContextIds = const <String>[],
  List<Map<String, dynamic>> scopedDefinitions = const <Map<String, dynamic>>[],
}) async {
  final normalizedContextId = _normalizeContextId(contextId);
  Map<String, dynamic> values = <String, dynamic>{};
  if (normalizedContextId != null) {
    values = await store.getScopedVariables(botId, scope, normalizedContextId);
  }
  if (values.isEmpty) {
    for (final candidate in legacyContextIds) {
      final legacyContextId = candidate.trim();
      if (legacyContextId.isEmpty) {
        continue;
      }
      values = await store.getScopedVariables(botId, scope, legacyContextId);
      if (values.isNotEmpty) {
        if (normalizedContextId != null &&
            normalizedContextId != legacyContextId) {
          for (final entry in values.entries) {
            await store.setScopedVariable(
              botId,
              scope,
              normalizedContextId,
              entry.key.toString(),
              entry.value,
            );
          }
        }
        break;
      }
    }
  }

  if (scopedDefinitions.isNotEmpty) {
    for (final definition in scopedDefinitions) {
      final definitionScope = (definition['scope'] ?? '').toString().trim();
      if (definitionScope != scope) {
        continue;
      }

      final normalizedKey = _normalizeScopedStorageKey(
        (definition['key'] ?? '').toString(),
      );
      if (normalizedKey.isEmpty) {
        continue;
      }

      final existingValue =
          values.containsKey(normalizedKey)
              ? values[normalizedKey]
              : values['bc_$normalizedKey'];
      if (!_isMissingOrEmptyValue(existingValue)) {
        continue;
      }

      if (!definition.containsKey('defaultValue')) {
        continue;
      }

      values[normalizedKey] = definition['defaultValue'];
    }
  }

  for (final entry in values.entries) {
    final rawKey = entry.key.toString().trim();
    if (rawKey.isEmpty) {
      continue;
    }

    final canonicalKey = rawKey.startsWith('bc_') ? rawKey : 'bc_$rawKey';
    final value = stringifyRuntimeVariableValue(entry.value);

    runtimeVariables['$scope.$canonicalKey'] = value;
    runtimeVariables['$scope.$rawKey'] = value;
  }
}

Future<void> hydrateRuntimeVariables({
  required BotDataStore store,
  required String botId,
  required Map<String, String> runtimeVariables,
  String? guildContextId,
  String? channelContextId,
  String? userContextId,
  String? messageContextId,
}) async {
  List<Map<String, dynamic>> scopedDefinitions = const <Map<String, dynamic>>[];
  try {
    scopedDefinitions = await store.getScopedVariableDefinitions(botId);
  } catch (_) {
    scopedDefinitions = const <Map<String, dynamic>>[];
  }

  await injectGlobalRuntimeVariables(
    store: store,
    botId: botId,
    runtimeVariables: runtimeVariables,
  );

  final normalizedGuildId = _normalizeContextId(guildContextId);
  final normalizedUserId = _normalizeContextId(userContextId);
  final guildMemberContextId =
      normalizedGuildId != null && normalizedUserId != null
          ? '$normalizedGuildId:$normalizedUserId'
          : null;

  await Future.wait([
    injectScopedRuntimeVariables(
      store: store,
      botId: botId,
      scope: 'guild',
      contextId: guildContextId,
      runtimeVariables: runtimeVariables,
      legacyContextIds: _legacyContextIdsForScope('guild', guildContextId),
      scopedDefinitions: scopedDefinitions,
    ),
    injectScopedRuntimeVariables(
      store: store,
      botId: botId,
      scope: 'channel',
      contextId: channelContextId,
      runtimeVariables: runtimeVariables,
      legacyContextIds: _legacyContextIdsForScope('channel', channelContextId),
      scopedDefinitions: scopedDefinitions,
    ),
    injectScopedRuntimeVariables(
      store: store,
      botId: botId,
      scope: 'user',
      contextId: userContextId,
      runtimeVariables: runtimeVariables,
      legacyContextIds: _legacyContextIdsForScope('user', userContextId),
      scopedDefinitions: scopedDefinitions,
    ),
    injectScopedRuntimeVariables(
      store: store,
      botId: botId,
      scope: 'guildMember',
      contextId: guildMemberContextId,
      runtimeVariables: runtimeVariables,
      legacyContextIds: _legacyContextIdsForScope(
        'guildMember',
        guildMemberContextId,
      ),
      scopedDefinitions: scopedDefinitions,
    ),
    injectScopedRuntimeVariables(
      store: store,
      botId: botId,
      scope: 'message',
      contextId: messageContextId,
      runtimeVariables: runtimeVariables,
      legacyContextIds: _legacyContextIdsForScope('message', messageContextId),
      scopedDefinitions: scopedDefinitions,
    ),
  ]);
}
