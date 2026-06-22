import 'dart:io';

import 'package:intentcall_session/intentcall_session.dart';
import 'package:test/test.dart';

void main() {
  group('IntentSessionManager', () {
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

    test('starts and persists a session through a connector', () async {
      final store = StateStore(path: statePath);
      final connector = _FakeConnector(endpoint: 'ws://127.0.0.1:8181/ws');
      final manager = IntentSessionManager(
        connector: connector,
        stateStore: store,
      );
      await manager.load();

      final result = await manager.startSession(
        const IntentSessionStartRequest(
          sessionId: 's1',
          mode: IntentSessionConnectionMode.uri,
        ),
      );

      expect(result.ok, isTrue);
      expect(result.data['sessionId'], equals('s1'));
      expect(connector.connectCount, equals(1));

      final loaded = await store.read();
      expect(loaded.activeSessionId, equals('s1'));
      expect(loaded.sessions['s1']?.endpoint, equals('ws://127.0.0.1:8181/ws'));
    });

    test('endSession removes active session and disconnects', () async {
      final now = DateTime.now().toUtc();
      final store = StateStore(path: statePath);
      await store.write(
        PersistedState(
          activeSessionId: 's1',
          sessions: {
            's1': SessionState(
              id: 's1',
              endpoint: 'ws://127.0.0.1:8181/ws',
              createdAt: now,
              lastUsedAt: now,
              mode: 'uri',
            ),
          },
        ),
      );

      final connector = _FakeConnector(endpoint: 'ws://127.0.0.1:8181/ws');
      final manager = IntentSessionManager(
        connector: connector,
        stateStore: store,
      );
      await manager.load();

      final result = await manager.endSession('s1');

      expect(result.ok, isTrue);
      expect(connector.disconnectCount, equals(1));
      expect((await store.read()).sessions, isEmpty);
    });

    test('maps multiple-target failures to selection required', () async {
      final manager = IntentSessionManager(
        connector: _FakeConnector(
          endpoint: 'ws://127.0.0.1:8181/ws',
          failure: const _FakeConnectionException(
            reasonName: IntentSessionConnectionFailureReason.multipleTargets,
            message: 'Multiple targets found',
            details: {'count': 2},
          ),
        ),
        stateStore: StateStore(path: statePath),
      );

      final result = await manager.startSession(
        const IntentSessionStartRequest(),
      );

      expect(result.ok, isFalse);
      expect(
        result.code,
        equals(IntentSessionErrorCode.connectionSelectionRequired),
      );
      expect(result.details, equals({'count': 2}));
    });
  });
}

final class _FakeConnector implements IntentSessionConnector {
  _FakeConnector({required this.endpoint, this.failure});

  final String endpoint;
  final _FakeConnectionException? failure;
  int connectCount = 0;
  int disconnectCount = 0;

  @override
  String? activeEndpointDisplay;

  @override
  Map<String, Object?> get lastSelectionDiagnostics => const {
    'decision': 'fake',
  };

  @override
  Future<Map<String, Object?>> connect({
    final IntentSessionConnectionMode mode = IntentSessionConnectionMode.auto,
    final String? targetId,
    final String? uri,
    final String? host,
    final int? port,
    final bool forceReconnect = false,
  }) async {
    connectCount += 1;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    activeEndpointDisplay = endpoint;
    return {'connected': true, 'reusedConnection': false, 'mode': mode.name};
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    activeEndpointDisplay = null;
  }
}

final class _FakeConnectionException
    implements IntentSessionConnectionException {
  const _FakeConnectionException({
    required this.reasonName,
    required this.message,
    this.details,
  });

  @override
  final String reasonName;

  @override
  final String message;

  @override
  final Object? details;
}
