# 0016. Dispatch Mode Handoff Contract

Date: 2026-06-28

## Status

Accepted

## Context

IntentCall's Dart-first bridge needs a precise contract for platform surfaces
that can either execute in the current runtime, wake the app, or only record an
invocation for later draining. Apple App Intents already generated wrappers that
queued an invocation and asked the system to open the app, but that behavior was
implicit in generated Swift rather than represented in the manifest.

The native queue also used direct `UserDefaults` append/take code. That is
adequate for a pre-1.0 dispatch bridge, but it must not be described as durable
delivery, exactly-once execution, result transport, or secure storage.

## Decision

IntentCall platform manifests use a manifest-local `dispatchMode` field:

- `inlineRuntime` means the exposed runtime completes the invocation without
  app wake. This covers Dart-first WebMCP and future proven native runtimes.
- `openApp` means the platform surface queues or routes an invocation envelope
  and opens or wakes the app so Dart can drain and execute it.
- `queueOnly` means the surface records an invocation envelope but must not ask
  the platform to open or wake the app.

The field belongs to `intentcall_platform` manifest parsing first. It is not a
wire-schema field in `intentcall_schema`, and it is not an `AgentIntentKind`;
tool/resource kind and dispatch behavior are separate concepts.

Apple treats `openApp` as the default for existing manifests. Generated Apple
App Intent wrappers still collect primitive parameters broadly. Shortcut
publication is curated separately with manifest `surfaces`; not every tool is
published through `AppShortcutsProvider`.

Apple `inlineRuntime` is rejected until there is separate proof for app
extension hosting or another native runtime path. `queueOnly` enqueues without
`openAppWhenRun` and without URL fallback dispatch.

Manifest entries can also declare per-surface projection hints:

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

Surface keys are platform projection hints, not dispatch modes. They decide
which generated artifacts advertise or mention an entry. They do not make
protocol fallback trusted, prove OS registration, or prove native semantic
execution. Windows protocol activation and Linux `x-scheme-handler` are
fallback route artifacts; Windows App Actions remain a separate roadmap semantic
surface.

The native storage boundary is named as a handoff store. Current plugin
semantics remain at-most-once: taking pending invocations clears them before
Dart execution reports success or failure. A future stronger store may add
claim, ack, fail, and retry semantics, but this decision does not claim that
durability today.

`IntentCallFlutterHost` owns dispatch after foregrounding. It can drain at
startup, listen for resume wake signals, coalesce overlapping drains, and emit
observable host events. App code should not poll raw pending native rows for
ordinary dispatch.

## Consequences

Good:

- Dispatch behavior is explicit in generated artifacts and tests.
- Apple open-app behavior remains compatible with existing manifests.
- Queue-only diagnostic paths cannot accidentally wake the app.
- Shortcut exposure can stay user-facing and opt-in.
- Android, web, Windows, and Linux projection artifacts can be curated with the
  same manifest-local mechanism.
- Docs can label the current native queue honestly as at-most-once dispatch.

Tradeoffs:

- Manifest authors need a separate `surfaces` object for publication and
  protocol projection.
- Existing app authors who expected every tool to appear in App Shortcuts must
  opt in with `surfaces["apple.appShortcuts"]`.
- `inlineRuntime` remains a non-claim for Apple until runtime proof exists.
- The current store is not durable delivery; stronger retry semantics require a
  later implementation and evidence loop.
- `surfaces` can curate generated metadata, but host apps still own runtime
  authorization, deep-link parsing, and allowlisting.

## Proof Boundary

Current proof is artifact and contract-test proof:

- manifest parser/default behavior,
- Apple emitter behavior for `openApp`, `queueOnly`, and rejected
  `inlineRuntime`,
- Flutter host startup/resume/manual drain behavior,
- bridge authorization tests,
- Steward adapter-contract scenario coverage.

Live OS discovery, assistant invocation, app-extension-hosted Dart, background
Dart execution, native semantic result execution, exactly-once delivery, and
production authorization UX remain consuming-app proof requirements.

## Official References

- Apple App Intents and `AppIntent` execution:
  [AppIntent](https://developer.apple.com/documentation/appintents/appintent),
  [openAppWhenRun](https://developer.apple.com/documentation/appintents/appintent/openappwhenrun).
- Flutter host/runtime and app-extension constraints:
  [iOS app extensions](https://docs.flutter.dev/platform-integration/ios/app-extensions),
  [deep linking](https://docs.flutter.dev/ui/navigation/deep-linking).
- Android projection tiers:
  [Android App Links](https://developer.android.com/training/app-links),
  [App Actions](https://developer.android.com/develop/devices/assistant/get-started),
  [App Functions](https://developer.android.com/ai/appfunctions).
- Web projection surfaces:
  [Web App Manifest](https://www.w3.org/TR/appmanifest/),
  [registerProtocolHandler](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/registerProtocolHandler),
  [manifest protocol handlers incubation](https://wicg.github.io/manifest-incubations/).
- Windows and Linux protocol fallback:
  [Windows URI activation](https://learn.microsoft.com/en-us/windows/apps/develop/launch/handle-uri-activation),
  [Windows App Actions URI launch](https://learn.microsoft.com/en-us/windows/ai/app-actions/actions-uri-launch),
  [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry/desktop-entry-spec-latest.html),
  [`xdg-settings` scheme handler behavior](https://cgit.freedesktop.org/xdg/xdg-utils/tree/scripts/xdg-settings.in).
