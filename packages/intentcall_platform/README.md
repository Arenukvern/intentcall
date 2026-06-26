> ⚠️ **Pre-release (0.2.x train)** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_platform

Platform emitters, `PlatformSync`, Dart-first WebMCP bootstrap, and optional
Flutter plugin support for pending native invocation dispatch.

Native platform code should stay thin. Generated wrappers collect supported
parameters, enqueue an `IntentCallInvocationEnvelope`, and let Dart execute the
registered `AgentRegistry` handler after app launch or wake. App-extension
hosted Dart execution is experimental and not a stable support claim.

For iOS and macOS, `PlatformSync` also maintains the generated
`Runner/Generated/IntentCallGenerated.swift` file in the main `Runner` target's
Sources build phase so App Intents can be compiled and discovered by Apple
system surfaces.

## Manifest workflow (I4)

`web/agent_manifest.json` is **checked in** and refreshed by CLI — not generated live from `AgentRegistry` yet.

```bash
flutter-mcp-toolkit codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir <app>
```

Use `--check` in CI (`make check-intentcall-integration`).

### One-time hooks

```bash
flutter-mcp-toolkit init intentcall-platform --project-dir <flutter_app>
```

### Future

Registry-backed `generateWebAgentManifest` is deferred — edit `agent_manifest.json`, then `codegen sync`.
