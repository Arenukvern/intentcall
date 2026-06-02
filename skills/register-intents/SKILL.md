---
name: register-intents
description: Guide to registering tool and resource intents in an IntentCall application, either manually or using `@AgentTool` code generation. Use when an agent needs to expose a Dart/Flutter function or resource endpoint to transport adapters.
license: MIT
metadata:
  author: intentcall
  version: "1.0.0"
  category: intentcall
---

# Register Intents in IntentCall

Learn how to register tool and resource intents in an application using IntentCall.

## 1. Manual Registration

Manual registration uses the `AgentRegistry` and `AgentCallEntry` classes from `intentcall_core`.

```dart
import 'package:intentcall_core/intentcall_core.dart';

void main() {
  final registry = AgentRegistry.instance;

  registry.register(
    AgentCallEntry(
      namespace: 'custom',
      name: 'ping',
      description: 'Ping the local agent surface.',
      inputSchema: const <String, Object?>{
        'type': 'object',
        'properties': {
          'message': {'type': 'string', 'description': 'Optional test message.'}
        }
      },
      handler: (arguments) async {
        final message = arguments['message'] as String? ?? 'pong';
        return AgentResult.success(<String, Object?>{'reply': message});
      },
    ),
  );
}
```

---

## 2. Code Generation (`@AgentTool`)

We can automate registration using the code generator package `intentcall_codegen`.

### Step 1: Add dependencies
Add `intentcall_codegen` to your `dev_dependencies` in `pubspec.yaml`:

```yaml
dependencies:
  intentcall_core: ^0.1.0

dev_dependencies:
  intentcall_codegen: ^0.1.0
  build_runner: ^2.4.0
```

### Step 2: Annotate your tool
Create your tool definition and annotate it with `@AgentTool`:

```dart
import 'package:intentcall_core/intentcall_core.dart';

part 'ping_tool.g.dart';

@AgentTool(
  name: 'ping',
  description: 'Ping the local agent surface.',
)
Future<AgentResult> pingTool(String? message) async {
  return AgentResult.success(<String, Object?>{'reply': message ?? 'pong'});
}
```

### Step 3: Run the builder
Run the build command to generate the code mapping:

```bash
just build-runner
# or: dart run build_runner build --delete-conflicting-outputs
```

### Step 4: Register generated tools
The generator creates a `pingToolRegistration` mapping. Register it in your application setup:

```dart
import 'package:intentcall_core/intentcall_core.dart';
import 'ping_tool.dart';

void main() {
  AgentRegistry.instance.register(pingToolRegistration);
}
```

---

## Related Documents

- [DESIGN_FAQ.md](../../DESIGN_FAQ.md) — Why IntentCall is designed this way.
- [DX_FAQ.md](../../DX_FAQ.md) — General workflow and CLI commands.
