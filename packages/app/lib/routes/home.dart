import 'dart:async';
import 'dart:io';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app.dart';
import 'package:bot_creator/routes/app/bot_logs.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:bot_creator/utils/bot_payload_builder.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/ad_reward_service.dart';
import 'package:bot_creator/utils/ads_placement_policy.dart';
import 'package:bot_creator/utils/ad_consent_service.dart';
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

  /// Vrai pendant qu'un démarrage/arrêt est en cours.
  bool _isTogglingBot = false;

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
    final runnerClient = await RunnerSettings.createClient(
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
      if (isDesktopBotRunning && desktopRunningBotId != null) {
        runningIds.add(desktopRunningBotId!);
      }
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
    setState(() => _isTogglingBot = true);

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
          await stopDesktopBot();
          setBotRuntimeActive(false);
          clearBotBaselineRss();
          if (mounted) {
            setState(() {
              _runningBotIds = <String>{};
            });
          }
        } else {
          await startDesktopBot(token);
          if (mounted) {
            setState(() {
              _runningBotIds = <String>{botId};
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
      if (mounted) setState(() => _isTogglingBot = false);
    }
  }

  Future<void> _maybeOfferRewardedAd() async {
    if (!_supportsForegroundTask || !mounted) {
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        final double horizontalPadding;
        final double cardHeight;

        // Responsive grid based on screen width
        if (width < 420) {
          // Small phone - single column
          crossAxisCount = 1;
          horizontalPadding = 12.0;
          cardHeight = 280.0;
        } else if (width < 600) {
          // Mobile - 2 columns
          crossAxisCount = 2;
          horizontalPadding = 12.0;
          cardHeight = 295.0;
        } else if (width >= 1500) {
          // Extra large desktop - 5 columns
          crossAxisCount = 5;
          horizontalPadding = 24.0;
          cardHeight = 282.0;
        } else if (width >= 1200) {
          // Large desktop - 4 columns
          crossAxisCount = 4;
          horizontalPadding = 24.0;
          cardHeight = 285.0;
        } else if (width >= 900) {
          // Tablet - 3 columns
          crossAxisCount = 3;
          horizontalPadding = 20.0;
          cardHeight = 276.0;
        } else if (width >= 760) {
          // Medium tablet - 3 columns
          crossAxisCount = 3;
          horizontalPadding = 16.0;
          cardHeight = 272.0;
        } else {
          // Small tablet - 2 columns
          crossAxisCount = 2;
          horizontalPadding = 16.0;
          cardHeight = 274.0;
        }

        final cardWidth =
            (width - (horizontalPadding * 2) - ((crossAxisCount - 1) * 12)) /
            crossAxisCount;
        final childAspectRatio = cardWidth / cardHeight;

        return Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: StreamBuilder<List<dynamic>>(
            stream: appManager.getAppStream(),
            initialData: const <dynamic>[],
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                developer.log(
                  'Error loading data: ${snapshot.error}',
                  name: 'HomePage',
                );
                return Center(child: Text(AppStrings.t('app_loading_error')));
              }

              final apps = snapshot.data;
              if (apps == null || apps.isEmpty) {
                return const _EmptyStateWithSupport();
              }

              final namesById = <String, String>{
                for (final app in apps)
                  (app['id']?.toString() ?? ''):
                      (app['name']?.toString() ??
                          AppStrings.t('home_unknown_app')),
              };
              final activeSessionIds = _runningBotIds.toList(growable: false)
                ..sort();

              return Column(
                children: [
                  if (_supportsForegroundTask && activeSessionIds.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
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
                    ),
                  if (AdsPlacementPolicy.isPlacementEnabled(
                        NativeAdPlacement.homeBots,
                      ) &&
                      apps.length >= AdsPlacementPolicy.listInterval)
                    const NativeAdSlot(
                      placement: NativeAdPlacement.homeBots,
                      height: 118,
                      margin: EdgeInsets.only(bottom: 12),
                    ),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        final name =
                            app['name']?.toString() ??
                            AppStrings.t('home_unknown_app');
                        final id = app['id']?.toString() ?? '';
                        final avatar = app['avatar']?.toString();
                        final guildCount = app['guild_count'] as int?;
                        final isRunning = _runningBotIds.contains(id);
                        const runtimeToggleAllowed = true;
                        // En mode runner, plusieurs bots peuvent tourner en parallèle.
                        final canToggle =
                            runtimeToggleAllowed &&
                            ((_runnerModeEnabled || _supportsForegroundTask)
                                ? !_isTogglingBot
                                : (!_isTogglingBot &&
                                    (_runningBotIds.isEmpty || isRunning)));

                        final pulseCtrl = _getOrCreatePulseController(id);

                        return _BotCard(
                          name: name,
                          id: id,
                          avatar: avatar,
                          guildCount: guildCount,
                          compact: width >= 760,
                          isRunning: isRunning,
                          canToggle: canToggle,
                          isTogglingThisBot: _isTogglingBot && isRunning,
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
                                  ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BotLogsPage(botId: id),
                                    ),
                                  )
                                  : null,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ── Widget carte ─────────────────────────────────────────────────────────────

class _BotCard extends StatelessWidget {
  const _BotCard({
    required this.name,
    required this.id,
    required this.avatar,
    required this.guildCount,
    required this.compact,
    required this.isRunning,
    required this.canToggle,
    required this.isTogglingThisBot,
    required this.pulseController,
    required this.onManage,
    required this.onToggle,
    required this.onLogs,
  });

  final String name;
  final String id;
  final String? avatar;
  final int? guildCount;
  final bool compact;
  final bool isRunning;
  final bool canToggle;
  final bool isTogglingThisBot;
  final AnimationController pulseController;
  final VoidCallback onManage;
  final VoidCallback onToggle;
  final VoidCallback? onLogs;

  String _serverCountLabel() {
    final count = guildCount ?? 0;
    final key = count > 1 ? 'home_server_count_other' : 'home_server_count_one';
    return AppStrings.tr(key, params: {'count': count.toString()});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarRadius = compact ? 30.0 : 36.0;
    final avatarFallbackSize = compact ? 60.0 : 72.0;
    final contentPadding = compact ? 9.0 : 12.0;
    final titleFontSize = compact ? 13.5 : 15.0;
    final statusFontSize = compact ? 9.5 : 11.0;
    final serverFontSize = compact ? 9.5 : 11.0;
    final buttonVerticalPadding = compact ? 6.0 : 8.0;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side:
            isRunning
                ? BorderSide(color: Colors.green.shade400, width: 1.5)
                : BorderSide.none,
      ),
      elevation: isRunning ? 6 : 4,
      child: Padding(
        padding: EdgeInsets.all(contentPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Avatar ──────────────────────────────────────────────────────
            avatar != null && avatar!.isNotEmpty
                ? CircleAvatar(
                  radius: avatarRadius,
                  backgroundImage: NetworkImage(avatar!),
                )
                : Icon(Icons.account_circle, size: avatarFallbackSize),

            SizedBox(height: compact ? 6 : 8),

            // ── Nom ─────────────────────────────────────────────────────────
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w600,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            SizedBox(height: compact ? 3 : 4),

            // ── Statut avec animation pulse ──────────────────────────────────
            AnimatedBuilder(
              animation: pulseController,
              builder: (_, _) {
                final opacity =
                    isRunning ? 0.4 + 0.6 * pulseController.value : 1.0;
                return Opacity(
                  opacity: opacity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRunning ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isRunning
                            ? AppStrings.t('home_status_online')
                            : AppStrings.t('home_status_offline'),
                        style: TextStyle(
                          fontSize: statusFontSize,
                          fontWeight: FontWeight.w500,
                          color: isRunning ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Compteur de serveurs ─────────────────────────────────────────
            if (guildCount != null && guildCount! > 0) ...[
              SizedBox(height: compact ? 3 : 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups,
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _serverCountLabel(),
                    style: TextStyle(
                      fontSize: serverFontSize,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],

            const Spacer(),

            // ── Bouton Lancer / Arrêter ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canToggle ? onToggle : null,
                icon:
                    isTogglingThisBot
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Icon(
                          isRunning
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 16,
                        ),
                label: Text(
                  isRunning
                      ? AppStrings.t('home_stop')
                      : AppStrings.t('home_start'),
                ),
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: isRunning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.white70,
                  padding: EdgeInsets.symmetric(
                    vertical: buttonVerticalPadding,
                  ),
                ),
              ),
            ),

            SizedBox(height: compact ? 5 : 6),

            // ── Ligne inférieure : Gérer + Logs ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.tune, size: 14),
                    label: Text(AppStrings.t('home_manage')),
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: buttonVerticalPadding,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: compact ? 5 : 6),
                IconButton.filled(
                  onPressed: onLogs,
                  icon: const Icon(Icons.article_outlined, size: 18),
                  tooltip: AppStrings.t('home_logs_tooltip'),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        onLogs != null
                            ? Colors.deepPurple.shade100
                            : Colors.grey.shade200,
                    foregroundColor:
                        onLogs != null ? Colors.deepPurple : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
      ),
    );
  }
}
