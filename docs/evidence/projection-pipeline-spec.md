# Platform Projection Completion Spec

**Status:** Draft for implementation  
**Date:** 2026-07-07  
**Goal:** Make manifest export, emitters, runtime bootstrap, Apple sub-channels, and entity lifecycle **one aligned pipeline** — with per-layer subagent lanes and native gates that prove each layer before the next starts.

**Disposition target:** `promote_to_artifact` → ADR `0021-projection-pipeline-alignment.md` + harness checks after Layer 5.

**Related:**

- [ADR 0016 — Dispatch mode handoff](../decisions/0016-dispatch-mode-handoff-contract.md)
- [ADR 0018 — Additive actions, typed entities, indexing](../decisions/0018-additive-actions-typed-entities-indexing-lifecycle.md)
- [ADR 0020 — Platform-scoped manifest surfaces](../decisions/0020-platform-scoped-manifest-surfaces.md)

---

## 1. Acceptance criteria (parent)

The work is done when **all** of the following hold:

| # | Criterion |
|---|-----------|
| A1 | Every exported `agent_manifest.json` tool row has **all 8 surfaces** with explicit `include: true/false` |
| A2 | Every emitter treats absent surface as **excluded** (`defaultValue: false`) |
| A3 | `platforms.enabled` scopes defaults correctly even when `defaults.surfaces` is partial |
| A4 | `apple.appShortcuts` stays **opt-in** when `ios`/`macos` enabled (ADR 0016 preserved) |
| A5 | Dart WebMCP bootstrap respects `web.webMcp` from manifest/catalog |
| A6 | `PlatformSync` reads manifest from `layout.manifest` and web dir from `layout.webDir` |
| A7 | Apple sub-channels are independently controllable (new surfaces + emitters) |
| A8 | Entity types export from catalog; single snapshot store; Spotlight indexing wired after upsert |
| A9 | `mcp_flutter` Jaspr + `flutter_test_app` pass three-gate CI |
| A10 | No orphan/broken emitter copies in `intentcall_platform` |

**Claim ceiling after full completion:** artifact + static CI proof.  
**Non-claims:** live Siri ranking, App Store discovery, signed-app Spotlight UX, exactly-once native delivery.

---

## 2. Cross-layer invariants (never break)

```yaml
invariants:
  source_of_truth: AgentRegistry + agent_catalog.g.dart + intentcall.yaml
  pipeline_order:
    - build_runner          # catalog
    - manifest export       # policy merge → dense manifest
    - platform sync         # emitters read manifest only
    - runtime bootstrap     # must not widen beyond manifest
  surface_keys_json: dotted   # web.webMcp, apple.appShortcuts, …
  surface_keys_yaml: camelCase_or_dotted  # both accepted in yaml
  apple_shortcuts_default: opt_in           # ADR 0016
  missing_surface_semantics: exclude        # after Layer 1
```

---

## 3. ADR prerequisites (before Layer 3)

Create **`docs/decisions/0021-projection-pipeline-alignment.md`** amending/clarifying 0020:

1. **Dense export** — export always emits all surfaces explicitly.
2. **Partial yaml merge** — `defaults.surfaces` per-key overrides platform-scoped fill; absent keys use platform scope.
3. **Apple shortcuts** — `apple.appShortcuts` never auto-enables from `platforms.enabled`; only `apple.appIntents` (new) may default on for ios/macos.
4. **New Apple surfaces** — `apple.appIntents`, `apple.spotlight`, `apple.entities` (names TBD, see Layer 3).
5. **Retire** `intentcall_apple` manifest generator from main path (deprecation note).

Layers 1–2 can start before ADR merge; Layer 3+ requires ADR accepted.

---

## 4. Layer specifications

### Layer 1 — Policy correctness (foundation)

**Outcome:** Export and policy are truthful; emitters cannot misread sparse manifests.

#### 4.1.1 Code changes

