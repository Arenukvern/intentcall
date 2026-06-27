import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:intentcall_platform/src/flutter/intentcall_flutter_host.dart';
import 'package:intentcall_platform/src/flutter/intentcall_invoke_link_stub.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('IntentCallFlutterHost drains pending native invocations', () async {
    final envelopes = <IntentCallInvocationEnvelope>[];
    final results = <AgentResult>[];
    final host = IntentCallFlutterHost.bindRegistry(
      registry: _registry(),
      policy: const IntentCallAuthorizationPolicy(
        allowedSources: <String>{IntentCallInvocationSource.nativeGenerated},
        allowedQualifiedNames: <String>{'app_echo'},
      ),
      takePendingInvocations: () async => <IntentCallInvocationEnvelope>[
        IntentCallInvocationEnvelope(
          id: 'native-1',
          qualifiedName: 'app_echo',
          arguments: const <String, Object?>{'text': 'hello'},
          source: IntentCallInvocationSource.nativeGenerated,
        ),
      ],
      onEnvelope: envelopes.add,
      onResult: (final envelope, final result) => results.add(result),
    );

    final drained = await host.start();

    expect(drained, hasLength(1));
    expect(drained.single.ok, isTrue);
    expect(drained.single.data['text'], 'hello');
    expect(envelopes.single.id, 'native-1');
    expect(results.single.data['correlationId'], 'native-1');
  });

  test('IntentCallFlutterHost reports denied invocations', () async {
    IntentCallInvocationEnvelope? deniedEnvelope;
    AgentResult? deniedResult;
    final host = IntentCallFlutterHost.bindRegistry(
      registry: _registry(),
      takePendingInvocations: () async => <IntentCallInvocationEnvelope>[
        IntentCallInvocationEnvelope(
          id: 'native-1',
          qualifiedName: 'app_echo',
          arguments: const <String, Object?>{'text': 'hello'},
          source: IntentCallInvocationSource.nativeGenerated,
        ),
      ],
      onDenied: (final envelope, final result) {
        deniedEnvelope = envelope;
        deniedResult = result;
      },
    );

    final drained = await host.drainPendingInvocations();

    expect(drained.single.ok, isFalse);
    expect(drained.single.code, 'invocation_denied');
    expect(deniedEnvelope?.id, 'native-1');
    expect(deniedResult?.code, 'invocation_denied');
  });

  test('deep-link listener requires an app-owned scheme', () {
    expect(
      () => IntentCallFlutterHost.bindRegistry(
        registry: _registry(),
        listenForDeepLinks: true,
      ),
      throwsArgumentError,
    );
  });

  test('IntentCallInvokeLinkListener parses app-owned invoke links', () {
    expect(
      IntentCallInvokeLinkListener.qualifiedNameFromUri(
        Uri.parse('demoapp://invoke/app_echo'),
        protocolScheme: 'demoapp',
      ),
      'app_echo',
    );
    expect(
      IntentCallInvokeLinkListener.qualifiedNameFromUri(
        Uri.parse('otherapp://invoke/app_echo'),
        protocolScheme: 'demoapp',
      ),
      isNull,
    );
  });
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
