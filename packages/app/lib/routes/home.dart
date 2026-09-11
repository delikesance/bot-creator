import 'dart:async';
import 'dart:io';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app.dart';
import 'package:bot_creator/routes/bdfd_docs.dart';
import 'package:bot_creator/routes/create.dart';
import 'package:bot_creator/routes/settings.dart';
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
import 'package:google_fonts/google_fonts.dart';
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
            final width = constraints.maxWidth;
            final isWide = width >= kDesktopBreakpoint;
            final columns = isWide ? 2 : 1;
            final contentMaxWidth = isWide ? 1000.0 : 640.0;
            final sidePad = isWide ? 28.0 : 16.0;
            final horizontal =
                width > contentMaxWidth
                    ? (width - contentMaxWidth) / 2 + sidePad
                    : sidePad;
            final innerWidth = width - horizontal * 2;

            final children = <Widget>[
              _HomeHeader(
                onRefresh: _handleRefresh,
                onDocs: () => _openPage(const BdfdDocsPage()),
                onSettings: () => _openPage(const SettingPage()),
                showCreate: isWide,
                onCreate: () => _openPage(const AppCreatePage()),
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

              final cards = <Widget>[
                for (final app in apps) _buildBotCard(context, app),
              ];

              if (columns == 1) {
                for (var i = 0; i < cards.length; i++) {
                  children.add(
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == cards.length - 1 ? 0 : 14,
                      ),
                      child: cards[i],
                    ),
                  );
                }
              } else {
                const gap = 16.0;
                final cardWidth =
                    (innerWidth - (columns - 1) * gap) / columns;
                children.add(
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final card in cards)
                        SizedBox(width: cardWidth, child: card),
                    ],
                  ),
                );
              }
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                24,
                horizontal,
                isWide ? 40 : 120,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              children: children,
            );
          },
        );
      },
    );
  }

  /// Construit une carte bot à partir d'une entrée du flux d'apps.
  Widget _buildBotCard(BuildContext context, dynamic app) {
    final name = app['name']?.toString() ?? AppStrings.t('home_unknown_app');
    final id = app['id']?.toString() ?? '';
    final avatar = app['avatar']?.toString();
    final guildCount = app['guild_count'] as int?;
    final hostingExpiresAt = (app['hosting_expires_at'] as num?)?.toInt();
    final isRunning = _runningBotIds.contains(id);
    final pulseCtrl = _getOrCreatePulseController(id);

    return _BotCard(
      key: ValueKey<String>(id),
      name: name,
      avatar: avatar,
      guildCount: guildCount,
      hostingExpiresAt: hostingExpiresAt,
      isRunning: isRunning,
      canToggle: !_isTogglingBot,
      isTogglingThisBot: _togglingBotId == id,
      pulseController: pulseCtrl,
      onManage:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => AppEditPage(appName: name, id: int.tryParse(id) ?? 0),
            ),
          ).then((_) => _initRunningState()),
      onToggle: () => _toggleBot(botId: id, botName: name),
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

/// Formate une durée d'hébergement restante de façon compacte (2 unités max),
/// p.ex. « 136 mois · 9j ».
String _formatHostingCompact(int expiresAtMs) {
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
  if (days > 0) parts.add('$days${AppStrings.t('home_hosting_unit_day')}');
  if (hours > 0) parts.add('$hours${AppStrings.t('home_hosting_unit_hour')}');
  if (minutes > 0) {
    parts.add('$minutes${AppStrings.t('home_hosting_unit_minute')}');
  }
  if (parts.isEmpty) {
    parts.add('0${AppStrings.t('home_hosting_unit_minute')}');
  }
  return parts.take(2).join(' · ');
}

// ── En-tête d'accueil ─────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onRefresh,
    required this.onDocs,
    required this.onSettings,
    this.onCreate,
    this.showCreate = false,
  });

  final VoidCallback onRefresh;
  final VoidCallback onDocs;
  final VoidCallback onSettings;
  final VoidCallback? onCreate;
  final bool showCreate;

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
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  AppStrings.t('app_title'),
                  maxLines: 1,
                  softWrap: false,
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (showCreate && onCreate != null) ...[
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(AppStrings.t('home_create_app')),
          ),
          const SizedBox(width: 12),
        ],
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
/// Couleur d'identité déterministe par bot (dérivée du nom/ID).
Color _botColor(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.5, 0.66).toColor();
}

class _BrandIconSquare extends StatelessWidget {
  const _BrandIconSquare({
    required this.icon,
    this.size = 48,
    this.imageUrl,
    this.tint,
  });

  final IconData icon;
  final double size;
  final String? imageUrl;

  /// Couleur d'accent propre à l'élément (identité du bot). Null = neutre.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final tintColor = tint;

    Widget fallbackIcon() => Icon(
      icon,
      color: tintColor ?? scheme.onSurfaceVariant,
      size: size * 0.5,
    );

    // Avec une vraie photo de profil : bordure neutre discrète.
    // Sinon : carré teinté de la couleur d'identité du bot (repli).
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color:
            hasImage
                ? scheme.surfaceContainerHigh
                : (tintColor != null
                    ? tintColor.withValues(alpha: 0.18)
                    : scheme.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              hasImage
                  ? scheme.outlineVariant
                  : (tintColor != null
                      ? tintColor.withValues(alpha: 0.38)
                      : scheme.outlineVariant),
        ),
      ),
      child:
          hasImage
              ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                gaplessPlayback: true,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(child: fallbackIcon());
                },
                errorBuilder: (_, _, _) => Center(child: fallbackIcon()),
              )
              : fallbackIcon(),
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
  });

  final String name;
  final String? avatar;
  final int? guildCount;
  final int? hostingExpiresAt;
  final bool isRunning;
  final bool canToggle;
  final bool isTogglingThisBot;
  final AnimationController pulseController;
  final VoidCallback onManage;
  final VoidCallback onToggle;

  @override
  State<_BotCard> createState() => _BotCardState();
}