| Area | File(s) | Change |
|------|---------|--------|
| Dense `toJson` | `agent_manifest.dart` → `AgentManifestSurfacePolicy.toJson` | Emit all `AgentManifestSurface.values` with resolved `include` |
| Resolved surfaces helper | `manifest_merger.dart` or new `surface_resolver.dart` | `resolveEntrySurfaces(overlay, defaultSurfaces)` returns full map |
| Partial yaml merge | `projection_policy.dart` → `resolvedDefaultSurfaces` | If `defaultSurfaces` partial: merge each enum — explicit override → else platform-scoped default → else legacy default |
| Apple opt-in fix | `projection_policy.dart` → `defaultSurfaceIncludeForPlatforms` | `appleAppShortcuts` always `false` unless explicit yaml/catalog overlay |
| Emitter defaults | All emitters in `intentcall_platform_sync/lib/src/emitters/` | `defaultValue: false` everywhere |
| Tests | `manifest_merger_test.dart` | + partial defaults + ios enabled + apple shortcuts stay false |
| Fixtures | `intentcall_codegen/example`, `intentcall_cli/test/fixtures/*`, `mcp_flutter/jaspr_web_example` | Regenerate manifests |

#### 4.1.2 Subagent lane L1

| Field | Value |
|-------|-------|
| Role | Policy + export engineer |
| Write set | `intentcall_platform_sync/lib/src/{agent_manifest,projection}/*`, `test/manifest_merger_test.dart`, fixtures |
| Forbidden | Apple emitters, runtime bootstrap, mcp_flutter |
| Native gate | `dart test packages/intentcall_platform_sync/test/manifest_merger_test.dart` |
| Direct fix | yes |

#### 4.1.3 Layer 1 verification gate

```bash
# Gate L1-A: unit
dart test packages/intentcall_platform_sync/test/manifest_merger_test.dart

# Gate L1-B: codegen example (web-only scoping + dense surfaces)
dart test packages/intentcall_codegen/example/test/manifest_projection_test.dart

# Gate L1-C: every tool row has 8 surface keys (new test)
dart test packages/intentcall_platform_sync/test/dense_manifest_test.dart  # add

# Gate L1-D: emitter unit — opt-out honored
dart test packages/intentcall_platform_sync/test/native_emitters_test.dart
```

**Alignment check L1→L2:** Parse exported manifest; for each tool assert `surfaces.keys.length == 8`; run `platform sync --check` on web-only fixture — **zero** android/windows/linux artifact changes.

---

### Layer 2 — Runtime + sync parity

**Outcome:** Sync reads correct paths; runtime does not widen beyond manifest.

#### 4.2.1 Code changes

| Area | File(s) | Change |
|------|---------|--------|
| Layout wiring | `platform_sync.dart` | Load `layout.manifest`, `layout.webDir` from yaml (reuse `ManifestMerger` readers); `_resolveManifestFile` uses both |
| Export context consumption | `manifest_exporter.dart` | Pass `manifestRelativePath` to CLI `resolveManifestOutput` if not already unified |
| WebMCP bootstrap filter | `agent_web_mcp_bootstrap_web.dart`, `intentcall_flutter_host.dart` | Load manifest or accept `Set<String> webMcpQualifiedNames` from catalog projection; skip tools with `web.webMcp: false` |
| Manifest loader for runtime | New `ManifestSurfaceIndex` in `platform_sync` | `includes(qualifiedName, surface)` from parsed manifest |
| Web hardcoding (optional L2.1) | `web_manifest_emitter.dart` | Document `web+intentcall` vs `protocolScheme`; defer config to Layer 5 docs unless trivial |
| Orphan cleanup | `intentcall_platform/lib/src/emitters/*` | Delete or replace with `export` from `intentcall_platform_sync` |
| Stale JS | `intentcall_codegen/example/web/intentcall_webmcp.generated.js` | Regenerate; `app_demo_cart` must be absent |

#### 4.2.2 Subagent lanes (parallel after L1 gate passes)

| Lane | Role | Scope | Gate |
|------|------|-------|------|
| **L2a** | Sync/layout engineer | `platform_sync.dart`, `platform_sync_test.dart` | `dart test .../platform_sync_test.dart` |
| **L2b** | WebMCP runtime engineer | bootstrap + flutter host | New `webmcp_bootstrap_surface_test.dart` |
| **L2c** | Package hygiene | `intentcall_platform` orphan removal | `dart analyze packages/intentcall_platform` |

