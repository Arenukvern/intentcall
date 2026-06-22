---
status: accepted
date: 2026-06-22
decision-makers: IntentCall maintainers
consulted:
informed:
---

# Own runtime sessions in IntentCall

## Context and Problem Statement

IntentCall already owns the reusable callable surface: registry, descriptors,
invocation, results, artifacts, and registry events. `mcp_flutter` previously
grew CLI session state around Flutter VM connections, then a temporary broker
extraction risked adding another command and dynamic-registry layer beside
IntentCall.

Downstream tools need the same session mechanics without importing Flutter MCP
server internals: start or attach to a live runtime, persist the selected
endpoint, invoke registered intents, and keep file-backed session state durable.

## Decision Drivers

* **Single command model** - IntentCall invocation is the command envelope.
* **No facade packages** - public packages must own behavior, not re-export it.
* **Hard-cut clarity** - pre-release consumers should update imports instead of
  carrying stale compatibility exports.
* **Runtime neutrality** - sessions should work for CLI, MCP, apps, and tools
  without pulling in Flutter VM or MCP server dependencies.
* **Persistence continuity** - existing file-backed session behavior remains
  the default.

## Considered Options

* **Keep a broker package in `mcp_flutter`** - rejected because it would sit
  beside IntentCall and duplicate registry/invocation ownership.
* **Rename broker to a toolkit session package** - rejected because reusable
  session semantics belong with the IntentCall runtime, not a consumer repo.
* **Move sessions into IntentCall** - chosen because sessions are runtime
  context for IntentCall invocation.

## Decision Outcome

Create `intentcall_session` as the owner of runtime session lifecycle and
persistence. It provides file-backed session state, state locking, safe writes,
session start/attach/end operations, and an `AgentRegistry` session executor.

The package does not define a dynamic registry, command catalog, artifact model,
transport, Flutter VM connector, MCP server, or visual debugger. Those remain in
`intentcall_core`, `intentcall_schema`, adapter packages, or concrete consumer
repos.

`mcp_flutter` consumes `intentcall_session` directly. The temporary broker
package and compatibility re-export shims are removed.

### Consequences

* Good, because downstreams use the same session behavior without Flutter MCP
  server internals.
* Good, because IntentCall remains the single owner of dynamic registry and
  invocation semantics.
* Neutral, because Flutter MCP still needs a concrete connector adapter for VM
  service targets.
* Bad, because pre-release consumers must update imports; accepted because stale
  compatibility layers would obscure the real owner.

## Links

* [NORTH_STAR.md](../NORTH_STAR.mdx)
* [DESIGN_FAQ.md](../DESIGN_FAQ.mdx)
