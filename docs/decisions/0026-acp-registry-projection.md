# 0026. Agent Client Protocol (ACP) as a Registry Projection

Date: 2026-08-22

## Status

Accepted

## Context

IntentCall's north star is *register intent truth once, project everywhere*.
Projections today cover MCP (`intentcall_mcp`), WebMCP
(`intentcall_webmcp`), on-device function calling (`intentcall_gemma`,
example-only), and platform artifacts. The Agent Client Protocol (ACP) — the
JSON-RPC-over-stdio protocol editors such as Zed use to talk to coding agents —
is a fourth transport lane with growing 2026 relevance for IDE-hosted agents.

A standalone ACP stdio server (`dart_acp_toolkit`, package dir
`packages/acp_toolkit`) already existed in the workspace but was orphaned:
absent from `justfile` test targets, the release-train metadata, and the README
package table; its pubspec pointed at the mcp_flutter repository; and it had no
connection to the `AgentRegistry`.

Separately, `xsoulspace_inference_core` plans to build a coding agent with an
agentic harness and wants to expose native tooling through IntentCall. ACP is
the natural surface for that: like MCP, CLI, and intents, it is just an
interface between client and server sides.

## Decision

1. **Adopt ACP as a registry projection.** `RegistryAcpBackend` maps prompt
   text to `AgentRegistry` invocations: first token is the qualified name,
   remainder parses as JSON arguments (plain-text fallback as `{text: ...}`).
   Results stream as ACP `session/update` notifications; failures map to JSON
   error payloads plus a `refusal` stop reason.
2. **Workspace-only for now.** `dart_acp_toolkit` stays `publish_to: none`
   until it has a shared adapter-contract test (`verifyNativeAdapterContract`)
   and a real consumer. It joins `workspaceOnlyPackages` in the release train
   metadata so version floors stay consistent.
3. **The backend stays thin** per the write-adapter rules: it publishes nothing
   ahead of time, translates prompts to invocations, and routes all execution
   through `registry.invoke`. No domain logic lives in the transport.
4. **Support tier: ecosystem alignment / native semantic (editor).** ACP is an
   editor-agent protocol, not an OS surface. Current evidence level: unit tests
   (invocation, argument parsing, failure mapping, tool-call lifecycle) plus
   full stdio lifecycle tests for the echo path. Live Zed round-trip proof is
   not yet recorded.

## Consequences

Good:

- One more projection of the same truth; tools registered once are callable
  from Zed-class clients without per-client adapters.
- `xsoulspace_inference_core` can embed `RegistryAcpBackend` to expose its
  inference tooling over ACP without duplicating registration.
- The orphaned package is now governed (tests wired into `just test`, README,
  release-train metadata).

Tradeoffs:

- Prompt-as-invocation is a thin convention, not a schema-negotiated tool list.
  Clients that want typed discovery should use MCP; ACP covers free-text agent
  surfaces. If a client needs `tools/list`, extend the backend later behind the
  same contract.
- One more workspace package to maintain until promotion or deletion.

## Non-goals

- Publishing `dart_acp_toolkit` to pub.dev in this change.
- Replacing MCP as the primary external-agent surface.
- Claiming live editor integration before a recorded Zed round-trip fixture.

## Related

- [NORTH_STAR](../NORTH_STAR.mdx) — platform support tiers
- [ADR 0019](0019-framework-neutral-intentcall-cli.md) — framework-neutral CLI
- [write-adapter skill](../../skills/write-adapter/SKILL.md) — thinness rules
