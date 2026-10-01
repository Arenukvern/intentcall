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
native runners — use the **mcp_flutter** showcase instead (below).

## Platform sync against mcp_flutter (Apple Swift proof)

The codegen example exports manifest rows (`app_demo_set_greeting`) but cannot
materialize `AppIntent` Swift without a Flutter/Xcode tree. The canonical Apple
dogfood app is **`mcp_flutter/flutter_test_app`**, which hand-registers
`app_set_greeting` with `apple.appIntents` + `apple.appShortcuts` opt-in.

### Prerequisite

Clone [mcp_flutter](https://github.com/Arenukvern/mcp_flutter) as a sibling of
this monorepo (or set `MCP_FLUTTER_ROOT` to the mcp_flutter checkout):

```text
~/mcp/
  agentkit/          ← this repo
  mcp_flutter/
    flutter_test_app/
      web/agent_manifest.json
      ios/Runner/Generated/IntentCallGenerated.swift
```

### From agentkit (IntentCall CLI)

```bash
# Drift check — manifest → generated Swift must match committed files
dart run intentcall_cli:intentcall platform sync \
  --platform ios,macos \
  --check \
  --project-dir ../mcp_flutter/flutter_test_app

# Regenerate after manifest changes
dart run intentcall_cli:intentcall platform sync \
  --platform ios,macos \
  --project-dir ../mcp_flutter/flutter_test_app
```

### From mcp_flutter (toolkit wrapper — what CI runs)

```bash
cd ../mcp_flutter
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir flutter_test_app --check
```

Xcode build phases call `ios/intentcall_codegen.sh`, which runs
`intentcall manifest export --check` then `intentcall platform sync --platform ios,macos`.

### Verify `SetGreeting` in generated Swift

After sync, both iOS and macOS emit the same intent scaffold:

```bash
rg 'AppSetGreetingIntent|app_set_greeting' \
  ../mcp_flutter/flutter_test_app/ios/Runner/Generated/IntentCallGenerated.swift \
  ../mcp_flutter/flutter_test_app/macos/Runner/Generated/IntentCallGenerated.swift
```

Expected symbols:

| Symbol | Role |
|--------|------|
| `struct AppSetGreetingIntent: AppIntent` | Siri / Shortcuts verb |
| `qualifiedName: "app_set_greeting"` | Dart registry handoff |
| `AppShortcut(intent: AppSetGreetingIntent()` | Curated Siri phrase |

Manifest source: `app_set_greeting` in
`mcp_flutter/flutter_test_app/web/agent_manifest.json` with
`apple.appShortcuts.include: true`. Registry source:
`lib/intentcall_showcase_entries.dart` → `buildSetGreetingEntry()`.

### Automated check (agentkit)

When the sibling repo is present, agentkit runs:

```bash
dart test packages/intentcall_platform_sync/test/mcp_flutter_apple_sync_test.dart
```

Or from `justfile`: `just mcp-flutter-apple-sync-check`.

Full consumer gates live in mcp_flutter:
`make check-intentcall-hosted-consumer` (hosted) or
`make check-intentcall-integration` (sibling agentkit matrix).

See also `mcp_flutter/flutter_test_app/INTENTCALL_PLATFORM.md` and
`docs/DX_FAQ.mdx` (Apple readiness checklist).


```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run ../../intentcall_cli/bin/intentcall.dart manifest export --check
dart run lib/main.dart
dart test
```
