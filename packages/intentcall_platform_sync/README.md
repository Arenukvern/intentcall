# intentcall_platform_sync

PRE-RELEASE — Dart-only platform manifest, emitters, and sync for
IntentCall.

The projection layer between an app's compiled registry catalog and the
platform artifacts agents consume. It reads the build_runner-generated
`lib/generated/agent_catalog.g.dart`, merges it with hand-curated
manifest metadata, and emits/validates everything downstream:

- **Agent manifest** — `web/agent_manifest.json` projection
  (`intentcall manifest export --check` keeps it honest).
- **Catalog loading** — probe-and-load the generated catalog
  (`CatalogLoader`), including entity type descriptors.
- **Platform emitters** — WebMCP bootstrap JS, Apple (Swift/App Intents)
  and Android runner scaffolds, Gradle/Xcode hook spines.
- **Sync** — `intentcall platform sync` writes platform artifacts;
  `--check` reports drift (CI gate).
- **Invocation** — protocol fallback (`<scheme>://invoke/...`) link
  records and discovery.

Pure Dart: no Flutter SDK, no plugin surfaces. Pair it with
`intentcall_cli` for the command surface and `intentcall_core` for the
runtime registry.

## WebMCP projection API

The Dart-first WebMCP bootstrap projects an app's entries/registry onto the
browser's `window.webMcp` surface. **Every entry point takes an explicit
`IntentCallAuthorizationPolicy`** — nothing registers WebMCP tools without
one:

```dart
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

// Composable with the Flutter MCP Toolkit's projection SPI: pass
// `projection.entriesChanged` to `MCPToolkitBinding.addEntryListener`.
const projection = WebMcpProjection(
  policy: IntentCallAuthorizationPolicy.denyAll(), // or an explicit allowlist
);
binding.addEntryListener(projection.entriesChanged);

// One-shot forms:
projectEntriesToWebMcp(entries, policy: myPolicy);
projectRegistryToWebMcp(registry, policy: myPolicy, surfaceIndex: index);
```

`debugAllowAll()` is open only while Dart assertions are enabled and behaves
like `denyAll()` in compiled profile/release builds — pass it deliberately,
for local dogfood only. Emitter and sync truth (`PlatformSync`, the Apple /
Android / web emitters, `kPlatformSyncTargets`) also lives here; the CLI
verbs over it live in `intentcall_cli`.
