---
name: register-intents
description: Guide to registering tool and resource intents in an IntentCall application, either manually or using `@AgentTool` code generation. Use when an agent needs to expose a Dart/Flutter function or resource endpoint to transport adapters.
license: MIT
type: developer
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
import 'package:intentcall_schema/intentcall_schema.dart';

void main() {
  final registry = InMemoryAgentRegistry();

  registry.register(
    AgentCallEntry.tool(
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
        return AgentResult.success(data: <String, Object?>{'reply': message});
      },
    ).toRegistration(),
  );
}
```

---

## 2. Code Generation (`@AgentTool`)

We can automate registration using the code generator package `intentcall_codegen`.

### Step 1: Add dependencies
Add IntentCall packages from the current hosted train:

```bash
dart pub add intentcall_core intentcall_schema
dart pub add --dev intentcall_codegen build_runner
```

### Step 2: Annotate your tool
Create your tool definition and annotate it with `@AgentTool`:

```dart
import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'ping_tool.g.dart';

@AgentTool(
  name: 'ping',
  description: 'Ping the local agent surface.',
)
Future<AgentResult> pingTool(
  @AgentParam('Test message.') String message,
) async {
  return AgentResult.success(data: <String, Object?>{'reply': message});
}
```

### Step 3: Run the builder
Run the build command to generate the code mapping:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 4: Register generated tools
The generator creates a `pingToolRegistration` mapping. Register it in your application setup:

```dart
import 'package:intentcall_core/intentcall_core.dart';
import 'ping_tool.dart';

void main() {
  final registry = InMemoryAgentRegistry()..register(pingToolRegistration);
}
```

Transport adapters, WebMCP, and native bridge wrappers should execute this Dart
registry entry rather than copying the business logic into JS, Swift, Kotlin, or
another host language.

---

## 3. After Changing Registrations

Run the package tests that cover the registered handler. When changing this
repository rather than only a downstream app, also run:

```bash
steward probe --json --profile quick
```

If the registration is consumed by a new or changed adapter, add or update the
adapter contract test and run:

```bash
steward benchmark --scenario intentcall.adapter-contract --json
```

---

## Related Documents

- [DESIGN_FAQ.mdx](../../docs/DESIGN_FAQ.mdx) — Why IntentCall is designed this way.
- [DX_FAQ.mdx](../../docs/DX_FAQ.mdx) — General workflow and CLI commands.
