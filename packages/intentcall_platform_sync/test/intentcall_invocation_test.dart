import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
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
    final bridge = IntentCallNativeBridge.bindRegistry(registry: _registry());

    final result = await bridge.execute(
      IntentCallInvocationEnvelope(
        id: 'native-1',
        qualifiedName: 'app_echo',
        arguments: const <String, Object?>{'text': 'hello'},
        source: IntentCallInvocationSource.nativeGenerated,
      ),
    );

    expect(result.ok, isFalse);
    expect(result.code, 'invocation_denied');
  });

  test('IntentCallAuthorizationPolicy constructor denies by default', () async {
    final allowed = await const IntentCallAuthorizationPolicy().allows(
      IntentCallInvocationEnvelope(
        id: 'webmcp-1',
        qualifiedName: 'app_echo',
        arguments: const <String, Object?>{'text': 'hello'},
        source: IntentCallInvocationSource.webMcpDart,
      ),
    );

    expect(allowed, isFalse);
  });

  test('debugAllowAll allows while assertions are enabled', () async {
    final allowed = await const IntentCallAuthorizationPolicy.debugAllowAll()
        .allows(
          IntentCallInvocationEnvelope(
            id: 'webmcp-1',
            qualifiedName: 'app_echo',
            arguments: const <String, Object?>{'text': 'hello'},
            source: IntentCallInvocationSource.webMcpDart,
          ),
        );

    expect(allowed, isTrue);
  });

  test('IntentCallNativeBridge executes allowed registry invocation', () async {
    final bridge = IntentCallNativeBridge.bindRegistry(
      registry: _registry(),
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

  test('IntentCallNativeBridge rejects source mismatch', () async {
    final bridge = IntentCallNativeBridge.bindRegistry(
      registry: _registry(),
      policy: const IntentCallAuthorizationPolicy(
        allowedSources: <String>{IntentCallInvocationSource.webMcpDart},
        allowedQualifiedNames: <String>{'app_echo'},
      ),
    );

    final result = await bridge.execute(
      IntentCallInvocationEnvelope(
        id: 'native-1',
        qualifiedName: 'app_echo',
        arguments: const <String, Object?>{'text': 'hello'},
        source: IntentCallInvocationSource.nativeGenerated,
      ),
    );

    expect(result.ok, isFalse);
    expect(result.code, 'invocation_denied');
  });

  test('IntentCallNativeBridge rejects qualified-name mismatch', () async {
    final bridge = IntentCallNativeBridge.bindRegistry(
      registry: _registry(),
      policy: const IntentCallAuthorizationPolicy(
        allowedSources: <String>{IntentCallInvocationSource.webMcpDart},
        allowedQualifiedNames: <String>{'app_other'},
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

    expect(result.ok, isFalse);
    expect(result.code, 'invocation_denied');
  });

  test('IntentCallNativeBridge respects confirmation callback', () async {
    final denied = IntentCallNativeBridge.bindRegistry(
      registry: _registry(),
      policy: IntentCallAuthorizationPolicy(
        allowedSources: const <String>{IntentCallInvocationSource.webMcpDart},
        allowedQualifiedNames: const <String>{'app_echo'},
        confirm: (final envelope) => Future<bool>.value(false),
      ),
    );
    final allowed = IntentCallNativeBridge.bindRegistry(
      registry: _registry(),
      policy: IntentCallAuthorizationPolicy(
        allowedSources: const <String>{IntentCallInvocationSource.webMcpDart},
        allowedQualifiedNames: const <String>{'app_echo'},
        confirm: (final envelope) =>
            Future<bool>.value(envelope.arguments['text'] == 'ok'),
      ),
    );

    final deniedResult = await denied.execute(
      IntentCallInvocationEnvelope(
        id: 'webmcp-1',
        qualifiedName: 'app_echo',
        arguments: const <String, Object?>{'text': 'ok'},
        source: IntentCallInvocationSource.webMcpDart,
      ),
    );
    final allowedResult = await allowed.execute(
      IntentCallInvocationEnvelope(
        id: 'webmcp-2',
        qualifiedName: 'app_echo',
        arguments: const <String, Object?>{'text': 'ok'},
        source: IntentCallInvocationSource.webMcpDart,
      ),
    );

    expect(deniedResult.ok, isFalse);
    expect(deniedResult.code, 'invocation_denied');
    expect(allowedResult.ok, isTrue);
    expect(allowedResult.data['text'], 'ok');
  });

  test('IntentCallDartExtensionInlineRuntime denies by default', () async {
    final runtime = IntentCallDartExtensionInlineRuntime.bindRegistry(
      registry: _registry(),
    );

    final result = await runtime.perform(<String, Object?>{
      'id': 'extension-1',
      'qualifiedName': 'app_echo',
      'arguments': const <String, Object?>{'text': 'hello'},
      'source': 'spoofed',
    });

    expect(result['ok'], isFalse);
    expect(result['code'], 'invocation_denied');
    expect(
      (result['details']! as Map)['source'],
      'apple.dart_extension_inline',
    );
  });

  test(
    'IntentCallDartExtensionInlineRuntime invokes allowed registry',
    () async {
      final runtime = IntentCallDartExtensionInlineRuntime.bindRegistry(
        registry: _registry(),
        policy: const IntentCallAuthorizationPolicy(
          allowedSources: <String>{
            IntentCallInvocationSource.appleDartExtensionInline,
          },
          allowedQualifiedNames: <String>{'app_echo'},
        ),
      );

      final result = await runtime.perform(<String, Object?>{
        'id': 'extension-1',
        'qualifiedName': 'app_echo',
        'arguments': const <String, Object?>{'text': 'hello'},
      });

      expect(result['ok'], isTrue);
      expect(result['dialog'], 'ok');
      expect((result['data']! as Map)['text'], 'hello');
      expect((result['data']! as Map)['correlationId'], 'extension-1');
    },
  );

  test(
    'IntentCallDartExtensionInlineRuntime rejects invalid requests',
    () async {
      final runtime = IntentCallDartExtensionInlineRuntime.bindRegistry(
        registry: _registry(),
        policy: const IntentCallAuthorizationPolicy.allowAll(),
      );

      final result = await runtime.perform(<String, Object?>{
        'arguments': const <String, Object?>{'text': 'hello'},
      });

      expect(result['ok'], isFalse);
      expect(result['code'], 'invalid_extension_request');
    },
  );
}

InMemoryAgentRegistry _registry() => InMemoryAgentRegistry()
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
