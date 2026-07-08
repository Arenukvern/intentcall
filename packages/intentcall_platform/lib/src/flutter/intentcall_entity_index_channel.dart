import 'package:intentcall_bridge/intentcall_bridge.dart' as bridge;

import 'intentcall_entity_key_bundle.dart';

final _entitiesHostApi = bridge.IntentCallEntitiesHostApi();

Future<Object?> defaultIntentCallPlatformEntityInvoke(
  final String method,
  final Object? arguments,
) async {
  final args = Map<String, Object?>.from(arguments as Map? ?? const {});
  final entityType = '${args['entityType'] ?? ''}';
  final keys = _toBridgeKeyBundle(_readKeyBundle(args));

  switch (method) {
    case 'upsertEntitySnapshots':
      final snapshots =
          (args['snapshots'] as List?)
              ?.map(
                (final row) => Map<String?, Object?>.from(row as Map),
              )
              .toList(growable: false) ??
          const <Map<String?, Object?>>[];
      return _entitiesHostApi.upsertEntitySnapshots(
        entityType,
        snapshots,
        keys,
      );
    case 'deleteEntitySnapshots':
      final ids =
          (args['ids'] as List?)?.map((final id) => '$id').toList(
            growable: false,
          ) ??
          const <String>[];
      return _entitiesHostApi.deleteEntitySnapshots(entityType, ids, keys);
    case 'clearEntityTypeSnapshots':
      return _entitiesHostApi.clearEntityTypeSnapshots(entityType);
    case 'listEntitySnapshots':
      final rows = await _entitiesHostApi.listEntitySnapshots(entityType);
      return rows
          .map((final row) => Map<String, Object?>.from(row))
          .toList(growable: false);
    case 'searchEntitySnapshots':
      final query = '${args['query'] ?? ''}';
      final limit = args['limit'] as int? ?? 20;
      final rows = await _entitiesHostApi.searchEntitySnapshots(
        entityType,
        query,
        limit,
        keys,
      );
      return rows
          .map((final row) => Map<String, Object?>.from(row))
          .toList(growable: false);
    default:
      throw UnsupportedError('Unknown entity bridge method: $method');
  }
}

IntentCallEntityKeyBundle _readKeyBundle(final Map<String, Object?> args) {
  final bundle = args['keys'];
  if (bundle is IntentCallEntityKeyBundle) {
    return bundle;
  }
  if (bundle is Map) {
    return IntentCallEntityKeyBundle(
      idKey: '${bundle['idKey'] ?? 'id'}',
      titleKey: '${bundle['titleKey'] ?? 'title'}',
      subtitleKey: '${bundle['subtitleKey'] ?? 'subtitle'}',
      keywordsKey: '${bundle['keywordsKey'] ?? 'keywords'}',
    );
  }
  return intentCallDefaultEntityKeyBundle();
}

bridge.IntentCallEntityKeyBundle _toBridgeKeyBundle(
  final IntentCallEntityKeyBundle keys,
) {
  return bridge.IntentCallEntityKeyBundle(
    idKey: keys.idKey,
    titleKey: keys.titleKey,
    subtitleKey: keys.subtitleKey,
    keywordsKey: keys.keywordsKey,
  );
}
