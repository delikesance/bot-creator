import 'package:bot_creator/routes/app/command.create.dart';
import 'package:bot_creator/routes/app/template_gallery.dart';
import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/ads_placement_policy.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/widgets/native_ad_slot.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class AppCommandsPage extends StatefulWidget {
  final NyxxRest? client;
  final String botId;
  const AppCommandsPage({super.key, required this.botId, this.client});

  @override
  State<AppCommandsPage> createState() => _AppCommandsPageState();
}

class _AppCommandsPageState extends State<AppCommandsPage>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // Log the opening of the commands page
    AppAnalytics.logScreenView(
      screenName: "AppCommandsPage",
      screenClass: "AppCommandsPage",
      parameters: {"app_id": widget.botId},
    );
  }

  Future<List<Map<String, dynamic>>> _getCommands() async {
    return appManager.listAppCommands(widget.botId);
  }

  Snowflake? _toSnowflake(String raw) {
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      return null;
    }
    return Snowflake(parsed);
  }

  Widget _buildCommandCard(Map<String, dynamic> command) {
    final commandId = (command['id'] ?? '').toString();
    final snowflake = _toSnowflake(commandId);
    final templateOrigin = command['templateOrigin'] as Map<String, dynamic>?;
    final templateId = (templateOrigin?['templateId'] ?? '').toString();

    return Card(
      child: ListTile(
        trailing: const Icon(Icons.arrow_forward_ios_outlined),
        title: Row(
          children: [
            Expanded(
              child: Text(
                (command['name'] ?? 'unknown').toString(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (templateId.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      templateId,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(
          (command['description'] ?? '').toString(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
        ),
        onTap: () async {
          if (snowflake == null) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid local command id.')),
            );
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CommandCreatePage(
                    client: widget.client,
                    botId: widget.botId,
                    id: snowflake,
                  ),
            ),
          );
          if (!mounted) {
            return;
          }
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        title: Text(AppStrings.t('commands_title')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: AppStrings.t('template_gallery_title'),
            onPressed: () async {
              final applied = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => TemplateGalleryPage(
                        botId: widget.botId,
                        client: widget.client,
                      ),
                ),
              );
              if (applied == true && mounted) {
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentMaxWidth = constraints.maxWidth >= 900 ? 760.0 : 640.0;
          return FutureBuilder(
            future: _getCommands(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    strokeAlign: 0.5,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    AppStrings.tr(
                      'commands_error',
                      params: {'error': snapshot.error.toString()},
                    ),
                  ),
                );
              }

              final commands = snapshot.data ?? const <Map<String, dynamic>>[];
              final adsEnabled = AdsPlacementPolicy.isPlacementEnabled(
                NativeAdPlacement.commandsList,
              );
              if (commands.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppStrings.t('commands_empty')),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () async {
                          final applied = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => TemplateGalleryPage(
                                    botId: widget.botId,
                                    client: widget.client,
                                  ),
                            ),
                          );
                          if (applied == true && mounted) {
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(AppStrings.t('template_gallery_title')),
                      ),
                    ],
                  ),
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    itemCount:
                        commands.length +
                        (adsEnabled
                            ? AdsPlacementPolicy.adCountForContentLength(
                              commands.length,
                            )
                            : 0),
                    itemBuilder: (context, index) {
                      if (adsEnabled &&
                          AdsPlacementPolicy.isAdSlotIndex(index)) {
                        return const NativeAdSlot(
                          placement: NativeAdPlacement.commandsList,
                          height: 110,
                        );
                      }

                      final command =
                          adsEnabled
                              ? commands[AdsPlacementPolicy.contentIndexForMixedIndex(
                                index,
                              )]
                              : commands[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildCommandCard(command),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CommandCreatePage(
                    client: widget.client,
                    botId: widget.botId,
                  ),
            ),
          );
          if (!mounted) {
            return;
          }
          setState(() {});
        },
        tooltip: AppStrings.t('commands_create_button'),
        label: Text(AppStrings.t('commands_create_button')),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
