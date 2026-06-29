import 'package:intentcall_schema/intentcall_schema.dart';

import 'intentcall_entity_index_channel_stub.dart'
    if (dart.library.ui) 'intentcall_entity_index_channel.dart';

typedef IntentCallPlatformInvoke =
    Future<Object?> Function(String method, Object? arguments);

/// Dart-facing writer for native entity snapshots used by platform projections.
///
/// The index is a platform cache, not the app's source of truth. App logic owns
/// the authoritative model and writes JSON-safe snapshots here so native
/// surfaces can resolve entities while Flutter is not running.
final class IntentCallPlatformEntityIndex {
  IntentCallPlatformEntityIndex({final IntentCallPlatformInvoke? invoke})
    : _invoke = invoke ?? defaultIntentCallPlatformEntityInvoke;

  final IntentCallPlatformInvoke _invoke;

  Future<int> upsertAgentSnapshots({
    required final Iterable<AgentEntitySnapshot> snapshots,
  }) async {
    var count = 0;
    for (final entry in _snapshotsByEntityType(snapshots).entries) {
      count += await upsertSnapshots(
        entityType: entry.key,
        snapshots: entry.value.map(_snapshotFromModel),
      );
    }
    return count;
  }

  Future<int> deleteAgentRefs({
    required final Iterable<AgentEntityRef> refs,
  }) async {
    var count = 0;
    for (final entry in _refsByEntityType(refs).entries) {
      count += await deleteSnapshots(entityType: entry.key, ids: entry.value);
    }
    return count;
  }

  Future<int> upsertSnapshots({
    required final String entityType,
    required final Iterable<Map<String, Object?>> snapshots,
  }) async {
    final rows = snapshots.map(_snapshotRow).toList(growable: false);
    final result = await _invoke('upsertEntitySnapshots', <String, Object?>{
      'entityType': _entityType(entityType),
      'snapshots': rows,
    });
    return _intResult(result, fallback: rows.length);
  }

  Future<int> deleteSnapshots({
    required final String entityType,
    required final Iterable<String> ids,
  }) async {
    final idRows = ids.map(_entityId).toList(growable: false);
    final result = await _invoke('deleteEntitySnapshots', <String, Object?>{
      'entityType': _entityType(entityType),
      'ids': idRows,
    });
    return _intResult(result, fallback: idRows.length);
  }

  Future<int> clearEntityType(final String entityType) async {
    final result = await _invoke('clearEntityTypeSnapshots', <String, Object?>{
      'entityType': _entityType(entityType),
    });
    return _intResult(result, fallback: 0);
  }

  Future<List<Map<String, Object?>>> listSnapshots({
    required final String entityType,
  }) async {
    final result = await _invoke('listEntitySnapshots', <String, Object?>{
      'entityType': _entityType(entityType),
    });
    return _snapshotRows(result);
  }

  Future<List<Map<String, Object?>>> searchSnapshots({
    required final String entityType,
    required final String query,
    final int? limit,
  }) async {
    final arguments = <String, Object?>{
      'entityType': _entityType(entityType),
      'query': query.trim(),
    };
    if (limit != null) {
      arguments['limit'] = limit;
    }
    final result = await _invoke('searchEntitySnapshots', arguments);
    return _snapshotRows(result);
  }
}

Map<String, List<AgentEntitySnapshot>> _snapshotsByEntityType(
  final Iterable<AgentEntitySnapshot> snapshots,
) {
  final groups = <String, List<AgentEntitySnapshot>>{};
  for (final snapshot in snapshots) {
    final entityType = _entityType(
      '${snapshot.ref.namespace}_${snapshot.ref.typeName}',
    );
    groups.putIfAbsent(entityType, () => <AgentEntitySnapshot>[]).add(snapshot);
  }
  return groups;
}

Map<String, List<String>> _refsByEntityType(
  final Iterable<AgentEntityRef> refs,
) {
  final groups = <String, List<String>>{};
  for (final ref in refs) {
    final entityType = _entityType('${ref.namespace}_${ref.typeName}');
    groups.putIfAbsent(entityType, () => <String>[]).add(ref.identifier);
  }
  return groups;
}

Map<String, Object?> _snapshotFromModel(final AgentEntitySnapshot snapshot) =>
    <String, Object?>{
      'id': snapshot.ref.identifier,
      if (snapshot.effectiveTitle != null) 'title': snapshot.effectiveTitle,
      if (snapshot.subtitle != null) 'subtitle': snapshot.subtitle,
      if (snapshot.keywords.isNotEmpty) 'keywords': snapshot.keywords,
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

String _entityType(final String value) {
  final trimmed = value.trim();
  if (!RegExp(r'^[a-z][a-z0-9_]*_[a-z][a-z0-9_]*$').hasMatch(trimmed)) {
    throw ArgumentError.value(
      value,
      'entityType',
      'Expected lowercase namespace_name identifier.',
    );
  }
  return trimmed;
}

String _entityId(final String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, 'id', 'Entity id must not be empty.');
  }
  return trimmed;
}

Map<String, Object?> _snapshotRow(final Map<String, Object?> snapshot) {
  final id = _entityId('${snapshot['id'] ?? ''}');
  return <String, Object?>{...snapshot, 'id': id};
}

int _intResult(final Object? result, {required final int fallback}) {
  if (result is int) {
    return result;
  }
  if (result is num) {
    return result.toInt();
  }
  return fallback;
}

List<Map<String, Object?>> _snapshotRows(final Object? result) {
  if (result is! List) {
    return const <Map<String, Object?>>[];
  }
  return result
      .whereType<Map>()
      .map(Map<String, Object?>.from)
      .toList(growable: false);
}
