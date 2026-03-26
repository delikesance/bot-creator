import 'dart:async';
import 'dart:io';

import 'package:bot_creator/utils/app_diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Product identifiers — must match Google Play / App Store Connect.
const String kMonthlySubscriptionId = 'bot_creator_premium_monthly';
const String kAnnualSubscriptionId = 'bot_creator_premium_annual';
const Set<String> _kSubscriptionIds = {
  kMonthlySubscriptionId,
  kAnnualSubscriptionId,
};

class SubscriptionService {
  SubscriptionService._();

  // ── Prefs keys ─────────────────────────────────────────────────────────────
  static const String _activeKey = 'subscription_active';
  static const String _productIdKey = 'subscription_product_id';

  // ── State ──────────────────────────────────────────────────────────────────
  static bool _initialized = false;
  static bool _isSubscribed = false;
  static String? _activeProductId;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static SharedPreferences? _prefs;

  /// Available products fetched from the store.
  static List<ProductDetails> products = [];

  /// Whether the store is available.
  static bool _storeAvailable = false;

  /// Whether the user holds an active premium subscription.
  static bool get isSubscribed => _isSubscribed;

  /// The active product ID (if subscribed).
  static String? get activeProductId => _activeProductId;

  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) return;

    try {
      _prefs = await SharedPreferences.getInstance();

      // Read cached state immediately so the UI can render without delay.
      _isSubscribed = _prefs?.getBool(_activeKey) ?? false;
      _activeProductId = _prefs?.getString(_productIdKey);

      final iap = InAppPurchase.instance;
      _storeAvailable = await iap.isAvailable();
      if (!_storeAvailable) {
        unawaited(
          AppDiagnostics.logInfo(
            'In-app purchase store not available',
          ),
        );
        _initialized = true;
        return;
      }

      // Listen to purchase updates.
      _subscription = iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription?.cancel(),
        onError: (Object error) {
          unawaited(
            AppDiagnostics.logError(
              'Purchase stream error',
              error,
              StackTrace.current,
              fatal: false,
            ),
          );
        },
      );

      // Query available products.
      final response = await iap.queryProductDetails(_kSubscriptionIds);
      if (response.notFoundIDs.isNotEmpty) {
        unawaited(
          AppDiagnostics.logInfo(
            'Some subscription IDs not found in store',
            data: {'ids': response.notFoundIDs.join(', ')},
          ),
        );
      }
      products = response.productDetails;

      // Restore previous purchases (required by Apple guidelines).
      await iap.restorePurchases();

      _initialized = true;
      unawaited(
        AppDiagnostics.logInfo(
          'Subscription service initialized',
          data: {
            'storeAvailable': _storeAvailable,
            'products': products.length,
            'cachedActive': _isSubscribed,
          },
        ),
      );
    } catch (error, stack) {
      _initialized = true;
      unawaited(
        AppDiagnostics.logError(
          'Failed to initialize subscription service',
          error,
          stack,
          fatal: false,
        ),
      );
    }
  }

  // ── Purchase flow ──────────────────────────────────────────────────────────

  /// Start a monthly subscription purchase.
  static Future<bool> purchaseMonthly() =>
      _purchase(kMonthlySubscriptionId);

  /// Start an annual subscription purchase.
  static Future<bool> purchaseAnnual() =>
      _purchase(kAnnualSubscriptionId);

  static Future<bool> _purchase(String productId) async {
    if (!_storeAvailable) return false;

    final product = products.cast<ProductDetails?>().firstWhere(
      (p) => p?.id == productId,
      orElse: () => null,
    );
    if (product == null) return false;

    final purchaseParam = PurchaseParam(productDetails: product);
    return InAppPurchase.instance.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  /// Restore purchases — surfaces the store-native restore dialog on iOS.
  static Future<void> restorePurchases() async {
    if (!_storeAvailable) return;
    await InAppPurchase.instance.restorePurchases();
  }

  // ── Purchase handling ──────────────────────────────────────────────────────

  static Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndDeliver(purchase);
        case PurchaseStatus.error:
          unawaited(
            AppDiagnostics.logInfo(
              'Purchase error',
              data: {
                'product': purchase.productID,
                'error': purchase.error?.message ?? 'unknown',
              },
            ),
          );
        case PurchaseStatus.canceled:
          break;
        case PurchaseStatus.pending:
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  static Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    // For a "remove ads" feature with no server, client-side verification
    // via the store receipt is sufficient. The store guarantees the purchase
    // validity through the purchaseStream.
    if (_kSubscriptionIds.contains(purchase.productID)) {
      _isSubscribed = true;
      _activeProductId = purchase.productID;
      await _prefs?.setBool(_activeKey, true);
      await _prefs?.setString(_productIdKey, purchase.productID);
      unawaited(
        AppDiagnostics.logInfo(
          'Subscription activated',
          data: {'product': purchase.productID},
        ),
      );
    }
  }

  /// Called when a subscription expires or is revoked.
  /// The store will stop sending restored purchases and we reset local state.
  static Future<void> _markExpired() async {
    _isSubscribed = false;
    _activeProductId = null;
    await _prefs?.setBool(_activeKey, false);
    await _prefs?.remove(_productIdKey);
  }

  /// Re-validate subscription status against the store.
  /// Call periodically or on app resume to detect expirations.
  static Future<void> refreshStatus() async {
    if (!_storeAvailable || !_isSupportedPlatform) return;

    // Triggering restorePurchases will re-fire the purchaseStream with
    // any still-active subscriptions. If none come back, the subscription
    // has expired.
    final previouslySubscribed = _isSubscribed;
    // Temporarily mark as not subscribed; will be re-set if restore finds
    // an active subscription.
    _isSubscribed = false;
    _activeProductId = null;

    await InAppPurchase.instance.restorePurchases();

    // Give the stream a moment to deliver restored purchases.
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!_isSubscribed && previouslySubscribed) {
      // No active subscription came back — mark as expired.
      await _markExpired();
      unawaited(
        AppDiagnostics.logInfo('Subscription expired or revoked'),
      );
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
