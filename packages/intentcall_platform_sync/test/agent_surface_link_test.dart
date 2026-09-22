import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_platform_sync/io.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test(
    'watch records calls and the transport does not touch app state',
    () async {
      var paints = 0;
      final hub = _hub(
        onText: (final text) {
          if (text == 'paint') {
            paints += 1;
          }
        },
      );
      addTearDown(hub.close);
      final seen = <String>[];
      final subscription = hub.watch().listen((final observation) {
        seen.add(
          '${observation.envelope.source}:${observation.result.data['text']}',
        );
      });
      addTearDown(subscription.cancel);

      await hub.invoke(
        IntentCallInvocationEnvelope(
          id: 'local-1',
          qualifiedName: 'app_echo',
          arguments: const <String, Object?>{'text': 'quiet'},
          source: IntentCallInvocationSource.mcp,
        ),
      );
      expect(paints, 0);

      final page = AgentHttpInvoke.through(hub);
      final pageResult = await page.handle(
        requestUri: Uri.parse('/agent/invoke?name=app_echo'),
        body: jsonEncode(<String, Object?>{'text': 'paint'}),
      );
      expect(pageResult['ok'], isTrue);
      expect(paints, 1);
      await Future<void>.delayed(Duration.zero);
      expect(seen, <String>['mcp:quiet', 'webmcp.fallback:paint']);
    },
  );

  test('websocket client and page HTTP share the hub', () async {
    final hub = _hub(onText: (_) {});
    addTearDown(hub.close);
    final surface = await AgentWebSocketSurface.serve(link: hub);
    addTearDown(surface.close);
    final seen = <String>[];
    final subscription = hub.watch().listen((final observation) {
      seen.add(observation.envelope.source);
    });
    addTearDown(subscription.cancel);

    final wsResult = await invokeAgentWebSocket(
      uri: surface.uri,
      envelope: IntentCallInvocationEnvelope(
        id: 'ws-1',
        qualifiedName: 'app_echo',
        arguments: const <String, Object?>{'text': 'from-socket'},
        source: IntentCallInvocationSource.websocket,
      ),
    );
    expect(wsResult.ok, isTrue);
    expect(wsResult.data['text'], 'from-socket');

    final page = AgentHttpInvoke.through(hub);
    final pageResult = await page.handle(
      requestUri: Uri.parse('/agent/invoke?name=app_echo'),
      body: jsonEncode(<String, Object?>{'text': 'from-page'}),
    );
    expect(pageResult['text'], 'from-page');
    await Future<void>.delayed(Duration.zero);
    expect(seen, <String>[
      IntentCallInvocationSource.websocket,
      IntentCallInvocationSource.webMcpFallback,
    ]);
  });
}

AgentInvocationHub _hub({required final void Function(String text) onText}) {
  final registry = InMemoryAgentRegistry()
    ..register(
      RegisteredAgentIntent(
        descriptor: AgentIntentDescriptor(
          namespace: 'app',
          name: 'echo',
          description: 'Echo.',
          kind: AgentIntentKind.tool,
          inputSchema: const <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'text': <String, Object?>{'type': 'string'},
            },
            'required': <String>['text'],
          },
        ),
        execute: (final invocation) async {
          final text = '${invocation.arguments['text']}';
          onText(text);
          return AgentResult.success(data: <String, Object?>{'text': text});
        },
      ),
    );
  return AgentInvocationHub.bindRegistry(
    registry: registry,
    policy: const IntentCallAuthorizationPolicy(
      allowedSources: <String>{
        IntentCallInvocationSource.mcp,
        IntentCallInvocationSource.websocket,
        IntentCallInvocationSource.webMcpFallback,
      },
      allowedQualifiedNames: <String>{'app_echo'},
    ),
  );
}
