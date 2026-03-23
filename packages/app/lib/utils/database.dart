import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:bot_creator/stores/sqlite_variable_store.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:bot_creator/utils/workflow_call.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nyxx/nyxx.dart';

class AppManager implements BotDataStore {
  static final AppManager _instance = AppManager._internal();
  factory AppManager() => _instance;
  final StreamController<List<dynamic>> _appsStreamController =
      StreamController<List<dynamic>>.broadcast();
  List<dynamic> _apps = [];
  late SqliteVariableStore _variableStore;
  final Map<String, Future<void>> _appWriteChains = <String, Future<void>>{};

  AppManager._internal() {
    unawaited(_init());
  }

  static Future<String> _path() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<String> get path async =>
      (await getApplicationDocumentsDirectory()).path;

  Future<void> _init() async {
    final path = await _path();
    final appsDir = Directory("$path/apps");
    if (!await appsDir.exists()) {
      await appsDir.create(recursive: true);
    }

    try {
      _variableStore = SqliteVariableStore();
      await _variableStore.init();
    } catch (error) {
      debugPrint('[AppManager._init] SQLite init failed: $error');
    }

    try {
      await getAllApps();
      await _writeWorkflowCompatibilityReportIfDebug();
    } catch (error) {
      debugPrint('[AppManager._init] App list load failed: $error');
      _apps = [];
    }

    _appsStreamController.add(_apps);
    _startStreamUpdateLoop();
  }

