# 0023. Entity Three-Slot Projection and Property Roles

Date: 2026-07-07

## Status

Accepted

## Context

[ADR 0018](0018-additive-actions-typed-entities-indexing-lifecycle.md) defines
typed app entities as additive projection metadata: Dart owns snapshots; native
platforms cache JSON-safe rows for cold-start query and indexing.

Entity descriptors declare many properties (`name`, `summary`, `tags`, …), but
native discovery UIs expose a **fixed display surface**:

| Platform | Primary line | Secondary line | Search tokens |
|----------|--------------|----------------|---------------|
| Apple `AppEntity` | `title` | `subtitle` | `keywords: [String]` |
| Apple `DisplayRepresentation` | title | subtitle | — |
| IntentCall native cache search | `titleKey` field | `subtitleKey` field | `keywordsKey` array |

Apple is the first concrete emitter (`apple.entities`, `apple.spotlight`). Android
and Windows entity lanes are not implemented yet, but they will map to the same
neutral three-slot vocabulary rather than per-platform property lists.

Before this ADR, manifest export duplicated key-derivation heuristics in
`manifest_merger.dart` and `intentcall_apple`, sometimes hardcoding
`subtitleKey: 'subtitle'` while descriptors used domain field names like
`summary`. Authors had only `isDisplay` / `isSearchable` booleans with implicit
ordering (first display property → title), which is fragile when multiple
properties share a flag.

## Decision

### 1. Three-slot manifest vocabulary

Each `entityTypes[]` row in `agent_manifest.json` carries exactly three
snapshot key slots plus the identifier:

| Manifest key | Semantic role | Default when unset |
|--------------|---------------|--------------------|
| `idKey` | Stable entity identifier in cache rows | `id` |
| `titleKey` | Primary display string | `title` |
| `subtitleKey` | Secondary display string | `subtitle` |
| `keywordsKey` | Search token array | `keywords` |

Emitters and native stores read these keys from the manifest. They do **not**
project arbitrary `displayProperties` lists — only one property name per slot.

### 2. `AgentEntityPropertyRole`

Core vocabulary in `intentcall_core`:

```dart
enum AgentEntityPropertyRole { none, title, subtitle, keywords }
```

`AgentEntityPropertyDescriptor.role` defaults to `none`. Codegen
`@AgentEntityProperty(role: 'title' | 'subtitle' | 'keywords')` maps to this
enum. Entity-level overrides on `@AgentEntity` (`titleProperty`,
`subtitleProperty`, `keywordsProperty`) assign roles by property name at codegen
time.

Validation (codegen and `AgentEntitySnapshotKeys.fromDescriptor`):

- At most one property per role (`title`, `subtitle`, `keywords`).
- `keywords` role requires `valueType: array`.
- Entity-level override names must match a declared property.

### 3. Canonical key resolution

`AgentEntitySnapshotKeys.fromDescriptor(AgentEntityTypeDescriptor)` in
`intentcall_core` is the single source of truth for slot assignment. Precedence:

1. Explicit `role` on a property (or entity-level override resolved at codegen).
2. Heuristic fallback for backward compatibility:
   - `titleKey` ← first `isDisplay` property, else `'title'`
   - `subtitleKey` ← second `isDisplay`, else first `isSearchable` ≠ title, else `'subtitle'`
   - `keywordsKey` ← first `isSearchable` array property, else `'keywords'`

Consumers must call this API — not reimplement heuristics:

- `projectAgentEntitySnapshot()` (runtime cache rows)
- `generateEntityManifestJson()` in `intentcall_platform_sync`
- Deprecated `intentcall_apple` manifest generator (delegates to core)

### 4. Snapshot schema extensions

`agentEntitySnapshotSchema(descriptor)` emits JSON Schema for each entity type.
Property rows include additive extensions:

- `x-intentcall-display`, `x-intentcall-searchable`, `x-intentcall-indexed`
- `x-intentcall-role` when `role != none`

Manifest schema version stays `1`; extensions are additive.

### 5. Codegen typed field constants

