> ⚠️ **Pre-release train** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_schema

[![pub package](https://img.shields.io/pub/v/intentcall_schema.svg?include_prereleases)](https://pub.dev/packages/intentcall_schema)
[![pub points](https://img.shields.io/pub/points/intentcall_schema.svg)](https://pub.dev/packages/intentcall_schema/score)
[![repository](https://img.shields.io/badge/repo-intentcall-blue)](https://github.com/Arenukvern/intentcall)

Transport-agnostic **wire contract** for IntentCall: result envelopes, argument validation, entity snapshots, and VM-service wire parsing. Pure Dart — no Flutter dependency.

Registry and invocation live in [`intentcall_core`](../intentcall_core). Adapters (`intentcall_mcp`, `intentcall_webmcp`, platform sync) translate between transports and these types.

```bash
dart pub add intentcall_schema
```

## Who this is for

| Audience | Use `intentcall_schema` when you need… |
|----------|--------------------------------------|
| **DX** (app authors, adapter authors) | Typed `AgentResult`, JSON Schema validation before `registry.invoke`, coercion from string-key wire maps |
| **AX** (agents, MCP clients, codegen) | Stable JSON shapes for tool outcomes, entity snapshots, and resource read arguments |

## Package map

| Module | Primary types | Role |
|--------|---------------|------|
| Results | `AgentResult`, `AgentArtifact` | Success/failure outcomes from any handler |
| Envelopes | `AgentResultEnvelope` | Versioned snapshot payloads for tools and resources |
| Arguments | `AgentArguments`, `InputSchema`, `AgentWireArgs` | Tool input maps and VM extension parsing |
| Validation | `validateAgainstSchema`, `coerceArgumentsForSchema` | JSON Schema subset check + wire coercion |
| Entities | `AgentEntityRef`, `AgentEntitySnapshot` | Indexable app objects for shortcuts, deep links, and agent context |
| Resources | `clientResourceReadInputSchema`, … | Default MCP dynamic-resource input schemas |

## Quick start

### Return a tool result

```dart
import 'package:intentcall_schema/intentcall_schema.dart';

AgentResult success() => AgentResult.success(
  message: 'Saved',
  data: {'id': 'note-42'},
);

AgentResult failure() => AgentResult.failure(
  code: 'not_found',
  message: 'Note does not exist.',
  details: {'id': 'note-42'},
);
```

### Validate and coerce arguments

VM service extensions and some transports deliver `Map<String, String>`. Coerce to schema types, then validate:

```dart
const schema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['count'],
  'properties': {
    'count': {'type': 'integer', 'minimum': 0},
    'label': {'type': 'string'},
  },
};

final wire = AgentWireArgs({'count': '3', 'label': 'demo'});
final args = coerceArgumentsForSchema(schema, wire.toAgentArguments());
validateAgainstSchema(schema, args);
// args == {'count': 3, 'label': 'demo'}
```

On failure, `validateAgainstSchema` throws [`AgentValidationException`](lib/src/agent_validation_exception.dart) with a human-readable `message` (safe to surface to agents).

### Snapshot envelope (tools and resources)

Use envelopes when the consumer needs a versioned JSON snapshot (MCP resources, inspector tools, codegen fixtures):

```dart
final result = AgentResultEnvelope.resourceEnvelope(
  resourceName: 'spark_runtime_snapshot',
  snapshot: {'phase': 'playing'},
);
// result.data['resource_uri'] == 'intentcall://resource/spark/runtime/snapshot'
```

### Entity snapshots (agent-visible app state)

Entities are stable, JSON-safe records agents can search, open, or reference:

```dart
final snapshot = AgentEntitySnapshot(
  ref: const AgentEntityRef(
    namespace: 'notes',
    typeName: 'note',
    identifier: 'note-1',
  ),
  title: 'Inbox note',
  keywords: const ['work', 'today'],
  deepLink: 'intentcall://notes/note-1',
  properties: const {
    'pinned': true,
    'rank': 3,
    'tags': ['work', 'today'],
  },
);

final json = snapshot.toJson(); // round-trips via AgentEntitySnapshot.fromJson
```

`effectiveTitle` resolves `title ?? displayName` for display surfaces.

## JSON Schema subset

`validateAgainstSchema` implements a **deliberately small** JSON Schema subset aligned with MCP tool `inputSchema` usage:

| Feature | Supported |
|---------|-----------|
| Root `type: object` | Yes |
| `required`, `properties` | Yes |
| `additionalProperties: false` | Yes |
| Property types: `string`, `integer`, `number`, `boolean`, `object`, `array` | Yes |
| `enum` on strings | Yes |
| `minimum` / `maximum` on numbers | Yes |
| Array `items` when each item is `type: object` with `required` / `properties` | Yes |
| `pattern`, `format`, `oneOf`, nested object property validation (except array items) | No |
| Type coercion | Use `coerceArgumentsForSchema` first |

Properties without a `type` are skipped. Unknown keys are allowed unless `additionalProperties` is `false`.

## Wire types

```dart
typedef AgentArguments = Map<String, Object?>;
typedef InputSchema = Map<String, Object?>;
typedef AgentWireMap = Map<String, String>;
```

- **`AgentArguments`** — normalized tool invocation payload after coercion.
- **`InputSchema`** — JSON Schema–shaped map attached to tool/resource registrations.
- **`AgentWireArgs`** — extension type over `AgentWireMap` with `string`, `bool_`, `int_`, `double_`, `jsonObject`, and `toAgentArguments()`.

## Entity JSON shape (AX)

Agents and platform projection share this wire shape:

```yaml
ref:
  namespace: notes      # app domain, e.g. notes, music
  type_name: note       # entity kind within namespace
  identifier: note-1    # stable id within type
properties:             # JSON-safe scalars, lists, nested maps only
  pinned: true
  rank: 3
title: Inbox note       # optional display fields
keywords: [work, today]
deep_link: intentcall://notes/note-1
updated_at: 2026-06-29T12:00:00.000Z
deleted: false
version: rev-7
freshness: fresh
```

`DateTime`, custom classes, and non-finite doubles are rejected at construction time so snapshots stay JSON-encodable.

## Resource input schemas

For MCP dynamic client resources:

```dart
final schema = clientResourceReadInputSchema();
// { type: object, required: [uri], properties: { uri: { type: string } } }

final fromRegistration = inputSchemaFromDynamicRegistrationMap(registration);
```

Templates with variables (for example `count`) use `clientResourceTemplateReadInputSchema`.

## Where this sits in the stack

```
Author handler → AgentResult
       ↑
AgentRegistry.invoke ← validateAgainstSchema(coerceArgumentsForSchema(...))
       ↑
Adapter (MCP / WebMCP / platform) ← wire maps, entity snapshots
```

## Related packages

- [`intentcall_core`](../intentcall_core) — registry, `AgentCallEntry`, adapters composition
- [`intentcall_mcp`](../intentcall_mcp) — MCP `CallToolResult` mapping from `AgentResult`
- [`intentcall_platform`](../intentcall_platform) — Flutter entity index and native snapshot store
- [`intentcall_platform_sync`](../intentcall_platform_sync) — manifest projection and entity export

Canonical design docs: [North Star](../../docs/NORTH_STAR.mdx), [Design FAQ](../../docs/DESIGN_FAQ.mdx), and [DX FAQ](../../docs/DX_FAQ.mdx).

## API reference

Run `dart doc` in this package, or browse [pub.dev documentation](https://pub.dev/documentation/intentcall_schema/latest/) after publish.
