import 'dart:convert';

class _ResolvedExpression {
  const _ResolvedExpression({required this.found, this.value});

  final bool found;
  final dynamic value;
}

List<Object>? _parseJsonPathSegments(String rawPath) {
  var path = rawPath.trim();
  if (path.isEmpty) {
    return null;
  }

  if (path.startsWith(r'$.')) {
    path = path.substring(2);
  } else if (path.startsWith(r'$')) {
    path = path.substring(1);
  }

  if (path.isEmpty) {
    return const <Object>[];
  }

  final segments = <Object>[];
  final token = StringBuffer();

  void flushToken() {
    if (token.isNotEmpty) {
      segments.add(token.toString());
      token.clear();
    }
  }

  for (var index = 0; index < path.length; index++) {
    final char = path[index];
    if (char == '.') {
      flushToken();
      continue;
    }

    if (char == '[') {
      flushToken();
      final closing = path.indexOf(']', index + 1);
      if (closing == -1) {
        return null;
      }
      final indexText = path.substring(index + 1, closing).trim();
      final listIndex = int.tryParse(indexText);
      if (listIndex == null) {
        return null;
      }
      segments.add(listIndex);
      index = closing;
      continue;
    }

    token.write(char);
  }

  flushToken();
  return segments;
}

List<Object>? parseJsonPathSegments(String rawPath) {
  return _parseJsonPathSegments(rawPath);
}

dynamic extractJsonPathValue(dynamic data, String rawPath) {
  final segments = _parseJsonPathSegments(rawPath);
  if (segments == null) {
    return null;
  }

  dynamic current = data;
  for (final segment in segments) {
    if (segment is String) {
      if (segment.isEmpty) {
        continue;
      }
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
      continue;
    }

    if (segment is int) {
      if (current is List && segment >= 0 && segment < current.length) {
        current = current[segment];
      } else {
        return null;
      }
    }
  }

  return current;
}

String _stringifyResolvedValue(dynamic value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  return jsonEncode(value);
}

dynamic decodeJsonStringIfNeeded(dynamic value) {
  if (value is! String) {
    return value;
  }

  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return value;
  }

  final looksJson =
      (trimmed.startsWith('[') && trimmed.endsWith(']')) ||
      (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      trimmed == 'null';
  if (!looksJson) {
    return value;
  }

  try {
    return jsonDecode(trimmed);
  } catch (_) {
    return value;
  }
}

String? _lookupVariableValue(String key, Map<String, String> updates) {
  if (updates.containsKey(key)) {
    return updates[key];
  }

  final loweredKey = key.toLowerCase();
  for (final entry in updates.entries) {
    if (entry.key.toLowerCase() == loweredKey) {
      return entry.value;
    }
  }

  return null;
}

dynamic _resolveComputedVariableValue(String key, Map<String, String> updates) {
  final markerIndex = key.lastIndexOf('.\$');
  if (markerIndex == -1) {
    return null;
  }

  final bodyVariableKey = key.substring(0, markerIndex);
  final jsonPathRaw = key.substring(markerIndex + 1);
  if (!jsonPathRaw.startsWith(r'$')) {
    return null;
  }

  final rawBody = _lookupVariableValue(bodyVariableKey, updates);
  if (rawBody == null || rawBody.isEmpty) {
    return null;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(rawBody);
  } catch (_) {
    return null;
  }

  return extractJsonPathValue(decoded, jsonPathRaw);
}

List<String> _splitTopLevel(String input, String delimiter) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  String? quote;
  var escaping = false;

  for (var index = 0; index < input.length; index++) {
    final char = input[index];

    if (quote != null) {
      buffer.write(char);
      if (escaping) {
        escaping = false;
      } else if (char == r'\') {
        escaping = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }

    if (char == '"' || char == "'") {
      quote = char;
      buffer.write(char);
      continue;
    }

    if (char == '(') {
      depth++;
      buffer.write(char);
      continue;
    }

    if (char == ')') {
      if (depth > 0) {
        depth--;
      }
      buffer.write(char);
      continue;
    }

    if (depth == 0 && input.startsWith(delimiter, index)) {
      parts.add(buffer.toString());
      buffer.clear();
      index += delimiter.length - 1;
      continue;
    }

    buffer.write(char);
  }

  parts.add(buffer.toString());
  return parts;
}

