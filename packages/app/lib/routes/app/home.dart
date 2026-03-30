import 'dart:async';
import 'dart:io';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/bot_logs.dart';
import 'package:bot_creator/routes/app/bot_stats.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:bot_creator/utils/bot_payload_builder.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/ad_reward_service.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:bot_creator/utils/ad_consent_service.dart';
import 'package:bot_creator/utils/subscription_service.dart';
import 'package:bot_creator/utils/runner_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:nyxx/nyxx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

/// Describes a secondary section accessible via quick-actions on mobile.
class QuickAccessSection {
  final int index;
  final IconData icon;
  final String labelKey;

  const QuickAccessSection({
    required this.index,
    required this.icon,
    required this.labelKey,
  });
}

class AppHomePage extends StatefulWidget {
  final NyxxRest client;
  final ValueChanged<int>? onNavigateToSection;
  final List<QuickAccessSection> secondarySections;
  const AppHomePage({
    super.key,
    required this.client,
    this.onNavigateToSection,
    this.secondarySections = const [],
  });

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage>
    with TickerProviderStateMixin {
  String _appName = "";
  NyxxRest? client; // Changez en nullable
  String avatar = "";
  bool _botLaunched = false;
  bool _isSyncingApp = false;
  void Function(Object)? _taskDataCallback;

  bool get _supportsForegroundTask => Platform.isAndroid || Platform.isIOS;

  Future<void> _requestPermissions() async {
    if (!_supportsForegroundTask) {
      return;
    }

    // Android 13+, you need to allow notification permission to display foreground service notification.
    //
    // iOS: If you need notification, ask for permission.
    try {
      final NotificationPermission notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      if (Platform.isAndroid) {
        if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      }
    } on MissingPluginException {
      // No-op on unsupported platforms.
    }
  }

  Future<void> _initService() async {
    if (!_supportsForegroundTask) {
      return;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (_supportsForegroundTask) {
      _taskDataCallback = (Object data) {
        consumeForegroundTaskDataForBotLogs(data);
        if (mounted) {
          setState(() {});
        }
      };
      try {
        FlutterForegroundTask.addTaskDataCallback(_taskDataCallback!);
      } on MissingPluginException {
        debugPrint('Foreground callback registration unavailable on platform');
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize service configuration.
      _initService();
    });
    _init();
  }

  @override
  void dispose() {
    final callback = _taskDataCallback;
    if (callback != null) {
      try {
        FlutterForegroundTask.removeTaskDataCallback(callback);
      } on MissingPluginException {
        debugPrint('Foreground callback removal unavailable on platform');
      }
    }
    super.dispose();
  }

  Future<List<ApplicationCommand>> getCommands() async {
    if (client == null) {
      throw Exception("Client is not initialized");
    }
    final commands = await client!.commands.list();
    return commands;
  }

  Future<void> _init() async {
    final botId = widget.client.user.id.toString();
    final app = await appManager.getApp(botId);
    var isRunning = false;
    final runnerClient = await RunnerSettings.createClient(
      getTimeout: const Duration(seconds: 30),
      postTimeout: const Duration(seconds: 90),
    );
    if (runnerClient != null) {
      try {
        final status = await runnerClient.getStatus();
        isRunning = status.isBotRunning(botId);
      } catch (_) {
        isRunning = false;
      }
    } else {
      if (_supportsForegroundTask) {
        try {
          final serviceRunning = await FlutterForegroundTask.isRunningService;
          if (serviceRunning) {
            final runningId =
                mobileRunningBotId ??
                await FlutterForegroundTask.getData<String>(
                  key: 'running_bot_id',
                );
            if (runningId != null && runningId.isNotEmpty) {
              isRunning = runningId == botId;
            } else {
              isRunning = serviceRunning;
            }
          } else {
            isRunning = false;
          }
        } on MissingPluginException {
          isRunning = false;
        }
      } else {
        isRunning = isDesktopBotRunning;
      }
    }

    await AppAnalytics.logScreenView(
      screenName: "AppHomePage",
      screenClass: "AppHomePage",
      parameters: {
        "app_name": app["name"],
        "app_id": botId,
        "is_running": isRunning ? "true" : "false",
      },
    );
    setState(() {
      _botLaunched = isRunning;
      _appName = app["name"];
      avatar = app["avatar"] ?? "";
    });

    unawaited(_syncAppFromRemote(showSnack: false));
  }

  Future<void> _syncAppFromRemote({required bool showSnack}) async {
    if (_isSyncingApp) {
      return;
    }

    _isSyncingApp = true;
    try {
      final user = await widget.client.user.get();
      final botId = user.id.toString();
      final app = await appManager.getApp(botId);
      final token = (app['token'] ?? '').toString().trim();
      if (token.isEmpty) {
        throw Exception('Token not found');
      }

      await appManager.createOrUpdateApp(user, token);

      try {
        final remoteCommands = await widget.client.commands.list(
          withLocalizations: true,
        );

        // Build an index of all local commands to reconcile temp IDs.
        final allLocal = await appManager.listAppCommands(botId);
        final reconciledLocalIds = <String>{};

        for (final command in remoteCommands) {
          final commandId = command.id.toString();
          var local = await appManager.getAppCommand(botId, commandId);

          // If no local match by Discord ID, find by name+type to reconcile
          // commands that were created offline with a temporary ID.
          if (local.isEmpty) {
            final commandType =
                command.type == ApplicationCommandType.user
                    ? 'user'
                    : command.type == ApplicationCommandType.message
                    ? 'message'
                    : 'chatinput';
            final match = allLocal.cast<Map<String, dynamic>?>().firstWhere((
              c,
            ) {
              final localId = (c!['id'] ?? '').toString();
              if (reconciledLocalIds.contains(localId)) return false;
              if (localId == commandId) return false;
              // Never reconcile legacy-only commands — they are local-only
              // and must not be absorbed into a Discord command.
              final localData = (c['data'] as Map?)?.cast<String, dynamic>();
              if (localData != null &&
                  localData['legacyModeEnabled'] == true &&
                  localData['legacyLocalOnly'] == true) {
                return false;
              }
              final localName = (c['name'] ?? '').toString();
              final localType =
                  (c['type'] ?? 'chatInput').toString().toLowerCase();
              return localName == command.name && localType == commandType;
            }, orElse: () => null);

            if (match != null) {
              final oldId = (match['id'] ?? '').toString();
              local = match;
              reconciledLocalIds.add(oldId);
              // Remove the orphaned file with the temp ID.
              await appManager.deleteAppCommand(botId, oldId);
            }
          }

          final merged = <String, dynamic>{
            ...local,
            'id': commandId,
            'name': command.name,
            if (command.description != null) 'description': command.description,
          };
          await appManager.saveAppCommand(botId, commandId, merged);
        }
      } catch (_) {
        // Keep profile sync resilient even if remote command fetch fails.
      }

      final refreshed = await appManager.getApp(botId);
      if (mounted) {
        setState(() {
          _appName = (refreshed['name'] ?? _appName).toString();
          avatar = (refreshed['avatar'] ?? avatar).toString();
        });
      }

      if (showSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('bot_home_sync_success'))),
        );
      }
    } catch (e) {
      if (showSnack && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      _isSyncingApp = false;
    }
  }

