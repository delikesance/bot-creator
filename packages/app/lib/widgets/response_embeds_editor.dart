import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:bot_creator/types/app_emoji.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:bot_creator/widgets/variable_text_field.dart';

class ResponseEmbedsEditor extends StatefulWidget {
  final List<Map<String, dynamic>> embeds;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final int maxEmbeds;
  final List<VariableSuggestion> variableSuggestions;
  final List<AppEmoji>? emojiSuggestions;

  const ResponseEmbedsEditor({
    super.key,
    required this.embeds,
    required this.onChanged,
    this.maxEmbeds = 10,
    this.variableSuggestions = const [],
    this.emojiSuggestions,
  });

  @override
  State<ResponseEmbedsEditor> createState() => _ResponseEmbedsEditorState();
}

class _ResponseEmbedsEditorState extends State<ResponseEmbedsEditor> {
  List<Map<String, dynamic>> _embeds = [];

  Color? _parseEmbedColor(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 6) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed == null) {
          return null;
        }
        return Color(0xFF000000 | parsed);
      }
      if (hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed == null) {
          return null;
        }
        return Color(parsed);
      }
      return null;
    }

    final asInt = int.tryParse(value);
    if (asInt == null) {
      return null;
    }
    return Color(0xFF000000 | (asInt & 0x00FFFFFF));
  }

  String _formatEmbedColorHex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> _pickEmbedColor(int index) async {
    Color selected =
        _parseEmbedColor((_embeds[index]['color'] ?? '').toString()) ??
        const Color(0xFF5865F2);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick embed color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: selected,
              onColorChanged: (color) {
                selected = color;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _setEmbedValue(index, 'color', _formatEmbedColorHex(selected));
    }
  }

  @override
  void initState() {
    super.initState();
    _embeds = widget.embeds.map(_normalizeEmbed).toList();
  }

  @override
  void didUpdateWidget(covariant ResponseEmbedsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.embeds != widget.embeds) {
      _embeds = widget.embeds.map(_normalizeEmbed).toList();
    }
  }

  Map<String, dynamic> _normalizeEmbed(Map<String, dynamic> embed) {
    return {
      'title': (embed['title'] ?? '').toString(),
      'type': (embed['type'] ?? 'rich').toString(),
      'description': (embed['description'] ?? '').toString(),
      'url': (embed['url'] ?? '').toString(),
      'timestamp': (embed['timestamp'] ?? '').toString(),
      'color': (embed['color'] ?? '').toString(),
      'footer': {
        'text': (embed['footer']?['text'] ?? '').toString(),
        'icon_url': (embed['footer']?['icon_url'] ?? '').toString(),
      },
      'image': {'url': (embed['image']?['url'] ?? '').toString()},
      'thumbnail': {'url': (embed['thumbnail']?['url'] ?? '').toString()},
      'author': {
        'name': (embed['author']?['name'] ?? '').toString(),
        'url': (embed['author']?['url'] ?? '').toString(),
        'icon_url': (embed['author']?['icon_url'] ?? '').toString(),
      },
      'fieldsTemplate': (embed['fieldsTemplate'] ?? '').toString(),
      'fields':
          (embed['fields'] is List)
              ? List<Map<String, dynamic>>.from(
                (embed['fields'] as List).whereType<Map>().map(
                  (field) => {
                    'name': (field['name'] ?? '').toString(),
                    'value': (field['value'] ?? '').toString(),
                    'inline': field['inline'] == true,
                  },
                ),
              ).take(25).toList()
              : <Map<String, dynamic>>[],
    };
  }

  void _emit() {
    widget.onChanged(List<Map<String, dynamic>>.from(_embeds));
  }

  void _addEmbed() {
    if (_embeds.length >= widget.maxEmbeds) return;
    setState(() {
      _embeds.add(_normalizeEmbed(const {}));
    });
    _emit();
  }

  Future<void> _removeEmbed(int index) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog.adaptive(
                title: const Text('Delete embed'),
                content: const Text('This embed will be removed. Continue?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
    if (!shouldDelete) {
      return;
    }

    setState(() {
      _embeds.removeAt(index);
    });
    _emit();
  }

  void _setEmbedValue(int index, String key, dynamic value) {
    setState(() {
      _embeds[index][key] = value;
    });
    _emit();
  }

  void _setNestedValue(int index, String key, String nestedKey, dynamic value) {
    setState(() {
      final nested = Map<String, dynamic>.from(_embeds[index][key] ?? {});
      nested[nestedKey] = value;
      _embeds[index][key] = nested;
    });
    _emit();
  }

  void _addField(int index) {
    final fields = List<Map<String, dynamic>>.from(
      _embeds[index]['fields'] ?? [],
    );
    if (fields.length >= 25) return;

    setState(() {
      fields.add({'name': '', 'value': '', 'inline': false});
      _embeds[index]['fields'] = fields;
    });
    _emit();
  }

  Future<void> _removeField(int embedIndex, int fieldIndex) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog.adaptive(
                title: const Text('Delete field'),
                content: const Text(
                  'This field will be removed from the embed. Continue?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
    if (!shouldDelete) {
      return;
    }

    final fields = List<Map<String, dynamic>>.from(
      _embeds[embedIndex]['fields'] ?? [],
    );
    setState(() {
      fields.removeAt(fieldIndex);
      _embeds[embedIndex]['fields'] = fields;
    });
    _emit();
  }

  void _setFieldValue(
    int embedIndex,
    int fieldIndex,
    String key,
    dynamic value,
  ) {
    final fields = List<Map<String, dynamic>>.from(
      _embeds[embedIndex]['fields'] ?? [],
    );
    setState(() {
      fields[fieldIndex][key] = value;
      _embeds[embedIndex]['fields'] = fields;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Response Embeds (${_embeds.length}/${widget.maxEmbeds})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            IconButton(
              onPressed: _embeds.length >= widget.maxEmbeds ? null : _addEmbed,
              icon: const Icon(Icons.add, size: 20),
              tooltip: 'Add embed',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_embeds.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'No embeds. You can add up to 10 embeds.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._embeds.asMap().entries.map((entry) {
            final index = entry.key;
            final embed = entry.value;
            final footer = Map<String, dynamic>.from(embed['footer'] ?? {});
            final image = Map<String, dynamic>.from(embed['image'] ?? {});
            final thumbnail = Map<String, dynamic>.from(
              embed['thumbnail'] ?? {},
            );
            final author = Map<String, dynamic>.from(embed['author'] ?? {});
            final fields = List<Map<String, dynamic>>.from(
              embed['fields'] ?? [],
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Embed #${index + 1}'),
                        IconButton(
                          onPressed: () => _removeEmbed(index),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    VariableTextField(
                      label: 'Title',
                      initialValue: embed['title']?.toString() ?? '',
                      maxLength: 256,
                      suggestions: widget.variableSuggestions,
                      emojiSuggestions: widget.emojiSuggestions,
                      onChanged:
                          (value) => _setEmbedValue(index, 'title', value),
                    ),
                    const SizedBox(height: 8),
                    VariableTextField(
                      label: 'Description',
                      initialValue: embed['description']?.toString() ?? '',
                      maxLength: 2000,
                      maxLines: 4,
                      suggestions: widget.variableSuggestions,
                      emojiSuggestions: widget.emojiSuggestions,
                      onChanged:
                          (value) =>
                              _setEmbedValue(index, 'description', value),
                    ),
                    const SizedBox(height: 8),
                    VariableTextField(
                      label: 'URL',
                      initialValue: embed['url']?.toString() ?? '',
                      suggestions: widget.variableSuggestions,
                      emojiSuggestions: widget.emojiSuggestions,
                      onChanged: (value) => _setEmbedValue(index, 'url', value),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 280,
                          child: VariableTextField(
                            label: 'Timestamp (ISO8601)',
                            initialValue: embed['timestamp']?.toString() ?? '',
                            suggestions: widget.variableSuggestions,
                            emojiSuggestions: widget.emojiSuggestions,
                            onChanged:
                                (value) =>
                                    _setEmbedValue(index, 'timestamp', value),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              VariableTextField(
                                label: 'Color (int or #hex)',
                                initialValue: embed['color']?.toString() ?? '',
                                suggestions: widget.variableSuggestions,
                                emojiSuggestions: widget.emojiSuggestions,
                                onChanged:
                                    (value) =>
                                        _setEmbedValue(index, 'color', value),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _pickEmbedColor(index),
                                  icon: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color:
                                          _parseEmbedColor(
                                            embed['color']?.toString() ?? '',
                                          ) ??
                                          Colors.transparent,
                                      border: Border.all(
                                        color: Colors.grey.shade500,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  label: const Text('Pick'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Footer'),
                      children: [
                        VariableTextField(
                          label: 'Footer Text',
                          initialValue: footer['text']?.toString() ?? '',
                          suggestions: widget.variableSuggestions,
                          emojiSuggestions: widget.emojiSuggestions,
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'footer',
                                'text',
                                value,
                              ),
                        ),
                        const SizedBox(height: 8),
                        VariableTextField(
                          label: 'Footer Icon URL',
                          initialValue: footer['icon_url']?.toString() ?? '',
                          suggestions: widget.variableSuggestions,
                          emojiSuggestions: widget.emojiSuggestions,
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'footer',
                                'icon_url',
                                value,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Author'),
                      children: [
                        VariableTextField(
                          label: 'Author Name',
                          initialValue: author['name']?.toString() ?? '',
                          suggestions: widget.variableSuggestions,
                          emojiSuggestions: widget.emojiSuggestions,
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'author',
                                'name',
                                value,
                              ),
                        ),
                        const SizedBox(height: 8),
                        VariableTextField(
                          label: 'Author URL',
                          initialValue: author['url']?.toString() ?? '',
                          suggestions: widget.variableSuggestions,
                          emojiSuggestions: widget.emojiSuggestions,
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'author',
                                'url',
                                value,
                              ),
                        ),
                        const SizedBox(height: 8),
                        VariableTextField(
                          label: 'Author Icon URL',
                          initialValue: author['icon_url']?.toString() ?? '',
                          suggestions: widget.variableSuggestions,
                          emojiSuggestions: widget.emojiSuggestions,
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'author',
                                'icon_url',
                                value,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Media'),
                      children: [
                        VariableTextField(
                          label: 'Image URL',
                          initialValue: image['url']?.toString() ?? '',
                          suggestions: widget.variableSuggestions,
                          emojiSuggestions: widget.emojiSuggestions,
                          onChanged:
                              (value) =>
                                  _setNestedValue(index, 'image', 'url', value),
                        ),
                        const SizedBox(height: 8),
                        VariableTextField(
                          label: 'Thumbnail URL',
                          initialValue: thumbnail['url']?.toString() ?? '',
                          suggestions: widget.variableSuggestions,
                          emojiSuggestions: widget.emojiSuggestions,
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'thumbnail',
                                'url',
                                value,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Fields (${fields.length}/25)'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed:
                            fields.length >= 25 ? null : () => _addField(index),
                      ),
                      children: [
                        if (fields.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text('No fields yet.'),
                          )
                        else
                          ...fields.asMap().entries.map((fieldEntry) {
                            final fieldIndex = fieldEntry.key;
                            final field = fieldEntry.value;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Field #${fieldIndex + 1}'),
                                        IconButton(
                                          onPressed:
                                              () => _removeField(
                                                index,
                                                fieldIndex,
                                              ),
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    VariableTextField(
                                      label: 'Name',
                                      initialValue:
                                          field['name']?.toString() ?? '',
                                      suggestions: widget.variableSuggestions,
                                      emojiSuggestions: widget.emojiSuggestions,
                                      onChanged:
                                          (value) => _setFieldValue(
                                            index,
                                            fieldIndex,
                                            'name',
                                            value,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    VariableTextField(
                                      label: 'Value',
                                      initialValue:
                                          field['value']?.toString() ?? '',
                                      maxLines: 3,
                                      suggestions: widget.variableSuggestions,
                                      emojiSuggestions: widget.emojiSuggestions,
                                      onChanged:
                                          (value) => _setFieldValue(
                                            index,
                                            fieldIndex,
                                            'value',
                                            value,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Inline'),
                                      value: field['inline'] == true,
                                      onChanged:
                                          (value) => _setFieldValue(
                                            index,
                                            fieldIndex,
                                            'inline',
                                            value,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    VariableTextField(
                      label: 'Dynamic Fields Template',
                      initialValue: embed['fieldsTemplate']?.toString() ?? '',
                      maxLines: 3,
                      suggestions: widget.variableSuggestions,
                      emojiSuggestions: widget.emojiSuggestions,
                      hint:
                          'Ex: ((embedFields(myHttp.body.\$.items, "{name}", "{score}", true)))',
                      onChanged:
                          (value) =>
                              _setEmbedValue(index, 'fieldsTemplate', value),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
