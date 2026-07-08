# 0024. Dart Hooks and Pigeon Bridge Consistency

Date: 2026-07-08

## Status

Accepted

## Context

[ADR 0019](0019-framework-neutral-intentcall-cli.md) extracted `intentcall_platform_sync` and
`intentcall_cli`, defining a three-gate projection spine (`build_runner` → manifest export →
platform sync). [ADR 0022](0022-projection-pipeline-alignment.md) and
[ADR 0023](0023-entity-three-slot-projection.md) completed dense manifest export, Apple
sub-channels, and entity projection.

Remaining gaps are **operational**, not policy:

1. Host build hooks are hand-maintained Gradle/Xcode/Jaspr string templates that subprocess
   `intentcall` on PATH. `hooks.syncCommand` in `intentcall.yaml` is parsed but unused.
2. The [Dart SDK hooks](https://dart.dev/tools/hooks) model (`hook/build.dart`, dependency
   ordering, cache invalidation) is a better long-term orchestration surface for Jaspr and
   plain Dart hosts.
3. Flutter runtime bridges use hand-written `MethodChannel` string dispatch. Generated Swift
   duplicates handoff-store logic; entity channel keys and entity-open drain are inconsistent
   with manifest projection (ADR 0015/0018).

The retired [projection-pipeline-spec](../evidence/projection-pipeline-spec.md) execution
playbook is superseded by [hooks-native-bridge-plan](../evidence/hooks-native-bridge-plan.md).

## Decision

### 1. PlatformHookSpine (Phase 1)

Add a single resolver in `intentcall_platform_sync` that reads `intentcall.yaml` and produces:

- codegen, manifest export, and platform sync phase commands
- resolved platform list from `HostProfile` + `platforms.enabled`
- CLI invocation from `hooks.syncCommand` when set, else `dart run intentcall_cli:intentcall`

Gradle, Xcode, and Jaspr templates are **generated from the spine**, not hand-maintained.

### 2. Dart SDK build hook (Phase 2, phased)

Publish `intentcall_hooks` with `hook/build.dart` that calls `ManifestExporter` and
`PlatformSync` **in-process** (no subprocess `intentcall`).

- **Phase 2a:** Jaspr and plain Dart web hosts — `intentcall_hooks` is the
  canonical build hook; no Gradle/Xcode involvement
- **Phase 2b (deferred gate):** Flutter hosts — Gradle `preBuild` and Xcode Run
  Script templates from `PlatformHookSpine` stay until dogfood proves Dart SDK
  hook ordering. **Gate:** `flutter build` must run `hook/build.dart` and
  complete manifest export + platform sync **before** `xcodebuild compile` /
  Android native compile for the app target. Until then, Flutter consumers keep
  spine-rendered Gradle/Xcode hooks from `intentcall platform hooks init`; do not
  remove those templates. After proof, templates may shrink to staleness checks;
  full removal needs ADR amendment. See
  [hooks-native-bridge-plan §6.3](../evidence/hooks-native-bridge-plan.md#63-flutter-native-hook-migration-deferred--phase-2b).
- Hook v1 **requires** fresh `agent_catalog.g.dart`; does not spawn `build_runner` inside the hook
- Extract shared `CatalogLoader` for CLI and hook parity

### 3. Pigeon bridge (Phase 3)

Add `intentcall_bridge` with Pigeon IDL for:

- `intentcall_platform/invocations` — pending invocation drain
- `intentcall_platform/entities` — entity snapshot cache CRUD/search

**Out of Pigeon scope:** App Intents Swift, shortcuts, Android XML, web manifest, deep links,
`nativeInline` handler registry (remain manifest-driven emitters per ADR 0016/0017).

Unify handoff store: single native implementation; generated Swift calls into it.

Pass manifest `EntityKeyBundle` on entity channel calls. Close entity-open drain parity with
invocation drain.

### 4. Harness (Phase 4)

- Add `just platform-hooks-check` and steward action `intentcall.platform-hooks-check`
- Promote `just projection-pipeline-check` to CI and steward quick probe
- Add `just pigeon-codegen-check` when Pigeon lands
- mcp_flutter three-gate remains sibling-repo proof (not agentkit CI blocker for core packages)

## Consequences

Good:

- One spine for all hosts; `hooks.syncCommand` becomes real
- Jaspr/Dart hosts lose PATH/subprocess fragility via Dart SDK hooks
- Plugin channels become typed and auditable; handoff duplication removed
- Three-gate semantics unchanged — only invocation surfaces evolve

Tradeoffs:

- Two new packages (`intentcall_hooks`, `intentcall_bridge`) in release train
- Pigeon adds codegen step to plugin development
- Flutter native hook migration deferred — dual hook systems temporarily

## Non-goals

- Fold `intentcall_platform_sync` into `intentcall_core`
- Pigeon or FFI for App Intents / platform semantic APIs
- Replace manifest emitters with hooks `CodeAsset` until `DataAsset` is stable for compile-time artifacts
- Live OS proof (Siri, Spotlight UX, signed-app discovery)

## Related

- [hooks-native-bridge-plan.md](../evidence/hooks-native-bridge-plan.md)
- [0015-dart-first-native-bridge.md](0015-dart-first-native-bridge.md)
- [0019-framework-neutral-intentcall-cli.md](0019-framework-neutral-intentcall-cli.md)
- [0022-projection-pipeline-alignment.md](0022-projection-pipeline-alignment.md)
- [0023-entity-three-slot-projection.md](0023-entity-three-slot-projection.md)