#### 4.2.3 Layer 2 verification gate

```bash
# Gate L2-A: custom layout.manifest
# Test fixture: intentcall.yaml layout.manifest: assets/agent_manifest.json
dart test packages/intentcall_platform_sync/test/platform_sync_layout_test.dart  # add

# Gate L2-B: WebMCP bootstrap respects opt-out
dart test packages/intentcall_platform_sync/test/webmcp_bootstrap_surface_test.dart  # add

# Gate L2-C: sync --check on web-only project does not touch android/
cd packages/intentcall_codegen/example && \
  dart run ../../intentcall_cli/bin/intentcall.dart manifest export --check && \
  dart run ../../intentcall_cli/bin/intentcall.dart platform sync --platform web --check

# Gate L2-D: generated JS excludes webMcp:false tools
rg -l 'app_demo_cart' packages/intentcall_codegen/example/web/intentcall_webmcp.generated.js && exit 1 || true
```

**Alignment check L2→L3:** Manifest `web.webMcp: false` → absent from JS **and** Dart bootstrap registration in integration test.

---

### Layer 3 — Apple sub-channels

**Outcome:** Siri, Spotlight, Shortcuts, and base App Intents are independently gated.

#### 4.3.1 Surface model (proposed)

```yaml
new_surfaces:
  appleAppIntents:      # Swift AppIntent struct emission (all tools default on ios/macos)
    manifest_key: apple.appIntents
    default_ios_macos: true
  appleAppShortcuts:      # AppShortcutsProvider phrases (opt-in, ADR 0016)
    manifest_key: apple.appShortcuts
    default: false
  appleSpotlight:         # CSSearchableIndex / IndexedEntity indexing
    manifest_key: apple.spotlight
    default: false
  appleEntities:          # AppEntity + EntityQuery generation
    manifest_key: apple.entities
    default: false        # true when entityTypes present + explicit or default policy
```

`AgentManifestSurfaceExposure.options` for future Siri phrase templates, donation hints — parsed in yaml/codegen in this layer minimally (store + round-trip), emitters read in Layer 4.

#### 4.3.2 Code changes

| Area | File(s) | Change |
|------|---------|--------|
| Enum + keys | `agent_manifest.dart` | Add 3 surfaces; bump schema doc only (version stays 1 if additive) |
| Policy defaults | `projection_policy.dart` | Map new surfaces to `ios`/`macos` |
| Codegen | `agent_projection.dart`, `agent_catalog_generator.dart` | Support new `@AgentProjection` keys |
| Apple emitter | `apple_swift_app_intents_emitter.dart` | Gate: struct emission ← `appleAppIntents`; shortcuts ← `appleAppShortcuts`; entity block ← `appleEntities`; indexing ← `appleSpotlight` |
| Testing emitter | `apple_app_intents_testing_emitter.dart` | Filter tools by relevant surfaces |
| Tests | `native_emitters_test.dart` | Matrix: each surface independently on/off |
| Docs/skills | `register-intents/SKILL.md`, `DX_FAQ.mdx` | Update surface table |
| Deprecate | `intentcall_apple` | README deprecation banner; no new features |

#### 4.3.3 Subagent lanes

| Lane | Role | Scope | Gate |
|------|------|-------|------|
| **L3a** | Schema + policy | manifest enum, projection_policy, merger tests | L1 gates + new surface tests |
| **L3b** | Apple emitter split | `apple_swift_app_intents_emitter.dart` | `native_emitters_test.dart` |
| **L3c** | Codegen + annotations | `intentcall_codegen` | `agent_catalog_generator_test.dart`, example export |
| **L3d** | ADR author | `docs/decisions/0021-*.md` | Review only |

**Merge order:** L3d (ADR) → L3a → L3b ∥ L3c → parent synthesis.

#### 4.3.4 Layer 3 verification gate

