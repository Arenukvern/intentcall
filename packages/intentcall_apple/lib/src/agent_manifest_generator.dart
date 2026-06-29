import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';

/// Builds `agent_manifest.json` for App Intents / Shortcuts codegen (Phase 3).
String generateAppleAgentManifest(
  final Iterable<AgentIntentDescriptor> descriptors, {
  final Iterable<AgentEntityTypeDescriptor> entityTypeDescriptors = const [],
  final Iterable<Map<String, Object?>> entityTypes = const [],
}) {
  final intents = <Map<String, Object?>>[];
  for (final descriptor in descriptors) {
    intents.add(<String, Object?>{
      'qualifiedName': descriptor.qualifiedName,
      'namespace': descriptor.namespace,
      'name': descriptor.name,
      'description': descriptor.description,
      'kind': descriptor.kind.name,
      if (descriptor.kind == AgentIntentKind.resource)
        'resourceUri': descriptor.effectiveResourceUri,
      if (descriptor.mimeType != null) 'mimeType': descriptor.mimeType,
      'inputSchema': descriptor.inputSchema,
    });
  }
  final entities = <Map<String, Object?>>[
    ...entityTypeDescriptors.map(_entityTypeDescriptorManifest),
    ...entityTypes.map(Map<String, Object?>.from),
  ];
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'version': 1,
    'platform': 'apple',
    'intents': intents,
    if (entities.isNotEmpty) 'entityTypes': entities,
  });
}

Map<String, Object?> _entityTypeDescriptorManifest(
  final AgentEntityTypeDescriptor descriptor,
) {
  final displayProperties = descriptor.displayProperties.toList();
  final searchableProperties = descriptor.searchableProperties.toList();
  final titleKey = displayProperties.isNotEmpty
      ? displayProperties.first.name
      : 'title';
  final subtitleKey = displayProperties.length > 1
      ? displayProperties[1].name
      : _firstOrNull(
              searchableProperties
                  .where((final property) => property.name != titleKey)
                  .map((final property) => property.name),
            ) ??
            'subtitle';
  final keywordsKey =
      _firstOrNull(
        searchableProperties
            .where(
              (final property) =>
                  property.valueType == AgentEntityPropertyValueType.array,
            )
            .map((final property) => property.name),
      ) ??
      'keywords';
  return <String, Object?>{
    'qualifiedName': descriptor.qualifiedName,
    'namespace': descriptor.namespace,
    'name': descriptor.name,
    'displayName': descriptor.displayName ?? _humanizeName(descriptor.name),
    'idKey': descriptor.identifierName,
    'titleKey': titleKey,
    'subtitleKey': subtitleKey,
    'keywordsKey': keywordsKey,
    'snapshotSchema': _snapshotSchema(descriptor),
  };
}

Map<String, Object?> _snapshotSchema(
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
    };
  }
  return <String, Object?>{
    'type': 'object',
    'required': <String>[descriptor.identifierName],
    'properties': properties,
  };
}

String? _firstOrNull(final Iterable<String> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
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

String _humanizeName(final String name) {
  final parts = name
      .split(RegExp(r'[_\s-]+'))
      .where((final part) => part.trim().isNotEmpty);
  if (parts.isEmpty) {
    return name;
  }
  return parts
      .map((final part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
