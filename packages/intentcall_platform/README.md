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

L3 adds an additive projection direction for actions, typed app entities, and
indexing lifecycle. Dart remains the source of truth for app behavior and
entity snapshots. Platform code may store a durable native projection cache so
query/indexing callbacks can answer while Flutter is cold, but that cache is not
the product database.

For iOS and macOS, `PlatformSync` also maintains the generated
`Runner/Generated/IntentCallGenerated.swift` file in the main `Runner` target's
Sources build phase. When a manifest has a `protocolScheme` and open-app Apple
entries, it also keeps `Runner/Info.plist` `CFBundleURLTypes` registered for
that app-owned scheme. That is an artifact/project-sync/configuration claim:
successful Xcode builds, signing, installation, Apple system discovery, and live
invocation need proof in the consuming app.

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
Important options are:

- `policy`: required for non-debug trust decisions; compiled builds deny by
  default without an explicit allowlist or confirmation policy.
- `registerWebMcp`: registers Dart-first WebMCP when the host page exposes a
  compatible `window.webMcp` surface.
- `listenForDeepLinks`: listens for app-owned invoke URLs and drains the native
  queue instead of trusting URL input directly.
- `protocolScheme`: required when `listenForDeepLinks` is enabled and should
  match manifest `protocolScheme` plus Apple `CFBundleURLTypes`.

Current native handoff storage is at-most-once dispatch. The plugin takes and
clears pending rows before Dart execution reports success or failure. Treat that
as a bridge contract, not durable delivery, result transport, secure storage, or
exactly-once execution.

## Actions, entities, and indexing (L3)

This package may project three additive concepts:

- actions: user-facing projections of normal `AgentRegistry` entries,
- typed app entities: stable ids, display fields, and search/index fields
  derived from Dart-owned app snapshots,
- indexing lifecycle: refresh, delete, and prune operations that copy those
  snapshots into platform caches.

Apple is the first concrete projection. Apple entity query and indexing code
must read durable native cache data because the Flutter runtime may be cold when
the system asks for entities or indexed records. The app's Dart layer owns the
snapshot and refresh lifecycle; native storage owns only the latest projection.

Generated schemas, generated App Intents files, native cache rows, and
indexing/donation helpers are not live Spotlight, Siri, Shortcuts, donation,
indexing, or product proof. Claim those only from a signed consuming app or
AppIntentsTesting proof where the API covers the scenario.

Keep Apple proof labels precise:

- Generated Swift compile proof means the generated code compiles against the
  active SDK; it does not prove runtime behavior.
- AppIntentsTesting runtime proof is the primary automated regression lane for
  Apple App Intents actions, supported entity queries, and Spotlight query paths
  where Apple's testing API covers them.
- Entity query proof shows native query code reading the durable projection
  cache while Flutter may be cold.
- Spotlight indexing/query proof shows accepted, queryable, refreshed, or
  deleted records through the signed consuming app or AppIntentsTesting path
  that exercises that system behavior.
- Manual Siri, Shortcuts, and Spotlight runs are smoke/product UX lanes.

If the active developer directory is Command Line Tools or `AppIntentsTesting`
is not importable, local package evidence should be described as scaffold and
API-shape proof plus Steward gates, not AppIntentsTesting runtime proof.

For the local Xcode framework probe, run:

```bash
just apple-appintents-testing-typecheck /Applications/Xcode-beta.app
```

The recipe points `DEVELOPER_DIR` at the full Xcode app and adds Xcode's
platform Developer framework directory to `swiftc`, which is where
`AppIntentsTesting.framework` is found. It does not prove live invocation;
runtime proof still requires the generated XCTest source in a signed consuming
app's UI-test target and an `xcodebuild test` run.

Generate that XCTest source from the consuming app's manifest and fixtures:

```bash
dart run tool/intentcall/bin/intentcall.dart apple-appintents-testing generate-tests \
  --manifest path/to/agent_manifest.json \
  --bundle-id com.example.app \
  --sample-arguments path/to/appintents_arguments.json \
  --entity-fixtures path/to/appintents_entities.json \
  --output ios/RunnerUITests/IntentCallAppIntentsTests.swift
```

`appintents_arguments.json` is keyed by action `qualifiedName`; each value is an
object of primitive argument fixtures. `appintents_entities.json` is keyed by
entity `qualifiedName`; each value contains `identifier`, `search`, and
`expectedTitle`.

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
For product/showcase actions, prefer normal registry entries with
`"dispatchMode": "openApp"` and a curated `"apple.appShortcuts"` opt-in. Publish
human actions such as "Set greeting in \(.applicationName)" or "Fill form in
\(.applicationName)", not every diagnostic bridge tool. The current manifest
surface options preserve unknown keys for future use, but generated Apple
shortcuts still use the default title/phrase/system image behavior; custom
`phrases`, `title`, `systemImage`, and `parameterSummary` are follow-up work.

## Manifest workflow (I4)

`agent_manifest.json` is read from the project root first, then from `web/`.
The web copy is commonly checked in and refreshed by CLI — not generated live
from `AgentRegistry` yet.

Apps that generate protocol fallback artifacts must declare their own URI scheme
with a top-level `"protocolScheme"` in `agent_manifest.json`, or pass an explicit
scheme to the sync/emitter API. IntentCall does not reserve a global
`intentcall://` scheme because each app owns its platform URL declarations.
For iOS and macOS, `PlatformSync` patches/checks `Runner/Info.plist`
`CFBundleURLTypes` for that scheme when Apple open-app entries are present.
Generated protocol artifacts do not guarantee default-handler selection, signing
success, Shortcuts/Spotlight discovery, or trusted dispatch. Web protocol
handlers, Windows protocol activation, and Linux `x-scheme-handler` entries are
app-owned fallback routes; host apps must validate source, scheme, qualified
name, payload, and authorization before dispatch.

The package-owned contract is the manifest, emitter, and sync API. Host CLIs may
wrap that API for their own product workflow. For example, Flutter MCP Toolkit
consumers can run:

```bash
intentcall platform sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir <app>
```

Use the same command with `--check` in CI.

Flutter MCP Toolkit consumers may delegate:

```bash
flutter-mcp-toolkit codegen sync --platform web,ios,macos --project-dir <app>
```

### Build hooks (ADR 0024)

| Host | Invocation surface |
|------|-------------------|
| **Flutter** (Android/iOS/macOS) | Gradle `preBuild` + Xcode Run Script from `PlatformHookSpine` — one-time init below |
| **Jaspr / plain Dart web** | `intentcall_hooks` Dart SDK `hook/build.dart` (no Gradle/Xcode) |

Flutter native hook migration to `intentcall_hooks` is **deferred** (Phase 2b)
until `flutter build` is proven to run the Dart hook before `xcodebuild compile`
/ Android native compile. Until then, keep spine-rendered Gradle/Xcode snippets.

**Flutter — one-time init:**

```bash
intentcall platform hooks init --host flutter --project-dir <flutter_app>
```

Renders Gradle and Xcode Run Script blocks from `PlatformHookSpine` (not
hand-maintained strings). Re-run after `intentcall.yaml` hook config changes.

**Jaspr / plain Dart — add dev dependency:**

```yaml
dev_dependencies:
  intentcall_hooks: ^0.6.0
```

See [intentcall_hooks README](../intentcall_hooks/README.md) for `user_defines`.

### Manifest generation

Run `dart run build_runner build`, then `intentcall manifest export --check`. Do not hand-edit descriptor rows in `agent_manifest.json`.
