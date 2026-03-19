import 'dart:convert';
import 'dart:io';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/types/app_emoji.dart';
import 'package:bot_creator/utils/app_emoji_api.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class EmojisPage extends StatefulWidget {
  final String botId;

  const EmojisPage({super.key, required this.botId});

  @override
  State<EmojisPage> createState() => _EmojisPageState();
}

class _EmojisPageState extends State<EmojisPage> {
  List<AppEmoji> _emojis = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEmojis();
  }

  Future<String?> _getToken() async {
    try {
      final app = await appManager.getApp(widget.botId);
      final token = (app['token'] ?? '').toString().trim();
      return token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadEmojis() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token');
      final emojis = await AppEmojiApi.listEmojis(token, widget.botId);
      if (!mounted) return;
      setState(() {
        _emojis = emojis;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppStrings.t('emojis_loading_error');
        _loading = false;
      });
    }
  }

  Future<void> _showUploadDialog() async {
    final nameController = TextEditingController();
    String? pickedFilePath;
    String? pickedFileName;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(AppStrings.t('emojis_upload')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: AppStrings.t('emojis_upload_name_hint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      pickedFileName ??
                          AppStrings.t('emojis_upload_pick_image'),
                    ),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        allowMultiple: false,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setDialogState(() {
                          pickedFilePath = result.files.first.path;
                          pickedFileName = result.files.first.name;
                          // Pre-fill name if empty
                          if (nameController.text.isEmpty) {
                            final baseName = result.files.first.name
                                .replaceAll(RegExp(r'\.[^.]+$'), '')
                                .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
                            nameController.text = baseName;
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(AppStrings.t('cancel')),
                ),
                FilledButton(
                  onPressed:
                      pickedFilePath == null
                          ? null
                          : () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty || pickedFilePath == null) return;
                            Navigator.of(ctx).pop();
                            await _uploadEmoji(name, pickedFilePath!);
                          },
                  child: Text(AppStrings.t('emojis_upload')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _uploadEmoji(String name, String filePath) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token');

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final ext = filePath.split('.').last.toLowerCase();
      final mime = _mimeForExt(ext);
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

      final created = await AppEmojiApi.createEmoji(
        token,
        widget.botId,
        name,
        dataUri,
      );
      if (!mounted) return;
      setState(() {
        _emojis = [..._emojis, created];
      });
    } catch (e) {
      if (!mounted) return;
      _showError(
        AppStrings.tr('emojis_upload_error', params: {'error': e.toString()}),
      );
    }
  }

  Future<void> _showRenameDialog(AppEmoji emoji) async {
    final controller = TextEditingController(text: emoji.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppStrings.t('emojis_rename_title')),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppStrings.t('emojis_rename_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppStrings.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(AppStrings.t('emojis_rename_title')),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final newName = controller.text.trim();
    if (newName.isEmpty || newName == emoji.name) return;
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token');
      final updated = await AppEmojiApi.renameEmoji(
        token,
        widget.botId,
        emoji.id,
        newName,
      );
      if (!mounted) return;
      setState(() {
        _emojis = _emojis.map((e) => e.id == emoji.id ? updated : e).toList();
      });
    } catch (e) {
      if (!mounted) return;
      _showError(
        AppStrings.tr('emojis_rename_error', params: {'error': e.toString()}),
      );
    }
  }

  Future<void> _confirmDelete(AppEmoji emoji) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppStrings.t('emojis_delete_confirm_title')),
            content: Text(
              AppStrings.tr(
                'emojis_delete_confirm_body',
                params: {'name': emoji.name},
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppStrings.t('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(AppStrings.t('delete')),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token');
      await AppEmojiApi.deleteEmoji(token, widget.botId, emoji.id);
      if (!mounted) return;
      setState(() {
        _emojis = _emojis.where((e) => e.id != emoji.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      _showError(
        AppStrings.tr('emojis_delete_error', params: {'error': e.toString()}),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _mimeForExt(String ext) {
    switch (ext) {
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'image/png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        title: Text(AppStrings.t('emojis_title')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadEmojis,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        icon: const Icon(Icons.add),
        label: Text(AppStrings.t('emojis_upload')),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_errorMessage!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadEmojis, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_emojis.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_emotions_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.t('emojis_empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: _emojis.length,
          itemBuilder: (context, index) {
            return _EmojiCard(
              emoji: _emojis[index],
              onRename: () => _showRenameDialog(_emojis[index]),
              onDelete: () => _confirmDelete(_emojis[index]),
            );
          },
        );
      },
    );
  }
}

class _EmojiCard extends StatelessWidget {
  final AppEmoji emoji;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _EmojiCard({
    required this.emoji,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.network(
                emoji.imageUrl,
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: Colors.grey,
                    ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Text(
              ':${emoji.name}:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (emoji.animated)
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(
                'animated',
                style: TextStyle(fontSize: 10, color: Colors.blueAccent),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Rename',
                onPressed: onRename,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                tooltip: 'Delete',
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
