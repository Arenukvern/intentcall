# 0022. Projection Pipeline Alignment — Dense Export and Apple Sub-Channels

Date: 2026-07-07

## Status

Accepted

## Context

[ADR 0020](0020-platform-scoped-manifest-surfaces.md) scoped default manifest
surfaces to `platforms.enabled`, but export still emitted sparse surface maps,
emitters disagreed on absent-key semantics, and Apple projection treated App
Intent struct emission, Shortcuts phrases, entity queries, and Spotlight indexing
as one bundle.

The [projection pipeline spec](../evidence/projection-pipeline-spec.md) requires
Layer 3 alignment before entity lifecycle and consumer harness work proceed.

## Decision

1. **Dense export** — `AgentManifestSurfacePolicy.toJson()` and
   `resolveEntrySurfaces()` always emit **all** `AgentManifestSurface` values with
   explicit `include: true | false`. Absent keys in handwritten yaml are not
   exported; merge resolves them before serialization.

2. **Partial yaml merge** — `ProjectionPolicy.resolvedDefaultSurfaces()` applies
   precedence: explicit `defaults.surfaces` key → platform-scoped default for that
   surface family → legacy `defaultSurfaceInclude()` when `platforms.enabled` is
   empty.

3. **Apple shortcuts opt-in (ADR 0016 preserved)** — `apple.appShortcuts` never
   auto-enables from `platforms.enabled` alone. Authors must set it explicitly in
   yaml, catalog `@AgentProjection`, or per-entry overlay.

4. **New Apple surfaces** (additive; manifest schema version stays `1`):

   | Enum | Manifest key | Default when `ios`/`macos` enabled |
   |------|--------------|-------------------------------------|
   | `appleAppIntents` | `apple.appIntents` | `true` |
   | `appleAppShortcuts` | `apple.appShortcuts` | `false` (opt-in) |
   | `appleSpotlight` | `apple.spotlight` | `false` |
   | `appleEntities` | `apple.entities` | `false` |

5. **Emitter gating** — `AppleSwiftAppIntentsEmitter` reads dense manifest rows:
   - Swift `AppIntent` structs ← `apple.appIntents`
   - `AppShortcutsProvider` rows ← `apple.appShortcuts`
   - `AppEntity` / `EntityQuery` / snapshot store ← `apple.entities`
   - `CoreSpotlight` / `IndexedEntity` / indexer helpers ← `apple.spotlight`

6. **`intentcall_apple` manifest generator** — deprecated on the main path;
   `intentcall_platform_sync` emitters are canonical. No new features land in
   `intentcall_apple`.

## Consequences

- Tool rows grow from 8 to 11 surface keys; regenerating fixtures is required in
  the same change set as enum additions.
- iOS/macOS hosts get App Intent structs by default; Shortcuts, entities, and
  Spotlight remain explicit opt-in surfaces.
- Emitters treat missing surface keys as excluded (`defaultValue: false`).
- Codegen `@AgentProjection` and yaml may address each Apple sub-channel
  independently.

## Related

- [0016-dispatch-mode-handoff-contract.md](0016-dispatch-mode-handoff-contract.md)
- [0018-additive-actions-typed-entities-indexing-lifecycle.md](0018-additive-actions-typed-entities-indexing-lifecycle.md)
- [0020-platform-scoped-manifest-surfaces.md](0020-platform-scoped-manifest-surfaces.md)
- [0021-agent-catalog-annotation.md](0021-agent-catalog-annotation.md)
- [projection-pipeline-spec.md](../evidence/projection-pipeline-spec.md)
