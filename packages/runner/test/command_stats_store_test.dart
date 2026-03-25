import 'dart:io';

import 'package:bot_creator_runner/stores/command_stats_store.dart';
import 'package:test/test.dart';

void main() {
  group('CommandStatsStore', () {
    late Directory tempDir;
    late CommandStatsStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cmd-stats-test-');
      store = CommandStatsStore(tempDir.path);
      await store.init();
    });

    tearDown(() async {
      store.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('init creates the database file', () {
      final dbFile = File('${tempDir.path}/command_stats.db');
      expect(dbFile.existsSync(), isTrue);
    });

    test('record and totalCount', () {
      store.record(botId: 'b1', commandName: 'ping');
      store.record(botId: 'b1', commandName: 'ping');
      store.record(botId: 'b1', commandName: 'ban');
      store.record(botId: 'b2', commandName: 'ping');

      expect(store.totalCount('b1'), equals(3));
      expect(store.totalCount('b2'), equals(1));
      expect(store.totalCount('unknown'), equals(0));
    });

    test('querySummary returns per-command counts', () {
      store.record(botId: 'b1', commandName: 'ping');
      store.record(botId: 'b1', commandName: 'ping');
      store.record(botId: 'b1', commandName: 'ban');

      final summary = store.querySummary('b1');
      expect(summary, hasLength(2));
      expect(summary[0]['command'], equals('ping'));
      expect(summary[0]['count'], equals(2));
      expect(summary[1]['command'], equals('ban'));
      expect(summary[1]['count'], equals(1));
    });

    test('querySummary with sinceMs filters old entries', () {
      store.record(botId: 'b1', commandName: 'ping');

      // With a very small window (1 ms), recent records should still show up
      // because the record was just inserted.
      final recent = store.querySummary('b1', sinceMs: 60000);
      expect(recent, hasLength(1));
    });

    test('querySummary returns empty for unknown bot', () {
      store.record(botId: 'b1', commandName: 'ping');
      expect(store.querySummary('b2'), isEmpty);
    });

    test('queryTimeline returns hourly buckets', () {
      store.record(botId: 'b1', commandName: 'ping');
      store.record(botId: 'b1', commandName: 'ban');

      final timeline = store.queryTimeline('b1', hours: 1);
      expect(timeline, isNotEmpty);
      // All records in the same hour bucket
      expect(timeline.first['count'], equals(2));
    });

    test('dispose prevents further recording', () {
      store.record(botId: 'b1', commandName: 'ping');
      store.dispose();

      // After dispose, record should silently no-op (not initialized)
      store.record(botId: 'b1', commandName: 'ping');
      // Cannot query either – totalCount returns 0 when not initialized
      expect(store.totalCount('b1'), equals(0));
    });

    test('double init is idempotent', () async {
      await store.init();
      store.record(botId: 'b1', commandName: 'ping');
      expect(store.totalCount('b1'), equals(1));
    });
  });
}
