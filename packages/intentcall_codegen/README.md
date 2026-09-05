> ⚠️ **Pre-release train** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_codegen

[![pub package](https://img.shields.io/pub/v/intentcall_codegen.svg?include_prereleases)](https://pub.dev/packages/intentcall_codegen)
[![pub points](https://img.shields.io/pub/points/intentcall_codegen.svg)](https://pub.dev/packages/intentcall_codegen/score)
[![repository](https://img.shields.io/badge/repo-intentcall-blue)](https://github.com/Arenukvern/intentcall)

Optional `@AgentTool` / `@AgentParam` annotations and **build_runner** codegen pilot.

Hand-written `AgentCallEntry` remains first-class; codegen is opt-in for stable tools with typed parameters.

## Catalog mental model

```text
@AgentTool          →  tool implementation + (usually) catalog row
handwritten getter  →  tool implementation only
catalog row         →  @AgentCatalog list
agent_catalog.g.dart →  merge of all three sources
```

See [ADR 0021](../../docs/decisions/0021-agent-catalog-annotation.md).

## Wiring instance methods

When a tool handler needs host state (services, config, or UI policy), keep the
business logic on an instance method and expose an `AgentCallEntry` getter whose
handler closes over `this`. This matches the **mcp_flutter harness** pattern: one
shared host object, instance methods for behavior, catalog rows for projection.

1. **Host class with a shared singleton**

```dart
final class DemoHostTools {
  DemoHostTools();

  static final DemoHostTools shared = DemoHostTools();

  Future<AgentResult> inbox(final String folder) async { /* … */ }

  AgentCallEntry get inboxCallEntry => AgentCallEntry.tool(
    namespace: 'app',
    name: 'demo_inbox',
    description: 'Read inbox folder',
    inputSchema: const <String, Object?>{ /* … */ },
    handler: (final args) async => inbox(args['folder'] as String),
  );
}
```

2. **Merge catalog rows with `@AgentCatalog`**

Co-locate a top-level or **static** `List<AgentRegistryCatalogEntry>` with the host
class and annotate it with `@AgentCatalog`. The catalog builder discovers annotated
lists under `lib/` and spreads them into `lib/generated/agent_catalog.g.dart`
alongside `@AgentTool` rows. Static host lists merge as
`HostClass.catalogEntries`. Optional per-row projection uses `EntryProjection`
(same as `@AgentProjection` on annotated tools).

```dart
final class DemoHostTools {
  static final DemoHostTools shared = DemoHostTools();

  AgentCallEntry get inboxCallEntry => AgentCallEntry.tool(/* … */);

  @AgentCatalog()
  static final List<AgentRegistryCatalogEntry> demoHostCatalogEntries =
      <AgentRegistryCatalogEntry>[
    AgentRegistryCatalogEntry(
      registryKey: 'app_demo_inbox',
      entry: shared.inboxCallEntry,
      projection: const EntryProjection(
        surfaces: {AgentManifestSurface.webMcp: true},
      ),
    ),
  ];
}
```

After `dart run build_runner build`, `lib/generated/agent_catalog.g.dart`
spreads `@AgentCatalog` lists next to `@AgentTool` rows discovered from generated
`*.g.dart` parts. Duplicate `registryKey` values between codegen and
`@AgentCatalog` rows fail the build.

3. **Export manifest and register at runtime**

```bash
dart run build_runner build --delete-conflicting-outputs
dart run intentcall_cli:intentcall manifest export --check
```

Register from the merged catalog in app setup, or invoke by `registryKey`.

### Probe anchor for manifest export

`intentcall manifest export` evaluates each catalog row's `entry:` expression in a
subprocess (`resolveDescriptor()`). Use a **compile-time anchor** such as
`Host.shared.<getter>CallEntry` or a top-level `*CallEntry` getter — not a
per-request or widget-scoped instance. The probe needs descriptor metadata only;
your runtime registry may bind a different live instance as long as
`qualifiedName` and schema stay aligned.

`static shared` is **optional**. When absent, instance `@AgentTool` catalog rows
use `descriptor:` (manifest metadata only); register extension getters from your
live host at bootstrap. When present, catalog may use `entry: Host.shared.*` for
one-line `registerAll` demos.

### Handwritten projection

Use inline `EntryProjection` on `@AgentCatalog` rows (recommended for small hosts):

```dart
AgentRegistryCatalogEntry(
  registryKey: 'app_demo_inbox',
  entry: shared.inboxCallEntry,
  projection: const EntryProjection(
    surfaces: {AgentManifestSurface.webMcp: true},
  ),
),
```

For manifest-only rows without a handler at probe time, use `descriptor:` on
`AgentRegistryCatalogEntry` and register the handler separately at runtime.

### `@AgentCatalog` placement

| Placement | Spread in `agent_catalog.g.dart` |
|-----------|----------------------------------|
| Static field on host (recommended) | `...HostClass.catalogEntries` |
| Top-level list | `...catalogEntries` |
| Instance field | Not supported |

Do not list tools in `@AgentCatalog` when `@AgentTool` already emits their catalog
row (duplicate `registryKey` fails the build).

Full runnable example:
[`example/lib/tools/demo_host_tools.dart`](example/lib/tools/demo_host_tools.dart).

### Catalog builder options

Configure `intentcall_codegen|agent_catalog` in `build.yaml`:

```yaml
targets:
  $default:
    builders:
      intentcall_codegen|agent_catalog:
        options:
          tool_part_globs: [lib/**.g.dart]   # @AgentTool via agent_tool parts
          tool_globs: [lib/**.dart]          # @AgentCatalog scan only
          tool_exclude_globs: [lib/**.g.dart, lib/generated/**]
          host_binding_field: shared         # optional static probe anchor name
```

- **`tool_part_globs`** — catalog rows come from generated parts, not raw `@AgentTool` sources.
- **`tool_globs` / `tool_exclude_globs`** — scope `@AgentCatalog` discovery only.
- **`lib/src/`** — not hard-excluded; tools under `lib/src/` join the catalog when `agent_tool` emits their `.g.dart`.

See [`example/build.yaml`](example/build.yaml) for a commented template.

## Pilot usage

1. Add dependencies from the current hosted train:

```bash
dart pub add intentcall_core intentcall_schema intentcall_codegen
dart pub add --dev build_runner
```

2. Annotate a top-level function:

```dart
import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'my_tools.g.dart';

@AgentTool(namespace: 'app', name: 'demo_ping', description: 'Ping')
Future<AgentResult> demoPing(@AgentParam('Message') String message) async {
  return AgentResult.success(data: {'pong': message});
}
```

3. Run codegen:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This emits `lib/generated/agent_catalog.g.dart` (all `@AgentTool` registrations)
and per-file `*.g.dart` part files.

4. Export the platform manifest (host project with `intentcall.yaml`):

```bash
dart run intentcall_cli:intentcall manifest export --check
```

5. Register generated intents:

```dart
registry.register(demoPingRegistration);
// or
registerAll(registry, {demoPingCallEntry});
```

## Runnable example

See [`example/`](example/) for a self-contained Dart host (`lib/tools/`,
`lib/generated/agent_catalog.g.dart`, `web/agent_manifest.json`):

```bash
cd example
dart pub get
dart run build_runner build
dart run intentcall_cli:intentcall manifest export --check --project-dir .
```

The library package root intentionally has **no** committed catalog or manifest —
only annotations and builders.

## Generated output

For each top-level `@AgentTool` function, `.g.dart` emits:

- `_<name>InputSchema` — JSON Schema from parameter types
- `<name>CallEntry` — top-level `AgentCallEntry.tool(...)` factory
- `<name>Registration` — `RegisteredAgentIntent` via `.toRegistration()`

For each instance `@AgentTool` method on a host class, `.g.dart` emits:

- `_<name>InputSchema` constants
- `extension <Host>AgentCodegen on <Host>` with `<name>CallEntry` getters whose
  handlers call instance methods on `this`
- optional top-level `<name>Registration` aliases when a static binding field
  (default `shared`) exists

The aggregate catalog references instance rows as `Host.shared.<name>CallEntry`
when a binding static exists, otherwise `descriptor:` metadata only.

`@AgentProjection` uses typed `AgentManifestSurface` keys:

```dart
@AgentProjection(surfaces: {AgentManifestSurface.webMcp: true})
```

Supported parameter types: `String`, `int`, `bool`, `double`.

`host_binding_field` (see **Catalog builder options**) overrides the default
`shared` static field name used for optional catalog probe anchors.

`platforms.enabled` in `intentcall.yaml` scopes default manifest surface families
(see [ADR 0020](../../docs/decisions/0020-platform-scoped-manifest-surfaces.md)).

## Scope (pilot)

- Top-level `@AgentTool` functions and optional instance-method codegen on host
  classes (see **Wiring instance methods**); handwritten `AgentCallEntry` getters
  remain the canonical path for host-bound tools
- Tool kind only (resources: hand-write `AgentCallEntry.resource`)
- Test fixtures: `test/fixtures/demo_ping_tool.dart`, `test/fixtures/host_instance_tool.dart`

See [DX FAQ](../../docs/DX_FAQ.mdx) for current codegen workflow and [Design FAQ](../../docs/DESIGN_FAQ.mdx) for the IntentPack direction.