For each `@AgentEntity`, codegen emits `{Namespace}{Name}EntityFields` with
`static const String` per property name (for example `AppProjectEntityFields.name`).
Authors use these constants with `AgentEntitySnapshotBuilder` to avoid string
typos when building cache rows. This is optional sugar; descriptors and manifest
keys remain the contract.

### 6. Platform mapping (current and future)

| Layer | Responsibility |
|-------|----------------|
| Dart `AgentEntitySnapshot` + `projectAgentEntitySnapshot` | Source rows keyed by descriptor fields |
| `agent_manifest.json` `entityTypes[]` | Declares slot → property name mapping |
| Apple `AppEntity` codegen | Fixed `title`/`subtitle`/`keywords` struct; reads snapshot via manifest keys |
| `IntentCallNativeEntitySnapshotStore` | Cold-start search over `titleKey`/`subtitleKey`/`keywordsKey` |
| Android / Windows (future) | Reuse same three slots; map to platform-specific labels when emitters land |

## Consequences

Good:

- One derivation path; manifest export and runtime projection stay aligned.
- Explicit roles remove guesswork when multiple properties are `isDisplay`.
- Neutral vocabulary is ready for non-Apple entity emitters without schema churn.
- `x-intentcall-role` in `snapshotSchema` documents intent for agents and tooling.

Tradeoffs:

- `IntentCallPlatformEntityIndex.upsertAgentSnapshots` was removed; use
  `upsertAgentSnapshotsForType` with an `AgentEntityTypeDescriptor` so cache
  rows align with manifest slot keys via `projectAgentEntitySnapshot()`.
- Only three discovery slots; extra display fields stay in `properties` but are
  not used for native string search unless a future ADR adds slots.
- Heuristic fallback remains for older catalogs; authors should migrate to
  explicit `role` or entity-level overrides.
- `isDisplay` / `isSearchable` booleans still exist for schema extensions and
  backward compatibility; `role` wins when both are set.

Neutral:

- This ADR does not require every app to declare entities.
- Indexed / Spotlight-specific behavior remains gated by manifest surfaces
  ([ADR 0022](0022-projection-pipeline-alignment.md)), not by property roles alone.

## Related

- [0018-additive-actions-typed-entities-indexing-lifecycle.md](0018-additive-actions-typed-entities-indexing-lifecycle.md)
- [0021-agent-catalog-annotation.md](0021-agent-catalog-annotation.md)
- [0022-projection-pipeline-alignment.md](0022-projection-pipeline-alignment.md)
- [0024-dart-hooks-and-pigeon-bridge-consistency.md](0024-dart-hooks-and-pigeon-bridge-consistency.md)
- [hooks-native-bridge-plan.md](../evidence/hooks-native-bridge-plan.md)
- [projection-pipeline-spec.md](../evidence/projection-pipeline-spec.md) (retired; see ADR 0024)
- `packages/intentcall_core/lib/src/entity/agent_entity_snapshot_keys.dart`
- `packages/intentcall_core/lib/src/entity/agent_entity_property_role.dart`

## Verification inventory

Primary test files for three-slot entity projection and manifest export:

| Test file | Coverage |
|-----------|----------|
| [`manifest_entity_export_test.dart`](../../packages/intentcall_cli/test/manifest_entity_export_test.dart) | `entityTypes[]` export with `idKey` / `titleKey` / `subtitleKey` / `keywordsKey` slots |
| [`intentcall_entity_index_test.dart`](../../packages/intentcall_platform/test/intentcall_entity_index_test.dart) | Native entity index search over manifest slot keys |
| [`agent_entity_snapshot_projection_test.dart`](../../packages/intentcall_core/test/agent_entity_snapshot_projection_test.dart) | `projectAgentEntitySnapshot()` maps descriptor roles to cache rows |
| [`projection_alignment_test.dart`](../../packages/intentcall_platform_sync/test/projection_alignment_test.dart) — `entityTypes in export` and `single native entity snapshot store` groups | Manifest `entityTypes` passthrough and Apple emitter entity store wiring |
