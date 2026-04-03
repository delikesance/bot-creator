import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:bot_creator/stores/sqlite_variable_store.dart';
import 'package:bot_creator/utils/premium_capabilities.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:bot_creator/utils/normalize_command_data.dart' as normalize_lib;
import 'package:bot_creator/utils/workflow_call.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nyxx/nyxx.dart';

class AppManager implements BotDataStore {
  static final AppManager _instance = AppManager._internal();
  factory AppManager() => _instance;

  /// Optional hook called after any save that should trigger a runner reload.
  ///
  /// Set this once at app startup (e.g. in main.dart) with a closure that
  /// builds the bot payload and calls [RunnerClient.reloadBot].
  /// The hook must be a no-throw fire-and-forget operation.
  static Future<void> Function(String botId)? onAfterSave;

  final StreamController<List<dynamic>> _appsStreamController =
      StreamController<List<dynamic>>.broadcast();
  List<dynamic> _apps = [];
  late SqliteVariableStore _variableStore;
  bool _sqliteAvailable = false;
  final Map<String, Future<void>> _appWriteChains = <String, Future<void>>{};
  final Map<String, List<Map<String, dynamic>>> _commandListCache =
      <String, List<Map<String, dynamic>>>{};

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
      _sqliteAvailable = true;
    } catch (error) {
      _sqliteAvailable = false;
      debugPrint(
        '[AppManager._init] SQLite init failed: $error\n'
        '[AppManager._init] Falling back to JSON scoped variable store.',
      );
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
    String? prefix,
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
            ..['prefix'] = () {
              final raw =
                  (prefix ?? existingData['prefix'] ?? '!').toString().trim();
              return raw.isEmpty ? '!' : raw;
            }()
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
            ..['scheduledTriggers'] = List<Map<String, dynamic>>.from(
              ((existingData['scheduledTriggers']) as List?)
                      ?.whereType<Map>()
                      .map((entry) => Map<String, dynamic>.from(entry)) ??
                  const <Map<String, dynamic>>[],
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
    final statsFile = File("$path/apps/$id.command_stats.json");
    if (await statsFile.exists()) {
      await statsFile.delete();
    }
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
          final appsList =
              decoded
                  .whereType<Map>()
                  .map((raw) => Map<String, dynamic>.from(raw))
                  .toList();
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

  File _commandStatsFileAtPath(String path, String botId) {
    return File("$path/apps/$botId.command_stats.json");
  }

  Future<void> recordCommandExecution(
    String botId,
    String commandName, {
    DateTime? executedAt,
  }) async {
    final normalizedCommandName = commandName.trim();
    if (normalizedCommandName.isEmpty) {
      return;
    }

    await _enqueueAppWrite(botId, () async {
      final path = await _path();
      final file = _commandStatsFileAtPath(path, botId);
      await file.parent.create(recursive: true);

      List<dynamic> rawEntries = const <dynamic>[];
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final decoded = content.isNotEmpty ? jsonDecode(content) : null;
          if (decoded is List) {
            rawEntries = decoded;
          }
        } catch (_) {}
      }

      final nowMs =
          (executedAt ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
      final cutoffMs = nowMs - const Duration(days: 30).inMilliseconds;
      final normalized = <Map<String, dynamic>>[];
      for (final entry in rawEntries) {
        if (entry is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(entry.cast<String, dynamic>());
        final name = (map['command'] ?? '').toString().trim();
        final timestamp = int.tryParse((map['executedAt'] ?? '').toString());
        if (name.isEmpty || timestamp == null || timestamp < cutoffMs) {
          continue;
        }
        normalized.add(<String, dynamic>{
          'command': name,
          'executedAt': timestamp,
        });
      }

      normalized.add(<String, dynamic>{
        'command': normalizedCommandName,
        'executedAt': nowMs,
      });

      const maxEntries = 50000;
      final kept =
          normalized.length > maxEntries
              ? normalized.sublist(normalized.length - maxEntries)
              : normalized;
      await file.writeAsString(jsonEncode(kept));
    });
  }

  Future<Map<String, dynamic>> getLocalCommandStats(
    String botId, {
    int hours = 24,
  }) async {
    final safeHours = hours <= 0 ? 24 : hours;
    final path = await _path();
    final file = _commandStatsFileAtPath(path, botId);
    if (!await file.exists()) {
      return <String, dynamic>{
        'botId': botId,
        'hours': safeHours,
        'totalAllTime': 0,
        'commands': const <Map<String, dynamic>>[],
        'timeline': const <Map<String, dynamic>>[],
        'locales': const <Map<String, dynamic>>[],
        'health': const <String, dynamic>{
          'total': 0,
          'failed': 0,
          'errorRatePct': 0.0,
          'p50LatencyMs': 0,
          'p95LatencyMs': 0,
        },
      };
    }

    List<dynamic> rawEntries = const <dynamic>[];
    try {
      final content = await file.readAsString();
      final decoded = content.isNotEmpty ? jsonDecode(content) : null;
      if (decoded is List) {
        rawEntries = decoded;
      }
    } catch (_) {}

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final sinceMs = nowMs - (safeHours * 3600000);
    var totalAllTime = 0;
    final countsByCommand = <String, int>{};
    final countsByHourBucket = <int, int>{};

    for (final entry in rawEntries) {
      if (entry is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(entry.cast<String, dynamic>());
      final name = (map['command'] ?? '').toString().trim();
      final timestamp = int.tryParse((map['executedAt'] ?? '').toString());
      if (name.isEmpty || timestamp == null) {
        continue;
      }

      totalAllTime += 1;
      if (timestamp < sinceMs) {
        continue;
      }

      countsByCommand.update(name, (value) => value + 1, ifAbsent: () => 1);
      final hourBucket = timestamp ~/ 3600000;
      countsByHourBucket.update(
        hourBucket,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final commands = countsByCommand.entries
        .map(
          (entry) => <String, dynamic>{
            'command': entry.key,
            'count': entry.value,
          },
        )
        .toList(growable: false)
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final sortedBuckets = countsByHourBucket.keys.toList(growable: false)
      ..sort();
    final timeline = sortedBuckets
        .map(
          (bucket) => <String, dynamic>{
            'hour': bucket.toString(),
            'count': countsByHourBucket[bucket]!,
          },
        )
        .toList(growable: false);

    return <String, dynamic>{
      'botId': botId,
      'hours': safeHours,
      'totalAllTime': totalAllTime,
      'commands': commands,
      'timeline': timeline,
      'locales': const <Map<String, dynamic>>[],
      'health': const <String, dynamic>{
        'total': 0,
        'failed': 0,
        'errorRatePct': 0.0,
        'p50LatencyMs': 0,
        'p95LatencyMs': 0,
      },
    };
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
    if (_sqliteAvailable) {
      return await _variableStore.getScopedVariables(id, scope, contextId);
    }
    return await _getScopedContextFromJson(id, scope, contextId);
  }

  @override
  Future<dynamic> getScopedVariable(
    String id,
    String scope,
    String contextId,
    String key,
  ) async {
    if (_sqliteAvailable) {
      return await _variableStore.getScopedVariable(id, scope, contextId, key);
    }
    final contextMap = await _getScopedContextFromJson(id, scope, contextId);
    return contextMap[key];
  }

  @override
  Future<void> setScopedVariable(
    String id,
    String scope,
    String contextId,
    String key,
    dynamic value,
  ) async {
    if (_sqliteAvailable) {
      await _variableStore.setScopedVariable(id, scope, contextId, key, value);
      return;
    }
    await _mutateScopedContextInJson(id, scope, contextId, (contextMap) {
      contextMap[key] = value;
    });
  }

  @override
  Future<void> renameScopedVariable(
    String id,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) async {
    if (_sqliteAvailable) {
      await _variableStore.renameScopedVariable(
        id,
        scope,
        contextId,
        oldKey,
        newKey,
      );
      return;
    }
    await _mutateScopedContextInJson(id, scope, contextId, (contextMap) {
      if (!contextMap.containsKey(oldKey)) {
        return;
      }
      final value = contextMap.remove(oldKey);
      contextMap[newKey] = value;
    });
  }

  @override
  Future<void> removeScopedVariable(
    String id,
    String scope,
    String contextId,
    String key,
  ) async {
    if (_sqliteAvailable) {
      await _variableStore.removeScopedVariable(id, scope, contextId, key);
      return;
    }
    await _mutateScopedContextInJson(id, scope, contextId, (contextMap) {
      contextMap.remove(key);
    });
  }

  @override
  Future<void> pushScopedArrayElement(
    String id,
    String scope,
    String contextId,
    String key,
    dynamic element,
  ) async {
    if (_sqliteAvailable) {
      await _variableStore.pushScopedArrayElement(
        id,
        scope,
        contextId,
        key,
        element,
      );
      return;
    }
    await _mutateScopedContextInJson(id, scope, contextId, (contextMap) {
      final existing = contextMap[key];
      final list =
          existing is List ? List<dynamic>.from(existing) : <dynamic>[];
      list.add(element);
      contextMap[key] = list;
    });
  }

  @override
  Future<dynamic> popScopedArrayElement(
    String id,
    String scope,
    String contextId,
    String key,
  ) async {
    if (_sqliteAvailable) {
      return await _variableStore.popScopedArrayElement(
        id,
        scope,
        contextId,
        key,
      );
    }

    dynamic removed;
    await _mutateScopedContextInJson(id, scope, contextId, (contextMap) {
      final existing = contextMap[key];
      if (existing is! List || existing.isEmpty) {
        removed = null;
        return;
      }
      final list = List<dynamic>.from(existing);
      removed = list.removeLast();
      contextMap[key] = list;
    });
    return removed;
  }

  @override
  Future<dynamic> removeScopedArrayElement(
    String id,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    if (_sqliteAvailable) {
      return await _variableStore.removeScopedArrayElement(
        id,
        scope,
        contextId,
        key,
        index,
      );
    }

    dynamic removed;
    await _mutateScopedContextInJson(id, scope, contextId, (contextMap) {
      final existing = contextMap[key];
      if (existing is! List) {
        removed = null;
        return;
      }
      final list = List<dynamic>.from(existing);
      if (index < 0 || index >= list.length) {
        removed = null;
        return;
      }
      removed = list.removeAt(index);
      contextMap[key] = list;
    });
    return removed;
  }

  @override
  Future<dynamic> getScopedArrayElement(
    String id,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    if (_sqliteAvailable) {
      return await _variableStore.getScopedArrayElement(
        id,
        scope,
        contextId,
        key,
        index,
      );
    }
    final contextMap = await _getScopedContextFromJson(id, scope, contextId);
    final list = contextMap[key];
    if (list is! List || index < 0 || index >= list.length) {
      return null;
    }
    return list[index];
  }

  @override
  Future<int> getScopedArrayLength(
    String id,
    String scope,
    String contextId,
    String key,
  ) async {
    if (_sqliteAvailable) {
      return await _variableStore.getScopedArrayLength(
        id,
        scope,
        contextId,
        key,
      );
    }
    final contextMap = await _getScopedContextFromJson(id, scope, contextId);
    final list = contextMap[key];
    return list is List ? list.length : 0;
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
    if (_sqliteAvailable) {
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

    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit.clamp(1, 25);
    final contextMap = await _getScopedContextFromJson(id, scope, contextId);
    final existing = contextMap[key];
    final source =
        existing is List ? List<dynamic>.from(existing) : <dynamic>[];
    final filtered = source
        .where((entry) => _arrayElementMatchesFilter(entry, filter))
        .toList(growable: false);
    final ordered =
        descending ? filtered.reversed.toList(growable: false) : filtered;
    final end =
        (safeOffset + safeLimit) > ordered.length
            ? ordered.length
            : (safeOffset + safeLimit);
    final page =
        safeOffset >= ordered.length
            ? const <dynamic>[]
            : ordered.sublist(safeOffset, end);

    return <String, dynamic>{
      'items': page,
      'count': page.length,
      'total': ordered.length,
    };
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

  String _normalizeInboundWebhookPath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final noLeading = trimmed.replaceFirst(RegExp(r'^/+'), '');
    return noLeading.replaceAll(RegExp(r'/+'), '/');
  }

  Map<String, dynamic> _normalizeInboundWebhook(Map<String, dynamic> raw) {
    final id = (raw['id'] ?? '').toString().trim();
    final path = _normalizeInboundWebhookPath((raw['path'] ?? '').toString());
    final workflowName = (raw['workflowName'] ?? '').toString().trim();
    final secret = (raw['secret'] ?? '').toString().trim();
    final enabled = raw['enabled'] != false;

    return <String, dynamic>{
      'id': id,
      'path': path,
      'workflowName': workflowName,
      'secret': secret,
      'enabled': enabled,
      if (raw['createdAt'] != null) 'createdAt': raw['createdAt'],
      if (raw['updatedAt'] != null) 'updatedAt': raw['updatedAt'],
    };
  }

  Map<String, dynamic> _readScopedContextFromAppData(
    Map<String, dynamic> appData,
    String scope,
    String contextId,
  ) {
    final scopedVariables = Map<String, dynamic>.from(
      (appData['scopedVariables'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    final scopeMap = Map<String, dynamic>.from(
      (scopedVariables[scope] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    return Map<String, dynamic>.from(
      (scopeMap[contextId] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> _getScopedContextFromJson(
    String id,
    String scope,
    String contextId,
  ) async {
    final appData = await getApp(id);
    return _readScopedContextFromAppData(appData, scope, contextId);
  }

  Future<void> _mutateScopedContextInJson(
    String id,
    String scope,
    String contextId,
    void Function(Map<String, dynamic> contextMap) mutate,
  ) async {
    await _mutateApp(id, (appData) {
      final scopedVariables = Map<String, dynamic>.from(
        (appData['scopedVariables'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );
      final scopeMap = Map<String, dynamic>.from(
        (scopedVariables[scope] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );
      final contextMap = Map<String, dynamic>.from(
        (scopeMap[contextId] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );

      mutate(contextMap);

      if (contextMap.isEmpty) {
        scopeMap.remove(contextId);
      } else {
        scopeMap[contextId] = contextMap;
      }
      if (scopeMap.isEmpty) {
        scopedVariables.remove(scope);
      } else {
        scopedVariables[scope] = scopeMap;
      }
      appData['scopedVariables'] = scopedVariables;
    });
  }

  Future<List<String>> _listContextIdsFromJson(
    String id,
    String scope, {
    String? searchKey,
  }) async {
    final appData = await getApp(id);
    final scopedVariables = Map<String, dynamic>.from(
      (appData['scopedVariables'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    final scopeMap = Map<String, dynamic>.from(
      (scopedVariables[scope] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    final lookupKey = (searchKey ?? '').trim();
    final contextIds = <String>[];
    for (final entry in scopeMap.entries) {
      final contextId = entry.key.trim();
      if (contextId.isEmpty || entry.value is! Map) {
        continue;
      }
      if (lookupKey.isEmpty) {
        contextIds.add(contextId);
        continue;
      }
      final contextMap = Map<String, dynamic>.from(
        (entry.value as Map).cast<String, dynamic>(),
      );
      if (contextMap.containsKey(lookupKey)) {
        contextIds.add(contextId);
      }
    }
    contextIds.sort();
    return contextIds;
  }

  bool _arrayElementMatchesFilter(dynamic value, String? filter) {
    final normalized = (filter ?? '').trim();
    if (normalized.isEmpty) {
      return true;
    }
    final lower = normalized.toLowerCase();
    final rendered = value?.toString() ?? '';

    if (lower.startsWith('contains ')) {
      final needle = normalized.substring('contains '.length).trim();
      return rendered.toLowerCase().contains(needle.toLowerCase());
    }

    num? valueNum;
    if (value is num) {
      valueNum = value;
    } else {
      valueNum = num.tryParse(rendered);
    }

    bool compareNum(String prefix, bool Function(num a, num b) predicate) {
      if (!lower.startsWith(prefix) || valueNum == null) {
        return false;
      }
      final rhs = num.tryParse(normalized.substring(prefix.length).trim());
      if (rhs == null) {
        return false;
      }
      return predicate(valueNum, rhs);
    }

    if (compareNum('>=', (a, b) => a >= b)) return true;
    if (compareNum('<=', (a, b) => a <= b)) return true;
    if (compareNum('>', (a, b) => a > b)) return true;
    if (compareNum('<', (a, b) => a < b)) return true;
    if (lower.startsWith('==')) {
      final rhs = normalized.substring(2).trim();
      if (valueNum != null) {
        final rhsNum = num.tryParse(rhs);
        if (rhsNum != null) {
          return valueNum == rhsNum;
        }
      }
      return rendered == rhs;
    }

    return rendered.toLowerCase().contains(normalized.toLowerCase());
  }

  // ===== SCOPED VARIABLE DEFINITIONS (stored in bot JSON, not SQLite) =====

  /// Returns the list of scoped variable definitions for [botId].
  /// Each entry is { 'key': String, 'scope': String, 'defaultValue': dynamic }.
  @override
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
  @override
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
    if (_sqliteAvailable) {
      return await _variableStore.queryScopedVariableIndex(
        botId,
        scope,
        _normalizeScopedStorageKey(key),
        offset: offset,
        limit: limit,
        descending: descending,
      );
    }

    final normalizedKey = _normalizeScopedStorageKey(key);
    final contextIds = await _listContextIdsFromJson(
      botId,
      scope,
      searchKey: normalizedKey,
    );
    final items = <Map<String, dynamic>>[];
    for (final contextId in contextIds) {
      final value = await getScopedVariable(
        botId,
        scope,
        contextId,
        normalizedKey,
      );
      if (value == null) {
        continue;
      }
      items.add(<String, dynamic>{
        'contextId': contextId,
        'key': normalizedKey,
        'value': value,
      });
    }

    if (descending) {
      items.sort(
        (a, b) => (b['contextId'] ?? '').toString().compareTo(
          (a['contextId'] ?? '').toString(),
        ),
      );
    } else {
      items.sort(
        (a, b) => (a['contextId'] ?? '').toString().compareTo(
          (b['contextId'] ?? '').toString(),
        ),
      );
    }

    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit.clamp(1, 25);
    final end =
        (safeOffset + safeLimit) > items.length
            ? items.length
            : (safeOffset + safeLimit);
    final page =
        safeOffset >= items.length
            ? const <Map<String, dynamic>>[]
            : items.sublist(safeOffset, end);

    return <String, dynamic>{
      'items': page,
      'count': page.length,
      'total': items.length,
    };
  }

  Future<Map<String, dynamic>> listScopedValuesForKey(
    String id,
    String scope,
    String key,
  ) async {
    final storageKey = _normalizeScopedStorageKey(key);
    final legacyKey = _toScopedReferenceKey(storageKey);

    final contextIds = List<String>.from(
      _sqliteAvailable
          ? await _variableStore.listContextIds(
            id,
            scope,
            searchKey: storageKey,
          )
          : await _listContextIdsFromJson(id, scope, searchKey: storageKey),
      growable: true,
    );
    if (legacyKey != storageKey) {
      final legacyContextIds =
          _sqliteAvailable
              ? await _variableStore.listContextIds(
                id,
                scope,
                searchKey: legacyKey,
              )
              : await _listContextIdsFromJson(id, scope, searchKey: legacyKey);
      contextIds.addAll(legacyContextIds);
    }
    final dedupedContextIds = contextIds.toSet().toList(growable: false);
    dedupedContextIds.sort();

    final result = <String, dynamic>{};
    for (final contextId in dedupedContextIds) {
      var value = await getScopedVariable(id, scope, contextId, storageKey);
      if (value == null && legacyKey != storageKey) {
        value = await getScopedVariable(id, scope, contextId, legacyKey);
      }
      if (value != null) {
        result[contextId] = value;
      }
    }

    return result;
  }

  Future<Map<String, Map<String, Map<String, dynamic>>>> exportScopedVariables(
    String botId,
  ) async {
    const scopes = <String>[
      'guild',
      'channel',
      'user',
      'guildMember',
      'message',
    ];

    final exported = <String, Map<String, Map<String, dynamic>>>{};
    for (final scope in scopes) {
      final contextIds =
          _sqliteAvailable
              ? await _variableStore.listContextIds(botId, scope)
              : await _listContextIdsFromJson(botId, scope);
      if (contextIds.isEmpty) {
        continue;
      }

      final scopeValues = <String, Map<String, dynamic>>{};
      for (final contextId in contextIds) {
        final values = await getScopedVariables(botId, scope, contextId);
        if (values.isEmpty) {
          continue;
        }
        scopeValues[contextId] = Map<String, dynamic>.from(values);
      }

      if (scopeValues.isNotEmpty) {
        exported[scope] = scopeValues;
      }
    }

    return exported;
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
    unawaited((onAfterSave ?? (_) async {}).call(id));
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

  Future<List<Map<String, dynamic>>> getScheduledTriggers(String id) async {
    final app = await getApp(id);
    return ((app['scheduledTriggers'] as List?)
            ?.whereType<Map>()
            .map(
              (entry) =>
                  _normalizeScheduledTrigger(Map<String, dynamic>.from(entry)),
            )
            .where(
              (entry) =>
                  (entry['workflowName'] ?? '').toString().trim().isNotEmpty,
            )
            .toList(growable: false)) ??
        const <Map<String, dynamic>>[];
  }

  Future<void> saveScheduledTrigger(
    String id, {
    required String workflowName,
    required int everyMinutes,
    bool enabled = true,
    String? triggerId,
    String? label,
  }) async {
    final app = Map<String, dynamic>.from(await getApp(id));
    final triggers =
        ((app['scheduledTriggers'] as List?)
            ?.whereType<Map>()
            .map(
              (entry) =>
                  _normalizeScheduledTrigger(Map<String, dynamic>.from(entry)),
            )
            .toList(growable: true)) ??
        <Map<String, dynamic>>[];

    final normalizedWorkflowName = workflowName.trim();
    if (normalizedWorkflowName.isEmpty) {
      throw ArgumentError('workflowName is required');
    }

    final normalizedId =
        (triggerId ?? '').trim().isEmpty
            ? 'sch_${DateTime.now().microsecondsSinceEpoch}'
            : triggerId!.trim();

    final index = triggers.indexWhere(
      (entry) => (entry['id'] ?? '').toString() == normalizedId,
    );

    final limit = PremiumCapabilities.limitFor(
      PremiumCapability.schedulerTriggers,
    );
    final wouldCreate = index < 0;
    if (wouldCreate && triggers.length >= limit) {
      throw StateError('scheduler_trigger_limit_reached:$limit');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'id': normalizedId,
      'workflowName': normalizedWorkflowName,
      'label': (label ?? normalizedWorkflowName).trim(),
      'everyMinutes': everyMinutes.clamp(1, 10080),
      'enabled': enabled,
      'updatedAt': nowIso,
    };

    if (index >= 0) {
      payload['createdAt'] = triggers[index]['createdAt'] ?? nowIso;
      triggers[index] = _normalizeScheduledTrigger(payload);
    } else {
      payload['createdAt'] = nowIso;
      triggers.add(_normalizeScheduledTrigger(payload));
    }

    app['scheduledTriggers'] = triggers;
    await saveApp(id, app);
  }

  Future<void> deleteScheduledTrigger(String id, String triggerId) async {
    final app = Map<String, dynamic>.from(await getApp(id));
    final triggers =
        ((app['scheduledTriggers'] as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: true)) ??
        <Map<String, dynamic>>[];
    triggers.removeWhere(
      (entry) => (entry['id'] ?? '').toString().trim() == triggerId.trim(),
    );
    app['scheduledTriggers'] = triggers;
    await saveApp(id, app);
  }

  Future<List<Map<String, dynamic>>> getInboundWebhooks(String id) async {
    final app = await getApp(id);
    return ((app['inboundWebhooks'] as List?)
            ?.whereType<Map>()
            .map(
              (entry) =>
                  _normalizeInboundWebhook(Map<String, dynamic>.from(entry)),
            )
            .where((entry) {
              return (entry['path'] ?? '').toString().trim().isNotEmpty &&
                  (entry['workflowName'] ?? '').toString().trim().isNotEmpty;
            })
            .toList(growable: false)) ??
        const <Map<String, dynamic>>[];
  }

  Future<void> saveInboundWebhook(
    String id, {
    required String path,
    required String workflowName,
    required String secret,
    bool enabled = true,
    String? webhookId,
  }) async {
    final app = Map<String, dynamic>.from(await getApp(id));
    final webhooks =
        ((app['inboundWebhooks'] as List?)
            ?.whereType<Map>()
            .map(
              (entry) =>
                  _normalizeInboundWebhook(Map<String, dynamic>.from(entry)),
            )
            .toList(growable: true)) ??
        <Map<String, dynamic>>[];

    final normalizedPath = _normalizeInboundWebhookPath(path);
    final normalizedWorkflow = workflowName.trim();
    final normalizedSecret = secret.trim();
    if (normalizedPath.isEmpty ||
        normalizedWorkflow.isEmpty ||
        normalizedSecret.isEmpty) {
      throw ArgumentError('path, workflowName and secret are required');
    }

    final normalizedId =
        (webhookId ?? '').trim().isEmpty
            ? 'wh_${DateTime.now().microsecondsSinceEpoch}'
            : webhookId!.trim();

    final duplicatePath = webhooks.any((entry) {
      return (entry['id'] ?? '').toString() != normalizedId &&
          (entry['path'] ?? '').toString().trim().toLowerCase() ==
              normalizedPath.toLowerCase();
    });
    if (duplicatePath) {
      throw StateError('inbound_webhook_path_conflict');
    }

    final index = webhooks.indexWhere(
      (entry) => (entry['id'] ?? '').toString() == normalizedId,
    );

    final limit = PremiumCapabilities.limitFor(
      PremiumCapability.inboundWebhooks,
    );
    final wouldCreate = index < 0;
    if (wouldCreate && webhooks.length >= limit) {
      throw StateError('inbound_webhook_limit_reached:$limit');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'id': normalizedId,
      'path': normalizedPath,
      'workflowName': normalizedWorkflow,
      'secret': normalizedSecret,
      'enabled': enabled,
      'updatedAt': nowIso,
    };

    if (index >= 0) {
      payload['createdAt'] = webhooks[index]['createdAt'] ?? nowIso;
      webhooks[index] = _normalizeInboundWebhook(payload);
    } else {
      payload['createdAt'] = nowIso;
      webhooks.add(_normalizeInboundWebhook(payload));
    }

    app['inboundWebhooks'] = webhooks;
    await saveApp(id, app);
    unawaited((onAfterSave ?? (_) async {}).call(id));
  }

  Future<void> deleteInboundWebhook(String id, String webhookId) async {
    final app = Map<String, dynamic>.from(await getApp(id));
    final webhooks =
        ((app['inboundWebhooks'] as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: true)) ??
        <Map<String, dynamic>>[];
    webhooks.removeWhere(
      (entry) => (entry['id'] ?? '').toString().trim() == webhookId.trim(),
    );
    app['inboundWebhooks'] = webhooks;
    await saveApp(id, app);
    unawaited((onAfterSave ?? (_) async {}).call(id));
  }

  Map<String, dynamic> _normalizeScheduledTrigger(Map<String, dynamic> raw) {
    final id = (raw['id'] ?? '').toString().trim();
    final workflowName = (raw['workflowName'] ?? '').toString().trim();
    final label = (raw['label'] ?? workflowName).toString().trim();
    final minutesRaw = int.tryParse((raw['everyMinutes'] ?? '').toString());
    final everyMinutes =
        (minutesRaw != null && minutesRaw > 0)
            ? minutesRaw.clamp(1, 10080)
            : 60;

    return <String, dynamic>{
      'id': id,
      'workflowName': workflowName,
      'label': label,
      'everyMinutes': everyMinutes,
      'enabled': raw['enabled'] != false,
      if (raw['createdAt'] != null) 'createdAt': raw['createdAt'],
      if (raw['updatedAt'] != null) 'updatedAt': raw['updatedAt'],
    };
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

  Future<List<Map<String, dynamic>>> listAppCommands(
    String id, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _commandListCache[id];
      if (cached != null) return cached;
    }

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
    _commandListCache[id] = commands;
    return commands;
  }

  Future<void> saveAppCommand(
    String id,
    String commandId,
    Map<String, dynamic> data,
  ) async {
    _commandListCache.remove(id);
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (!await file.exists()) await file.create(recursive: true);
    await file.writeAsString(jsonEncode(normalizeCommandData(data)));
    unawaited((onAfterSave ?? (_) async {}).call(id));
  }

  Map<String, dynamic> normalizeCommandData(Map<String, dynamic> command) {
    return normalize_lib.normalizeCommandData(command);
  }

  bool _deepEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    return jsonEncode(a) == jsonEncode(b);
  }

  Future<void> deleteAppCommand(String id, String commandId) async {
    _commandListCache.remove(id);
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAppCommands(String id) async {
    _commandListCache.remove(id);
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
