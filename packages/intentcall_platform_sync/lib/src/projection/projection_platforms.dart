import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'manifest_merger.dart';

/// Parses comma-separated or repeated platform labels.
List<String> parsePlatformList(final Iterable<String>? values) {
  final out = <String>{};
  for (final value in values ?? const <String>[]) {
    for (final part in value.split(',')) {
      final trimmed = part.trim().toLowerCase();
      if (trimmed.isNotEmpty) {
        out.add(trimmed);
      }
    }
  }
  return out.toList()..sort();
}

/// Resolves platform sync targets from overrides, config, or host defaults.
List<String> resolveProjectionPlatforms({
  required final String projectRoot,
  final Iterable<String>? overridePlatforms,
}) {
  final override = parsePlatformList(overridePlatforms);
  if (override.isNotEmpty) {
    return override;
  }

  final enabled = const ManifestMerger().readEnabledPlatforms(projectRoot);
  if (enabled.isNotEmpty) {
    return enabled;
  }

  final configFile = File(p.join(projectRoot, 'intentcall.yaml'));
  if (!configFile.existsSync()) {
    return const [];
  }
  final doc = loadYaml(configFile.readAsStringSync());
  if (doc is! YamlMap) {
    return const [];
  }
  final host = doc['host']?.toString().trim().toLowerCase();
  return switch (host) {
    'jaspr' => const <String>['web'],
    'flutter' => const <String>[
      'web',
      'android',
      'ios',
      'macos',
      'linux',
      'windows',
    ],
    _ => const <String>[],
  };
}
