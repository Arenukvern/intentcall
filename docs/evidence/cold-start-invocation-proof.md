# Cold-Start Invocation Proof — Native Half

**Date:** 2026-08-22
**Status:** Native half proven locally; Dart cold-start half covered by host tests; full end-to-end (real Shortcuts/Siri launch of a signed app) remains a non-claim.

## What was proven

Ran `cold_start_native_half_probe.swift` (this directory) against the real
handoff semantics shared by the generated `IntentCallGenerated.swift` and the
federated plugin store:

| Assertion | Result |
|---|---|
| `enqueue` writes a pending row to the UserDefaults-backed store | PASS |
| Fallback URL shape (`mcpfluttertest://invoke/<qualified_name>`) matches what `IntentCallInvokeLinkListener.qualifiedNameFromUri` parses | PASS |
| First `takePendingInvocations()` returns exactly one row with id/qualifiedName/source round-tripped | PASS |
| Second take is empty — rows are cleared **before** Dart reports success (documented at-most-once semantics, ADR 0016) | PASS |

Run it:

```bash
xcrun swiftc -o /tmp/probe docs/evidence/cold_start_native_half_probe.swift && /tmp/probe
```

## What the Dart half already proves (repo tests)

- `intentcall_flutter_host_test.dart`: host drains pending native envelopes on
  `start()`, on injected resume wake, coalesces overlapping drains, enforces
  `IntentCallAuthorizationPolicy`, and reports denied invocations.
- `intentcall_invoke_link.dart` + test: `<scheme>://invoke/<name>` deep links
  trigger a drain via `app_links`.

## What is still NOT claimed

- A real OS Shortcuts/Siri invocation launching a **signed** app from cold.
- Exactly-once or durable delivery (store is at-most-once by design).
- Live AppIntentsTesting runtime proof.

The remaining gap to a full live claim: run the mcp_flutter showcase macOS app,
invoke `AppIntentcallBridgePingIntent` from Shortcuts while the app is not
running, and observe `intentcall pending invocation app_intentcall_bridge_ping:
true` in the drained log. That requires a signed build and manual execution —
tracked as the open end-to-end fixture.
