import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_runner/runner_runtime_controller.dart';
import 'package:bot_creator_runner/web_log_store.dart';
import 'package:bot_creator_runner/web_runtime_config.dart';

class _CpuSample {
  const _CpuSample({required this.jiffies, required this.timestampMs});

  final int jiffies;
  final int timestampMs;
}

/// HTTP API server for the Bot Creator Runner.
///
/// All endpoints return JSON. `/health` stays public; protected endpoints use
/// bearer auth when an API token is configured.
///
/// Endpoints
/// ---------
/// GET  /health              → {ok: true}
/// GET  /status              → {apiVersion, running, runningCount, bots: [...]}
/// GET  /metrics             → process metrics + bot runtime states
/// GET  /bots/{id}/status    → state for one bot
/// GET  /bots/{id}/metrics   → process metrics + one bot state
/// GET  /bots/{id}/command-stats → command usage statistics
/// GET  /bots                → [{id, name, syncedAt}]
/// POST /bots/sync           → body: {botId, botName?, config: {...}}
///                           → {ok: true}
/// POST /bots/{id}/start     → status payload
/// POST /bots/{id}/stop      → status payload
/// GET  /logs?limit=N        → {lines: [string]}
class RunnerWebBootstrapServer {
  RunnerWebBootstrapServer({
    required this.host,
    required this.port,
    String? apiToken,
    required this.logStore,
  }) : _apiToken = normalizeRunnerApiToken(apiToken),
       _runtimeController = RunnerRuntimeController();

  final String host;
  final int port;
  final String _apiToken;
  final RunnerLogStore logStore;

  final RunnerRuntimeController _runtimeController;
  _CpuSample? _lastCpuSample;

  HttpServer? _server;
  final Completer<void> _lifecycleCompleter = Completer<void>();

  String get listenUrl => 'http://$host:$port';

  Future<void> start() async {
    if (_server != null) return;

    _server = await HttpServer.bind(host, port);
    _server!.listen(
      (request) => unawaited(_handleRequest(request)),
      onDone: () {
        if (!_lifecycleCompleter.isCompleted) {
          _lifecycleCompleter.complete();
        }
      },
    );
  }

  Future<void> waitForShutdown() => _lifecycleCompleter.future;

  Future<void> stop() async {
    await _runtimeController.dispose();

    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }

    if (!_lifecycleCompleter.isCompleted) {
      _lifecycleCompleter.complete();
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // CORS headers so future web-based tools can reach this API too.
    request.response.headers
      ..set('access-control-allow-origin', '*')
      ..set('access-control-allow-methods', 'GET, POST, OPTIONS')
      ..set('access-control-allow-headers', 'content-type, authorization');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (_requiresAuthentication(request) && !_isAuthorized(request)) {
      request.response.headers.set(
        HttpHeaders.wwwAuthenticateHeader,
        'Bearer realm="bot-creator-runner"',
      );
      await _respondJson(request, <String, dynamic>{
        'error': 'Missing or invalid bearer token.',
      }, statusCode: HttpStatus.unauthorized);
      return;
    }

    final path = request.uri.path;
    final scopedStartBotId = _extractBotAction(path, action: 'start');
    final scopedStopBotId = _extractBotAction(path, action: 'stop');
    final scopedStatusBotId = _extractBotAction(path, action: 'status');
    final scopedMetricsBotId = _extractBotAction(path, action: 'metrics');
    final scopedStatsBotId = _extractBotAction(path, action: 'command-stats');
    try {
      if (request.method == 'GET') {
        if (scopedStatusBotId != null) {
          await _respondJson(request, <String, dynamic>{
            'apiVersion': 2,
            'bot': _buildBotStatePayload(scopedStatusBotId),
          });
          return;
        }
        if (scopedMetricsBotId != null) {
          await _handleMetrics(request, botId: scopedMetricsBotId);
          return;
        }
        if (scopedStatsBotId != null) {
          await _handleCommandStats(request, scopedStatsBotId);
          return;
        }
        switch (path) {
          case '/health':
            await _respondJson(request, <String, dynamic>{'ok': true});
            return;
          case '/status':
            await _respondJson(request, _buildStatusPayload());
            return;
          case '/metrics':
            await _handleMetrics(request);
            return;
          case '/bots':
            await _handleListBots(request);
            return;
          case '/logs':
            await _handleLogs(request);
            return;
          default:
            _respondText(request, HttpStatus.notFound, 'Not found');
            return;
        }
      }

      if (request.method == 'POST') {
        if (scopedStartBotId != null) {
          await _handleRunnerStart(request, botIdFromPath: scopedStartBotId);
          return;
        }
        if (scopedStopBotId != null) {
          await _handleRunnerStop(request, botIdFromPath: scopedStopBotId);
          return;
        }
        switch (path) {
          case '/bots/sync':
            await _handleBotsSync(request);
            return;
          default:
            _respondText(request, HttpStatus.notFound, 'Not found');
            return;
        }
      }

      _respondText(request, HttpStatus.methodNotAllowed, 'Method not allowed');
    } catch (error, st) {
      stderr.writeln('Unhandled error for ${request.method} $path: $error');
      stderr.writeln(st);
      await _respondJson(request, <String, dynamic>{
        'error': error.toString(),
      }, statusCode: HttpStatus.internalServerError);
    }
  }

