import 'dart:io';

import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/premium_capabilities.dart';
import 'package:bot_creator/utils/subscription_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen page (or bottom-sheet) for purchasing a premium subscription.
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  /// Show the subscription page as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    if (!SubscriptionService.supportsNativeBilling) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(AppStrings.t('subscription_not_available_on_platform')),
        ),
      );
      return Future<void>.value();
    }

    AppAnalytics.logEvent(name: 'subscription_page_opened');
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SubscriptionPage(),
    );
  }

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _purchasing = false;
  String? _error;

  Future<void> _buy({required bool annual}) async {
    setState(() {
      _purchasing = true;
      _error = null;
    });

    try {
      final success =
          annual
              ? await SubscriptionService.purchaseAnnual()
              : await SubscriptionService.purchaseMonthly();

      if (!success && mounted) {
        setState(() => _error = AppStrings.t('subscription_error'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _purchasing = true;
      _error = null;
    });

    try {
      await SubscriptionService.restorePurchases();
      // Wait a moment for the stream to deliver restored purchases.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) {
        if (SubscriptionService.isSubscribed) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.t('subscription_restored'))),
          );
        } else {
          setState(
            () => _error = AppStrings.t('subscription_restore_not_found'),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allFeatures = PremiumCapabilities.getAllFeaturesForSubscription();

    // Close automatically when subscription becomes active.
    if (SubscriptionService.isSubscribed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 48,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                AppStrings.t('subscription_title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t('subscription_subtitle'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Benefits (exhaustive premium feature list)
              ...allFeatures.asMap().entries.map((entry) {
                final feature = entry.value;
                final comingSoon = PremiumCapabilities.isFeatureComingSoon(
                  feature.capability,
                );
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == allFeatures.length - 1 ? 0 : 10,
                  ),
                  child: _BenefitRow(
                    icon: feature.icon,
                    text: AppStrings.t(feature.titleKey),
                    subtitle: AppStrings.t(feature.descriptionKey),
                    comingSoon: comingSoon,
                  ),
                );
              }),
              const SizedBox(height: 28),

              // Annual plan (recommended)
              _PlanCard(
                title: AppStrings.t('subscription_annual_title'),
                price: _priceForProduct(kAnnualSubscriptionId, '8,00 €'),
                period: AppStrings.t('subscription_per_year'),
                badge: AppStrings.t('subscription_save_badge'),
                isPrimary: true,
                onTap: _purchasing ? null : () => _buy(annual: true),
              ),
              const SizedBox(height: 12),

              // Monthly plan
              _PlanCard(
                title: AppStrings.t('subscription_monthly_title'),
                price: _priceForProduct(kMonthlySubscriptionId, '2,00 €'),
                period: AppStrings.t('subscription_per_month'),
                isPrimary: false,
                onTap: _purchasing ? null : () => _buy(annual: false),
              ),
              const SizedBox(height: 16),

              if (_purchasing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 8),

              // Restore purchases
              TextButton(
                onPressed: _purchasing ? null : _restore,
                child: Text(AppStrings.t('subscription_restore')),
              ),
              const SizedBox(height: 8),

              // Legal links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegalLink(
                    label: AppStrings.t('subscription_terms'),
                    url: _termsUrl,
                  ),
                  const SizedBox(width: 16),
                  _LegalLink(
                    label: AppStrings.t('subscription_privacy'),
                    url: _privacyUrl,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _priceForProduct(String productId, String fallback) {
    final product = SubscriptionService.products.cast<dynamic>().firstWhere(
      (p) => p.id == productId,
      orElse: () => null,
    );
    if (product != null) return product.price as String;
    return fallback;
  }

  static String get _termsUrl {
    if (!kIsWeb && Platform.isIOS) {
      return 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
    }
    return 'https://play.google.com/intl/en_us/about/play-terms/';
  }

  static const String _privacyUrl = 'https://bot-creator-f884b.web.app/privacy';
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.text,
    required this.subtitle,
    this.comingSoon = false,
  });

  final IconData icon;
  final String text;
  final String subtitle;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.amber),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (comingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        AppStrings.t('subscription_feature_coming_soon'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.isPrimary,
    this.badge,
    this.onTap,
  });

  final String title;
  final String price;
  final String period;
  final String? badge;
  final bool isPrimary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isPrimary ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side:
            isPrimary
                ? const BorderSide(color: Colors.amber, width: 2)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      period,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? Colors.amber : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          decoration: TextDecoration.underline,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
