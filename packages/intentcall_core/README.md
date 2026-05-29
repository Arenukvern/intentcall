> ⚠️ **Pre-release (0.1.x)** — Highly experimental. APIs may change without notice. Not for production. [Details](../../PRE_RELEASE.md).


# intentcall_core

Transport-agnostic agent intent registry and runtime for Flutter MCP Toolkit.

## Authoring

| Style | Server | Client (`mcp_toolkit`) |
|-------|--------|------------------------|
| Hand-written | `ToolRegistration` / `ResourceRegistration` via capability kernel | `AgentCallEntry` + `AgentModuleFromEntries` |
| Codegen (optional) | `@AgentTool` + build_runner pilot | Same annotations (optional) |

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
- `AgentClientInstall.once` in `mcp_toolkit` for lazy registration

## Related packages

- `intentcall_schema` — results, validation, wire args
- `intentcall_mcp` — MCP bridge, publish adapter, resource mapper
- `intentcall_webmcp` — WebMCP `modelContext` publish adapter
- `intentcall_gemma` — on-device Gemma function-calling adapter
- `intentcall_apple` / `intentcall_android` — `agent_manifest.json` codegen
- `intentcall_testing` — registry contract helpers

Design spec (in parent repo): [intentcall design](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/superpowers/specs/2026-05-25-intentcall-design.md).