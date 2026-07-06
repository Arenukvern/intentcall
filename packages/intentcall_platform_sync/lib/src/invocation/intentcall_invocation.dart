import 'dart:async';
import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

typedef IntentCallConfirmation =
    FutureOr<bool> Function(IntentCallInvocationEnvelope envelope);

final class IntentCallInvocationSource {
  const IntentCallInvocationSource._();

  static const String webMcpDart = 'webmcp.dart';
  static const String webMcpFallback = 'webmcp.fallback';
  static const String nativeGenerated = 'native.generated';
  static const String appleDartExtensionInline = 'apple.dart_extension_inline';
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
    this.allowedSources = const <String>{},
    this.allowedQualifiedNames = const <String>{},
    this.confirm,
  }) : allowAnySource = false,
       allowAnyQualifiedName = false,
       debugOnly = false;

  const IntentCallAuthorizationPolicy.allowAll()
    : allowedSources = const <String>{},
      allowedQualifiedNames = const <String>{},
      confirm = null,
      allowAnySource = true,
      allowAnyQualifiedName = true,
      debugOnly = false;

  /// Allows all invocations only while Dart assertions are enabled.
  ///
  /// This is intended for local development and dogfood apps. In compiled
  /// profile/release builds, where assertions are disabled, it behaves like
  /// [IntentCallAuthorizationPolicy.denyAll].
  const IntentCallAuthorizationPolicy.debugAllowAll()
    : allowedSources = const <String>{},
      allowedQualifiedNames = const <String>{},
      confirm = null,
      allowAnySource = true,
      allowAnyQualifiedName = true,
      debugOnly = true;

  const IntentCallAuthorizationPolicy.denyAll()
    : allowedSources = const <String>{},
      allowedQualifiedNames = const <String>{},
      confirm = null,
      allowAnySource = false,
      allowAnyQualifiedName = false,
      debugOnly = false;

  final Set<String> allowedSources;
  final Set<String> allowedQualifiedNames;
  final IntentCallConfirmation? confirm;
  final bool allowAnySource;
  final bool allowAnyQualifiedName;
  final bool debugOnly;

  Future<bool> allows(final IntentCallInvocationEnvelope envelope) async {
    if (debugOnly && !_debugAssertionsEnabled) {
      return false;
    }
    final sourceAllowed =
        allowAnySource || allowedSources.contains(envelope.source);
    final nameAllowed =
        allowAnyQualifiedName ||
        allowedQualifiedNames.contains(envelope.qualifiedName);
    if (!sourceAllowed || !nameAllowed) {
      return false;
    }
    final approve = confirm;
    return approve == null || await approve(envelope);
  }
}

bool get _debugAssertionsEnabled {
  var enabled = false;
  assert(() {
    enabled = true;
    return true;
  }(), 'Detect whether Dart assertions are enabled.');
  return enabled;
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

/// VM-safe runtime used by the experimental Apple Dart extension inline bridge.
///
/// The Flutter extension entrypoint owns MethodChannel binding; this class owns
/// request decoding, source attribution, authorization, registry invocation, and
/// stable result encoding.
final class IntentCallDartExtensionInlineRuntime {
  IntentCallDartExtensionInlineRuntime._({required this.bridge});

  factory IntentCallDartExtensionInlineRuntime.bindRegistry({
    required final AgentRegistry registry,
    final IntentCallAuthorizationPolicy policy =
        const IntentCallAuthorizationPolicy.denyAll(),
  }) => IntentCallDartExtensionInlineRuntime._(
    bridge: IntentCallNativeBridge.bindRegistry(
      registry: registry,
      policy: policy,
    ),
  );

  final IntentCallNativeBridge bridge;

  Future<Map<String, Object?>> perform(final Object? request) async {
    final envelope = _readDartExtensionEnvelope(request);
    if (envelope == null) {
      return _encodeAgentResult(
        AgentResult.failure(
          code: 'invalid_extension_request',
          message: 'Invalid dartExtensionInline invocation request.',
        ),
      );
    }
    final result = await bridge.execute(envelope);
    return _encodeAgentResult(result);
  }
}

IntentCallInvocationEnvelope? _readDartExtensionEnvelope(
  final Object? request,
) {
  if (request is! Map) {
    return null;
  }
  final raw = Map<String, Object?>.from(request);
  final qualifiedName = '${raw['qualifiedName'] ?? ''}'.trim();
  if (qualifiedName.isEmpty) {
    return null;
  }
  final arguments = raw['arguments'];
  return IntentCallInvocationEnvelope(
    id: '${raw['id'] ?? ''}'.trim().isEmpty
        ? 'dart-extension-${DateTime.now().toUtc().microsecondsSinceEpoch}'
        : '${raw['id']}',
    qualifiedName: qualifiedName,
    arguments: arguments is Map
        ? Map<String, Object?>.from(arguments)
        : const <String, Object?>{},
    source: IntentCallInvocationSource.appleDartExtensionInline,
    createdAt: DateTime.tryParse('${raw['createdAt'] ?? ''}'),
  );
}

Map<String, Object?> _encodeAgentResult(
  final AgentResult result,
) => <String, Object?>{
  'ok': result.ok,
  'message': result.message,
  'dialog': result.message,
  if (result.code != null) 'code': result.code,
  'data': result.data,
  'details': result.details,
  'artifacts': result.artifacts
      .map(
        (final artifact) => <String, Object?>{
          'mimeType': artifact.mimeType,
          if (artifact.text != null) 'text': artifact.text,
          if (artifact.bytes != null) 'base64': base64Encode(artifact.bytes!),
        },
      )
      .toList(),
};
