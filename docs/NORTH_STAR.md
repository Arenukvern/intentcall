# IntentCall — North Star

**Tagline:** *Register intents. Call them everywhere.*

IntentCall is a **transport-agnostic agent intent platform** for Dart/Flutter. It provides a central registry (`AgentRegistry`), a typed invocation model (`AgentCallEntry` / `RegisteredAgentIntent`), and adapters that publish those intents to multiple transports — MCP, WebMCP, native Apple/Android surfaces — from a single source of truth.

---

## What this repo owns

| In scope | Out of scope |
|---|---|
| `intentcall_schema` — wire types, validation, `AgentResult` | Product harness for app authors → **mcp_flutter / mcp_toolkit** |
| `intentcall_core` — registry, runtime, call entries | Agent skill meta-layer → **Skill Steward** |
| `intentcall_mcp` — MCP publish adapter | Embedding / RAG / LLM backends |
| `intentcall_webmcp` — WebMCP hot-sync adapter | UI rendering, visual harness reconstruction |
| `intentcall_platform` — native/web emitters + Flutter plugin | Any production app serving end users |
| `intentcall_codegen` — optional `@AgentTool` code generation | |
| `intentcall_testing` — contract / invoke test helpers | |
| `intentcall_gemma` / `intentcall_apple` / `intentcall_android` — surface adapters | |

**Do not own:** harness tooling (CLI, inspector UI), skill governance, LLM prompt engineering, or any product that wraps IntentCall for end users.

---

## Success criteria

1. A Flutter app can register intents once and expose them over MCP and WebMCP without per-transport boilerplate.
2. The `intentcall_schema` wire contract is stable enough that adapters can evolve independently without breaking consumers.
3. `make test && make analyze && make publish-dry-run` stays green on every PR.
4. A new adapter author can read `intentcall_core` + one existing adapter and ship a working adapter in a single session.

---

## Ecosystem

| Repo | Role |
|---|---|
| **IntentCall** (this repo) | Platform layer — registry + adapters |
| **[mcp_flutter](https://github.com/Arenukvern/mcp_flutter)** | Product harness — `mcp_toolkit`, `flutter-mcp-toolkit` CLI |
| **[Skill Steward](https://github.com/Arenukvern/skill_steward)** | Meta-layer — agent skills governance |

---

## Ethical principles

IntentCall is **pre-release platform infrastructure**, not a consumer product. These principles govern how it is built:

1. **Legibility over magic.** APIs must be deterministic and include remediation paths in errors. Do not paraphrase code logic in docs — link to the implementation.
2. **Reversibility.** Installers and codegen must never leave undocumented side-effects. Uninstall must be as clean as install.
3. **No bloat.** Refuse feature requests that introduce convenience over clarity. Keep the dependency footprint minimal per package.
4. **Behavior-as-truth.** Wire contracts (`intentcall_schema`) define the protocol. Adapters implement; they do not redefine.
5. **Artisan credit.** Human authorship is primary. AI is a collaborator; all significant decisions are recorded in ADRs with date and decision-maker.

---

## Pre-release status

All packages are **0.1.x** — experimental. APIs may change without a major semver bump. See [PRE_RELEASE.md](../PRE_RELEASE.md).

## Key docs

- [AGENTS.md](../AGENTS.md) — agent map and navigation pointers
- [DESIGN_FAQ.md](../DESIGN_FAQ.md) — why IntentCall is built this way
- [DX_FAQ.md](../DX_FAQ.md) — how to use and extend IntentCall
- [docs/decisions/](decisions/) — architecture decision records
- [CONTRIBUTING.md](../CONTRIBUTING.md) — how to contribute
- [PUBLISHING.md](../PUBLISHING.md) — pub.dev publishing guide
