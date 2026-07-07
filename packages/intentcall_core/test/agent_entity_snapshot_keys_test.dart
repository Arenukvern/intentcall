import 'package:intentcall_core/intentcall_core.dart';
import 'package:test/test.dart';

AgentEntityTypeDescriptor _projectFixtureDescriptor({
  final Iterable<AgentEntityPropertyDescriptor> properties =
      const <AgentEntityPropertyDescriptor>[],
}) {
  return AgentEntityTypeDescriptor(
    namespace: 'app',
    name: 'project',
    identifierName: 'project_id',
    displayName: 'Project',
    properties: properties,
  );
}

void main() {
  group('AgentEntitySnapshotKeys.fromDescriptor', () {
    test('derives keys from display/searchable heuristics', () {
      final keys = AgentEntitySnapshotKeys.fromDescriptor(
        _projectFixtureDescriptor(
          properties: [
            AgentEntityPropertyDescriptor(
              name: 'name',
              valueType: AgentEntityPropertyValueType.string,
              isDisplay: true,
              isSearchable: true,
              isIndexed: true,
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
            ),
          ],
        ),
      );

      expect(keys.idKey, 'project_id');
      expect(keys.titleKey, 'name');
      expect(keys.subtitleKey, 'summary');
      expect(keys.keywordsKey, 'tags');
    });

    test('prefers explicit role over heuristics', () {
      final keys = AgentEntitySnapshotKeys.fromDescriptor(
        _projectFixtureDescriptor(
          properties: [
            AgentEntityPropertyDescriptor(
              name: 'name',
              valueType: AgentEntityPropertyValueType.string,
              isDisplay: true,
              isSearchable: true,
            ),
            AgentEntityPropertyDescriptor(
              name: 'headline',
              valueType: AgentEntityPropertyValueType.string,
              role: AgentEntityPropertyRole.title,
            ),
            AgentEntityPropertyDescriptor(
              name: 'blurb',
              valueType: AgentEntityPropertyValueType.string,
              role: AgentEntityPropertyRole.subtitle,
            ),
            AgentEntityPropertyDescriptor(
              name: 'labels',
              valueType: AgentEntityPropertyValueType.array,
              role: AgentEntityPropertyRole.keywords,
            ),
          ],
        ),
      );

      expect(keys.titleKey, 'headline');
      expect(keys.subtitleKey, 'blurb');
      expect(keys.keywordsKey, 'labels');
    });

    test('throws when duplicate explicit roles are declared', () {
      expect(
        () => AgentEntitySnapshotKeys.fromDescriptor(
          _projectFixtureDescriptor(
            properties: [
              AgentEntityPropertyDescriptor(
                name: 'title_a',
                valueType: AgentEntityPropertyValueType.string,
                role: AgentEntityPropertyRole.title,
              ),
              AgentEntityPropertyDescriptor(
                name: 'title_b',
                valueType: AgentEntityPropertyValueType.string,
                role: AgentEntityPropertyRole.title,
              ),
            ],
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (final error) => error.message,
            'message',
            contains('Duplicate entity property role title'),
          ),
        ),
      );
    });

    test('uses legacy default key names when properties are absent', () {
      final keys = AgentEntitySnapshotKeys.fromDescriptor(
        AgentEntityTypeDescriptor(
          namespace: 'notes',
          name: 'note',
          identifierName: 'id',
        ),
      );

      expect(keys.idKey, 'id');
      expect(keys.titleKey, 'title');
      expect(keys.subtitleKey, 'subtitle');
      expect(keys.keywordsKey, 'keywords');
    });
  });
}
