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
    final bundle = await _loadBundle(projectRoot: projectRoot);
    return bundle.entries;
  }

  Future<List<AgentEntityTypeDescriptor>> loadEntityTypeDescriptors({
    required final String projectRoot,
  }) async {
    final bundle = await _loadBundle(projectRoot: projectRoot);
    return bundle.entityTypeDescriptors;
  }

  Future<_CatalogBundle> _loadBundle({
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

  Future<_CatalogBundle?> _loadFromGeneratedCatalog(
    final String projectRoot,
  ) async {
    final packageName = readPackageName(projectRoot);
    if (packageName == null) {
      return null;
    }

    final probeDir = Directory(p.join(projectRoot, '.dart_tool'))
      ..createSync(recursive: true);
    final probeFile =
        File(p.join(probeDir.path, 'intentcall_catalog_probe.dart'))
          ..writeAsStringSync('''
// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:$packageName/generated/agent_catalog.g.dart';
import 'package:intentcall_core/intentcall_core.dart';
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
  final entities = agentEntityTypeDescriptors
      .map(_entityDescriptorJson)
      .toList(growable: false);
  print(jsonEncode(<String, Object?>{
    'entries': rows,
    'entityTypeDescriptors': entities,
  }));
}

Map<String, Object?> _entityDescriptorJson(final AgentEntityTypeDescriptor descriptor) {
  return <String, Object?>{
    'namespace': descriptor.namespace,
    'name': descriptor.name,
    'identifierName': descriptor.identifierName,
    if (descriptor.displayName != null) 'displayName': descriptor.displayName,
    'privacy': descriptor.privacy.name,
    'deepLinkBehavior': descriptor.deepLinkBehavior.name,
    'openBehavior': descriptor.openBehavior.name,
    'properties': descriptor.properties
        .map(
          (final property) => <String, Object?>{
            'name': property.name,
            'valueType': property.valueType.name,
            'description': property.description,
            'isDisplay': property.isDisplay,
            'isSearchable': property.isSearchable,
            'isIndexed': property.isIndexed,
            if (property.privacy != null) 'privacy': property.privacy!.name,
            if (property.role != AgentEntityPropertyRole.none)
              'role': property.role.name,
          },
        )
        .toList(growable: false),
  };
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
      return const _CatalogBundle(
        entries: <AgentRegistryCatalogEntry>[],
        entityTypeDescriptors: <AgentEntityTypeDescriptor>[],
      );
    }
    final decoded = jsonDecode(stdoutText);
    if (decoded is List) {
      return _CatalogBundle(
        entries: _parseCatalogEntries(decoded),
        entityTypeDescriptors: const <AgentEntityTypeDescriptor>[],
      );
    }
    if (decoded is! Map) {
      return null;
    }
    final map = decoded.cast<String, Object?>();
    final entriesRaw = map['entries'];
    final entitiesRaw = map['entityTypeDescriptors'];
    return _CatalogBundle(
      entries: entriesRaw is List
          ? _parseCatalogEntries(entriesRaw)
          : const <AgentRegistryCatalogEntry>[],
      entityTypeDescriptors: entitiesRaw is List
          ? _parseEntityTypeDescriptors(entitiesRaw)
          : const <AgentEntityTypeDescriptor>[],
    );
  }

  List<AgentRegistryCatalogEntry> _parseCatalogEntries(final List decoded) =>
      decoded.map((final row) {
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

  List<AgentEntityTypeDescriptor> _parseEntityTypeDescriptors(
    final List decoded,
  ) => decoded.map((final row) {
    final map = (row as Map).cast<String, Object?>();
    final propertiesRaw = map['properties'];
    final properties = propertiesRaw is List
        ? propertiesRaw.map((final property) {
            final propertyMap = (property as Map).cast<String, Object?>();
            final privacyName = propertyMap['privacy']?.toString();
            final roleName = propertyMap['role']?.toString();
            return AgentEntityPropertyDescriptor(
              name: '${propertyMap['name']}',
              valueType: AgentEntityPropertyValueType.values.byName(
                '${propertyMap['valueType']}',
              ),
              description: '${propertyMap['description'] ?? ''}',
              isDisplay: propertyMap['isDisplay'] as bool? ?? false,
              isSearchable: propertyMap['isSearchable'] as bool? ?? false,
              isIndexed: propertyMap['isIndexed'] as bool? ?? false,
              privacy: privacyName == null
                  ? null
                  : AgentEntityPrivacy.values.byName(privacyName),
              role: roleName == null
                  ? AgentEntityPropertyRole.none
                  : AgentEntityPropertyRole.values.byName(roleName),
            );
          }).toList()
        : const <AgentEntityPropertyDescriptor>[];
    return AgentEntityTypeDescriptor(
      namespace: '${map['namespace']}',
      name: '${map['name']}',
      identifierName: '${map['identifierName']}',
      displayName: map['displayName']?.toString(),
      properties: properties,
      privacy: AgentEntityPrivacy.values.byName('${map['privacy']}'),
      deepLinkBehavior: AgentEntityDeepLinkBehavior.values.byName(
        '${map['deepLinkBehavior']}',
      ),
      openBehavior: AgentEntityOpenBehavior.values.byName(
        '${map['openBehavior']}',
      ),
    );
  }).toList();

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

final class _CatalogBundle {
  const _CatalogBundle({
    required this.entries,
    required this.entityTypeDescriptors,
  });

  final List<AgentRegistryCatalogEntry> entries;
  final List<AgentEntityTypeDescriptor> entityTypeDescriptors;
}

/// Thrown when the generated catalog cannot be loaded.
final class CatalogLoadException implements Exception {
  CatalogLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
