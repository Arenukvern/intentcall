import 'dart:convert';
import 'dart:io';

import 'package:intentcall_session/intentcall_session.dart';
import 'package:test/test.dart';

void main() {
  group('IntentSnapshotStore', () {
    late Directory tempDir;
    late String snapshotsDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('intentcall_snapshots_');
      snapshotsDir = '${tempDir.path}/snapshots';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('saves, loads, and lists JSON snapshots', () async {
      final store = IntentSnapshotStore(snapshotsDir: snapshotsDir);

      final saved = await store.saveSnapshot(
        id: 's1',
        snapshot: const {
          'id': 's1',
          'createdAt': '2026-06-22T00:00:00.000Z',
          'value': {'x': 1},
        },
      );

      expect(saved['path'], equals('$snapshotsDir/s1.json'));
      expect(File('$snapshotsDir/s1.json').existsSync(), isTrue);

      final loaded = await store.loadSnapshot('s1');
      expect(loaded['id'], equals('s1'));
      expect(loaded['path'], isNull);
      expect(loaded['writeResults'], isNull);

      final listed = await store.listSnapshots();
      expect(listed, hasLength(1));
      expect(listed.single['id'], equals('s1'));
      expect(listed.single['path'], equals('$snapshotsDir/s1.json'));
    });

    test('computes structural diffs', () async {
      final store = IntentSnapshotStore(snapshotsDir: snapshotsDir);
      await Directory(snapshotsDir).create(recursive: true);

      await File('$snapshotsDir/a.json').writeAsString(
        jsonEncode({
          'id': 'a',
          'value': {
            'x': 1,
            'list': [1, 2],
          },
        }),
      );
      await File('$snapshotsDir/b.json').writeAsString(
        jsonEncode({
          'id': 'b',
          'value': {
            'x': 2,
            'list': [1, 3],
            'extra': true,
          },
        }),
      );

      final diff = await store.diffSnapshots(fromId: 'a', toId: 'b');
      final changes = (diff['changes']! as List).cast<Map<String, Object?>>();
      final paths = changes.map((final change) => change['path']).toSet();

      expect(paths, contains(r'$.value.x'));
      expect(paths, contains(r'$.value.list[1]'));
      expect(paths, contains(r'$.value.extra'));
    });

    test('supports check-only writes', () async {
      final store = IntentSnapshotStore(snapshotsDir: snapshotsDir);

      final saved = await store.saveSnapshot(
        id: 'check_only',
        snapshot: const {'id': 'check_only'},
        writeOptions: const SafeWriteOptions(check: true, diff: true),
      );

      final writes = (saved['writeResults']! as List)
          .cast<Map<String, Object?>>();
      expect(writes.single['status'], equals(SafeWriteStatus.added));
      expect(writes.single['wrote'], isFalse);
      expect(writes.single['diff'], isA<Map<String, Object?>>());
      expect(File('$snapshotsDir/check_only.json').existsSync(), isFalse);
    });

    test('skips invalid files while listing snapshots', () async {
      final store = IntentSnapshotStore(snapshotsDir: snapshotsDir);
      await Directory(snapshotsDir).create(recursive: true);
      await File('$snapshotsDir/good.json').writeAsString(
        jsonEncode({'id': 'good', 'createdAt': '2026-06-22T00:00:00.000Z'}),
      );
      await File('$snapshotsDir/bad.json').writeAsString('{not-json');

      final listed = await store.listSnapshots();

      expect(listed, hasLength(1));
      expect(listed.single['id'], equals('good'));
    });
  });
}
