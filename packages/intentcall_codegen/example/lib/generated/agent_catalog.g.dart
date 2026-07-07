// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import '../tools/demo_host_tools.dart';
import '../tools/demo_ping_tool.dart';

final List<AgentRegistryCatalogEntry> agentCatalogEntries =
    <AgentRegistryCatalogEntry>[
  AgentRegistryCatalogEntry(registryKey: 'app_demo_host_status', entry: DemoHostTools.shared.demoHostStatusCallEntry, projection: EntryProjection(
  dispatchMode: AgentManifestDispatchMode.openApp,
  surfaces: <AgentManifestSurface, bool>{AgentManifestSurface.webMcp: true},
)),
  AgentRegistryCatalogEntry(registryKey: 'app_demo_ping', entry: demoPingCallEntry),
  AgentRegistryCatalogEntry(registryKey: 'app_demo_cart', entry: demoCartCallEntry, projection: EntryProjection(
  dispatchMode: AgentManifestDispatchMode.openApp,
  surfaces: <AgentManifestSurface, bool>{AgentManifestSurface.webMcp: false},
)),
  AgentRegistryCatalogEntry(registryKey: 'app_demo_required_named', entry: demoRequiredNamedCallEntry),
  ...DemoHostTools.demoHostCatalogEntries,
];

abstract final class AppProjectEntityFields {
  static const String name = 'name';
  static const String summary = 'summary';
  static const String tags = 'tags';
}

final List<AgentEntityTypeDescriptor> agentEntityTypeDescriptors =
    <AgentEntityTypeDescriptor>[
  AgentEntityTypeDescriptor(
    namespace: 'app',
    name: 'project',
    identifierName: 'projectId',
    displayName: 'Project',
    properties: <AgentEntityPropertyDescriptor>[
      AgentEntityPropertyDescriptor(
        name: 'name',
        valueType: AgentEntityPropertyValueType.string,
        description: 'Display name',
        isDisplay: true,
        isSearchable: false,
        isIndexed: false,
        role: AgentEntityPropertyRole.title,
      ),
      AgentEntityPropertyDescriptor(
        name: 'summary',
        valueType: AgentEntityPropertyValueType.string,
        description: 'Searchable summary',
        isDisplay: false,
        isSearchable: true,
        isIndexed: false,
        role: AgentEntityPropertyRole.subtitle,
      ),
      AgentEntityPropertyDescriptor(
        name: 'tags',
        valueType: AgentEntityPropertyValueType.array,
        description: 'Search keywords',
        isDisplay: false,
        isSearchable: true,
        isIndexed: false,
        role: AgentEntityPropertyRole.keywords,
      )
    ],
    privacy: AgentEntityPrivacy.private,
    deepLinkBehavior: AgentEntityDeepLinkBehavior.unsupported,
    openBehavior: AgentEntityOpenBehavior.unsupported,
  ),
];
