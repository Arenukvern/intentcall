import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/intentcall_platform_bridge.g.dart',
    dartPackageName: 'intentcall_bridge',
    swiftOut:
        '../intentcall_platform/ios/intentcall_platform/Sources/intentcall_platform/IntentCallPlatformBridge.g.swift',
    swiftOptions: SwiftOptions(),
    kotlinOut:
        '../intentcall_platform/android/src/main/kotlin/dev/intentcall/intentcall_platform/IntentCallPlatformBridge.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.intentcall.intentcall_platform',
    ),
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

/// Manifest-projected entity field keys for snapshot CRUD and search.
class IntentCallEntityKeyBundle {
  String idKey;
  String titleKey;
  String subtitleKey;
  String keywordsKey;

  IntentCallEntityKeyBundle({
    this.idKey = 'id',
    this.titleKey = 'title',
    this.subtitleKey = 'subtitle',
    this.keywordsKey = 'keywords',
  });
}

@HostApi()
abstract class IntentCallInvocationsHostApi {
  List<IntentCallInvocationEnvelopeDto> takePendingInvocations();
}

@HostApi()
abstract class IntentCallEntitiesHostApi {
  int upsertEntitySnapshots(
    String entityType,
    List<Map<String?, Object?>> snapshots,
    IntentCallEntityKeyBundle keys,
  );

  int deleteEntitySnapshots(
    String entityType,
    List<String> ids,
    IntentCallEntityKeyBundle keys,
  );

  int clearEntityTypeSnapshots(String entityType);

  List<Map<String?, Object?>> listEntitySnapshots(String entityType);

  List<Map<String?, Object?>> searchEntitySnapshots(
    String entityType,
    String query,
    int limit,
    IntentCallEntityKeyBundle keys,
  );
}
