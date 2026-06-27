---
name: write-adapter
description: Guide to implementing a custom transport adapter, platform emitter, or native bridge wrapper for IntentCall. Use when an agent needs to publish registry-backed intents to a new protocol or platform surface.
license: MIT
type: developer
metadata:
  author: intentcall
  version: "1.0.0"
  category: intentcall
---

# Write a Custom Adapter in IntentCall

Learn how to connect the IntentCall registry to a target surface. Runtime
adapters execute `AgentRegistry` entries directly. Platform emitters generate
metadata or source artifacts. Native bridge wrappers should collect parameters,
authorize the source, and dispatch an invocation envelope back to Dart.

## 1. Implement AgentAdapter

All adapters must implement the `AgentAdapter` interface from `intentcall_core`.

```dart
import 'dart:async';
import 'package:intentcall_core/intentcall_core.dart';

class MyCustomAdapter implements AgentAdapter {
  MyCustomAdapter({required this.myTransportClient});

  final MyTransportClient myTransportClient;
  StreamSubscription<AgentRegistryEvent>? _subscription;

  @override
  String get id => 'my_custom_transport';

  @override
  bool get watchesRegistry => true;

  @override
  Future<void> attach(AgentRegistry registry) async {
    // 1. Publish all currently registered intents
    for (final entry in registry.listEntries()) {
      _publishIntent(registry, entry);
    }

    // 2. Listen to registry events to sync runtime registrations
    _subscription = registry.events.listen((event) {
      switch (event) {
        case IntentRegistered(:final qualifiedName):
          final intent = registry.get(qualifiedName);
          if (intent != null) {
            _publishIntent(
              registry,
              AgentRegistryEntry(
                key: qualifiedName,
                intent: intent,
              ),
            );
          }
        case IntentUnregistered(:final qualifiedName):
          _unpublishIntent(qualifiedName);
      }
    });
  }

  @override
  Future<void> detach() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _publishIntent(AgentRegistry registry, AgentRegistryEntry entry) {
    final descriptor = entry.descriptor;
    myTransportClient.registerTool(
      name: entry.key,
      description: descriptor.description,
      inputSchema: descriptor.inputSchema,
      handler: (arguments) async {
        // Delegate execution to the core registry
        final result = await registry.invoke(entry.key, arguments);
        return <String, Object?>{
          'ok': result.ok,
          'message': result.message,
          if (result.ok) ...result.data,
          if (!result.ok) 'code': result.code,
          if (!result.ok) 'details': result.details,
        };
      },
    );
  }

  void _unpublishIntent(String name) {
    myTransportClient.unregisterTool(name);
  }
}
```

---

## 2. Key Rules for Adapter Authors

1. **Keep it thin:** The adapter should only map protocol structures to and from the `AgentRegistry`. It should never implement domain logic or custom validations that differ from the core registry validation.
2. **Preserve registry keys:** Use `AgentRegistry.listEntries()` for adapter publication. `listDescriptors()` is compatibility sugar for display-only catalog reads and can lose override-key intent.
3. **Listen to Events:** If `watchesRegistry` is true, ensure you handle both `IntentRegistered` and `IntentUnregistered` events in real-time to support hot-sync environments such as WebMCP.
4. **Gate native/fallback sources:** Fallback invoke paths and native bridge wrappers should use `IntentCallAuthorizationPolicy`; plain deep links are untrusted unless generated wrappers or app allowlists mark the source as trusted. Production registrations should use explicit source/name allowlists or confirmation callbacks. `debugAllowAll()` is for local dogfood only: it opens while assertions are enabled and denies in compiled profile/release builds.
5. **Use Stable Wire Contracts:** Depend on `intentcall_schema` rather than `intentcall_core` for sharing data envelopes (`AgentResult` / `AgentCallEntry`) between packages.

---

## 3. After Changing an Adapter

Add or extend a contract test using `verifyNativeAdapterContract(...)` from
`intentcall_testing`. The canonical package entrypoint is
`packages/intentcall_testing/README.md`.

Then run:

```bash
steward benchmark --scenario intentcall.adapter-contract --json
```

For smaller local checks, start with:

```bash
steward probe --json --profile quick
```

---

## Related Documents

- [DESIGN_FAQ.mdx](../../docs/DESIGN_FAQ.mdx) — Adapter modularity details.
- [DX_FAQ.mdx](../../docs/DX_FAQ.mdx) — Sibling overrides and testing custom adapters.
- [intentcall_testing README](../../packages/intentcall_testing/README.md) — Contract-test entrypoint.
