# 0017. Apple Inline Runtime Tracks

Date: 2026-06-28

## Status

Accepted

## Context

Apple App Intents can run without opening the app when the intent can complete
inside an allowed platform runtime. IntentCall already had `dispatchMode:
inlineRuntime`, but Apple previously rejected it because there was no proven
native or Dart-in-extension execution path.

The Apple track needs two separate meanings:

- `nativeInline`: generated Swift calls app-owned native Swift code and maps the
  result back to App Intents.
- `dartExtensionInline`: an App Intents extension or other Apple runtime boots
  Flutter/Dart, invokes the Dart registry, and maps results/errors back.

Those tracks are not equivalent. Native Swift inline is a normal platform
integration point. Dart-in-extension is only experimentally plausible until
there is target generation, Flutter engine bootstrap proof, plugin auditing,
shared storage or IPC, timeout/memory handling, and live OS invocation evidence.

Local SDK inspection on 2026-06-28 showed `AppIntent.supportedModes` and
`IntentModes.background` in the installed macOS SDK, with `openAppWhenRun`
deprecated in favor of `supportedModes`. Because `supportedModes` is available
from Apple's 26.0 SDK line, generated Swift guards it with availability while
keeping older open-app compatibility where needed.

Local Xcode beta inspection also showed Apple 27+ AppIntentsTesting APIs:
`IntentDefinitions`, `AnyAppIntent.run()`, and typed `ResolvedIntentResult`
access. That is the automated live-system proof lane for consuming apps because
it runs through App Intents infrastructure rather than directly calling
`perform()`.

## Decision

Apple `inlineRuntime` now requires explicit manifest metadata:

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

The manifest parser rejects `dispatchMode: "inlineRuntime"` without an
`inlineRuntime` object and rejects stale `inlineRuntime` metadata on non-inline
entries.

For Apple `nativeInline` with `target: "mainApp"`, generated Swift:

- emits `supportedModes` as background-only behind Apple 26.0 availability,
- emits `allowedExecutionTargets` as `.main` behind Apple 27.0 availability,
- does not emit `openAppWhenRun`,
- collects primitive parameters as before,
- calls `IntentCallAppleInlineRuntime.perform(qualifiedName:arguments:)`,
- maps dialog-only success and generated failures to `IntentDialog`,
- maps declared primitive `inlineRuntime.result` values to
  `ReturnsValue<T> & ProvidesDialog`,
- exposes a small registration contract for app-owned native Swift handlers.

`dartExtensionInline` remains outside the normal main-app emitter. Track B is
implemented as an explicit experimental scaffold:

- `IntentCallDartExtensionInlineRuntime` decodes extension channel requests,
  force-tags them as `apple.dart_extension_inline`, applies an
  `IntentCallAuthorizationPolicy`, invokes the Dart `AgentRegistry`, and encodes
  a stable result map.
- `AppleDartExtensionInlineEmitter(enableExperimental: true)` emits a Swift App
  Intents extension scaffold that boots a `FlutterEngine`, invokes a
  `MethodChannel`, constrains Apple 27+ execution to `.appIntentsExtension`,
  and maps Dart results/errors to `IntentDialog` or declared primitive typed
  values from `AgentResult.data[dataKey]`.
- The same emitter emits a Dart entrypoint template with
  `@pragma('vm:entry-point')` and an app-owned registry factory placeholder.

`AppleAppIntentsTestingEmitter` emits an Apple 27+ XCTest UI-test scaffold that
uses `AppIntentsTesting.IntentDefinitions` and `AnyAppIntent.run()` for
consuming-app live invocation proof. Required App Intent parameters must be
provided as explicit sample values when generating this scaffold.

The default `AppleSwiftAppIntentsEmitter` still rejects `dartExtensionInline`.
The scaffold requires an explicit experimental flag and is not wired into normal
`PlatformSync`, because live target membership and OS invocation are not proven.

Apple `openApp` and `queueOnly` remain handoff modes. They keep the generated
handoff store and bridge; `openApp` can request foreground execution, while
`queueOnly` remains background queueing and is not promoted product proof.

