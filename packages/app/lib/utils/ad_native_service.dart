import 'dart:async';
import 'dart:io';

import 'package:bot_creator/utils/ad_consent_service.dart';
import 'package:bot_creator/utils/ads_placement_policy.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/app_diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdNativeService {
  AdNativeService._();

  static const String _androidNativeUnitId =
      'ca-app-pub-9146609240142753/8747612571';
  static const String _iosNativeUnitId =
      'ca-app-pub-9146609240142753/9769050206';

  static const String _testAndroidNativeUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _testIosNativeUnitId =
      'ca-app-pub-3940256099942544/3986624511';

  static const String _lastImpressionAtKey = 'ads_native_last_impression_at';

  static bool _initialized = false;
  static SharedPreferences? _prefs;
  static bool? _cachedCanRequestAds;

  static bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  static String get _nativeUnitId {
    if (!kReleaseMode) {
      if (Platform.isAndroid) {
        return _testAndroidNativeUnitId;
      }
      return _testIosNativeUnitId;
    }

    if (Platform.isAndroid) {
      return _androidNativeUnitId;
    }
    return _iosNativeUnitId;
  }

  static Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) {
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      unawaited(
        AppDiagnostics.logInfo(
          'Native ads initialized',
          data: {'platform': Platform.operatingSystem, 'release': kReleaseMode},
        ),
      );
    } catch (error, stack) {
      unawaited(
        AppDiagnostics.logError(
          'Failed to initialize native ads',
          error,
          stack,
          fatal: false,
        ),
      );
    }
  }

  static Future<bool> canLoadForPlacement(NativeAdPlacement placement) async {
    if (!_initialized || !_isSupportedPlatform) {
      return false;
    }

    if (!AdsPlacementPolicy.isPlacementEnabled(placement)) {
      return false;
    }

    final canRequestAds = await _canRequestAds();
    if (!canRequestAds) {
      await AppAnalytics.logAdEvent(
        action: 'blocked_consent',
        format: 'native',
        placement: AdsPlacementPolicy.placementKey(placement),
      );
      return false;
    }

    final cooldownElapsed = await _isGlobalCooldownElapsed();
    if (!cooldownElapsed) {
      await AppAnalytics.logAdEvent(
        action: 'blocked_cooldown',
        format: 'native',
        placement: AdsPlacementPolicy.placementKey(placement),
      );
      return false;
    }

    return true;
  }

  static NativeAd createNativeAd({
    required NativeAdPlacement placement,
    required NativeAdListener listener,
  }) {
    return NativeAd(
      adUnitId: _nativeUnitId,
      listener: listener,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
    );
  }

  static Future<void> trackRequest(NativeAdPlacement placement) {
    return AppAnalytics.logAdEvent(
      action: 'request',
      format: 'native',
      placement: AdsPlacementPolicy.placementKey(placement),
    );
  }

  static Future<void> trackLoaded(NativeAdPlacement placement) {
    return AppAnalytics.logAdEvent(
      action: 'loaded',
      format: 'native',
      placement: AdsPlacementPolicy.placementKey(placement),
    );
  }

  static Future<void> trackClicked(NativeAdPlacement placement) {
    return AppAnalytics.logAdEvent(
      action: 'clicked',
      format: 'native',
      placement: AdsPlacementPolicy.placementKey(placement),
    );
  }

  static Future<void> trackFailed(
    NativeAdPlacement placement,
    AdError error,
  ) async {
    await AppAnalytics.logAdEvent(
      action: 'failed',
      format: 'native',
      placement: AdsPlacementPolicy.placementKey(placement),
      parameters: {'code': error.code, 'domain': error.domain},
    );

    unawaited(
      AppDiagnostics.logInfo(
        'Native ad failed to load',
        data: {
          'placement': AdsPlacementPolicy.placementKey(placement),
          'code': error.code,
          'domain': error.domain,
          'message': error.message,
        },
      ),
    );
  }

  static Future<void> recordImpression(NativeAdPlacement placement) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setInt(_lastImpressionAtKey, now);

    await AppAnalytics.logAdEvent(
      action: 'impression',
      format: 'native',
      placement: AdsPlacementPolicy.placementKey(placement),
    );
  }

  static Future<bool> _canRequestAds() async {
    final cached = _cachedCanRequestAds;
    if (cached != null) {
      return cached;
    }

    final canRequest = await AdConsentService.ensureCanRequestAds();
    _cachedCanRequestAds = canRequest;
    return canRequest;
  }

  static Future<bool> _isGlobalCooldownElapsed() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final lastImpressionAt = prefs.getInt(_lastImpressionAtKey);
    if (lastImpressionAt == null) {
      return true;
    }

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastImpressionAt;
    return elapsed >= AdsPlacementPolicy.globalCooldown.inMilliseconds;
  }
}
