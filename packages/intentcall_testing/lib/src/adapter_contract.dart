import 'dart:async';
import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

typedef AdapterContractInvoker =
    FutureOr<Object?> Function(String qualifiedName, AgentArguments arguments);

typedef AdapterContractResultNormalizer = AgentResult Function(Object? result);

final class AdapterContractProof {
  const AdapterContractProof({
    required this.adapterId,
    required this.initialToolName,
    required this.overriddenToolName,
    required this.failureToolName,
    required this.hotSyncToolName,
    required this.successData,
    required this.failureCode,
    required this.hotSyncProven,
    required this.detachCleanupProven,
  });

  final String adapterId;
  final String initialToolName;
  final String overriddenToolName;
  final String failureToolName;
  final String hotSyncToolName;
  final Map<String, Object?> successData;
  final String? failureCode;
  final bool hotSyncProven;
  final bool detachCleanupProven;
}

final class AdapterContractViolation extends StateError {
  AdapterContractViolation(super.message);
}

Future<AdapterContractProof> verifyNativeAdapterContract({
  required final AgentAdapter adapter,
  required final bool Function(String qualifiedName) isPublished,
  required final AdapterContractInvoker invoke,
  required final AdapterContractResultNormalizer normalize,
  final bool? requireHotSync,
  final bool requireDetachCleanup = true,
}) async {
  final registry = InMemoryAgentRegistry()
    ..register(_successIntent(name: 'echo'))
    ..register(_failureIntent(name: 'fail'))
    ..register(
      _successIntent(namespace: 'descriptor', name: 'override'),
      qualifiedNameOverride: 'custom_override',
    );

  const initialToolName = 'contract_echo';
  const overriddenToolName = 'custom_override';
  const failureToolName = 'contract_fail';
  const hotSyncToolName = 'contract_late';
  final shouldVerifyHotSync = requireHotSync ?? adapter.watchesRegistry;
  var attached = false;
  var detachCleanupProven = false;

  try {
    await adapter.attach(registry);
    attached = true;

    _require(
      isPublished(initialToolName),
      '${adapter.id} did not publish $initialToolName on attach',
    );
    _require(
      isPublished(failureToolName),
      '${adapter.id} did not publish $failureToolName on attach',
    );
    _require(
      isPublished(overriddenToolName),
      '${adapter.id} did not publish overridden $overriddenToolName on attach',
    );

    final success = normalize(
      await invoke(initialToolName, const <String, Object?>{
        'text': 'hello',
        'count': 2,
      }),
    );
    _require(success.ok, '${adapter.id} returned failure for $initialToolName');
    _require(
      success.data['text'] == 'hello',
      '${adapter.id} did not preserve success data text',
    );
    _require(
      success.data['count'] == 2,
      '${adapter.id} did not preserve success data count',
    );
    _require(
      success.data['qualifiedName'] == initialToolName,
      '${adapter.id} did not preserve success qualifiedName',
    );

    final overridden = normalize(
      await invoke(overriddenToolName, const <String, Object?>{
        'text': 'override',
        'count': 4,
      }),
    );
    _require(
      overridden.ok,
      '${adapter.id} returned failure for $overriddenToolName',
    );
    _require(
      overridden.data['qualifiedName'] == 'descriptor_override',
      '${adapter.id} did not invoke overridden registry key',
    );

    final failure = normalize(
      await invoke(failureToolName, const <String, Object?>{}),
    );
    _require(
      !failure.ok,
      '${adapter.id} returned success for $failureToolName',
    );
    _require(
      failure.code == 'contract_failure',
      '${adapter.id} did not preserve failure code',
    );
    _require(
      failure.details['surface'] == 'adapter_contract',
      '${adapter.id} did not preserve failure details',
    );

    if (shouldVerifyHotSync) {
      registry.register(_successIntent(name: 'late'));
      await Future<void>.delayed(Duration.zero);
      _require(
        isPublished(hotSyncToolName),
        '${adapter.id} did not hot-sync $hotSyncToolName',
      );

      final late = normalize(
        await invoke(hotSyncToolName, const <String, Object?>{
          'text': 'late',
          'count': 3,
        }),
      );
      _require(late.ok, '${adapter.id} returned failure for $hotSyncToolName');
      _require(
        late.data['qualifiedName'] == hotSyncToolName,
        '${adapter.id} did not invoke hot-synced tool',
      );

      registry.unregister(hotSyncToolName);
      await Future<void>.delayed(Duration.zero);
      _require(
        !isPublished(hotSyncToolName),
        '${adapter.id} did not unpublish $hotSyncToolName',
      );
    }

    await adapter.detach();
    attached = false;
    if (requireDetachCleanup) {
      _require(
        !isPublished(initialToolName),
        '${adapter.id} did not unpublish $initialToolName on detach',
      );
      _require(
        !isPublished(failureToolName),
        '${adapter.id} did not unpublish $failureToolName on detach',
      );
      _require(
        !isPublished(overriddenToolName),
        '${adapter.id} did not unpublish $overriddenToolName on detach',
      );
      detachCleanupProven = true;
    }

    return AdapterContractProof(
      adapterId: adapter.id,
      initialToolName: initialToolName,
      overriddenToolName: overriddenToolName,
      failureToolName: failureToolName,
      hotSyncToolName: hotSyncToolName,
      successData: success.data,
      failureCode: failure.code,
      hotSyncProven: shouldVerifyHotSync,
      detachCleanupProven: detachCleanupProven,
    );
  } finally {
    if (attached) {
      await adapter.detach();
    }
  }
}

