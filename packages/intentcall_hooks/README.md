# intentcall_hooks

Dart SDK build hooks for IntentCall projection: manifest export and platform
sync in-process (no `intentcall` subprocess).

## Usage

Add a dev dependency and configure user-defines on the consuming package:

```yaml
dev_dependencies:
  intentcall_hooks: ^0.6.0

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
