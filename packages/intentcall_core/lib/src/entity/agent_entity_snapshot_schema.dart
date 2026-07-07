import 'agent_entity_property_descriptor.dart';
import 'agent_entity_property_role.dart';
import 'agent_entity_type_descriptor.dart';

Map<String, Object?> agentEntitySnapshotSchema(
  final AgentEntityTypeDescriptor descriptor,
) {
  final properties = <String, Object?>{
    descriptor.identifierName: const <String, Object?>{'type': 'string'},
  };
  for (final property in descriptor.properties) {
    properties[property.name] = <String, Object?>{
      'type': _jsonSchemaType(property.valueType),
      if (property.description.isNotEmpty) 'description': property.description,
      if (property.isDisplay) 'x-intentcall-display': true,
      if (property.isSearchable) 'x-intentcall-searchable': true,
      if (property.isIndexed) 'x-intentcall-indexed': true,
      if (property.privacy != null)
        'x-intentcall-privacy': property.privacy!.name,
      if (property.role != AgentEntityPropertyRole.none)
        'x-intentcall-role': property.role.name,
    };
  }
  return <String, Object?>{
    'type': 'object',
    'required': <String>[descriptor.identifierName],
    'properties': properties,
  };
}

String _jsonSchemaType(final AgentEntityPropertyValueType type) =>
    switch (type) {
      AgentEntityPropertyValueType.string => 'string',
      AgentEntityPropertyValueType.integer => 'integer',
      AgentEntityPropertyValueType.number => 'number',
      AgentEntityPropertyValueType.boolean => 'boolean',
      AgentEntityPropertyValueType.object => 'object',
      AgentEntityPropertyValueType.array => 'array',
    };
