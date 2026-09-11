import 'dart:async';
import 'dart:io';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app.dart';
import 'package:bot_creator/routes/app/bot_logs.dart';
import 'package:bot_creator/routes/bdfd_docs.dart';
import 'package:bot_creator/routes/create.dart';
import 'package:bot_creator/routes/settings.dart';
import 'package:bot_creator/widgets/subscription_page.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:bot_creator/utils/bot_payload_builder.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/ad_reward_service.dart';
import 'package:bot_creator/utils/ads_placement_policy.dart';
import 'package:bot_creator/utils/ad_consent_service.dart';
import 'package:bot_creator/utils/premium_capabilities.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:bot_creator/utils/runner_settings.dart';
import 'package:bot_creator/widgets/native_ad_slot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  /// IDs des bots en cours d'exécution.
  Set<String> _runningBotIds = <String>{};
  bool _runnerModeEnabled = false;

  /// Label du runner actif (null si local).
  String? _activeRunnerLabel;

  /// Vrai pendant qu'un démarrage/arrêt est en cours.
  bool _isTogglingBot = false;

  /// ID du bot dont le démarrage/arrêt est en cours (pour le spinner).
  String? _togglingBotId;

  /// Un AnimationController par carte (clé = bot id) pour l'effet pulse.
  final Map<String, AnimationController> _pulseControllers = {};

  bool get _supportsForegroundTask => Platform.isAndroid || Platform.isIOS;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    AppAnalytics.logScreenView(screenName: 'HomePage', screenClass: 'HomePage');
    AppAnalytics.logEvent(name: 'home_page_opened');
    _initRunningState();
  }

  @override
  void dispose() {
    for (final ctrl in _pulseControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── Initialisation de l'état running ───────────────────────────────────────

  Future<void> _initRunningState() async {
    final runningIds = <String>{};
    final config = await RunnerSettings.getConfig();
    final runnerClient = config?.createClient(
      getTimeout: const Duration(seconds: 30),
      postTimeout: const Duration(seconds: 90),
    );
    if (runnerClient != null) {
      try {
        final status = await runnerClient.getStatus();
        for (final bot in status.bots) {
          if (bot.isRunning) {
            runningIds.add(bot.botId);
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _runningBotIds = runningIds;
        _runnerModeEnabled = true;
        _activeRunnerLabel = config!.name ?? config.url;
      });
      _syncPulse(runningIds);
      return;
    }

    if (_supportsForegroundTask) {
      try {
        final running = await FlutterForegroundTask.isRunningService;
        if (running) {
          final configuredIds = await getConfiguredMobileBotIds();
          if (configuredIds.isNotEmpty) {
            runningIds.addAll(configuredIds);
            for (final botId in configuredIds) {
              addMobileRunningBotId(botId);
            }
          } else {
            final fallbackId =
                mobileRunningBotId ??
                await FlutterForegroundTask.getData<String>(
                  key: 'running_bot_id',
                );
            if (fallbackId != null && fallbackId.isNotEmpty) {
              runningIds.add(fallbackId);
              addMobileRunningBotId(fallbackId);
            }
          }
        }
      } on MissingPluginException {
        // Plateforme non supportée.
      }
    } else {
      runningIds.addAll(desktopRunningBotIds);
    }
    if (!mounted) return;
    setState(() {
      _runningBotIds = runningIds;
      _runnerModeEnabled = false;
    });
    _syncPulse(runningIds);
  }

  // ── Gestion des animations pulse ───────────────────────────────────────────

  AnimationController _getOrCreatePulseController(String botId) {
    return _pulseControllers.putIfAbsent(
      botId,
      () => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _syncPulse(Set<String> runningIds) {
    for (final entry in _pulseControllers.entries) {
      if (runningIds.contains(entry.key)) {
        if (!entry.value.isAnimating) {
          entry.value.repeat(reverse: true);
        }
      } else {
        entry.value
          ..stop()
          ..value = 0;
      }
    }
  }

  // ── Démarrage / Arrêt du bot ───────────────────────────────────────────────

  Future<void> _toggleBot({
    required String botId,
    required String botName,
  }) async {
    if (_isTogglingBot) return;
    setState(() {
      _isTogglingBot = true;
      _togglingBotId = botId;
    });

    try {
      final isRunning = _runningBotIds.contains(botId);

      if (!isRunning && _runningBotIds.length >= 5) {
        throw Exception(
          AppStrings.tr(
            'error_with_details',
            params: {'error': 'Maximum active bots reached (5)'},
          ),
        );
      }

      // ── Fetch + validate token before anything else (only when starting) ──
      String? token;
      if (!isRunning) {
        final usingRunner = await RunnerSettings.getConfig() != null;

        if (!usingRunner) {
          final app = await appManager.getApp(botId);
          token = app['token']?.toString();
          if (token == null || token.trim().isEmpty) {
            throw Exception(
              AppStrings.tr('home_token_missing', params: {'botName': botName}),
            );
          }

          // Token check against Discord before showing ads
          try {
            await getDiscordUser(token);
          } catch (_) {
            if (!mounted) return;
            final proceed =
                await showDialog<bool>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: Text(
                          AppStrings.t('bot_home_token_invalid_title'),
                        ),
                        content: Text(
                          AppStrings.t('bot_home_token_invalid_content'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(AppStrings.t('cancel')),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(AppStrings.t('bot_home_start')),
                          ),
                        ],
                      ),
                ) ??
                false;
            if (!proceed || !mounted) return;
          }
        }

        await _maybeOfferRewardedAd();
        if (!mounted) return;
      }

      // ── Runner API (API only) ─────────────────────────────────────────────
      final client = await RunnerSettings.createClient(
        getTimeout: const Duration(seconds: 30),
        postTimeout: const Duration(seconds: 90),
      );
      if (client != null) {
        if (isRunning) {
          appendBotLog('Bot stop requested', botId: botId);
          await client.stopBot(botId);
          endBotLogSession(botId: botId);
          if (mounted) {
            setState(() {
              _runningBotIds = <String>{..._runningBotIds}..remove(botId);
            });
          }
          setBotRuntimeActive(_runningBotIds.isNotEmpty);
        } else {
          startBotLogSession(botId: botId);
          clearBotBaselineRss();
          appendBotLog('Bot start requested', botId: botId);
          final payload = await buildBotPayload(botId);
          await client.syncBot(botId, botName, payload);
          await client.startBot(botId, botName: botName);
          setBotRuntimeActive(true);
          if (mounted) {
            setState(() {
              _runningBotIds = <String>{..._runningBotIds, botId};
            });
          }
        }
        _syncPulse(_runningBotIds);
        return;
      }

      // ── Local engine ──────────────────────────────────────────────────────
      // Token already fetched and validated above; re-read if needed (stop path)
      if (token == null) {
        final app = await appManager.getApp(botId);
        token = app['token']?.toString();
      }
      if (token == null || token.trim().isEmpty) {
        throw Exception(
          AppStrings.tr('home_token_missing', params: {'botName': botName}),
        );
      }

      if (!isRunning) {
        clearBotBaselineRss();
        startBotLogSession(botId: botId);
        appendBotLog('Bot start requested', botId: botId);
      }

      if (_supportsForegroundTask) {
        // ── Mobile (Android / iOS) ─────────────────────────────────────────
        if (isRunning) {
          appendBotLog('Bot stop requested', botId: botId);
          await stopMobileBotSession(botId: botId);
          endBotLogSession(botId: botId);
          if (mounted) {
            setState(() {
              _runningBotIds = <String>{..._runningBotIds}..remove(botId);
            });
          }
          setBotRuntimeActive(_runningBotIds.isNotEmpty);
        } else {
          // Vérifier / demander la permission de notification.
          try {
            var perm =
                await FlutterForegroundTask.checkNotificationPermission();
            if (perm != NotificationPermission.granted) {
              await FlutterForegroundTask.requestNotificationPermission();
            }
          } on MissingPluginException {
            // Continuer sans vérification sur les plateformes non supportées.
          }

          await initForegroundService(eventIntervalMs: 5000);
          await startMobileBotSession(botId: botId, token: token);

          try {
            final running = await FlutterForegroundTask.isRunningService;
            if (!running) {
              throw Exception(
                AppStrings.t('home_foreground_service_not_started'),
              );
            }
          } on MissingPluginException {
            // Accepter sur les plateformes de dev.
          }

          if (mounted) {
            setState(() {
              _runningBotIds = <String>{..._runningBotIds, botId};
            });
          }
        }
      } else {
        // ── Desktop (Linux / Windows / macOS) ─────────────────────────────
        if (isRunning) {
          appendBotLog(
            AppStrings.t('home_log_desktop_stop_requested'),
            botId: botId,
          );
          await stopDesktopBot(botId: botId);
          endBotLogSession(botId: botId);
          setBotRuntimeActive(
            isDesktopBotRunning || mobileRunningBotIds.isNotEmpty,
          );
          clearBotBaselineRss();
          if (mounted) {
            setState(() {
              _runningBotIds = <String>{..._runningBotIds}..remove(botId);
            });
          }
        } else {
          await startDesktopBot(token);
          if (mounted) {
            setState(() {
              _runningBotIds = <String>{..._runningBotIds, botId};
            });
          }
        }
      }

      _syncPulse(_runningBotIds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.tr(
                'error_with_details',
                params: {'error': e.toString()},
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingBot = false;
          _togglingBotId = null;
        });
      }
    }
  }

  Future<void> _maybeOfferRewardedAd() async {
    if (!_supportsForegroundTask || !mounted) {
      return;
    }

    if (PremiumCapabilities.hasCapability(PremiumCapability.noAds)) {
      return;
    }

    if (!await AdRewardService.shouldOfferRewardedAd()) {
      return;
    }

    if (!AdRewardService.hasReadyRewardedAd) {
      return;
    }

    final consentGranted = await _ensureAdsConsent();
    if (!consentGranted || !mounted) {
      return;
    }

    if (kDebugMode) {
      final shouldWatch =
          await showDialog<bool>(
            context: context,
            builder:
                (dialogContext) => AlertDialog(
                  title: Text(AppStrings.t('rewarded_start_title')),
                  content: Text(AppStrings.t('rewarded_start_message')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(AppStrings.t('rewarded_start_skip')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(AppStrings.t('rewarded_start_watch')),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!shouldWatch || !mounted) {
        return;
      }
    } else {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(AppStrings.t('rewarded_start_title')),
              content: Text(AppStrings.t('rewarded_start_message')),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(AppStrings.t('rewarded_start_continue')),
                ),
              ],
            ),
      );
    }

    AdRewardService.showRewardedAdNonBlocking();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.t('rewarded_start_thanks'))),
    );
  }

  Future<bool> _ensureAdsConsent() async {
    final consentGranted = await AdConsentService.ensureCanRequestAds();
    if (!consentGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('ads_consent_refused_info'))),
      );
    }
    return consentGranted;
  }

  // ── Navigation helpers ──────────────────────────────────────────────────────

  Future<void> _handleRefresh() async {
    await appManager.refreshApps();
    if (mounted) await _initRunningState();
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) await _initRunningState();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: appManager.getAppStream(),
      initialData: const <dynamic>[],
      builder: (context, snapshot) {
        final apps = snapshot.data;

        return LayoutBuilder(
          builder: (context, constraints) {
            const maxContentWidth = 640.0;
            final width = constraints.maxWidth;
            final horizontal =
                width > maxContentWidth
                    ? (width - maxContentWidth) / 2 + 20.0
                    : 16.0;

            final children = <Widget>[
              _HomeHeader(
                onRefresh: _handleRefresh,
                onDocs: () => _openPage(const BdfdDocsPage()),
                onSettings: () => _openPage(const SettingPage()),
              ),
              const SizedBox(height: 22),
              _TurnkeyCard(onTap: () => _openPage(const AppCreatePage())),
              const SizedBox(height: 22),
            ];

            if (snapshot.hasError) {
              developer.log(
                'Error loading data: ${snapshot.error}',
                name: 'HomePage',
              );
              children.add(
                _buildInfoCard(
                  context,
                  Icons.error_outline_rounded,
                  AppStrings.t('app_loading_error'),
                ),
              );
            } else if (apps == null || apps.isEmpty) {
              children.add(const _EmptyStateWithSupport());
            } else {
              final namesById = <String, String>{
                for (final app in apps)
                  (app['id']?.toString() ?? ''):
                      (app['name']?.toString() ??
                          AppStrings.t('home_unknown_app')),
              };
              final activeSessionIds = _runningBotIds.toList(growable: false)
                ..sort();

              if (_supportsForegroundTask && activeSessionIds.isNotEmpty) {
                children.add(
                  _buildSessionsBanner(context, activeSessionIds, namesById),
                );
                children.add(const SizedBox(height: 16));
              }

              if (AdsPlacementPolicy.isPlacementEnabled(
                    NativeAdPlacement.homeBots,
                  ) &&
                  apps.length >= AdsPlacementPolicy.listInterval) {
                children.add(
                  const NativeAdSlot(
                    placement: NativeAdPlacement.homeBots,
                    height: 118,
                    margin: EdgeInsets.only(bottom: 16),
                  ),
                );
              }

              for (var index = 0; index < apps.length; index++) {
                final app = apps[index];
                final name =
                    app['name']?.toString() ??
                    AppStrings.t('home_unknown_app');
                final id = app['id']?.toString() ?? '';
                final avatar = app['avatar']?.toString();
                final guildCount = app['guild_count'] as int?;
                final hostingExpiresAt =
                    (app['hosting_expires_at'] as num?)?.toInt();
                final isRunning = _runningBotIds.contains(id);
                final pulseCtrl = _getOrCreatePulseController(id);

                children.add(
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == apps.length - 1 ? 0 : 14,
                    ),
                    child: _BotCard(
                      key: ValueKey<String>(id),
                      name: name,
                      avatar: avatar,
                      guildCount: guildCount,
                      hostingExpiresAt: hostingExpiresAt,
                      isRunning: isRunning,
                      canToggle: !_isTogglingBot,
                      isTogglingThisBot: _togglingBotId == id,
                      runnerLabel:
                          isRunning && _runnerModeEnabled
                              ? _activeRunnerLabel
                              : null,
                      pulseController: pulseCtrl,
                      onManage:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => AppEditPage(
                                    appName: name,
                                    id: int.tryParse(id) ?? 0,
                                  ),
                            ),
                          ).then((_) => _initRunningState()),
                      onToggle: () => _toggleBot(botId: id, botName: name),
                      onLogs:
                          isRunning
                              ? () => _openPage(BotLogsPage(botId: id))
                              : null,
                      onAddHosting: () => _openPage(const SubscriptionPage()),
                    ),
                  ),
                );
              }
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 120),
              physics: const AlwaysScrollableScrollPhysics(),
              children: children,
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard(BuildContext context, IconData icon, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsBanner(
    BuildContext context,
    List<String> activeSessionIds,
    Map<String, String> namesById,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sessions mobiles actives (${activeSessionIds.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final botId in activeSessionIds)
                Chip(
                  avatar: const Icon(Icons.smart_toy, size: 16),
                  label: Text(namesById[botId] ?? botId),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Formate une durée d'hébergement restante en « X mois, Xj, Xh, Xm ».
String _formatHostingRemaining(int expiresAtMs) {
  final remaining = expiresAtMs - DateTime.now().millisecondsSinceEpoch;
  if (remaining <= 0) {
    return '0${AppStrings.t('home_hosting_unit_minute')}';
  }
  final totalMinutes = remaining ~/ 60000;
  final minutes = totalMinutes % 60;
  final totalHours = totalMinutes ~/ 60;
  final hours = totalHours % 24;
  final totalDays = totalHours ~/ 24;
  final days = totalDays % 30;
  final months = totalDays ~/ 30;

  final parts = <String>[];
  if (months > 0) {
    parts.add('$months ${AppStrings.t('home_hosting_unit_month')}');
  }
  if (months > 0 || days > 0) {
    parts.add('$days${AppStrings.t('home_hosting_unit_day')}');
  }
  parts.add('$hours${AppStrings.t('home_hosting_unit_hour')}');
  parts.add('$minutes${AppStrings.t('home_hosting_unit_minute')}');
  return parts.join(', ');
}

// ── En-tête d'accueil ─────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onRefresh,
    required this.onDocs,
    required this.onSettings,
  });

  final VoidCallback onRefresh;
  final VoidCallback onDocs;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.t('home_overline'),
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                AppStrings.t('app_title'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        _HeaderIconButton(
          icon: Icons.sync_rounded,
          tooltip: AppStrings.t('home_refresh_tooltip'),
          onTap: onRefresh,
        ),
        const SizedBox(width: 10),
        _HeaderIconButton(
          icon: Icons.menu_book_rounded,
          tooltip: AppStrings.t('home_docs_tooltip'),
          onTap: onDocs,
        ),
        const SizedBox(width: 10),
        _HeaderIconButton(
          icon: Icons.settings_rounded,
          tooltip: AppStrings.t('home_settings_tooltip'),
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

// ── Carte promo « Bots Clé en main » ──────────────────────────────────────────

class _TurnkeyCard extends StatelessWidget {
  const _TurnkeyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _BrandIconSquare(icon: Icons.smart_toy_rounded, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t('home_turnkey_title'),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.t('home_turnkey_subtitle'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carré d'icône teinté de la couleur de marque (avec avatar optionnel).
class _BrandIconSquare extends StatelessWidget {
  const _BrandIconSquare({
    required this.icon,
    this.size = 48,
    this.imageUrl,
  });

  final IconData icon;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kBrandPurple.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child:
          hasImage
              ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) =>
                        Icon(icon, color: kBrandPurple, size: size * 0.5),
              )
              : Icon(icon, color: kBrandPurple, size: size * 0.5),
    );
  }
}

// ── Carte bot ─────────────────────────────────────────────────────────────────

class _BotCard extends StatefulWidget {
  const _BotCard({
    super.key,
    required this.name,
    required this.avatar,
    required this.guildCount,
    required this.hostingExpiresAt,
    required this.isRunning,
    required this.canToggle,
    required this.isTogglingThisBot,
    required this.pulseController,
    required this.onManage,
    required this.onToggle,
    required this.onLogs,
    required this.onAddHosting,
    this.runnerLabel,
  });

  final String name;
  final String? avatar;
  final int? guildCount;
  final int? hostingExpiresAt;
  final bool isRunning;
  final bool canToggle;
  final bool isTogglingThisBot;
  final String? runnerLabel;
  final AnimationController pulseController;
  final VoidCallback onManage;
  final VoidCallback onToggle;
  final VoidCallback? onLogs;
  final VoidCallback onAddHosting;

  @override
  State<_BotCard> createState() => _BotCardState();
}

class _BotCardState extends State<_BotCard> {
  late bool _expanded = widget.isRunning;

  @override
  void didUpdateWidget(covariant _BotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      _expanded = widget.isRunning;
    }
  }

  String _subtitle() {
    final count = widget.guildCount ?? 0;
    if (count > 0) {
      final String key;
      if (widget.isRunning) {
        key =
            count > 1
                ? 'home_servers_active_other'
                : 'home_servers_active_one';
      } else {
        key = count > 1 ? 'home_server_count_other' : 'home_server_count_one';
      }
      return AppStrings.tr(key, params: {'count': count.toString()});
    }
    return widget.isRunning
        ? AppStrings.t('home_status_online')
        : AppStrings.t('home_status_offline');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              widget.isRunning
                  ? kOnlineColor.withValues(alpha: 0.45)
                  : scheme.outlineVariant,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            // ── En-tête (tap pour déplier / replier) ───────────────────────
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _AvatarSquare(
                      imageUrl: widget.avatar,
                      isRunning: widget.isRunning,
                      pulseController: widget.pulseController,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ActionPill(
                      isRunning: widget.isRunning,
                      loading: widget.isTogglingThisBot,
                      onTap: widget.canToggle ? widget.onToggle : null,
                    ),
                  ],
                ),
              ),
            ),
            // ── Contenu déplié ─────────────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState:
                  _expanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: [
                    if (widget.runnerLabel != null) ...[
                      _RunnerChip(label: widget.runnerLabel!),
                      const SizedBox(height: 12),
                    ],
                    _HostingBlock(
                      expiresAtMs: widget.hostingExpiresAt,
                      onAdd: widget.onAddHosting,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: widget.onManage,
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: Text(AppStrings.t('home_manage_app')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _SquareIconButton(
                          icon: Icons.article_outlined,
                          tooltip: AppStrings.t('home_logs_tooltip'),
                          onTap: widget.onLogs,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarSquare extends StatelessWidget {
  const _AvatarSquare({
    required this.imageUrl,
    required this.isRunning,
    required this.pulseController,
  });

  final String? imageUrl;
  final bool isRunning;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: isRunning ? 1.0 : 0.55,
            child: _BrandIconSquare(
              icon: Icons.smart_toy_rounded,
              size: 50,
              imageUrl: imageUrl,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: AnimatedBuilder(
              animation: pulseController,
              builder: (_, _) {
                final glow =
                    isRunning ? 0.4 + 0.6 * pulseController.value : 1.0;
                return Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainer,
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: glow,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isRunning
                                ? kOnlineColor
                                : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.isRunning,
    required this.loading,
    required this.onTap,
  });

  final bool isRunning;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isRunning ? kDangerColor : kBrandPurple;
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(
                  isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: color,
                ),
              const SizedBox(width: 6),
              Text(
                isRunning
                    ? AppStrings.t('home_stop')
                    : AppStrings.t('home_start_action'),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(
              icon,
              size: 20,
              color:
                  enabled
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunnerChip extends StatelessWidget {
  const _RunnerChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 14, color: scheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostingBlock extends StatelessWidget {
  const _HostingBlock({required this.expiresAtMs, required this.onAdd});

  final int? expiresAtMs;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlimited = expiresAtMs == null;
    final value =
        unlimited
            ? AppStrings.t('home_hosting_unlimited')
            : _formatHostingRemaining(expiresAtMs!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t('home_hosting_remaining'),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (unlimited) ...[
                      const Icon(
                        Icons.all_inclusive_rounded,
                        size: 18,
                        color: kBrandPurpleSoft,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _AddHostingButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _AddHostingButton extends StatelessWidget {
  const _AddHostingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: kBrandPurpleSoft),
              const SizedBox(width: 4),
              Text(
                AppStrings.t('home_hosting_add'),
                style: const TextStyle(
                  color: kBrandPurpleSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state avec CTA support ──────────────────────────────────────────

class _EmptyStateWithSupport extends StatelessWidget {
  const _EmptyStateWithSupport();

  static const _discordUrl = 'https://discord.gg/gyEGNBUZdA';
  static const _discordColor = Color(0xFF5865F2);

  Future<void> _openDiscord() async {
    final uri = Uri.parse(_discordUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.t('app_no_apps'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              AppStrings.t('home_empty_support_hint'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openDiscord,
              icon: const Icon(Icons.forum_rounded, size: 18),
              label: Text(AppStrings.t('home_empty_support_btn')),
              style: FilledButton.styleFrom(
                backgroundColor: _discordColor,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
    );
  }
}
