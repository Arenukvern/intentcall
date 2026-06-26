import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('invoke runs intent handler', () async {
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'demo',
            name: 'echo',
            description: 'echo',
            kind: AgentIntentKind.tool,
            inputSchema: const {
              'type': 'object',
              'properties': <String, Object?>{},
            },
          ),
          execute: (final inv) async =>
              AgentResult.success(data: {'in': inv.arguments['x']}),
        ),
      );
    final out = await registry.invoke('demo_echo', {'x': 1});
    expect(out.ok, isTrue);
    expect(out.data['in'], 1);
  });

  test('invoke coerces VM wire strings before validate', () async {
    int? capturedSnapshotId;
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'tap',
            description: 'tap',
            kind: AgentIntentKind.tool,
            inputSchema: const {
              'type': 'object',
              'required': ['ref'],
              'properties': {
                'ref': {'type': 'string'},
                'snapshotId': {'type': 'integer'},
              },
            },
          ),
          execute: (final inv) async {
            capturedSnapshotId = inv.arguments['snapshotId'] as int?;
            return AgentResult.success();
          },
        ),
      );

    final out = await registry.invoke('app_tap', {
      'ref': 's_0',
      'snapshotId': '99',
    });
    expect(out.ok, isTrue);
    expect(capturedSnapshotId, 99);
  });

  test('invoke returns failure for validation errors', () async {
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'tap',
            description: 'tap',
            kind: AgentIntentKind.tool,
            inputSchema: const {
              'type': 'object',
              'required': ['ref'],
              'properties': {
                'ref': {'type': 'string'},
              },
            },
          ),
          execute: (_) async => AgentResult.success(),
        ),
      );

    final out = await registry.invoke('app_tap', const <String, Object?>{});
    expect(out.ok, isFalse);
    expect(out.code, 'validation_error');
  });

  test('invoke returns failure for handler errors', () async {
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'boom',
            description: 'boom',
            kind: AgentIntentKind.tool,
            inputSchema: const {'type': 'object'},
          ),
          execute: (_) async => throw StateError('boom'),
        ),
      );

    final out = await registry.invoke('app_boom', const <String, Object?>{});
    expect(out.ok, isFalse);
    expect(out.code, 'intent_execution_error');
    expect(out.message, contains('boom'));
  });

  test('duplicate qualified name throws', () {
    final registry = InMemoryAgentRegistry();
    final intent = RegisteredAgentIntent(
      descriptor: AgentIntentDescriptor(
        namespace: 'demo',
        name: 'echo',
        description: 'echo',
        kind: AgentIntentKind.tool,
        inputSchema: const {
          'type': 'object',
          'properties': <String, Object?>{},
        },
      ),
      execute: (_) async => AgentResult.success(),
    );
    registry.register(intent);
    expect(
      () => registry.register(intent),
      throwsA(isA<AgentIntentCollisionError>()),
    );
  });

  test('listEntries preserves qualifiedNameOverride keys', () {
    final registry = InMemoryAgentRegistry();
    final intent = RegisteredAgentIntent(
      descriptor: AgentIntentDescriptor(
        namespace: 'demo',
        name: 'echo',
        description: 'echo',
        kind: AgentIntentKind.tool,
        inputSchema: const <String, Object?>{'type': 'object'},
      ),
      execute: (_) async => AgentResult.success(),
    );

    registry.register(intent, qualifiedNameOverride: 'custom_transport_key');

    final entry = registry.listEntries().single;
    expect(entry.key, 'custom_transport_key');
    expect(entry.intent, same(intent));
    expect(entry.descriptor.qualifiedName, 'demo_echo');
    expect(registry.listDescriptors().single.qualifiedName, 'demo_echo');
  });
}
