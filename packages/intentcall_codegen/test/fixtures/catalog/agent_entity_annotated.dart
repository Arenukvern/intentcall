import 'package:intentcall_codegen/intentcall_codegen.dart';

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
  ],
)
final class AppProjectEntityDescriptor {}
