import 'package:meta/meta.dart';

import '../naming/qualified_name.dart';
import 'agent_entity_property_descriptor.dart';

enum AgentEntityDeepLinkBehavior { unsupported, optional, required }

enum AgentEntityOpenBehavior { unsupported, supported, requiresDeepLink }

@immutable
final class AgentEntityTypeDescriptor {
  AgentEntityTypeDescriptor({
    required this.namespace,
    required this.name,
    required this.identifierName,
    this.displayName,
    final Iterable<AgentEntityPropertyDescriptor> properties = const [],
    this.privacy = AgentEntityPrivacy.private,
    this.deepLinkBehavior = AgentEntityDeepLinkBehavior.unsupported,
    this.openBehavior = AgentEntityOpenBehavior.unsupported,
  }) : properties = List<AgentEntityPropertyDescriptor>.unmodifiable(
         properties,
       ) {
    validateNamespace(namespace);
    validateBareName(name);
    _validateSnapshotFieldName(identifierName);
    final names = <String>{};
    for (final property in this.properties) {
      if (!names.add(property.name)) {
        throw ArgumentError('Duplicate entity property: ${property.name}');
      }
    }
  }

  final String namespace;
  final String name;
  final String identifierName;
  final String? displayName;
  final List<AgentEntityPropertyDescriptor> properties;
  final AgentEntityPrivacy privacy;
  final AgentEntityDeepLinkBehavior deepLinkBehavior;
  final AgentEntityOpenBehavior openBehavior;

  String get qualifiedName => qualifyName(namespace: namespace, name: name);

  Iterable<AgentEntityPropertyDescriptor> get displayProperties =>
      properties.where((final property) => property.isDisplay);

  Iterable<AgentEntityPropertyDescriptor> get searchableProperties =>
      properties.where((final property) => property.isSearchable);

  Iterable<AgentEntityPropertyDescriptor> get indexedProperties =>
      properties.where((final property) => property.isIndexed);
}

void _validateSnapshotFieldName(final String value) {
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value)) {
    throw ArgumentError('Invalid snapshot field name: $value');
  }
}
