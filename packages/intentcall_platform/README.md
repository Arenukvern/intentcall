> ⚠️ **Pre-release train** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_platform

Platform emitters, `PlatformSync`, Dart-first WebMCP bootstrap, and optional
Flutter plugin support for pending native invocation dispatch.

Native platform code should stay thin. Generated wrappers collect supported
parameters, enqueue an `IntentCallInvocationEnvelope`, and let Dart execute the
registered `AgentRegistry` handler after app launch or wake. App-extension
hosted Dart execution is experimental and not a stable support claim.

For iOS and macOS, `PlatformSync` also maintains the generated
`Runner/Generated/IntentCallGenerated.swift` file in the main `Runner` target's
Sources build phase. That is an artifact/project-sync claim: successful Xcode
builds, installation, Apple system discovery, and live invocation need proof in
the consuming app.

## Invocation policy

Native and WebMCP execution is deny-by-default in compiled profile/release
builds. For local dogfood, `IntentCallAuthorizationPolicy.debugAllowAll()` opens
execution only while Dart assertions are enabled; in compiled builds it behaves
like `denyAll()`.

Production apps should pass an explicit `IntentCallAuthorizationPolicy` with
source and qualified-name allowlists, and use `confirm` for mutating or sensitive
tools.

## Manifest workflow (I4)

`agent_manifest.json` is read from the project root first, then from `web/`.
The web copy is commonly checked in and refreshed by CLI — not generated live
from `AgentRegistry` yet.

```bash
flutter-mcp-toolkit codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir <app>
```

Use the same command with `--check` in CI. `--check` reports whether any
generated artifact or native project membership would change without writing
files.

### One-time hooks

```bash
flutter-mcp-toolkit init intentcall-platform --project-dir <flutter_app>
```

### Future

Registry-backed `generateWebAgentManifest` is deferred — edit `agent_manifest.json`, then `codegen sync`.
