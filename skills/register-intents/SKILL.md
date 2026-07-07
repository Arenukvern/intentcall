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

## 2. Instance-bound tools and catalog merge

Use this when a handler needs host state but you are not using `@AgentTool`
codegen for that tool (dynamic hosts, instance services, or tools that must close
over `this`).

**Pattern (same as the mcp_flutter harness):**

1. Put behavior on a host class (optional `static final shared` for probe anchors).
2. Expose each intent as an instance `AgentCallEntry` getter; the handler calls
   instance methods on `this`.
3. Optionally co-locate `EntryProjection` consts on the host (see **Handwritten projection** below).
4. Co-locate a `List<AgentRegistryCatalogEntry>` annotated with **`@AgentCatalog`**
   (discovered via `tool_globs`).
5. Run `build_runner` so `lib/generated/agent_catalog.g.dart` merges `@AgentTool`
   rows (from `tool_part_globs` / generated `.g.dart` parts) and `@AgentCatalog` spreads.

```dart
final class InboxHost {
  InboxHost();
  static final InboxHost shared = InboxHost();

  Future<AgentResult> readInbox(final String folder) async { /* … */ }

  AgentCallEntry get readInboxCallEntry => AgentCallEntry.tool(
    namespace: 'app',
    name: 'read_inbox',
    description: 'Read inbox folder',
    inputSchema: const <String, Object?>{ /* … */ },
    handler: (final args) async => readInbox(args['folder'] as String),
  );
}
```

```dart
// Co-located with InboxHost (same file or sibling module file)
@AgentCatalog()
final List<AgentRegistryCatalogEntry> inboxHostCatalogEntries =
    <AgentRegistryCatalogEntry>[
  AgentRegistryCatalogEntry(
    registryKey: 'app_read_inbox',
    entry: InboxHost.shared.readInboxCallEntry,
  ),
];
```

Reference implementation:
[`packages/intentcall_codegen/example/lib/tools/demo_host_tools.dart`](../../packages/intentcall_codegen/example/lib/tools/demo_host_tools.dart).

Then run `intentcall manifest export --check` so committed
`agent_manifest.json` stays in sync with the merged catalog (see
[ADR 0019](../../docs/decisions/0019-framework-neutral-intentcall-cli.md)).

**Probe anchor (optional):** When `static shared` exists, catalog rows may use
`InboxHost.shared.readInboxCallEntry` — manifest export evaluates `entry:` in a
subprocess and strips handlers. **Live instance registration is canonical** for
stateful hosts: construct the host and register `liveHost.readInboxCallEntry`
at bootstrap even when catalog uses `shared` for probe convenience.

**Descriptor-only rows:** Use `descriptor:` on `AgentRegistryCatalogEntry` when
manifest metadata is needed without a probe-time handler; register handlers from
a live host at runtime and keep `qualifiedName` aligned.

**Handwritten projection:** Co-locate surface hints on the host class and
reference them from catalog rows:

```dart
static const inboxProjection = EntryProjection(
  surfaces: {AgentManifestSurface.webMcp: true},
);

AgentRegistryCatalogEntry(
  registryKey: 'app_read_inbox',
  entry: InboxHost.shared.readInboxCallEntry,
  projection: InboxHost.inboxProjection,
),
```

`platforms.enabled` in `intentcall.yaml` scopes default manifest surface families
(web-only hosts omit android/windows/linux defaults unless overridden).

---

## 3. Code Generation (`@AgentTool`)

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

### Optional: instance-method codegen

For host-bound tools you may annotate instance methods instead of writing
getters by hand. Codegen emits an extension with `this`-bound `AgentCallEntry`
getters. When a static binding field exists (default name `shared`), catalog
rows use `entry: Host.shared.<getter>CallEntry` for probe convenience; otherwise
codegen emits `descriptor:`-only rows and you register from a live host instance.
Handwritten getters in section 2 remain the canonical path when you need full
control.

`@AgentProjection` uses typed `AgentManifestSurface` keys:

```dart
@AgentProjection(surfaces: {AgentManifestSurface.webMcp: true})
```

Apple sub-channels (Siri, Spotlight, etc.) use `AgentManifestSurfaceExposure.options`
on handwritten `EntryProjection` rows until emitters support them.

---

## 4. After Changing Registrations

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
