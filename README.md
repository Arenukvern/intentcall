# agentkit

> **Pre-release (`0.1.x`)** — Highly experimental. APIs may change without notice. **Not for production.** See [PRE_RELEASE.md](PRE_RELEASE.md).

Transport-agnostic agent intent platform (extracted from [mcp_flutter](https://github.com/Arenukvern/mcp_flutter)).

Standalone workspace at `~/mcp/agentkit` (sibling to `mcp_flutter`). Consumer integration tests run in the parent repo: `make -C ../mcp_flutter check-agentkit-integration` with `AGENTKIT_ROOT` pointing here (default when cloned as siblings).

## Packages

| Package | Role |
|---------|------|
| `agentkit_schema` | Wire types, validation, `AgentResult` |
| `agentkit_core` | Registry, runtime, `AgentCallEntry` |
| `agentkit_mcp` | MCP publish adapter (`dart_mcp`) |
| `agentkit_webmcp` | WebMCP hot-sync adapter |
| `agentkit_platform` | Native/web emitters + Flutter plugin |
| `agentkit_codegen` | Optional `@AgentTool` codegen |
| `agentkit_testing` | Contract / invoke test helpers |
| `agentkit_gemma` / `agentkit_apple` / `agentkit_android` | Optional surface adapters |

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

App authors should prefer **`mcp_toolkit`** + `flutter-mcp-toolkit` CLI. Agentkit packages are for platform work and advanced integration.

## Publishing

See [PUBLISHING.md](PUBLISHING.md). Execute publish only with pub.dev credentials: `bash tool/agentkit/publish_all.sh --execute`.
