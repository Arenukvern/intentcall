import 'agent_entity_property_descriptor.dart';
import 'agent_entity_property_role.dart';
import 'agent_entity_type_descriptor.dart';

final class AgentEntitySnapshotKeys {
  const AgentEntitySnapshotKeys({
    required this.idKey,
    required this.titleKey,
    required this.subtitleKey,
    required this.keywordsKey,
  });

  factory AgentEntitySnapshotKeys.fromDescriptor(
    final AgentEntityTypeDescriptor descriptor,
  ) {
    _validateUniqueRoles(descriptor.properties);

    final titleKey = _propertyNameWithRole(
          descriptor.properties,
          AgentEntityPropertyRole.title,
        ) ??
        _firstPropertyNameWhere(
          descriptor.properties,
          (final property) => property.isDisplay,
        ) ??
        'title';

    final subtitleKey = _propertyNameWithRole(
          descriptor.properties,
          AgentEntityPropertyRole.subtitle,
        ) ??
        _nthPropertyNameWhere(
          descriptor.properties,
          (final property) => property.isDisplay,
          1,
        ) ??
        _firstOrNull(
          descriptor.properties
              .where(
                (final property) =>
                    property.isSearchable && property.name != titleKey,
              )
              .map((final property) => property.name),
        ) ??
        'subtitle';

    final keywordsKey = _propertyNameWithRole(
          descriptor.properties,
          AgentEntityPropertyRole.keywords,
        ) ??
        _firstOrNull(
          descriptor.properties
              .where(
                (final property) =>
                    property.isSearchable &&
                    property.valueType == AgentEntityPropertyValueType.array,
              )
              .map((final property) => property.name),
        ) ??
        'keywords';

    return AgentEntitySnapshotKeys(
      idKey: descriptor.identifierName,
      titleKey: titleKey,
      subtitleKey: subtitleKey,
      keywordsKey: keywordsKey,
    );
  }

  final String idKey;
  final String titleKey;
  final String subtitleKey;
  final String keywordsKey;
}

void _validateUniqueRoles(
  final Iterable<AgentEntityPropertyDescriptor> properties,
) {
  for (final role in <AgentEntityPropertyRole>[
    AgentEntityPropertyRole.title,
    AgentEntityPropertyRole.subtitle,
    AgentEntityPropertyRole.keywords,
  ]) {
    final matches = properties
        .where((final property) => property.role == role)
        .toList();
    if (matches.length > 1) {
      throw ArgumentError(
        'Duplicate entity property role ${role.name}: '
        '${matches.map((final property) => property.name).join(', ')}',
      );
    }
  }
}

String? _propertyNameWithRole(
  final Iterable<AgentEntityPropertyDescriptor> properties,
  final AgentEntityPropertyRole role,
) {
  for (final property in properties) {
    if (property.role == role) {
      return property.name;
    }
  }
  return null;
}

String? _firstPropertyNameWhere(
  final Iterable<AgentEntityPropertyDescriptor> properties,
  final bool Function(AgentEntityPropertyDescriptor property) test,
) {
  for (final property in properties) {
    if (test(property)) {
      return property.name;
    }
  }
  return null;
}

String? _nthPropertyNameWhere(
  final Iterable<AgentEntityPropertyDescriptor> properties,
  final bool Function(AgentEntityPropertyDescriptor property) test,
  final int index,
) {
  var seen = 0;
  for (final property in properties) {
    if (!test(property)) {
      continue;
    }
    if (seen == index) {
      return property.name;
    }
    seen++;
  }
  return null;
}

String? _firstOrNull(final Iterable<String> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
}
