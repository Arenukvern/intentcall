> ⚠️ **Pre-release train** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_testing

Contract and invoke helpers for IntentCall adapters, `AgentCallEntry`, and
registry envelopes.

Use this package when a new adapter needs to prove it publishes current registry
entries, watches registry changes where supported, preserves registry keys, and
routes calls back through `AgentRegistry.invoke(...)`.

## Adapter Contract

Add `intentcall_testing` as a `dev_dependency`, then call
`verifyNativeAdapterContract(...)` from the adapter package test suite.

```dart
import 'package:intentcall_testing/intentcall_testing.dart';
import 'package:test/test.dart';

void main() {
  test('MyAdapter satisfies the shared native contract', () async {
    await verifyNativeAdapterContract(
      attach: (registry, transport) async {
        final adapter = MyAdapter(registry: registry, transport: transport);
        await adapter.attach();
        return adapter.detach;
      },
    );
  });
}
```

The reference shape lives in
`packages/intentcall_mcp/test/mcp_adapter_contract_test.dart`.

## Validation

From the repository root:

```bash
steward benchmark --scenario intentcall.adapter-contract --json
```

This benchmark runs workspace validation and the adapter/platform contract lane.
It is the preferred proof surface before claiming a new adapter satisfies the
shared IntentCall contract.
