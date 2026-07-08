# Platform Subset + Federated Plugins Implementation Plan

**Status:** Implemented (compressed A/B/C) — ready for `delete_or_retire` after this PR  
**Date:** 2026-07-08  
**ADR target:** [0025 — Platform Subset and Federated Flutter Plugins](../decisions/0025-platform-subset-federated-plugins.md) (Accepted)  
**Builds on:** [hooks-native-bridge-plan.md](hooks-native-bridge-plan.md), [ADR 0024](../decisions/0024-dart-hooks-and-pigeon-bridge-consistency.md)  
**Disposition:** `delete_or_retire` after this PR (durable knowledge already in ADR 0025 + DX_FAQ)

**Hardcuts (landed vs early draft below):**

- No separate `intentcall_platform_interface` package — host API lives in the umbrella
- Darwin native code lives in `intentcall_platform_apple` (`darwin/…`), not the umbrella
- SPM-only for Apple (no CocoaPods / podspecs)
- Phase A+B+C landed (subset enforcement, legacy sunset, federated apple+android + umbrella)

**Flutter references (authoritative):**

- [Developing packages & plugins](https://docs.flutter.dev/packages-and-plugins/developing-packages) — federated plugins, `default_package`, `sharedDarwinSource`, `implements`
- [Swift Package Manager for plugin authors](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors) — `Package.swift` layout, Pigeon `swiftOut` paths, `FlutterFramework` dependency
- [Dart SDK hooks](https://dart.dev/tools/hooks) — build-time orchestration (see hooks-native-bridge-plan)

**User constraint:** Drop CocoaPods completely for IntentCall Apple plugins. SPM is the sole native integration path for iOS/macOS.

---

## 1. Problem statement

IntentCall must support **many platforms** (web, android, ios, macos, linux, windows, future HarmonyOS/Huawei APK variants) while apps ship **different subsets**:

- Mobile-only: `android` + `ios`
- Desktop: `macos` + `windows`
- Android + Huawei: still `android` token (OEM packaging is app concern)
- Web-only: Jaspr / plain Dart

**Current pain:**

| Issue | Impact |
|-------|--------|
| `intentcall_apple` / `intentcall_android` legacy packages | Wrong mental model; parallel manifest generators (deprecated ADR 0022) |
| `intentcall_platform` bundles all Flutter native impls | iOS-only apps still compile android/ios/macos plugin code |
| Duplicate iOS + macOS Swift trees | Drift risk (`ios/.../Sources` vs `macos/.../Sources`) |
| CocoaPods + SPM dual maintenance | Podspecs + Package.swift; user wants SPM-only |
| Empty `platforms.enabled` on Flutter | Defaults to all six sync targets + broad manifest surfaces |
| `PlatformHooksInit` ignores enabled list | Patches Gradle/Xcode even when platform disabled |

**Non-goals:**

- Split `intentcall_platform_sync` emitters into per-platform pub packages (unless a platform needs non-Dart toolchain deps)
- Pigeon for App Intents Swift (manifest emitters remain correct tool)
- Live OS proof (Siri, Spotlight UX) in agentkit CI
- HarmonyOS NEXT package until artifact format diverges from Android

---

## 2. Target architecture

### 2.1 Three layers (unchanged truth model)

```text
Layer 1 — Truth:      intentcall_schema + intentcall_core + intentcall_codegen
Layer 2 — Projection: intentcall_platform_sync + intentcall_cli + intentcall_hooks
Layer 3 — Runtime:    federated Flutter plugins + intentcall_bridge (Pigeon)
Layer 4 — Adapters:   intentcall_mcp | intentcall_webmcp
```

### 2.2 Platform opt-in contract

**Authoritative knob:** `intentcall.yaml` → `platforms.enabled`

```yaml
host: flutter
protocolScheme: myapp
platforms:
  enabled: [android, ios]   # REQUIRED for non-default combos
```

Drives:

1. Manifest surface defaults (ADR 0020)
2. `intentcall platform sync --platform` default list
3. `PlatformHookSpine` template platform list
4. `PlatformHooksInit` patch targets (after Phase 2)
5. Federated plugin `default_package` endorsement (after Phase 4)

**Sync tokens today:** `web`, `android`, `ios`, `macos`, `linux`, `windows`  
**No `huawei` token** — use `android`; document OEM caveats in DX_FAQ.

### 2.3 Federated Flutter plugin topology (Flutter docs pattern)

Per [federated plugins](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins):

```text
intentcall_platform                    # app-facing umbrella (endorsed default_package map)
intentcall_platform_interface          # platform interface (Dart API + Pigeon contracts)
intentcall_platform_apple              # ios + macos via sharedDarwinSource
intentcall_platform_android            # Kotlin + Pigeon
intentcall_bridge                      # Pigeon generated code (shared by apple + android impls)
```

**App-facing `pubspec.yaml` (endorsed — automatic):**

```yaml
dependencies:
  intentcall_platform: ^0.7.0
```

**Non-endorsed override (advanced):**

```yaml
dependencies:
  intentcall_platform: ^0.7.0
  # Omit apple impl on Android-only CI nodes if needed:
  # intentcall_platform_apple: ^0.7.0
```

**Umbrella `pubspec.yaml` plugin map (target):**

```yaml
flutter:
  plugin:
    platforms:
      android:
        default_package: intentcall_platform_android
      ios:
        default_package: intentcall_platform_apple
        sharedDarwinSource: true
      macos:
        default_package: intentcall_platform_apple
        sharedDarwinSource: true
```

Projection (`intentcall_platform_sync`) stays **one package** — emitters are pure Dart; subset is config-gated.

### 2.4 Apple native: SPM-only, shared Darwin

Per [SPM for plugin authors](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors):

| Rule | IntentCall application |
|------|------------------------|
| Layout | `darwin/intentcall_platform_apple/Sources/intentcall_platform_apple/` |
| `Package.swift` | `FlutterFramework` path dep; library name `intentcall-platform-apple` (underscores → hyphens) |
| Pigeon `swiftOut` | `darwin/intentcall_platform_apple/Sources/.../IntentCallPlatformBridge.g.swift` |
| Privacy | `PrivacyInfo.xcprivacy` in Sources; `.process(...)` in Package.swift |
| CocoaPods | **Remove** `*.podspec` after SPM CI proof |
| `sharedDarwinSource: true` | Single Swift tree for ios + macos in umbrella pubspec |

**Minimum Flutter SDK:** `>=3.24.0` (already in `intentcall_platform`); document `>=3.44.0` for SPM-default consumers.

### 2.5 Legacy package sunset

| Package | Action |
|---------|--------|
| `intentcall_apple` | `@Deprecated` + `publish_to: none` + removed from release train (this cycle) |
| `intentcall_android` | Same |

Canonical path: `agent_catalog.g.dart` → `ManifestExporter` → `PlatformSync` emitters.

---

## 3. Acceptance criteria

| # | Criterion | Phase |
|---|-----------|-------|
| S1 | ADR 0025 accepted; NORTH_STAR / choose_your_path updated | P0 |
| S2 | `intentcall validate` warns/errors when `host:flutter` and `platforms.enabled` empty | P1 |
| S3 | `PlatformHooksInit` only patches targets in `platforms.enabled` | P1 |
| S4 | CI templates for `windows`/`linux` from `PlatformHookSpine` | P1 |
| S5 | `intentcall_apple` / `intentcall_android` deprecated + removed from docs router | P2 |
| S6 | `intentcall_platform_interface` published with stable Dart host API | P3 |
| S7 | `intentcall_platform_apple` + `intentcall_platform_android` federated impls | P3 |
| S8 | Umbrella `intentcall_platform` endorses `default_package` per platform | P3 |
| S9 | Single `darwin/` Swift source; no duplicate ios/macos trees | P4 |
| S10 | No `*.podspec` in intentcall Apple plugins; SPM-only publish preflight | P4 |
| S11 | Pigeon outputs land under federated package paths | P4 |
| S12 | `mcp_flutter` `make check-contracts` green with federated layout | P5 |
| S13 | `just test && just analyze` green | P5 |

**Claim ceiling:** artifact + static CI + federated plugin compile proof.  
**Non-claims:** App Store discovery, Huawei HMS behavior, Windows App Actions live proof.

---

## 4. Phase 0 — ADR + charter sync

**Goal:** Record decision before structural package moves.

| Lane | Agent | Write set | Gate |
|------|-------|-----------|------|
| **P0-adr** | ADR author | `docs/decisions/0025-platform-subset-federated-plugins.md`, update `docs/decisions/README.md` | Review |
| **P0-docs** | Doc author | `NORTH_STAR.mdx`, `choose_your_path.mdx`, `DX_FAQ.mdx` platform subset section; link this plan | `intentcall validate` |

**ADR 0025 must state:**

1. Projection stays in `intentcall_platform_sync`; subset via `platforms.enabled`
2. Runtime splits into federated Flutter plugins
3. Apple: SPM-only; CocoaPods dropped for IntentCall-owned plugins
4. `intentcall_apple` / `intentcall_android` deprecated
5. Huawei = `android` token until HarmonyOS artifact diverges

**Merge order:** P0-adr → P0-docs

---

## 5. Phase 1 — Platform subset enforcement

**Goal:** Make `platforms.enabled` real before package splits.

| Lane | Agent | Write set | Forbidden | Gate |
|------|-------|-----------|-----------|------|
| **P1a-validate** | CLI validator | `intentcall_config.dart`, `intentcall validate` warning/error for empty enabled on flutter/jaspr | Federated packages | `command_runner_test` |
| **P1b-hooks-init** | Hooks engineer | `platform_hooks_init.dart` — patch only enabled platforms | Package moves | `platform_hooks_init_test` |
| **P1c-spine-ci** | Spine engineer | `platform_hook_spine.dart` — `renderCiSnippet()` for windows/linux; docs in plan appendix | — | `platform_hook_templates_test` |
| **P1d-fixtures** | Fixture author | Update CLI fixtures with explicit `platforms.enabled`; register-intents skill | — | `just adr-gates` |

**Aggregate gate:**

```bash
just platform-hooks-check
dart run tool/intentcall/bin/intentcall.dart validate
```

---

## 6. Phase 2 — Legacy package sunset

**Goal:** Stop authors from installing wrong packages.

| Lane | Agent | Write set | Gate |
|------|-------|-----------|------|
| **P2a-deprecate** | Package maintainer | `@Deprecated` on `generateAppleAgentManifest`, `generateAndroidAgentManifest`; README banners | Package unit tests |
| **P2b-train** | Release engineer | Remove from `release_train.dart` / release-please OR mark `publish_to: none` + changelog | `release_train check` |
| **P2c-docs** | Doc sweep | Remove apple/android from package tables; migration snippet to three-gate | `docs-check` |

**Do not delete code until one release cycle after deprecation notice.**

---

## 7. Phase 3 — Federated plugin scaffold

**Goal:** Flutter-correct package separation per [developing-packages](https://docs.flutter.dev/packages-and-plugins/developing-packages).

### 7.1 Package creation commands

```bash
# Interface (Dart only)
flutter create --template=package --org dev.intentcall intentcall_platform_interface

# Apple federated impl (ios + macos, sharedDarwinSource later in umbrella)
flutter create --template=plugin --org dev.intentcall \
  --platforms=ios,macos -i swift intentcall_platform_apple

# Android federated impl
flutter create --template=plugin --org dev.intentcall \
  --platforms=android -a kotlin intentcall_platform_android
```

Then **move** from current `intentcall_platform`:

| From | To |
|------|-----|
| `lib/intentcall_platform_flutter.dart` + `lib/src/flutter/*` | `intentcall_platform_interface` (API) + keep thin exports in umbrella |
| iOS/macOS Swift plugin + stores | `intentcall_platform_apple` |
| Android Kotlin plugin | `intentcall_platform_android` |
| Pigeon IDL | Stay `intentcall_bridge`; impl packages depend on it |

### 7.2 Parallel lanes

| Lane | Agent | Scope | Gate |
|------|-------|-------|------|
| **P3a-interface** | Interface author | `intentcall_platform_interface` — `IntentCallFlutterHost`, exports from sync/bridge types | Interface tests |
| **P3a-apple** | Apple impl | `intentcall_platform_apple` — move Swift, wire Pigeon HostApi | `pigeon_bridge_contract_test` (relocated) |
| **P3b-android** | Android impl | `intentcall_platform_android` — real Kotlin Pigeon impl (replace stub) | Android compile in example |
| **P3c-umbrella** | Umbrella author | `intentcall_platform` pubspec `default_package` + deps; re-export interface | `flutter_host_test` |
| **P3d-codegen** | Pigeon paths | Update `pigeons/intentcall_platform_bridge.dart` swiftOut/kotlinOut to federated paths | `just pigeon-codegen-check` |

**Merge order:** P3a-interface → P3a-apple ∥ P3b-android → P3c-umbrella → P3d-codegen

**Umbrella stays the only package most apps list.** Interface + impl packages are endorsed dependencies.

---

## 8. Phase 4 — SPM-only + shared Darwin consolidation

**Goal:** One Apple native tree; drop CocoaPods per user directive.

### 8.1 Target directory layout (`intentcall_platform_apple`)

```text
intentcall_platform_apple/
  pubspec.yaml                    # implements: intentcall_platform (interface)
  darwin/
    intentcall_platform_apple/
      Package.swift               # .iOS("13.0"), .macOS("10.14")
      Sources/intentcall_platform_apple/
        IntentCallPlatformPlugin.swift
        IntentCallNativeHandoffStore.swift
        IntentCallNativeEntitySnapshotStore.swift
        IntentCallPlatformBridge.g.swift
        PrivacyInfo.xcprivacy
  android/ ...                    # empty — apple package is darwin-only
```

**Umbrella pubspec** (ios + macos):

```yaml
flutter:
  plugin:
    platforms:
      ios:
        pluginClass: IntentCallPlatformPlugin
        sharedDarwinSource: true
        default_package: intentcall_platform_apple
      macos:
        pluginClass: IntentCallPlatformPlugin
        sharedDarwinSource: true
        default_package: intentcall_platform_apple
```

Per Flutter docs, enable `sharedDarwinSource: true` and use **`darwin/`** folder instead of separate `ios/` + `macos/` native folders in the **impl** package.

### 8.2 CocoaPods removal checklist

| Step | Action |
|------|--------|
| 1 | Delete `ios/intentcall_platform.podspec`, `macos/intentcall_platform.podspec` from apple impl |
| 2 | Remove podspec version checks from `release_train.dart` / publish preflight **or** gate on SPM-only packages |
| 3 | Update `swiftPackageManagerFindings` in `tool/intentcall` — require `Package.swift` + Pigeon bridge in federated paths |
| 4 | Update `PlatformSync` / Xcode sync to target SPM layout only |
| 5 | Document minimum Flutter 3.44 + `flutter config --enable-swift-package-manager` for consumers |
| 6 | Add `.gitignore` entries: `.build/`, `.swiftpm/` |

### 8.3 Parallel lanes

| Lane | Agent | Scope | Gate |
|------|-------|-------|------|
| **P4a-darwin** | Swift consolidation | Merge ios/macos Sources → `darwin/`; delete duplicates | `swiftPackageManagerFindings` empty on fixture |
| **P4b-spm** | SPM hygiene | Package.swift, PrivacyInfo, FlutterFramework dep | `flutter build ios --config-only` on example |
| **P4c-pod-drop** | Remove podspecs | Delete podspecs; update publish preflight tests | `publish_preflight_test` |
| **P4d-pigeon** | Regenerate Pigeon | `swiftOut` → `darwin/.../IntentCallPlatformBridge.g.swift` | `just pigeon-codegen-check` |

**Aggregate gate:**

```bash
just pigeon-codegen-check
dart test tool/intentcall/test/publish_preflight_test.dart
# Manual: flutter build ios --no-codesign --config-only in mcp_flutter/flutter_test_app
```

---

## 9. Phase 5 — Harness + consumer proof

| Lane | Agent | Scope | Gate |
|------|-------|-------|------|
| **P5a-harness** | Steward | New scenario `intentcall.federated-platform` or extend adapter-contract | steward benchmark |
| **P5b-mcp** | Sibling consumer | Update `mcp_flutter` path deps for new packages; regenerate artifacts | `make check-contracts` |
| **P5c-docs** | DX | Author matrix: platform combo → `enabled` → deps → hooks | `docs-check` |

**Extend `projection_alignment_test.dart`:** federated plugin compile + SPM layout rows.

---

## 10. Execution timeline

```text
P0 (ADR)        ─────────────────────────────────────────►
P1 (subset)     ──────► [P1a ∥ P1b ∥ P1c ∥ P1d]
P2 (sunset)           ──────► [P2a ∥ P2b ∥ P2c]     (after P0)
P3 (federated)              ──────► [P3a → P3b∥P3c → P3d]
P4 (SPM/darwin)                     ──────► [P4a → P4b∥P4c∥P4d]  (after P3 apple scaffold)
P5 (harness)                              ──────► [P5a ∥ P5b ∥ P5c]
```

**Hard dependencies:**

- P3 requires P0 ADR
- P4 requires P3 apple package exists
- P5 requires P3 + P4 minimum

**P1 and P2 can run in parallel after P0.**

---

## 11. Master subagent batch contract

```markdown
| Lane | Phase | Role | Write set | Forbidden | Native gate |
|------|-------|------|-----------|-----------|-------------|
| P0-adr | 0 | ADR 0025 | docs/decisions/0025-* | code moves | review |
| P0-docs | 0 | Charter sync | NORTH_STAR, choose_your_path, DX_FAQ | emitters | validate |
| P1a-validate | 1 | platforms.enabled gate | intentcall_cli config/validate | federated pkgs | command_runner_test |
| P1b-hooks-init | 1 | Platform-aware hooks init | platform_hooks_init | package moves | platform_hooks_init_test |
| P1c-spine-ci | 1 | CI snippets for desktop | platform_hook_spine | — | platform_hook_templates_test |
| P1d-fixtures | 1 | Fixture enabled lists | fixtures, register-intents skill | — | adr-gates |
| P2a-deprecate | 2 | Legacy deprecations | intentcall_apple/android | delete yet | generator tests |
| P2b-train | 2 | Release train | release_train, release-please | — | release_train check |
| P2c-docs | 2 | Doc sunset | README, package tables | — | docs-check |
| P3a-interface | 3 | Platform interface | intentcall_platform_interface | SPM moves | interface tests |
| P3a-apple | 3 | Apple federated impl | intentcall_platform_apple | drop podspec early | pigeon tests |
| P3b-android | 3 | Android federated impl | intentcall_platform_android | — | android compile |
| P3c-umbrella | 3 | Endorsed umbrella | intentcall_platform pubspec | — | flutter_host_test |
| P3d-pigeon | 3 | Pigeon path update | intentcall_bridge pigeons | — | pigeon-codegen-check |
| P4a-darwin | 4 | sharedDarwinSource | darwin/ tree | podspec | SPM findings |
| P4b-spm | 4 | Package.swift hygiene | Package.swift, PrivacyInfo | — | flutter build config-only |
| P4c-pod-drop | 4 | Remove CocoaPods | delete podspecs, preflight | — | publish_preflight_test |
| P4d-pigeon | 4 | Regenerate swift out | pigeon + swift | — | pigeon-codegen-check |
| P5a-harness | 5 | Steward scenario | steward.yaml, justfile | — | steward benchmark |
| P5b-mcp | 5 | mcp_flutter consumer | ../mcp_flutter | agentkit core | check-contracts |
| P5c-docs | 5 | Author matrix | DX_FAQ platform table | — | docs-check |
```

Parent blocks phase N+1 until phase N aggregate gate passes.

---

## 12. Author cheat sheet (target state)

| App profile | `platforms.enabled` | `pubspec` deps | Hooks |
|-------------|---------------------|----------------|-------|
| iOS + Android mobile | `[android, ios]` | `intentcall_platform` (+ codegen stack) | Gradle + Xcode from spine |
| macOS + Windows desktop | `[macos, windows]` | `intentcall_platform` | CI sync for windows/linux |
| Android + Huawei stores | `[android]` | `intentcall_platform` | Gradle only |
| Web Jaspr | `[web]` | `intentcall_hooks` dev; no platform plugin | Dart SDK hook |
| iOS-only (future) | `[ios]` | `intentcall_platform` (android impl not compiled into app binary via federated split) | Xcode only |

---

## 13. Risk register

| Risk | Mitigation |
|------|------------|
| SPM-only breaks older Flutter apps | Document min Flutter 3.44; pre-1.0 train allows breaking change |
| Federated split breaks `mcp_flutter` | Path deps + contract scripts in P5 |
| Duplicate Swift during migration | P4 deletes ios/macos copies only after darwin compiles |
| Manifest surface drift when narrowing enabled | Regenerate fixtures in same PR as P1 |
| HarmonyOS premature package | Stay on `android` emitter until ArkTS format exists |
| CocoaPods removal vs Flutter docs | User explicit: drop pods; Flutter 3.44 SPM primary; pods registry read-only Dec 2026 |

---

## 14. Relationship to hooks-native-bridge-plan

| hooks plan phase | Status | This plan |
|----------------|--------|-----------|
| P0–P4 hooks/bridge/harness | Implemented | Builds on; do not regress |
| Flutter Gradle/Xcode deferral (ADR 0024 §6.3) | Active | Unchanged until federated + SPM stable |
| `intentcall_platform` monolith | Open | **Resolved by P3–P4 here** |

---

## 15. Suggested first execution prompt

```text
Execute Phase 0 + Phase 1 of docs/evidence/platform-subset-federated-plugins-plan.md:

1. Draft and accept ADR 0025 (platform subset + federated plugins + SPM-only).
2. Implement platforms.enabled validation for host:flutter (warn → error).
3. Make PlatformHooksInit respect platforms.enabled.
4. Add CI hook snippets for windows/linux in PlatformHookSpine.
5. Update fixtures and register-intents skill.

Do NOT create federated packages or delete podspecs yet.
Gates: just platform-hooks-check, intentcall validate, just adr-gates.
Use subagents per batch contract §11.
```

---

## 16. MoE audit origin

Synthesized from platform package strategy discussion (2026-07-08), Flutter developing-packages + SPM plugin author docs, and prior hooks-native-bridge MoE. Generational Architecture Skeptic lens: split runtime (federated), not projection; sunset `intentcall_apple`/`android`; `platforms.enabled` is the product-facing contract.
