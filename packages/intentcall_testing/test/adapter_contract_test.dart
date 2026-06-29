import 'dart:async';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:intentcall_testing/intentcall_testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'verifyNativeAdapterContract proves the shared adapter contract',
    () async {
      final adapter = _MapAdapter();

      final proof = await verifyNativeAdapterContract(
        adapter: adapter,
        isPublished: adapter.isPublished,
        invoke: adapter.invoke,
        normalize: normalizeAdapterMapResult,
      );

      expect(proof.adapterId, 'map');
      expect(proof.initialToolName, 'contract_echo');
      expect(proof.overriddenToolName, 'custom_override');
      expect(proof.failureCode, 'contract_failure');
      expect(proof.hotSyncProven, isTrue);
      expect(proof.detachCleanupProven, isTrue);
    },
  );

  test('normalizeJsonTextAgentResult unwraps JSON text envelopes', () {
    final success = normalizeJsonTextAgentResult(
      AgentResult.success(
        data: const <String, Object?>{'text': '{"text":"hello","count":2}'},
      ),
    );

    expect(success.ok, isTrue);
    expect(success.data['text'], 'hello');
    expect(success.data['count'], 2);

    final failure = normalizeJsonTextAgentResult(
      AgentResult.failure(
        code: 'transport_error',
        message:
            '{"code":"contract_failure","message":"failed","details":{"surface":"adapter_contract"}}',
      ),
    );

    expect(failure.ok, isFalse);
    expect(failure.code, 'contract_failure');
    expect(failure.details['surface'], 'adapter_contract');
  });
}

final class _MapAdapter implements AgentAdapter {
  final Map<String, Future<Map<String, Object?>> Function(AgentArguments)>
  _published = {};

  StreamSubscription<AgentRegistryEvent>? _events;
  AgentRegistry? _registry;

  @override
  String get id => 'map';

  @override
  bool get watchesRegistry => true;

  bool isPublished(final String qualifiedName) =>
      _published.containsKey(qualifiedName);

  Future<Map<String, Object?>> invoke(
    final String qualifiedName,
    final AgentArguments arguments,
  ) {
    final invoker = _published[qualifiedName];
    if (invoker == null) {
      throw StateError('No published tool for $qualifiedName');
    }
    return invoker(arguments);
  }

  @override
  Future<void> attach(final AgentRegistry registry) async {
    _registry = registry;
    for (final entry in registry.listEntries()) {
      _publish(registry, key: entry.key, descriptor: entry.descriptor);
    }
    _events = registry.events.listen((final event) {
      final reg = _registry;
      if (reg == null) return;
      switch (event) {
        case IntentRegistered(:final qualifiedName):
          final intent = reg.get(qualifiedName);
          if (intent != null) {
            _publish(reg, key: qualifiedName, descriptor: intent.descriptor);
          }
        case IntentUnregistered(:final qualifiedName):
          _published.remove(qualifiedName);
        case EntityTypeRegistered() || EntityTypeUnregistered():
          break;
      }
    });
  }

  @override
  Future<void> detach() async {
    await _events?.cancel();
    _events = null;
    _published.clear();
    _registry = null;
  }

  void _publish(
    final AgentRegistry registry, {
    required final String key,
    required final AgentIntentDescriptor descriptor,
  }) {
    if (descriptor.kind != AgentIntentKind.tool) return;
    final name = key;
    _published[name] = (final arguments) async {
      final result = await registry.invoke(name, arguments);
      if (!result.ok) {
        return <String, Object?>{
          'ok': false,
          'code': result.code,
          'message': result.message,
          'details': result.details,
        };
      }
      return <String, Object?>{'ok': true, ...result.data};
    };
  }
}
