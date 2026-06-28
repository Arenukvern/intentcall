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

Swift Package Manager support is declared for the iOS/macOS Flutter plugin under
`ios/intentcall_platform/Package.swift` and
`macos/intentcall_platform/Package.swift`. CocoaPods remains supported through
the existing podspecs so current Flutter projects can use either native package
integration path.

## Invocation policy

Native and WebMCP execution is deny-by-default in compiled profile/release
builds. For local dogfood, `IntentCallAuthorizationPolicy.debugAllowAll()` opens
execution only while Dart assertions are enabled; in compiled builds it behaves
like `denyAll()`.

Production apps should pass an explicit `IntentCallAuthorizationPolicy` with
source and qualified-name allowlists, and use `confirm` for mutating or sensitive
tools.

`IntentCallFlutterHost.bindRegistry(...)` is the high-level Flutter app entry
point. It binds an `AgentRegistry`, optionally registers Dart-first WebMCP,
drains pending native envelopes at startup, can drain again on foreground/resume,
coalesces overlapping drains, and emits host events for dispatch observability.
Plain deep links are not trusted by default; they should normally wake the app so
the pending native queue can be drained through the same authorization policy.

Current native handoff storage is at-most-once dispatch. The plugin takes and
clears pending rows before Dart execution reports success or failure. Treat that
as a bridge contract, not durable delivery, result transport, secure storage, or
exactly-once execution.

## Dispatch modes

Each manifest entry can declare a manifest-local `"dispatchMode"`:

| Mode | Meaning |
|---|---|
| `"inlineRuntime"` | The current exposed runtime completes the call without app wake. Apple rejects this until separate native runtime proof exists. |
| `"openApp"` | Queue or route an envelope and open/wake the app for Dart dispatch. This is the default for existing manifests. |
| `"queueOnly"` | Queue an envelope without opening the app or URL fallback. This is diagnostic/fallback dispatch, not product proof. |

Apple App Intent wrappers are still generated broadly for tools, but
`AppShortcutsProvider` is curated. Set `"includeInShortcuts": true` only for
user-facing actions that should appear as shortcuts.

## Manifest workflow (I4)

`agent_manifest.json` is read from the project root first, then from `web/`.
The web copy is commonly checked in and refreshed by CLI — not generated live
from `AgentRegistry` yet.

Apps that generate protocol fallback artifacts must declare their own URI scheme
with a top-level `"protocolScheme"` in `agent_manifest.json`, or pass an explicit
scheme to the sync/emitter API. IntentCall does not reserve a global
`intentcall://` scheme because each app owns its platform URL declarations.

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
