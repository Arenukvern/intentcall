import 'package:flutter/services.dart';

import '../invocation/intentcall_invocation.dart';

final class IntentCallPendingInvocations {
  const IntentCallPendingInvocations({
    this.channel = const MethodChannel('intentcall_platform/invocations'),
  });

  final MethodChannel channel;

  Future<List<IntentCallInvocationEnvelope>> takePending() async {
    final rows = await channel.invokeListMethod<Object?>(
      'takePendingInvocations',
    );
    if (rows == null) {
      return const <IntentCallInvocationEnvelope>[];
    }
    return rows
        .whereType<Map>()
        .map(
          (final row) => IntentCallInvocationEnvelope.fromJson(
            Map<String, Object?>.from(row),
          ),
        )
        .toList(growable: false);
  }
}
