> ⚠️ **Pre-release (0.1.x)** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_mcp

MCP bridge: `McpPublishAdapter`, registry ↔ `dart_mcp` publish.

Depends on `intentcall_core` and `intentcall_schema`. Only intentcall package that imports `dart_mcp`.

## What it owns

- publishing `AgentRegistry` tools to MCP tools
- publishing IntentCall resources and resource templates to MCP resources
- mapping `AgentResult` success/failure envelopes to MCP tool/resource results
- hot-syncing registry events into the `dart_mcp` server surface

It does not own the neutral registration vocabulary. `ToolRegistration`,
`ToolHandler`, `ResourceRegistration`, `ResourceTemplateRegistration`, and
`ResourceHandler` are owned by `intentcall_core`; this package re-exports them
so existing MCP adapter imports remain source-compatible.

```dart
import 'package:intentcall_mcp/intentcall_mcp.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

// Compatibility import: ToolRegistration is re-exported from intentcall_core.
final registration = ToolRegistration(
  name: 'echo',
  description: 'Echo arguments',
  inputSchema: const <String, Object?>{'type': 'object'},
  handler: (arguments) async => AgentResult.success(data: arguments),
);
```

It also does not own runtime sessions, dynamic discovery inside an app, Flutter
VM inspection, screenshots, or CLI process management. Use `intentcall_session`
for session lifecycle and concrete hosts such as `mcp_flutter` for runtime
adapters.

## Resource behavior

Static IntentCall resources are also published as query-tolerant MCP resource
templates when the host provides a template publisher. This keeps resources
visible in `resources/list` while allowing reads such as:

```text
visual://localhost/view/details?uri=ws%3A%2F%2F127.0.0.1%2Fws
```

The adapter de-duplicates resource templates by URI pattern. This matters for
dynamic hosts that may publish the same app resource through both host
capability registration and registry discovery.
