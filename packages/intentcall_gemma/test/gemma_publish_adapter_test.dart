import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_gemma/intentcall_gemma.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('GemmaPublishAdapter registers tools and invokes registry', () async {
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'gemma',
            name: 'sum',
            description: 'add numbers',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'a': <String, Object?>{'type': 'integer'},
              },
            },
          ),
          execute: (final inv) async => AgentResult.success(
            data: <String, Object?>{
              'sum': (inv.arguments['a'] as int? ?? 0) + 1,
            },
          ),
        ),
      );

    final invokers = <String, GemmaToolInvoker>{};
    final adapter = GemmaPublishAdapter(
      register: (final def, final invoker) => invokers[def.name] = invoker,
      unregister: (_) {},
    );

    await adapter.attach(registry);
    expect(invokers, contains('gemma_sum'));

    final out = await invokers['gemma_sum']!(const <String, Object?>{'a': 2});
    expect(out['ok'], isTrue);
    expect(out['sum'], 3);

    await adapter.detach();
  });

  test(
    'GemmaPublishAdapter registers overridden attach-time tool keys',
    () async {
      final registry = InMemoryAgentRegistry()
        ..register(
          RegisteredAgentIntent(
            descriptor: AgentIntentDescriptor(
              namespace: 'gemma',
              name: 'sum',
              description: 'add numbers',
              kind: AgentIntentKind.tool,
              inputSchema: const <String, Object?>{'type': 'object'},
            ),
            execute: (_) async =>
                AgentResult.success(data: const <String, Object?>{'sum': 5}),
          ),
          qualifiedNameOverride: 'custom_sum',
        );

      final invokers = <String, GemmaToolInvoker>{};
      final adapter = GemmaPublishAdapter(
        register: (final def, final invoker) => invokers[def.name] = invoker,
        unregister: (_) {},
      );

      await adapter.attach(registry);

      expect(invokers, contains('custom_sum'));
      expect(invokers, isNot(contains('gemma_sum')));
      final out = await invokers['custom_sum']!(const <String, Object?>{});
      expect(out['ok'], isTrue);
      expect(out['sum'], 5);

      await adapter.detach();
    },
  );
}
