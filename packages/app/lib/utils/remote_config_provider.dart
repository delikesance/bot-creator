import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../types/action.dart';
import 'app_diagnostics.dart';

class RemoteRuntimeConfig {
  const RemoteRuntimeConfig({
    required this.maxActiveBots,
    required this.syncIntervalMs,
    required this.runnerGetTimeoutSeconds,
    required this.runnerPostTimeoutSeconds,
    required this.botRuntimeEnabled,
    required this.rewardedAdsEnabled,
    required this.loadedFromRemote,
  });

  final int maxActiveBots;
  final int syncIntervalMs;
  final int runnerGetTimeoutSeconds;
  final int runnerPostTimeoutSeconds;
  final bool botRuntimeEnabled;
  final bool rewardedAdsEnabled;
  final bool loadedFromRemote;

  static const RemoteRuntimeConfig defaults = RemoteRuntimeConfig(
    maxActiveBots: 5,
    syncIntervalMs: 5000,
    runnerGetTimeoutSeconds: 30,
    runnerPostTimeoutSeconds: 90,
    botRuntimeEnabled: true,
    rewardedAdsEnabled: true,
    loadedFromRemote: false,
  );
}

class RemoteConfigProvider extends ChangeNotifier {
  static const String _rolloutSubjectIdKey =
      'remote_config_rollout_subject_id_v1';

  RemoteRuntimeConfig _config = RemoteRuntimeConfig.defaults;
  String _rolloutSubjectId = 'unknown';
  Map<String, bool> _actionFlagsByName = <String, bool>{};
  Map<String, int> _actionRolloutByName = <String, int>{};

  RemoteRuntimeConfig get config => _config;
  int get maxActiveBots => _config.maxActiveBots;
  int get syncIntervalMs => _config.syncIntervalMs;
  int get runnerGetTimeoutSeconds => _config.runnerGetTimeoutSeconds;
  int get runnerPostTimeoutSeconds => _config.runnerPostTimeoutSeconds;
  Duration get runnerGetTimeout =>
      Duration(seconds: _config.runnerGetTimeoutSeconds);
  Duration get runnerPostTimeout =>
      Duration(seconds: _config.runnerPostTimeoutSeconds);
  bool get isBotRuntimeEnabled => _config.botRuntimeEnabled;
  bool get rewardedAdsEnabled => _config.rewardedAdsEnabled;
  int get apiTimeoutSeconds => _config.runnerGetTimeoutSeconds;
  Map<String, bool> get actionFlagsByName => _actionFlagsByName;
  Map<String, int> get actionRolloutByName => _actionRolloutByName;

  /// Returns true if the current user/install is in the rollout bucket.
  bool isFeatureEnabledForCurrentUser({
    required String featureKey,
    required bool baseEnabled,
    required int rolloutPercent,
  }) {
    final safeRollout = rolloutPercent.clamp(0, 100);
    if (!baseEnabled || safeRollout <= 0) {
      return false;
    }
    if (safeRollout >= 100) {
      return true;
    }
    return rolloutBucketForFeature(featureKey) < safeRollout;
  }

  int rolloutBucketForFeature(String featureKey) {
    final digest =
        sha256.convert(utf8.encode('$featureKey:$_rolloutSubjectId')).bytes;
    final value =
        (digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3];
    return value % 100;
  }

  bool isActionEnabledForCurrentUser(BotCreatorActionType actionType) {
    final actionName = actionType.name;
    final explicitEnabled = _actionFlagsByName[actionName] ?? true;
    final rolloutPercent = (_actionRolloutByName[actionName] ?? 100).clamp(
      0,
      100,
    );
    return isFeatureEnabledForCurrentUser(
      featureKey: 'action_$actionName',
      baseEnabled: explicitEnabled,
      rolloutPercent: rolloutPercent,
    );
  }

