// ignore_for_file: avoid_print

import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:intentcall_session/intentcall_session.dart';

Future<void> main() async {
  final tempDir = Directory.systemTemp.createTempSync(
    'intentcall_session_example_',
  );

  final registry = InMemoryAgentRegistry()
    ..register(
      AgentCallEntry.tool(
        namespace: 'debug',
        name: 'select',
        description: 'Select an object in the active runtime.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
          },
          'required': ['id'],
        },
        handler: (final args) =>
            AgentResult.success(data: {'selected': args['id']}),
      ).toRegistration(),
    );

  final sessions = IntentSessionManager(
    connector: ExampleConnector(endpoint: 'ws://127.0.0.1:8181/ws'),
    stateStore: StateStore(path: '${tempDir.path}/session_state.json'),
  );
  await sessions.load();

  final start = await sessions.startSession(
    const IntentSessionStartRequest(
      sessionId: 'debug',
      mode: IntentSessionConnectionMode.uri,
      uri: 'ws://127.0.0.1:8181/ws',
    ),
  );
  print('started: ${start.data}');

  final executor = IntentSessionExecutor(
    sessions: sessions,
    registry: registry,
  );
  final result = await executor.invoke(
    sessionId: 'debug',
    qualifiedName: 'debug_select',
    arguments: const {'id': 'node-7'},
  );
  print('invoked: ${result.data}');

  final snapshots = IntentSnapshotStore(
    snapshotsDir: '${tempDir.path}/snapshots',
  );
  await snapshots.saveSnapshot(
    id: 'before',
    snapshot: const {
      'id': 'before',
      'createdAt': '2026-06-22T00:00:00.000Z',
      'selection': null,
    },
  );
  await snapshots.saveSnapshot(
    id: 'after',
    snapshot: const {
      'id': 'after',
      'createdAt': '2026-06-22T00:00:01.000Z',
      'selection': 'node-7',
    },
  );

  final diff = await snapshots.diffSnapshots(fromId: 'before', toId: 'after');
  print('snapshot diff: ${diff['summary']}');

  await tempDir.delete(recursive: true);
}

final class ExampleConnector implements IntentSessionConnector {
  ExampleConnector({required this.endpoint});

  final String endpoint;

  @override
  String? activeEndpointDisplay;

  @override
  Map<String, Object?> get lastSelectionDiagnostics => const {
    'source': 'example',
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
    activeEndpointDisplay = uri ?? endpoint;
    return {
      'connected': true,
      'mode': mode.name,
      'reusedConnection': !forceReconnect,
    };
  }

  @override
  Future<void> disconnect() async {
    activeEndpointDisplay = null;
  }
}
