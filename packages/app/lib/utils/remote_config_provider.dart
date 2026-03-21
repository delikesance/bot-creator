import 'package:flutter/foundation.dart';

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

/// Provides runtime configuration values to the widget tree.
///
/// Firebase Remote Config has been removed. All values are now served from
/// [RemoteRuntimeConfig.defaults]. The class retains [ChangeNotifier] because
/// widgets throughout the app use `context.watch<RemoteConfigProvider>()`.
class RemoteConfigProvider extends ChangeNotifier {
  final RemoteRuntimeConfig _config = RemoteRuntimeConfig.defaults;

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

  /// All actions are enabled when remote config is not in use.
  bool isActionEnabledForCurrentUser(BotCreatorActionType actionType) => true;

  Future<void> initialize() async {
    await AppDiagnostics.logInfo(
      'Runtime config using local defaults (remote config not in use)',
      data: <String, Object?>{
        'maxActiveBots': _config.maxActiveBots,
        'syncIntervalMs': _config.syncIntervalMs,
        'runnerGetTimeoutSeconds': _config.runnerGetTimeoutSeconds,
        'runnerPostTimeoutSeconds': _config.runnerPostTimeoutSeconds,
        'botRuntimeEnabled': _config.botRuntimeEnabled,
        'rewardedAdsEnabled': _config.rewardedAdsEnabled,
      },
    );
  }
}
