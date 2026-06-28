> ⚠️ **Pre-release train** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_platform

[![pub package](https://img.shields.io/pub/v/intentcall_platform.svg?include_prereleases)](https://pub.dev/packages/intentcall_platform)
[![pub points](https://img.shields.io/pub/points/intentcall_platform.svg)](https://pub.dev/packages/intentcall_platform/score)
[![repository](https://img.shields.io/badge/repo-intentcall-blue)](https://github.com/Arenukvern/intentcall)

Platform emitters, `PlatformSync`, Dart-first WebMCP bootstrap, and optional
Flutter plugin support for pending native invocation dispatch.

Native platform code should stay thin. Open-app generated wrappers collect
supported parameters, enqueue an `IntentCallInvocationEnvelope`, and let Dart
execute the registered `AgentRegistry` handler after app launch or wake. Apple
`nativeInline` wrappers can instead call an app-owned Swift handler without
opening the app. Apple inline runtimes can also generate primitive typed App
Intents returns when `inlineRuntime.result` is declared. App-extension hosted
Dart execution has an experimental scaffold and Dart runtime bridge, but is not
a stable support claim.

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
| `"inlineRuntime"` | The current exposed runtime completes the call without app wake. Apple supports explicit `nativeInline` main-app Swift handlers today; `dartExtensionInline` is experimental scaffold-only. |
| `"openApp"` | Queue or route an envelope and open/wake the app for Dart dispatch. This is the default for existing manifests. |
| `"queueOnly"` | Queue an envelope without opening the app or URL fallback. This is diagnostic/fallback dispatch, not product proof. |

Apple inline runtime entries must opt in explicitly:

```json
{
  "dispatchMode": "inlineRuntime",
  "inlineRuntime": {
    "kind": "nativeInline",
    "platforms": {
      "apple": { "target": "mainApp" }
    }
  }
}
```

Generated Swift exposes `IntentCallAppleInlineRuntime.register(...)` for
app-owned native handlers. Dialog-only entries map native success or generated
failure to an `IntentDialog`. Entries with `inlineRuntime.result` generate
`ReturnsValue<T> & ProvidesDialog` App Intents results for primitive
`string`/`integer`/`number`/`boolean` values:

```json
{
  "dispatchMode": "inlineRuntime",
  "inlineRuntime": {
    "kind": "nativeInline",
    "result": { "type": "string" },
    "platforms": {
      "apple": { "target": "mainApp" }
    }
  }
}
```

For `nativeInline`, app Swift handlers return the typed value through
`IntentCallInlineRuntimeResult(value:)`. For `dartExtensionInline`, generated
Swift reads the typed value from `AgentResult.data[dataKey]`; `dataKey` defaults
to `"value"`.

Track B (`"kind": "dartExtensionInline"`) is available only as an experimental
scaffold:

- `IntentCallDartExtensionInlineRuntime` is VM-safe Dart code that invokes an
  app-provided `AgentRegistry` from an extension channel request.
- `AppleDartExtensionInlineEmitter(enableExperimental: true)` emits a Swift App
  Intents extension scaffold and Dart entrypoint template.
- `AppleAppIntentsTestingEmitter` emits an Apple 27+ XCTest UI-test scaffold
  that uses `AppIntentsTesting` for live system invocation proof in the
  consuming app.
- Normal `PlatformSync` does not create or wire an App Intents extension target.

Do not ship `dartExtensionInline` as supported until a fixture app proves target
membership, `FlutterEngine` bootstrap, plugin allowlisting, App Group/shared
storage or IPC, timeout/memory limits, typed result success/failure, and live OS
invocation.

Apple App Intent wrappers are still generated broadly for tools, but
`AppShortcutsProvider` is curated. Use entry-local `"surfaces"` for publication
and fallback artifact projection:

```json
{
  "dispatchMode": "openApp",
  "surfaces": {
    "apple.appShortcuts": { "include": true },
    "android.shortcuts": { "include": true },
    "web.manifestShortcuts": { "include": true },
    "web.protocolHandlers": { "include": true },
    "web.webMcp": { "include": true },
    "windows.protocolActivation": { "include": true },
    "windows.msixProtocol": { "include": true },
    "linux.schemeHandler": { "include": true }
  }
}
```

Apple App Shortcuts default to opt-in (`false`) so apps publish only
user-facing actions. Android, web, Windows, and Linux projection artifacts
preserve existing broad defaults and can be opted out with `"include": false`.

## Manifest workflow (I4)

`agent_manifest.json` is read from the project root first, then from `web/`.
The web copy is commonly checked in and refreshed by CLI — not generated live
from `AgentRegistry` yet.

Apps that generate protocol fallback artifacts must declare their own URI scheme
with a top-level `"protocolScheme"` in `agent_manifest.json`, or pass an explicit
scheme to the sync/emitter API. IntentCall does not reserve a global
`intentcall://` scheme because each app owns its platform URL declarations.
Generated protocol artifacts do not guarantee OS registration, default-handler
selection, or trusted dispatch. Web protocol handlers, Windows protocol
activation, and Linux `x-scheme-handler` entries are app-owned fallback routes;
host apps must validate source, scheme, qualified name, payload, and
authorization before dispatch.

The package-owned contract is the manifest, emitter, and sync API. Host CLIs may
wrap that API for their own product workflow. For example, Flutter MCP Toolkit
consumers can run:

```bash
flutter-mcp-toolkit codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir <app>
```

Use the same command with `--check` in CI. `--check` reports whether any
generated artifact or native project membership would change without writing
files.

### One-time hooks

Flutter MCP Toolkit consumer example:

```bash
flutter-mcp-toolkit init intentcall-platform --project-dir <flutter_app>
```

### Future

Registry-backed `generateWebAgentManifest` is deferred — edit `agent_manifest.json`, then `codegen sync`.
