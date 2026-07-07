import 'package:intentcall_cli/src/catalog/catalog_loader.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

import 'manifest_registry_parity_test.dart';

void main() {
  test('mergeManifest includes entityTypes from catalog descriptors', () {
    const merger = ManifestMerger();
    final manifest = merger.mergeManifest(
      catalog: const <AgentRegistryCatalogEntry>[],
      entityTypeDescriptors: [
        AgentEntityTypeDescriptor(
          namespace: 'app',
          name: 'project',
          identifierName: 'projectId',
          displayName: 'Project',
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
          ],
        ),
      ],
      policy: const ProjectionPolicy(),
    );

    expect(manifest.entityTypes, hasLength(1));
    expect(manifest.entityTypes.single.qualifiedName, 'app_project');
    expect(manifest.entityTypes.single.titleKey, 'name');
    expect(manifest.entityTypes.single.subtitleKey, 'summary');
    expect(manifest.entityTypes.single.keywordsKey, 'keywords');
    expect(manifest.entityTypes.single.snapshotSchema, <String, Object?>{
      'type': 'object',
      'required': <String>['projectId'],
      'properties': <String, Object?>{
        'projectId': <String, Object?>{'type': 'string'},
        'name': <String, Object?>{
          'type': 'string',
          'x-intentcall-display': true,
        },
        'summary': <String, Object?>{
          'type': 'string',
          'x-intentcall-searchable': true,
        },
      },
    });
  });

  test(
    'catalog loader reads entity descriptors from fixture catalog',
    () async {
      final projectRoot = fixtureRoot('entity_catalog_project');
      final descriptors = await const CatalogLoader().loadEntityTypeDescriptors(
        projectRoot: projectRoot,
      );

      expect(descriptors, hasLength(1));
      expect(descriptors.single.qualifiedName, 'app_project');
      expect(descriptors.single.identifierName, 'projectId');
      expect(descriptors.single.displayProperties.map((final p) => p.name), [
        'name',
        'summary',
      ]);
      expect(
        descriptors.single.properties
            .singleWhere((final p) => p.role == AgentEntityPropertyRole.title)
            .name,
        'name',
      );
    },
  );

  test('manifest export includes entityTypes from fixture catalog', () async {
    final projectRoot = fixtureRoot('entity_catalog_project');
    const exporter = ManifestExporter();
    final context = exporter.loadExportContext(projectRoot: projectRoot);
    final catalog = await const CatalogLoader().load(projectRoot: projectRoot);
    final entityTypeDescriptors = await const CatalogLoader()
        .loadEntityTypeDescriptors(projectRoot: projectRoot);

    final manifest = exporter.buildManifest(
      catalog: catalog,
      context: context,
      entityTypeDescriptors: entityTypeDescriptors,
    );

    expect(manifest.entityTypes, hasLength(1));
    expect(manifest.entityTypes.single.qualifiedName, 'app_project');
    expect(manifest.entityTypes.single.titleKey, 'name');
    expect(manifest.entityTypes.single.subtitleKey, 'summary');
    expect(
      (manifest.entityTypes.single.snapshotSchema['properties']!
          as Map)['name']['x-intentcall-role'],
      'title',
    );
  });
}
