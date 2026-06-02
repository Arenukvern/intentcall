---
name: write-adapter
description: Guide to implementing a custom transport/surface adapter for IntentCall (such as custom MCP or native Apple/Android emitters). Use when an agent needs to publish registry-backed intents to a new protocol or platform surface.
license: MIT
metadata:
  author: intentcall
  version: "1.0.0"
  category: intentcall
---

# Write a Custom Adapter in IntentCall

Learn how to write a custom adapter that connects the IntentCall registry to a target transport.

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
    for (final descriptor in registry.listDescriptors()) {
      _publishIntent(registry, descriptor);
    }

    // 2. Listen to registry events to sync runtime registrations
    _subscription = registry.events.listen((event) {
      switch (event) {
        case IntentRegistered(:final qualifiedName):
          final intent = registry.get(qualifiedName);
          if (intent != null) {
            _publishIntent(registry, intent.descriptor);
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

  void _publishIntent(AgentRegistry registry, AgentIntentDescriptor descriptor) {
    myTransportClient.registerTool(
      name: descriptor.qualifiedName,
      description: descriptor.description,
      inputSchema: descriptor.inputSchema,
      handler: (arguments) async {
        // Delegate execution to the core registry
        final result = await registry.invoke(descriptor.qualifiedName, arguments);
        return result.toMap(); // Or translate to transport result format
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
2. **Listen to Events:** If `watchesRegistry` is true, ensure you handle both `IntentRegistered` and `IntentUnregistered` events in real-time to support hot-sync environments (e.g. WebMCP).
3. **Use Stable Wire Contracts:** Depend on `intentcall_schema` rather than `intentcall_core` for sharing data envelopes (`AgentResult` / `AgentCallEntry`) between packages.

---

## Related Documents

- [DESIGN_FAQ.md](../../DESIGN_FAQ.md) — Adapter modularity details.
- [DX_FAQ.md](../../DX_FAQ.md) — Sibling overrides and testing custom adapters.
