part of 'command.create.dart';

extension _CommandCreateWorkflow on _CommandCreatePageState {
  List<Map<String, dynamic>> _normalizeEmbedsPayload(dynamic rawEmbeds) {
    if (rawEmbeds is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawEmbeds
        .whereType<Map>()
        .map((embed) {
          return Map<String, dynamic>.from(
            embed.map((key, value) => MapEntry(key.toString(), value)),
          );
        })
        .take(10)
        .toList(growable: false);
  }

  Map<String, dynamic> _normalizeWorkflow(Map<String, dynamic> input) {
    final conditional = Map<String, dynamic>.from(
      (input['conditional'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    return {
      'autoDeferIfActions': input['autoDeferIfActions'] != false,
      'visibility':
          (input['visibility']?.toString().toLowerCase() == 'ephemeral')
              ? 'ephemeral'
              : 'public',
      'onError': 'edit_error',
      'conditional': {
        'enabled': conditional['enabled'] == true,
        'variable': (conditional['variable'] ?? '').toString(),
        'whenTrueType': (conditional['whenTrueType'] ?? 'normal').toString(),
        'whenFalseType': (conditional['whenFalseType'] ?? 'normal').toString(),
        'whenTrueText': (conditional['whenTrueText'] ?? '').toString(),
        'whenFalseText': (conditional['whenFalseText'] ?? '').toString(),
        'whenTrueEmbeds': _normalizeEmbedsPayload(
          conditional['whenTrueEmbeds'],
        ),
        'whenFalseEmbeds': _normalizeEmbedsPayload(
          conditional['whenFalseEmbeds'],
        ),
        'whenTrueNormalComponents': Map<String, dynamic>.from(
          (conditional['whenTrueNormalComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenFalseNormalComponents': Map<String, dynamic>.from(
          (conditional['whenFalseNormalComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenTrueComponents': Map<String, dynamic>.from(
          (conditional['whenTrueComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenFalseComponents': Map<String, dynamic>.from(
          (conditional['whenFalseComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenTrueModal': Map<String, dynamic>.from(
          (conditional['whenTrueModal'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
        'whenFalseModal': Map<String, dynamic>.from(
          (conditional['whenFalseModal'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
      },
    };
  }

  String _workflowSummary() {
    final visibility =
        _responseWorkflow['visibility'] == 'ephemeral' ? 'Ephemeral' : 'Public';
    final autoDefer = _responseWorkflow['autoDeferIfActions'] != false;
    final conditional = Map<String, dynamic>.from(
      (_responseWorkflow['conditional'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
    final conditionEnabled = conditional['enabled'] == true;
    final conditionLabel = conditionEnabled ? 'Condition ON' : 'Condition OFF';

    return '${autoDefer ? 'Auto defer if actions' : 'No auto defer'} • $visibility • $conditionLabel';
  }
}