String _unescapeStringLiteral(String body) {
  final buffer = StringBuffer();
  for (var index = 0; index < body.length; index++) {
    final char = body[index];
    if (char != r'\' || index + 1 >= body.length) {
      buffer.write(char);
      continue;
    }

    final next = body[++index];
    switch (next) {
      case 'n':
        buffer.write('\n');
        break;
      case 'r':
        buffer.write('\r');
        break;
      case 't':
        buffer.write('\t');
        break;
      case r'\':
        buffer.write(r'\');
        break;
      case '"':
        buffer.write('"');
        break;
      case "'":
        buffer.write("'");
        break;
      default:
        buffer
          ..write(r'\')
          ..write(next);
        break;
    }
  }
  return buffer.toString();
}

bool _isWrappedStringLiteral(String input) {
  if (input.length < 2) {
    return false;
  }
  final quote = input[0];
  if ((quote != '"' && quote != "'") || input[input.length - 1] != quote) {
    return false;
  }

  var escaping = false;
  for (var index = 1; index < input.length - 1; index++) {
    final char = input[index];
    if (escaping) {
      escaping = false;
      continue;
    }
    if (char == r'\') {
      escaping = true;
      continue;
    }
    if (char == quote) {
      return false;
    }
  }

  return true;
}

({String name, String inner})? _parseFunctionCall(String expression) {
  final openIndex = expression.indexOf('(');
  if (openIndex <= 0 || !expression.endsWith(')')) {
    return null;
  }

  final name = expression.substring(0, openIndex).trim();
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
    return null;
  }

  var depth = 0;
  String? quote;
  var escaping = false;
  for (var index = openIndex; index < expression.length; index++) {
    final char = expression[index];

    if (quote != null) {
      if (escaping) {
        escaping = false;
      } else if (char == r'\') {
        escaping = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }

    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }

    if (char == '(') {
      depth++;
      continue;
    }

    if (char == ')') {
      depth--;
      if (depth == 0 && index != expression.length - 1) {
        return null;
      }
      if (depth < 0) {
        return null;
      }
    }
  }

  if (depth != 0) {
    return null;
  }

  return (
    name: name,
    inner: expression.substring(openIndex + 1, expression.length - 1),
  );
}

int? _coerceInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_stringifyResolvedValue(value).trim());
}

bool _coerceBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }

  final text = _stringifyResolvedValue(value).trim().toLowerCase();
  if (text == 'true') {
    return true;
  }
  if (text == 'false') {
    return false;
  }
  return fallback;
}

List<dynamic>? _coerceList(dynamic value) {
  final decoded = decodeJsonStringIfNeeded(value);
  if (decoded is List) {
    return List<dynamic>.from(decoded);
  }
  return null;
}

const Set<String> _discordMediaFormats = <String>{
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
};

String _normalizeDiscordMediaFormat(dynamic value, {String fallback = 'webp'}) {
  final normalized = _stringifyResolvedValue(value).trim().toLowerCase();
  if (_discordMediaFormats.contains(normalized)) {
    return normalized;
  }
  return fallback;
}

int _normalizeDiscordMediaSize(dynamic value, {int fallback = 1024}) {
  final parsed = _coerceInt(value) ?? fallback;
  final bounded = parsed.clamp(16, 4096);
  return bounded;
}

String _applyDiscordMediaOptions(
  dynamic rawUrl, {
  dynamic format,
  dynamic size,
}) {
  final source = _stringifyResolvedValue(rawUrl).trim();
  if (source.isEmpty) {
    return '';
  }

  final uri = Uri.tryParse(source);
  if (uri == null) {
    return source;
  }

  final normalizedFormat = _normalizeDiscordMediaFormat(format);
  final normalizedSize = _normalizeDiscordMediaSize(size);
  final segments = List<String>.from(uri.pathSegments);
  if (segments.isNotEmpty) {
    final last = segments.last;
    final dotIndex = last.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < last.length - 1) {
      segments[segments.length - 1] =
          '${last.substring(0, dotIndex)}.$normalizedFormat';
    }
  }

  final queryParameters = Map<String, String>.from(uri.queryParameters);
  queryParameters['size'] = normalizedSize.toString();

  return uri
      .replace(pathSegments: segments, queryParameters: queryParameters)
      .toString();
}

