import '../invocation/intentcall_invocation.dart';

/// VM-safe fallback for host tests and non-Flutter analysis.
final class IntentCallPendingInvocations {
  const IntentCallPendingInvocations();

  Future<List<IntentCallInvocationEnvelope>> takePending() async =>
      const <IntentCallInvocationEnvelope>[];
}
