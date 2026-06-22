import 'dart:convert';
import 'dart:io';

import 'package:intentcall_session/intentcall_session.dart';
import 'package:test/test.dart';

void main() {
  group('StateStore', () {
    late Directory tempDir;
    late String statePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('intentcall_session_');
      statePath = '${tempDir.path}/state.json';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('persists the existing session JSON shape', () async {
      final store = StateStore(path: statePath);
      final now = DateTime.utc(2026, 6, 22, 10);

      await store.write(
        PersistedState(
          activeSessionId: 's1',
          stickyEndpoint: 'ws://127.0.0.1:8181/token/ws',
          lastMode: 'uri',
          sessions: {
            's1': SessionState(
              id: 's1',
              endpoint: 'ws://127.0.0.1:8181/token/ws',
              createdAt: now,
              lastUsedAt: now,
              mode: 'uri',
              uri: 'ws://127.0.0.1:8181/token/ws',
            ),
          },
        ),
      );

      final raw = (jsonDecode(File(statePath).readAsStringSync()) as Map)
          .cast<String, Object?>();
      final sessions = (raw['sessions']! as Map).cast<String, Object?>();
      final sessionJson = (sessions['s1']! as Map).cast<String, Object?>();
      expect(raw['schemaVersion'], equals(1));
      expect(raw['activeSessionId'], equals('s1'));
      expect(sessionJson['endpoint'], contains('8181'));

      final loaded = await store.read();
      expect(loaded.activeSessionId, equals('s1'));
      expect(loaded.sessions['s1']?.mode, equals('uri'));
    });

    test('returns empty state for malformed JSON', () async {
      File(statePath).writeAsStringSync('{not-json');
      final loaded = await StateStore(path: statePath).read();
      expect(loaded.sessions, isEmpty);
      expect(loaded.activeSessionId, isNull);
    });

    test(
      'coerces tolerant persisted JSON fields at the file boundary',
      () async {
        File(statePath).writeAsStringSync(
          jsonEncode({
            'schemaVersion': '2',
            'activeSessionId': 's1',
            'sessions': {
              's1': {
                'id': 's1',
                'endpoint': 'ws://127.0.0.1:8181/token/ws',
                'createdAt': '2026-06-22T00:00:00.000Z',
                'lastUsedAt': '2026-06-22T00:01:00.000Z',
                'mode': '',
                'port': '8181',
              },
            },
          }),
        );

        final loaded = await StateStore(path: statePath).read();

        expect(loaded.schemaVersion, equals(2));
        expect(loaded.activeSessionId, equals('s1'));
        expect(loaded.sessions['s1']?.mode, equals('auto'));
        expect(loaded.sessions['s1']?.port, equals(8181));
      },
    );
  });
}
