import 'dart:async';
import 'dart:io';

import 'package:bot_creator/utils/app_diagnostics.dart';
import 'package:bot_creator/utils/premium_capabilities.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdRewardService {
  AdRewardService._();

  static const String _androidRewardedUnitId =
      'ca-app-pub-9146609240142753/1438617123';
  static const String _iosRewardedUnitId =
      'ca-app-pub-9146609240142753/2977961908';

  static const String _testRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  static bool _initialized = false;
  static bool _isLoading = false;
  static bool _isShowing = false;
  static RewardedAd? _rewardedAd;

  /// Cooldown duration after showing a rewarded ad before offering another.
  static const Duration _cooldown = Duration(minutes: 10);
  static DateTime? _lastShownAt;

  static bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  static bool get hasReadyRewardedAd => _rewardedAd != null;

  static String get _rewardedUnitId {
    if (!kReleaseMode) {
      return _testRewardedUnitId;
    }
    if (Platform.isAndroid) {
      return _androidRewardedUnitId;
    }
    return _iosRewardedUnitId;
  }

  static Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) {
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      unawaited(
        AppDiagnostics.logInfo(
          'Rewarded ads initialized',
          data: {'platform': Platform.operatingSystem, 'release': kReleaseMode},
        ),
      );
      _preloadRewardedAd();
    } catch (error, stack) {
      unawaited(
        AppDiagnostics.logError(
          'Failed to initialize rewarded ads',
          error,
          stack,
          fatal: false,
        ),
      );
    }
  }

  static Future<bool> shouldOfferRewardedAd() async {
    if (!_initialized || !_isSupportedPlatform) return false;
    if (PremiumCapabilities.hasCapability(PremiumCapability.noAds)) {
      return false;
    }
    if (_lastShownAt != null &&
        DateTime.now().difference(_lastShownAt!) < _cooldown) {
      return false;
    }
    return true;
  }

  static void showRewardedAdNonBlocking() {
    if (!_initialized || !_isSupportedPlatform) {
      return;
    }

    if (_isShowing) {
      return;
    }

    final ad = _rewardedAd;
    if (ad == null) {
      _preloadRewardedAd();
      return;
    }

    _rewardedAd = null;
    _isShowing = true;
    _lastShownAt = DateTime.now();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        unawaited(AppDiagnostics.logInfo('Rewarded ad displayed'));
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isShowing = false;
        _preloadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isShowing = false;
        unawaited(
          AppDiagnostics.logInfo(
            'Rewarded ad failed to show',
            data: {'error': error.message, 'code': error.code},
          ),
        );
        _preloadRewardedAd();
      },
    );

    ad.show(
      onUserEarnedReward: (_, reward) {
        unawaited(
          AppDiagnostics.logInfo(
            'Reward earned from rewarded ad',
            data: {'amount': reward.amount, 'type': reward.type},
          ),
        );
      },
    );

    // Ensure a future ad is prepared even if callbacks are delayed.
    Future<void>.delayed(const Duration(seconds: 10), () {
      if (!_isShowing && _rewardedAd == null) {
        _preloadRewardedAd();
      }
    });
  }

  static void _preloadRewardedAd() {
    if (!_initialized || _isLoading || _rewardedAd != null) {
      return;
    }

    _isLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _rewardedAd = ad;
          unawaited(AppDiagnostics.logInfo('Rewarded ad loaded'));
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          unawaited(
            AppDiagnostics.logInfo(
              'Rewarded ad load failed',
              data: {'error': error.message, 'code': error.code},
            ),
          );
        },
      ),
    );
  }
}
