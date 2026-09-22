import 'dart:convert';

import 'package:intentcall_bridge/intentcall_bridge.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

void registerIntentCallAwaitingHandler(final IntentCallNativeBridge bridge) {
  IntentCallAwaitingFlutterApi.setUp(_IntentCallAwaitingHandler(bridge));
}

final class _IntentCallAwaitingHandler implements IntentCallAwaitingFlutterApi {
  _IntentCallAwaitingHandler(this._bridge);

  final IntentCallNativeBridge _bridge;

  @override
  Future<IntentCallAwaitResultDto> invoke(
    final IntentCallInvocationEnvelopeDto envelope,
  ) async {
    final arguments = <String, Object?>{};
    final raw = envelope.arguments;
    if (raw != null) {
      for (final entry in raw.entries) {
        final key = entry.key;
        if (key == null) {
          continue;
        }
        arguments[key] = entry.value;
      }
    }
    final result = await _bridge.execute(
      IntentCallInvocationEnvelope(
        id: envelope.id,
        qualifiedName: envelope.qualifiedName,
        arguments: arguments,
        source: IntentCallInvocationSource.appleAwaitApp,
        createdAt: DateTime.tryParse(envelope.createdAt),
      ),
    );
    return IntentCallAwaitResultDto(
      ok: result.ok,
      code: result.code,
      dialog: jsonEncode(_dialogPayload(result)),
    );
  }
}

Map<String, Object?> _dialogPayload(final AgentResult result) {
  if (!result.ok) {
    return <String, Object?>{
      'ok': false,
      'code': result.code,
      'message': result.message,
      if (result.details.isNotEmpty) 'details': result.details,
    };
  }
  return <String, Object?>{'ok': true, ...result.data};
}
