import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:intentcall_mcp/intentcall_mcp.dart';
import 'package:intentcall_testing/intentcall_testing.dart';
import 'package:test/test.dart';

void main() {
  test('McpPublishAdapter satisfies the shared native contract', () async {
    final published =
        <String, FutureOr<CallToolResult> Function(CallToolRequest)>{};
    final adapter = McpPublishAdapter(
      publishTool: (final tool, final impl) {
        published[tool.name] = impl;
      },
      unpublishTool: published.remove,
    );

    final proof = await verifyNativeAdapterContract(
      adapter: adapter,
      isPublished: published.containsKey,
      invoke: (final qualifiedName, final arguments) {
        final invoker = published[qualifiedName];
        if (invoker == null) {
          throw StateError('No MCP tool published for $qualifiedName');
        }
        return invoker(
          CallToolRequest(name: qualifiedName, arguments: arguments),
        );
      },
      normalize: (final result) => normalizeJsonTextAgentResult(
        mcpResultToAgentResult(result! as CallToolResult),
      ),
    );

    expect(proof.adapterId, 'mcp');
    expect(proof.hotSyncProven, isTrue);
    expect(proof.detachCleanupProven, isTrue);
  });
}
