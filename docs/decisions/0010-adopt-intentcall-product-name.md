---
status: accepted
date: 2026-05-29
decision-makers: IntentCall maintainers
consulted:
informed:
---

# Adopt IntentCall as the public product name

## Context and Problem Statement

The repository was introduced as **agentkit** — a transport-agnostic **agent intent platform**: central registry (`AgentRegistry`), `RegisteredAgentIntent`, adapters (MCP, WebMCP, native Apple/Android), `agent_manifest.json`, and `agentkit://invoke/<qualifiedName>`.

In October 2025, **OpenAI announced [AgentKit](https://openai.com/index/introducing-agentkit/)** — a different product (visual agent builder, ChatKit, evals). That collision blocks clear search, pub.dev naming, and public positioning for this codebase.

The maintainer ecosystem also includes:

- **[mcp_flutter](https://github.com/Arenukvern/mcp_flutter)** — product **harness** (`mcp_toolkit`, `flutter-mcp-toolkit` CLI).
- **[Skill Steward](https://github.com/Arenukvern/skill_steward)** — meta-layer for Agent Skills ([ADR 0008](https://github.com/Arenukvern/skill_steward/blob/main/docs/decisions/0008-adopt-skill-steward-product-name.md)).
- **flutter_harness**, **flutter_visual_reconstruct** — sibling specs and path overrides.

We need one **public name** that states *register intents, invoke everywhere* without colliding with OpenAI or crowded “intent kit / mux” products, while allowing incremental repository and folder migration.

## Decision Drivers

* **Collision safety** — avoid OpenAI AgentKit, Coinbase/crestal IntentKit, AgentMux, and near-neighbor **AgentSpan** (agents + MCP).
* **Semantic fit** — intents + call/invoke; aligns with `AgentCallEntry`, `RegisteredAgentIntent`, registry + adapters.
* **Ecosystem clarity** — distinct from mcp_flutter harness and Skill Steward meta-layer.
* **Incremental migration** — package rename in-repo first; GitHub repo rename and pub.dev publish order documented separately.
* **DX** — predictable package prefix and URI scheme for Flutter/MCP consumers.

## Considered Options

* **Keep agentkit** — no rename cost; permanent confusion with OpenAI AgentKit.
* **IntentKit** — rejected; crowded “intent” namespace and existing IntentKit products.
* **IntentMux / AgentMux** — rejected; mux products and ambiguous positioning.
* **CallSpan** — rejected; **[AgentSpan](https://github.com/agentspan-ai/agentspan)** too close; weaker “intent registry” story.
* **IntentCall** — chosen: intents + invoke; no major product collision found in shortlist review.

## Decision Outcome

Chosen option: **IntentCall** as the **public product name**.

**Tagline (canonical):** *Register intents. Call them everywhere.*

### Naming map

| Before | After |
|--------|--------|
| `agentkit_*` packages | `intentcall_*` |
| `agentkit://invoke/...` | `<app-scheme>://invoke/...` |
| `tool/agentkit/` | `tool/intentcall/` |
| `make check-agentkit-integration` | `make check-intentcall-integration` |
| `init agentkit-platform` (CLI) | `init intentcall-platform` |
| Android/iOS plugin id `dev.agentkit.*` | `dev.intentcall.*` |
| Generated `AgentKitGenerated.swift` | `IntentCallGenerated.swift` |

**Workspace root pubspec:** `intentcall_workspace`.

**Sibling checkout path:** consumers can use repo-relative `../agentkit/packages/intentcall_*` path dependencies during local development.

### Consequences

* Good, because public docs, packages, and URIs no longer compete with OpenAI AgentKit in search or pub.dev.
* Good, because name matches registry + invoke mental model for harness integrators.
* Neutral, because **historical** superpowers ADRs/plans may retain `intentcall` in renamed filenames while git history in mcp_flutter still references pre-extract agentkit work.
* Neutral, because **GitHub repository** may remain `agentkit` until maintainer renames; CI may checkout `agentkit` until then (see Follow-up).
* Bad, if renamed without updating sibling path overrides — mitigated by `make check-intentcall-integration` in mcp_flutter.

### Follow-up

| Item | Action |
|------|--------|
| GitHub repo | Done — `Arenukvern/intentcall`; local clone folders may keep their existing names until maintainers choose to rename them |
| pub.dev | Publish `intentcall_*` packages; deprecate `agentkit_*` if ever published |
| Skill Steward / bios | Update ecosystem docs to say IntentCall |
| Local folder | Optional: rename local checkout folders after the GitHub rename |

## Links

* [IntentCall North Star](/NORTH_STAR)
* [IntentCall Design FAQ](/DESIGN_FAQ)
* [PRE_RELEASE.md](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md)
* [PUBLISHING.md](https://github.com/Arenukvern/intentcall/blob/main/PUBLISHING.md)
* [Skill Steward ADR 0008 — naming pattern](https://github.com/Arenukvern/skill_steward/blob/main/docs/decisions/0008-adopt-skill-steward-product-name.md)
