# dart_acp_toolkit

Standalone [Agent Client Protocol](https://agentclientprotocol.com) (ACP) server library — JSON-RPC 2.0 over stdio with pluggable agent backends. Pure Dart, workspace-only (not published to pub.dev).

## What it is

ACP is the protocol editors like Zed use to talk to coding agents. This package implements the ACP v1 baseline:

- `initialize` → protocol version + capability negotiation
- `session/new` → backend session creation
- `session/prompt` → one prompt turn, streaming `session/update` notifications
- `session/cancel` → cancels in-flight work
- `session/request_permission` → client-side permission callback

Agent behavior is supplied by an [`AcpAgentBackend`](lib/src/acp_agent_backend.dart); the server owns the transport and protocol lifecycle.

## Backends

| Backend  | Class                | Purpose                                                                     |
| -------- | -------------------- | --------------------------------------------------------------------------- |
| Echo     | `EchoAcpBackend`     | Conformance smoke target; echoes prompts with plan/chunk/tool-call updates. |
| Registry | `RegistryAcpBackend` | Projects an IntentCall `AgentRegistry` into ACP.                            |

### Registry backend

`RegistryAcpBackend` maps prompt text to registry invocations:

```text
contract_echo {"text": "hello", "count": 2}
```

- First token = registry qualified name (`namespace_name`).
- Remainder parsed as a JSON object when possible; otherwise passed as `{'text': ...}`.
- Results stream as `session/update` notifications (tool-call lifecycle + message chunk).
- Unknown intents and failed invocations return a JSON error payload and a `refusal` stop reason.

```dart
final backend = RegistryAcpBackend(registry: myRegistry);
final server = AcpStdioServer(backend: backend);
await server.run();
```

## Running the stdio server

```sh
dart run bin/acp_server.dart --backend echo      # smoke
dart run bin/acp_server.dart --backend registry  # AgentRegistry-backed
```

Register in Zed (or any ACP client) as an agent command pointing at the chosen backend.

## Relationship to IntentCall

This package lives in the IntentCall workspace because the registry backend makes ACP another projection of the same intent truth: define tools once in `AgentRegistry`, expose them over MCP (`intentcall_mcp`), WebMCP (`intentcall_webmcp`), and now ACP. The adapter stays thin — it publishes nothing ahead of time; prompts name intents directly.

## Status

Pre-release, workspace-only. The echo path has full stdio lifecycle tests; the registry backend has unit tests covering invocation, argument parsing, failure mapping, and tool-call updates. Live editor-client proof (Zed) is not yet recorded.
