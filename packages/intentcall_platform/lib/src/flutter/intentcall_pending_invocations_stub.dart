import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

/// VM-safe fallback for host tests and non-Flutter analysis.
final class IntentCallPendingInvocations {
  const IntentCallPendingInvocations();

  Future<List<IntentCallInvocationEnvelope>> takePending() async =>
      const <IntentCallInvocationEnvelope>[];
}
