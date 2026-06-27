> ⚠️ **Pre-release train** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_core

Transport-agnostic agent intent registry and runtime for Dart and Flutter apps.

## Authoring

| Style | Runtime registration | Consumer host |
|-------|--------|------------------------|
| Hand-written | `RegisteredAgentIntent` via `AgentCallEntry` | Flutter, CLI, MCP, WebMCP, or custom adapters |
| Codegen (optional) | `@AgentTool` + build_runner pilot | Generated entries can be composed by any host |

Authors define **descriptors + executors**; they do not implement a public `AgentIntent` interface. The registry stores `RegisteredAgentIntent` (descriptor + `execute`).

## Invoke path

```
MCP CallToolRequest → AgentRegistry.invoke → AgentResult → CallToolResult
```

The Flutter MCP server uses `McpHost`, which owns an `AgentRuntime` with `McpPublishAdapter` as the sole MCP attach path: registry registration drives MCP publish via `IntentRegistered` events, and `runtime.stop()` on host dispose.

MCP publish lives in `intentcall_mcp` (`McpPublishAdapter`). WebMCP and Gemma use parallel adapters on the same registry:

```dart
final runtime = AgentRuntime(
  registry: InMemoryAgentRegistry(),
  adapters: [
    McpPublishAdapter(publish: ..., unpublish: ...),
    WebMcpPublishAdapter(publish: ..., unpublish: ...),
    GemmaPublishAdapter(register: ..., unregister: ...),
  ],
);
await runtime.start();
```

## Client helpers

- `AgentResult.envelope` / `resourceEnvelope` (`intentcall_schema`)
- `AgentWireArgs` for string-key maps
- Tool/resource registration contracts for hosts that expose capability
  surfaces without depending on a concrete transport adapter
- `AgentClientInstall.once` in `mcp_toolkit` for lazy registration

## Public surface ownership

`intentcall_core` owns the transport-neutral registry, invocation, and
registration vocabulary:

- `AgentRegistry`, `AgentRuntime`, `AgentCallEntry`, and
  `RegisteredAgentIntent`
- `ToolRegistration` / `ToolHandler`
- `ResourceRegistration`, `ResourceTemplateRegistration`, and
  `ResourceHandler`

Adapters may re-export these value objects for source compatibility, but they
should treat `intentcall_core` as the canonical owner. Use
`intentcall_mcp` only when you need the MCP publishing adapter or MCP result and
resource mapping helpers.

```dart
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

final registration = ToolRegistration(
  name: 'echo',
  description: 'Echo arguments',
  inputSchema: const <String, Object?>{'type': 'object'},
  handler: (arguments) async => AgentResult.success(data: arguments),
);
```

## Migration helpers

The main `intentcall_core.dart` barrel is the runtime/authoring API. The legacy
`MCPCallEntry` migration helpers are intentionally exposed through a separate
library so downstream packages can depend on them explicitly:

```dart
import 'package:intentcall_core/intentcall_core_migration.dart';
```

Use this import for `MigrateAgentEntriesMigrator`,
`MigrateAgentEntriesReport`, `MigrateAgentEntriesPathNotFound`, and
`migrateAgentEntriesAtPath`.

## Related packages

- `intentcall_schema` — results, validation, wire args
- `intentcall_session` — reusable runtime session state, lifecycle, and JSON
  snapshot persistence
- `intentcall_mcp` — MCP bridge, publish adapter, resource mapper; re-exports
  core registration value objects for compatibility
- `intentcall_webmcp` — WebMCP `modelContext` publish adapter
- `intentcall_gemma` — on-device Gemma function-calling adapter
- `intentcall_apple` / `intentcall_android` — `agent_manifest.json` codegen
- `intentcall_testing` — registry contract helpers

Canonical design docs: [North Star](../../docs/NORTH_STAR.mdx), [Design FAQ](../../docs/DESIGN_FAQ.mdx), and [DX FAQ](../../docs/DX_FAQ.mdx).
