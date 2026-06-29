import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform/src/flutter/intentcall_entity_index.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('IntentCallPlatformEntityIndex writes snapshot rows', () async {
    final calls = <String, Object?>{};
    final index = IntentCallPlatformEntityIndex(
      invoke: (final method, final arguments) async {
        calls[method] = arguments;
        return 1;
      },
    );

    final count = await index.upsertSnapshots(
      entityType: 'notes_note',
      snapshots: const <Map<String, Object?>>[
        <String, Object?>{
          'id': 'note-1',
          'title': 'Launch note',
          'subtitle': 'Spotlight-ready',
          'properties': <String, Object?>{'category': 'work'},
        },
      ],
    );

    expect(count, 1);
    final args = calls['upsertEntitySnapshots']! as Map<String, Object?>;
    expect(args['entityType'], 'notes_note');
    expect(args['snapshots'], isA<List>());
    expect((args['snapshots']! as List).single, containsPair('id', 'note-1'));
  });

  test(
    'IntentCallPlatformEntityIndex writes schema snapshots by ref',
    () async {
      final calls = <String, Object?>{};
      final index = IntentCallPlatformEntityIndex(
        invoke: (final method, final arguments) async {
          calls[method] = arguments;
          return 1;
        },
      );

      final count = await index.upsertAgentSnapshots(
        snapshots: [
          AgentEntitySnapshot(
            ref: const AgentEntityRef(
              namespace: 'notes',
              typeName: 'note',
              identifier: 'note-1',
            ),
            title: 'Launch note',
            subtitle: 'Spotlight-ready',
            keywords: const <String>['launch'],
            deepLink: 'demo://entity/notes_note/note-1',
            updatedAt: DateTime.utc(2026, 6, 29),
            properties: const <String, Object?>{'category': 'work'},
          ),
        ],
      );

      expect(count, 1);
      final args = calls['upsertEntitySnapshots']! as Map<String, Object?>;
      expect(args['entityType'], 'notes_note');
      final row = (args['snapshots']! as List).single as Map;
      expect(row['id'], 'note-1');
      expect(row['title'], 'Launch note');
      expect(row['keywords'], ['launch']);
      expect(row['deepLink'], 'demo://entity/notes_note/note-1');
      expect(row['updatedAt'], '2026-06-29T00:00:00.000Z');
    },
  );

  test(
    'IntentCallPlatformEntityIndex writes descriptor-aware snapshot rows',
    () async {
      final calls = <String, Object?>{};
      final index = IntentCallPlatformEntityIndex(
        invoke: (final method, final arguments) async {
          calls[method] = arguments;
          return 1;
        },
      );
      final descriptor = AgentEntityTypeDescriptor(
        namespace: 'projects',
        name: 'project',
        identifierName: 'projectId',
        properties: [
          AgentEntityPropertyDescriptor(
            name: 'name',
            valueType: AgentEntityPropertyValueType.string,
            isDisplay: true,
          ),
          AgentEntityPropertyDescriptor(
            name: 'summary',
            valueType: AgentEntityPropertyValueType.string,
            isSearchable: true,
          ),
          AgentEntityPropertyDescriptor(
            name: 'tags',
            valueType: AgentEntityPropertyValueType.array,
            isSearchable: true,
            isIndexed: true,
          ),
        ],
      );

      final count = await index.upsertAgentSnapshotsForType(
        descriptor: descriptor,
        snapshots: [
          AgentEntitySnapshot(
            ref: const AgentEntityRef(
              namespace: 'projects',
              typeName: 'project',
              identifier: 'project-1',
            ),
            title: 'Fallback title',
            subtitle: 'Fallback subtitle',
            keywords: const <String>['fallback'],
            deepLink: 'demo://projects/project-1',
            properties: const <String, Object?>{
              'name': 'Launch project',
              'summary': 'Descriptor-owned summary',
              'tags': <String>['launch', 'work'],
            },
          ),
        ],
      );

      expect(count, 1);
      final args = calls['upsertEntitySnapshots']! as Map<String, Object?>;
      expect(args['entityType'], 'projects_project');
      final row = (args['snapshots']! as List).single as Map;
      expect(row['projectId'], 'project-1');
      expect(row['id'], 'project-1');
      expect(row['name'], 'Launch project');
      expect(row['summary'], 'Descriptor-owned summary');
      expect(row['tags'], ['launch', 'work']);
      expect(row['title'], 'Fallback title');
      expect(row['subtitle'], 'Fallback subtitle');
      expect(row['keywords'], ['fallback']);
      expect(row['deepLink'], 'demo://projects/project-1');
    },
  );

  test('IntentCallPlatformEntityIndex reads snapshot rows', () async {
    final index = IntentCallPlatformEntityIndex(
      invoke: (final method, final arguments) async => <Map<String, Object?>>[
        <String, Object?>{'id': 'note-1', 'title': 'Launch note'},
      ],
    );

    final rows = await index.searchSnapshots(
      entityType: 'notes_note',
      query: 'launch',
      limit: 3,
    );

    expect(rows.single['id'], 'note-1');
  });

  test('IntentCallPlatformEntityIndex validates entity type and ids', () {
    final index = IntentCallPlatformEntityIndex(
      invoke: (final method, final arguments) async => 0,
    );

    expect(
      () => index.listSnapshots(entityType: 'Notes.Note'),
      throwsArgumentError,
    );
    expect(
      () => index.upsertSnapshots(
        entityType: 'notes_note',
        snapshots: const <Map<String, Object?>>[
          <String, Object?>{'id': ''},
        ],
      ),
      throwsArgumentError,
    );
  });
}