```bash
dart test packages/intentcall_platform_sync/test/native_emitters_test.dart

# New: apple surface independence matrix
dart test packages/intentcall_platform_sync/test/apple_surface_matrix_test.dart  # add

# ios sync generates Swift only for appleAppIntents:true tools
# shortcuts provider empty when all appleAppShortcuts:false
```

**Alignment check L3→L4:** Tool with `apple.appIntents: true`, `apple.appShortcuts: false` → Swift struct exists, no `AppShortcut` row. Entity types only when `apple.entities: true` or global entityTypes + policy.

---

### Layer 4 — Entity lifecycle (ADR 0018 completion)

**Outcome:** Entity types flow catalog → manifest → native cache → Spotlight; one store.

#### 4.4.1 Code changes

| Area | File(s) | Change |
|------|---------|--------|
| Catalog entity rows | `agent_catalog_generator.dart` | Emit `@AgentEntity` / descriptor rows into catalog |
| CLI export | `command_runner.dart`, `manifest_exporter.dart` | Pass `entityTypeDescriptors` from catalog loader |
| Catalog loader | `catalog_loader.dart` | Load entity descriptors from generated catalog |
| Unify snapshot store | `IntentCallPlatformPlugin.swift` (all copies) | Delegate to generated `IntentCallNativeEntitySnapshotStore` or delete hand-written store |
| Dart API | `intentcall_entity_index.dart` | Deprecate legacy `upsertAgentSnapshots`; canonical: `upsertAgentSnapshotsForType` |
| Indexing hook | Plugin method channel | After upsert → call generated `IntentCallAppEntityIndexer.indexAppEntities()` |
| Emitter | `apple_swift_app_intents_emitter.dart` | Indexing gated by `apple.spotlight` |

#### 4.4.2 Subagent lanes

| Lane | Role | Scope | Gate |
|------|------|-------|------|
| **L4a** | Export + catalog | CLI, catalog loader, codegen | `manifest export` includes `entityTypes` |
| **L4b** | Native store unification | iOS/macOS plugin Swift | `intentcall_entity_index_test.dart` |
| **L4c** | Indexing lifecycle | emitter + plugin bridge | AppIntentsTesting scaffold compile |

#### 4.4.3 Layer 4 verification gate

```bash
dart test packages/intentcall_core/test/agent_entity_snapshot_projection_test.dart
dart test packages/intentcall_platform/test/intentcall_entity_index_test.dart

# New: export includes entityTypes from fixture catalog
dart test packages/intentcall_cli/test/manifest_entity_export_test.dart  # add

# AppIntentsTesting compile (if SDK available)
dart run packages/intentcall_cli/bin/intentcall.dart apple-appintents-testing generate --check  # if fixture exists
```

**Alignment check L4→L5:** `entityTypes` in manifest match catalog; upsert uses descriptor keys; generated entity query reads same keys cold.

---

### Layer 5 — Consumer migration + harness proof

**Outcome:** mcp_flutter and agentkit examples dogfood the full pipeline.

#### 4.5.1 Code changes

| Repo | Change |
|------|--------|
| **agentkit** | Steward scenario `intentcall.projection-pipeline` (new yaml) |
| **mcp_flutter** | `flutter_test_app`: add `intentcall.yaml`, catalog codegen, drop hand manifest |
| **mcp_flutter** | Extend `check_intentcall_hosted_consumer.sh` with `manifest export --check` |
| **mcp_flutter** | Regenerate `jaspr_web_example/web/agent_manifest.json` (web-only surfaces) |
| **agentkit** | `register-intents/SKILL.md` surface table + three-gate workflow |
| **optional** | `WebMcpPublishAdapter` in dogfood app |

#### 4.5.2 Subagent lanes

| Lane | Role | Scope | Gate |
|------|------|-------|------|
| **L5a** | agentkit harness | steward scenario, docs | `steward benchmark --scenario intentcall.projection-pipeline --json` |
| **L5b** | mcp_flutter Jaspr | jaspr_web_example fixtures | `tool/contracts/check_intentcall_jaspr_three_gate.sh` |
| **L5c** | mcp_flutter Flutter dogfood | flutter_test_app migration | `tool/contracts/check_intentcall_hosted_consumer.sh` |
| **L5d** | Docs/skills | DX_FAQ, platform_support, register-intents | Docs review only |

