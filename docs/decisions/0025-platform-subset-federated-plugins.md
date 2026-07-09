# 0025. Platform Subset and Federated Flutter Plugins

Date: 2026-07-08

## Status

Accepted

## Context

IntentCall supports many projection targets (`web`, `android`, `ios`, `macos`,
`linux`, `windows`) but consuming apps ship different subsets. Legacy packages
`intentcall_apple` and `intentcall_android` implemented an obsolete sparse-manifest
path superseded by ADR 0019/0022 unified projection in `intentcall_platform_sync`
and were **deleted** from the workspace (hardcut; not renamed into
`intentcall_platform_*`).

The monolithic `intentcall_platform` Flutter plugin bundles Android, iOS, and
macOS native implementations. Apps that target only one mobile platform still
depend on a plugin that declares all platforms.

Flutter documents [federated
plugins](https://docs.flutter.dev/packages-and-plugins/developing-packages) and
[Swift Package Manager for plugin
authors](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors)
as the modern integration model. As of Flutter 3.44, SPM is the primary strategy
for iOS/macOS native dependencies. The CocoaPods registry becomes read-only on
2026-12-02.

IntentCall will drop CocoaPods for Apple-owned plugin packages and standardize on
SPM with `sharedDarwinSource` for iOS + macOS.

Implementation plan:
[platform-subset-federated-plugins-plan.md](../evidence/platform-subset-federated-plugins-plan.md).

## Decision

### 1. Platform subset contract

- `intentcall.yaml` → `platforms.enabled` is the **authoritative** platform
  contract for manifest surface defaults, `platform sync`, and hook spine
  resolution.
- Authors with `host: flutter` or `host: jaspr` must set `platforms.enabled`
  explicitly for non-default combinations; validation will warn then error on
  empty lists.
- Huawei/HyperOS and similar OEM Android variants use the `android` sync token;
  OEM store packaging remains an app concern.

### 2. Projection stays unified

- `intentcall_platform_sync` remains the single Dart-only projection package for
  all emitters and `PlatformSync`.
- Per-platform pub packages for emitters are deferred until a platform requires
  non-Dart build toolchain dependencies (e.g. future HarmonyOS ArkTS).

### 3. Federated Flutter runtime plugins

Split runtime native code into endorsed federated packages:

| Package | Role |
|---------|------|
| `intentcall_platform` | App-facing umbrella with `default_package` map and Dart host API |
| `intentcall_platform_apple` | iOS + macOS native (Pigeon + Swift), SPM under `darwin/`; public Swift facades `IntentCallNativeBridge`, `IntentCallNativeHandoffStore`, `IntentCallNativeEntitySnapshotStore` |
| `intentcall_platform_android` | Android native (Pigeon + Kotlin) |
| `intentcall_bridge` | Shared Pigeon IDL and generated bindings |

**Hardcut:** no separate `intentcall_platform_interface` package — the umbrella
owns the Dart host surface; apple + android are the endorsed impl packages.

### 4. Apple: SPM-only

- Native Apple code lives under SPM layout in the apple impl package:
  `intentcall_platform_apple/darwin/intentcall_platform_apple/Sources/...`
  with `Package.swift`.
- Use `sharedDarwinSource: true` in the umbrella plugin pubspec for ios + macos.
- No `*.podspec` for IntentCall-owned Apple plugin packages (SPM-only).
- Minimum consumer Flutter: 3.44+ with Swift Package Manager enabled.

### 5. Legacy package sunset

- Delete `intentcall_apple` and `intentcall_android` from the workspace (hardcut:
  zero pub consumers; do not rename into `intentcall_platform_*`).
- Projection remains in `intentcall_platform_sync`; runtime remains federated
  under `intentcall_platform` + endorsed impl packages.
- Do not resurrect sparse-manifest generators.

## Consequences

Good:

- Config (`platforms.enabled`) scopes projection surfaces and hook spine targets;
  federation scopes per-target native compile. Config does **not** remove
  transitive pub dependencies — unused platform packages may still appear in the
  dependency graph until consumers depend on a federated subset.
- Flutter-aligned federated plugin model; domain experts can extend per platform.
- Single Darwin Swift tree under `intentcall_platform_apple/darwin/`; SPM-only
  (no CocoaPods dual path).
- Apple cross-target contract: `intentcall_platform_sync` emits `AppIntent`
  structs into `Runner/Generated/`; generated Swift imports
  `intentcall_platform_apple` and calls plugin facades (no per-app bridge enum).
- No separate interface package — fewer packages, umbrella remains the only
  app-facing dependency for most authors.
- Projection pipeline unchanged — three-gate spine preserved.

Tradeoffs:

- More packages in the release train (umbrella + 2 endorsed impl packages).
- SPM-only is a breaking change for consumers on legacy CocoaPods-only workflows.
- Migration requires coordinated `mcp_flutter` and docs updates.

## Non-goals

- Per-platform projection pub packages without toolchain justification
- Pigeon for App Intents Swift emitters
- HarmonyOS package until artifact format diverges from Android
- Live OS semantic proof in agentkit CI

## Related

- [0022-projection-pipeline-alignment.md](0022-projection-pipeline-alignment.md)
- [0024-dart-hooks-and-pigeon-bridge-consistency.md](0024-dart-hooks-and-pigeon-bridge-consistency.md)
- [platform-subset-federated-plugins-plan.md](../evidence/platform-subset-federated-plugins-plan.md)
- [hooks-native-bridge-plan.md](../evidence/hooks-native-bridge-plan.md)