  /// GET /bots — list all synced bots.
  Future<void> _handleListBots(HttpRequest request) async {
    final entries = await _runtimeController.botStore.listAll();
    await _respondJson(request, <String, dynamic>{
      'bots': entries
          .map(
            (e) => <String, dynamic>{
              'id': e.id,
              'name': e.name,
              'syncedAt': e.syncedAt.toUtc().toIso8601String(),
            },
          )
          .toList(growable: false),
    });
  }

  /// POST /bots/sync — push and persist a bot config from the app.
  Future<void> _handleBotsSync(HttpRequest request) async {
    final payload = await _readJsonBody(request);
    final botId = (payload['botId'] ?? '').toString().trim();
    final botName = (payload['botName'] ?? '').toString().trim();

    if (botId.isEmpty) {
      await _respondJson(request, <String, dynamic>{
        'error': 'Missing botId.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    final rawConfig = payload['config'];
    if (rawConfig == null || rawConfig is! Map) {
      await _respondJson(request, <String, dynamic>{
        'error': 'Missing or invalid config payload.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    final BotConfig config;
    try {
      config = BotConfig.fromJson(Map<String, dynamic>.from(rawConfig));
      config.validate();
    } catch (e) {
      await _respondJson(request, <String, dynamic>{
        'error': 'Invalid config: $e',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    await _runtimeController.botStore.save(
      botId,
      botName.isEmpty ? botId : botName,
      config,
    );

    await _respondJson(request, <String, dynamic>{'ok': true});
  }

  /// POST /bots/{id}/start — start a previously synced bot.
  Future<void> _handleRunnerStart(
    HttpRequest request, {
    String? botIdFromPath,
  }) async {
    final payload = await _readJsonBody(request);
    final botId = (botIdFromPath ?? payload['botId'] ?? '').toString().trim();
    final botName = (payload['botName'] ?? '').toString().trim();

    if (botId.isEmpty) {
      await _respondJson(request, <String, dynamic>{
        'error': 'Missing botId.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    try {
      await _runtimeController.startBot(
        botId: botId,
        botName: botName.isEmpty ? null : botName,
      );
      await _respondJson(request, _buildStatusPayload());
    } on StateError catch (error) {
      await _respondJson(request, <String, dynamic>{
        'error': error.message,
      }, statusCode: HttpStatus.conflict);
    }
  }

  /// POST /bots/{id}/stop — stop one running bot.
  Future<void> _handleRunnerStop(
    HttpRequest request, {
    String? botIdFromPath,
  }) async {
    final payload = await _readJsonBody(request);
    final botId = (botIdFromPath ?? payload['botId'] ?? '').toString().trim();

    if (botId.isEmpty) {
      await _respondJson(request, <String, dynamic>{
        'error': 'Missing botId.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    await _runtimeController.stopBot(botId);
    await _respondJson(request, _buildStatusPayload());
  }

  /// GET /logs — return recent log lines.
  Future<void> _handleLogs(HttpRequest request) async {
    final limitRaw = request.uri.queryParameters['limit'] ?? '200';
    final parsed = int.tryParse(limitRaw);
    final limit = (parsed == null || parsed <= 0) ? 200 : parsed;
    await _respondJson(request, <String, dynamic>{
      'lines': logStore.tail(limit: limit),
    });
  }

  /// GET /metrics — return process/runtime metrics for the runner process.
  Future<void> _handleMetrics(HttpRequest request, {String? botId}) async {
    final running = _runtimeController.isRunning;
    final rss = running ? _readCurrentProcessRssBytes() : null;
    final cpuPercent = running ? _readCurrentProcessCpuPercent() : null;

    final botPayloads =
        (botId == null)
            ? _runtimeController
                .listRuntimeStates()
                .map(_runtimeStateToPayload)
                .toList(growable: false)
            : <Map<String, dynamic>>[_buildBotStatePayload(botId)];

    await _respondJson(request, <String, dynamic>{
      'apiVersion': 2,
      'running': running,
      'runningCount': _runtimeController.runningCount,
      'rssBytes': rss,
      'cpuPercent': cpuPercent,
      'storageBytes': null,
      'bots': botPayloads,
    });
  }

  int? _readCurrentProcessRssBytes() {
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return null;
    }
  }

  int? _readCurrentProcessCpuJiffies() {
    if (!(Platform.isAndroid || Platform.isLinux)) {
      return null;
    }

    try {
      final stat = File('/proc/self/stat').readAsStringSync();
      final lastParen = stat.lastIndexOf(')');
      if (lastParen == -1 || lastParen + 2 >= stat.length) {
        return null;
      }
      final afterState = stat.substring(lastParen + 2).trim();
      final fields = afterState.split(RegExp(r'\s+'));
      if (fields.length <= 11) {
        return null;
      }

      final utime = int.tryParse(fields[10]);
      final stime = int.tryParse(fields[11]);
      if (utime == null || stime == null) {
        return null;
      }
      return utime + stime;
    } catch (_) {
      return null;
    }
  }

  double? _readCurrentProcessCpuPercent() {
    final jiffies = _readCurrentProcessCpuJiffies();
    if (jiffies == null) {
      return null;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final prev = _lastCpuSample;
    _lastCpuSample = _CpuSample(jiffies: jiffies, timestampMs: nowMs);

    if (prev == null) {
      return 0.0;
    }

    final deltaJiffies = jiffies - prev.jiffies;
    final deltaMs = nowMs - prev.timestampMs;
    if (deltaJiffies <= 0 || deltaMs <= 0) {
      return 0.0;
    }

    const ticksPerSecond = 100.0;
    final elapsedSeconds = deltaMs / 1000.0;
    final cpuSeconds = deltaJiffies / ticksPerSecond;
    final cores = Platform.numberOfProcessors.clamp(1, 64);
    final percent = (cpuSeconds / elapsedSeconds) * 100.0 / cores;
    if (percent.isNaN || percent.isInfinite) {
      return null;
    }
    return percent.clamp(0.0, 100.0);
  }

  Map<String, dynamic> _buildStatusPayload() {
    final bots = _runtimeController
        .listRuntimeStates()
        .map(_runtimeStateToPayload)
        .toList(growable: false);
    return <String, dynamic>{
      'apiVersion': 2,
      'running': _runtimeController.isRunning,
      'runningCount': _runtimeController.runningCount,
      'bots': bots,
    };
  }

  Map<String, dynamic> _buildBotStatePayload(String botId) {
    final state = _runtimeController.runtimeStateForBot(botId);
    return _runtimeStateToPayload(state);
  }

  /// GET /bots/{id}/command-stats — command usage statistics.
  Future<void> _handleCommandStats(HttpRequest request, String botId) async {
    final queryParams = request.uri.queryParameters;
    final hoursRaw = int.tryParse(queryParams['hours'] ?? '');
    final hours = (hoursRaw != null && hoursRaw > 0) ? hoursRaw : 24;
    final sinceMs = hours * 3600000;

    final store = _runtimeController.commandStatsStore;
    final summary = store.querySummary(botId, sinceMs: sinceMs);
    final timeline = store.queryTimeline(botId, hours: hours);
    final total = store.totalCount(botId);

    await _respondJson(request, <String, dynamic>{
      'botId': botId,
      'hours': hours,
      'totalAllTime': total,
      'commands': summary,
      'timeline': timeline,
    });
  }

  Map<String, dynamic> _runtimeStateToPayload(RunnerBotRuntimeState state) {
    return <String, dynamic>{
      'botId': state.botId,
      'botName': state.botName,
      'state': state.state,
      'lastSeenAt': state.lastSeenAt?.toIso8601String(),
      'lastError': state.lastError,
      'baselineRssBytes': state.baselineRssBytes,
    };
  }

  String? _extractBotAction(String path, {required String action}) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length == 3 && parts[0] == 'bots' && parts[2] == action) {
      return Uri.decodeComponent(parts[1]);
    }
    return null;
  }

  bool _requiresAuthentication(HttpRequest request) {
    if (_apiToken.isEmpty) {
      return false;
    }

    return !(request.method == 'GET' && request.uri.path == '/health');
  }

  bool _isAuthorized(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null) {
      return false;
    }

    const prefix = 'Bearer ';
    if (!header.startsWith(prefix)) {
      return false;
    }

    final token = normalizeRunnerApiToken(header.substring(prefix.length));
    return token == _apiToken;
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _respondJson(
    HttpRequest request,
    Map<String, dynamic> payload, {
    int statusCode = HttpStatus.ok,
  }) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set('cache-control', 'no-store');
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }

  void _respondText(HttpRequest request, int statusCode, String text) {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.text;
    request.response.write(text);
    unawaited(request.response.close());
  }
}
