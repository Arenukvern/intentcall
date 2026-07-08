import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/intentcall_platform_bridge.g.dart',
    dartPackageName: 'intentcall_bridge',
    swiftOut:
        '../intentcall_platform_apple/darwin/intentcall_platform_apple/Sources/intentcall_platform_apple/IntentCallPlatformBridge.g.swift',
    swiftOptions: SwiftOptions(),
    kotlinOut:
        '../intentcall_platform_android/android/src/main/kotlin/dev/intentcall/intentcall_platform/IntentCallPlatformBridge.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.intentcall.intentcall_platform'),
  ),
)
/// Native invocation envelope drained from the handoff store.
class IntentCallInvocationEnvelopeDto {
  late String id;
  late String qualifiedName;
  Map<String?, Object?>? arguments;
  late String source;
  late String createdAt;
}

/// Native entity-open envelope drained from the entity snapshot store.
class IntentCallEntityOpenEnvelopeDto {
  late String id;
  late String entityType;
  late String entityId;
  late String source;
  late String createdAt;
}

/// Manifest-projected entity field keys for snapshot CRUD and search.
class IntentCallEntityKeyBundle {
  IntentCallEntityKeyBundle({
    this.idKey = 'id',
    this.titleKey = 'title',
    this.subtitleKey = 'subtitle',
    this.keywordsKey = 'keywords',
  });
  String idKey;
  String titleKey;
  String subtitleKey;
  String keywordsKey;
}

@HostApi()
abstract class IntentCallInvocationsHostApi {
  List<IntentCallInvocationEnvelopeDto> takePendingInvocations();
}

@HostApi()
abstract class IntentCallEntitiesHostApi {
  int upsertEntitySnapshots(
    final String entityType,
    final List<Map<String?, Object?>> snapshots,
    final IntentCallEntityKeyBundle keys,
  );

  int deleteEntitySnapshots(
    final String entityType,
    final List<String> ids,
    final IntentCallEntityKeyBundle keys,
  );

  int clearEntityTypeSnapshots(final String entityType);

  List<Map<String?, Object?>> listEntitySnapshots(final String entityType);

  List<Map<String?, Object?>> searchEntitySnapshots(
    final String entityType,
    final String query,
    final int limit,
    final IntentCallEntityKeyBundle keys,
  );

  List<IntentCallEntityOpenEnvelopeDto> takePendingEntityOpens();
}
