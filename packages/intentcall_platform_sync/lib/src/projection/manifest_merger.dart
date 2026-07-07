import 'dart:convert';
import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../agent_manifest.dart';
import '../catalog/agent_registry_catalog.dart';
import 'projection_policy.dart';

/// Inputs for [ManifestMerger.mergeManifest] loaded from host config.
final class ManifestExportContext {
  const ManifestExportContext({
    required this.policy,
    required this.platform,
    required this.manifestRelativePath,
    this.protocolScheme,
    this.enabledPlatforms = const [],
  });

  final ProjectionPolicy policy;
  final String? protocolScheme;
  final String platform;
  final String manifestRelativePath;

  /// From `intentcall.yaml` `platforms.enabled` — scopes default surface families.
  final List<String> enabledPlatforms;
}

/// Merges registry catalog rows and projection policy into [agent_manifest.json].
final class ManifestMerger {
  const ManifestMerger();

  AgentManifest mergeManifest({
    required final Iterable<AgentRegistryCatalogEntry> catalog,
    required final ProjectionPolicy policy,
    final String? protocolScheme,
    final Iterable<AgentEntityTypeDescriptor> entityTypeDescriptors = const [],
    final Iterable<Map<String, Object?>> entityTypes = const [],
    final String platform = 'unified',
    final Iterable<String> enabledPlatforms = const [],
  }) {
    final defaultSurfaces = policy.resolvedDefaultSurfaces(
      enabledPlatforms: enabledPlatforms,
    );
    final entries = <AgentManifestEntry>[];
    for (final row in catalog) {
      final descriptor = row.resolveDescriptor();
      final overlay = row.projection ?? policy.overlayFor(row.qualifiedName);
      final dispatchMode = overlay?.dispatchMode ?? policy.defaultDispatchMode;
      final inlineRuntime = overlay?.inlineRuntime;
      if (dispatchMode == AgentManifestDispatchMode.inlineRuntime &&
          inlineRuntime == null) {
        throw FormatException(
          'dispatchMode inlineRuntime requires inlineRuntime for '
          '"${row.qualifiedName}".',
        );
      }
      final surfaces =
          overlay?.resolveSurfaces(defaults: defaultSurfaces) ??
          defaultSurfaces;
      entries.add(
        AgentManifestEntry(
          qualifiedName: row.qualifiedName,
          namespace: descriptor.namespace,
          name: descriptor.name,
          description: descriptor.description,
          kind: descriptor.kind,
          inputSchema: descriptor.inputSchema,
          dispatchMode: dispatchMode,
          inlineRuntime: inlineRuntime,
          surfaces: surfaces,
          resourceUri: descriptor.resourceUri,
        ),
      );
    }

    final mergedEntities = <AgentManifestEntityType>[
      ...entityTypeDescriptors.map(_entityFromDescriptor),
      ...entityTypes.map(AgentManifestEntityType.fromJson),
    ];

    return AgentManifest(
      version: kAgentManifestSchemaVersion,
      platform: platform,
      entries: entries,
      entityTypes: mergedEntities,
      protocolScheme: protocolScheme,
    );
  }

  String encodeManifest(final AgentManifest manifest) =>
      '${manifest.encode()}\n';

  ProjectionPolicy loadProjectionPolicy({
    required final String projectRoot,
    final String configFileName = 'intentcall.yaml',
  }) {
    final configFile = File(p.join(projectRoot, configFileName));
    if (!configFile.existsSync()) {
      return const ProjectionPolicy();
    }
    final doc = loadYaml(configFile.readAsStringSync());
    if (doc is! YamlMap) {
      return const ProjectionPolicy();
    }
    return ProjectionPolicy.fromYamlMap(doc);
  }

  String readPlatformLabel(final String projectRoot) {
    final configFile = File(p.join(projectRoot, 'intentcall.yaml'));
    if (!configFile.existsSync()) {
      return 'unified';
    }
    final doc = loadYaml(configFile.readAsStringSync());
    if (doc is! YamlMap) {
      return 'unified';
    }
    final host = doc['host']?.toString().trim();
    return host == 'jaspr' ? 'web' : 'unified';
  }

  String readManifestRelativePath(final String projectRoot) {
    final configFile = File(p.join(projectRoot, 'intentcall.yaml'));
    if (!configFile.existsSync()) {
      return 'web/agent_manifest.json';
    }
    final doc = loadYaml(configFile.readAsStringSync());
    if (doc is! YamlMap) {
      return 'web/agent_manifest.json';
    }
    final layout = doc['layout'];
    if (layout is YamlMap) {
      final manifest = layout['manifest']?.toString().trim();
      if (manifest != null && manifest.isNotEmpty) {
        return manifest;
      }
    }
    return 'web/agent_manifest.json';
  }

  ManifestExportContext loadExportContext({
    required final String projectRoot,
  }) => ManifestExportContext(
    policy: loadProjectionPolicy(projectRoot: projectRoot),
    protocolScheme: readProtocolScheme(projectRoot),
    platform: readPlatformLabel(projectRoot),
    manifestRelativePath: readManifestRelativePath(projectRoot),
    enabledPlatforms: readEnabledPlatforms(projectRoot),
  );

  List<String> readEnabledPlatforms(final String projectRoot) {
    final configFile = File(p.join(projectRoot, 'intentcall.yaml'));
    if (!configFile.existsSync()) {
      return const [];
    }
    final doc = loadYaml(configFile.readAsStringSync());
    if (doc is! YamlMap) {
      return const [];
    }
    final platforms = doc['platforms'];
    if (platforms is! YamlMap) {
      return const [];
    }
    final enabled = platforms['enabled'];
    if (enabled is! YamlList) {
      return const [];
    }
    return enabled
        .map((final value) => value?.toString().trim().toLowerCase() ?? '')
        .where((final value) => value.isNotEmpty)
        .toList();
  }

  String? readProtocolScheme(final String projectRoot) {
    final configFile = File(p.join(projectRoot, 'intentcall.yaml'));
    if (!configFile.existsSync()) {
      return null;
    }
    final doc = loadYaml(configFile.readAsStringSync());
    if (doc is! YamlMap) {
      return null;
    }
    final scheme = doc['protocolScheme']?.toString().trim();
    return scheme == null || scheme.isEmpty ? null : scheme;
  }
}

AgentManifestEntityType _entityFromDescriptor(
  final AgentEntityTypeDescriptor descriptor,
) {
  final json =
      jsonDecode(generateEntityManifestJson(descriptor))
          as Map<String, Object?>;
  return AgentManifestEntityType.fromJson(json);
}

/// Shared entity projection JSON for one descriptor.
String generateEntityManifestJson(final AgentEntityTypeDescriptor descriptor) {
  final displayProperties = descriptor.displayProperties.toList();
  final searchableProperties = descriptor.searchableProperties.toList();
  final titleKey = displayProperties.isNotEmpty
      ? displayProperties.first.name
      : 'title';
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'qualifiedName': descriptor.qualifiedName,
    'namespace': descriptor.namespace,
    'name': descriptor.name,
    'displayName': descriptor.displayName ?? descriptor.name,
    'idKey': descriptor.identifierName,
    'titleKey': titleKey,
    'subtitleKey': 'subtitle',
    'keywordsKey': 'keywords',
    'snapshotSchema': const <String, Object?>{'type': 'object'},
  });
}
