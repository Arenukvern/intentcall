import 'package:intentcall_bridge/intentcall_bridge.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

final class IntentCallPendingInvocations {
  IntentCallPendingInvocations({final IntentCallInvocationsHostApi? hostApi})
    : _hostApi = hostApi ?? IntentCallInvocationsHostApi();

  final IntentCallInvocationsHostApi _hostApi;

  Future<List<IntentCallInvocationEnvelope>> takePending() async {
    final rows = await _hostApi.takePendingInvocations();
    return rows.map(_toEnvelope).toList(growable: false);
  }
}

IntentCallInvocationEnvelope _toEnvelope(
  final IntentCallInvocationEnvelopeDto dto,
) => IntentCallInvocationEnvelope(
  id: dto.id,
  qualifiedName: dto.qualifiedName,
  arguments: Map<String, Object?>.from(dto.arguments ?? const {}),
  source: dto.source,
  createdAt: DateTime.tryParse(dto.createdAt),
);
