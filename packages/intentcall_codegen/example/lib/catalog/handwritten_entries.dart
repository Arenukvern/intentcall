import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

import '../tools/demo_host_tools.dart';

final List<AgentRegistryCatalogEntry> handwrittenCatalogEntries =
    <AgentRegistryCatalogEntry>[
  AgentRegistryCatalogEntry(
    registryKey: 'app_demo_inbox',
    entry: DemoHostTools.shared.inboxCallEntry,
    projection: const EntryProjection(
      surfaces: {AgentManifestSurface.webMcp: true},
    ),
  ),
  AgentRegistryCatalogEntry(
    registryKey: 'app_demo_handwritten',
    entry: DemoHostTools.shared.demoHandwrittenCallEntry,
  ),
];
