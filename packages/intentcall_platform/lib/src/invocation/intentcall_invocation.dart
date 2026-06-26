import 'dart:async';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

typedef IntentCallConfirmation =
    FutureOr<bool> Function(IntentCallInvocationEnvelope envelope);

final class IntentCallInvocationSource {
  const IntentCallInvocationSource._();

  static const String webMcpDart = 'webmcp.dart';
  static const String webMcpFallback = 'webmcp.fallback';
  static const String nativeGenerated = 'native.generated';
  static const String deepLink = 'deeplink';
}

final class IntentCallInvocationEnvelope {
  IntentCallInvocationEnvelope({
    required this.id,
    required this.qualifiedName,
    required this.arguments,
    required this.source,
    final DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  factory IntentCallInvocationEnvelope.fromJson(
    final Map<String, Object?> json,
  ) {
    final args = json['arguments'];
    return IntentCallInvocationEnvelope(
      id: '${json['id'] ?? ''}',
      qualifiedName: '${json['qualifiedName'] ?? ''}',
      arguments: args is Map
          ? Map<String, Object?>.from(args)
          : const <String, Object?>{},
      source: '${json['source'] ?? ''}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
    );
  }

  final String id;
  final String qualifiedName;
  final Map<String, Object?> arguments;
  final String source;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'qualifiedName': qualifiedName,
    'arguments': arguments,
    'source': source,
    'createdAt': createdAt.toIso8601String(),
  };
}

final class IntentCallAuthorizationPolicy {
  const IntentCallAuthorizationPolicy({
    this.allowedSources,
    this.allowedQualifiedNames,
    this.confirm,
  });

  const IntentCallAuthorizationPolicy.allowAll()
    : allowedSources = null,
      allowedQualifiedNames = null,
      confirm = null;

  const IntentCallAuthorizationPolicy.denyAll()
    : allowedSources = const <String>{},
      allowedQualifiedNames = const <String>{},
      confirm = null;

  final Set<String>? allowedSources;
  final Set<String>? allowedQualifiedNames;
  final IntentCallConfirmation? confirm;

  Future<bool> allows(final IntentCallInvocationEnvelope envelope) async {
    final sourceAllowed =
        allowedSources == null || allowedSources!.contains(envelope.source);
    final nameAllowed =
        allowedQualifiedNames == null ||
        allowedQualifiedNames!.contains(envelope.qualifiedName);
    if (!sourceAllowed || !nameAllowed) {
      return false;
    }
    final approve = confirm;
    return approve == null || await approve(envelope);
  }
}

final class IntentCallNativeBridge {
  IntentCallNativeBridge._({required this.registry, required this.policy});

  factory IntentCallNativeBridge.bindRegistry({
    required final AgentRegistry registry,
    final IntentCallAuthorizationPolicy policy =
        const IntentCallAuthorizationPolicy.denyAll(),
  }) => IntentCallNativeBridge._(registry: registry, policy: policy);

  final AgentRegistry registry;
  final IntentCallAuthorizationPolicy policy;

  Future<AgentResult> execute(
    final IntentCallInvocationEnvelope envelope, {
    final String? correlationId,
  }) async {
    if (!await policy.allows(envelope)) {
      return AgentResult.failure(
        code: 'invocation_denied',
        message: 'Invocation denied for ${envelope.qualifiedName}.',
        details: <String, Object?>{'source': envelope.source},
      );
    }
    if (registry.get(envelope.qualifiedName) == null) {
      return AgentResult.failure(
        code: 'intent_not_found',
        message: 'No intent registered for ${envelope.qualifiedName}',
        details: <String, Object?>{'source': envelope.source},
      );
    }
    return registry.invoke(
      envelope.qualifiedName,
      envelope.arguments,
      correlationId: correlationId ?? envelope.id,
    );
  }
}
