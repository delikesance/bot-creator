import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_runner/runner_runtime_controller.dart';
import 'package:bot_creator_runner/web_log_store.dart';

class _CpuSample {
  const _CpuSample({required this.jiffies, required this.timestampMs});

  final int jiffies;
  final int timestampMs;
}

/// HTTP API server for the Bot Creator Runner.
///
/// All endpoints return JSON. There is no authentication in MVP.
///
/// Endpoints
/// ---------
/// GET  /health              → {ok: true}
/// GET  /status              → {running, activeBotId, activeBotName}
/// GET  /metrics             → {running, activeBotId, rssBytes, baselineRssBytes, botEstimatedRssBytes, cpuPercent, storageBytes}
/// GET  /bots                → [{id, name, syncedAt}]
/// POST /bots/sync           → body: {botId, botName?, config: {...}}
///                           → {ok: true}
/// POST /runner/start        → body: {botId}  → status payload
/// POST /runner/stop         → status payload
/// GET  /logs?limit=N        → {lines: [string]}
class RunnerWebBootstrapServer {
  RunnerWebBootstrapServer({
    required this.host,
    required this.port,
    required this.logStore,
  }) : _runtimeController = RunnerRuntimeController();

  final String host;
  final int port;
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
      ..set('access-control-allow-headers', 'content-type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    try {
      if (request.method == 'GET') {
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
        switch (path) {
          case '/bots/sync':
            await _handleBotsSync(request);
            return;
          case '/runner/start':
            await _handleRunnerStart(request);
            return;
          case '/runner/stop':
            await _handleRunnerStop(request);
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

  /// POST /runner/start — start a previously synced bot.
  Future<void> _handleRunnerStart(HttpRequest request) async {
    final payload = await _readJsonBody(request);
    final botId = (payload['botId'] ?? '').toString().trim();
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

  /// POST /runner/stop — stop the running bot.
  Future<void> _handleRunnerStop(HttpRequest request) async {
    await _runtimeController.stopBot();
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

  /// GET /metrics — return process/runtime metrics for the active runner.
  Future<void> _handleMetrics(HttpRequest request) async {
    final running = _runtimeController.isRunning;
    final rss = running ? _readCurrentProcessRssBytes() : null;
    final baseline = running ? _runtimeController.baselineRssBytes : null;
    final estimated =
        (rss != null && baseline != null)
            ? (rss - baseline).clamp(0, rss)
            : null;

    await _respondJson(request, <String, dynamic>{
      'running': running,
      'activeBotId': _runtimeController.activeBotId,
      'rssBytes': rss,
      'baselineRssBytes': baseline,
      'botEstimatedRssBytes': estimated,
      'cpuPercent': running ? _readCurrentProcessCpuPercent() : null,
      'storageBytes': null,
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

  Map<String, dynamic> _buildStatusPayload() => <String, dynamic>{
    'running': _runtimeController.isRunning,
    'activeBotId': _runtimeController.activeBotId,
    'activeBotName': _runtimeController.activeBotName,
  };

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
