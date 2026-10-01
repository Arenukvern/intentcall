import 'package:intentcall_core/intentcall_core.dart';

import 'generated/agent_catalog.g.dart';
import 'tools/demo_host_tools.dart';

/// Smoke harness for catalog → registry wiring in the example app.
///
/// Catalog sources (see `@AgentCatalog` in `demo_host_tools.dart` and `docs/DX_FAQ.mdx`):
///
/// ```text
/// @AgentTool          →  tool implementation + (usually) catalog row
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
///
/// **Apple discovery** — Siri and Shortcuts discover registry **verbs** via
/// `apple.appIntents` + opt-in `apple.appShortcuts` on tools such as
/// `app_demo_set_greeting`. Indexable **nouns** (`@AgentEntity`, Spotlight) are
/// dogfooded in the Flutter showcase, not this dart-only host:
/// `mcp_flutter/flutter_test_app`.
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

  final greeting = await registry.invoke('app_demo_set_greeting', {
    'text': 'hello codegen',
  });
  if (!greeting.ok) {
    throw StateError('demo_set_greeting smoke failed: ${greeting.message}');
  }
  if (greeting.data['greeting'] != 'hello codegen') {
    throw StateError('demo_set_greeting smoke failed: unexpected greeting');
  }
}
