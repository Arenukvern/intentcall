# 0015. Dart-first Native Bridge for Platform Surfaces

Date: 2026-06-26

## Status

Accepted

## Context

IntentCall's promise is that app authors define intent logic once in Dart and
project it into MCP, WebMCP, native platform metadata, shortcuts, and fallback
routes. The previous platform emitters could describe native surfaces, but they
risked implying that Swift, Kotlin, or JS should own semantic business logic.

Apple App Intents can collect typed parameters and wake the app, but stable
support for app-extension-hosted Dart execution requires separate proof:
app-group storage, Flutter engine bootstrap, plugin registration, extension
lifecycle behavior, and compatibility with Flutter's documented app-extension
constraints.

WebMCP similarly needs a first-class in-page Dart path so sites do not have to
ship a JS-first `/agent/invoke` endpoint by default.

## Decision

IntentCall v1 platform projection is Dart-first:

- `IntentCallInvocationEnvelope` is the shared native/WebMCP invocation unit.
- `IntentCallAuthorizationPolicy` gates source and intent-name access before
  dispatch. Empty/default policies deny all invocations.
- `IntentCallNativeBridge.bindRegistry(...)` executes authorized envelopes
  through the Dart `AgentRegistry`.
- `registerAgentWebMcpFromRegistry(...)` registers WebMCP tools from Dart and
  invokes Dart handlers in-page.
- WebMCP network fallback is opt-in only.
- Development builds may use `IntentCallAuthorizationPolicy.debugAllowAll()` to
  expose local dogfood tools while Dart assertions are enabled. Compiled
  profile/release builds must provide explicit source/name allowlists or
  confirmation callbacks.
- Generated Apple App Intents collect supported primitive parameters, enqueue
  an invocation envelope, open or wake the Flutter app, and return dispatch
  status. They do not claim background Dart execution or native semantic result
  execution in this pass.

## Consequences

Good:

- App authors keep business logic in Dart.
- Native wrappers stay thin and auditable.
- Fallback paths have explicit authorization hooks.
- Docs can truthfully distinguish metadata/dispatch support from native
  background execution.

Tradeoffs:

- Apple App Intents return dispatch status in v1, not the Dart handler result.
- Apps must drain pending native invocations after launch or wake.
- App-extension-hosted Dart remains an experiment until it has separate runtime
  proof and compatibility documentation.

## Future Experiment: App-extension-hosted Dart

Do not document app-extension-hosted Dart as supported until a separate proof
covers:

- app-group queue/storage semantics,
- Flutter engine startup inside an extension target,
- plugin registration and unavailable-API filtering,
- extension memory/time limits,
- result propagation back to App Intents,
- failure envelopes for stale, denied, unavailable, and unknown-intent states.