String _resolveItemPlaceholderValue(dynamic item, String rawPath) {
  final path = rawPath.trim();
  if (path.isEmpty) {
    return '';
  }

  if (path == 'value') {
    return _stringifyResolvedValue(item);
  }

  final composedPath =
      path.startsWith(r'$')
          ? path
          : path.startsWith('[')
          ? '\$$path'
          : '\$.$path';
  return _stringifyResolvedValue(extractJsonPathValue(item, composedPath));
}

String resolveItemTemplate(
  String template,
  dynamic item,
  Map<String, String> updates,
) {
  final interpolated = template.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (
    match,
  ) {
    return _resolveItemPlaceholderValue(item, match.group(1)!);
  });
  return resolveTemplatePlaceholders(interpolated, updates);
}

dynamic _applyFunction(
  String rawName,
  List<dynamic> args,
  Map<String, String> updates,
) {
  final name = rawName.trim().toLowerCase();
  switch (name) {
    case 'length':
      if (args.isEmpty) {
        return null;
      }
      final value = decodeJsonStringIfNeeded(args.first);
      if (value is List || value is Map || value is String) {
        return value.length;
      }
      return null;
    case 'at':
      if (args.length < 2) {
        return null;
      }
      final source = _coerceList(args[0]);
      final index = _coerceInt(args[1]);
      if (source == null || index == null) {
        return null;
      }
      if (index < 0 || index >= source.length) {
        return null;
      }
      return source[index];
    case 'slice':
      if (args.length < 2) {
        return null;
      }
      final start = _coerceInt(args[1]);
      if (start == null) {
        return null;
      }
      final end = args.length >= 3 ? _coerceInt(args[2]) : null;

      final sourceList = _coerceList(args[0]);
      if (sourceList != null) {
        final safeStart = start.clamp(0, sourceList.length);
        final safeEnd = (end ?? sourceList.length).clamp(
          safeStart,
          sourceList.length,
        );
        return sourceList.sublist(safeStart, safeEnd);
      }

      final sourceString = _stringifyResolvedValue(args[0]);
      if (sourceString.isEmpty) {
        return '';
      }
      final safeStart = start.clamp(0, sourceString.length);
      final safeEnd = (end ?? sourceString.length).clamp(
        safeStart,
        sourceString.length,
      );
      return sourceString.substring(safeStart, safeEnd);
    case 'join':
      if (args.length < 2) {
        return null;
      }
      final source = _coerceList(args[0]);
      if (source == null) {
        return null;
      }
      final separator = _stringifyResolvedValue(args[1]);
      return source.map(_stringifyResolvedValue).join(separator);
    case 'formateach':
      if (args.length < 3) {
        return null;
      }
      final source = _coerceList(args[0]);
      if (source == null) {
        return null;
      }
      final itemTemplate = _stringifyResolvedValue(args[1]);
      final separator = _stringifyResolvedValue(args[2]);
      return source
          .map((item) => resolveItemTemplate(itemTemplate, item, updates))
          .join(separator);
    case 'embedfields':
      if (args.length < 3) {
        return null;
      }
      final source = _coerceList(args[0]);
      if (source == null) {
        return null;
      }
      final nameTemplate = _stringifyResolvedValue(args[1]);
      final valueTemplate = _stringifyResolvedValue(args[2]);
      final isInline = args.length >= 4 ? _coerceBool(args[3]) : false;
      final fields = <Map<String, dynamic>>[];
      for (final item in source) {
        final fieldName = resolveItemTemplate(nameTemplate, item, updates);
        final fieldValue = resolveItemTemplate(valueTemplate, item, updates);
        if (fieldName.isEmpty || fieldValue.isEmpty) {
          continue;
        }
        fields.add(<String, dynamic>{
          'name': fieldName,
          'value': fieldValue,
          'inline': isInline,
        });
      }
      return fields;
    case 'avatar':
      if (args.isEmpty) {
        return null;
      }
      return _applyDiscordMediaOptions(
        args.first,
        format: args.length >= 2 ? args[1] : 'webp',
        size: args.length >= 3 ? args[2] : 1024,
      );
    case 'banner':
      if (args.isEmpty) {
        return null;
      }
      return _applyDiscordMediaOptions(
        args.first,
        format: args.length >= 2 ? args[1] : 'webp',
        size: args.length >= 3 ? args[2] : 1024,
      );
    default:
      return null;
  }
}

