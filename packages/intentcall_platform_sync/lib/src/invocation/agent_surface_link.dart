import 'dart:async';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import 'intentcall_invocation.dart';

/// One completed call on an [AgentSurfaceLink].
///
/// Subscribers may record it. They must not treat arrival as a UI rebuild.
final class AgentCallObservation {
  const AgentCallObservation({required this.envelope, required this.result});

  factory AgentCallObservation.fromJson(final Map<String, Object?> json) {
    final envelopeRaw = json['envelope'];
    final resultRaw = json['result'];
    return AgentCallObservation(
      envelope: IntentCallInvocationEnvelope.fromJson(
        envelopeRaw is Map
            ? Map<String, Object?>.from(envelopeRaw)
            : const <String, Object?>{},
      ),
      result: _resultFromJson(
        resultRaw is Map
            ? Map<String, Object?>.from(resultRaw)
            : const <String, Object?>{},
      ),
    );
  }

  final IntentCallInvocationEnvelope envelope;
  final AgentResult result;

  Map<String, Object?> toJson() => <String, Object?>{
    'envelope': envelope.toJson(),
    'result': _resultJson(result),
  };
}

/// Cross-surface call and observation. Implementations must not redraw UI.
abstract interface class AgentSurfaceLink {
  Future<AgentResult> invoke(final IntentCallInvocationEnvelope envelope);

  Stream<AgentCallObservation> watch();
}

/// In-process link. Executes through [IntentCallNativeBridge] and records
/// every [invoke]. [observe] records a call some other adapter already ran.
final class AgentInvocationHub implements AgentSurfaceLink {
  AgentInvocationHub({required this.bridge, this.registry});

  factory AgentInvocationHub.bindRegistry({
    required final AgentRegistry registry,
    required final IntentCallAuthorizationPolicy policy,
  }) => AgentInvocationHub(
    bridge: IntentCallNativeBridge.bindRegistry(
      registry: registry,
      policy: policy,
    ),
    registry: registry,
  );

  final IntentCallNativeBridge bridge;
  final AgentRegistry? registry;

  List<Map<String, Object?>> listTools() {
    final registry = this.registry;
    if (registry == null) {
      return const <Map<String, Object?>>[];
    }
    return <Map<String, Object?>>[
      for (final entry in registry.listEntries())
        if (entry.descriptor.kind == AgentIntentKind.tool)
          <String, Object?>{
            'name': entry.key,
            'description': entry.descriptor.description,
            'inputSchema': entry.descriptor.inputSchema,
          },
    ];
  }

  final StreamController<AgentCallObservation> _calls =
      StreamController<AgentCallObservation>.broadcast();

  @override
  Future<AgentResult> invoke(
    final IntentCallInvocationEnvelope envelope,
  ) async {
    final result = await bridge.execute(envelope);
    observe(envelope: envelope, result: result);
    return result;
  }

  void observe({
    required final IntentCallInvocationEnvelope envelope,
    required final AgentResult result,
  }) {
    if (_calls.isClosed) {
      return;
    }
    _calls.add(AgentCallObservation(envelope: envelope, result: result));
  }

  @override
  Stream<AgentCallObservation> watch() => _calls.stream;

  Future<void> close() => _calls.close();
}

Map<String, Object?> _resultJson(final AgentResult result) {
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

AgentResult _resultFromJson(final Map<String, Object?> json) {
  final ok = json['ok'] == true;
  if (!ok) {
    return AgentResult.failure(
      code: '${json['code'] ?? 'tool_failed'}',
      message: '${json['message'] ?? 'Tool failed.'}',
      details: json['details'] is Map
          ? Map<String, Object?>.from(json['details']! as Map)
          : const <String, Object?>{},
    );
  }
  final data = Map<String, Object?>.from(json)..remove('ok');
  return AgentResult.success(data: data);
}