  void _startStreamUpdateLoop() async {
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      _appsStreamController.add(_apps);
    }
  }

  Future<File> createOrUpdateApp(
    User user,
    String token, {
    Map<String, bool>? intents,
  }) async {
    final botId = user.id.toString();
    return await _enqueueAppWrite(botId, () async {
      final path = await _path();
      final file = File("$path/apps/$botId.json");
      final allAppsFile = File("$path/apps/all_apps.json");
      final avatarUri = makeAvatarUrl(
        botId,
        avatarId: user.avatarHash,
        discriminator: user.discriminator,
      );

      Map<String, dynamic> existingData = <String, dynamic>{};
      if (await file.exists()) {
        final existingContent = await file.readAsString();
        if (existingContent.isNotEmpty) {
          existingData = Map<String, dynamic>.from(
            jsonDecode(existingContent) as Map<String, dynamic>,
          );
        }
      }

      final data =
          Map<String, dynamic>.from(existingData)
            ..['name'] = user.username
            ..['id'] = botId
            ..['avatar'] = avatarUri
            ..['token'] = token
            ..['createdAt'] =
                existingData['createdAt'] ?? DateTime.now().toIso8601String()
            ..['intents'] = intents ?? existingData['intents'] ?? {}
            ..['globalVariables'] = Map<String, dynamic>.from(
              (existingData['globalVariables'] as Map?)
                      ?.cast<String, dynamic>() ??
                  const {},
            )
            ..['scopedVariables'] = Map<String, dynamic>.from(
              (existingData['scopedVariables'] as Map?)
                      ?.cast<String, dynamic>() ??
                  const {},
            )
            ..['scopedVariableDefinitions'] = List<Map<String, dynamic>>.from(
              ((existingData['scopedVariableDefinitions']) as List?)
                      ?.whereType<Map>()
                      .map((entry) => Map<String, dynamic>.from(entry)) ??
                  const <Map<String, dynamic>>[],
            )
            ..['workflows'] = List<Map<String, dynamic>>.from(
              _coerceWorkflowList(existingData['workflows']),
            )
            ..['statuses'] = List<Map<String, dynamic>>.from(
              (existingData['statuses'] as List?)?.whereType<Map>().map(
                    (status) => Map<String, dynamic>.from(status),
                  ) ??
                  const <Map<String, dynamic>>[],
            )
            ..['activities'] = List<Map<String, dynamic>>.from(
              ((existingData['activities'] ?? existingData['statuses'])
                          as List?)
                      ?.whereType<Map>()
                      .map((activity) => Map<String, dynamic>.from(activity)) ??
                  const <Map<String, dynamic>>[],
            );

      await _writeAppToDisk(botId, data);
      if (!await allAppsFile.exists()) {
        await allAppsFile.create(recursive: true);
      }

      final appsList = await getAllApps();
      final index = appsList.indexWhere((a) => a['id'] == botId);
      if (index >= 0) {
        appsList[index]['name'] = user.username;
        appsList[index]['avatar'] = avatarUri;
      } else {
        appsList.add({'name': user.username, 'avatar': avatarUri, 'id': botId});
      }

      await allAppsFile.writeAsString(jsonEncode(appsList));
      _apps = appsList;
      _appsStreamController.add(appsList);
      return file;
    });
  }

  Future<void> deleteApp(String id) async {
    final path = await _path();
    await File("$path/apps/$id.json").delete();
    await Directory("$path/apps/$id").delete(recursive: true);
    final allAppsFile = File("$path/apps/all_apps.json");
    if (!await allAppsFile.exists()) return;

    final content = await allAppsFile.readAsString();
    final appsList =
        content.isNotEmpty ? jsonDecode(content) as List<dynamic> : [];
    appsList.removeWhere((a) => a['id'] == id);

    await allAppsFile.writeAsString(jsonEncode(appsList));
    _apps = appsList;
    _appsStreamController.add(appsList);
  }

  Future<List<dynamic>> _rebuildAppsIndexFromFiles(String path) async {
    final appsDir = Directory("$path/apps");
    if (!await appsDir.exists()) {
      return const <dynamic>[];
    }

    final appsList = <Map<String, dynamic>>[];
    await for (final entity in appsDir.list()) {
      if (entity is! File ||
          !entity.path.endsWith('.json') ||
          entity.path.endsWith('all_apps.json')) {
        continue;
      }

      try {
        final content = await entity.readAsString();
        if (content.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(content);
        if (decoded is! Map || decoded['id'] == null) {
          continue;
        }

        final app = Map<String, dynamic>.from(decoded);
        appsList.add(<String, dynamic>{
          'id': app['id'].toString(),
          'name': (app['name'] ?? 'Unknown').toString(),
          'avatar': (app['avatar'] ?? '').toString(),
          if (app['guild_count'] != null) 'guild_count': app['guild_count'],
        });
      } catch (_) {}
    }

    final allAppsFile = File("$path/apps/all_apps.json");
    await allAppsFile.writeAsString(jsonEncode(appsList));
    return appsList;
  }

  Future<List<dynamic>> getAllApps() async {
    final path = await _path();
    final allAppsFile = File("$path/apps/all_apps.json");

    if (await allAppsFile.exists()) {
      try {
        final content = await allAppsFile.readAsString();
        final decoded = content.isNotEmpty ? jsonDecode(content) : const [];
        if (decoded is List) {
          final appsList = decoded
              .whereType<Map>()
              .map((raw) => Map<String, dynamic>.from(raw))
              .toList(growable: false);
          if (appsList.isNotEmpty) {
            _apps = appsList;
            return appsList;
          }
        }
      } catch (_) {}
    }

    final rebuilt = await _rebuildAppsIndexFromFiles(path);
    _apps = rebuilt;
    return rebuilt;
  }

  Stream<List<dynamic>> getAppStream() => _appsStreamController.stream;

  Future<void> refreshApps() async {
    debugPrint('[AppManager] Refreshing app list...');
    final apps = await getAllApps();
    debugPrint('[AppManager] Apps loaded from disk: ${apps.length} app(s)');
    for (final app in apps) {
      debugPrint('[AppManager]   - ${app['name'] ?? 'Unknown'} (${app['id']})');
    }
    _appsStreamController.add(apps);
    debugPrint('[AppManager] Stream updated with ${apps.length} app(s)');
  }

  Future<void> clearLogs(String id) async {
    final path = await _path();
    await File("$path/apps/$id/logs.json").delete();
  }

  Future<void> deleteAllLogs() async {
    final apps = await getAllApps();
    for (final app in apps) {
      await clearLogs(app["id"]);
    }
  }

  Future<Map<String, dynamic>> getApp(String id) async {
    final path = await _path();
    final file = File("$path/apps/$id.json");
    if (!await file.exists()) return {};

    final data = await file.readAsString();
    return data.isNotEmpty ? jsonDecode(data) : {};
  }

  Future<void> saveApp(String id, Map<String, dynamic> data) async {
    await _enqueueAppWrite(id, () => _writeAppToDisk(id, data));
  }

  Future<void> _writeAppToDisk(String id, Map<String, dynamic> data) async {
    final path = await _path();
    final file = File("$path/apps/$id.json");
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(data));
  }

  Future<T> _enqueueAppWrite<T>(String id, Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _appWriteChains[id] ?? Future<void>.value();
    late final Future<void> next;
    next = previous
        .catchError((_) {})
        .then((_) async {
          try {
            final result = await action();
            completer.complete(result);
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_appWriteChains[id], next)) {
            _appWriteChains.remove(id);
          }
        });
    _appWriteChains[id] = next;
    return completer.future;
  }

  Future<void> _mutateApp(
    String id,
    void Function(Map<String, dynamic> data) mutate,
  ) async {
    await _enqueueAppWrite(id, () async {
      final appData = Map<String, dynamic>.from(await getApp(id));
      mutate(appData);
      await _writeAppToDisk(id, appData);
    });
  }

  Future<void> updateGuildCount(String id, int count) async {
    final path = await _path();
    final appFile = File("$path/apps/$id.json");
    if (await appFile.exists()) {
      final content = await appFile.readAsString();
      if (content.isNotEmpty) {
        final data = jsonDecode(content) as Map<String, dynamic>;
        data['guild_count'] = count;
        await appFile.writeAsString(jsonEncode(data));
      }
    }
    final index = _apps.indexWhere((a) => a['id'] == id);
    if (index >= 0) {
      _apps[index]['guild_count'] = count;
      final allAppsFile = File("$path/apps/all_apps.json");
      if (await allAppsFile.exists()) {
        await allAppsFile.writeAsString(jsonEncode(_apps));
      }
      _appsStreamController.add(List<dynamic>.from(_apps));
    }
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String id) async {
    final appData = await getApp(id);
    return Map<String, dynamic>.from(
      (appData['globalVariables'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }

  @override
  Future<void> setGlobalVariable(String id, String key, dynamic value) async {
    await _mutateApp(id, (appData) {
      final globals = Map<String, dynamic>.from(
        (appData['globalVariables'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );
      globals[key] = value;
      appData['globalVariables'] = globals;
    });
  }

  @override
  Future<dynamic> getGlobalVariable(String id, String key) async {
    final globals = await getGlobalVariables(id);
    return globals[key];
  }

  @override
  Future<void> renameGlobalVariable(
    String id,
    String oldKey,
    String newKey,
  ) async {
    if (oldKey == newKey) {
      return;
    }
    await _mutateApp(id, (appData) {
      final globals = Map<String, dynamic>.from(
        (appData['globalVariables'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );
      if (!globals.containsKey(oldKey)) {
        return;
      }
      final previous = globals.remove(oldKey);
      globals[newKey] = previous;
      appData['globalVariables'] = globals;
    });
  }

  @override
  Future<void> removeGlobalVariable(String id, String key) async {
    await _mutateApp(id, (appData) {
      final globals = Map<String, dynamic>.from(
        (appData['globalVariables'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );
      globals.remove(key);
      appData['globalVariables'] = globals;
    });
  }

  @override
  Future<Map<String, dynamic>> getScopedVariables(
    String id,
    String scope,
    String contextId,
  ) async {
    return await _variableStore.getScopedVariables(id, scope, contextId);
  }

  @override
  Future<dynamic> getScopedVariable(
    String id,
    String scope,
    String contextId,
    String key,
  ) async {
    return await _variableStore.getScopedVariable(id, scope, contextId, key);
  }

  @override
  Future<void> setScopedVariable(
    String id,
    String scope,
    String contextId,
    String key,
    dynamic value,
  ) async {
    await _variableStore.setScopedVariable(id, scope, contextId, key, value);
  }

  @override
  Future<void> renameScopedVariable(
    String id,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) async {
    await _variableStore.renameScopedVariable(
      id,
      scope,
      contextId,
      oldKey,
      newKey,
    );
  }

  @override
  Future<void> removeScopedVariable(
    String id,
    String scope,
    String contextId,
    String key,
  ) async {
    await _variableStore.removeScopedVariable(id, scope, contextId, key);
  }

  @override
  Future<void> pushScopedArrayElement(
    String id,
    String scope,
    String contextId,
    String key,
    dynamic element,
  ) async {
    await _variableStore.pushScopedArrayElement(
      id,
      scope,
      contextId,
      key,
      element,
    );
  }

  @override
  Future<dynamic> popScopedArrayElement(
    String id,
    String scope,
    String contextId,
    String key,
  ) async {
    return await _variableStore.popScopedArrayElement(
      id,
      scope,
      contextId,
      key,
    );
  }

  @override
  Future<dynamic> removeScopedArrayElement(
    String id,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    return await _variableStore.removeScopedArrayElement(
      id,
      scope,
      contextId,
      key,
      index,
    );
  }

  @override
  Future<dynamic> getScopedArrayElement(
    String id,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    return await _variableStore.getScopedArrayElement(
      id,
      scope,
      contextId,
      key,
      index,
    );
  }

  @override
  Future<int> getScopedArrayLength(
    String id,
    String scope,
    String contextId,
    String key,
  ) async {
    return await _variableStore.getScopedArrayLength(id, scope, contextId, key);
  }

  @override
  Future<Map<String, dynamic>> queryScopedArray(
    String id,
    String scope,
    String contextId,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
    String? filter,
  }) async {
    return await _variableStore.queryScopedArray(
      id,
      scope,
      contextId,
      key,
      offset: offset,
      limit: limit,
      descending: descending,
      filter: filter,
    );
  }

  String _normalizeScopedStorageKey(String key) {
    final trimmed = key.trim();
    if (trimmed.startsWith('bc_') && trimmed.length > 3) {
      return trimmed.substring(3);
    }
    return trimmed;
  }

  String _toScopedReferenceKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return trimmed.startsWith('bc_') ? trimmed : 'bc_$trimmed';
  }

  // ===== SCOPED VARIABLE DEFINITIONS (stored in bot JSON, not SQLite) =====

  /// Returns the list of scoped variable definitions for [botId].
  /// Each entry is { 'key': String, 'scope': String, 'defaultValue': dynamic }.
  Future<List<Map<String, dynamic>>> getScopedVariableDefinitions(
    String botId,
  ) async {
    final data = await getApp(botId);
    final raw = data['scopedVariableDefinitions'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Adds or updates a scoped variable definition in the bot JSON.
  Future<void> setScopedVariableDefinition(
    String botId,
    String key,
    String scope,
    dynamic defaultValue, {
    String valueType = 'string',
  }) async {
    final normalizedKey = _normalizeScopedStorageKey(key);
    if (normalizedKey.isEmpty) {
      return;
    }
    await _mutateApp(botId, (data) {
      final defs = List<dynamic>.from(
        (data['scopedVariableDefinitions'] as List?) ?? const [],
      );
      final entry = <String, dynamic>{
        'key': normalizedKey,
        'scope': scope,
        'defaultValue': defaultValue,
        'valueType': valueType,
      };
      final idx = defs.indexWhere(
        (e) =>
            e is Map &&
            _normalizeScopedStorageKey((e['key'] ?? '').toString()) ==
                normalizedKey &&
            (e['scope'] ?? '').toString().trim() == scope.trim(),
      );
      if (idx >= 0) {
        defs[idx] = entry;
      } else {
        defs.add(entry);
      }
      data['scopedVariableDefinitions'] = defs;
    });
  }

  /// Removes a scoped variable definition from the bot JSON.
  Future<void> removeScopedVariableDefinition(
    String botId,
    String key, {
    String? scope,
  }) async {
    final normalizedKey = _normalizeScopedStorageKey(key);
    await _mutateApp(botId, (data) {
      final defs = List<dynamic>.from(
        (data['scopedVariableDefinitions'] as List?) ?? const [],
      );
      defs.removeWhere(
        (e) =>
            e is Map &&
            _normalizeScopedStorageKey((e['key'] ?? '').toString()) ==
                normalizedKey &&
            (scope == null ||
                (e['scope'] ?? '').toString().trim() == scope.trim()),
      );
      data['scopedVariableDefinitions'] = defs;
    });
  }

  @override
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  }) async {
    return await _variableStore.queryScopedVariableIndex(
      botId,
      scope,
      _normalizeScopedStorageKey(key),
      offset: offset,
      limit: limit,
      descending: descending,
    );
  }

  Future<Map<String, dynamic>> listScopedValuesForKey(
    String id,
    String scope,
    String key,
  ) async {
    final storageKey = _normalizeScopedStorageKey(key);
    final legacyKey = _toScopedReferenceKey(storageKey);

    final contextIds = List<String>.from(
      await _variableStore.listContextIds(id, scope, searchKey: storageKey),
      growable: true,
    );
    if (legacyKey != storageKey) {
      final legacyContextIds = await _variableStore.listContextIds(
        id,
        scope,
        searchKey: legacyKey,
      );
      contextIds.addAll(legacyContextIds);
    }
    final dedupedContextIds = contextIds.toSet().toList(growable: false);
    dedupedContextIds.sort();

    final result = <String, dynamic>{};
    for (final contextId in dedupedContextIds) {
      var value = await _variableStore.getScopedVariable(
        id,
        scope,
        contextId,
        storageKey,
      );
      if (value == null && legacyKey != storageKey) {
        value = await _variableStore.getScopedVariable(
          id,
          scope,
          contextId,
          legacyKey,
        );
      }
      if (value != null) {
        result[contextId] = value;
      }
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> getWorkflows(String id) async {
    final app = await getApp(id);
    final rawWorkflows = _coerceWorkflowList(app['workflows']);
    return rawWorkflows
        .map((workflow) => _normalizeStoredWorkflow(workflow))
        .toList(growable: false);
  }

  Future<void> saveWorkflow(
    String id, {
    required String name,
    required List<Map<String, dynamic>> actions,
    String? entryPoint,
    List<Map<String, dynamic>>? arguments,
    String? workflowType,
    Map<String, dynamic>? eventTrigger,
  }) async {
    final app = Map<String, dynamic>.from(await getApp(id));
    final workflows = _coerceWorkflowList(app['workflows']);

    final normalizedName = name.trim();
    final index = workflows.indexWhere(
      (workflow) =>
          (workflow['name'] ?? '').toString().toLowerCase() ==
          normalizedName.toLowerCase(),
    );
    final existing =
        index >= 0
            ? _normalizeStoredWorkflow(
              Map<String, dynamic>.from(workflows[index]),
            )
            : null;
    final normalizedEntryPoint =
        entryPoint == null
            ? normalizeWorkflowEntryPoint(existing?['entryPoint'])
            : normalizeWorkflowEntryPoint(entryPoint);
    final normalizedWorkflowType =
        workflowType == null
            ? normalizeWorkflowType(existing?['workflowType'])
            : normalizeWorkflowType(workflowType);
    final normalizedArguments = serializeWorkflowArgumentDefinitions(
      parseWorkflowArgumentDefinitions(
        arguments ?? existing?['arguments'] ?? const [],
      ),
    );

    final payload = <String, dynamic>{
      'name': normalizedName,
      'actions': List<Map<String, dynamic>>.from(actions),
      'workflowType': normalizedWorkflowType,
      'entryPoint': normalizedEntryPoint,
      'arguments': normalizedArguments,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (normalizedWorkflowType == workflowTypeEvent) {
      payload['eventTrigger'] = normalizeWorkflowEventTrigger(
        eventTrigger ?? existing?['eventTrigger'],
      );
    }

    if (index >= 0) {
      workflows[index] = payload;
    } else {
      workflows.add(payload);
    }

    app['workflows'] = workflows;
    await saveApp(id, app);
  }

  Future<void> deleteWorkflow(String id, String name) async {
    final app = Map<String, dynamic>.from(await getApp(id));
    final workflows = _coerceWorkflowList(app['workflows']);

    workflows.removeWhere(
      (workflow) =>
          (workflow['name'] ?? '').toString().toLowerCase() ==
          name.toLowerCase(),
    );

    app['workflows'] = workflows;
    await saveApp(id, app);
  }

  @override
  Future<Map<String, dynamic>?> getWorkflowByName(
    String id,
    String name,
  ) async {
    final workflows = await getWorkflows(id);
    for (final workflow in workflows) {
      if ((workflow['name'] ?? '').toString().toLowerCase() ==
          name.toLowerCase()) {
        return workflow;
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizeStoredWorkflow(Map<String, dynamic> workflow) {
    final draft = Map<String, dynamic>.from(workflow);
    final rawType = (draft['workflowType'] ?? '').toString().trim();
    final hasLegacyEventHints =
        draft['eventTrigger'] != null ||
        (draft['event']?.toString().trim().isNotEmpty ?? false) ||
        (draft['listenFor']?.toString().trim().isNotEmpty ?? false);

    if (rawType.isEmpty && hasLegacyEventHints) {
      draft['workflowType'] = workflowTypeEvent;
      if (draft['eventTrigger'] == null) {
        final eventName =
            (draft['event'] ?? draft['listenFor'] ?? 'messageCreate')
                .toString()
                .trim();
        draft['eventTrigger'] = <String, dynamic>{
          'category': 'messages',
          'event': eventName.isEmpty ? 'messageCreate' : eventName,
        };
      }
    }

    return normalizeStoredWorkflowDefinition(draft);
  }

  List<Map<String, dynamic>> _coerceWorkflowList(dynamic raw) {
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }

    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
        continue;
      }

      if (item is String) {
        final text = item.trim();
        if (text.isEmpty) {
          continue;
        }
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map) {
            result.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Keep compatibility mode resilient: malformed entries are skipped.
        }
      }
    }

    return result;
  }

  Future<void> _writeWorkflowCompatibilityReportIfDebug() async {
    if (kReleaseMode || !Platform.isWindows) {
      return;
    }

    try {
      final report = <String, dynamic>{
        'generatedAt': DateTime.now().toIso8601String(),
        'apps': <Map<String, dynamic>>[],
      };

      for (final appMeta in _apps) {
        if (appMeta is! Map) {
          continue;
        }

        final id = (appMeta['id'] ?? '').toString().trim();
        if (id.isEmpty) {
          continue;
        }

        final app = await getApp(id);
        final raw = app['workflows'];
        final rawList = raw is List ? raw : const <dynamic>[];
        final parsed = _coerceWorkflowList(raw);
        final normalized = parsed
            .map((entry) => _normalizeStoredWorkflow(entry))
            .toList(growable: false);
        final commandRefsByFile = await _collectCommandWorkflowReferences(id);
        final referencedWorkflowNames =
            commandRefsByFile.values.expand((names) => names).toSet();
        final normalizedWorkflowNames =
            normalized
                .map((entry) => (entry['name'] ?? '').toString().trim())
                .where((name) => name.isNotEmpty)
                .toSet();
        final missingReferencedWorkflows = referencedWorkflowNames
          .where((name) => !normalizedWorkflowNames.contains(name))
          .toList(growable: false)..sort();

        final missingNames =
            normalized
                .where(
                  (workflow) =>
                      (workflow['name'] ?? '').toString().trim().isEmpty,
                )
                .length;

        (report['apps'] as List<Map<String, dynamic>>).add({
          'id': id,
          'name': (appMeta['name'] ?? '').toString(),
          'rawWorkflowEntries': rawList.length,
          'parsedWorkflowEntries': parsed.length,
          'normalizedWorkflowEntries': normalized.length,
          'droppedEntries': rawList.length - parsed.length,
          'missingNameAfterNormalization': missingNames,
          'commandWorkflowReferenceCount': referencedWorkflowNames.length,
          'missingReferencedWorkflows': missingReferencedWorkflows,
          'commandWorkflowReferencesByFile': commandRefsByFile,
          'rawTypes':
              rawList.map((entry) => entry.runtimeType.toString()).toList(),
          'normalizedPreview': normalized.take(20).toList(),
        });
      }

      final basePath = await _path();
      final debugDir = Directory('$basePath/apps/_debug');
      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
      }

      final reportFile = File(
        '$basePath/apps/_debug/workflow_compat_report.json',
      );
      final encoder = const JsonEncoder.withIndent('  ');
      await reportFile.writeAsString(encoder.convert(report));

      debugPrint('Workflow compatibility report written: ${reportFile.path}');
    } catch (error) {
      debugPrint('Workflow compatibility report failed: $error');
    }
  }

  Future<Map<String, List<String>>> _collectCommandWorkflowReferences(
    String botId,
  ) async {
    final basePath = await _path();
    final commandsDir = Directory('$basePath/apps/$botId');
    if (!await commandsDir.exists()) {
      return const <String, List<String>>{};
    }

    final result = <String, List<String>>{};
    final entities = await commandsDir.list().toList();
    for (final entity in entities) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }

      try {
        final content = await entity.readAsString();
        if (content.trim().isEmpty) {
          continue;
        }
        final decoded = jsonDecode(content);
        final names = _extractWorkflowNames(decoded).toList(growable: false)
          ..sort();
        if (names.isNotEmpty) {
          final fileName = entity.uri.pathSegments.last;
          result[fileName] = names;
        }
      } catch (_) {
        // Ignore malformed command files in debug report generation.
      }
    }

    return result;
  }

  Set<String> _extractWorkflowNames(dynamic node) {
    final names = <String>{};
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString();
        if (key == 'workflowName') {
          final value = entry.value?.toString().trim() ?? '';
          if (value.isNotEmpty) {
            names.add(value);
          }
        }
        names.addAll(_extractWorkflowNames(entry.value));
      }
      return names;
    }

    if (node is List) {
      for (final item in node) {
        names.addAll(_extractWorkflowNames(item));
      }
    }
    return names;
  }

  Future<Map<String, dynamic>> getAppCommand(
    String id,
    String commandId,
  ) async {
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (!await file.exists()) return {};

    final data = await file.readAsString();
    if (data.isEmpty) return {};

    final decoded = Map<String, dynamic>.from(jsonDecode(data));
    final normalized = normalizeCommandData(decoded);
    if (!_deepEquals(decoded, normalized)) {
      await file.writeAsString(jsonEncode(normalized));
    }

    return normalized;
  }

  Future<List<Map<String, dynamic>>> listAppCommands(String id) async {
    final path = await _path();
    final dir = Directory("$path/apps/$id");
    if (!await dir.exists()) {
      return const <Map<String, dynamic>>[];
    }

    final entities = await dir.list().toList();
    final commands = <Map<String, dynamic>>[];

    for (final entity in entities) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }

      try {
        final content = await entity.readAsString();
        if (content.trim().isEmpty) {
          continue;
        }

        final decoded = Map<String, dynamic>.from(jsonDecode(content));
        final normalized = normalizeCommandData(decoded);
        final fileName = entity.uri.pathSegments.last;
        final fallbackId = fileName.substring(0, fileName.length - 5);

        normalized['id'] = (normalized['id'] ?? fallbackId).toString();
        normalized['name'] = (normalized['name'] ?? 'unknown').toString();
        normalized['description'] =
            (normalized['description'] ?? '').toString();
        commands.add(normalized);
      } catch (_) {
        // Ignore malformed command files to keep list rendering resilient.
      }
    }

    commands.sort((a, b) {
      final aName = (a['name'] ?? '').toString().toLowerCase();
      final bName = (b['name'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });
    return commands;
  }

  Future<void> saveAppCommand(
    String id,
    String commandId,
    Map<String, dynamic> data,
  ) async {
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (!await file.exists()) await file.create(recursive: true);
    await file.writeAsString(jsonEncode(normalizeCommandData(data)));
  }

  Map<String, dynamic> normalizeCommandData(Map<String, dynamic> command) {
    final normalized = Map<String, dynamic>.from(command);
    final rawData = Map<String, dynamic>.from(
      (normalized['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final rawCommandType =
        (rawData['commandType'] ?? normalized['type'] ?? 'chatInput')
            .toString()
            .trim()
            .toLowerCase();
    final commandType =
        (rawCommandType == 'user' ||
                rawCommandType == 'usercommand' ||
                rawCommandType == 'user_command')
            ? 'user'
            : (rawCommandType == 'message' ||
                rawCommandType == 'messagecommand' ||
                rawCommandType == 'message_command')
            ? 'message'
            : 'chatInput';

    final legacyResponse = rawData['response'];
    final response = Map<String, dynamic>.from(
      (legacyResponse is Map)
          ? legacyResponse.cast<String, dynamic>()
          : {
            'mode': 'text',
            'text': legacyResponse?.toString() ?? '',
            'embed': {'title': '', 'description': '', 'url': ''},
            'embeds': <Map<String, dynamic>>[],
          },
    );

    final legacySingleEmbed = Map<String, dynamic>.from(
      (response['embed'] as Map?)?.cast<String, dynamic>() ??
          {'title': '', 'description': '', 'url': ''},
    );
    final embeds =
        (response['embeds'] is List)
            ? List<Map<String, dynamic>>.from(
              (response['embeds'] as List).whereType<Map>().map(
                (embed) => Map<String, dynamic>.from(embed),
              ),
            )
            : <Map<String, dynamic>>[];

    final hasLegacyEmbed =
        (legacySingleEmbed['title']?.toString().isNotEmpty ?? false) ||
        (legacySingleEmbed['description']?.toString().isNotEmpty ?? false) ||
        (legacySingleEmbed['url']?.toString().isNotEmpty ?? false);
    if (embeds.isEmpty && hasLegacyEmbed) {
      embeds.add(legacySingleEmbed);
    }

    final actions =
        (rawData['actions'] is List)
            ? List<Map<String, dynamic>>.from(
              (rawData['actions'] as List).whereType<Map>().map(
                (action) => Map<String, dynamic>.from(action),
              ),
            )
            : <Map<String, dynamic>>[];

    final rawEditorMode =
        (rawData['editorMode'] ?? 'advanced').toString().toLowerCase();
    final editorMode = rawEditorMode == 'simple' ? 'simple' : 'advanced';

    final simpleConfigRaw = Map<String, dynamic>.from(
      (rawData['simpleConfig'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final simpleConfig = <String, dynamic>{
      'deleteMessages': simpleConfigRaw['deleteMessages'] == true,
      'kickUser': simpleConfigRaw['kickUser'] == true,
      'banUser': simpleConfigRaw['banUser'] == true,
      'muteUser': simpleConfigRaw['muteUser'] == true,
      'addRole': simpleConfigRaw['addRole'] == true,
      'removeRole': simpleConfigRaw['removeRole'] == true,
      'sendMessage': simpleConfigRaw['sendMessage'] == true,
      'sendMessageText': (simpleConfigRaw['sendMessageText'] ?? '').toString(),
    };

    final rawWorkflow = Map<String, dynamic>.from(
      (response['workflow'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final rawConditional = Map<String, dynamic>.from(
      (rawWorkflow['conditional'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    final normalizedWorkflow = <String, dynamic>{
      'autoDeferIfActions': rawWorkflow['autoDeferIfActions'] != false,
      'visibility':
          (rawWorkflow['visibility']?.toString().toLowerCase() == 'ephemeral')
              ? 'ephemeral'
              : 'public',
      'onError': 'edit_error',
      'conditional': {
        'enabled': rawConditional['enabled'] == true,
        'variable': (rawConditional['variable'] ?? '').toString(),
        'whenTrueType': (rawConditional['whenTrueType'] ?? 'normal').toString(),
        'whenFalseType':
            (rawConditional['whenFalseType'] ?? 'normal').toString(),
        'whenTrueText': (rawConditional['whenTrueText'] ?? '').toString(),
        'whenFalseText': (rawConditional['whenFalseText'] ?? '').toString(),
        'whenTrueEmbeds':
            (rawConditional['whenTrueEmbeds'] as List? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
        'whenFalseEmbeds':
            (rawConditional['whenFalseEmbeds'] as List? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
        'whenTrueNormalComponents': Map<String, dynamic>.from(
          (rawConditional['whenTrueNormalComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenFalseNormalComponents': Map<String, dynamic>.from(
          (rawConditional['whenFalseNormalComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenTrueComponents': Map<String, dynamic>.from(
          (rawConditional['whenTrueComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenFalseComponents': Map<String, dynamic>.from(
          (rawConditional['whenFalseComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenTrueModal': Map<String, dynamic>.from(
          (rawConditional['whenTrueModal'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
        'whenFalseModal': Map<String, dynamic>.from(
          (rawConditional['whenFalseModal'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
      },
    };

    normalized['type'] = commandType;
    normalized['data'] = {
      'version': 1,
      'commandType': commandType,
      'editorMode': editorMode,
      'simpleConfig': simpleConfig,
      'defaultMemberPermissions':
          (rawData['defaultMemberPermissions'] ?? '').toString().trim(),
      'response': {
        'mode':
            (embeds.isNotEmpty ? 'embed' : (response['mode'] ?? 'text'))
                .toString(),
        'text': (response['text'] ?? '').toString(),
        'type': (response['type'] ?? 'normal').toString(),
        'embed':
            embeds.isNotEmpty
                ? embeds.first
                : {'title': '', 'description': '', 'url': ''},
        'embeds': embeds.take(10).toList(),
        'components': Map<String, dynamic>.from(
          (response['components'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        'modal': Map<String, dynamic>.from(
          (response['modal'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        'workflow': normalizedWorkflow,
      },
      'actions': actions,
    };

    return normalized;
  }

  bool _deepEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    return jsonEncode(a) == jsonEncode(b);
  }

  Future<void> deleteAppCommand(String id, String commandId) async {
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAppCommands(String id) async {
    final path = await _path();
    final dir = Directory("$path/apps/$id");
    if (!await dir.exists()) return;

    final files = await dir.list().toList();
    for (final file in files) {
      if (file is File && file.path.endsWith(".json")) {
        await file.delete();
      }
    }
  }

  Future<List<FileSystemEntity>> getAllAppDirectory() async {
    final path = await _path();
    final dir = Directory("$path/apps");
    if (!await dir.exists()) return [];

    final files = await dir.list(recursive: true).toList();
    final allAppsFile = File("$path/apps/all_apps.json");
    if (await allAppsFile.exists()) files.add(allAppsFile);
    return files;
  }

  Future<void> deleteAllApps() async {
    final apps = await getAllApps();
    for (final app in apps) {
      await deleteApp(app['id']);
    }
  }
}
