import 'package:intentcall_schema/intentcall_schema.dart';

import 'agent_entity_property_descriptor.dart';
import 'agent_entity_type_descriptor.dart';

/// Projects an app-owned entity snapshot into a platform-neutral cache row.
///
/// The returned row uses descriptor-derived keys for the entity identifier,
/// display, searchable, and indexed fields while preserving the stable legacy
/// keys consumed by existing platform caches.
Map<String, Object?> projectAgentEntitySnapshot(
  final AgentEntitySnapshot snapshot,
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
  final title = _fieldValue(snapshot, titleKey) ?? snapshot.effectiveTitle;
  final subtitle = _fieldValue(snapshot, subtitleKey) ?? snapshot.subtitle;
  final keywords =
      _fieldValue(snapshot, keywordsKey) ??
      (snapshot.keywords.isNotEmpty ? snapshot.keywords : null);

  final row = <String, Object?>{
    ...snapshot.properties,
    'id': snapshot.ref.identifier,
    if (descriptor.identifierName != 'id')
      descriptor.identifierName: snapshot.ref.identifier,
    if (titleKey != 'title' && snapshot.effectiveTitle != null)
      'title': snapshot.effectiveTitle,
    if (subtitleKey != 'subtitle' && snapshot.subtitle != null)
      'subtitle': snapshot.subtitle,
    if (keywordsKey != 'keywords' && snapshot.keywords.isNotEmpty)
      'keywords': snapshot.keywords,
    if (snapshot.thumbnailUrl != null) 'thumbnailUrl': snapshot.thumbnailUrl,
    if (snapshot.url != null) 'url': snapshot.url,
    if (snapshot.deepLink != null) 'deepLink': snapshot.deepLink,
    if (snapshot.updatedAt != null)
      'updatedAt': snapshot.updatedAt!.toUtc().toIso8601String(),
    if (snapshot.deleted) 'deleted': true,
    if (snapshot.version != null) 'version': snapshot.version,
    if (snapshot.freshness != null) 'freshness': snapshot.freshness,
    if (snapshot.properties.isNotEmpty) 'properties': snapshot.properties,
  };
  if (title != null) {
    row[titleKey] = title;
  }
  if (subtitle != null) {
    row[subtitleKey] = subtitle;
  }
  if (keywords != null) {
    row[keywordsKey] = keywords;
  }
  return row;
}

Object? _fieldValue(final AgentEntitySnapshot snapshot, final String key) {
  final value = snapshot.properties[key];
  return value;
}

String? _firstOrNull(final Iterable<String> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
}