class _BotCardState extends State<_BotCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = widget.guildCount ?? 0;

    final Widget? serverChip =
        count > 0
            ? _InfoChip(
              icon: Icons.dns_rounded,
              value: count.toString(),
              label: AppStrings.t(
                count > 1
                    ? 'home_servers_noun_other'
                    : 'home_servers_noun_one',
              ),
            )
            : null;
    final Widget hostingChip =
        widget.hostingExpiresAt != null
            ? _InfoChip(
              icon: Icons.bolt_rounded,
              value: _formatHostingCompact(widget.hostingExpiresAt!),
            )
            : _InfoChip(
              icon: Icons.all_inclusive_rounded,
              value: AppStrings.t('home_hosting_unlimited'),
              badge: true,
            );

    // Bordure fine avec reflet plus clair vers le haut (dégradé 1px).
    final Color borderTop = (widget.isRunning ? kBrandPurpleSoft : Colors.white)
        .withValues(
          alpha: _hovered ? 0.50 : (widget.isRunning ? 0.30 : 0.14),
        );
    final Color borderBottom = Colors.white.withValues(
      alpha: _hovered ? 0.16 : 0.04,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [borderTop, borderBottom],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow:
              _hovered
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 28,
                      spreadRadius: -4,
                      offset: const Offset(0, 14),
                    ),
                  ]
                  : null,
        ),
        padding: const EdgeInsets.all(1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: _cardGradient(scheme, widget.isRunning, _hovered),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onManage,
              borderRadius: BorderRadius.circular(21),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _AvatarSquare(
                          seed: widget.name,
                          imageUrl: widget.avatar,
                          isRunning: widget.isRunning,
                          pulseController: widget.pulseController,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _displayStyle(16.5, color: scheme.onSurface),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _ActionPill(
                          isRunning: widget.isRunning,
                          loading: widget.isTogglingThisBot,
                          onTap: widget.canToggle ? widget.onToggle : null,
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (serverChip != null) ...[
                          serverChip,
                          const SizedBox(width: 8),
                        ],
                        Flexible(child: hostingChip),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Style de titre « display » (Syne) pour l'identité visuelle.
TextStyle _displayStyle(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w700,
}) {
  return GoogleFonts.syne(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: -0.2,
  );
}

/// Dégradé subtil derrière les cartes pour donner de la profondeur.
/// S'éclaircit au survol pour signaler l'interactivité de toute la carte.
Gradient _cardGradient(ColorScheme scheme, bool isRunning, bool hovered) {
  final top =
      isRunning
          ? Color.alphaBlend(
            kBrandPurple.withValues(alpha: 0.18),
            scheme.surfaceContainerHigh,
          )
          : scheme.surfaceContainerHigh;
  final bottom = scheme.surfaceContainer;
  final lift = hovered ? 0.06 : 0.0;
  Color raise(Color c) =>
      Color.alphaBlend(Colors.white.withValues(alpha: lift), c);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [raise(top), raise(bottom)],
  );
}

class _AvatarSquare extends StatelessWidget {
  const _AvatarSquare({
    required this.seed,
    required this.imageUrl,
    required this.isRunning,
    required this.pulseController,
  });

  final String seed;
  final String? imageUrl;
  final bool isRunning;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _BrandIconSquare(
            icon: Icons.smart_toy_rounded,
            size: 50,
            imageUrl: imageUrl,
            tint: _botColor(seed),
          ),
          // Pastille de statut, façon badge Discord (haut-droite de l'icône).
          Positioned(
            top: -4,
            right: -4,
            child: AnimatedBuilder(
              animation: pulseController,
              builder: (_, _) {
                final glow =
                    isRunning ? 0.4 + 0.6 * pulseController.value : 1.0;
                final dotColor =
                    isRunning ? kOnlineColor : scheme.onSurfaceVariant;
                return Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                  ),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      boxShadow:
                          isRunning
                              ? [
                                BoxShadow(
                                  color: kOnlineColor.withValues(
                                    alpha: 0.8 * glow,
                                  ),
                                  blurRadius: 9,
                                  spreadRadius: 1,
                                ),
                              ]
                              : null,
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
    final scheme = Theme.of(context).colorScheme;
    final fg = isRunning ? kDangerColor : scheme.onSurface;
    final borderColor =
        isRunning ? kDangerColor.withValues(alpha: 0.5) : scheme.outline;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  else
                    Icon(
                      isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 16,
                      color: fg,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    isRunning
                        ? AppStrings.t('home_stop')
                        : AppStrings.t('home_start_action'),
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Petite pastille d'information : la **donnée** dynamique est mise en avant
/// (accent pastel, chasse fixe), le **label** reste en gris lisible.
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.value,
    this.label,
    this.badge = false,
  });

  final IconData icon;

  /// Donnée dynamique (chiffre serveurs, durée, « Illimité »…) → accent.
  final String value;

  /// Label statique optionnel (« serveurs »…) → gris.
  final String? label;

  /// Pastille entièrement accentuée (ex. badge « Illimité »).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            badge
                ? kDataAccent.withValues(alpha: 0.12)
                : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              badge
                  ? kDataAccent.withValues(alpha: 0.35)
                  : scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: badge ? kDataAccent : kMetaText),
          const SizedBox(width: 5),
          Flexible(
            child: RichText(
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: kDataAccent,
                ),
                children: [
                  TextSpan(text: value),
                  if (label != null)
                    TextSpan(
                      text: ' $label',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: kMetaText,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
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
