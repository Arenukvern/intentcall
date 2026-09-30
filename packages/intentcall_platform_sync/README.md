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
