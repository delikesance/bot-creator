import 'dart:convert';

import 'package:bot_creator_shared/bot/bot_data_store.dart';

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
}) async {
  final normalizedContextId = (contextId ?? '').trim();
  if (normalizedContextId.isEmpty) {
    return;
  }

  final values = await store.getScopedVariables(
    botId,
    scope,
    normalizedContextId,
  );
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
  await injectGlobalRuntimeVariables(
    store: store,
    botId: botId,
    runtimeVariables: runtimeVariables,
  );

  final normalizedGuildId = (guildContextId ?? '').trim();
  final normalizedUserId = (userContextId ?? '').trim();
  final guildMemberContextId =
      normalizedGuildId.isNotEmpty && normalizedUserId.isNotEmpty
          ? '$normalizedGuildId:$normalizedUserId'
          : null;

  await injectScopedRuntimeVariables(
    store: store,
    botId: botId,
    scope: 'guild',
    contextId: guildContextId,
    runtimeVariables: runtimeVariables,
  );
  await injectScopedRuntimeVariables(
    store: store,
    botId: botId,
    scope: 'channel',
    contextId: channelContextId,
    runtimeVariables: runtimeVariables,
  );
  await injectScopedRuntimeVariables(
    store: store,
    botId: botId,
    scope: 'user',
    contextId: userContextId,
    runtimeVariables: runtimeVariables,
  );
  await injectScopedRuntimeVariables(
    store: store,
    botId: botId,
    scope: 'guildMember',
    contextId: guildMemberContextId,
    runtimeVariables: runtimeVariables,
  );
  await injectScopedRuntimeVariables(
    store: store,
    botId: botId,
    scope: 'message',
    contextId: messageContextId,
    runtimeVariables: runtimeVariables,
  );
}
