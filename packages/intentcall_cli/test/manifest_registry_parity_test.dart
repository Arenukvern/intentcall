import 'dart:convert';
import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String fixtureRoot() {
  final candidates = <String>[
    p.join('packages', 'intentcall_cli', 'test', 'fixtures', 'flutter_project'),
    p.join('test', 'fixtures', 'flutter_project'),
  ];
  for (final candidate in candidates) {
    if (File(p.join(candidate, 'web', 'agent_manifest.json')).existsSync()) {
      return candidate;
    }
  }
  throw StateError(
    'flutter_project fixture not found from ${Directory.current.path}',
  );
}

void main() {
  test('manifest tools are subset of fixture registry descriptors', () {
    final fixtureRootPath = fixtureRoot();
    final manifestFile = File(
      p.join(fixtureRootPath, 'web', 'agent_manifest.json'),
    );
    final manifest = AgentManifest.parse(manifestFile.readAsStringSync());
    final registry = InMemoryAgentRegistry();
    registry.register(
      AgentCallEntry.tool(
        namespace: 'app',
        name: 'cart_total',
        description: 'Return cart total',
        inputSchema: const <String, Object?>{'type': 'object'},
        handler: (_) async => AgentResult.success(),
      ).toRegistration(),
    );

    final registryKeys = registry.listEntries().map((final e) => e.key).toSet();
    for (final entry in manifest.tools) {
      expect(
        registryKeys.contains(entry.qualifiedName),
        isTrue,
        reason: 'manifest tool ${entry.qualifiedName} missing from registry',
      );
    }
  });

  test('manifest export --check fixture is valid JSON manifest', () {
    final fixtureRootPath = fixtureRoot();
    final manifestFile = File(
      p.join(fixtureRootPath, 'web', 'agent_manifest.json'),
    );
    final json =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
    expect(json['version'], 1);
    expect(
      AgentManifest.parse(manifestFile.readAsStringSync()).tools,
      isNotEmpty,
    );
  });
}
