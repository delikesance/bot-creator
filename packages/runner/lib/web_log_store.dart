import 'dart:io';

import 'package:logging/logging.dart';

class RunnerLogStore {
  RunnerLogStore({this.maxEntries = 500, String? filePath})
    : _filePath =
          (filePath ??
                  Platform.environment['BOT_CREATOR_RUNNER_LOG_FILE'] ??
                  '/data/logs/runner.log')
              .trim() {
    _initializeFile();
  }

  final int maxEntries;
  final String _filePath;
  final List<String> _entries = <String>[];
  File? _file;

  List<String> tail({int limit = 200}) {
    final safeLimit = limit <= 0 ? 1 : limit;
    if (_entries.length <= safeLimit) {
      return List<String>.from(_entries);
    }
    return List<String>.from(_entries.sublist(_entries.length - safeLimit));
  }

  void add(LogRecord record) {
    final timestamp = record.time.toUtc().toIso8601String();
    final errorPart = record.error == null ? '' : ' | ${record.error}';
    final line =
        '[$timestamp] [${record.level.name}] ${record.loggerName}: ${record.message}$errorPart';

    _entries.add(line);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }

    final file = _file;
    if (file == null) {
      return;
    }

    try {
      file.writeAsStringSync('$line\n', mode: FileMode.append, flush: false);
    } catch (_) {}
  }

  void _initializeFile() {
    if (_filePath.isEmpty) {
      return;
    }

    try {
      final file = File(_filePath);
      file.parent.createSync(recursive: true);
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
      _file = file;
    } catch (_) {
      _file = null;
    }
  }
}