AgentResult normalizeAdapterMapResult(final Object? result) {
  final map = _toStringObjectMap(result);
  final ok = map['ok'];
  if (ok == false) {
    return AgentResult.failure(
      code: map['code'] as String? ?? 'adapter_error',
      message: map['message'] as String? ?? 'Adapter returned an error',
      details: _optionalStringObjectMap(map['details']),
    );
  }
  if (ok == true) {
    final data = Map<String, Object?>.of(map)..remove('ok');
    return AgentResult.success(data: data);
  }
  return AgentResult.success(data: map);
}

AgentResult normalizeJsonTextAgentResult(final Object? result) {
  if (result is! AgentResult) {
    throw AdapterContractViolation(
      'Expected AgentResult, got ${result.runtimeType}',
    );
  }
  if (result.ok) {
    final text = result.data['text'];
    final decoded = text is String ? _tryDecodeJsonMap(text) : null;
    if (decoded != null) {
      return AgentResult.success(message: result.message, data: decoded);
    }
    return result;
  }

  final decoded = _tryDecodeJsonMap(result.message);
  if (decoded == null) {
    return result;
  }
  return AgentResult.failure(
    code: decoded['code'] as String? ?? result.code ?? 'adapter_error',
    message: decoded['message'] as String? ?? result.message,
    details: _optionalStringObjectMap(decoded['details']),
  );
}

RegisteredAgentIntent _successIntent({
  required final String name,
  final String namespace = 'contract',
}) => RegisteredAgentIntent(
  descriptor: AgentIntentDescriptor(
    namespace: namespace,
    name: name,
    description: 'Adapter contract success fixture',
    kind: AgentIntentKind.tool,
    inputSchema: const <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'text': <String, Object?>{'type': 'string'},
        'count': <String, Object?>{'type': 'integer'},
      },
      'required': <String>['text', 'count'],
    },
  ),
  execute: (final invocation) async => AgentResult.success(
    data: <String, Object?>{
      'text': invocation.arguments['text'],
      'count': invocation.arguments['count'],
      'qualifiedName': invocation.descriptor.qualifiedName,
    },
  ),
);

RegisteredAgentIntent _failureIntent({required final String name}) =>
    RegisteredAgentIntent(
      descriptor: AgentIntentDescriptor(
        namespace: 'contract',
        name: name,
        description: 'Adapter contract failure fixture',
        kind: AgentIntentKind.tool,
        inputSchema: const <String, Object?>{'type': 'object'},
      ),
      execute: (_) async => AgentResult.failure(
        code: 'contract_failure',
        message: 'Adapter contract expected failure',
        details: const <String, Object?>{'surface': 'adapter_contract'},
      ),
    );

Map<String, Object?>? _tryDecodeJsonMap(final String text) {
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return _toStringObjectMap(decoded);
    }
  } on FormatException {
    return null;
  }
  return null;
}

Map<String, Object?> _toStringObjectMap(final Object? value) {
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.of(value);
  }
  if (value is Map) {
    return value.map<String, Object?>(
      (final key, final value) => MapEntry('$key', value),
    );
  }
  throw AdapterContractViolation('Expected map, got ${value.runtimeType}');
}

Map<String, Object?> _optionalStringObjectMap(final Object? value) =>
    value == null ? const <String, Object?>{} : _toStringObjectMap(value);

void _require(final bool condition, final String message) {
  if (!condition) {
    throw AdapterContractViolation(message);
  }
}
