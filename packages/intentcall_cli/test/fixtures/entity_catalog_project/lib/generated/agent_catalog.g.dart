// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

abstract final class AppProjectEntityFields {
  static const String name = 'name';
  static const String summary = 'summary';
}

final List<AgentRegistryCatalogEntry> agentCatalogEntries =
    <AgentRegistryCatalogEntry>[];

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
            role: AgentEntityPropertyRole.title,
          ),
          AgentEntityPropertyDescriptor(
            name: 'summary',
            valueType: AgentEntityPropertyValueType.string,
            description: 'Searchable summary',
            isSearchable: true,
            role: AgentEntityPropertyRole.subtitle,
          ),
        ],
        privacy: AgentEntityPrivacy.private,
        deepLinkBehavior: AgentEntityDeepLinkBehavior.unsupported,
        openBehavior: AgentEntityOpenBehavior.unsupported,
      ),
    ];
