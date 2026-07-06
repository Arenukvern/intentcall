import 'dart:async';
import 'dart:io' as io;

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_mcp/intentcall_mcp.dart';

/// Minimal stdio MCP host wiring [McpPublishAdapter] to [ToolsSupport].
Future<void> runIntentCallStdioMcpServer({
  final AgentRegistry? registry,
  final List<AgentModule> modules = const <AgentModule>[],
}) async {
  IntentCallStdioMcpServer? serverRef;
  final adapter = McpPublishAdapter(
    publishTool: (final tool, final impl) =>
        serverRef!.registerTool(tool, impl),
    unpublishTool: (final name) => serverRef!.unregisterTool(name),
    publishResource: (final resource, final impl) =>
        serverRef!.addResource(resource, impl),
    unpublishResource: (final uri) => serverRef!.removeResource(uri),
    publishResourceTemplate: (final template, final impl) =>
        serverRef!.addResourceTemplate(template, impl),
  );

  serverRef = IntentCallStdioMcpServer(
    stdioChannel(input: io.stdin, output: io.stdout),
    adapter: adapter,
  );
  final server = serverRef;

  final runtime = AgentRuntime(
    registry: registry,
    modules: modules,
    adapters: <AgentAdapter>[adapter],
  );
  await runtime.start();
  await server.initialized;
  await server.done;
  await runtime.stop();
}

base class IntentCallStdioMcpServer extends MCPServer
    with ToolsSupport, ResourcesSupport {
  IntentCallStdioMcpServer(
    super.channel, {
    required this.adapter,
  }) : super.fromStreamChannel(
          implementation: Implementation(
            name: 'intentcall',
            version: '0.6.0',
          ),
          instructions:
              'IntentCall registry-backed MCP server (minimal dogfood host).',
        );

  final McpPublishAdapter adapter;
}