_ResolvedExpression _evaluateSingleExpression(
  String expression,
  Map<String, String> updates,
) {
  final trimmed = expression.trim();
  if (trimmed.isEmpty) {
    return const _ResolvedExpression(found: true, value: '');
  }

  if (_isWrappedStringLiteral(trimmed)) {
    return _ResolvedExpression(
      found: true,
      value: _unescapeStringLiteral(trimmed.substring(1, trimmed.length - 1)),
    );
  }

  if (trimmed == 'null') {
    return const _ResolvedExpression(found: true, value: null);
  }
  if (trimmed == 'true') {
    return const _ResolvedExpression(found: true, value: true);
  }
  if (trimmed == 'false') {
    return const _ResolvedExpression(found: true, value: false);
  }

  final number = num.tryParse(trimmed);
  if (number != null) {
    return _ResolvedExpression(found: true, value: number);
  }

  final functionCall = _parseFunctionCall(trimmed);
  if (functionCall != null) {
    final args = _splitTopLevel(functionCall.inner, ',');
    final resolvedArgs = <dynamic>[];
    for (final arg in args) {
      final outcome = _evaluateExpression(arg, updates);
      if (!outcome.found) {
        return const _ResolvedExpression(found: false);
      }
      resolvedArgs.add(outcome.value);
    }
    final value = _applyFunction(functionCall.name, resolvedArgs, updates);
    if (value == null && functionCall.name.trim().toLowerCase() != 'length') {
      return const _ResolvedExpression(found: false);
    }
    return _ResolvedExpression(found: true, value: value);
  }

  final direct = _lookupVariableValue(trimmed, updates);
  if (direct != null) {
    return _ResolvedExpression(found: true, value: direct);
  }

  final computed = _resolveComputedVariableValue(trimmed, updates);
  if (computed != null) {
    return _ResolvedExpression(found: true, value: computed);
  }

  return const _ResolvedExpression(found: false);
}

_ResolvedExpression _evaluateExpression(
  String expression,
  Map<String, String> updates,
) {
  final candidates = _splitTopLevel(expression, '|');
  if (candidates.length <= 1) {
    return _evaluateSingleExpression(expression, updates);
  }

  for (final candidate in candidates) {
    final outcome = _evaluateSingleExpression(candidate, updates);
    if (outcome.found) {
      return outcome;
    }
  }

  return const _ResolvedExpression(found: false);
}

dynamic resolveTemplateExpressionValue(
  String expression,
  Map<String, String> updates,
) {
  final outcome = _evaluateExpression(expression, updates);
  if (!outcome.found) {
    return null;
  }
  return outcome.value;
}

String resolveTemplateExpressionToString(
  String expression,
  Map<String, String> updates,
) {
  return _stringifyResolvedValue(
    resolveTemplateExpressionValue(expression, updates),
  );
}

String resolveTemplatePlaceholders(
  String initial,
  Map<String, String> updates,
) {
  if (initial.isEmpty) {
    return initial;
  }

  final buffer = StringBuffer();
  var index = 0;
  while (index < initial.length) {
    final start = initial.indexOf('((', index);
    if (start == -1) {
      buffer.write(initial.substring(index));
      break;
    }

    buffer.write(initial.substring(index, start));
    var cursor = start + 2;
    var depth = 0;
    String? quote;
    var escaping = false;
    var foundClosing = false;

    while (cursor < initial.length) {
      final char = initial[cursor];

      if (quote != null) {
        if (escaping) {
          escaping = false;
        } else if (char == r'\') {
          escaping = true;
        } else if (char == quote) {
          quote = null;
        }
        cursor++;
        continue;
      }

      if (char == '"' || char == "'") {
        quote = char;
        cursor++;
        continue;
      }

      if (char == '(') {
        depth++;
        cursor++;
        continue;
      }

      if (char == ')') {
        if (depth > 0) {
          depth--;
          cursor++;
          continue;
        }
        if (cursor + 1 < initial.length && initial[cursor + 1] == ')') {
          final expression = initial.substring(start + 2, cursor);
          buffer.write(resolveTemplateExpressionToString(expression, updates));
          index = cursor + 2;
          foundClosing = true;
          break;
        }
      }

      cursor++;
    }

    if (!foundClosing) {
      buffer.write(initial.substring(start));
      break;
    }
  }

  return buffer.toString();
}
