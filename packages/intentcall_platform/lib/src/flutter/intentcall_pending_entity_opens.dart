import 'package:intentcall_bridge/intentcall_bridge.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

final class IntentCallPendingEntityOpens {
  IntentCallPendingEntityOpens({
    final IntentCallEntitiesHostApi? hostApi,
  }) : _hostApi = hostApi ?? IntentCallEntitiesHostApi();

  final IntentCallEntitiesHostApi _hostApi;

  Future<List<IntentCallEntityOpenEnvelope>> takePending() async {
    final rows = await _hostApi.takePendingEntityOpens();
    return rows.map(_toEnvelope).toList(growable: false);
  }
}

IntentCallEntityOpenEnvelope _toEnvelope(
  final IntentCallEntityOpenEnvelopeDto dto,
) {
  return IntentCallEntityOpenEnvelope(
    id: dto.id,
    entityType: dto.entityType,
    entityId: dto.entityId,
    source: dto.source,
    createdAt: DateTime.tryParse(dto.createdAt),
  );
}
