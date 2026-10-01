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
  final IntentCallStdioMcpServer serverRef = IntentCallStdioMcpServer(
    stdioChannel(input: io.stdin, output: io.stdout),
  );

  final adapter = McpPublishAdapter(
    publishTool: serverRef.registerTool,
    unpublishTool: serverRef.unregisterTool,
    publishResource: serverRef.addResource,
    unpublishResource: serverRef.removeResource,
    publishResourceTemplate: serverRef.addResourceTemplate,
  );

  final runtime = AgentRuntime(
    registry: registry,
    modules: modules,
    adapters: <AgentAdapter>[adapter],
  );
  await runtime.start();
  await serverRef.initialized;
  await serverRef.done;
  await runtime.stop();
}

base class IntentCallStdioMcpServer extends MCPServer
    with ToolsSupport, ResourcesSupport {
  IntentCallStdioMcpServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(name: 'intentcall', version: '0.6.0'),
        instructions:
            'IntentCall registry-backed MCP server (minimal dogfood host).',
      );
}
