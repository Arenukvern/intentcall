import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

/// VM-safe fallback for host tests and non-Flutter analysis.
final class IntentCallPendingEntityOpens {
  const IntentCallPendingEntityOpens();

  Future<List<IntentCallEntityOpenEnvelope>> takePending() async =>
      const <IntentCallEntityOpenEnvelope>[];
}
