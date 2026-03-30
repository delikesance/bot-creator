import 'dart:convert';

import 'package:bot_creator/utils/simple_mode.dart';

Map<String, dynamic> normalizeCommandData(Map<String, dynamic> command) {
  final normalized = Map<String, dynamic>.from(command);
  final rawData = Map<String, dynamic>.from(
    (normalized['data'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
  final rawCommandType =
      (rawData['commandType'] ?? normalized['type'] ?? 'chatInput')
          .toString()
          .trim()
          .toLowerCase();
  final commandType =
      (rawCommandType == 'user' ||
              rawCommandType == 'usercommand' ||
              rawCommandType == 'user_command')
          ? 'user'
          : (rawCommandType == 'message' ||
              rawCommandType == 'messagecommand' ||
              rawCommandType == 'message_command')
          ? 'message'
          : 'chatInput';

  final legacyResponse = rawData['response'];
  final response = Map<String, dynamic>.from(
    (legacyResponse is Map)
        ? legacyResponse.cast<String, dynamic>()
        : {
          'mode': 'text',
          'text': legacyResponse?.toString() ?? '',
          'embed': {'title': '', 'description': '', 'url': ''},
          'embeds': <Map<String, dynamic>>[],
        },
  );

  final legacySingleEmbed = Map<String, dynamic>.from(
    (response['embed'] as Map?)?.cast<String, dynamic>() ??
        {'title': '', 'description': '', 'url': ''},
  );
  final embeds =
      (response['embeds'] is List)
          ? List<Map<String, dynamic>>.from(
            (response['embeds'] as List).whereType<Map>().map(
              (embed) => Map<String, dynamic>.from(embed),
            ),
          )
          : <Map<String, dynamic>>[];

  final hasLegacyEmbed =
      (legacySingleEmbed['title']?.toString().isNotEmpty ?? false) ||
      (legacySingleEmbed['description']?.toString().isNotEmpty ?? false) ||
      (legacySingleEmbed['url']?.toString().isNotEmpty ?? false) ||
      (legacySingleEmbed['color']?.toString().isNotEmpty ?? false) ||
      (legacySingleEmbed['footer'] is Map &&
          (legacySingleEmbed['footer'] as Map).isNotEmpty) ||
      (legacySingleEmbed['thumbnail']?.toString().isNotEmpty ?? false) ||
      (legacySingleEmbed['image']?.toString().isNotEmpty ?? false) ||
      (legacySingleEmbed['author'] is Map &&
          (legacySingleEmbed['author'] as Map).isNotEmpty) ||
      (legacySingleEmbed['fields'] is List &&
          (legacySingleEmbed['fields'] as List).isNotEmpty);
  if (embeds.isEmpty && hasLegacyEmbed) {
    embeds.add(legacySingleEmbed);
  }

  final actions =
      (rawData['actions'] is List)
          ? List<Map<String, dynamic>>.from(
            (rawData['actions'] as List).whereType<Map>().map(
              (action) => Map<String, dynamic>.from(action),
            ),
          )
          : <Map<String, dynamic>>[];

  final options =
      (rawData['options'] is List)
          ? List<Map<String, dynamic>>.from(
            (rawData['options'] as List).whereType<Map>().map(
              (option) => Map<String, dynamic>.from(
                jsonDecode(jsonEncode(option)) as Map,
              ),
            ),
          )
          : <Map<String, dynamic>>[];

  final normalizedSubcommandWorkflows = <String, Map<String, dynamic>>{};
  final rawSubcommandWorkflows = rawData['subcommandWorkflows'];
  if (rawSubcommandWorkflows is Map) {
    rawSubcommandWorkflows.forEach((route, payload) {
      if (payload is! Map) {
        return;
      }
      final routeKey = route.toString().trim();
      if (routeKey.isEmpty) {
        return;
      }
      normalizedSubcommandWorkflows[routeKey] = Map<String, dynamic>.from(
        (jsonDecode(jsonEncode(payload)) as Map).cast<String, dynamic>(),
      );
    });
  }

  final requestedActiveSubcommandRoute =
      (rawData['activeSubcommandRoute'] ?? '').toString().trim();
  final normalizedActiveSubcommandRoute =
      normalizedSubcommandWorkflows.containsKey(requestedActiveSubcommandRoute)
          ? requestedActiveSubcommandRoute
          : (normalizedSubcommandWorkflows.isNotEmpty
              ? normalizedSubcommandWorkflows.keys.first
              : '');

  final rawEditorMode =
      (rawData['editorMode'] ?? 'advanced').toString().toLowerCase();
  final editorMode = rawEditorMode == 'simple' ? 'simple' : 'advanced';
  final rawExecutionMode =
      (rawData['executionMode'] ?? 'workflow').toString().toLowerCase();
  final executionMode =
      rawExecutionMode == 'bdfd_script' ? 'bdfd_script' : 'workflow';
  final bdfdScriptContent = (rawData['bdfdScriptContent'] ?? '').toString();
  final legacyModeEnabled = rawData['legacyModeEnabled'] == true;
  final legacyLocalOnly = rawData['legacyLocalOnly'] == true;
  final legacyPrefixOverride =
      (rawData['legacyPrefixOverride'] ?? '').toString().trim();
  final rawLegacyResponseTarget =
      (rawData['legacyResponseTarget'] ?? 'reply').toString().trim();
  final legacyResponseTarget =
      rawLegacyResponseTarget == 'channelSend' ? 'channelSend' : 'reply';

  final simpleConfigRaw = Map<String, dynamic>.from(
    (rawData['simpleConfig'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
  final simpleConfig = normalizeSimpleModeConfigMap(simpleConfigRaw);

  final rawWorkflow = Map<String, dynamic>.from(
    (response['workflow'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
  final rawConditional = Map<String, dynamic>.from(
    (rawWorkflow['conditional'] as Map?)?.cast<String, dynamic>() ?? const {},
  );

  final normalizedWorkflow = <String, dynamic>{
    'autoDeferIfActions': rawWorkflow['autoDeferIfActions'] != false,
    'visibility':
        (rawWorkflow['visibility']?.toString().toLowerCase() == 'ephemeral')
            ? 'ephemeral'
            : 'public',
    'onError': 'edit_error',
    'conditional': {
      'enabled': rawConditional['enabled'] == true,
      'variable': (rawConditional['variable'] ?? '').toString(),
      'whenTrueType': (rawConditional['whenTrueType'] ?? 'normal').toString(),
      'whenFalseType': (rawConditional['whenFalseType'] ?? 'normal').toString(),
      'whenTrueText': (rawConditional['whenTrueText'] ?? '').toString(),
      'whenFalseText': (rawConditional['whenFalseText'] ?? '').toString(),
      'whenTrueEmbeds':
          (rawConditional['whenTrueEmbeds'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
      'whenFalseEmbeds':
          (rawConditional['whenFalseEmbeds'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
      'whenTrueNormalComponents': Map<String, dynamic>.from(
        (rawConditional['whenTrueNormalComponents'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      ),
      'whenFalseNormalComponents': Map<String, dynamic>.from(
        (rawConditional['whenFalseNormalComponents'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      ),
      'whenTrueComponents': Map<String, dynamic>.from(
        (rawConditional['whenTrueComponents'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      ),
      'whenFalseComponents': Map<String, dynamic>.from(
        (rawConditional['whenFalseComponents'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      ),
      'whenTrueModal': Map<String, dynamic>.from(
        (rawConditional['whenTrueModal'] as Map?)?.cast<String, dynamic>() ??
            const {},
      ),
      'whenFalseModal': Map<String, dynamic>.from(
        (rawConditional['whenFalseModal'] as Map?)?.cast<String, dynamic>() ??
            const {},
      ),
    },
  };

  normalized['type'] = commandType;
  normalized['data'] = {
    'version': 1,
    'commandType': commandType,
    'editorMode': editorMode,
    'executionMode': executionMode,
    'bdfdScriptContent': bdfdScriptContent,
    'legacyModeEnabled': legacyModeEnabled,
    'legacyLocalOnly': legacyLocalOnly,
    'legacyPrefixOverride': legacyPrefixOverride,
    'legacyResponseTarget': legacyResponseTarget,
    'simpleConfig': simpleConfig,
    'defaultMemberPermissions':
        (rawData['defaultMemberPermissions'] ?? '').toString().trim(),
    'response': {
      'mode':
          (embeds.isNotEmpty ? 'embed' : (response['mode'] ?? 'text'))
              .toString(),
      'text': (response['text'] ?? '').toString(),
      'type': (response['type'] ?? 'normal').toString(),
      'embed':
          embeds.isNotEmpty
              ? embeds.first
              : {'title': '', 'description': '', 'url': ''},
      'embeds': embeds.take(10).toList(),
      'components': Map<String, dynamic>.from(
        (response['components'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      'modal': Map<String, dynamic>.from(
        (response['modal'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      'workflow': normalizedWorkflow,
    },
    'actions': actions,
    if (options.isNotEmpty) 'options': options,
    if (normalizedSubcommandWorkflows.isNotEmpty)
      'subcommandWorkflows': normalizedSubcommandWorkflows,
    if (normalizedSubcommandWorkflows.isNotEmpty)
      'activeSubcommandRoute': normalizedActiveSubcommandRoute,
  };

  return normalized;
}
