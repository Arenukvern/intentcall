# intentcall_hooks

Dart SDK build hooks for IntentCall projection: manifest export and platform
sync in-process (no `intentcall` subprocess).

**Host scope (ADR 0024):** Jaspr and plain Dart web hosts use this package as the
canonical build hook (Phase 2a). **Flutter hosts still use Gradle/Xcode templates
from `PlatformHookSpine`** (`intentcall platform hooks init`) until Phase 2b
timing proof shows `flutter build` runs this hook before `xcodebuild compile` /
Android native compile. Do not remove Gradle/Xcode hooks in Flutter apps until
that gate passes.

## Usage

Add a dev dependency and configure user-defines on the consuming package:

```yaml
dev_dependencies:
  intentcall_hooks: any # dart pub add --dev intentcall_hooks

hooks:
  user_defines:
    intentcall_hooks:
      project_root: .
      platforms: web
      check_only: false
```

Prerequisite: fresh `lib/generated/agent_catalog.g.dart` from `build_runner`.
The hook does **not** spawn `build_runner` in v1.

## Manual verification (jaspr fixture)

```bash
cd packages/intentcall_cli/test/fixtures/jaspr_web_project
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart test ../../../intentcall_hooks/test/intentcall_hook_runner_test.dart
```

## Gates

```bash
dart analyze packages/intentcall_hooks
dart test packages/intentcall_hooks
dart test packages/intentcall_platform_sync/test/catalog_loader_test.dart
```
