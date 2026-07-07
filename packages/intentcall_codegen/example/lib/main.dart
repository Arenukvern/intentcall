import 'package:intentcall_core/intentcall_core.dart';

import 'entity_snapshot_seed.dart';
import 'generated/agent_catalog.g.dart';
import 'tools/demo_host_tools.dart';

/// Smoke harness for catalog → registry wiring in the example app.
///
/// Catalog sources (see `@AgentCatalog` in `demo_host_tools.dart` and `docs/DX_FAQ.mdx`):
///
/// ```text
/// @AgentTool          →  tool implementation + (usually) catalog row
/// @AgentEntity         →  entity type descriptor + EntityFields constants
/// handwritten getter  →  tool implementation only
/// catalog row         →  @AgentCatalog list
/// agent_catalog.g.dart →  merge of all three sources
/// ```
///
/// Build time and runtime serve different jobs:
///
/// - **Build / manifest export** — `AgentCatalogGenerator` merges rows into
///   [agentCatalogEntries]. For `@AgentTool` on instance methods it needs a
///   compile-time probe anchor, defaulting to `Host.shared.<getter>CallEntry`
///   (here `DemoHostTools.shared.demoHostStatusCallEntry`).
/// - **Runtime** — the app may register a different live host instance when
///   descriptors match (DI container, per-session state, tests).
Future<void> main() async {
  final registry = InMemoryAgentRegistry();

  // Live host for runtime registration. Not the same object as
  // [DemoHostTools.shared], which exists only as the catalog probe anchor.
  final liveHost = DemoHostTools();

  // Bulk-register every row from the generated catalog except one override
  // (see below). Rows come from @AgentTool codegen, @AgentCatalog spreads,
  // and their merged projection metadata.
  for (final row in agentCatalogEntries) {
    // Skip `app_demo_host_status`: the generated catalog binds that row to
    // [DemoHostTools.shared] so manifest export can resolve descriptors at
    // build time. We re-register the same qualified name from [liveHost]
    // immediately after this loop to demonstrate instance-bound runtime wiring.
    if (row.registryKey == 'app_demo_host_status') {
      continue;
    }
    final entry = row.entry;
    if (entry != null) {
      registry.register(entry.toRegistration());
    }
  }

  // Runtime override: same registry key and descriptor as the catalog row, but
  // handler closes over [liveHost] so invocation runs on this instance.
  registry.register(liveHost.demoHostStatusCallEntry.toRegistration());

  // Handwritten instance-bound tool registered via @AgentCatalog on
  // [DemoHostTools.demoHostCatalogEntries] (no skip/re-register needed).
  final inbox = await registry.invoke('app_demo_inbox', {'folder': 'inbox'});
  if (!inbox.ok) {
    throw StateError('demo_inbox smoke failed: ${inbox.message}');
  }

  final handwritten = await registry.invoke('app_demo_handwritten', {
    'note': 'hello',
  });
  if (!handwritten.ok) {
    throw StateError('demo_handwritten smoke failed: ${handwritten.message}');
  }

  // Codegen @AgentTool on an instance method — proves [liveHost], not
  // [DemoHostTools.shared], handled the call after the runtime override above.
  final hostStatus = await registry.invoke('app_demo_host_status', {
    'label': 'primary',
  });
  if (!hostStatus.ok) {
    throw StateError('demo_host_status smoke failed: ${hostStatus.message}');
  }
  if (hostStatus.data['source'] != 'codegen_instance') {
    throw StateError(
      'demo_host_status smoke failed: expected codegen_instance source',
    );
  }

  for (final descriptor in agentEntityTypeDescriptors) {
    registry.registerEntityType(descriptor);
  }
  if (agentEntityTypeDescriptors.isNotEmpty) {
    final row = demoProjectSnapshotRow();
    if (row['projectId'] != 'project-1') {
      throw StateError('entity smoke failed: expected projectId project-1');
    }
    if (row['name'] != 'Codegen project') {
      throw StateError(
        'entity smoke failed: expected descriptor title key name',
      );
    }
    if (row['summary'] != 'Entity snapshot seed') {
      throw StateError(
        'entity smoke failed: expected descriptor subtitle key summary',
      );
    }
    final tags = row['tags'];
    if (tags is! List ||
        tags.length != 2 ||
        tags[0] != 'demo' ||
        tags[1] != 'codegen') {
      throw StateError(
        'entity smoke failed: expected descriptor keywords tags',
      );
    }
  }
}
