import 'package:intentcall_schema/intentcall_schema.dart';

import 'agent_entity_snapshot_keys.dart';
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
  final keys = AgentEntitySnapshotKeys.fromDescriptor(descriptor);
  final title = _fieldValue(snapshot, keys.titleKey) ?? snapshot.effectiveTitle;
  final subtitle =
      _fieldValue(snapshot, keys.subtitleKey) ?? snapshot.subtitle;
  final keywords =
      _fieldValue(snapshot, keys.keywordsKey) ??
      (snapshot.keywords.isNotEmpty ? snapshot.keywords : null);

  final row = <String, Object?>{
    ...snapshot.properties,
    'id': snapshot.ref.identifier,
    if (keys.idKey != 'id') keys.idKey: snapshot.ref.identifier,
    if (keys.titleKey != 'title' && snapshot.effectiveTitle != null)
      'title': snapshot.effectiveTitle,
    if (keys.subtitleKey != 'subtitle' && snapshot.subtitle != null)
      'subtitle': snapshot.subtitle,
    if (keys.keywordsKey != 'keywords' && snapshot.keywords.isNotEmpty)
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
    row[keys.titleKey] = title;
  }
  if (subtitle != null) {
    row[keys.subtitleKey] = subtitle;
  }
  if (keywords != null) {
    row[keys.keywordsKey] = keywords;
  }
  return row;
}

Object? _fieldValue(final AgentEntitySnapshot snapshot, final String key) {
  final value = snapshot.properties[key];
  return value;
}
