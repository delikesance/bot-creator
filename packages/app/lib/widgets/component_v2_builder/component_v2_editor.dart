import 'package:flutter/material.dart';
import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_node_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_node_factory.dart';

/// Full visual editor for a ComponentV2 message (text + recursive component nodes).
/// Manages a [ComponentV2Definition] and notifies via [onChanged].
class ComponentV2EditorWidget extends StatefulWidget {
  final ComponentV2Definition definition;
  final ValueChanged<ComponentV2Definition> onChanged;
  final List<VariableSuggestion> variableSuggestions;
  final String? botIdForConfig;

  const ComponentV2EditorWidget({
    super.key,
    required this.definition,
    required this.onChanged,
    required this.variableSuggestions,
    this.botIdForConfig,
  });

  @override
  State<ComponentV2EditorWidget> createState() =>
      _ComponentV2EditorWidgetState();
}

class _ComponentV2EditorWidgetState extends State<ComponentV2EditorWidget> {
  late List<ComponentNode> _components;
  late bool _ephemeral;

  @override
  void initState() {
    super.initState();
    _initFromWidget();
  }

  @override
  void didUpdateWidget(ComponentV2EditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the external definition reference has changed, re-sync our local state
    // to prevent losing data visually when the parent redraws.
    if (widget.definition != oldWidget.definition) {
      _initFromWidget();
    }
  }

  void _initFromWidget() {
    // Deep copy components via json serialization round-trip
    _components =
        widget.definition.components
            .map((c) => ComponentNode.fromJson(c.toJson()))
            .toList();
    _ephemeral = widget.definition.ephemeral;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      ComponentV2Definition(
        content: '',
        components:
            _components.map((c) => ComponentNode.fromJson(c.toJson())).toList(),
        ephemeral: _ephemeral,
      ),
    );
  }

  void _addNode(ComponentV2Type type) {
    setState(() => _components.add(ComponentNodeFactory.create(type)));
    _emit();
  }

  void _removeNode(int index) {
    setState(() => _components.removeAt(index));
    _emit();
  }

  void _updateNode(int index, ComponentNode updated) {
    setState(() {
      _components[index] = updated;
    });
    _emit();
  }

  String _getTitleForType(ComponentV2Type type) => ComponentNodeFactory.labelFor(type);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.dashboard_customize,
                size: 18,
                color: Colors.purple.shade600,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Layout Builder',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    Text(
                      'Discord rich layout — containers, media, text & forms',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.purple.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_components.length} Root Nodes',
                style: TextStyle(color: Colors.purple.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.purple.shade200),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Ephemeral (only visible to command user)',
                  style: TextStyle(fontSize: 13),
                ),
                value: _ephemeral,
                onChanged: (v) {
                  setState(() => _ephemeral = v);
                  _emit();
                },
              ),
              const Divider(height: 16),
              // Render root components
              ..._components.asMap().entries.map((entry) {
                final index = entry.key;
                final node = entry.value;
                return ComponentNodeEditor(
                  node: node,
                  onChanged: (updated) => _updateNode(index, updated),
                  onRemove: () => _removeNode(index),
                  variableSuggestions: widget.variableSuggestions,
                  botIdForConfig: widget.botIdForConfig,
                );
              }),
              const SizedBox(height: 8),
              // Add root component dropdown
              PopupMenuButton<ComponentV2Type>(
                tooltip: 'Add Root Component',
                onSelected: (v) {
                  _addNode(v);
                },
                itemBuilder: (BuildContext context) {
                  final rootTypes = [
                    ComponentV2Type.container,
                    ComponentV2Type.actionRow,
                    ComponentV2Type.section,
                    ComponentV2Type.textDisplay,
                    ComponentV2Type.mediaGallery,
                    ComponentV2Type.file,
                    ComponentV2Type.separator,
                  ];
                  return rootTypes
                      .map(
                        (t) => PopupMenuItem(
                          value: t,
                          child: Text(_getTitleForType(t)),
                        ),
                      )
                      .toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueGrey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.blueGrey),
                      SizedBox(width: 8),
                      Text(
                        'Add Root Component',
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
