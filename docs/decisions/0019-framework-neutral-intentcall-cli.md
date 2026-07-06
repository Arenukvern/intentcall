# 0019. Framework-Neutral IntentCall CLI and Registry-Backed Manifest Generation

Date: 2026-07-07

## Status

Accepted

## Context

IntentCall's north star is *register intent truth once, project everywhere*.
Platform projection (`PlatformSync`, emitters, `agent_manifest.json`) is
framework-agnostic logic, but today's developer experience hardcodes
**mcp_flutter's** `flutter-mcp-toolkit codegen sync` in build hooks and lives
inside `intentcall_platform`, which requires the Flutter SDK for the plugin.
That blocks Jaspr, plain Dart CLIs, and MCP servers from using platform sync
without pulling Flutter.

`agent_manifest.json` is hand-maintained while [NORTH_STAR.mdx](../NORTH_STAR.mdx)
targets registry-backed generation — creating **two catalogs** (registry for
MCP, manifest for native) with no parity checks.

`@AgentTool` codegen emits `AgentCallEntry` but not manifest. Projection
metadata (`dispatchMode`, `surfaces`, `inlineRuntime`) is manifest-local per
[ADR 0016](0016-dispatch-mode-handoff-contract.md) — it must be **authored once**
alongside code, not duplicated in per-tool YAML rows.

[mcp_flutter](https://github.com/Arenukvern/mcp_flutter) is a **product harness**
([ADR 0010](0010-adopt-intentcall-product-name.md)), not the owner of platform
contracts.

## Decision

### Framework-neutral CLI and package split

1. **Publish `intentcall_cli`** — framework-neutral consumer CLI (`intentcall`
   executable).
2. **Extract `intentcall_platform_sync`** — Dart-only package owning manifest
   parsing, emitters, `PlatformSync`, hook templates, invocation envelope types,
   and `ManifestMerger` (no Flutter SDK).
3. **Keep `intentcall_platform`** — Flutter plugin + `IntentCallFlutterHost`
   runtime bridge only; re-export `intentcall_platform_sync` for backward
   compatibility.
4. **`intentcall.yaml` is host wiring only:** `host`, `protocolScheme`, `layout`,
   `platforms.enabled`, `hooks.syncCommand`, global projection defaults. **No**
   per-tool descriptor rows.
5. **`flutter-mcp-toolkit`** delegates `codegen sync` and `init intentcall-platform`
   to `intentcall`; it does not own manifest or sync semantics.

### Registry-backed manifest (single truth)

1. **`agent_manifest.json` is a generated artifact** — committed like `.g.dart`,
   refreshed by `build_runner` + `intentcall manifest export --check`.
2. **Authoring surface:**
   - Semantic truth: `AgentCallEntry` / `@AgentTool` (namespace, name,
     description, schema, handler).
   - Projection policy: `@AgentProjection` on annotated tools OR keyed
     `.intentcall/projection.yaml` overlay for handwritten entries
     (`dispatchMode`, `surfaces`, `inlineRuntime` only — no schema duplication).
3. **`intentcall_codegen` gains two builders:**
   - `AgentCatalogBuilder` → `lib/generated/agent_catalog.g.dart` (aggregates
     all registrations).
   - `AgentManifestBuilder` → path from `intentcall.yaml` (default
     `web/agent_manifest.json`).
4. **`ManifestMerger`** in `intentcall_platform_sync` merges catalog entries,
     projection policy, and entity types into one canonical manifest.

### Three validation gates

| Gate | Proves | Command |
|------|--------|---------|
| Manifest freshness | Committed manifest == merge(catalog, projection) | `build_runner` then `intentcall manifest export --check` |
| Artifact freshness | Native/web files == emit(manifest) | `intentcall platform sync --check` |
| Descriptor parity | Every manifest entry ⊆ registry; no orphan tools | `manifest_registry_parity_test` |

### Per-host workflow

| Host | build_runner | manifest | platform sync | Runtime |
|------|-------------|----------|---------------|---------|
| Flutter | required | generated, committed | hooks run export --check + sync | registry + Flutter plugin |
| Jaspr | required | generated (web) | `intentcall platform sync --platform web --check` | registry + WebMCP |
| MCP server | optional | skip | skip | registry + `intentcall_mcp` |
| Dart CLI | optional | skip | skip | registry invoke |

## Consequences

Good:

- One platform contract for Flutter, Jaspr, MCP servers, and plain Dart hosts.
- No duplicate catalogs; CI can prove manifest/registry parity.
- Hook templates use `intentcall` — no Flutter harness required for codegen.

Tradeoffs:

- Two new packages in the release train.
- Existing apps must migrate hand-edited manifest descriptor rows to generated
  output + projection overlay.
- mcp_flutter needs a follow-up PR to delegate (documented contract).

## Non-goals

- Runtime isolate/reflection manifest export as the primary path.
- Putting `dispatchMode` in `intentcall_schema` wire types.
- Mandatory codegen for dynamic MCP hosts that register at runtime.
- Replacing mcp_flutter harness (VM, inspector, Flutter init UX).
- Live OS proof (Shortcuts/Siri) — still consuming-app responsibility.

### mcp_flutter delegation (follow-up PR)

`flutter-mcp-toolkit` should delegate without re-owning manifest semantics:

```bash
flutter-mcp-toolkit codegen sync "$@"  →  intentcall platform sync --host flutter "$@"
flutter-mcp-toolkit init intentcall-platform  →  intentcall platform hooks init --host flutter "$@"
```

Add `intentcall_cli` as a hosted dependency in [mcp_flutter](https://github.com/Arenukvern/mcp_flutter).

## Links

- [ADR 0016 — Dispatch Mode Handoff Contract](0016-dispatch-mode-handoff-contract.md)
- [ADR 0010 — Adopt IntentCall product name](0010-adopt-intentcall-product-name.md)
- [NORTH_STAR.mdx](../NORTH_STAR.mdx)
