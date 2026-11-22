# 0031. Service-extension wire encode

Date: 2026-11-23

## Status

Accepted for implementation.

## Context

Flutter's `BindingBase.registerServiceExtension` hands every service-extension callback a `Map<String, String>`: complex parameter values are flattened with `toString()`. An argument that left the sender as `{width: 2.0, color: 4294918846}` (Dart syntax, no quoting, no escaping) arrives at the app-side handler exactly that way — not JSON. Tool args declared `object` or `array` in their input schema could not round-trip:

- `coerceArgumentsForSchema` decoded object-typed strings with an unguarded JSON decode, so the Dart syntax threw `FormatException` out of coercion (surfacing as an invalid-command failure for a perfectly valid call).
- A list-typed string went through `_parseWireJsonList`, which called `jsonDecode` directly — same crash class.
- An open-object entry decoder passed the JSON codec constant instead of the string it was given, so that branch never decoded anything.
- The `agentInvoke` tier (`parameters['json']`) already worked, because one JSON-text parameter is a string and survives the flattening untouched.

The flattening itself is framework behavior and cannot be changed from these packages.

## Decision

The wire contract for complex argument values is **JSON text, encoded before the call**:

1. `intentcall_schema` owns both halves of the contract. Outbound: `wireArgumentsForServiceExtension` / `wireValueForServiceExtension` encode maps and lists to JSON text (strings pass through, `null` encodes to `''`, other scalars use their literal text). Inbound: `coerceArgumentsForSchema` decodes JSON first and, for senders that predate the contract, recovers Dart `toString()` shapes with a conservative parser (`tryDecodeDartMap` / `tryDecodeDartList`). The parser refuses anything it cannot attribute — undecodable text passes through unchanged so schema validation refuses it honestly; `FormatException` never escapes coercion.
2. Senders encode at their VM-service choke points: every extension call funnels through one method that applies the encode (server `ConnectionContext.callFlutterExtension` / `callServiceExtension`, harness `VmClient._callExtension`, toolkit's legacy `mcpToolkitTool` path).
3. The app side keeps `coerceArgumentsForSchema` as the single decode point. Tool handlers never parse wire text themselves.

## Consequences

- Tool arguments declared `object`/`array` round-trip exactly through the per-tool extension path, matching what `agentInvoke` already delivered.
- Old servers (pre-encode) still work against new apps through the Dart-literal recovery — lossy for values containing delimiters, which `toString()` genuinely loses.
- New servers against old apps encode to JSON text that old coercions already decode correctly, so the direction of rollout does not matter.
- Values that are neither JSON-safe nor Dart-literal-shaped still fail honestly at validation instead of crashing inside coercion.
