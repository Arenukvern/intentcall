import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import 'intentcall_entity_index_channel_stub.dart'
    if (dart.library.ui) 'intentcall_entity_index_channel.dart';
import 'intentcall_entity_key_bundle.dart';

typedef IntentCallPlatformInvoke =
    Future<Object?> Function(String method, Object? arguments);

/// Manifest-projected entity field keys for native snapshot channels.
IntentCallEntityKeyBundle entityKeyBundleFromDescriptor(
  final AgentEntityTypeDescriptor descriptor,
) {
  String? byRole(final AgentEntityPropertyRole role) {
    for (final property in descriptor.properties) {
      if (property.role == role) {
        return property.name;
      }
    }
    return null;
  }

  return IntentCallEntityKeyBundle(
    idKey: descriptor.identifierName,
    titleKey: byRole(AgentEntityPropertyRole.title) ?? 'title',
    subtitleKey: byRole(AgentEntityPropertyRole.subtitle) ?? 'subtitle',
    keywordsKey: byRole(AgentEntityPropertyRole.keywords) ?? 'keywords',
  );
}

/// Dart-facing writer for native entity snapshots used by platform projections.
///
/// The index is a platform cache, not the app's source of truth. App logic owns
/// the authoritative model and writes JSON-safe snapshots here so native
/// surfaces can resolve entities while Flutter is not running.
final class IntentCallPlatformEntityIndex {
  IntentCallPlatformEntityIndex({final IntentCallPlatformInvoke? invoke})
    : _invoke = invoke ?? defaultIntentCallPlatformEntityInvoke;

  final IntentCallPlatformInvoke _invoke;

  Future<int> upsertAgentSnapshotsForType({
    required final AgentEntityTypeDescriptor descriptor,
    required final Iterable<AgentEntitySnapshot> snapshots,
  }) => upsertSnapshots(
    entityType: descriptor.qualifiedName,
    snapshots: snapshots.map(
      (final snapshot) => projectAgentEntitySnapshot(snapshot, descriptor),
    ),
    keys: entityKeyBundleFromDescriptor(descriptor),
  );

  Future<int> deleteAgentRefs({
    required final Iterable<AgentEntityRef> refs,
    final IntentCallEntityKeyBundle? keys,
  }) async {
    var count = 0;
    for (final entry in _refsByEntityType(refs).entries) {
      count += await deleteSnapshots(
        entityType: entry.key,
        ids: entry.value,
        keys: keys,
      );
    }
    return count;
  }

  Future<int> upsertSnapshots({
    required final String entityType,
    required final Iterable<Map<String, Object?>> snapshots,
    final IntentCallEntityKeyBundle? keys,
  }) async {
    final rows = snapshots.map(_snapshotRow).toList(growable: false);
    final result = await _invoke('upsertEntitySnapshots', <String, Object?>{
      'entityType': _entityType(entityType),
      'snapshots': rows,
      'keys': keys ?? intentCallDefaultEntityKeyBundle(),
    });
    return _intResult(result, fallback: rows.length);
  }

  Future<int> deleteSnapshots({
    required final String entityType,
    required final Iterable<String> ids,
    final IntentCallEntityKeyBundle? keys,
  }) async {
    final idRows = ids.map(_entityId).toList(growable: false);
    final result = await _invoke('deleteEntitySnapshots', <String, Object?>{
      'entityType': _entityType(entityType),
      'ids': idRows,
      'keys': keys ?? intentCallDefaultEntityKeyBundle(),
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
    final IntentCallEntityKeyBundle? keys,
  }) async {
    final arguments = <String, Object?>{
      'entityType': _entityType(entityType),
      'query': query.trim(),
      'keys': keys ?? intentCallDefaultEntityKeyBundle(),
    };
    if (limit != null) {
      arguments['limit'] = limit;
    }
    final result = await _invoke('searchEntitySnapshots', arguments);
    return _snapshotRows(result);
  }
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
