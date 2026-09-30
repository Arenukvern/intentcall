import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_mcp/intentcall_mcp.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('CLI MCP and the page HTTP route share one registry', () async {
    final seen = <String>[];
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'echo',
            description: 'Echo text into the page the CLI launched.',
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
            seen.add(text);
            return AgentResult.success(
              data: <String, Object?>{'text': text, 'from': seen.length},
            );
          },
        ),
      );
    final bridge = IntentCallNativeBridge.bindRegistry(
      registry: registry,
      policy: const IntentCallAuthorizationPolicy(
        allowedSources: <String>{IntentCallInvocationSource.webMcpFallback},
        allowedQualifiedNames: <String>{'app_echo'},
      ),
    );

    final published =
        <String, FutureOr<CallToolResult> Function(CallToolRequest)>{};
    final adapter = McpPublishAdapter(
      publishTool: (final tool, final impl) {
        published[tool.name] = impl;
      },
      unpublishTool: published.remove,
    );
    await adapter.attach(registry);

    final mcpResult = await published['app_echo']!(
      CallToolRequest(
        name: 'app_echo',
        arguments: const <String, Object?>{'text': 'from-agent'},
      ),
    );
    final mcpJson =
        jsonDecode((mcpResult.content.single as TextContent).text)
            as Map<String, Object?>;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final invoke = AgentHttpInvoke(bridge: bridge);
    server.listen((final request) async {
      final body = await utf8.decodeStream(request);
      final payload = await invoke.handle(requestUri: request.uri, body: body);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(payload));
      await request.response.close();
    });

    final pageResponse = await _postInvoke(
      port: server.port,
      name: 'app_echo',
      arguments: const <String, Object?>{'text': 'from-page'},
    );

    expect(mcpJson['text'], 'from-agent');
    expect(pageResponse['ok'], isTrue);
    expect(pageResponse['text'], 'from-page');
    expect(pageResponse['from'], 2);
    expect(seen, <String>['from-agent', 'from-page']);

    final denied = await invoke.handle(
      requestUri: Uri.parse('/agent/invoke?name=app_other'),
      body: '{}',
    );
    expect(denied['ok'], isFalse);
    expect(denied['code'], 'invocation_denied');

    await adapter.detach();
  });

  test('MCP onToolCall is observed without a second invoke', () async {
    var calls = 0;
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'echo',
            description: 'Echo.',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{'type': 'object'},
          ),
          execute: (final _) async {
            calls += 1;
            return AgentResult.success(
              data: const <String, Object?>{'text': 'once'},
            );
          },
        ),
      );
    final hub = AgentInvocationHub.bindRegistry(
      registry: registry,
      policy: const IntentCallAuthorizationPolicy.allowAll(),
    );
    addTearDown(hub.close);
    final seen = <String>[];
    final subscription = hub.watch().listen((final observation) {
      seen.add(observation.envelope.source);
    });
    addTearDown(subscription.cancel);
    final published =
        <String, FutureOr<CallToolResult> Function(CallToolRequest)>{};
    final adapter = McpPublishAdapter(
      publishTool: (final tool, final impl) {
        published[tool.name] = impl;
      },
      unpublishTool: published.remove,
      onToolCall: (final name, final arguments, final result) {
        hub.observe(
          envelope: IntentCallInvocationEnvelope(
            id: 'mcp-1',
            qualifiedName: name,
            arguments: arguments,
            source: IntentCallInvocationSource.mcp,
          ),
          result: result,
        );
      },
    );
    await adapter.attach(registry);
    await published['app_echo']!(
      CallToolRequest(name: 'app_echo', arguments: const <String, Object?>{}),
    );
    expect(calls, 1);
    await Future<void>.delayed(Duration.zero);
    expect(seen, <String>[IntentCallInvocationSource.mcp]);
    await adapter.detach();
  });
}

Future<Map<String, Object?>> _postInvoke({
  required final int port,
  required final String name,
  required final Map<String, Object?> arguments,
}) async {
  final client = HttpClient();
  addTearDown(client.close);
  final request = await client.post(
    InternetAddress.loopbackIPv4.host,
    port,
    '${AgentHttpInvoke.defaultPath}?name=${Uri.encodeQueryComponent(name)}',
  );
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode(arguments));
  final response = await request.close();
  final raw = await utf8.decodeStream(response);
  return (jsonDecode(raw) as Map).cast<String, Object?>();
}
