import 'dart:convert';
import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;

import '../utils/cli_utils.dart';

/// Loads registry catalog rows for [ManifestMerger].
final class CatalogLoader {
  const CatalogLoader();

  static const catalogRelativePath = 'lib/generated/agent_catalog.g.dart';

  Future<List<AgentRegistryCatalogEntry>> load({
    required final String projectRoot,
  }) async {
    final root = p.normalize(p.absolute(projectRoot));
    final catalogFile = File(p.join(root, catalogRelativePath));
    if (!catalogFile.existsSync()) {
      throw CatalogLoadException(
        'Missing $catalogRelativePath — run '
        '`dart run build_runner build --delete-conflicting-outputs`.',
      );
    }
    final fromProbe = await _loadFromGeneratedCatalog(root);
    if (fromProbe != null) {
      return fromProbe;
    }
    throw CatalogLoadException(
      'Failed to load $catalogRelativePath — run '
      '`dart run build_runner build --delete-conflicting-outputs` and ensure '
      'the package compiles.',
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
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

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
      if (row.projection != null) 'projection': _projectionJson(row.projection!),
    });
  }
  print(jsonEncode(rows));
}

Map<String, Object?> _projectionJson(final EntryProjection projection) {
  return <String, Object?>{
    if (projection.dispatchMode != null)
      'dispatchMode': projection.dispatchMode!.name,
  'surfaces': <String, bool>{
      for (final entry in projection.surfaces.entries)
        entry.key.manifestKey: entry.value,
    },
  };
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
      EntryProjection? projection;
      final projectionRaw = map['projection'];
      if (projectionRaw is Map) {
        projection = _projectionFromJson(
          projectionRaw.cast<String, Object?>(),
        );
      }
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
        projection: projection,
      );
    }).toList();
  }

  EntryProjection _projectionFromJson(final Map<String, Object?> json) {
    final dispatchName = json['dispatchMode']?.toString();
    final dispatchMode = dispatchName == null
        ? null
        : AgentManifestDispatchMode.values.byName(dispatchName);
    final surfaces = <AgentManifestSurface, bool>{};
    final surfacesRaw = json['surfaces'];
    if (surfacesRaw is Map) {
      for (final entry in surfacesRaw.entries) {
        surfaces[resolveAgentManifestSurface('${entry.key}')] =
            entry.value as bool;
      }
    }
    return EntryProjection(dispatchMode: dispatchMode, surfaces: surfaces);
  }
}

/// Thrown when the generated catalog cannot be loaded.
final class CatalogLoadException implements Exception {
  CatalogLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
