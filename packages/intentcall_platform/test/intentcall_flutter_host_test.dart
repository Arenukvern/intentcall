import 'dart:async';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:intentcall_platform/src/flutter/intentcall_flutter_host.dart';
import 'package:intentcall_platform/src/flutter/intentcall_host_events.dart';
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

  test('IntentCallFlutterHost drains pending native entity opens', () async {
    final opens = <IntentCallEntityOpenEnvelope>[];
    final host = IntentCallFlutterHost.bindRegistry(
      registry: _registry(),
      takePendingInvocations: () async => const <IntentCallInvocationEnvelope>[],
      takePendingEntityOpens: () async => <IntentCallEntityOpenEnvelope>[
        IntentCallEntityOpenEnvelope(
          id: 'open-1',
          entityType: 'notes_note',
          entityId: 'note-1',
          source: IntentCallEntityOpenSource.nativeEntityGenerated,
        ),
      ],
      onEntityOpen: opens.add,
    );

    await host.start();

    expect(opens, hasLength(1));
    expect(opens.single.id, 'open-1');
    expect(opens.single.entityType, 'notes_note');
    expect(opens.single.entityId, 'note-1');
    expect(opens.single.source, IntentCallEntityOpenSource.nativeEntityGenerated);
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

  test('IntentCallFlutterHost drains on injected resume wake', () async {
    final wakeSignals = StreamController<IntentCallDrainTrigger>();
    final eventKinds = <IntentCallHostEventKind>[];
    var pendingReads = 0;
    final host = IntentCallFlutterHost.bindRegistry(
      registry: _registry(),
      policy: const IntentCallAuthorizationPolicy(
        allowedSources: <String>{IntentCallInvocationSource.nativeGenerated},
        allowedQualifiedNames: <String>{'app_echo'},
      ),
      drainOnStart: false,
      wakeSignals: wakeSignals.stream,
      takePendingInvocations: () async {
        pendingReads += 1;
        return <IntentCallInvocationEnvelope>[
          IntentCallInvocationEnvelope(
            id: 'native-resume',
            qualifiedName: 'app_echo',
            arguments: const <String, Object?>{'text': 'resume'},
            source: IntentCallInvocationSource.nativeGenerated,
          ),
        ];
      },
    );
    host.events.listen((final event) => eventKinds.add(event.kind));
    final finished = host.events.firstWhere(
      (final event) => event.kind == IntentCallHostEventKind.drainFinished,
    );

    addTearDown(() async {
      await wakeSignals.close();
      await host.dispose();
    });

    final startResults = await host.start();
    wakeSignals.add(IntentCallDrainTrigger.resume);
    final finishedEvent = await finished;

    expect(startResults, isEmpty);
    expect(pendingReads, 1);
    expect(finishedEvent.trigger, IntentCallDrainTrigger.resume);
    expect(finishedEvent.results.single.data['text'], 'resume');
    expect(eventKinds, <IntentCallHostEventKind>[
      IntentCallHostEventKind.drainStarted,
      IntentCallHostEventKind.envelope,
      IntentCallHostEventKind.result,
      IntentCallHostEventKind.drainFinished,
    ]);
  });

  test('IntentCallFlutterHost coalesces overlapping drain requests', () async {
    final firstRead = Completer<List<IntentCallInvocationEnvelope>>();
    var pendingReads = 0;
    var activeReads = 0;
    var maxActiveReads = 0;
    final host = IntentCallFlutterHost.bindRegistry(
      registry: _registry(),
      drainOnStart: false,
      takePendingInvocations: () async {
        pendingReads += 1;
        activeReads += 1;
        maxActiveReads = activeReads > maxActiveReads
            ? activeReads
            : maxActiveReads;
        try {
          if (pendingReads == 1) {
            return await firstRead.future;
          }
          return const <IntentCallInvocationEnvelope>[];
        } finally {
          activeReads -= 1;
        }
      },
    );

    addTearDown(host.dispose);

    final first = host.requestDrain(IntentCallDrainTrigger.manual);
    final second = host.requestDrain(IntentCallDrainTrigger.resume);
    firstRead.complete(const <IntentCallInvocationEnvelope>[]);
    await first;
    await second;

    expect(pendingReads, 2);
    expect(maxActiveReads, 1);
  });

  test('IntentCallFlutterHost dispose stops wake-triggered drains', () async {
    final wakeSignals = StreamController<IntentCallDrainTrigger>();
    var pendingReads = 0;
    final host = IntentCallFlutterHost.bindRegistry(
      registry: _registry(),
      drainOnStart: false,
      wakeSignals: wakeSignals.stream,
      takePendingInvocations: () async {
        pendingReads += 1;
        return const <IntentCallInvocationEnvelope>[];
      },
    );

    await host.start();
    await host.dispose();
    wakeSignals.add(IntentCallDrainTrigger.resume);
    await pumpEventQueue();
    await wakeSignals.close();

    expect(pendingReads, 0);
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
