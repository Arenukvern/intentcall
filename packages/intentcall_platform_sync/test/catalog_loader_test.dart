import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String fixtureRoot(final String name) {
  final candidates = <String>[
    p.join('packages', 'intentcall_cli', 'test', 'fixtures', name),
    p.join('test', 'fixtures', name),
  ];
  for (final candidate in candidates) {
    final dir = Directory(candidate);
    if (dir.existsSync()) {
      return p.normalize(p.absolute(candidate));
    }
  }
  throw StateError(
    'fixture $name not found from ${Directory.current.path}',
  );
}

void main() {
  test('loads generated catalog rows from codegen_dart_project', () async {
    final projectRoot = fixtureRoot('codegen_dart_project');
    final catalog = await const CatalogLoader().load(projectRoot: projectRoot);

    expect(catalog, isNotEmpty);
    expect(catalog.first.qualifiedName, isNotEmpty);
  });

  test('loads entity descriptors when present', () async {
    final projectRoot = fixtureRoot('codegen_dart_project');
    final descriptors = await const CatalogLoader().loadEntityTypeDescriptors(
      projectRoot: projectRoot,
    );

    expect(descriptors, isA<List<AgentEntityTypeDescriptor>>());
  });

  test('fails loud when catalog is missing', () async {
    final temp = await Directory.systemTemp.createTemp('intentcall_catalog_');
    addTearDown(temp.deleteSync);

    expect(
      () => const CatalogLoader().load(projectRoot: temp.path),
      throwsA(isA<CatalogLoadException>()),
    );
  });
}
