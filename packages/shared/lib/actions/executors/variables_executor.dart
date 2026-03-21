import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';

const _supportedVariableScopes = <String>{
  'guild',
  'user',
  'channel',
  'guildMember',
  'message',
};

String _scopedStorageKey(String rawKey) {
  final key = rawKey.trim();
  if (key.isEmpty) {
    throw Exception('key is required for scoped variables');
  }
  if (key.startsWith('bc_')) {
    if (key.length <= 3) {
      throw Exception('key is required for scoped variables');
    }
    return key.substring(3);
  }
  return key;
}

String _scopedReferenceKey(String rawKey) {
  final key = rawKey.trim();
  if (key.isEmpty) {
    throw Exception('key is required for scoped variables');
  }
  return key.startsWith('bc_') ? key : 'bc_$key';
}

dynamic _resolveVariableValuePayload(
  Map<String, dynamic> payload,
  String Function(String input) resolveValue,
) {
  final valueType =
      (payload['valueType'] ?? '').toString().trim().toLowerCase();
  if (valueType == 'number') {
    final rawNumber =
        resolveValue((payload['numberValue'] ?? '').toString()).trim();
    final number = num.tryParse(rawNumber);
    if (number == null) {
      throw Exception(
        'numberValue is required and must be numeric when valueType=number',
      );
    }
    return number;
  }

  if (payload.containsKey('value') && payload['value'] is num) {
    return payload['value'] as num;
  }

  return resolveValue((payload['value'] ?? '').toString());
}

