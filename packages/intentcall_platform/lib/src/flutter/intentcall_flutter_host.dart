import 'dart:async';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import '../bootstrap/agent_web_mcp_bootstrap.dart';
import '../invocation/intentcall_invocation.dart';
import 'intentcall_invoke_link_stub.dart'
    if (dart.library.ui) 'intentcall_invoke_link.dart';
import 'intentcall_pending_invocations_stub.dart'
    if (dart.library.ui) 'intentcall_pending_invocations.dart';

typedef IntentCallPendingReader =
    Future<List<IntentCallInvocationEnvelope>> Function();
typedef IntentCallEnvelopeCallback =
    void Function(IntentCallInvocationEnvelope envelope);
typedef IntentCallResultCallback =
    void Function(IntentCallInvocationEnvelope envelope, AgentResult result);
typedef IntentCallErrorCallback =
    void Function(
      IntentCallInvocationEnvelope envelope,
      Object error,
      StackTrace stackTrace,
    );

final class IntentCallFlutterHost {
  IntentCallFlutterHost._({
    required this.bridge,
    required this.takePendingInvocations,
    required this.registerWebMcp,
    required this.onEnvelope,
    required this.onResult,
    required this.onDenied,
    required this.onError,
    final IntentCallInvokeLinkListener? deepLinkListener,
  }) : _deepLinkListener = deepLinkListener;

  factory IntentCallFlutterHost.bindRegistry({
    required final AgentRegistry registry,
    final IntentCallAuthorizationPolicy policy =
        const IntentCallAuthorizationPolicy.denyAll(),
    final bool registerWebMcp = false,
    final bool listenForDeepLinks = false,
    final String? protocolScheme,
    final IntentCallPendingReader? takePendingInvocations,
    final IntentCallEnvelopeCallback? onEnvelope,
    final IntentCallResultCallback? onResult,
    final IntentCallResultCallback? onDenied,
    final IntentCallErrorCallback? onError,
  }) {
    final host = IntentCallFlutterHost._(
      bridge: IntentCallNativeBridge.bindRegistry(
        registry: registry,
        policy: policy,
      ),
      takePendingInvocations:
          takePendingInvocations ??
          const IntentCallPendingInvocations().takePending,
      registerWebMcp: registerWebMcp,
      onEnvelope: onEnvelope,
      onResult: onResult,
      onDenied: onDenied,
      onError: onError,
    );
    if (!listenForDeepLinks) {
      return host;
    }
    final scheme = protocolScheme?.trim() ?? '';
    if (scheme.isEmpty) {
      throw ArgumentError(
        'listenForDeepLinks requires an app-owned protocolScheme.',
      );
    }
    return IntentCallFlutterHost._(
      bridge: host.bridge,
      takePendingInvocations: host.takePendingInvocations,
      registerWebMcp: host.registerWebMcp,
      onEnvelope: host.onEnvelope,
      onResult: host.onResult,
      onDenied: host.onDenied,
      onError: host.onError,
      deepLinkListener: IntentCallInvokeLinkListener(
        protocolScheme: scheme,
        onQualifiedName: (_) {
          unawaited(
            host.drainPendingInvocations().catchError((_) => <AgentResult>[]),
          );
        },
      ),
    );
  }

  final IntentCallNativeBridge bridge;
  final IntentCallPendingReader takePendingInvocations;
  final bool registerWebMcp;
  final IntentCallEnvelopeCallback? onEnvelope;
  final IntentCallResultCallback? onResult;
  final IntentCallResultCallback? onDenied;
  final IntentCallErrorCallback? onError;

  final IntentCallInvokeLinkListener? _deepLinkListener;

  Future<List<AgentResult>> start() async {
    if (registerWebMcp) {
      registerAgentWebMcpFromRegistry(bridge.registry, policy: bridge.policy);
    }
    await _deepLinkListener?.start();
    return drainPendingInvocations();
  }

  Future<List<AgentResult>> drainPendingInvocations() async {
    final pending = await takePendingInvocations();
    final results = <AgentResult>[];
    for (final envelope in pending) {
      results.add(await execute(envelope));
    }
    return results;
  }

  Future<AgentResult> execute(
    final IntentCallInvocationEnvelope envelope,
  ) async {
    onEnvelope?.call(envelope);
    try {
      final result = await bridge.execute(envelope);
      if (!result.ok && result.code == 'invocation_denied') {
        onDenied?.call(envelope, result);
      }
      onResult?.call(envelope, result);
      return result;
    } catch (error, stackTrace) {
      onError?.call(envelope, error, stackTrace);
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _deepLinkListener?.dispose();
  }
}
