import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('projects descriptor-derived snapshot fields', () {
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
    final row = projectAgentEntitySnapshot(
      AgentEntitySnapshot(
        ref: const AgentEntityRef(
          namespace: 'projects',
          typeName: 'project',
          identifier: 'project-1',
        ),
        title: 'Fallback title',
        subtitle: 'Fallback subtitle',
        keywords: const <String>['fallback'],
        url: 'https://example.test/projects/project-1',
        deepLink: 'demo://projects/project-1',
        updatedAt: DateTime.utc(2026, 6, 29),
        properties: const <String, Object?>{
          'name': 'Launch project',
          'summary': 'Descriptor-owned summary',
          'tags': <String>['launch', 'work'],
        },
      ),
      descriptor,
    );

    expect(row['projectId'], 'project-1');
    expect(row['id'], 'project-1');
    expect(row['name'], 'Launch project');
    expect(row['summary'], 'Descriptor-owned summary');
    expect(row['tags'], ['launch', 'work']);
    expect(row['title'], 'Fallback title');
    expect(row['subtitle'], 'Fallback subtitle');
    expect(row['keywords'], ['fallback']);
    expect(row['url'], 'https://example.test/projects/project-1');
    expect(row['deepLink'], 'demo://projects/project-1');
    expect(row['updatedAt'], '2026-06-29T00:00:00.000Z');
  });

  test('keeps legacy fields when descriptor uses default names', () {
    final descriptor = AgentEntityTypeDescriptor(
      namespace: 'notes',
      name: 'note',
      identifierName: 'id',
      properties: [
        AgentEntityPropertyDescriptor(
          name: 'title',
          valueType: AgentEntityPropertyValueType.string,
          isDisplay: true,
        ),
      ],
    );
    final row = projectAgentEntitySnapshot(
      AgentEntitySnapshot(
        ref: const AgentEntityRef(
          namespace: 'notes',
          typeName: 'note',
          identifier: 'note-1',
        ),
        title: 'Launch note',
        subtitle: 'Spotlight-ready',
        keywords: const <String>['launch'],
        properties: const <String, Object?>{},
      ),
      descriptor,
    );

    expect(row['id'], 'note-1');
    expect(row['title'], 'Launch note');
    expect(row['subtitle'], 'Spotlight-ready');
    expect(row['keywords'], ['launch']);
  });
}
