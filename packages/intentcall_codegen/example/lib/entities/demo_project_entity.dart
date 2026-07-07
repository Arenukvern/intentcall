import 'package:intentcall_codegen/intentcall_codegen.dart';

/// Codegen-discovered entity type for manifest export and snapshot seed demos.
@AgentEntity(
  namespace: 'app',
  name: 'project',
  identifierName: 'projectId',
  displayName: 'Project',
  properties: [
    AgentEntityProperty(
      name: 'name',
      valueType: 'string',
      description: 'Display name',
      isDisplay: true,
      role: 'title',
    ),
    AgentEntityProperty(
      name: 'summary',
      valueType: 'string',
      description: 'Searchable summary',
      isSearchable: true,
      role: 'subtitle',
    ),
    AgentEntityProperty(
      name: 'tags',
      valueType: 'array',
      description: 'Search keywords',
      isSearchable: true,
      role: 'keywords',
    ),
  ],
)
final class DemoProjectEntity {}
