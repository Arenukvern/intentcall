import 'package:intentcall_core/intentcall_core.dart';
import 'package:test/test.dart';

void main() {
  test('entity identifier names use snapshot field syntax', () {
    expect(
      AgentEntityTypeDescriptor(
        namespace: 'projects',
        name: 'project',
        identifierName: 'projectId',
      ).identifierName,
      'projectId',
    );
    expect(
      () => AgentEntityTypeDescriptor(
        namespace: 'projects',
        name: 'project',
        identifierName: 'project-id',
      ),
      throwsArgumentError,
    );
  });

  test('registers, lists, gets, and unregisters entity types', () {
    final registry = InMemoryAgentRegistry();
    final events = <AgentRegistryEvent>[];
    final subscription = registry.events.listen(events.add);
    addTearDown(subscription.cancel);

    final descriptor = AgentEntityTypeDescriptor(
      namespace: 'notes',
      name: 'note',
      identifierName: 'id',
      displayName: 'Note',
      deepLinkBehavior: AgentEntityDeepLinkBehavior.optional,
      openBehavior: AgentEntityOpenBehavior.supported,
      properties: <AgentEntityPropertyDescriptor>[
        AgentEntityPropertyDescriptor(
          name: 'id',
          valueType: AgentEntityPropertyValueType.string,
          isIndexed: true,
        ),
        AgentEntityPropertyDescriptor(
          name: 'title',
          valueType: AgentEntityPropertyValueType.string,
          isDisplay: true,
          isSearchable: true,
        ),
      ],
    );

    registry.registerEntityType(descriptor);

    expect(registry.getEntityType('notes_note'), same(descriptor));
    expect(registry.listEntityTypes().single, same(descriptor));
    expect(
      registry.listEntityTypes(namespace: 'notes').single,
      same(descriptor),
    );
    expect(registry.listEntityTypes(namespace: 'other'), isEmpty);
    expect(descriptor.displayProperties.single.name, 'title');
    expect(descriptor.searchableProperties.single.name, 'title');
    expect(descriptor.indexedProperties.single.name, 'id');
    expect(events.single, isA<EntityTypeRegistered>());
    expect((events.single as EntityTypeRegistered).qualifiedName, 'notes_note');

    registry.unregisterEntityType('notes_note');

    expect(registry.getEntityType('notes_note'), isNull);
    expect(events.last, isA<EntityTypeUnregistered>());
    expect((events.last as EntityTypeUnregistered).qualifiedName, 'notes_note');
  });
}