#### 4.5.3 Layer 5 verification gate (aggregate)

```bash
# agentkit root
steward doctor --json
steward probe --json --profile quick
dart test packages/intentcall_platform_sync
dart test packages/intentcall_codegen
dart test packages/intentcall_cli

# sibling integration (when ../agentkit exists)
cd ~/mcp/mcp_flutter && make check-contracts
```

---

## 5. Master subagent batch contract

```markdown
## Parallel Batch
Original goal: Align platform projection across export → manifest → emitters → runtime → consumers
Acceptance check: Criteria A1–A10 above
Product impact check: agent_manifest.json shape, generated artifacts, WebMCP registration, Apple Swift output, entity cache
Default native gate: dart test packages/intentcall_platform_sync
Aggregate gate: steward benchmark --scenario intentcall.projection-pipeline + mcp_flutter make check-contracts
Detour budget: No new surfaces beyond 0021; no runtime Siri proof rabbit holes
Claim ceiling: Static CI + artifact proof; no live OS discovery claims
Non-claims: Siri ranking, App Store approval, signed-app Spotlight UX, exactly-once delivery

| Lane | Agent/role | Scope | Write set | Forbidden | Native gate | Layer | Terminal |
|------|------------|-------|-----------|-----------|-------------|-------|----------|
| L1 | policy-export | L1 | platform_sync projection/* | emitters, mcp_flutter | manifest_merger_test | 1 | pending |
| L2a | sync-layout | L2 | platform_sync.dart | apple, mcp_flutter | platform_sync_test | 2 | pending |
| L2b | webmcp-runtime | L2 | bootstrap, flutter_host | apple, mcp_flutter | webmcp_bootstrap_test | 2 | pending |
| L2c | pkg-hygiene | L2 | intentcall_platform emitters | codegen | dart analyze | 2 | pending |
| L3a | schema-policy | L3 | agent_manifest, projection_policy | emitters | merger + dense tests | 3 | pending |
| L3b | apple-emitter | L3 | apple_swift_* | web, mcp_flutter | native_emitters_test | 3 | pending |
| L3c | codegen-surfaces | L3 | intentcall_codegen | platform_sync emitters | catalog_generator_test | 3 | pending |
| L3d | adr-author | L3 | docs/decisions/0021-* | code | review | 3 | pending |
| L4a | entity-export | L4 | CLI, catalog_loader | plugin swift | manifest_entity_export_test | 4 | pending |
| L4b | native-store | L4 | plugin Swift, entity_index | emitters | entity_index_test | 4 | pending |
| L4c | indexing-bridge | L4 | plugin + emitter hook | mcp_flutter | platform tests | 4 | pending |
| L5a | harness | L5 | steward scenarios | app code | steward benchmark | 5 | pending |
| L5b | mcp-jaspr | L5 | jaspr_web_example | agentkit core | jaspr three-gate | 5 | pending |
| L5c | mcp-flutter | L5 | flutter_test_app | agentkit core | hosted consumer | 5 | pending |
| L5d | docs | L5 | skills, FAQ | code | doc review | 5 | pending |
```

**Execution order (strict):**

```
L1 → [L2a ∥ L2b ∥ L2c] → ADR 0021 → [L3a → L3b ∥ L3c] → [L4a → L4b ∥ L4c] → [L5a ∥ L5b ∥ L5c ∥ L5d]
```

Parent **blocks** layer N+1 until layer N aggregate gate passes.

---

## 6. Cross-layer alignment matrix

After each layer, parent runs this matrix (automate as `projection_alignment_test.dart` in Layer 5):

