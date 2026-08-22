import 'dart:convert';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

RegisteredAgentIntent _echoIntent() => RegisteredAgentIntent(
  descriptor: AgentIntentDescriptor(
    namespace: 'contract',
    name: 'echo',
    description: 'Echo fixture',
    kind: AgentIntentKind.tool,
    inputSchema: const <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'text': <String, Object?>{'type': 'string'},
        'count': <String, Object?>{'type': 'integer'},
      },
    },
  ),
  execute: (final invocation) async => AgentResult.success(
    data: <String, Object?>{
      'text': invocation.arguments['text'],
      'count': invocation.arguments['count'],
      'qualifiedName': invocation.descriptor.qualifiedName,
    },
  ),
);

RegisteredAgentIntent _failIntent() => RegisteredAgentIntent(
  descriptor: AgentIntentDescriptor(
    namespace: 'contract',
    name: 'fail',
    description: 'Failure fixture',
    kind: AgentIntentKind.tool,
    inputSchema: const <String, Object?>{'type': 'object'},
  ),
  execute: (_) async => AgentResult.failure(
    code: 'contract_failure',
    message: 'expected failure',
  ),
);

AcpPromptRequest _prompt(final String sessionId, final String text) =>
    AcpPromptRequest(sessionId: sessionId, prompt: [AcpTextBlock(text)]);

void main() {
  test('lists registered tool intents', () async {
    final registry = InMemoryAgentRegistry()..register(_echoIntent());
    final backend = RegistryAcpBackend(registry: registry);

    final tools = backend.listTools();
    expect(tools, hasLength(1));
    expect(tools.single['name'], 'contract_echo');
    expect(tools.single['description'], 'Echo fixture');
  });

  test(
    'invokes a registry tool from prompt text with JSON arguments',
    () async {
      final registry = InMemoryAgentRegistry()..register(_echoIntent());
      final backend = RegistryAcpBackend(registry: registry);
      final sessionId = await backend.createSession(
        const AcpSessionNewRequest(cwd: '/tmp'),
      );

      final updates = <AcpSessionUpdate>[];
      final stop = await backend.prompt(
        _prompt(sessionId, 'contract_echo {"text": "hello", "count": 2}'),
        emit: updates.add,
        isCancelled: () => false,
      );

      expect(stop, AcpStopReason.endTurn);
      final chunks = updates.whereType<AgentMessageChunk>().toList();
      expect(chunks, isNotEmpty);
      final payload =
          jsonDecode(chunks.last.content.toJson()['text'] as String)
              as Map<String, Object?>;
      expect(payload['ok'], true);
      expect(payload['text'], 'hello');
      expect(payload['count'], 2);
      expect(payload['qualifiedName'], 'contract_echo');
    },
  );

  test('invokes with plain-text arguments when JSON does not parse', () async {
    final registry = InMemoryAgentRegistry()..register(_echoIntent());
    final backend = RegistryAcpBackend(registry: registry);
    final sessionId = await backend.createSession(
      const AcpSessionNewRequest(cwd: '/tmp'),
    );

    final updates = <AcpSessionUpdate>[];
    await backend.prompt(
      _prompt(sessionId, 'contract_echo just some words'),
      emit: updates.add,
      isCancelled: () => false,
    );

    final chunks = updates.whereType<AgentMessageChunk>().toList();
    final payload =
        jsonDecode(chunks.last.content.toJson()['text'] as String)
            as Map<String, Object?>;
    expect(payload['text'], 'just some words');
  });

  test(
    'maps registry failure to refusal stop reason with error payload',
    () async {
      final registry = InMemoryAgentRegistry()..register(_failIntent());
      final backend = RegistryAcpBackend(registry: registry);
      final sessionId = await backend.createSession(
        const AcpSessionNewRequest(cwd: '/tmp'),
      );

      final updates = <AcpSessionUpdate>[];
      final stop = await backend.prompt(
        _prompt(sessionId, 'contract_fail'),
        emit: updates.add,
        isCancelled: () => false,
      );

      expect(stop, AcpStopReason.refusal);
      final chunks = updates.whereType<AgentMessageChunk>().toList();
      final payload =
          jsonDecode(chunks.last.content.toJson()['text'] as String)
              as Map<String, Object?>;
      expect(payload['ok'], false);
      expect(payload['code'], 'contract_failure');
    },
  );

  test('refuses unknown intents and lists available tools', () async {
    final registry = InMemoryAgentRegistry()..register(_echoIntent());
    final backend = RegistryAcpBackend(registry: registry);
    final sessionId = await backend.createSession(
      const AcpSessionNewRequest(cwd: '/tmp'),
    );

    final updates = <AcpSessionUpdate>[];
    final stop = await backend.prompt(
      _prompt(sessionId, 'nope_missing'),
      emit: updates.add,
      isCancelled: () => false,
    );

    expect(stop, AcpStopReason.refusal);
    final chunks = updates.whereType<AgentMessageChunk>().toList();
    final payload =
        jsonDecode(chunks.first.content.toJson()['text'] as String)
            as Map<String, Object?>;
    expect(payload['code'], 'intent_not_found');
    expect(payload['message'], contains('contract_echo'));
  });

  test('emits tool call lifecycle updates around invocation', () async {
    final registry = InMemoryAgentRegistry()..register(_echoIntent());
    final backend = RegistryAcpBackend(registry: registry);
    final sessionId = await backend.createSession(
      const AcpSessionNewRequest(cwd: '/tmp'),
    );

    final updates = <AcpSessionUpdate>[];
    await backend.prompt(
      _prompt(sessionId, 'contract_echo {"text": "x", "count": 1}'),
      emit: updates.add,
      isCancelled: () => false,
    );

    final toolCalls = updates.whereType<ToolCallUpdate>().toList();
    expect(toolCalls.first.status, 'in_progress');
    expect(toolCalls.first.title, 'contract_echo');
    expect(toolCalls.last.status, 'completed');
  });
}
