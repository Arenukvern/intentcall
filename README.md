# intentcall

> **Pre-release (`0.1.x`)** — Highly experimental. APIs may change without notice. **Not for production.** See [PRE_RELEASE.md](PRE_RELEASE.md).

Transport-agnostic agent intent platform (extracted from [mcp_flutter](https://github.com/Arenukvern/mcp_flutter)).

Standalone workspace at `~/mcp/agentkit` (sibling to `mcp_flutter`). GitHub: [Arenukvern/intentcall](https://github.com/Arenukvern/intentcall). See [docs/decisions/0010-adopt-intentcall-product-name.md](docs/decisions/0010-adopt-intentcall-product-name.md). Consumer integration tests run in the parent repo: `make -C ../mcp_flutter check-intentcall-integration` with `INTENTCALL_ROOT` pointing here (default when cloned as siblings).

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

## Git history

This repository starts with a **fresh history** (2026-05-28). Packages were developed inside `mcp_flutter` until Phase 7 extract; `git filter-repo` / subtree split was deferred to avoid timebox risk. Use `mcp_flutter` git log before the extract commit for prior package history.

## Flutter MCP Toolkit

App authors should prefer **`mcp_toolkit`** + `flutter-mcp-toolkit` CLI. IntentCall packages are for platform work and advanced integration.

## Publishing

See [PUBLISHING.md](PUBLISHING.md). Execute publish only with pub.dev credentials: `bash tool/intentcall/publish_all.sh --execute`.
