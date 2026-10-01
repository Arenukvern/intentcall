# intentcall_cli

Framework-neutral IntentCall CLI: manifest export, platform sync, link
discovery, and a stdio MCP server for any Dart host.

```sh
dart run intentcall_cli:intentcall manifest export --check   # drift gate
dart run intentcall_cli:intentcall platform sync --platform web
dart run intentcall_cli:intentcall link discover
dart run intentcall_cli:intentcall mcp serve
```

- **`manifest export`** — project the compiled agent catalog
  (`agent_catalog.g.dart`) plus curated metadata into
  `web/agent_manifest.json`; `--check` reports drift (CI gate).
- **`platform sync`** — write/validate platform artifacts (WebMCP
  bootstrap JS, Apple App Intents scaffolds) from `intentcall.yaml`.
- **`link discover` / `link call`** — read the per-user links directory
  and invoke published app surfaces via the `<scheme>://invoke/...`
  fallback.
- **`mcp serve`** — expose the host's registered intents as MCP tools
  over stdio (`--auto` keeps the server non-empty with
  `intentcall_app_status`).
- **Apple testing helpers** — emit AppIntentsTesting fixtures from the
  manifest for UI-automation runs.

Pure Dart — no Flutter SDK required. Pair with `intentcall_core`
(runtime registry) and `intentcall_platform_sync` (projection layer).
