import 'dart:convert';

import 'package:http/http.dart' as http;

/// Status returned by the runner API.
class RunnerStatus {
  const RunnerStatus({
    required this.running,
    this.activeBotId,
    this.activeBotName,
  });

  final bool running;
  final String? activeBotId;
  final String? activeBotName;

  factory RunnerStatus.fromJson(Map<String, dynamic> json) {
    return RunnerStatus(
      running: (json['running'] as bool?) ?? false,
      activeBotId: json['activeBotId'] as String?,
      activeBotName: json['activeBotName'] as String?,
    );
  }
}

/// Runtime metrics returned by the runner API.
class RunnerMetrics {
  const RunnerMetrics({
    required this.running,
    this.activeBotId,
    this.rssBytes,
    this.baselineRssBytes,
    this.botEstimatedRssBytes,
    this.cpuPercent,
    this.storageBytes,
  });

  final bool running;
  final String? activeBotId;
  final int? rssBytes;
  final int? baselineRssBytes;
  final int? botEstimatedRssBytes;
  final double? cpuPercent;
  final int? storageBytes;

  factory RunnerMetrics.fromJson(Map<String, dynamic> json) {
    return RunnerMetrics(
      running: json['running'] == true,
      activeBotId: json['activeBotId']?.toString(),
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
  RunnerClient({required String baseUrl, http.Client? httpClient})
    : _baseUrl =
          baseUrl.trimRight().endsWith('/')
              ? baseUrl.trimRight().substring(0, baseUrl.trimRight().length - 1)
              : baseUrl.trimRight(),
      _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

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
  }) async {
    final response = await _http
        .get(_uri(path, query: query))
        .timeout(const Duration(seconds: 10));
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _http
        .post(
          _uri(path),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _parseResponse(response);
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
      final json = await _get('/health');
      return json['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Returns the current runner status (running, activeBotId, activeBotName).
  Future<RunnerStatus> getStatus() async {
    final json = await _get('/status');
    return RunnerStatus.fromJson(json);
  }

  /// Returns process/runtime metrics from the runner.
  Future<RunnerMetrics> getMetrics() async {
    final json = await _get('/metrics');
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
    final json = await _post('/runner/start', <String, dynamic>{
      'botId': botId,
      if (botName != null && botName.isNotEmpty) 'botName': botName,
    });
    return RunnerStatus.fromJson(json);
  }

  /// Stops the currently running bot on the runner.
  Future<RunnerStatus> stopBot() async {
    final json = await _post('/runner/stop', const <String, dynamic>{});
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
