import 'package:flutter/material.dart';
import 'package:bot_creator/types/app_emoji.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:bot_creator/widgets/variable_text_field.dart';
import 'package:bot_creator/routes/app/command.response_workflow.dart';
import 'package:bot_creator/widgets/response_embeds_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_v2_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/normal_component_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/modal_builder.dart';
import 'package:bot_creator/types/component.dart';

class ReplyCard extends StatelessWidget {
  final String responseType;
  final ValueChanged<String> onResponseTypeChanged;
  final TextEditingController responseController;
  final Widget variableSuggestionBar;
  final List<Map<String, dynamic>> responseEmbeds;
  final ValueChanged<List<Map<String, dynamic>>> onEmbedsChanged;
  final Map<String, dynamic> responseComponents;
  final ValueChanged<Map<String, dynamic>> onComponentsChanged;
  final Map<String, dynamic> responseModal;
  final ValueChanged<Map<String, dynamic>> onModalChanged;
  final Map<String, dynamic> responseWorkflow;
  final Map<String, dynamic> Function(Map<String, dynamic>) normalizeWorkflow;
  final List<VariableSuggestion> variableSuggestions;
  final List<AppEmoji>? emojiSuggestions;
  final String? botIdForConfig;
  final ValueChanged<Map<String, dynamic>> onWorkflowChanged;
  final String workflowSummary;
  final String? activeRouteLabel;
  final bool activeRouteIsGrouped;

  const ReplyCard({
    super.key,
    required this.responseType,
    required this.onResponseTypeChanged,
    required this.responseController,
    required this.variableSuggestionBar,
    required this.responseEmbeds,
    required this.onEmbedsChanged,
    required this.responseComponents,
    required this.onComponentsChanged,
    required this.responseModal,
    required this.onModalChanged,
    required this.responseWorkflow,
    required this.normalizeWorkflow,
    required this.variableSuggestions,
    this.emojiSuggestions,
    this.botIdForConfig,
    required this.onWorkflowChanged,
    required this.workflowSummary,
    this.activeRouteLabel,
    this.activeRouteIsGrouped = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 420;
    final routeColor =
        activeRouteIsGrouped
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.primary;

    Future<void> openWorkflowEditor() async {
      final nextWorkflow = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder:
              (context) => CommandResponseWorkflowPage(
                initialWorkflow: normalizeWorkflow(responseWorkflow),
                variableSuggestions: variableSuggestions,
                emojiSuggestions: emojiSuggestions,
                botIdForConfig: botIdForConfig,
              ),
        ),
      );

      if (nextWorkflow != null) {
        onWorkflowChanged(normalizeWorkflow(nextWorkflow));
      }
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Command Reply",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              "Choose the type of response to send",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (activeRouteLabel != null && activeRouteLabel!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: routeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Active route: $activeRouteLabel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: routeColor,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _buildResponseModeSelector(context),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Response Workflow',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    workflowSummary,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: openWorkflowEditor,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Configure Response Workflow'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (responseType == 'normal') ...[
              VariableTextField(
                label: "Response Text",
                controller: responseController,
                maxLines: 4,
                suggestions: variableSuggestions,
                emojiSuggestions: emojiSuggestions,
                onChanged: (_) {},
                helperText:
                    "Used as slash-command reply text. Supports ((variable)) syntax.",
              ),
              // external suggestion bar provided by parent (e.g. command creation page)
              variableSuggestionBar,
              const SizedBox(height: 12),
              ResponseEmbedsEditor(
                embeds: responseEmbeds,
                variableSuggestions: variableSuggestions,
                emojiSuggestions: emojiSuggestions,
                onChanged: onEmbedsChanged,
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Buttons & Select Menus (optional)'),
                subtitle: Text(
                  'Add interactive buttons or dropdowns to this message',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                collapsedBackgroundColor: Colors.grey.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                childrenPadding: const EdgeInsets.all(8.0),
                children: [
                  NormalComponentEditorWidget(
                    definition: ComponentV2Definition.fromJson(
                      responseComponents,
                    ),
                    onChanged: (def) => onComponentsChanged(def.toJson()),
                    variableSuggestions: variableSuggestions,
                    botIdForConfig: botIdForConfig,
                  ),
                ],
              ),
            ] else if (responseType == 'componentV2') ...[
              ComponentV2EditorWidget(
                definition: ComponentV2Definition.fromJson(responseComponents),
                onChanged: (def) => onComponentsChanged(def.toJson()),
                variableSuggestions: variableSuggestions,
                botIdForConfig: botIdForConfig,
              ),
            ] else if (responseType == 'modal') ...[
              ModalBuilderWidget(
                modal: ModalDefinition.fromJson(responseModal),
                onChanged: (def) => onModalChanged(def.toJson()),
                variableSuggestions: variableSuggestions,
                botIdForConfig: botIdForConfig,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Unified mode selector that displays each response mode with a label,
  /// description, and icon so users understand when to use which mode.
  Widget _buildResponseModeSelector(BuildContext context) {
    const modes = [
      (
        value: 'normal',
        label: 'Standard Message',
        description: 'Text, embeds and optional buttons / select menus',
        icon: Icons.message_outlined,
      ),
      (
        value: 'componentV2',
        label: 'Layout Mode',
        description:
            "Discord's rich layout system — containers, media, text & forms",
        icon: Icons.dashboard_customize_outlined,
      ),
      (
        value: 'modal',
        label: 'Modal Form',
        description: 'Pop-up dialog with text input fields',
        icon: Icons.web_asset_outlined,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mode in modes)
          _buildResponseModeChip(
            context: context,
            value: mode.value,
            label: mode.label,
            description: mode.description,
            icon: mode.icon,
          ),
      ],
    );
  }

  Widget _buildResponseModeChip({
    required BuildContext context,
    required String value,
    required String label,
    required String description,
    required IconData icon,
  }) {
    final selected = responseType == value;
    final activeColor = Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: description,
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 16,
          color: selected ? activeColor : Colors.grey.shade600,
        ),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? activeColor : null,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color:
                    selected
                        ? activeColor.withValues(alpha: 0.75)
                        : Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        onSelected: (_) => onResponseTypeChanged(value),
      ),
    );
  }
}
