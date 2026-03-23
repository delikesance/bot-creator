import 'dart:convert';

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

  if (payload.containsKey('element') && payload['element'] is num) {
    return payload['element'] as num;
  }

  if (valueType == 'boolean' || valueType == 'bool') {
    final rawBool =
        resolveValue(
          (payload['boolValue'] ?? '').toString(),
        ).trim().toLowerCase();
    if (rawBool == 'true') {
      return true;
    }
    if (rawBool == 'false') {
      return false;
    }
    throw Exception(
      'boolValue is required and must be true or false when valueType=boolean',
    );
  }

  if (valueType == 'json') {
    final rawJson =
        resolveValue((payload['jsonValue'] ?? '').toString()).trim();
    if (rawJson.isEmpty) {
      throw Exception('jsonValue is required when valueType=json');
    }
    try {
      return jsonDecode(rawJson);
    } catch (error) {
      throw Exception('jsonValue must be valid JSON: $error');
    }
  }

  final rawValue =
      payload.containsKey('value') ? payload['value'] : payload['element'];
  return resolveValue((rawValue ?? '').toString());
}

String _stringifyRuntimeValue(dynamic value) {
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
      final runtimeValue = _stringifyRuntimeValue(value);
      variables['$scope.$referenceKey'] = runtimeValue;
      if (rawKey.isNotEmpty && rawKey != referenceKey) {
        variables['$scope.$rawKey'] = runtimeValue;
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
      final runtimeValue = _stringifyRuntimeValue(value);
      final storeAs =
          resolveValue(
            (payload['storeAs'] ?? '$scope.$referenceKey').toString(),
          ).trim();
      if (storeAs.isNotEmpty) {
        variables[storeAs] = runtimeValue;
      }
      variables['$scope.$referenceKey'] = runtimeValue;
      if (rawKey.isNotEmpty && rawKey != referenceKey) {
        variables['$scope.$rawKey'] = runtimeValue;
      }
      results[resultKey] = runtimeValue;
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

    case BotCreatorActionType.listScopedVariableIndex:
      final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(scope)) {
        throw Exception(
          'scope is required for listScopedVariableIndex and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }

      final rawKey = resolveValue((payload['key'] ?? '').toString()).trim();
      final storageKey = _scopedStorageKey(rawKey);
      final offset =
          int.tryParse(
            resolveValue((payload['offset'] ?? '0').toString()).trim(),
          ) ??
          0;
      final limit =
          int.tryParse(
            resolveValue((payload['limit'] ?? '25').toString()).trim(),
          ) ??
          25;
      final safeOffset = offset < 0 ? 0 : offset;
      final safeLimit = limit < 1 ? 1 : (limit > 25 ? 25 : limit);
      final order =
          resolveValue(
            (payload['order'] ?? 'desc').toString(),
          ).trim().toLowerCase();

      final page = await store.queryScopedVariableIndex(
        botId,
        scope,
        storageKey,
        offset: safeOffset,
        limit: safeLimit,
        descending: order != 'asc',
      );
      final items = List<Map<String, dynamic>>.from(
        (page['items'] as List?)?.whereType<Map>().map(
              (entry) => Map<String, dynamic>.from(entry),
            ) ??
            const <Map<String, dynamic>>[],
      );
      final itemsJson = jsonEncode(items);
      final count = (page['count'] ?? items.length).toString();
      final total = (page['total'] ?? items.length).toString();

      variables['action.$resultKey.items'] = itemsJson;
      variables['$resultKey.items'] = itemsJson;
      variables['action.$resultKey.count'] = count;
      variables['$resultKey.count'] = count;
      variables['action.$resultKey.total'] = total;
      variables['$resultKey.total'] = total;

      final storeAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (storeAs.isNotEmpty) {
        variables[storeAs] = itemsJson;
      }

      results[resultKey] = itemsJson;
      return true;

    // Array operations
    case BotCreatorActionType.pushScopedArrayElement:
      final pushScope =
          resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(pushScope)) {
        throw Exception(
          'scope is required for pushScopedArrayElement and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }
      final pushContextId = _resolveScopeContextId(
        scope: pushScope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (pushContextId == null || pushContextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$pushScope"');
      }
      final pushKey = _scopedStorageKey(
        resolveValue((payload['key'] ?? '').toString()).trim(),
      );
      final pushElement = _resolveVariableValuePayload(payload, resolveValue);
      await store.pushScopedArrayElement(
        botId,
        pushScope,
        pushContextId,
        pushKey,
        pushElement,
      );
      // After push, get the array length to return as feedback
      final pushLength = await store.getScopedArrayLength(
        botId,
        pushScope,
        pushContextId,
        pushKey,
      );
      final pushStoreAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (pushStoreAs.isNotEmpty) {
        // Store the length in the variable if requested
        variables[pushStoreAs] = pushLength.toString();
      }
      results[resultKey] = pushLength.toString();
      return true;

    case BotCreatorActionType.popScopedArrayElement:
      final popScope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(popScope)) {
        throw Exception('scope is required for popScopedArrayElement');
      }
      final popContextId = _resolveScopeContextId(
        scope: popScope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (popContextId == null || popContextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$popScope"');
      }
      final popKey = _scopedStorageKey(
        resolveValue((payload['key'] ?? '').toString()).trim(),
      );
      final popped = await store.popScopedArrayElement(
        botId,
        popScope,
        popContextId,
        popKey,
      );
      final poppedStr = _stringifyRuntimeValue(popped);
      final popStoreAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (popStoreAs.isNotEmpty) {
        variables[popStoreAs] = poppedStr;
      }
      results[resultKey] = poppedStr;
      return true;

    case BotCreatorActionType.removeScopedArrayElement:
      final rmScope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(rmScope)) {
        throw Exception('scope is required for removeScopedArrayElement');
      }
      final rmContextId = _resolveScopeContextId(
        scope: rmScope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (rmContextId == null || rmContextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$rmScope"');
      }
      final rmKey = _scopedStorageKey(
        resolveValue((payload['key'] ?? '').toString()).trim(),
      );
      final rmIndex =
          int.tryParse(
            resolveValue((payload['index'] ?? '0').toString()).trim(),
          ) ??
          0;
      final removed = await store.removeScopedArrayElement(
        botId,
        rmScope,
        rmContextId,
        rmKey,
        rmIndex,
      );
      final removedStr = _stringifyRuntimeValue(removed);
      final rmStoreAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (rmStoreAs.isNotEmpty) {
        variables[rmStoreAs] = removedStr;
      }
      results[resultKey] = removedStr;
      return true;

    case BotCreatorActionType.getScopedArrayElement:
      final getScope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(getScope)) {
        throw Exception('scope is required for getScopedArrayElement');
      }
      final getContextId = _resolveScopeContextId(
        scope: getScope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (getContextId == null || getContextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$getScope"');
      }
      final getKey = _scopedStorageKey(
        resolveValue((payload['key'] ?? '').toString()).trim(),
      );
      final getIndex =
          int.tryParse(
            resolveValue((payload['index'] ?? '0').toString()).trim(),
          ) ??
          0;
      final element = await store.getScopedArrayElement(
        botId,
        getScope,
        getContextId,
        getKey,
        getIndex,
      );
      final elementStr = _stringifyRuntimeValue(element);
      final getStoreAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (getStoreAs.isNotEmpty) {
        variables[getStoreAs] = elementStr;
      }
      results[resultKey] = elementStr;
      return true;

    case BotCreatorActionType.getScopedArrayLength:
      final lenScope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(lenScope)) {
        throw Exception('scope is required for getScopedArrayLength');
      }
      final lenContextId = _resolveScopeContextId(
        scope: lenScope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (lenContextId == null || lenContextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$lenScope"');
      }
      final lenKey = _scopedStorageKey(
        resolveValue((payload['key'] ?? '').toString()).trim(),
      );
      final length = await store.getScopedArrayLength(
        botId,
        lenScope,
        lenContextId,
        lenKey,
      );
      final lengthStr = length.toString();
      final lenStoreAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (lenStoreAs.isNotEmpty) {
        variables[lenStoreAs] = lengthStr;
      }
      results[resultKey] = lengthStr;
      return true;

    case BotCreatorActionType.listScopedArrayElements:
      final listScope =
          resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(listScope)) {
        throw Exception('scope is required for listScopedArrayElements');
      }
      final listContextId = _resolveScopeContextId(
        scope: listScope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (listContextId == null || listContextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$listScope"');
      }
      final listKey = _scopedStorageKey(
        resolveValue((payload['key'] ?? '').toString()).trim(),
      );
      final listOffset =
          int.tryParse(
            resolveValue((payload['offset'] ?? '0').toString()).trim(),
          ) ??
          0;
      final listLimit =
          int.tryParse(
            resolveValue((payload['limit'] ?? '25').toString()).trim(),
          ) ??
          25;
      final safeListOffset = listOffset < 0 ? 0 : listOffset;
      final safeListLimit =
          listLimit < 1 ? 1 : (listLimit > 25 ? 25 : listLimit);
      final listOrder =
          resolveValue(
            (payload['order'] ?? 'desc').toString(),
          ).trim().toLowerCase();
      final listFilter =
          resolveValue((payload['filter'] ?? '').toString()).trim();

      final arrayPage = await store.queryScopedArray(
        botId,
        listScope,
        listContextId,
        listKey,
        offset: safeListOffset,
        limit: safeListLimit,
        descending: listOrder != 'asc',
        filter: listFilter.isEmpty ? null : listFilter,
      );
      final arrayItems = List<dynamic>.from(arrayPage['items'] as List? ?? []);
      final arrayItemsJson = jsonEncode(arrayItems);
      final arrayCount = (arrayPage['count'] ?? arrayItems.length).toString();
      final arrayTotal = (arrayPage['total'] ?? arrayItems.length).toString();

      // Create a formatted text representation for easy display
      final itemsDisplay =
          arrayItems.isEmpty
              ? '(empty)'
              : arrayItems
                  .map((e) => '• ${_stringifyRuntimeValue(e)}')
                  .join('\n');

      variables['action.$resultKey.items'] = arrayItemsJson;
      variables['$resultKey.items'] = arrayItemsJson;
      variables['action.$resultKey.display'] = itemsDisplay;
      variables['$resultKey.display'] = itemsDisplay;
      variables['action.$resultKey.count'] = arrayCount;
      variables['$resultKey.count'] = arrayCount;
      variables['action.$resultKey.total'] = arrayTotal;
      variables['$resultKey.total'] = arrayTotal;

      // Create individual item variables for easy access
      // e.g., myArray.0, myArray.1, myArray.2, etc.
      for (int i = 0; i < arrayItems.length; i++) {
        final itemStr = _stringifyRuntimeValue(arrayItems[i]);
        variables['action.$resultKey.$i'] = itemStr;
        variables['$resultKey.$i'] = itemStr;
      }

      final listStoreAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (listStoreAs.isNotEmpty) {
        variables[listStoreAs] = arrayItemsJson;
        // Also create individual items under the custom alias
        for (int i = 0; i < arrayItems.length; i++) {
          final itemStr = _stringifyRuntimeValue(arrayItems[i]);
          variables['$listStoreAs.$i'] = itemStr;
        }
      }

      results[resultKey] = itemsDisplay;
      return true;

    case BotCreatorActionType.setGlobalVariable:
      final key = resolveValue((payload['key'] ?? '').toString()).trim();
      if (key.isEmpty) {
        throw Exception('key is required for setGlobalVariable');
      }
      final value = _resolveVariableValuePayload(payload, resolveValue);
      await store.setGlobalVariable(botId, key, value);
      variables['global.$key'] = _stringifyRuntimeValue(value);
      results[resultKey] = 'OK';
      return true;

    case BotCreatorActionType.getGlobalVariable:
      final key = resolveValue((payload['key'] ?? '').toString()).trim();
      if (key.isEmpty) {
        throw Exception('key is required for getGlobalVariable');
      }
      final value = await store.getGlobalVariable(botId, key) ?? '';
      final valueAsString = _stringifyRuntimeValue(value);
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
