import 'dart:convert';
import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../utils/cli_utils.dart';

/// Loads registry catalog rows for [ManifestMerger].
final class CatalogLoader {
  const CatalogLoader();

  static const catalogRelativePath = 'lib/generated/agent_catalog.g.dart';

  Future<List<AgentRegistryCatalogEntry>> load({
    required final String projectRoot,
    required final File manifestOut,
  }) async {
    final catalogFile = File(p.join(projectRoot, catalogRelativePath));
    if (catalogFile.existsSync()) {
      final fromProbe = await _loadFromGeneratedCatalog(projectRoot);
      if (fromProbe != null) {
        return fromProbe;
      }
    }
    return _loadFromProjectionAndManifest(
      projectRoot: projectRoot,
      manifestOut: manifestOut,
    );
  }

  Future<List<AgentRegistryCatalogEntry>?> _loadFromGeneratedCatalog(
    final String projectRoot,
  ) async {
    final packageName = readPackageName(projectRoot);
    if (packageName == null) {
      return null;
    }

    final probeDir = Directory(p.join(projectRoot, '.dart_tool'));
    probeDir.createSync(recursive: true);
    final probeFile = File(p.join(probeDir.path, 'intentcall_catalog_probe.dart'));
    probeFile.writeAsStringSync('''
// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:$packageName/generated/agent_catalog.g.dart';

void main() {
  final rows = <Map<String, Object?>>[];
  for (final row in agentCatalogEntries) {
    final descriptor = row.resolveDescriptor();
    rows.add(<String, Object?>{
      'registryKey': row.registryKey,
      'qualifiedName': descriptor.qualifiedName,
      'namespace': descriptor.namespace,
      'name': descriptor.name,
      'description': descriptor.description,
      'kind': descriptor.kind.name,
      'inputSchema': descriptor.inputSchema,
      if (descriptor.resourceUri != null) 'resourceUri': descriptor.resourceUri,
    });
  }
  print(jsonEncode(rows));
}
''');

    final result = await Process.run(
      'dart',
      <String>['run', probeFile.path],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      return null;
    }
    final stdoutText = '${result.stdout}'.trim();
    if (stdoutText.isEmpty) {
      return const <AgentRegistryCatalogEntry>[];
    }
    final decoded = jsonDecode(stdoutText);
    if (decoded is! List) {
      return null;
    }
    return decoded.map((final row) {
      final map = (row as Map).cast<String, Object?>();
      return AgentRegistryCatalogEntry(
        registryKey: '${map['registryKey']}',
        descriptor: AgentIntentDescriptor(
          namespace: '${map['namespace']}',
          name: '${map['name']}',
          description: '${map['description']}',
          kind: AgentIntentKind.values.byName('${map['kind']}'),
          inputSchema: Map<String, Object?>.from(
            (map['inputSchema'] as Map?)?.cast<String, Object?>() ??
                const <String, Object?>{'type': 'object'},
          ),
          resourceUri: map['resourceUri']?.toString(),
        ),
      );
    }).toList();
  }

  List<AgentRegistryCatalogEntry> _loadFromProjectionAndManifest({
    required final String projectRoot,
    required final File manifestOut,
  }) {
    final merger = ManifestMerger();
    final overlayPaths = <String>[
      if (loadIntentCallConfig(projectRoot)?.projectionOverlay case final String path)
        p.isAbsolute(path) ? path : p.join(projectRoot, path),
      p.join(projectRoot, '.intentcall', 'projection.yaml'),
    ];

    final overlayKeys = <String>{};
    for (final overlayPath in overlayPaths) {
      final overlays = merger.loadOverlayFile(overlayPath);
      overlayKeys.addAll(overlays.keys);
    }

    if (!manifestOut.existsSync()) {
      return const <AgentRegistryCatalogEntry>[];
    }

    final manifest = AgentManifest.parse(manifestOut.readAsStringSync());
    final tools = overlayKeys.isEmpty
        ? manifest.tools
        : manifest.tools.where(
            (final tool) => overlayKeys.contains(tool.qualifiedName),
          );

    return tools
        .map(
          (final tool) => AgentRegistryCatalogEntry(
            registryKey: tool.qualifiedName,
            descriptor: tool.toDescriptor(),
          ),
        )
        .toList();
  }
}

/// Reads optional `.intentcall/projection.yaml` for diagnostics.
Map<String, Object?> scanProjectionYaml(final String projectRoot) {
  final file = File(p.join(projectRoot, '.intentcall', 'projection.yaml'));
  if (!file.existsSync()) {
    return const <String, Object?>{};
  }
  final doc = loadYaml(file.readAsStringSync());
  if (doc is! YamlMap) {
    return const <String, Object?>{};
  }
  return doc.cast<String, Object?>();
}
