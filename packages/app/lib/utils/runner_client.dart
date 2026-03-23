import 'dart:convert';

import 'package:http/http.dart' as http;

class RunnerBotRuntime {
  const RunnerBotRuntime({
    required this.botId,
    required this.botName,
    required this.state,
    this.lastSeenAt,
    this.lastError,
    this.baselineRssBytes,
  });

  final String botId;
  final String botName;
  final String state;
  final DateTime? lastSeenAt;
  final String? lastError;
  final int? baselineRssBytes;

  bool get isRunning => state == 'running';

  factory RunnerBotRuntime.fromJson(Map<String, dynamic> json) {
    final rawLastSeenAt = json['lastSeenAt']?.toString();
    return RunnerBotRuntime(
      botId: (json['botId'] ?? '').toString(),
      botName:
          ((json['botName'] ?? '').toString()).trim().isEmpty
              ? (json['botId'] ?? '').toString()
              : json['botName'].toString(),
      state: (json['state'] ?? 'stopped').toString(),
      lastSeenAt:
          (rawLastSeenAt == null || rawLastSeenAt.isEmpty)
              ? null
              : DateTime.tryParse(rawLastSeenAt),
      lastError: json['lastError']?.toString(),
      baselineRssBytes: _asInt(json['baselineRssBytes']),
    );
  }
}

/// Status returned by the runner API.
class RunnerStatus {
  const RunnerStatus({
    required this.running,
    required this.bots,
    this.activeBotId,
    this.activeBotName,
  });

  final bool running;
  final List<RunnerBotRuntime> bots;
  final String? activeBotId;
  final String? activeBotName;

  bool isBotRunning(String botId) =>
      bots.any((bot) => bot.botId == botId && bot.isRunning);

  factory RunnerStatus.fromJson(Map<String, dynamic> json) {
    final bots = _parseBotRuntimeList(json['bots']);
    final firstRunning = bots
        .where((bot) => bot.isRunning)
        .cast<RunnerBotRuntime?>()
        .firstWhere((bot) => bot != null, orElse: () => null);
    return RunnerStatus(
      running: (json['running'] as bool?) ?? bots.any((bot) => bot.isRunning),
      bots: bots,
      activeBotId: json['activeBotId']?.toString() ?? firstRunning?.botId,
      activeBotName: json['activeBotName']?.toString() ?? firstRunning?.botName,
    );
  }
}

/// Runtime metrics returned by the runner API.
class RunnerMetrics {
  const RunnerMetrics({
    required this.running,
    required this.bots,
    this.activeBotId,
    this.rssBytes,
    this.baselineRssBytes,
    this.botEstimatedRssBytes,
    this.cpuPercent,
    this.storageBytes,
  });

  final bool running;
  final List<RunnerBotRuntime> bots;
  final String? activeBotId;
  final int? rssBytes;
  final int? baselineRssBytes;
  final int? botEstimatedRssBytes;
  final double? cpuPercent;
  final int? storageBytes;

  factory RunnerMetrics.fromJson(Map<String, dynamic> json) {
    final bots = _parseBotRuntimeList(json['bots']);
    final firstRunning = bots
        .where((bot) => bot.isRunning)
        .cast<RunnerBotRuntime?>()
        .firstWhere((bot) => bot != null, orElse: () => null);
    return RunnerMetrics(
      running: json['running'] == true,
      bots: bots,
      activeBotId: json['activeBotId']?.toString() ?? firstRunning?.botId,
      rssBytes: _asInt(json['rssBytes']),
      baselineRssBytes: _asInt(json['baselineRssBytes']),
      botEstimatedRssBytes: _asInt(json['botEstimatedRssBytes']),
      cpuPercent: _asDouble(json['cpuPercent']),
      storageBytes: _asInt(json['storageBytes']),
    );
  }
}

/// Summary of a bot that has been synced to the runner.
class RunnerBotSummary {
  const RunnerBotSummary({
    required this.id,
    required this.name,
    required this.syncedAt,
  });

  final String id;
  final String name;
  final DateTime syncedAt;

  factory RunnerBotSummary.fromJson(Map<String, dynamic> json) {
    return RunnerBotSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      syncedAt: DateTime.parse(json['syncedAt'] as String),
    );
  }
}

/// HTTP client for the Bot Creator Runner REST API.
///
/// All methods throw a [RunnerClientException] if the server returns an error
/// or if the request fails.
class RunnerClient {
  RunnerClient({
    required String baseUrl,
    String? apiToken,
    http.Client? httpClient,
    Duration? getTimeout,
    Duration? postTimeout,
  }) : _getTimeout = getTimeout ?? const Duration(seconds: 10),
       _postTimeout = postTimeout ?? const Duration(seconds: 30),
       _apiToken = _normalizeOptional(apiToken),
       _baseUrl =
           baseUrl.trimRight().endsWith('/')
               ? baseUrl.trimRight().substring(
                 0,
                 baseUrl.trimRight().length - 1,
               )
               : baseUrl.trimRight(),
       _http = httpClient ?? http.Client();

  final String _baseUrl;
  final String? _apiToken;
  final http.Client _http;
  final Duration _getTimeout;
  final Duration _postTimeout;

