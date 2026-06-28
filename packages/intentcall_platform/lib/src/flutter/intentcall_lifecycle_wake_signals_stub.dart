import 'intentcall_host_events.dart';

/// VM-safe lifecycle wake source.
final class IntentCallLifecycleWakeSignals {
  IntentCallLifecycleWakeSignals();

  Stream<IntentCallDrainTrigger> get resumeSignals =>
      const Stream<IntentCallDrainTrigger>.empty();

  Future<void> dispose() async {}
}
