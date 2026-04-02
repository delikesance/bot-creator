import 'dart:math';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/premium_capabilities.dart';
import 'package:bot_creator/utils/runner_settings.dart';
import 'package:bot_creator/widgets/subscription_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InboundWebhooksPage extends StatefulWidget {
  const InboundWebhooksPage({super.key, required this.botId});

  final String botId;

  @override
  State<InboundWebhooksPage> createState() => _InboundWebhooksPageState();
}

class _InboundWebhooksPageState extends State<InboundWebhooksPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _webhooks = const <Map<String, dynamic>>[];
  List<String> _workflowNames = const <String>[];

  bool get _hasCapability =>
      PremiumCapabilities.hasCapability(PremiumCapability.inboundWebhooks);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final workflows = await appManager.getWorkflows(widget.botId);
    final workflowNames = workflows
      .map((entry) => (entry['name'] ?? '').toString().trim())
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList(growable: false)..sort();

    final webhooks = await appManager.getInboundWebhooks(widget.botId);

    if (!mounted) {
      return;
    }

    setState(() {
      _workflowNames = workflowNames;
      _webhooks = webhooks;
      _loading = false;
    });
  }

  Future<void> _showEditor({Map<String, dynamic>? initial}) async {
    if (_workflowNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create at least one workflow before adding an inbound webhook.',
          ),
        ),
      );
      return;
    }

    final pathCtrl = TextEditingController(
      text: (initial?['path'] ?? '').toString(),
    );
    final secretCtrl = TextEditingController(
      text: (initial?['secret'] ?? _generateSecret()).toString(),
    );

    var selectedWorkflow =
        ((initial?['workflowName'] ?? '').toString().trim().isNotEmpty)
            ? (initial!['workflowName'] as String)
            : _workflowNames.first;
    var enabled = initial == null ? true : initial['enabled'] != false;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setInnerState) {
            return AlertDialog.adaptive(
              title: Text(
                initial == null
                    ? 'Add inbound webhook'
                    : 'Edit inbound webhook',
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: pathCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Path',
                          hintText: 'orders/new',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedWorkflow,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Workflow target',
                          border: OutlineInputBorder(),
                        ),
                        items: _workflowNames
                            .map(
                              (name) => DropdownMenuItem<String>(
                                value: name,
                                child: Text(name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setInnerState(() {
                            selectedWorkflow = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: secretCtrl,
                        decoration: InputDecoration(
                          labelText: 'Webhook secret',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: 'Generate',
                            icon: const Icon(Icons.casino_outlined),
                            onPressed: () {
                              setInnerState(() {
                                secretCtrl.text = _generateSecret();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: enabled,
                        title: const Text('Enabled'),
                        onChanged: (value) {
                          setInnerState(() {
                            enabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(AppStrings.t('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(AppStrings.t('app_save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (save != true) {
      return;
    }

    try {
      await appManager.saveInboundWebhook(
        widget.botId,
        path: pathCtrl.text,
        workflowName: selectedWorkflow,
        secret: secretCtrl.text,
        enabled: enabled,
        webhookId:
            (initial?['id'] ?? '').toString().trim().isEmpty
                ? null
                : (initial?['id'] ?? '').toString(),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final text = error.toString();
      if (text.contains('inbound_webhook_limit_reached')) {
        final limit = PremiumCapabilities.limitFor(
          PremiumCapability.inboundWebhooks,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Inbound webhook limit reached ($limit).')),
        );
      } else if (text.contains('inbound_webhook_path_conflict')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This path already exists. Choose another one.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save inbound webhook: $error')),
        );
      }
    }
  }

  Future<void> _deleteWebhook(Map<String, dynamic> webhook) async {
    final label = (webhook['path'] ?? '').toString().trim();

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog.adaptive(
              title: const Text('Delete inbound webhook?'),
              content: Text(
                label.isEmpty
                    ? 'This cannot be undone.'
                    : 'Delete "$label"? This cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(AppStrings.t('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(AppStrings.t('delete')),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm) {
      return;
    }

    await appManager.deleteInboundWebhook(
      widget.botId,
      (webhook['id'] ?? '').toString(),
    );
    await _load();
  }

  Future<void> _copyFullWebhookUrl(Map<String, dynamic> webhook) async {
    final baseUrl = await RunnerSettings.getUrl();
    final normalizedBase = (baseUrl ?? '').trim();
    if (normalizedBase.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configure a Runner URL first to copy the full webhook URL.',
          ),
        ),
      );
      return;
    }

    final path = (webhook['path'] ?? '').toString().trim();
    final secret = (webhook['secret'] ?? '').toString().trim();
    if (path.isEmpty || secret.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Webhook path or secret is missing.')),
      );
      return;
    }

    try {
      final baseUri = Uri.parse(normalizedBase);
      final combinedSegments = <String>[
        ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
        'bots',
        widget.botId,
        'inbound',
        ...path.split('/').where((segment) => segment.trim().isNotEmpty),
      ];
      final fullUri = baseUri.replace(
        pathSegments: combinedSegments,
        queryParameters: <String, String>{'secret': secret},
      );
      await Clipboard.setData(ClipboardData(text: fullUri.toString()));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Full webhook URL copied.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Runner URL is invalid.')));
    }
  }

  String _generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final chars = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return chars;
  }

  Widget _buildUpsellCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.t('subscription_feature_webhooks_title'),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(AppStrings.t('subscription_feature_webhooks_desc')),
            const SizedBox(height: 12),
            if (PremiumCapabilities.canShowPurchaseUI)
              FilledButton.icon(
                onPressed: () async {
                  await SubscriptionPage.show(context);
                  if (!mounted) {
                    return;
                  }
                  await _load();
                },
                icon: const Icon(Icons.workspace_premium_rounded),
                label: Text(AppStrings.t('premium_card_button')),
              )
            else
              Text(
                AppStrings.t('subscription_unavailable_platform'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final limit = PremiumCapabilities.limitFor(
      PremiumCapability.inboundWebhooks,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbound Webhooks'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton:
          _hasCapability
              ? FloatingActionButton.extended(
                onPressed: () => _showEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Add webhook'),
              )
              : null,
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (!_hasCapability) _buildUpsellCard(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Text(
                          'Webhooks: ${_webhooks.length}${limit > 0 ? ' / $limit' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        _webhooks.isEmpty
                            ? const Center(
                              child: Text('No inbound webhooks yet.'),
                            )
                            : ListView.separated(
                              itemCount: _webhooks.length,
                              separatorBuilder:
                                  (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final webhook = _webhooks[index];
                                final path = (webhook['path'] ?? '').toString();
                                final workflow =
                                    (webhook['workflowName'] ?? '').toString();
                                final secret =
                                    (webhook['secret'] ?? '').toString();
                                final enabled = webhook['enabled'] != false;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  title: Text('/$path'),
                                  subtitle: Text('Workflow: $workflow'),
                                  trailing: PopupMenuButton<String>(
                                    itemBuilder:
                                        (BuildContext context) => [
                                          PopupMenuItem<String>(
                                            value: 'copy_url',
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.content_copy_outlined,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 12),
                                                const Text('Copy URL'),
                                              ],
                                            ),
                                            onTap:
                                                () => _copyFullWebhookUrl(
                                                  webhook,
                                                ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'copy_path',
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.link_outlined,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 12),
                                                const Text('Copy path'),
                                              ],
                                            ),
                                            onTap: () async {
                                              await Clipboard.setData(
                                                ClipboardData(text: '/$path'),
                                              );
                                              if (!mounted) {
                                                return;
                                              }
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Path copied.'),
                                                ),
                                              );
                                            },
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'copy_secret',
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.key_outlined,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 12),
                                                const Text('Copy secret'),
                                              ],
                                            ),
                                            onTap: () async {
                                              await Clipboard.setData(
                                                ClipboardData(text: secret),
                                              );
                                              if (!mounted) {
                                                return;
                                              }
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Secret copied.',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          if (_hasCapability) ...[
                                            PopupMenuItem<String>(
                                              value: 'edit',
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.edit_outlined,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text('Edit'),
                                                ],
                                              ),
                                              onTap:
                                                  () => _showEditor(
                                                    initial: webhook,
                                                  ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                    color: Colors.red,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              onTap:
                                                  () => _deleteWebhook(webhook),
                                            ),
                                          ],
                                        ],
                                    child: IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      tooltip: 'Actions',
                                      onPressed: null,
                                    ),
                                  ),
                                  leading: Switch.adaptive(
                                    value: enabled,
                                    onChanged:
                                        _hasCapability
                                            ? (value) async {
                                              await appManager
                                                  .saveInboundWebhook(
                                                    widget.botId,
                                                    path: path,
                                                    workflowName: workflow,
                                                    secret: secret,
                                                    enabled: value,
                                                    webhookId:
                                                        (webhook['id'] ?? '')
                                                            .toString(),
                                                  );
                                              await _load();
                                            }
                                            : null,
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
