import 'package:bot_creator/utils/subscription_service.dart';

/// Centralized premium capability matrix used to gate paid features.
enum PremiumCapability {
  noAds,
  instantStart,
  analyticsExpanded,
  schedulerTriggers,
  inboundWebhooks,
  visualDebuggerReplay,
  autoSharding,

  /// Automatically restart the bot after a config change that cannot be
  /// hot-reloaded (e.g. gateway intent changes, new token).
  autoRestart,
}

class PremiumCapabilities {
  PremiumCapabilities._();

  // Rollout flags for roadmap capabilities. Keep disabled until implemented.
  static const Map<PremiumCapability, bool> _rolloutEnabled = {
    PremiumCapability.noAds: true,
    PremiumCapability.instantStart: true,
    PremiumCapability.analyticsExpanded: true,
    PremiumCapability.schedulerTriggers: true,
    PremiumCapability.inboundWebhooks: true,
    PremiumCapability.visualDebuggerReplay: false,
    PremiumCapability.autoSharding: true,
    PremiumCapability.autoRestart: true,
  };

  static bool get isPremiumUser => SubscriptionService.isSubscribed;

  static bool isCapabilityRolledOut(PremiumCapability capability) {
    return _rolloutEnabled[capability] ?? false;
  }

  static bool hasCapability(PremiumCapability capability) {
    if (capability == PremiumCapability.noAds ||
        capability == PremiumCapability.instantStart) {
      return isPremiumUser;
    }
    return isPremiumUser && isCapabilityRolledOut(capability);
  }

  static int limitFor(PremiumCapability capability) {
    switch (capability) {
      case PremiumCapability.noAds:
      case PremiumCapability.instantStart:
        return isPremiumUser ? 1 : 0;
      case PremiumCapability.analyticsExpanded:
        return isPremiumUser ? 1 : 0;
      case PremiumCapability.schedulerTriggers:
        return isPremiumUser ? 10 : 0;
      case PremiumCapability.inboundWebhooks:
        return isPremiumUser ? 5 : 0;
      case PremiumCapability.visualDebuggerReplay:
        return isPremiumUser ? 1 : 0;
      case PremiumCapability.autoSharding:
        return isPremiumUser ? 1 : 0;
      case PremiumCapability.autoRestart:
        return isPremiumUser ? 1 : 0;
    }
  }

  static bool get canShowPurchaseUI =>
      SubscriptionService.supportsNativeBilling && !isPremiumUser;
}
