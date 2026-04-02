import 'dart:math';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator_shared/bot/bot_template.dart';
import 'package:bot_creator_shared/bot/builtin_templates.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

/// Const icon mapping so Flutter's icon tree-shaker can resolve them
/// statically (dynamic `IconData(codePoint)` breaks AOT builds).
const Map<String, IconData> _templateIcons = {
  'welcome': Icons.waving_hand,
  'moderation': Icons.shield,
  'utility': Icons.build,
  'fun': Icons.casino,
};

/// Gallery page that displays built-in bot templates and lets the user apply
/// them to the current bot.
class TemplateGalleryPage extends StatelessWidget {
  final String botId;
  final NyxxRest? client;

  const TemplateGalleryPage({super.key, required this.botId, this.client});

  @override
  Widget build(BuildContext context) {
    AppAnalytics.logScreenView(
      screenName: 'TemplateGalleryPage',
      screenClass: 'TemplateGalleryPage',
    );

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('template_gallery_title'))),
      body: SafeArea(
        child:
            builtInTemplates.isEmpty
                ? Center(child: Text(AppStrings.t('template_gallery_empty')))
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        AppStrings.t('template_gallery_subtitle'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ...builtInTemplates.map(
                      (template) => _TemplateCard(
                        template: template,
                        botId: botId,
                        client: client,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final BotTemplate template;
  final String botId;
  final NyxxRest? client;

  const _TemplateCard({
    required this.template,
    required this.botId,
    this.client,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _applying = false;

  Future<void> _applyTemplate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppStrings.t(widget.template.nameKey)),
            content: Text(
              AppStrings.tr(
                'template_gallery_apply_success',
                params: {
                  'count': widget.template.commands.length.toString(),
                  'wCount': widget.template.workflows.length.toString(),
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppStrings.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(AppStrings.t('template_gallery_apply')),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _applying = true);

    try {
      final existingCommands = await appManager.listAppCommands(widget.botId);
      final existingNames =
          existingCommands
              .map((c) => (c['name'] ?? '').toString().toLowerCase())
              .toSet();

      final skipped = <String>[];
      var addedCommands = 0;
      final client = widget.client;

      for (final cmd in widget.template.commands) {
        if (existingNames.contains(cmd.name.toLowerCase())) {
          skipped.add(cmd.name);
          continue;
        }

        final commandType = (cmd.data['commandType'] ?? 'chatInput').toString();
        final templateOrigin = <String, dynamic>{
          'templateId': widget.template.id,
          'appliedAt': DateTime.now().toIso8601String(),
        };
        final commandData = Map<String, dynamic>.from(cmd.data);

        if (client != null) {
          // Register on Discord and save with real ID
          try {
            final ApplicationCommandBuilder commandBuilder;
            if (commandType == 'user') {
              commandBuilder = ApplicationCommandBuilder.user(name: cmd.name);
            } else if (commandType == 'message') {
              commandBuilder = ApplicationCommandBuilder.message(
                name: cmd.name,
              );
            } else {
              commandBuilder = ApplicationCommandBuilder.chatInput(
                name: cmd.name,
                description: cmd.description,
                options: [],
              );
            }
            await createCommand(client, commandBuilder, data: commandData);
          } catch (_) {
            // Discord registration failed — save locally with temp ID
            final commandId =
                DateTime.now().millisecondsSinceEpoch.toString() +
                Random().nextInt(99999).toString();
            final commandMap = <String, dynamic>{
              'id': commandId,
              'name': cmd.name,
              'description': cmd.description,
              'type': commandType,
              'templateOrigin': templateOrigin,
              'data': commandData,
            };
            await appManager.saveAppCommand(
              widget.botId,
              commandId,
              commandMap,
            );
          }
        } else {
          // No client — save locally with temp ID
          final commandId =
              DateTime.now().millisecondsSinceEpoch.toString() +
              Random().nextInt(99999).toString();
          final commandMap = <String, dynamic>{
            'id': commandId,
            'name': cmd.name,
            'description': cmd.description,
            'type': commandType,
            'templateOrigin': templateOrigin,
            'data': commandData,
          };
          await appManager.saveAppCommand(widget.botId, commandId, commandMap);
        }
        addedCommands++;
      }

      // Apply workflows to the bot config
      var addedWorkflows = 0;
      if (widget.template.workflows.isNotEmpty) {
        final appData = await appManager.getApp(widget.botId);
        if (appData.isNotEmpty) {
          final existingWorkflows = List<Map<String, dynamic>>.from(
            (appData['workflows'] as List?)?.whereType<Map>().map(
                  (w) => Map<String, dynamic>.from(w),
                ) ??
                const <Map<String, dynamic>>[],
          );
          final existingWfNames =
              existingWorkflows
                  .map((w) => (w['name'] ?? '').toString().toLowerCase())
                  .toSet();

          for (final wf in widget.template.workflows) {
            final wfName = (wf['name'] ?? '').toString().toLowerCase();
            if (wfName.isEmpty || existingWfNames.contains(wfName)) {
              continue;
            }
            existingWorkflows.add({
              ...Map<String, dynamic>.from(wf),
              'templateOrigin': {
                'templateId': widget.template.id,
                'appliedAt': DateTime.now().toIso8601String(),
              },
            });
            addedWorkflows++;
          }

          appData['workflows'] = existingWorkflows;

          // Merge intents
          final existingIntents = Map<String, bool>.from(
            (appData['intents'] as Map?)?.cast<String, bool>() ??
                const <String, bool>{},
          );
          for (final entry in widget.template.intents.entries) {
            if (entry.value) {
              existingIntents[entry.key] = true;
            }
          }
          appData['intents'] = existingIntents;

          await appManager.saveApp(widget.botId, appData);
        }
      }

      if (!mounted) return;

      for (final name in skipped) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.tr(
                'template_gallery_already_exists',
                params: {'name': name},
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.tr(
              'template_gallery_apply_success',
              params: {
                'count': addedCommands.toString(),
                'wCount': addedWorkflows.toString(),
              },
            ),
          ),
        ),
      );

      if (client == null && addedCommands > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.t('template_gallery_sync_warning')),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      await AppAnalytics.logEvent(
        name: 'apply_template',
        parameters: {
          'template_id': widget.template.id as Object,
          'commands_added': addedCommands as Object,
          'workflows_added': addedWorkflows as Object,
        },
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.tr(
                'template_gallery_apply_error',
                params: {'error': e.toString()},
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  Future<void> _removeTemplateContent() async {
    final templateId = widget.template.id;

    // Find commands generated by this template.
    final commands = await appManager.listAppCommands(widget.botId);
    final templateCommands =
        commands.where((cmd) {
          final origin = cmd['templateOrigin'] as Map?;
          return (origin?['templateId'] ?? '').toString() == templateId;
        }).toList();

    // Find workflows generated by this template.
    final appData = await appManager.getApp(widget.botId);
    final allWorkflows = List<Map<String, dynamic>>.from(
      (appData['workflows'] as List?)?.whereType<Map>().map(
            (w) => Map<String, dynamic>.from(w),
          ) ??
          const <Map<String, dynamic>>[],
    );
    final templateWorkflows =
        allWorkflows.where((wf) {
          final origin = wf['templateOrigin'] as Map?;
          return (origin?['templateId'] ?? '').toString() == templateId;
        }).toList();

    final totalCount = templateCommands.length + templateWorkflows.length;

    if (!mounted) return;

    if (totalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.tr(
              'template_gallery_nothing_to_remove',
              params: {'name': AppStrings.t(widget.template.nameKey)},
            ),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppStrings.t('template_gallery_remove_title')),
            content: Text(
              AppStrings.tr(
                'template_gallery_remove_confirm',
                params: {
                  'name': AppStrings.t(widget.template.nameKey),
                  'commands': templateCommands.length.toString(),
                  'workflows': templateWorkflows.length.toString(),
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppStrings.t('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(AppStrings.t('delete')),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _applying = true);

    try {
      for (final cmd in templateCommands) {
        await appManager.deleteAppCommand(
          widget.botId,
          (cmd['id'] ?? '').toString(),
        );
      }

      if (templateWorkflows.isNotEmpty) {
        final remaining =
            allWorkflows.where((wf) {
              final origin = wf['templateOrigin'] as Map?;
              return (origin?['templateId'] ?? '').toString() != templateId;
            }).toList();
        appData['workflows'] = remaining;
        await appManager.saveApp(widget.botId, appData);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.tr(
              'template_gallery_removed',
              params: {
                'commands': templateCommands.length.toString(),
                'workflows': templateWorkflows.length.toString(),
              },
            ),
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _applying ? null : _applyTemplate,
        onLongPress: _applying ? null : _removeTemplateContent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _templateIcons[template.id] ?? Icons.smart_toy,
                  size: 28,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t(template.nameKey),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.t(template.descriptionKey),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _InfoChip(
                          icon: Icons.code,
                          label: AppStrings.tr(
                            'template_gallery_commands_count',
                            params: {
                              'count': template.commands.length.toString(),
                            },
                          ),
                        ),
                        if (template.workflows.isNotEmpty)
                          _InfoChip(
                            icon: Icons.account_tree,
                            label: AppStrings.tr(
                              'template_gallery_workflows_count',
                              params: {
                                'count': template.workflows.length.toString(),
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_applying)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
