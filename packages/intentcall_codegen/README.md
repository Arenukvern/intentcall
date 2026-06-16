> ⚠️ **Pre-release (0.1.x)** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_codegen

Optional `@AgentTool` / `@AgentParam` annotations and **build_runner** codegen pilot.

Hand-written `AgentCallEntry` remains first-class; codegen is opt-in for stable tools with typed parameters.

## Pilot usage

1. Add dependency:

```yaml
dependencies:
  intentcall_codegen: ^0.1.0
  intentcall_core: ^0.1.0
  intentcall_schema: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.15
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

4. Register generated intent:

```dart
registry.register(demoPingRegistration);
// or
registerAll(registry, {demoPingCallEntry});
```

## Generated output

For each `@AgentTool` function, `.g.dart` emits:

- `_<name>InputSchema` — JSON Schema from parameter types
- `<name>CallEntry` — `AgentCallEntry.tool(...)` factory
- `<name>Registration` — `RegisteredAgentIntent` via `.toRegistration()`

Supported parameter types: `String`, `int`, `bool`, `double`.

## Scope (pilot)

- Top-level functions only
- Tool kind only (resources: hand-write `AgentCallEntry.resource`)
- Test fixture: `test/fixtures/demo_ping_tool.dart`

See [DX FAQ](../../docs/DX_FAQ.mdx) for current codegen workflow and [Design FAQ](../../docs/DESIGN_FAQ.mdx) for the IntentPack direction.