String? _resolveScopeContextId({
  required String scope,
  required Map<String, String> variables,
  Snowflake? guildId,
  Snowflake? channelId,
  Interaction? interaction,
}) {
  String? fromVariables(String key) {
    final value = variables[key]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? fromSnowflake(Snowflake? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? interactionUserId() {
    final dynamic raw = interaction;
    final value = (raw?.user?.id ?? raw?.author?.id)?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? interactionMessageId() {
    final dynamic raw = interaction;
    final value = (raw?.message?.id ?? raw?.id)?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  switch (scope) {
    case 'guild':
      return fromVariables('guildId') ?? fromSnowflake(guildId);
    case 'channel':
      return fromVariables('channelId') ?? fromSnowflake(channelId);
    case 'user':
      return fromVariables('userId') ?? interactionUserId();
    case 'guildMember':
      {
        final guild = fromVariables('guildId') ?? fromSnowflake(guildId);
        final user = fromVariables('userId') ?? interactionUserId();
        if (guild == null || user == null) {
          return null;
        }
        return '$guild:$user';
      }
    case 'message':
      return fromVariables('messageId') ??
          fromVariables('message.id') ??
          interactionMessageId();
    default:
      return null;
  }
}

Future<bool> executeVariablesAction({
  required BotCreatorActionType type,
  required BotDataStore store,
  required String botId,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  required Interaction? interaction,
}) async {
  switch (type) {
    case BotCreatorActionType.setScopedVariable:
      final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(scope)) {
        throw Exception(
          'scope is required for setScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }

      final rawKey = resolveValue((payload['key'] ?? '').toString()).trim();
      final storageKey = _scopedStorageKey(rawKey);
      final referenceKey = _scopedReferenceKey(rawKey);

      final contextId = _resolveScopeContextId(
        scope: scope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (contextId == null || contextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$scope"');
      }

      final value = _resolveVariableValuePayload(payload, resolveValue);
      await store.setScopedVariable(botId, scope, contextId, storageKey, value);
      variables['$scope.$referenceKey'] = value.toString();
      if (rawKey.isNotEmpty && rawKey != referenceKey) {
        variables['$scope.$rawKey'] = value.toString();
      }
      results[resultKey] = 'OK';
      return true;

    case BotCreatorActionType.getScopedVariable:
      final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(scope)) {
        throw Exception(
          'scope is required for getScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }

      final rawKey = resolveValue((payload['key'] ?? '').toString()).trim();
      final storageKey = _scopedStorageKey(rawKey);
      final referenceKey = _scopedReferenceKey(rawKey);

      final contextId = _resolveScopeContextId(
        scope: scope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (contextId == null || contextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$scope"');
      }

      var value = await store.getScopedVariable(
        botId,
        scope,
        contextId,
        storageKey,
      );
      if (value == null && referenceKey != storageKey) {
        value = await store.getScopedVariable(
          botId,
          scope,
          contextId,
          referenceKey,
        );
      }
      value ??= '';
      final storeAs =
          resolveValue(
            (payload['storeAs'] ?? '$scope.$referenceKey').toString(),
          ).trim();
      if (storeAs.isNotEmpty) {
        variables[storeAs] = value.toString();
      }
      variables['$scope.$referenceKey'] = value.toString();
      if (rawKey.isNotEmpty && rawKey != referenceKey) {
        variables['$scope.$rawKey'] = value.toString();
      }
      results[resultKey] = value.toString();
      return true;

    case BotCreatorActionType.removeScopedVariable:
      final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(scope)) {
        throw Exception(
          'scope is required for removeScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }

      final rawKey = resolveValue((payload['key'] ?? '').toString()).trim();
      final storageKey = _scopedStorageKey(rawKey);
      final referenceKey = _scopedReferenceKey(rawKey);

      final contextId = _resolveScopeContextId(
        scope: scope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (contextId == null || contextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$scope"');
      }

      await store.removeScopedVariable(botId, scope, contextId, storageKey);
      if (referenceKey != storageKey) {
        await store.removeScopedVariable(botId, scope, contextId, referenceKey);
      }
      variables.remove('$scope.$referenceKey');
      if (rawKey.isNotEmpty && rawKey != referenceKey) {
        variables.remove('$scope.$rawKey');
      }
      results[resultKey] = 'REMOVED';
      return true;

    case BotCreatorActionType.renameScopedVariable:
      final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(scope)) {
        throw Exception(
          'scope is required for renameScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }

      final oldRawKey =
          resolveValue((payload['oldKey'] ?? '').toString()).trim();
      final newRawKey =
          resolveValue((payload['newKey'] ?? '').toString()).trim();
      final oldStorageKey = _scopedStorageKey(oldRawKey);
      final newStorageKey = _scopedStorageKey(newRawKey);
      final oldReferenceKey = _scopedReferenceKey(oldRawKey);
      final newReferenceKey = _scopedReferenceKey(newRawKey);

      final contextId = _resolveScopeContextId(
        scope: scope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (contextId == null || contextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$scope"');
      }

      await store.renameScopedVariable(
        botId,
        scope,
        contextId,
        oldStorageKey,
        newStorageKey,
      );
      if (oldReferenceKey != oldStorageKey) {
        final legacyValue = await store.getScopedVariable(
          botId,
          scope,
          contextId,
          oldReferenceKey,
        );
        if (legacyValue != null) {
          await store.setScopedVariable(
            botId,
            scope,
            contextId,
            newStorageKey,
            legacyValue,
          );
          await store.removeScopedVariable(
            botId,
            scope,
            contextId,
            oldReferenceKey,
          );
        }
      }
      final oldRuntimeKey = '$scope.$oldReferenceKey';
      final newRuntimeKey = '$scope.$newReferenceKey';
      if (variables.containsKey(oldRuntimeKey)) {
        final runtimeValue = variables.remove(oldRuntimeKey);
        if (runtimeValue != null) {
          variables[newRuntimeKey] = runtimeValue;
          if (oldRawKey.isNotEmpty && oldRawKey != oldReferenceKey) {
            variables.remove('$scope.$oldRawKey');
          }
          if (newRawKey.isNotEmpty && newRawKey != newReferenceKey) {
            variables['$scope.$newRawKey'] = runtimeValue;
          }
        }
      }
      results[resultKey] = 'RENAMED';
      return true;

    case BotCreatorActionType.setGlobalVariable:
      final key = resolveValue((payload['key'] ?? '').toString()).trim();
      if (key.isEmpty) {
        throw Exception('key is required for setGlobalVariable');
      }
      final value = _resolveVariableValuePayload(payload, resolveValue);
      await store.setGlobalVariable(botId, key, value);
      variables['global.$key'] = value.toString();
      results[resultKey] = 'OK';
      return true;

    case BotCreatorActionType.getGlobalVariable:
      final key = resolveValue((payload['key'] ?? '').toString()).trim();
      if (key.isEmpty) {
        throw Exception('key is required for getGlobalVariable');
      }
      final value = await store.getGlobalVariable(botId, key) ?? '';
      final valueAsString = value.toString();
      final storeAs =
          resolveValue((payload['storeAs'] ?? 'global.$key').toString()).trim();
      if (storeAs.isNotEmpty) {
        variables[storeAs] = valueAsString;
      }
      variables['global.$key'] = valueAsString;
      results[resultKey] = valueAsString;
      return true;

    case BotCreatorActionType.removeGlobalVariable:
      final key = resolveValue((payload['key'] ?? '').toString()).trim();
      if (key.isEmpty) {
        throw Exception('key is required for removeGlobalVariable');
      }
      await store.removeGlobalVariable(botId, key);
      variables.remove('global.$key');
      results[resultKey] = 'REMOVED';
      return true;

    default:
      return false;
  }
}
