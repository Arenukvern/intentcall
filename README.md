# IntentCall

[![maintained with Skill Steward](https://raw.githubusercontent.com/Arenukvern/skill_steward/main/docs/brand/assets/svg/badge-solid.svg)](https://github.com/Arenukvern/skill_steward)

> **Pre-release (`0.1.x`)** — Highly experimental. APIs may change without notice. **Not for production.** See [PRE_RELEASE.md](PRE_RELEASE.md).

*Register intents. Call them everywhere.*

Transport-agnostic agent intent platform for Dart/Flutter — central registry (`AgentRegistry`), typed invocation model, and adapters for MCP, WebMCP, and native surfaces. Extracted from [mcp_flutter](https://github.com/Arenukvern/mcp_flutter).

**Charter:** [docs/NORTH_STAR.md](docs/NORTH_STAR.md) · **Agent map:** [AGENTS.md](AGENTS.md)  
**Why / how:** [DESIGN_FAQ.md](DESIGN_FAQ.md) · [DX_FAQ.md](DX_FAQ.md) · [Decisions](docs/decisions/) · [CONTRIBUTING.md](CONTRIBUTING.md)

GitHub: [Arenukvern/intentcall](https://github.com/Arenukvern/intentcall)

## Ecosystem

| Repo | Role |
|---|---|
| **IntentCall** (this repo) | Platform layer — registry + adapters |
| **[mcp_flutter](https://github.com/Arenukvern/mcp_flutter)** | Product harness — `mcp_toolkit`, `flutter-mcp-toolkit` CLI |
| **[Skill Steward](https://github.com/Arenukvern/skill_steward)** | Meta-layer — agent skills governance |

## Packages

| Package | Role |
|---------|------|
| `intentcall_schema` | Wire types, validation, `AgentResult` |
| `intentcall_core` | Registry, runtime, `AgentCallEntry` |
| `intentcall_mcp` | MCP publish adapter (`dart_mcp`) |
| `intentcall_webmcp` | WebMCP hot-sync adapter |
| `intentcall_platform` | Native/web emitters + Flutter plugin |
| `intentcall_codegen` | Optional `@AgentTool` codegen |
| `intentcall_testing` | Contract / invoke test helpers |
| `intentcall_gemma` / `intentcall_apple` / `intentcall_android` | Optional surface adapters |

## Development

```bash
dart pub get
make test
make analyze
make publish-dry-run   # pub.dev dry-run (all packages)
```

See [DX_FAQ.md](DX_FAQ.md) for detailed workflows.

## Git history

This repository starts with a **fresh history** (2026-05-28). Packages were developed inside `mcp_flutter` until Phase 7 extract; `git filter-repo` / subtree split was deferred to avoid timebox risk. Use `mcp_flutter` git log before the extract commit for prior package history.

## Flutter MCP Toolkit

App authors should prefer **`mcp_toolkit`** + `flutter-mcp-toolkit` CLI. IntentCall packages are for platform work and advanced integration.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). All PRs must pass `make test && make analyze && make publish-dry-run`.

## Publishing

See [PUBLISHING.md](PUBLISHING.md). Execute publish only with pub.dev credentials: `bash tool/intentcall/publish_all.sh --execute`.
