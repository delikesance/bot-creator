import 'dart:convert';

import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/utils/command_autocomplete.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
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

bool _isInvalidContextId(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == 'unknown user' ||
      normalized == 'dm';
}

String? _resolveScopeContextId({
  required String scope,
  required Map<String, String> variables,
  Snowflake? guildId,
  Snowflake? channelId,
  Interaction? interaction,
}) {
  String? normalize(dynamic value) {
    final text = (value ?? '').toString().trim();
    return _isInvalidContextId(text) ? null : text;
  }

  String? fromVariables(List<String> keys) {
    for (final key in keys) {
      final value = normalize(variables[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  String? fromSnowflake(Snowflake? value) {
    return normalize(value?.toString());
  }

  String? interactionUserId() {
    final dynamic raw = interaction;
    return normalize(
      raw?.user?.id ??
          raw?.member?.user?.id ??
          raw?.member?.id ??
          raw?.interaction?.user?.id ??
          raw?.interaction?.member?.user?.id ??
          raw?.author?.id,
    );
  }

  String? interactionGuildId() {
    final dynamic raw = interaction;
    return normalize(
      raw?.guildId ?? raw?.guild?.id ?? raw?.interaction?.guildId,
    );
  }

  String? interactionChannelId() {
    final dynamic raw = interaction;
    return normalize(
      raw?.channelId ??
          raw?.channel?.id ??
          raw?.message?.channelId ??
          raw?.interaction?.channelId,
    );
  }

  String? interactionMessageId() {
    final dynamic raw = interaction;
    return normalize(raw?.message?.id ?? raw?.id);
  }

  switch (scope) {
    case 'guild':
      return fromVariables(<String>[
            'guildId',
            'guild.id',
            'interaction.guildId',
            'interaction.guild.id',
          ]) ??
          interactionGuildId() ??
          fromSnowflake(guildId);
    case 'channel':
      return fromVariables(<String>[
            'channelId',
            'channel.id',
            'interaction.channelId',
            'interaction.channel.id',
          ]) ??
          interactionChannelId() ??
          fromSnowflake(channelId);
    case 'user':
      return fromVariables(<String>[
            'userId',
            'user.id',
            'interaction.userId',
            'interaction.user.id',
            'author.id',
            'member.id',
            'interaction.member.id',
          ]) ??
          interactionUserId();
    case 'guildMember':
      final guild =
          fromVariables(<String>[
            'guildId',
            'guild.id',
            'interaction.guildId',
            'interaction.guild.id',
          ]) ??
          interactionGuildId() ??
          fromSnowflake(guildId);
      final user =
          fromVariables(<String>[
            'userId',
            'user.id',
            'interaction.userId',
            'interaction.user.id',
            'author.id',
            'member.id',
            'interaction.member.id',
          ]) ??
          interactionUserId();
      if (guild == null || user == null) {
        return null;
      }
      return '$guild:$user';
    case 'message':
      return fromVariables(<String>[
            'messageId',
            'message.id',
            'interaction.messageId',
            'interaction.message.id',
          ]) ??
          interactionMessageId();
    default:
      return null;
  }
}

dynamic _deepCloneJsonValue(dynamic value) {
  if (value == null) {
    return null;
  }
  return jsonDecode(jsonEncode(value));
}

String _normalizeJsonPath(dynamic rawPath) {
  final text = (rawPath ?? '').toString().trim();
  return text.isEmpty ? r'$' : text;
}

String _normalizeVariableTarget(Map<String, dynamic> payload) {
  final explicit = (payload['target'] ?? '').toString().trim().toLowerCase();
  if (explicit == 'global' || explicit == 'scoped') {
    return explicit;
  }
  return (payload['scope'] ?? '').toString().trim().isNotEmpty
      ? 'scoped'
      : 'global';
}

({String scope, String contextId, String storageKey, String referenceKey})
_resolveScopedBinding({
  required Map<String, dynamic> payload,
  required String Function(String input) resolveValue,
  required Map<String, String> variables,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  required Interaction? interaction,
}) {
  final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
  if (!_supportedVariableScopes.contains(scope)) {
    throw Exception(
      'scope is required and must be one of ${_supportedVariableScopes.join(', ')}',
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

  return (
    scope: scope,
    contextId: contextId,
    storageKey: storageKey,
    referenceKey: referenceKey,
  );
}

List<String> _legacyContextIdsForScope(
  String scope,
  String canonicalContextId,
) {
  switch (scope) {
    case 'user':
      return const <String>['Unknown User'];
    case 'guild':
    case 'channel':
      return const <String>['DM'];
    case 'guildMember':
      final parts = canonicalContextId.split(':');
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

Future<dynamic> _readPersistedVariable({
  required BotDataStore store,
  required String botId,
  required String target,
  required Map<String, dynamic> payload,
  required String Function(String input) resolveValue,
  required Map<String, String> variables,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  required Interaction? interaction,
}) async {
  if (target == 'global') {
    final key = resolveValue((payload['key'] ?? '').toString()).trim();
    if (key.isEmpty) {
      throw Exception('key is required for global variables');
    }
    return store.getGlobalVariable(botId, key);
  }

  final binding = _resolveScopedBinding(
    payload: payload,
    resolveValue: resolveValue,
    variables: variables,
    guildId: guildId,
    fallbackChannelId: fallbackChannelId,
    interaction: interaction,
  );
  return store.getScopedVariable(
    botId,
    binding.scope,
    binding.contextId,
    binding.storageKey,
  );
}

Future<void> _writePersistedVariable({
  required BotDataStore store,
  required String botId,
  required String target,
  required Map<String, dynamic> payload,
  required String Function(String input) resolveValue,
  required Map<String, String> variables,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  required Interaction? interaction,
  required dynamic value,
}) async {
  if (target == 'global') {
    final key = resolveValue((payload['key'] ?? '').toString()).trim();
    if (key.isEmpty) {
      throw Exception('key is required for global variables');
    }
    await store.setGlobalVariable(botId, key, value);
    variables['global.$key'] = _stringifyRuntimeValue(value);
    return;
  }

  final binding = _resolveScopedBinding(
    payload: payload,
    resolveValue: resolveValue,
    variables: variables,
    guildId: guildId,
    fallbackChannelId: fallbackChannelId,
    interaction: interaction,
  );
  await store.setScopedVariable(
    botId,
    binding.scope,
    binding.contextId,
    binding.storageKey,
    value,
  );
  final runtimeValue = _stringifyRuntimeValue(value);
  variables['${binding.scope}.${binding.referenceKey}'] = runtimeValue;
  if ((payload['key'] ?? '').toString().trim() != binding.referenceKey) {
    variables['${binding.scope}.${(payload['key'] ?? '').toString().trim()}'] =
        runtimeValue;
  }
}

void _storeArrayOutputs({
  required String resultKey,
  required Map<String, String> variables,
  required List<dynamic> items,
  dynamic removed,
}) {
  final itemsJson = jsonEncode(items);
  final length = items.length.toString();
  variables['action.$resultKey.items'] = itemsJson;
  variables['$resultKey.items'] = itemsJson;
  variables['action.$resultKey.length'] = length;
  variables['$resultKey.length'] = length;
  if (removed != null) {
    final removedValue = _stringifyRuntimeValue(removed);
    variables['action.$resultKey.removed'] = removedValue;
    variables['$resultKey.removed'] = removedValue;
  }
}

void _storePagedOutputs({
  required String resultKey,
  required Map<String, String> variables,
  required List<dynamic> items,
  required int total,
}) {
  final itemsJson = jsonEncode(items);
  variables['action.$resultKey.items'] = itemsJson;
  variables['$resultKey.items'] = itemsJson;
  variables['action.$resultKey.count'] = items.length.toString();
  variables['$resultKey.count'] = items.length.toString();
  variables['action.$resultKey.total'] = total.toString();
  variables['$resultKey.total'] = total.toString();
}

bool _mutateJsonPathList(
  dynamic root,
  String rawPath,
  List<dynamic> Function(List<dynamic>? current) update,
) {
  final path = _normalizeJsonPath(rawPath);
  if (path == r'$') {
    if (root is! List<dynamic>) {
      final next = update(null);
      if (root is List) {
        root
          ..clear()
          ..addAll(next);
      }
      return false;
    }
    final next = update(root);
    root
      ..clear()
      ..addAll(next);
    return true;
  }

  final segments = parseJsonPathSegments(path);
  if (segments == null || segments.isEmpty) {
    return false;
  }

  dynamic current = root;
  for (var index = 0; index < segments.length - 1; index++) {
    final segment = segments[index];
    final nextSegment = segments[index + 1];
    if (segment is String) {
      if (current is! Map) {
        return false;
      }
      if (!current.containsKey(segment) || current[segment] == null) {
        current[segment] =
            nextSegment is int ? <dynamic>[] : <String, dynamic>{};
      }
      current = current[segment];
      continue;
    }

    if (segment is int) {
      if (current is! List || segment < 0 || segment >= current.length) {
        return false;
      }
      current = current[segment];
    }
  }

  final last = segments.last;
  if (last is String) {
    if (current is! Map) {
      return false;
    }
    final next = update(
      current[last] is List ? List<dynamic>.from(current[last] as List) : null,
    );
    current[last] = next;
    return true;
  }

  if (last is int) {
    if (current is! List || last < 0 || last >= current.length) {
      return false;
    }
    final currentValue = current[last];
    final next = update(
      currentValue is List ? List<dynamic>.from(currentValue) : null,
    );
    current[last] = next;
    return true;
  }

  return false;
}

List<dynamic> _ensureUpdatedArray(dynamic root, String rawPath) {
  if (_normalizeJsonPath(rawPath) == r'$') {
    if (root is List) {
      return List<dynamic>.from(root);
    }
    return const <dynamic>[];
  }

  final extracted = extractJsonPathValue(root, rawPath);
  if (extracted is List) {
    return List<dynamic>.from(extracted);
  }
  return const <dynamic>[];
}

List<dynamic> _extractArrayFromJsonInput(String input, String rawPath) {
  final decoded = decodeJsonStringIfNeeded(input);
  final target =
      _normalizeJsonPath(rawPath) == r'$'
          ? decoded
          : extractJsonPathValue(decoded, rawPath);
  if (target is List) {
    return List<dynamic>.from(target);
  }
  return <dynamic>[];
}

bool _matchesFilter({
  required String candidate,
  required String operator,
  required String expected,
}) {
  final op = operator.trim().toLowerCase();
  final leftLower = candidate.toLowerCase();
  final rightLower = expected.toLowerCase();

  switch (op) {
    case 'contains':
      return leftLower.contains(rightLower);
    case 'equals':
      final leftNum = num.tryParse(candidate);
      final rightNum = num.tryParse(expected);
      if (leftNum != null && rightNum != null) {
        return leftNum == rightNum;
      }
      return candidate == expected;
    case 'startswith':
      return leftLower.startsWith(rightLower);
    case 'endswith':
      return leftLower.endsWith(rightLower);
    case 'gt':
    case 'gte':
    case 'lt':
    case 'lte':
      final leftNum = num.tryParse(candidate);
      final rightNum = num.tryParse(expected);
      if (leftNum == null || rightNum == null) {
        return false;
      }
      switch (op) {
        case 'gt':
          return leftNum > rightNum;
        case 'gte':
          return leftNum >= rightNum;
        case 'lt':
          return leftNum < rightNum;
        case 'lte':
          return leftNum <= rightNum;
        default:
          return false;
      }
    default:
      return false;
  }
}

int _compareSortValues(String left, String right, bool descending) {
  final leftNum = num.tryParse(left);
  final rightNum = num.tryParse(right);
  final comparison =
      leftNum != null && rightNum != null
          ? leftNum.compareTo(rightNum)
          : left.toLowerCase().compareTo(right.toLowerCase());
  return descending ? -comparison : comparison;
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
      if (value == null) {
        final legacyContextIds = _legacyContextIdsForScope(scope, contextId);
        for (final legacyContextId in legacyContextIds) {
          value = await store.getScopedVariable(
            botId,
            scope,
            legacyContextId,
            storageKey,
          );
          if (value != null) {
            // Legacy compatibility: copy forward to canonical context, keep legacy data untouched.
            await store.setScopedVariable(
              botId,
              scope,
              contextId,
              storageKey,
              value,
            );
            break;
          }
        }
      }
      if (value == null && referenceKey != storageKey) {
        value = await store.getScopedVariable(
          botId,
          scope,
          contextId,
          referenceKey,
        );
      }
      if (value == null && referenceKey != storageKey) {
        final legacyContextIds = _legacyContextIdsForScope(scope, contextId);
        for (final legacyContextId in legacyContextIds) {
          value = await store.getScopedVariable(
            botId,
            scope,
            legacyContextId,
            referenceKey,
          );
          if (value != null) {
            await store.setScopedVariable(
              botId,
              scope,
              contextId,
              storageKey,
              value,
            );
            break;
          }
        }
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
      _storePagedOutputs(
        resultKey: resultKey,
        variables: variables,
        items: items,
        total: (page['total'] ?? items.length) as int,
      );

      final storeAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (storeAs.isNotEmpty) {
        variables[storeAs] = jsonEncode(items);
      }

      results[resultKey] = jsonEncode(items);
      return true;

    case BotCreatorActionType.appendArrayElement:
      final target = _normalizeVariableTarget(payload);
      final path = _normalizeJsonPath(
        resolveValue((payload['path'] ?? r'$').toString()),
      );
      final rootValue = await _readPersistedVariable(
        store: store,
        botId: botId,
        target: target,
        payload: payload,
        resolveValue: resolveValue,
        variables: variables,
        guildId: guildId,
        fallbackChannelId: fallbackChannelId,
        interaction: interaction,
      );
      final clonedRoot =
          path == r'$'
              ? <dynamic>[]
              : (_deepCloneJsonValue(rootValue) ?? <String, dynamic>{});
      final element = _resolveVariableValuePayload(payload, resolveValue);
      if (path == r'$') {
        final list =
            rootValue is List ? List<dynamic>.from(rootValue) : <dynamic>[];
        list.add(element);
        await _writePersistedVariable(
          store: store,
          botId: botId,
          target: target,
          payload: payload,
          resolveValue: resolveValue,
          variables: variables,
          guildId: guildId,
          fallbackChannelId: fallbackChannelId,
          interaction: interaction,
          value: list,
        );
        _storeArrayOutputs(
          resultKey: resultKey,
          variables: variables,
          items: list,
        );
        results[resultKey] = jsonEncode(list);
        return true;
      }

      _mutateJsonPathList(clonedRoot, path, (current) {
        final next = List<dynamic>.from(current ?? const <dynamic>[]);
        next.add(element);
        return next;
      });
      final updated = _ensureUpdatedArray(clonedRoot, path);
      await _writePersistedVariable(
        store: store,
        botId: botId,
        target: target,
        payload: payload,
        resolveValue: resolveValue,
        variables: variables,
        guildId: guildId,
        fallbackChannelId: fallbackChannelId,
        interaction: interaction,
        value: clonedRoot,
      );
      _storeArrayOutputs(
        resultKey: resultKey,
        variables: variables,
        items: updated,
      );
      results[resultKey] = jsonEncode(updated);
      return true;

    case BotCreatorActionType.removeArrayElement:
      final target = _normalizeVariableTarget(payload);
      final path = _normalizeJsonPath(
        resolveValue((payload['path'] ?? r'$').toString()),
      );
      final index = int.tryParse(
        resolveValue((payload['index'] ?? '').toString()).trim(),
      );
      if (index == null) {
        throw Exception('index is required for removeArrayElement');
      }

      final rootValue = await _readPersistedVariable(
        store: store,
        botId: botId,
        target: target,
        payload: payload,
        resolveValue: resolveValue,
        variables: variables,
        guildId: guildId,
        fallbackChannelId: fallbackChannelId,
        interaction: interaction,
      );
      dynamic removed;
      if (path == r'$') {
        final list =
            rootValue is List ? List<dynamic>.from(rootValue) : <dynamic>[];
        if (index >= 0 && index < list.length) {
          removed = list.removeAt(index);
        }
        await _writePersistedVariable(
          store: store,
          botId: botId,
          target: target,
          payload: payload,
          resolveValue: resolveValue,
          variables: variables,
          guildId: guildId,
          fallbackChannelId: fallbackChannelId,
          interaction: interaction,
          value: list,
        );
        _storeArrayOutputs(
          resultKey: resultKey,
          variables: variables,
          items: list,
          removed: removed,
        );
        results[resultKey] = jsonEncode(list);
        return true;
      }

      final clonedRoot = _deepCloneJsonValue(rootValue) ?? <String, dynamic>{};
      _mutateJsonPathList(clonedRoot, path, (current) {
        final next = List<dynamic>.from(current ?? const <dynamic>[]);
        if (index >= 0 && index < next.length) {
          removed = next.removeAt(index);
        }
        return next;
      });
      final updated = _ensureUpdatedArray(clonedRoot, path);
      await _writePersistedVariable(
        store: store,
        botId: botId,
        target: target,
        payload: payload,
        resolveValue: resolveValue,
        variables: variables,
        guildId: guildId,
        fallbackChannelId: fallbackChannelId,
        interaction: interaction,
        value: clonedRoot,
      );
      _storeArrayOutputs(
        resultKey: resultKey,
        variables: variables,
        items: updated,
        removed: removed,
      );
      results[resultKey] = jsonEncode(updated);
      return true;

    case BotCreatorActionType.queryArray:
      final input = resolveValue((payload['input'] ?? '').toString());
      final path = _normalizeJsonPath(
        resolveValue((payload['path'] ?? r'$').toString()),
      );
      final items = _extractArrayFromJsonInput(input, path);
      final filterTemplate =
          (payload['filterTemplate'] ?? '{value}').toString();
      final filterOperator =
          resolveValue((payload['filterOperator'] ?? '').toString()).trim();
      final filterValue =
          resolveValue((payload['filterValue'] ?? '').toString()).trim();
      final sortTemplate = (payload['sortTemplate'] ?? '{value}').toString();
      final order =
          resolveValue(
            (payload['order'] ?? 'asc').toString(),
          ).trim().toLowerCase();
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

      var working = List<dynamic>.from(items);
      if (filterOperator.isNotEmpty && filterValue.isNotEmpty) {
        working = working
            .where((item) {
              final candidate = resolveItemTemplate(
                filterTemplate,
                item,
                variables,
              );
              return _matchesFilter(
                candidate: candidate,
                operator: filterOperator,
                expected: filterValue,
              );
            })
            .toList(growable: false);
      }

      working.sort((left, right) {
        final leftValue = resolveItemTemplate(sortTemplate, left, variables);
        final rightValue = resolveItemTemplate(sortTemplate, right, variables);
        return _compareSortValues(leftValue, rightValue, order == 'desc');
      });

      final safeOffset = offset < 0 ? 0 : offset;
      final safeLimit = limit < 1 ? 1 : (limit > 100 ? 100 : limit);
      final start = safeOffset.clamp(0, working.length);
      final end = (start + safeLimit).clamp(start, working.length);
      final page = working.sublist(start, end);

      _storePagedOutputs(
        resultKey: resultKey,
        variables: variables,
        items: page,
        total: working.length,
      );
      final storeAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (storeAs.isNotEmpty) {
        variables[storeAs] = jsonEncode(page);
      }
      results[resultKey] = jsonEncode(page);
      return true;

    case BotCreatorActionType.respondWithAutocomplete:
      if (interaction is! ApplicationCommandAutocompleteInteraction) {
        throw Exception(
          'respondWithAutocomplete requires an autocomplete interaction context',
        );
      }

      final itemsInput = resolveValue((payload['items'] ?? '').toString());
      final path = _normalizeJsonPath(
        resolveValue((payload['path'] ?? r'$').toString()),
      );
      final items = _extractArrayFromJsonInput(itemsInput, path);
      final labelTemplate = (payload['labelTemplate'] ?? '{value}').toString();
      final valueTemplate = (payload['valueTemplate'] ?? '{value}').toString();

      final focused =
          variables['autocomplete.optionType']?.trim().toLowerCase() ??
          commandOptionTypeToText(
            findFocusedInteractionOption(interaction.data.options)?.type ??
                CommandOptionType.string,
          ).toLowerCase();

      final builders = <CommandOptionChoiceBuilder<dynamic>>[];
      for (final item in items) {
        if (builders.length >= 25) {
          break;
        }
        final label =
            resolveItemTemplate(labelTemplate, item, variables).trim();
        final rawValue =
            resolveItemTemplate(valueTemplate, item, variables).trim();
        if (label.isEmpty || rawValue.isEmpty) {
          continue;
        }

        dynamic typedValue;
        switch (focused) {
          case 'integer':
            typedValue = int.tryParse(rawValue);
            break;
          case 'number':
            typedValue = double.tryParse(rawValue);
            break;
          default:
            typedValue = rawValue;
            break;
        }

        if (typedValue == null) {
          continue;
        }

        builders.add(
          CommandOptionChoiceBuilder<dynamic>(name: label, value: typedValue),
        );
      }

      await interaction.respond(builders);
      results[resultKey] = 'RESPONDED';
      results['__stopped__'] = 'AUTOCOMPLETE';
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
