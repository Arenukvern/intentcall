import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

/// Reason a pending native invocation drain was requested.
enum IntentCallDrainTrigger { start, resume, deepLink, manual }

/// Observable host dispatch lifecycle event.
enum IntentCallHostEventKind {
  drainStarted,
  envelope,
  result,
  denied,
  error,
  drainFinished,
}

/// Event emitted by [IntentCallFlutterHost] while dispatching pending work.
final class IntentCallHostEvent {
  const IntentCallHostEvent({
    required this.kind,
    required this.trigger,
    this.envelope,
    this.result,
    this.results = const <AgentResult>[],
    this.error,
    this.stackTrace,
  });

  final IntentCallHostEventKind kind;
  final IntentCallDrainTrigger trigger;
  final IntentCallInvocationEnvelope? envelope;
  final AgentResult? result;
  final List<AgentResult> results;
  final Object? error;
  final StackTrace? stackTrace;
}
