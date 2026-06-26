> WARNING: Pre-release (0.2.x train) — Highly experimental. APIs may change without notice. Not for production. See the root PRE_RELEASE.md.

# intentcall_session

IntentCall runtime sessions for commandable tools and apps.

Use this package when a CLI, MCP server, app host, or agent tool needs to keep a
durable attachment to a live runtime before invoking IntentCall registry entries.
See `example/session_example.dart` for a complete runnable in-memory example.

This package owns reusable runtime persistence mechanics:

- session identity and persisted session state
- file-backed state storage, state locking, and safe writes
- lifecycle operations for start, attach, mark-used, and end
- invoking an `AgentRegistry` inside a resolved session
- JSON runtime snapshot storage, listing, loading, and diffing

It deliberately does not define a dynamic registry, command catalog, artifact
model, transport, Flutter VM connection, MCP server, or visual debugger. Those
belong to `intentcall_core` / `intentcall_schema` or to concrete adapters.

## Concepts

| Concept | Purpose |
|---|---|
| `IntentSessionManager` | Starts, attaches, marks-used, and ends sessions. |
| `IntentSessionConnector` | Runtime-specific connection adapter implemented by the host. |
| `StateStore` | File-backed persisted state with tolerant JSON reads. |
| `StateLockManager` | Cross-process lock around state reads and writes. |
| `SafeFileWriter` | Atomic-ish durable file writes used by `StateStore`. |
| `IntentSessionExecutor` | Attaches to a session, invokes an `AgentRegistry`, then updates usage time. |
| `IntentSnapshotStore` | Stores and diffs JSON runtime artifacts without executing commands. |

The connector is the only runtime-specific seam. Flutter MCP implements a
connector for VM service endpoints; another host can implement one for a device,
browser, daemon, simulator, or local service.

## Start a session

```dart
import 'package:intentcall_session/intentcall_session.dart';

final manager = IntentSessionManager(
  connector: myConnector,
  stateStore: StateStore(path: '.intentcall/session_state.json'),
);

await manager.load();
final result = await manager.startSession(
  const IntentSessionStartRequest(
    mode: IntentSessionConnectionMode.uri,
    uri: 'ws://127.0.0.1:8181/ws',
    sessionId: 'debug',
  ),
);
```

The connector is implemented by the host. A minimal connector only needs to
resolve an endpoint display string and report any target-selection diagnostics.
The package does not open sockets or know about Flutter, MCP, devices, browsers,
or daemons by itself.

## Invoke through a session

```dart
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_session/intentcall_session.dart';

final executor = IntentSessionExecutor(
  sessions: manager,
  registry: registry,
);

final result = await executor.invoke(
  sessionId: 'debug',
  qualifiedName: 'debug_select',
  arguments: const {'id': 'node-7'},
);
```

## Store JSON snapshots

```dart
final snapshots = IntentSnapshotStore(
  snapshotsDir: '.intentcall/snapshots',
);

await snapshots.saveSnapshot(
  id: 'before',
  snapshot: const {
    'id': 'before',
    'createdAt': '2026-06-22T00:00:00.000Z',
    'payload': {'selected': 'node-7'},
  },
);

final diff = await snapshots.diffSnapshots(fromId: 'before', toId: 'after');
```

Hosts own how snapshots are produced. For example, Flutter MCP has a command
snapshot service that executes its command catalog and stores the resulting JSON
through this package.

## Run the example

```bash
dart run packages/intentcall_session/example/session_example.dart
```

The example creates a fake connector, starts a persisted session, invokes an
`AgentRegistry` entry through that session, writes two JSON snapshots, and prints
a structural diff.

## Boundaries

`intentcall_session` is not a broker facade. A product broker can compose this
package with `intentcall_core`, `intentcall_schema`, an adapter such as
`intentcall_mcp`, and domain-specific artifact storage. Keep product policy in
that host; keep reusable session lifecycle here.
