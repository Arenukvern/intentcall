# 0027. Agent-usable projection results

Date: 2026-09-22

## Status

Accepted. Amends [ADR 0015](0015-dart-first-native-bridge.md) and
[ADR 0016](0016-dispatch-mode-handoff-contract.md) for one result-bearing
dispatch mode. Does not supersede them.

## Context

MCP already gives an IDE or CLI agent `tools/list`, a JSON Schema, `tools/call`,
and an `AgentResult`. WebMCP, macOS App Intents, and Windows do not.

WebMCP registration reached `document.modelContext`, with
`navigator.modelContext` kept as a shim, but a failed handler returned
`{ok: false}` as a resolved tool result. The 2026 imperative API registers with
an `AbortSignal` and treats a rejected `execute` promise as the tool failure.
The static JS bootstrap could not replace a tool, and a missing
`modelContext` was indistinguishable from a successful registration.

Generated Apple App Intents for `openApp` and `queueOnly` enqueue a UserDefaults
row and return the dialog `Queued invocation <id>`. ADR 0015 recorded that as
dispatch status, not handler result. Shortcuts and Siri finish before Dart runs.
That is a valid wake path. It is not an agent tool call.

Windows projection is a `.reg` script and an MSIX `windows.protocol` fragment.
Microsoft's App Actions URI model is a different artifact: package identity,
`registration.json`, `ProtocolForResults`, and one Text result. Agent Launchers
are the inverse product: the app registers itself as an agent that receives a
prompt. They do not let an outside agent call the app's tools.

IDE coding agents speak MCP or ACP. They do not speak WebMCP, App Intents, or
Windows App Actions. Completing those projections serves the browser, Siri /
Shortcuts, and the Windows action runtime. It does not replace MCP, and it does
not make an unregistered Flutter app agent-callable.

## Decision

A projection is agent-usable only when the platform host can list the tool,
pass the manifest's primitive arguments, reach `AgentRegistry` under
`IntentCallAuthorizationPolicy`, and receive the handler output or a typed
failure. A queue id is not a result. The running app is the supported path.
Cold start either returns that result inside a 10 second bound or fails with
`runtime_unavailable`. It must not report success.

1. **WebMCP** stays `inlineRuntime`. Browser `execute` rejects when
   `AgentResult.ok` is false. Registration passes an `AbortSignal`, aborts the
   previous registration before replacing a name, and returns
   `WebMcpRegistrationReport` when `document.modelContext` is missing.
   `navigator.modelContext` remains a shim. Declarative form tools stay out.
2. **`dispatchMode: awaitApp`** is the Apple and Windows result mode.
   `openApp` and `queueOnly` keep today's handoff and stay labeled assistant
   launch, not agent-usable. `awaitApp` does not write the at-most-once
   UserDefaults queue. Generated Swift calls
   `IntentCallNativeBridge.invokeAwaiting`, which opens `scheme://wake` when a
   scheme exists (not `scheme://invoke/...`, so the deep-link listener does not
   run the tool twice) and waits up to 10 seconds for the Flutter host.
   The host answers with `AgentResult` JSON in the App Intents dialog.
   `nativeInline` and experimental `dartExtensionInline` are unchanged.
3. **Windows App Actions** are a new opt-in surface, `windows.appActions`.
   The emitter writes `registration.json` and an MSIX fragment for
   `com.microsoft.windows.ai.actions` plus `ReturnResults="always"`. Primitive
   fields become Text entities. Nested schemas fail the emit. The Text output
   `result` is `AgentResult` JSON, including failures, because URI launch
   completes the activation through `ReportCompleted`. Protocol `.reg` /
   `windows.protocol` artifacts stay fallback and are not this surface.
   Unpackaged `flutter run -d windows` cannot register actions. Live proof is
   an MSIX app on Windows 11 (SDK 10.0.26100 or newer).
4. **IDE agents** keep using MCP. ACP stays the workspace-only editor
   projection from ADR 0026. These OS surfaces are not an IDE tool protocol.

`awaitApp` and `windows.appActions` are opt-in. Existing manifests keep
`openApp` and do not gain the new surface.

## Consequences

Good:

- A browser agent can treat a failed WebMCP tool as a failed call.
- Siri and Shortcuts can observe the Dart handler outcome when the app is
  running, instead of a queue receipt.
- Windows gains an artifact that matches App Actions URI launch, separate from
  protocol fallback.
- `openApp` behavior for existing apps stays in place.

Tradeoffs:

- WebMCP rejection is a behavior change for generated JS. Callers that treated
  `{ok: false}` as success data must read the rejection `code` and `message`.
- `awaitApp` can hit the App Intents time limit. The supported claim narrows to
  "app already running" if a signed Shortcuts run exceeds it.
- If the intent runs outside the Flutter process, `invokeAwaiting` returns
  `runtime_unavailable` after the bound. It does not fall back to the queue.
- Windows URI completion is still `ReportCompleted`. The agent reads success or
  failure from the Text entity. There is no repo-hosted WinRT runner yet.
- Agent Launchers, declarative WebMCP forms, extension-hosted Dart, and
  automatic projection of apps that never register intents are out of scope.
- Live browser, Shortcuts, and packaged Windows proof stay in the consuming
  app. Emitter and contract tests do not move the platform-support row to
  live OS proof.

## Proof boundary

Repo tests cover the JS rejection and `AbortSignal`, the registration report on
the VM, `awaitApp` Swift shape, and App Actions JSON shape. They do not prove
Chrome, Shortcuts, or the Windows action runtime.

## References

- [WebMCP](https://github.com/webmachinelearning/webmcp) imperative
  `document.modelContext.registerTool` (Community Group draft).
- [Windows App Actions URI launch](https://learn.microsoft.com/en-us/windows/ai/app-actions/actions-uri-launch).
- [ADR 0012](0012-adopt-platform-support-tiers.md),
  [ADR 0015](0015-dart-first-native-bridge.md),
  [ADR 0016](0016-dispatch-mode-handoff-contract.md).