| Check | L1 | L2 | L3 | L4 | L5 |
|-------|----|----|----|----|-----|
| 8 surfaces per tool in JSON | ✓ | ✓ | ✓ (+3 Apple) | ✓ | ✓ |
| web-only yaml → no non-web `include:true` | ✓ | ✓ | ✓ | ✓ | ✓ |
| emitter `defaultValue:false` | ✓ | ✓ | ✓ | ✓ | ✓ |
| sync uses layout.manifest | — | ✓ | ✓ | ✓ | ✓ |
| Dart WebMCP ⊆ manifest webMcp | — | ✓ | ✓ | ✓ | ✓ |
| apple shortcuts opt-in on ios | ✓ | ✓ | ✓ | ✓ | ✓ |
| apple struct gated separately | — | — | ✓ | ✓ | ✓ |
| entityTypes in export | — | — | — | ✓ | ✓ |
| single snapshot store | — | — | — | ✓ | ✓ |
| mcp_flutter three-gate | — | — | — | — | ✓ |

---

## 7. New tests to add (checklist)

| Test file | Layer | Asserts |
|-----------|-------|---------|
| `dense_manifest_test.dart` | 1 | 8 keys per tool; all `include` bool |
| `partial_defaults_platform_scope_test.dart` | 1 | yaml `{webMcp:true}` + `platforms:[web]` → android false |
| `ios_shortcuts_opt_in_test.dart` | 1 | `enabledPlatforms:[ios]` → `apple.appShortcuts` false |
| `platform_sync_layout_test.dart` | 2 | custom `layout.manifest` path |
| `webmcp_bootstrap_surface_test.dart` | 2 | opt-out tool not registered |
| `apple_surface_matrix_test.dart` | 3 | independent surface gating |
| `manifest_entity_export_test.dart` | 4 | `entityTypes` from catalog |
| `projection_alignment_test.dart` | 5 | full matrix above |

---

## 8. Steward harness scenario (Layer 5)

Add `steward/scenarios/intentcall.projection-pipeline.yaml`:

```yaml
name: intentcall.projection-pipeline
steps:
  - run: dart test packages/intentcall_platform_sync/test/manifest_merger_test.dart
  - run: dart test packages/intentcall_platform_sync/test/dense_manifest_test.dart
  - run: dart test packages/intentcall_codegen/example/test/manifest_projection_test.dart
  - run: dart test packages/intentcall_platform_sync/test/native_emitters_test.dart
  - working_directory: packages/intentcall_codegen/example
    run: dart run ../../intentcall_cli/bin/intentcall.dart manifest export --check
  - working_directory: packages/intentcall_codegen/example
    run: dart run ../../intentcall_cli/bin/intentcall.dart platform sync --platform web --check
```

---

## 9. Parent synthesis template (after each layer)

```markdown
## Layer N synthesis
- Gates run: {list}
- Gates skipped: {reason}
- Lanes integrated: {ids}
- Lanes partial/timed_out: {ids}
- Alignment matrix row: {pass/fail per check}
- Claim ceiling: {what we can claim now}
- Blockers for layer N+1: {none | list}
```

---

## 10. Risk register

| Risk | Mitigation |
|------|------------|
| Schema bump breaks consumers | Additive surfaces only; dense export backward-compatible |
| Breaking sparse manifest consumers | Layer 1 regenerates all fixtures in same PR |
| Apple SDK CI variance | AppIntentsTesting optional; compile proof labeled |
| mcp_flutter path deps | Land agentkit first; then bump hosted versions |
| Dual store migration breaks apps | Deprecation period; legacy API calls new store |

---

## 11. Suggested first execution prompt

> Execute Layer 1 per projection completion spec: dense manifest export, partial yaml + platform merge, appleAppShortcuts opt-in on ios, emitter defaultValue:false. Add dense_manifest_test + ios_shortcuts_opt_in_test. Regenerate codegen example and jaspr_web_example manifests. Run L1 gates only; do not start Layer 2.

---

## 12. MoE audit origin

This spec synthesizes findings from a Mixture-of-Experts audit (2026-07-07) covering:

- Apple projection wiring (Siri, Spotlight, Shortcuts, entity pipeline)
- Web and multi-platform emitter/runtime gaps
- mcp_flutter consumer delegation and three-gate CI
- ADR 0020 partial implementation state

Lens status at audit time: Apple and web wiring integrated; harness QA partial; disposition `promote_to_artifact`.
