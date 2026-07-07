# intentcall_codegen example

Dart-only dogfood host for `@AgentTool`, `@AgentCatalog`, and manifest export.
It proves catalog merge, projection surfaces, and registry smoke wiring without
a Flutter shell.

## What this example teaches

| Topic | Where |
|-------|--------|
| Top-level `@AgentTool` codegen | `lib/tools/demo_ping_tool.dart` |
| Instance-bound tools + `@AgentCatalog` | `lib/tools/demo_host_tools.dart` |
| Siri / Shortcuts verb discovery | `app_demo_set_greeting` with `apple.appIntents` + `apple.appShortcuts` |
| Web MCP projection | `demo_host_status`, `demo_inbox` |
| Manifest export | `intentcall.yaml` → `web/agent_manifest.json` |

## What belongs elsewhere

**`@AgentEntity`, native entity cache, and Spotlight indexing** are not modeled
here. That path needs a Flutter host, platform sync, and runtime snapshot seeding.
Use the MCP Flutter showcase instead:

- [`mcp_flutter/flutter_test_app`](https://github.com/Arenukvern/mcp_flutter/tree/main/flutter_test_app) — `app_screen` entities, `upsertAgentSnapshotsForType`, iOS generated Swift
- [`packages/intentcall_cli/test/fixtures/entity_catalog_project`](../../intentcall_cli/test/fixtures/entity_catalog_project) — codegen + manifest export unit tests for `@AgentEntity`

Entity codegen fixtures also live under
`packages/intentcall_codegen/test/fixtures/catalog/`.

## Apple surfaces in this example

`intentcall.yaml` enables `web`, `ios`, and `macos` so manifest export emits
Apple App Intent scaffolds for tools. Only curated product verbs opt into
`apple.appShortcuts` (Siri phrases). See `demo_set_greeting` in
`demo_ping_tool.dart`.

Run `intentcall platform sync` from a Flutter app with an `ios/` or `macos/`
target to materialize generated Swift. This dart-only package does not ship
native runners.

## Commands

```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run ../../intentcall_cli/bin/intentcall.dart manifest export --check
dart run lib/main.dart
dart test
```
