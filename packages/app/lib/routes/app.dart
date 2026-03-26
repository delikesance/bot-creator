import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/command_dashboard.dart';
import 'package:bot_creator/routes/app/commands.list.dart';
import 'package:bot_creator/routes/app/emojis.page.dart';
import 'package:bot_creator/routes/app/global.variables.dart';
import 'package:bot_creator/routes/app/home.dart';
import 'package:bot_creator/routes/app/settings.dart';
import 'package:bot_creator/routes/app/workflows.page.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/responsive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class AppEditPage extends StatefulWidget {
  final String appName;
  final int id;
  const AppEditPage({super.key, required this.appName, required this.id});

  @override
  State<AppEditPage> createState() => _AppEditPageState();
}

class _AppEditPageState extends State<AppEditPage>
    with TickerProviderStateMixin {
  NyxxRest? client;
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _degradedReason;

  bool get _isDesktopPlatform {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => true,
      TargetPlatform.linux => true,
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<List<ApplicationCommand>> getCommands() async {
    if (client == null) {
      throw Exception("Client is not initialized");
    }
    final commands = await client!.commands.list();
    return commands;
  }

  Future<void> _init() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        client = null;
        _degradedReason = null;
      });
    }
    await AppAnalytics.logScreenView(
      screenName: "AppEditPage",
      screenClass: "AppEditPage",
      parameters: {"app_name": widget.appName, "app_id": widget.id.toString()},
    );
    try {
      final app = await appManager.getApp(widget.id.toString());
      final token = (app["token"] ?? '').toString().trim();

      if (token.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _degradedReason = 'Token missing. Local edit mode enabled.';
          _isLoading = false;
        });
        return;
      }

      try {
        client = await Nyxx.connectRest(token);
      } catch (_) {
        client = null;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        if (client == null) {
          _degradedReason =
              'Token invalid or network unavailable. Local edit mode enabled.';
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _degradedReason = 'Unable to load bot data. Local edit mode enabled.';
        _isLoading = false;
      });
    }
  }

  String get _botId => widget.id.toString();

  List<_AppPageEntry> _buildEntries(bool isSmallPhone) {
    if (client == null) {
      return [
        _AppPageEntry(
          icon: Icons.warning_amber_rounded,
          label: 'Recovery',
          compactLabel: 'Recovery',
          page: _OfflineRecoveryPage(
            reason: _degradedReason,
            onRetry: _init,
            onDeleteLocal: () async {
              await appManager.deleteApp(_botId);
              if (!mounted) {
                return;
              }
              Navigator.of(context).pop();
            },
          ),
        ),
        _AppPageEntry(
          icon: Icons.vpn_key_outlined,
          label: AppStrings.t('settings_tab'),
          compactLabel: AppStrings.t('settings_tab'),
          page: _OfflineTokenPage(botId: _botId, onTokenSaved: _init),
        ),
        _AppPageEntry(
          icon: Icons.add_circle,
          label: AppStrings.t('commands_tab'),
          compactLabel: AppStrings.t('commands_tab_short'),
          page: AppCommandsPage(botId: _botId),
        ),
        _AppPageEntry(
          icon: Icons.key,
          label: AppStrings.t('globals_tab'),
          compactLabel: AppStrings.t('globals_tab_short'),
          page: GlobalVariablesPage(botId: _botId),
        ),
        _AppPageEntry(
          icon: Icons.account_tree,
          label: AppStrings.t('workflows_tab'),
          compactLabel: AppStrings.t('workflows_tab_short'),
          page: WorkflowsPage(botId: _botId),
        ),
      ];
    }

    return [
      _AppPageEntry(
        icon: Icons.home,
        label: AppStrings.t('home_tab'),
        compactLabel: AppStrings.t('home_tab'),
        page: AppHomePage(client: client!),
      ),
      _AppPageEntry(
        icon: Icons.add_circle,
        label: AppStrings.t('commands_tab'),
        compactLabel: AppStrings.t('commands_tab_short'),
        page: AppCommandsPage(client: client!, botId: _botId),
      ),
      _AppPageEntry(
        icon: Icons.key,
        label: AppStrings.t('globals_tab'),
        compactLabel: AppStrings.t('globals_tab_short'),
        page: GlobalVariablesPage(botId: _botId),
      ),
      _AppPageEntry(
        icon: Icons.account_tree,
        label: AppStrings.t('workflows_tab'),
        compactLabel: AppStrings.t('workflows_tab_short'),
        page: WorkflowsPage(botId: _botId),
      ),
      _AppPageEntry(
        icon: Icons.emoji_emotions_outlined,
        label: AppStrings.t('emojis_tab'),
        compactLabel: AppStrings.t('emojis_tab_short'),
        page: EmojisPage(botId: _botId),
        mobileSecondary: true,
      ),
      _AppPageEntry(
        icon: Icons.bar_chart,
        label: AppStrings.t('dashboard_title'),
        compactLabel: AppStrings.t('dashboard_title'),
        page: CommandDashboardPage(botId: _botId),
        mobileSecondary: true,
      ),
      _AppPageEntry(
        icon: Icons.settings,
        label: AppStrings.t('settings_tab'),
        compactLabel: AppStrings.t('settings_tab'),
        page: AppSettingsPage(client: client!),
        mobileSecondary: true,
      ),
    ];
  }

  Widget _buildDesktopSidebar(
    BuildContext context,
    ColorScheme colorScheme,
    List<_AppNavItem> navItems,
  ) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  widget.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(navItems.length, (index) {
                final item = navItems[index];
                final selected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color:
                            selected
                                ? colorScheme.primaryContainer
                                : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color:
                                selected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight:
                                    selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                color:
                                    selected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = ResponsiveHelper.isMobile(context);
    final isSmallPhone = ResponsiveHelper.isSmallPhone(context);
    final useDesktopSidebar = _isDesktopPlatform;
    final entries = _buildEntries(isSmallPhone);
    final navItems =
        entries
            .map(
              (entry) => _AppNavItem(
                icon: entry.icon,
                label: entry.label,
                compactLabel: entry.compactLabel,
              ),
            )
            .toList();
    final pages = entries.map((entry) => entry.page).toList();

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (pages.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeIndex =
        _selectedIndex < pages.length ? _selectedIndex : pages.length - 1;

    if (useDesktopSidebar) {
      return Scaffold(
        body: Row(
          children: [
            _buildDesktopSidebar(context, colorScheme, navItems),
            Expanded(child: pages[activeIndex]),
          ],
        ),
      );
    }

    // Mobile: split into core (bottom nav) and secondary ("More" sheet) entries
    final coreEntries = <int>[];
    final secondaryEntries = <int>[];
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].mobileSecondary) {
        secondaryEntries.add(i);
      } else {
        coreEntries.add(i);
      }
    }

    final hasSecondary = secondaryEntries.isNotEmpty;
    final moreSelected =
        hasSecondary && secondaryEntries.contains(activeIndex);

    // Bottom nav index mapping
    int bottomIndex;
    if (moreSelected) {
      bottomIndex = coreEntries.length; // "More" tab index
    } else {
      bottomIndex = coreEntries.indexOf(activeIndex);
      if (bottomIndex < 0) bottomIndex = 0;
    }

    final bottomItems = <BottomNavigationBarItem>[
      ...coreEntries.map((i) {
        final item = navItems[i];
        return BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: isSmallPhone ? item.compactLabel : item.label,
          backgroundColor: colorScheme.surface,
        );
      }),
      if (hasSecondary)
        BottomNavigationBarItem(
          icon: const Icon(Icons.more_horiz),
          label: AppStrings.t('more_tab'),
          backgroundColor: colorScheme.surface,
        ),
    ];

    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        type:
            isSmallPhone
                ? BottomNavigationBarType.shifting
                : BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        showUnselectedLabels: !isMobile,
        currentIndex: bottomIndex,
        onTap: (index) {
          if (hasSecondary && index == coreEntries.length) {
            // "More" tab tapped — show bottom sheet
            _showMoreSheet(context, entries, secondaryEntries);
          } else {
            setState(() {
              _selectedIndex = coreEntries[index];
            });
          }
        },
        items: bottomItems,
      ),
      body: pages[activeIndex],
    );
  }

  void _showMoreSheet(
    BuildContext context,
    List<_AppPageEntry> entries,
    List<int> secondaryIndices,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final i in secondaryIndices)
                ListTile(
                  leading: Icon(entries[i].icon),
                  title: Text(entries[i].label),
                  selected: _selectedIndex == i,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _selectedIndex = i;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AppNavItem {
  final IconData icon;
  final String label;
  final String compactLabel;

  const _AppNavItem({
    required this.icon,
    required this.label,
    required this.compactLabel,
  });
}

class _AppPageEntry {
  final IconData icon;
  final String label;
  final String compactLabel;
  final Widget page;
  final bool mobileSecondary;

  const _AppPageEntry({
    required this.icon,
    required this.label,
    required this.compactLabel,
    required this.page,
    this.mobileSecondary = false,
  });
}

class _OfflineTokenPage extends StatefulWidget {
  final String botId;
  final Future<void> Function() onTokenSaved;

  const _OfflineTokenPage({required this.botId, required this.onTokenSaved});

  @override
  State<_OfflineTokenPage> createState() => _OfflineTokenPageState();
}

class _OfflineTokenPageState extends State<_OfflineTokenPage> {
  final _tokenController = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newToken = _tokenController.text.trim();
    if (newToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('bot_settings_token_required'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final discordUser = await getDiscordUser(newToken);

      // ── Bot ID mismatch check ─────────────────────────────────────────────
      final newBotId = discordUser.id.toString();
      if (newBotId != widget.botId) {
        if (!mounted) return;
        final proceed =
            await showDialog<bool>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: Text(
                      AppStrings.t('bot_settings_token_mismatch_title'),
                    ),
                    content: Text(
                      AppStrings.tr(
                        'bot_settings_token_mismatch_content',
                        params: {'oldId': widget.botId, 'newId': newBotId},
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(AppStrings.t('cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(
                          AppStrings.t('bot_settings_token_mismatch_confirm'),
                        ),
                      ),
                    ],
                  ),
            ) ??
            false;
        if (!proceed || !mounted) return;
      }

      final existingData = Map<String, dynamic>.from(
        await appManager.getApp(widget.botId),
      );
      final intents = Map<String, bool>.from(
        (existingData['intents'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v == true),
            ) ??
            const <String, bool>{},
      );
      await appManager.createOrUpdateApp(
        discordUser,
        newToken,
        intents: intents,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('bot_settings_token_saved'))),
      );
      await widget.onTokenSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('bot_settings_token_title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.vpn_key_outlined,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.t('bot_offline_token_desc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _tokenController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('bot_settings_update_token'),
                    hintText: AppStrings.t('bot_settings_token_hint'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon:
                      _saving
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save_outlined),
                  label: Text(AppStrings.t('bot_settings_save_token_only_btn')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineRecoveryPage extends StatelessWidget {
  final String? reason;
  final Future<void> Function() onRetry;
  final Future<void> Function() onDeleteLocal;

  const _OfflineRecoveryPage({
    required this.reason,
    required this.onRetry,
    required this.onDeleteLocal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery mode')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(reason ?? 'Discord connection unavailable.'),
            const SizedBox(height: 12),
            const Text(
              'Offline features available: commands, globals, workflows.',
            ),
            const Text(
              'Unavailable while offline: start bot, profile (username/avatar).',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Discord connection'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onDeleteLocal,
              icon: const Icon(Icons.delete),
              label: const Text('Delete bot locally'),
            ),
          ],
        ),
      ),
    );
  }
}
