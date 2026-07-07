import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';

import '../agent_manifest.dart';
import '../catalog/agent_registry_catalog.dart';
import 'manifest_merger.dart';

/// Shared manifest writer used by the CLI and tests.
final class ManifestExporter {
  const ManifestExporter();

  final _merger = const ManifestMerger();

  ManifestExportContext loadExportContext({
    required final String projectRoot,
  }) => _merger.loadExportContext(projectRoot: projectRoot);

  AgentManifest buildManifest({
    required final Iterable<AgentRegistryCatalogEntry> catalog,
    required final ManifestExportContext context,
    final Iterable<AgentEntityTypeDescriptor> entityTypeDescriptors = const [],
  }) => _merger.mergeManifest(
    catalog: catalog,
    policy: context.policy,
    protocolScheme: context.protocolScheme,
    platform: context.platform,
    enabledPlatforms: context.enabledPlatforms,
    entityTypeDescriptors: entityTypeDescriptors,
  );

  String encodeManifest(final AgentManifest manifest) =>
      _merger.encodeManifest(manifest);

  /// Writes or checks [outPath] against merge(catalog, policy).
  ///
  /// Returns `0` on success, `1` on drift or missing file when [checkOnly].
  int exportToFile({
    required final Iterable<AgentRegistryCatalogEntry> catalog,
    required final ManifestExportContext context,
    required final File outPath,
    final Iterable<AgentEntityTypeDescriptor> entityTypeDescriptors = const [],
    final bool checkOnly = false,
  }) {
    final encoded = encodeManifest(
      buildManifest(
        catalog: catalog,
        context: context,
        entityTypeDescriptors: entityTypeDescriptors,
      ),
    );

    if (checkOnly) {
      if (!outPath.existsSync()) {
        return 1;
      }
      return outPath.readAsStringSync() == encoded ? 0 : 1;
    }

    outPath.parent.createSync(recursive: true);
    outPath.writeAsStringSync(encoded);
    return 0;
  }
}
