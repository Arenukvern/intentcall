import 'dart:async';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import 'intentcall_host_events.dart';
import 'intentcall_invoke_link_stub.dart'
    if (dart.library.ui) 'intentcall_invoke_link.dart';
import 'intentcall_lifecycle_wake_signals_stub.dart'
    if (dart.library.ui) 'intentcall_lifecycle_wake_signals.dart';
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
    required this.webMcpSurfaceIndex,
    required this.onEnvelope,
    required this.onResult,
    required this.onDenied,
    required this.onError,
    required this.drainOnStart,
    this._wakeSignals,
    this._lifecycleWakeSignals,
    this._deepLinkListener,
  });

  factory IntentCallFlutterHost.bindRegistry({
    required final AgentRegistry registry,
    final IntentCallAuthorizationPolicy policy =
        const IntentCallAuthorizationPolicy.denyAll(),
    final bool registerWebMcp = false,
    final ManifestSurfaceIndex? webMcpSurfaceIndex,
    final bool drainOnStart = true,
    final bool drainOnResume = true,
    final bool listenForDeepLinks = false,
    final String? protocolScheme,
    final IntentCallPendingReader? takePendingInvocations,
    final Stream<IntentCallDrainTrigger>? wakeSignals,
    final IntentCallEnvelopeCallback? onEnvelope,
    final IntentCallResultCallback? onResult,
    final IntentCallResultCallback? onDenied,
    final IntentCallErrorCallback? onError,
  }) {
    final lifecycleWakeSignals = wakeSignals == null && drainOnResume
        ? IntentCallLifecycleWakeSignals()
        : null;
    late final IntentCallFlutterHost host;
    final deepLinkListener = listenForDeepLinks
        ? IntentCallInvokeLinkListener(
            protocolScheme: _requireProtocolScheme(protocolScheme),
            onQualifiedName: (_) {
              unawaited(
                host
                    .requestDrain(IntentCallDrainTrigger.deepLink)
                    .catchError((_) => <AgentResult>[]),
              );
            },
          )
        : null;
    // The deep-link callback captures the host, so this cannot be inlined.
    // ignore: join_return_with_assignment
    host = IntentCallFlutterHost._(
      bridge: IntentCallNativeBridge.bindRegistry(
        registry: registry,
        policy: policy,
      ),
      takePendingInvocations:
          takePendingInvocations ??
          const IntentCallPendingInvocations().takePending,
      registerWebMcp: registerWebMcp,
      webMcpSurfaceIndex: webMcpSurfaceIndex,
      onEnvelope: onEnvelope,
      onResult: onResult,
      onDenied: onDenied,
      onError: onError,
      drainOnStart: drainOnStart,
      wakeSignals: wakeSignals ?? lifecycleWakeSignals?.resumeSignals,
      lifecycleWakeSignals: lifecycleWakeSignals,
      deepLinkListener: deepLinkListener,
    );
    return host;
  }

  final IntentCallNativeBridge bridge;
  final IntentCallPendingReader takePendingInvocations;
  final bool registerWebMcp;
  final ManifestSurfaceIndex? webMcpSurfaceIndex;
  final IntentCallEnvelopeCallback? onEnvelope;
  final IntentCallResultCallback? onResult;
  final IntentCallResultCallback? onDenied;
  final IntentCallErrorCallback? onError;
  final bool drainOnStart;

  final Stream<IntentCallDrainTrigger>? _wakeSignals;
  final IntentCallLifecycleWakeSignals? _lifecycleWakeSignals;
  final IntentCallInvokeLinkListener? _deepLinkListener;
  final StreamController<IntentCallHostEvent> _events =
      StreamController<IntentCallHostEvent>.broadcast();
  StreamSubscription<IntentCallDrainTrigger>? _wakeSubscription;
  Future<List<AgentResult>>? _activeDrain;
  IntentCallDrainTrigger? _queuedTrigger;
  bool _drainAgain = false;
  bool _disposed = false;

  Stream<IntentCallHostEvent> get events => _events.stream;

  Future<List<AgentResult>> start() async {
    if (registerWebMcp) {
      registerAgentWebMcpFromRegistry(
        bridge.registry,
        policy: bridge.policy,
        surfaceIndex: webMcpSurfaceIndex,
      );
    }
    await _deepLinkListener?.start();
    _wakeSubscription ??= _wakeSignals?.listen((final trigger) {
      unawaited(requestDrain(trigger).catchError((_) => <AgentResult>[]));
    });
    if (!drainOnStart) {
      return const <AgentResult>[];
    }
    return requestDrain(IntentCallDrainTrigger.start);
  }

  Future<List<AgentResult>> drainPendingInvocations() =>
      requestDrain(IntentCallDrainTrigger.manual);

  Future<List<AgentResult>> requestDrain(final IntentCallDrainTrigger trigger) {
    if (_disposed) {
      return Future<List<AgentResult>>.value(const <AgentResult>[]);
    }
    final activeDrain = _activeDrain;
    if (activeDrain != null) {
      _drainAgain = true;
      _queuedTrigger ??= trigger;
      return activeDrain;
    }
    final drain = _runDrainLoop(trigger);
    _activeDrain = drain;
    return drain.whenComplete(() {
      _activeDrain = null;
    });
  }

  Future<List<AgentResult>> _runDrainLoop(
    final IntentCallDrainTrigger trigger,
  ) async {
    var currentTrigger = trigger;
    final allResults = <AgentResult>[];
    do {
      _drainAgain = false;
      _queuedTrigger = null;
      allResults.addAll(await _drainOnce(currentTrigger));
      currentTrigger = _queuedTrigger ?? trigger;
    } while (_drainAgain);
    return allResults;
  }

  Future<List<AgentResult>> _drainOnce(
    final IntentCallDrainTrigger trigger,
  ) async {
    _emit(
      IntentCallHostEvent(
        kind: IntentCallHostEventKind.drainStarted,
        trigger: trigger,
      ),
    );
    final pending = await takePendingInvocations();
    final results = <AgentResult>[];
    for (final envelope in pending) {
      results.add(await execute(envelope, trigger: trigger));
    }
    _emit(
      IntentCallHostEvent(
        kind: IntentCallHostEventKind.drainFinished,
        trigger: trigger,
        results: results,
      ),
    );
    return results;
  }

  Future<AgentResult> execute(
    final IntentCallInvocationEnvelope envelope, {
    final IntentCallDrainTrigger trigger = IntentCallDrainTrigger.manual,
  }) async {
    onEnvelope?.call(envelope);
    _emit(
      IntentCallHostEvent(
        kind: IntentCallHostEventKind.envelope,
        trigger: trigger,
        envelope: envelope,
      ),
    );
    try {
      final result = await bridge.execute(envelope);
      if (!result.ok && result.code == 'invocation_denied') {
        onDenied?.call(envelope, result);
        _emit(
          IntentCallHostEvent(
            kind: IntentCallHostEventKind.denied,
            trigger: trigger,
            envelope: envelope,
            result: result,
          ),
        );
      }
      onResult?.call(envelope, result);
      _emit(
        IntentCallHostEvent(
          kind: IntentCallHostEventKind.result,
          trigger: trigger,
          envelope: envelope,
          result: result,
        ),
      );
      return result;
    } catch (error, stackTrace) {
      onError?.call(envelope, error, stackTrace);
      _emit(
        IntentCallHostEvent(
          kind: IntentCallHostEventKind.error,
          trigger: trigger,
          envelope: envelope,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      rethrow;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _wakeSubscription?.cancel();
    _wakeSubscription = null;
    await _deepLinkListener?.dispose();
    await _lifecycleWakeSignals?.dispose();
    await _events.close();
  }

  void _emit(final IntentCallHostEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}

String _requireProtocolScheme(final String? protocolScheme) {
  final scheme = protocolScheme?.trim() ?? '';
  if (scheme.isEmpty) {
    throw ArgumentError(
      'listenForDeepLinks requires an app-owned protocolScheme.',
    );
  }
  return scheme;
}
