import 'dart:io';

import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;

/// Result of running the IntentCall projection hook spine in-process.
final class IntentCallHookResult {
  const IntentCallHookResult({
    required this.projectRoot,
    required this.platforms,
    required this.checkOnly,
    required this.dependencies,
    this.manifestPath,
    this.syncChanged = false,
  });

  final String projectRoot;
  final List<String> platforms;
  final bool checkOnly;
  final List<Uri> dependencies;
  final String? manifestPath;
  final bool syncChanged;
}

/// In-process manifest export + platform sync spine for Dart SDK hooks.
final class IntentCallHookRunner {
  const IntentCallHookRunner({
    this.exporter = const ManifestExporter(),
    this.catalogLoader = const CatalogLoader(),
    this.sync = const PlatformSync(),
  });

  final ManifestExporter exporter;
  final CatalogLoader catalogLoader;
  final PlatformSync sync;

  Future<IntentCallHookResult> run({
    required final String projectRoot,
    final Iterable<String>? platforms,
    final bool checkOnly = false,
  }) async {
    final root = p.normalize(p.absolute(projectRoot));
    final resolvedPlatforms = resolveProjectionPlatforms(
      projectRoot: root,
      overridePlatforms: platforms,
    );
    if (resolvedPlatforms.isEmpty) {
      throw StateError(
        'No projection platforms resolved — set platforms.enabled in '
        'intentcall.yaml or hooks.user_defines.intentcall_hooks.platforms.',
      );
    }

    final context = exporter.loadExportContext(projectRoot: root);
    final manifestFile = File(p.join(root, context.manifestRelativePath));
    final catalog = await catalogLoader.load(projectRoot: root);
    final entityTypeDescriptors = await catalogLoader.loadEntityTypeDescriptors(
      projectRoot: root,
    );

    final manifestExitCode = exporter.exportToFile(
      catalog: catalog,
      context: context,
      outPath: manifestFile,
      entityTypeDescriptors: entityTypeDescriptors,
      checkOnly: checkOnly,
    );
    if (manifestExitCode != 0) {
      throw StateError(
        checkOnly
            ? 'Manifest drift at ${manifestFile.path} — run intentcall manifest export'
            : 'Failed to write manifest at ${manifestFile.path}',
      );
    }

    var syncChanged = false;
    if (checkOnly) {
      final ok = sync.checkPlatforms(root, resolvedPlatforms);
      if (!ok) {
        throw StateError(
          'Platform artifact drift for $resolvedPlatforms — run intentcall platform sync',
        );
      }
    } else {
      final result = sync.syncPlatforms(
        projectRoot: root,
        platforms: resolvedPlatforms,
      );
      syncChanged = result.changed;
    }

    return IntentCallHookResult(
      projectRoot: root,
      platforms: resolvedPlatforms,
      checkOnly: checkOnly,
      manifestPath: manifestFile.path,
      syncChanged: syncChanged,
      dependencies: projectionHookDependencies(
        projectRoot: root,
        manifestPath: manifestFile.path,
      ),
    );
  }
}

/// Cache dependencies for the IntentCall projection hook spine.
List<Uri> projectionHookDependencies({
  required final String projectRoot,
  required final String manifestPath,
}) {
  final root = p.normalize(p.absolute(projectRoot));
  return <Uri>[
    File(p.join(root, 'intentcall.yaml')).uri,
    File(p.join(root, CatalogLoader.catalogRelativePath)).uri,
    File(manifestPath).uri,
  ];
}

/// Parses `hooks.user_defines.intentcall_hooks.platforms`.
List<String> parseHookPlatforms(final Object? raw) {
  if (raw == null) {
    return const [];
  }
  if (raw is String) {
    return parsePlatformList(<String>[raw]);
  }
  if (raw is Iterable) {
    return parsePlatformList(raw.map((final value) => '$value'));
  }
  throw const FormatException(
    'hooks.user_defines.intentcall_hooks.platforms must be a string or list.',
  );
}

/// Reads optional `check_only` from hook user-defines.
bool parseHookCheckOnly(final Object? raw) {
  if (raw == null) {
    return false;
  }
  if (raw is bool) {
    return raw;
  }
  throw const FormatException(
    'hooks.user_defines.intentcall_hooks.check_only must be a boolean.',
  );
}
