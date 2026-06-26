import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('IntentCallInvocationEnvelope serializes stable JSON', () {
    final createdAt = DateTime.utc(2026, 6, 26);
    final envelope = IntentCallInvocationEnvelope(
      id: 'native-1',
      qualifiedName: 'app_echo',
      arguments: const <String, Object?>{'text': 'hi'},
      source: IntentCallInvocationSource.nativeGenerated,
      createdAt: createdAt,
    );

    expect(
      IntentCallInvocationEnvelope.fromJson(envelope.toJson()).toJson(),
      envelope.toJson(),
    );
  });

  test('IntentCallNativeBridge denies invocations by default', () async {
    final bridge = IntentCallNativeBridge.bindRegistry(
      registry: InMemoryAgentRegistry(),
    );

    final result = await bridge.execute(
      IntentCallInvocationEnvelope(
        id: 'deep-link-1',
        qualifiedName: 'app_echo',
        arguments: const <String, Object?>{},
        source: IntentCallInvocationSource.deepLink,
      ),
    );

    expect(result.ok, isFalse);
    expect(result.code, 'invocation_denied');
  });

  test('IntentCallNativeBridge executes allowed registry invocation', () async {
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'echo',
            description: 'echo',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{
              'type': 'object',
              'required': <String>['text'],
              'properties': <String, Object?>{
                'text': <String, Object?>{'type': 'string'},
              },
            },
          ),
          execute: (final invocation) async => AgentResult.success(
            data: <String, Object?>{
              'text': invocation.arguments['text'],
              'correlationId': invocation.correlationId,
            },
          ),
        ),
      );
    final bridge = IntentCallNativeBridge.bindRegistry(
      registry: registry,
      policy: const IntentCallAuthorizationPolicy(
        allowedSources: <String>{IntentCallInvocationSource.webMcpDart},
        allowedQualifiedNames: <String>{'app_echo'},
      ),
    );

    final result = await bridge.execute(
      IntentCallInvocationEnvelope(
        id: 'webmcp-1',
        qualifiedName: 'app_echo',
        arguments: const <String, Object?>{'text': 'hello'},
        source: IntentCallInvocationSource.webMcpDart,
      ),
    );

    expect(result.ok, isTrue);
    expect(result.data['text'], 'hello');
    expect(result.data['correlationId'], 'webmcp-1');
  });
}