  Future<void> _maybeOfferRewardedAd() async {
    try {
      if (!_supportsForegroundTask || !mounted) {
        return;
      }

      if (SubscriptionService.isSubscribed) {
        return;
      }

      if (!AdRewardService.hasReadyRewardedAd) {
        return;
      }

      final shouldOffer = await AdRewardService.shouldOfferRewardedAd().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if (!shouldOffer) {
        return;
      }

      final consentGranted = await _ensureAdsConsent().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
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
    } catch (error) {
      appendBotDebugLog('Rewarded ad flow skipped due to error: $error');
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        title: Text(_appName),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentMaxWidth = constraints.maxWidth >= 900 ? 560.0 : 460.0;
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // let's show the app icon
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.center,
                        child:
                            avatar.isNotEmpty
                                ? CircleAvatar(
                                  radius: 40,
                                  backgroundImage: NetworkImage(avatar),
                                )
                                : const Icon(Icons.account_circle, size: 80),
                      ),
                      const SizedBox(height: 20),
                      // App Name
                      Text(
                        _appName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _botLaunched ? Colors.red : Colors.green,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () async {
                          try {
                            final app = await appManager.getApp(
                              widget.client.user.id.toString(),
                            );
                            final token = app["token"]?.toString();
                            if (token == null || token.trim().isEmpty) {
                              throw Exception("Token not found");
                            }

                            final botId = widget.client.user.id.toString();

                            if (!_botLaunched) {
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
                                              AppStrings.t(
                                                'bot_home_token_invalid_title',
                                              ),
                                            ),
                                            content: Text(
                                              AppStrings.t(
                                                'bot_home_token_invalid_content',
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.of(
                                                      ctx,
                                                    ).pop(false),
                                                child: Text(
                                                  AppStrings.t('cancel'),
                                                ),
                                              ),
                                              FilledButton(
                                                onPressed:
                                                    () => Navigator.of(
                                                      ctx,
                                                    ).pop(true),
                                                child: Text(
                                                  AppStrings.t(
                                                    'bot_home_start',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    ) ??
                                    false;
                                if (!proceed || !mounted) return;
                              }
                              await _maybeOfferRewardedAd();
                            }

                            // ── Runner API (API only) ────────────────────────────
                            final remoteClient =
                                await RunnerSettings.createClient(
                                  getTimeout: const Duration(seconds: 30),
                                  postTimeout: const Duration(seconds: 90),
                                );
                            if (remoteClient != null) {
                              if (_botLaunched) {
                                appendBotLog(
                                  'Bot stop requested',
                                  botId: botId,
                                );
                                await remoteClient.stopBot(botId);
                                endBotLogSession(botId: botId);
                                setBotRuntimeActive(false);
                                if (mounted) {
                                  setState(() => _botLaunched = false);
                                }
                              } else {
                                startBotLogSession(botId: botId);
                                clearBotBaselineRss();
                                appendBotLog(
                                  'Bot start requested',
                                  botId: botId,
                                );
                                final payload = await buildBotPayload(botId);
                                await remoteClient.syncBot(
                                  botId,
                                  _appName,
                                  payload,
                                );
                                await remoteClient.startBot(
                                  botId,
                                  botName: _appName,
                                );
                                setBotRuntimeActive(true);
                                if (mounted) {
                                  setState(() => _botLaunched = true);
                                }
                              }
                              return;
                            }

                            // ── Local engine ─────────────────────────────────
                            if (!_botLaunched) {
                              clearBotBaselineRss();
                              startBotLogSession(botId: botId);
                              appendBotLog('Bot start requested', botId: botId);
                            }

                            if (_supportsForegroundTask) {
                              if (_botLaunched) {
                                appendBotLog(
                                  'Bot stop requested',
                                  botId: botId,
                                );
                                await stopMobileBotSession(botId: botId);
                                endBotLogSession(botId: botId);
                                setBotRuntimeActive(
                                  isDesktopBotRunning ||
                                      mobileRunningBotIds.isNotEmpty,
                                );
                                if (mounted) {
                                  setState(() {
                                    _botLaunched = false;
                                  });
                                }
                                return;
                              }

                              await _requestPermissions();
                              await _initService();

                              await startMobileBotSession(
                                botId: botId,
                                token: token,
                              );
                              developer.log(
                                'Token saved, starting foreground service',
                                name: 'AppHomePage',
                              );

                              final running =
                                  await FlutterForegroundTask.isRunningService;
                              if (!running) {
                                throw Exception(
                                  AppStrings.t('bot_home_service_not_started'),
                                );
                              }
                            } else {
                              if (_botLaunched) {
                                appendBotLog(
                                  AppStrings.t('bot_home_log_desktop_stop'),
                                  botId: botId,
                                );
                                await stopDesktopBot();
                                endBotLogSession(botId: botId);
                                setBotRuntimeActive(false);
                                clearBotBaselineRss();
                                if (mounted) {
                                  setState(() {
                                    _botLaunched = false;
                                  });
                                }
                                return;
                              }

                              await startDesktopBot(token);
                            }

                            if (mounted) {
                              setState(() {
                                _botLaunched = true;
                              });
                            }
                          } catch (e) {
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppStrings.tr(
                                    'bot_home_start_error',
                                    params: {'error': e.toString()},
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_botLaunched ? Icons.stop : Icons.play_arrow),
                            const SizedBox(width: 8),
                            Text(
                              _botLaunched
                                  ? AppStrings.t('bot_home_stop')
                                  : AppStrings.t('bot_home_start'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                        height: 40,
                        thickness: 2,
                        indent: 20,
                        endIndent: 20,
                      ),
                      // ── Quick access to secondary sections (mobile) ──
                      if (widget.secondarySections.isNotEmpty &&
                          widget.onNavigateToSection != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              for (
                                var i = 0;
                                i < widget.secondarySections.length;
                                i++
                              ) ...[
                                if (i > 0) const SizedBox(width: 10),
                                Expanded(
                                  child: _QuickAccessChip(
                                    icon: widget.secondarySections[i].icon,
                                    label: AppStrings.t(
                                      widget.secondarySections[i].labelKey,
                                    ),
                                    onTap:
                                        () => widget.onNavigateToSection!(
                                          widget.secondarySections[i].index,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      // Logs Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () {
                          final botId = widget.client.user.id.toString();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BotLogsPage(botId: botId),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long),
                            const SizedBox(width: 8),
                            Text(AppStrings.t('bot_home_view_logs')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () {
                          final botId = widget.client.user.id.toString();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BotStatsPage(botId: botId),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monitor_heart_outlined),
                            const SizedBox(width: 8),
                            Text(AppStrings.t('bot_home_view_stats')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed:
                            _isSyncingApp
                                ? null
                                : () async {
                                  await _syncAppFromRemote(showSnack: true);
                                },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _isSyncingApp
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.sync),
                            const SizedBox(width: 8),
                            Text(AppStrings.t('bot_home_sync')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Invite Bot Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () async {
                          final botId = widget.client.user.id.toString();
                          final inviteUrl = Uri.parse(
                            'https://discord.com/api/oauth2/authorize?client_id=$botId&scope=bot&permissions=8',
                          );

                          if (await canLaunchUrl(inviteUrl)) {
                            await launchUrl(inviteUrl);
                            await AppAnalytics.logEvent(
                              name: "invite_bot",
                              parameters: {"bot_id": botId},
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppStrings.t('bot_home_invite_error'),
                                ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_add),
                            const SizedBox(width: 8),
                            Text(AppStrings.t('bot_home_invite')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () async {
                          final dialog = AlertDialog.adaptive(
                            title: Text(AppStrings.t('bot_home_delete')),
                            content: Text(
                              AppStrings.t('bot_home_delete_confirm'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text(AppStrings.t('cancel')),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await appManager.deleteApp(
                                    widget.client.user.id.toString(),
                                  );
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();
                                },
                                child: Text(AppStrings.t('delete')),
                              ),
                            ],
                          );
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return dialog;
                            },
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete),
                            const SizedBox(width: 8),
                            Text(AppStrings.t('bot_home_delete')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickAccessChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: colorScheme.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