  Future<void> initialize({required bool firebaseReady}) async {
    _rolloutSubjectId = await _loadOrCreateRolloutSubjectId();

    if (!firebaseReady) {
      await AppDiagnostics.logInfo(
        'Remote Config disabled (Firebase unavailable), using local defaults',
        data: <String, Object?>{'rolloutSubjectId': _rolloutSubjectId},
      );
      return;
    }

    final remoteConfig = FirebaseRemoteConfig.instance;

    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval:
              kDebugMode
                  ? const Duration(minutes: 2)
                  : const Duration(hours: 1),
        ),
      );

      await remoteConfig.setDefaults(<String, dynamic>{
        'max_active_bots': RemoteRuntimeConfig.defaults.maxActiveBots,
        'sync_interval_ms': RemoteRuntimeConfig.defaults.syncIntervalMs,
        'api_timeout_seconds':
            RemoteRuntimeConfig.defaults.runnerGetTimeoutSeconds,
        'runner_get_timeout_seconds': 0,
        'runner_post_timeout_seconds': 0,
        'feature_bot_runtime_enabled':
            RemoteRuntimeConfig.defaults.botRuntimeEnabled,
        'rewarded_ads_enabled': RemoteRuntimeConfig.defaults.rewardedAdsEnabled,
        'feature_action_flags_json': '{}',
        'feature_action_rollout_json': '{}',
      });

      final loadedFromRemote = await remoteConfig.fetchAndActivate();
      _config = _readSnapshot(remoteConfig, loadedFromRemote: loadedFromRemote);
      _actionFlagsByName = _readActionFlags(remoteConfig);
      _actionRolloutByName = _readActionRollouts(remoteConfig);
      notifyListeners();

      await AppDiagnostics.logInfo(
        'Remote Config loaded',
        data: <String, Object?>{
          'loadedFromRemote': loadedFromRemote,
          'maxActiveBots': _config.maxActiveBots,
          'syncIntervalMs': _config.syncIntervalMs,
          'runnerGetTimeoutSeconds': _config.runnerGetTimeoutSeconds,
          'runnerPostTimeoutSeconds': _config.runnerPostTimeoutSeconds,
          'botRuntimeEnabled': _config.botRuntimeEnabled,
          'rewardedAdsEnabled': _config.rewardedAdsEnabled,
          'dynamicActionFlagsCount': _actionFlagsByName.length,
          'dynamicActionRolloutsCount': _actionRolloutByName.length,
        },
      );
    } catch (error, stack) {
      _config = RemoteRuntimeConfig.defaults;
      _actionFlagsByName = <String, bool>{};
      _actionRolloutByName = <String, int>{};
      notifyListeners();
      await AppDiagnostics.logError(
        'Remote Config fetch failed, using defaults',
        error,
        stack,
        fatal: false,
      );
    }
  }

  Map<String, bool> _readActionFlags(FirebaseRemoteConfig remoteConfig) {
    final raw = remoteConfig.getString('feature_action_flags_json').trim();
    if (raw.isEmpty) {
      return <String, bool>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, bool>{};
      }

      final mapped = <String, bool>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) {
          continue;
        }
        final value = entry.value;
        if (value is bool) {
          mapped[key] = value;
          continue;
        }
        if (value is String) {
          final normalized = value.trim().toLowerCase();
          if (normalized == 'true') {
            mapped[key] = true;
          } else if (normalized == 'false') {
            mapped[key] = false;
          }
        }
      }
      return mapped;
    } catch (_) {
      return <String, bool>{};
    }
  }

  Map<String, int> _readActionRollouts(FirebaseRemoteConfig remoteConfig) {
    final raw = remoteConfig.getString('feature_action_rollout_json').trim();
    if (raw.isEmpty) {
      return <String, int>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, int>{};
      }

      final mapped = <String, int>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) {
          continue;
        }
        final rawValue = entry.value;
        final parsed =
            rawValue is int
                ? rawValue
                : int.tryParse(rawValue?.toString() ?? '');
        if (parsed == null) {
          continue;
        }
        mapped[key] = parsed.clamp(0, 100);
      }
      return mapped;
    } catch (_) {
      return <String, int>{};
    }
  }

  RemoteRuntimeConfig _readSnapshot(
    FirebaseRemoteConfig remoteConfig, {
    required bool loadedFromRemote,
  }) {
    final rawMaxBots = remoteConfig.getInt('max_active_bots');
    final rawSyncIntervalMs = remoteConfig.getInt('sync_interval_ms');
    final rawApiTimeout = remoteConfig.getInt('api_timeout_seconds');
    final rawRunnerGetTimeout = remoteConfig.getInt(
      'runner_get_timeout_seconds',
    );
    final rawRunnerPostTimeout = remoteConfig.getInt(
      'runner_post_timeout_seconds',
    );

    final legacyRunnerGetTimeout = _clampInt(
      rawApiTimeout,
      fallback: RemoteRuntimeConfig.defaults.runnerGetTimeoutSeconds,
      min: 3,
      max: 120,
    );
    final legacyRunnerPostTimeout = _clampInt(
      rawApiTimeout > 0 ? rawApiTimeout * 3 : 0,
      fallback: RemoteRuntimeConfig.defaults.runnerPostTimeoutSeconds,
      min: 5,
      max: 180,
    );

    return RemoteRuntimeConfig(
      maxActiveBots: _clampInt(
        rawMaxBots,
        fallback: RemoteRuntimeConfig.defaults.maxActiveBots,
        min: 1,
        max: 20,
      ),
      syncIntervalMs: _clampInt(
        rawSyncIntervalMs,
        fallback: RemoteRuntimeConfig.defaults.syncIntervalMs,
        min: 1000,
        max: 60000,
      ),
      runnerGetTimeoutSeconds: _clampInt(
        rawRunnerGetTimeout,
        fallback: legacyRunnerGetTimeout,
        min: 3,
        max: 120,
      ),
      runnerPostTimeoutSeconds: _clampInt(
        rawRunnerPostTimeout,
        fallback: legacyRunnerPostTimeout,
        min: 5,
        max: 180,
      ),
      botRuntimeEnabled: remoteConfig.getBool('feature_bot_runtime_enabled'),
      rewardedAdsEnabled: remoteConfig.getBool('rewarded_ads_enabled'),
      loadedFromRemote: loadedFromRemote,
    );
  }

  Future<String> _loadOrCreateRolloutSubjectId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_rolloutSubjectIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final random = Random.secure();
    final candidate =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${random.nextInt(1 << 32).toRadixString(16)}';
    await prefs.setString(_rolloutSubjectIdKey, candidate);
    return candidate;
  }

  int _clampInt(
    int raw, {
    required int fallback,
    required int min,
    required int max,
    bool allowZero = false,
  }) {
    if (allowZero && raw == 0) {
      return 0;
    }
    if (raw <= 0) {
      return fallback;
    }
    if (raw < min) {
      return min;
    }
    if (raw > max) {
      return max;
    }
    return raw;
  }
}
