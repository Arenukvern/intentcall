import 'dart:io';

import 'package:intentcall_cli/src/catalog/catalog_loader.dart';
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
  test('catalog and manifest qualified names match bidirectionally', () async {
    final projectRoot = fixtureRoot('codegen_dart_project');
    final manifestFile = File(p.join(projectRoot, 'web', 'agent_manifest.json'));
    final manifest = AgentManifest.parse(manifestFile.readAsStringSync());
    final catalog = await const CatalogLoader().load(projectRoot: projectRoot);

    final catalogNames = catalog.map((final row) => row.qualifiedName).toSet();
    final manifestNames = manifest.tools.map((final t) => t.qualifiedName).toSet();

    expect(catalogNames, isNotEmpty);
    expect(manifestNames.difference(catalogNames), isEmpty);
    expect(catalogNames.difference(manifestNames), isEmpty);
  });

  test('flutter fixture catalog matches manifest tools', () async {
    final projectRoot = fixtureRoot('flutter_project');
    final manifestFile = File(p.join(projectRoot, 'web', 'agent_manifest.json'));
    final manifest = AgentManifest.parse(manifestFile.readAsStringSync());
    final catalog = await const CatalogLoader().load(projectRoot: projectRoot);

    final catalogNames = catalog.map((final row) => row.qualifiedName).toSet();
    final manifestNames = manifest.tools.map((final t) => t.qualifiedName).toSet();

    expect(catalogNames, manifestNames);
  });

  test('manifest export --check fixture is valid JSON manifest', () {
    final projectRoot = fixtureRoot('flutter_project');
    final manifestFile = File(p.join(projectRoot, 'web', 'agent_manifest.json'));
    final parsed = AgentManifest.parse(manifestFile.readAsStringSync());
    expect(parsed.version, 1);
    expect(parsed.tools, isNotEmpty);
  });
}