  Uri _uri(String path, {Map<String, String?>? query}) {
    final uri = Uri.parse('$_baseUrl$path');
    if (query == null) return uri;
    final params = <String, String>{};
    for (final entry in query.entries) {
      if (entry.value != null) params[entry.key] = entry.value!;
    }
    return uri.replace(queryParameters: params);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String?>? query,
    bool includeAuth = true,
  }) async {
    final response = await _http
        .get(
          _uri(path, query: query),
          headers: _headers(includeAuth: includeAuth),
        )
        .timeout(_getTimeout);
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    final response = await _http
        .post(
          _uri(path),
          headers: _headers(includeAuth: includeAuth),
          body: jsonEncode(body),
        )
        .timeout(_postTimeout);
    return _parseResponse(response);
  }

  Map<String, String> _headers({required bool includeAuth}) {
    final headers = <String, String>{'content-type': 'application/json'};
    if (includeAuth && _apiToken != null) {
      headers['authorization'] = 'Bearer $_apiToken';
    }
    return headers;
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json =
          decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
    } catch (_) {
      json = <String, dynamic>{};
    }

    if (response.statusCode >= 400) {
      final error =
          (json['error'] ?? response.reasonPhrase ?? 'Unknown error')
              .toString();
      throw RunnerClientException(error, statusCode: response.statusCode);
    }
    return json;
  }

  /// Checks that the runner is reachable and responding.
  Future<bool> checkHealth() async {
    try {
      final json = await _get('/health', includeAuth: false);
      return json['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Returns the current runner status.
  ///
  /// If [botId] is provided, this calls `/bots/{botId}/status` and adapts
  /// the response shape to [RunnerStatus].
  Future<RunnerStatus> getStatus({String? botId}) async {
    if (botId == null || botId.trim().isEmpty) {
      final json = await _get('/status');
      return RunnerStatus.fromJson(json);
    }

    final json = await _get(
      '/bots/${Uri.encodeComponent(botId.trim())}/status',
    );
    final bot = json['bot'];
    if (bot is Map) {
      return RunnerStatus.fromJson(<String, dynamic>{
        'running': (bot['state'] ?? '').toString() == 'running',
        'bots': <dynamic>[bot],
      });
    }
    return const RunnerStatus(running: false, bots: <RunnerBotRuntime>[]);
  }

  /// Returns process/runtime metrics from the runner.
  ///
  /// If [botId] is provided, this calls `/bots/{botId}/metrics`.
  Future<RunnerMetrics> getMetrics({String? botId}) async {
    final path =
        (botId == null || botId.trim().isEmpty)
            ? '/metrics'
            : '/bots/${Uri.encodeComponent(botId.trim())}/metrics';
    final json = await _get(path);
    return RunnerMetrics.fromJson(json);
  }

  /// Returns the list of bots that have been synced to this runner.
  Future<List<RunnerBotSummary>> listBots() async {
    final json = await _get('/bots');
    final rawBots = json['bots'];
    if (rawBots is! List) return const [];
    return rawBots
        .whereType<Map>()
        .map((e) => RunnerBotSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Pushes a complete bot configuration to the runner and persists it.
  Future<void> syncBot(
    String botId,
    String botName,
    Map<String, dynamic> configJson,
  ) async {
    await _post('/bots/sync', <String, dynamic>{
      'botId': botId,
      'botName': botName,
      'config': configJson,
    });
  }

  /// Starts the bot identified by [botId] on the runner.
  ///
  /// The bot must have been synced beforehand via [syncBot].
  Future<RunnerStatus> startBot(String botId, {String? botName}) async {
    final json = await _post(
      '/bots/${Uri.encodeComponent(botId)}/start',
      <String, dynamic>{
        if (botName != null && botName.isNotEmpty) 'botName': botName,
      },
    );
    return RunnerStatus.fromJson(json);
  }

  /// Stops the bot identified by [botId] on the runner.
  Future<RunnerStatus> stopBot(String botId) async {
    final normalizedBotId = botId.trim();
    if (normalizedBotId.isEmpty) {
      throw const RunnerClientException('Missing botId for stopBot().');
    }

    final json = await _post(
      '/bots/${Uri.encodeComponent(normalizedBotId)}/stop',
      const <String, dynamic>{},
    );
    return RunnerStatus.fromJson(json);
  }

  /// Fetches recent log lines from the runner.
  ///
  /// [limit] controls the maximum number of lines returned (default: 300).
  Future<List<String>> getLogs({int limit = 300}) async {
    final json = await _get('/logs', query: {'limit': limit.toString()});
    final rawLines = json['lines'];
    if (rawLines is! List) return const [];
    return rawLines.map((e) => e.toString()).toList(growable: false);
  }
}

/// Exception thrown by [RunnerClient] when the runner returns an error or
/// when the request fails.
class RunnerClientException implements Exception {
  const RunnerClientException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode != null
          ? 'RunnerClientException($statusCode): $message'
          : 'RunnerClientException: $message';
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse((value ?? '').toString());
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString());
}

List<RunnerBotRuntime> _parseBotRuntimeList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (entry) => RunnerBotRuntime.fromJson(Map<String, dynamic>.from(entry)),
      )
      .where((entry) => entry.botId.isNotEmpty)
      .toList(growable: false);
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
