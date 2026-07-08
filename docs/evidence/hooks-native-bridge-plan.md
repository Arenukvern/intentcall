# Hooks + Native Bridge Consistency Plan

**Status:** Active implementation plan  
**Date:** 2026-07-08  
**Supersedes:** [projection-pipeline-spec.md](projection-pipeline-spec.md) (retired)  
**ADR:** [0024 — Dart Hooks and Pigeon Bridge Consistency](../decisions/0024-dart-hooks-and-pigeon-bridge-consistency.md)  
**Disposition:** `promote_to_artifact`

**Related ADRs:** [0015](../decisions/0015-dart-first-native-bridge.md), [0016](../decisions/0016-dispatch-mode-handoff-contract.md), [0017](../decisions/0017-apple-inline-runtime-tracks.md), [0019](../decisions/0019-framework-neutral-intentcall-cli.md), [0022](../decisions/0022-projection-pipeline-alignment.md), [0023](../decisions/0023-entity-three-slot-projection.md)

---

## 1. Problem statement

IntentCall's projection pipeline (ADR 0019/0022/0023) is **implemented and tested** in agentkit. Remaining pain is **operational consistency**:

1. **Build hooks** — Gradle/Xcode/Jaspr string templates duplicate the same three-gate spine; `hooks.syncCommand` in `intentcall.yaml` is parsed but unused; `intentcall` must be on PATH.
2. **Dart SDK hooks** — [dart.dev/tools/hooks](https://dart.dev/tools/hooks) offers package-scoped `hook/build.dart` with cache invalidation; IntentCall should adopt this for Jaspr/plain Dart first, then Flutter.
3. **Native bridge** — Flutter plugin uses hand-written `MethodChannel` string dispatch; generated Swift duplicates handoff-store logic; entity keys and entity-open drain are inconsistent.

**Non-goals:** Fold `intentcall_platform_sync` into `core`; Pigeon App Intents; live OS proof (Siri/Spotlight UX).

---

## 2. Target architecture

```text
Layer 1 — Truth:     intentcall_schema + intentcall_core + intentcall_codegen (build_runner)
Layer 2 — Projection: intentcall_platform_sync + intentcall_cli (+ intentcall_hooks hook/build.dart)
Layer 3 — Bridge:    intentcall_bridge (Pigeon) + intentcall_platform (Flutter plugin)
Layer 4 — Adapters:  intentcall_mcp | intentcall_webmcp
```

**Three-gate spine (semantics unchanged):**

```text
build_runner → intentcall manifest export --check → intentcall platform sync --check
```

Invocation surfaces evolve; gate meaning does not.

---

## 3. Acceptance criteria

| # | Criterion | Phase |
|---|-----------|-------|
| H1 | `PlatformHookSpine` resolves phases + CLI invocation from `intentcall.yaml` | P1 |
| H2 | Gradle/Xcode/Jaspr templates generated from spine (not hand-maintained const strings) | P1 |
| H3 | `hooks.syncCommand` honored when set | P1 |
| H4 | `just platform-hooks-check` + steward action pass | P1, P4 |
| H5 | `intentcall_hooks` package with `hook/build.dart` runs export+sync in-process for Jaspr fixture | P2 |
| H6 | Shared `CatalogLoader` used by CLI and Dart hook | P2 |
| H7 | Pigeon IDL for invocations + entities channels; plugin uses generated HostApi | P3 |
| H8 | Single handoff store (no duplicate Swift implementations) | P3 |
| H9 | `EntityKeyBundle` from manifest on entity channel calls | P3 |
| H10 | `projection-pipeline-check` in CI + quick probe | P4 |
| H11 | mcp_flutter three-gate (sibling repo) | P4 |

**Claim ceiling:** artifact + static CI. **Non-claims:** live Siri ranking, signed-app Spotlight UX, exactly-once native delivery.

---

## 4. Phase 0 — Doc hygiene

**Goal:** Retire stale spec; record decision in ADR 0024.

| Lane | Scope |
|------|-------|
| P0-doc | Tombstone `projection-pipeline-spec.md`; ADR 0024; verification appendices on ADR 0022/0023; update `docs/decisions/README.md` |

**Gate:** Doc links valid; `intentcall validate` passes.

---

## 5. Phase 1 — Hook spine unification

**Goal:** One resolver, three host renderers. No Dart SDK hook yet.

### 5.1 `PlatformHookSpine`

**Location:** `packages/intentcall_platform_sync/lib/src/templates/platform_hook_spine.dart`

```yaml
inputs:
  intentcall.yaml: [host, platforms.enabled, hooks.syncCommand, layout]
  HostProfile from host_profiles.dart
outputs:
  codegen_phase: dart run build_runner build --delete-conflicting-outputs
  manifest_phase: <cli> manifest export --check
  sync_phase: <cli> platform sync --platform <resolved> [--check]
  cli_invocation: hooks.syncCommand ?? dart run intentcall_cli:intentcall
  platform_list: from HostProfile + platforms.enabled
```

### 5.2 Parallel lanes

| Lane | Agent | Write set | Gate |
|------|-------|-----------|------|
| **P1a-spine** | Hook resolver | `platform_hook_spine.dart`, refactor `platform_hook_templates.dart` | `platform_hook_templates_test.dart` |
| **P1b-init** | Hooks init | `platform_hooks_init.dart`, wire `hooks.syncCommand` | `platform_hooks_init_test.dart` |
| **P1c-cli** | CLI | `intentcall hooks render`, `intentcall hooks spine --json` | `command_runner_test.dart` |

**Order:** P1a → P1b ∥ P1c

**Aggregate gate:**

```bash
just platform-hooks-check
```

---

## 6. Phase 2 — Dart SDK build hook

**Goal:** Replace shell hooks for Jaspr/plain Dart hosts.

### 6.1 New package `intentcall_hooks`

```
packages/intentcall_hooks/
  hook/build.dart          # calls ManifestExporter + PlatformSync in-process
  pubspec.yaml             # depends: hooks, code_assets, intentcall_platform_sync
```

**v1 rules:**

- Require fresh `agent_catalog.g.dart` (do not spawn build_runner inside hook)
- Register `output.dependencies` on `intentcall.yaml`, catalog, manifest
- Use `hooks.user_defines.intentcall_hooks` for `platforms`, `check_only`, `project_root`

### 6.2 Parallel lanes

| Lane | Agent | Write set | Gate |
|------|-------|-----------|------|
| **P2a-hook-pkg** | Dart hooks | `packages/intentcall_hooks/` | Jaspr fixture spine test |
| **P2b-catalog-loader** | Shared lib | Extract `CatalogLoader` from CLI | CLI + hook parity tests |

**Order:** P2b → P2a (loader first)

**Defer:** Flutter iOS/Android Gradle/Xcode hook removal until Flutter hook timing proof
(see §6.3).

### 6.3 Flutter native hook migration (deferred — Phase 2b)

Gradle `preBuild` and Xcode Run Script hooks remain the **canonical** invocation
surface for Flutter Android/iOS/macOS until Dart SDK hook ordering is proven in
real `flutter build` pipelines.

**Deferral criteria (Phase 2b gate):**

Do **not** remove or shrink Gradle/Xcode templates until all of:

1. **Ordering** — `flutter build` (apk, appbundle, ipa, macos, or equivalent)
   runs `intentcall_hooks` `hook/build.dart` **before** the host native compile
   phase (`xcodebuild compile` / `CompileSwift` for Apple; `compileDebugKotlin`
   or release equivalent for Android).
2. **Three-gate parity** — manifest export + platform sync complete before native
   Swift/Kotlin that reads `agent_manifest.json`, `IntentCallGenerated.swift`, or
   other sync outputs is compiled.
3. **Incremental builds** — stale-cache and skip paths are observed (hook not
   re-run on incremental rebuild, `DataAsset` invalidation gaps) and mitigations
   are documented or fixed.
4. **Dogfood proof** — build log evidence from mcp_flutter or an in-repo Flutter
   fixture showing hook output timestamps preceding the first native compile line
   for the app target.

**Until the gate passes:**

- `PlatformHookSpine` continues to render Gradle/Xcode snippets via
  `intentcall platform hooks init` (templates generated from spine, not
  hand-maintained).
- `intentcall_hooks` ships for Jaspr and plain Dart hosts only (Phase 2a).
- Gradle/Xcode templates may shrink to staleness checks **after** timing proof;
  full removal requires ADR amendment.

**Proof artifact:** recorded build logs or CI appendices under `docs/evidence/`
demonstrating hook-before-compile ordering; optional steward scenario.

---

## 7. Phase 3 — Pigeon bridge

**Goal:** Typed plugin channels; collapse handoff duplication.

### 7.1 New package `intentcall_bridge`

```
packages/intentcall_bridge/
  pigeons/intentcall_platform_bridge.dart
  lib/intentcall_bridge.dart
```

**Pigeon surfaces:**

- `IntentCallInvocationsHostApi.takePendingInvocations()`
- `IntentCallEntitiesHostApi` — upsert/search/delete/clear with `EntityKeyBundle`

**Do NOT Pigeon:** App Intents, shortcuts, deep links, `nativeInline` registry.

### 7.2 Parallel lanes

| Lane | Agent | Write set | Gate |
|------|-------|-----------|------|
| **P3a-idl** | IDL author | `intentcall_bridge` pigeons + codegen | `just pigeon-codegen-check` |
| **P3b-plugin** | Plugin | Refactor `IntentCallPlatformPlugin`; dedupe Swift | `pigeon_bridge_contract_test.dart` |
| **P3c-entity** | Entity bridge | `EntityKeyBundle`; entity-open drain parity | `intentcall_entity_index_test.dart` |

**Order:** P3a → P3b ∥ P3c

---

## 8. Phase 4 — Harness + consumer

**Goal:** Promote gates; close L5 sibling gap.

| Lane | Agent | Scope | Gate |
|------|-------|-------|------|
| **P4a-harness** | Steward | CI + quick probe; new steward actions | `steward benchmark --scenario intentcall.projection-pipeline` |
| **P4b-tests** | Tests | Extend `projection-pipeline-check`; A5/A8 gaps | `just projection-pipeline-check` |
| **P4c-mcp-jaspr** | Sibling | mcp_flutter Jaspr three-gate | `make check-contracts` |
| **P4d-mcp-flutter** | Sibling | flutter_test_app migration | hosted consumer script |

**Harness additions:**

```bash
just platform-hooks-check      # P1
just pigeon-codegen-check      # P3
just projection-pipeline-check # promote to CI
```

**mcp_flutter three-gate (sibling repo, not agentkit CI blocker):**

```bash
# Jaspr web example (hook presence → manifest export --check → platform sync --check)
cd ../mcp_flutter && make check-contracts
# Or directly:
bash tool/contracts/check_intentcall_jaspr_three_gate.sh
```

Gate 1 may apply hooks when `--check` fails; gates 2–3 are pure `--check` invocations.
See also `projection_alignment_test.dart` → `mcp_flutter three-gate` group.

---

## 9. Execution timeline

```text
P0 (doc)     ─────────────────────────────────────────►
P1 (spine)   ──────► [P1a → P1b ∥ P1c]
P2 (dart hook)        ──────► [P2b → P2a]        (after P1 gate)
P3 (pigeon)     ──────► [P3a → P3b ∥ P3c]       (P3a after P0; parallel to P2)
P4 (harness)                        ──────► [P4a ∥ P4b ∥ P4c ∥ P4d]
```

**Dependencies:**

- P2 requires P1 (`PlatformHookSpine` + shared catalog loader path)
- P3b requires P3a
- P4c/P4d require P1 minimum

---

## 10. Master subagent batch contract

```markdown
| Lane | Phase | Role | Write set | Forbidden | Native gate |
|------|-------|------|-----------|-----------|-------------|
| P0-doc | 0 | ADR + doc hygiene | docs/** | code | intentcall validate |
| P1a-spine | 1 | Hook resolver | platform_hook_spine, templates | pigeon, mcp_flutter | platform_hook_templates_test |
| P1b-init | 1 | Hooks init | platform_hooks_init | CLI surface break | platform_hooks_init_test |
| P1c-cli | 1 | CLI hooks commands | intentcall_cli | emitter logic | command_runner_test |
| P2b-catalog | 2 | CatalogLoader extract | platform_sync or hooks | emitters | catalog loader tests |
| P2a-hook-pkg | 2 | Dart hook package | intentcall_hooks | Gradle/Xcode removal | jaspr fixture |
| P3a-idl | 3 | Pigeon IDL | intentcall_bridge | App Intents emitters | pigeon-codegen-check |
| P3b-plugin | 3 | Plugin refactor | intentcall_platform | emitters | pigeon_bridge_contract_test |
| P3c-entity | 3 | Entity bridge | entity_index, plugin | mcp_flutter | entity_index_test |
| P4a-harness | 4 | Steward/CI | steward.yaml, justfile, ci.yml | app code | steward benchmark |
| P4b-tests | 4 | Test promotion | projection tests | — | projection-pipeline-check |
| P4c-mcp-jaspr | 4 | Sibling Jaspr | mcp_flutter | agentkit core | check-contracts |
| P4d-mcp-flutter | 4 | Sibling Flutter | mcp_flutter | agentkit core | hosted consumer |
```

Parent blocks phase N+1 until phase N aggregate gate passes (except P3a after P0, P4 doc-only lanes).

---

## 11. Risk register

| Risk | Mitigation |
|------|------------|
| Flutter hook timing vs Xcode compile | Keep Gradle/Xcode until dogfood proof (§6.3) |
| `DataAsset` not stable for Swift/XML artifacts | Hook writes project tree via `PlatformSync` (same as CLI) |
| Pigeon breaks plugin consumers | Deprecation period; channel names unchanged |
| mcp_flutter path deps | Land agentkit first; bump hosted versions |
| New packages in release train | Add to `release_train.dart`, `PUBLISHING.md` |

---

## 12. MoE audit origin

Synthesized from Mixture-of-Experts audit (2026-07-08): Dart SDK Hooks lens, Pigeon/Bridge lens, Generational Architecture Skeptic, Harness QA. Prior projection-pipeline MoE (2026-07-07) layers 1–4 are complete per ADR 0022/0023.
