import 'dart:async';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:intentcall_webmcp/intentcall_webmcp.dart';
import 'package:test/test.dart';

void main() {
  test('WebMcpPublishAdapter publishes tools and invokes registry', () async {
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'hello',
            description: 'say hello',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{'type': 'object'},
          ),
          execute: (_) async =>
              AgentResult.success(data: const <String, Object?>{'text': 'hi'}),
        ),
      );

    final published =
        <String, Future<Map<String, Object?>> Function(Map<String, Object?>)>{};
    final adapter = WebMcpPublishAdapter(
      publish:
          ({
            required final name,
            required final description,
            required final inputSchema,
            required final execute,
          }) {
            published[name] = execute;
          },
      unpublish: (_) {},
    );

    await adapter.attach(registry);
    expect(published, contains('app_hello'));

    final out = await published['app_hello']!(const <String, Object?>{});
    expect(out['ok'], isTrue);
    expect(out['text'], 'hi');

    await adapter.detach();
  });

  test(
    'WebMcpPublishAdapter hot-syncs register and unregister after attach',
    () async {
      final registry = InMemoryAgentRegistry();
      final published =
          <
            String,
            Future<Map<String, Object?>> Function(Map<String, Object?>)
          >{};
      final unpublished = <String>[];
      final adapter = WebMcpPublishAdapter(
        publish:
            ({
              required final name,
              required final description,
              required final inputSchema,
              required final execute,
            }) {
              published[name] = execute;
            },
        unpublish: unpublished.add,
      );

      await adapter.attach(registry);
      expect(published, isEmpty);

      registry.register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'late',
            description: 'registered after attach',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{'type': 'object'},
          ),
          execute: (_) async => AgentResult.success(
            data: const <String, Object?>{'text': 'late'},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(published, contains('app_late'));

      final out = await published['app_late']!(const <String, Object?>{});
      expect(out['ok'], isTrue);
      expect(out['text'], 'late');

      registry.unregister('app_late');
      await Future<void>.delayed(Duration.zero);
      expect(unpublished, contains('app_late'));

      await adapter.detach();
    },
  );

  test(
    'WebMcpPublishAdapter publishes overridden attach-time tool keys',
    () async {
      final registry = InMemoryAgentRegistry()
        ..register(
          RegisteredAgentIntent(
            descriptor: AgentIntentDescriptor(
              namespace: 'app',
              name: 'hello',
              description: 'say hello',
              kind: AgentIntentKind.tool,
              inputSchema: const <String, Object?>{'type': 'object'},
            ),
            execute: (_) async => AgentResult.success(
              data: const <String, Object?>{'text': 'override'},
            ),
          ),
          qualifiedNameOverride: 'custom_hello',
        );
      final published =
          <
            String,
            Future<Map<String, Object?>> Function(Map<String, Object?>)
          >{};
      final adapter = WebMcpPublishAdapter(
        publish:
            ({
              required final name,
              required final description,
              required final inputSchema,
              required final execute,
            }) {
              published[name] = execute;
            },
        unpublish: (_) {},
      );

      await adapter.attach(registry);

      expect(published, contains('custom_hello'));
      expect(published, isNot(contains('app_hello')));
      final out = await published['custom_hello']!(const <String, Object?>{});
      expect(out['ok'], isTrue);
      expect(out['text'], 'override');

      await adapter.detach();
    },
  );

  test(
    'WebMcpPublishAdapter replaces a tool that is published again',
    () async {
      final registry = _ReplaceRegistry();
      final published = <String, String>{};
      final unpublished = <String>[];
      final adapter = WebMcpPublishAdapter(
        publish:
            ({
              required final name,
              required final description,
              required final inputSchema,
              required final execute,
            }) {
              published[name] = description;
            },
        unpublish: unpublished.add,
      );
      await adapter.attach(registry);
      expect(published['app_hello'], 'first');

      registry.retarget('second');
      await Future<void>.delayed(Duration.zero);

      expect(unpublished, contains('app_hello'));
      expect(published['app_hello'], 'second');
      await adapter.detach();
    },
  );
}

final class _ReplaceRegistry implements AgentRegistry {
  _ReplaceRegistry() {
    _intent = _intentWith('first');
  }

  late RegisteredAgentIntent _intent;
  final StreamController<AgentRegistryEvent> _events =
      StreamController<AgentRegistryEvent>.broadcast(sync: true);

  void retarget(final String description) {
    _intent = _intentWith(description);
    _events.add(
      IntentRegistered(timestamp: DateTime.now(), qualifiedName: 'app_hello'),
    );
  }

  RegisteredAgentIntent _intentWith(final String description) =>
      RegisteredAgentIntent(
        descriptor: AgentIntentDescriptor(
          namespace: 'app',
          name: 'hello',
          description: description,
          kind: AgentIntentKind.tool,
          inputSchema: const <String, Object?>{'type': 'object'},
        ),
        execute: (_) async => AgentResult.success(),
      );

  @override
  Stream<AgentRegistryEvent> get events => _events.stream;

  @override
  RegisteredAgentIntent? get(final String qualifiedName) => _intent;

  @override
  Iterable<AgentRegistryEntry> listEntries({final String? namespace}) =>
      <AgentRegistryEntry>[
        AgentRegistryEntry(key: 'app_hello', intent: _intent),
      ];

  @override
  Future<AgentResult> invoke(
    final String qualifiedName,
    final AgentArguments arguments, {
    final String? correlationId,
  }) => Future<AgentResult>.value(AgentResult.success());

  @override
  String qualify({
    required final String namespace,
    required final String name,
  }) => '${namespace}_$name';

  @override
  void register(
    final RegisteredAgentIntent intent, {
    final String? qualifiedNameOverride,
  }) {}

  @override
  void unregister(final String qualifiedName) {}

  @override
  Iterable<AgentIntentDescriptor> listDescriptors({final String? namespace}) =>
      listEntries().map((final entry) => entry.descriptor);

  @override
  void registerEntityType(final AgentEntityTypeDescriptor descriptor) {}

  @override
  void unregisterEntityType(final String qualifiedName) {}

  @override
  AgentEntityTypeDescriptor? getEntityType(final String qualifiedName) => null;

  @override
  Iterable<AgentEntityTypeDescriptor> listEntityTypes({
    final String? namespace,
  }) => const <AgentEntityTypeDescriptor>[];
}
