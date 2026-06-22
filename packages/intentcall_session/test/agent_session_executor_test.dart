import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:intentcall_session/intentcall_session.dart';
import 'package:test/test.dart';

void main() {
  test(
    'IntentSessionExecutor invokes an AgentRegistry inside a session',
    () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'intentcall_session_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final registry = InMemoryAgentRegistry()
        ..register(
          AgentCallEntry.tool(
            namespace: 'debug',
            name: 'select',
            description: 'Select an object.',
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

      final manager = IntentSessionManager(
        connector: _FakeConnector(endpoint: 'ws://127.0.0.1:8181/ws'),
        stateStore: StateStore(path: '${tempDir.path}/state.json'),
      );
      await manager.startSession(
        const IntentSessionStartRequest(sessionId: 's1'),
      );

      final executor = IntentSessionExecutor(
        sessions: manager,
        registry: registry,
      );

      final result = await executor.invoke(
        sessionId: 's1',
        qualifiedName: 'debug_select',
        arguments: const {'id': 'node-7'},
      );

      expect(result.ok, isTrue);
      expect(result.data['selected'], equals('node-7'));
    },
  );
}

final class _FakeConnector implements IntentSessionConnector {
  _FakeConnector({required this.endpoint});

  final String endpoint;

  @override
  String? activeEndpointDisplay;

  @override
  Map<String, Object?> get lastSelectionDiagnostics => const {};

  @override
  Future<Map<String, Object?>> connect({
    final IntentSessionConnectionMode mode = IntentSessionConnectionMode.auto,
    final String? targetId,
    final String? uri,
    final String? host,
    final int? port,
    final bool forceReconnect = false,
  }) async {
    activeEndpointDisplay = endpoint;
    return {'connected': true};
  }

  @override
  Future<void> disconnect() async {
    activeEndpointDisplay = null;
  }
}
