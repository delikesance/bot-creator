import 'dart:async';

class MobileSessionsOrchestrator {
  Future<void> _queue = Future<void>.value();

  Future<T> runSerialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