## Consequences

Good:

- `nativeInline` can be used for small native Swift actions without waking the
  app.
- The Dart extension idea now has a concrete scaffold and VM-safe Dart runtime
  bridge, but cannot accidentally become a support claim.
- Primitive typed App Intents returns can be generated and tested without
  inventing a full output-schema system yet.
- Consuming apps have a generated AppIntentsTesting lane for real macOS/iOS
  system invocation proof on Apple 27+ SDKs.
- The generated Swift follows the modern `supportedModes` direction while
  preserving older open-app behavior.
- Tests distinguish parser shape, native inline generation, and unsupported
  extension targets.

Tradeoffs:

- Typed App Intents returns are limited to primitive values until IntentCall has
  explicit output schemas for richer App Intents value types.
- App authors must register native Swift handlers by qualified name.
- The main app target is the only supported Apple native inline target for now.
- App authors experimenting with `dartExtensionInline` must create and maintain
  an App Intents extension target themselves until target generation is proven.
- Live OS invocation proof is still a consuming-app lane, not guaranteed by
  emitter string tests or SDK typechecks.

## Cross-Platform Notes

WebMCP remains the current Dart-first inline runtime.

Android App Functions are the closest future Android analogue for native
semantic execution. Android shortcuts and deep links remain routing/fallback
artifacts.

Windows App Actions and Agent Launchers are future native semantic targets.
Windows URI activation remains protocol fallback and must not be described as
inline runtime.

Linux has no current OS-level native inline intent analogue in this repo; keep
Linux on protocol fallback until a real desktop API and runtime proof exist.

## Proof Boundary

Current proof:

- manifest parser tests for inline runtime metadata,
- Apple emitter tests for `nativeInline`, `openApp`, `queueOnly`, rejected
  main-app `dartExtensionInline`, and experimental Dart extension scaffold
  generation,
- Apple AppIntentsTesting emitter tests for live invocation scaffolds,
- Dart runtime bridge tests for extension request decoding, source attribution,
  deny-by-default authorization, and allowed registry invocation,
- local Swift typecheck of generated-style typed AppIntent and
  AppIntentsTesting UI-test snippets against Xcode beta 27 SDKs,
- Steward adapter-contract scenario once validation passes.

Still not claimed:

- completed live macOS or iOS system invocation in a real Flutter app,
- automatic App Intents extension target generation,
- proven Flutter/Dart boot inside an App Intents extension,
- plugin compatibility inside extensions,
- production permission UX for native inline handlers.

## Official References

- Apple App Intents:
  [AppIntent](https://developer.apple.com/documentation/appintents/appintent),
  [ReturnsValue](https://developer.apple.com/documentation/appintents/returnsvalue),
  [IntentResult.result(value:dialog:)](https://developer.apple.com/documentation/appintents/intentresult/result(value:dialog:)),
  [supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes),
  [openAppWhenRun](https://developer.apple.com/documentation/appintents/appintent/openappwhenrun),
  [AppIntentsExtension](https://developer.apple.com/documentation/appintents/appintentsextension),
  [IntentExecutionTargets](https://developer.apple.com/documentation/appintents/intentexecutiontargets).
- Apple App Intents testing:
  [AppIntentsTesting](https://developer.apple.com/documentation/appintentstesting),
  [Testing your App Intents code](https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code),
  [AnyAppIntent.run()](https://developer.apple.com/documentation/appintentstesting/anyappintent/run()).
- Flutter host/runtime and extension constraints:
  [Add a Flutter screen to an iOS app](https://docs.flutter.dev/add-to-app/ios/add-flutter-screen),
  [iOS app extensions](https://docs.flutter.dev/platform-integration/ios/app-extensions).
- Android native semantic target:
  [Android App Functions](https://developer.android.com/ai/appfunctions).
- Windows native semantic and fallback surfaces:
  [Windows App Actions URI launch](https://learn.microsoft.com/en-us/windows/ai/app-actions/actions-uri-launch),
  [URI activation](https://learn.microsoft.com/en-us/windows/apps/develop/launch/handle-uri-activation).
