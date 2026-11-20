import 'dart:convert';
import 'dart:io';

const publishablePackages = [
  'intentcall_schema',
  'intentcall_core',
  'intentcall_session',
  'intentcall_mcp',
  'intentcall_webmcp',
  'intentcall_codegen',
  'intentcall_platform_sync',
  'intentcall_hooks',
  'intentcall_bridge',
  'intentcall_cli',
  'intentcall_platform',
  'intentcall_platform_apple',
  'intentcall_platform_android',
  'intentcall_testing',
];

const workspaceOnlyPackages = ['intentcall_gemma', 'acp_toolkit'];

const allInternalPackages = [...publishablePackages, ...workspaceOnlyPackages];

const releaseTrainMaintenanceFile = '.release-train-maintenance.json';

Future<void> main(List<String> arguments) async {
  final repoRoot = findRepoRoot();
  final command = arguments.isEmpty ? 'check' : arguments.first;
  final args = arguments.skip(1).toList();

  final code = switch (command) {
    'check' => await runReleaseTrainCheck(repoRoot),
    'sync' => await runReleaseTrainSync(
      repoRoot,
      version: _option(args, '--version'),
      checkOnly: args.contains('--check'),
      force: args.contains('--force'),
    ),
    _ => _usage(),
  };

  exit(code);
}

Directory findRepoRoot() {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    final pubspec = File(joinPath([dir.path, 'pubspec.yaml']));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: intentcall_workspace')) {
      return dir;
    }
    dir = dir.parent;
  }
  return Directory.current;
}

Future<int> runReleaseTrainCheck(Directory repoRoot) async {
  if (await usesPerPackageReleaseTrain(repoRoot)) {
    final manifestVersions = await readManifestVersions(repoRoot);
    final maintenance = await readMaintenanceOverrides(repoRoot);
    final findings = await releaseTrainMaintenanceFindings(
      repoRoot,
      manifestVersions: manifestVersions,
      maintenance: maintenance,
    );
    if (findings.isNotEmpty) {
      stderr.writeln('FAIL: IntentCall release train metadata is stale.');
      for (final finding in findings) {
        stderr.writeln('  - $finding');
      }
      return 1;
    }
    print(
      'OK: IntentCall release train metadata is synchronized (maintenance line).',
    );
    return 0;
  }

  final version = await resolveReleaseTrainVersion(repoRoot);
  final findings = await releaseTrainFindings(repoRoot, version: version);
  if (findings.isNotEmpty) {
    stderr.writeln('FAIL: IntentCall release train metadata is stale.');
    stderr.writeln('Run: dart tool/intentcall/bin/release_train.dart sync');
    for (final finding in findings) {
      stderr.writeln('  - $finding');
    }
    return 1;
  }
  print('OK: IntentCall release train metadata is synchronized at $version.');
  return 0;
}

Future<int> runReleaseTrainSync(
  Directory repoRoot, {
  String? version,
  bool checkOnly = false,
  bool force = false,
}) async {
  if (!force && await usesPerPackageReleaseTrain(repoRoot)) {
    stderr.writeln(
      'FAIL: maintenance-line metadata is active (.release-train-maintenance.json '
      'or divergent .release-please-manifest.json). '
      'sync is blocked; use sync --force only to restore lockstep train.',
    );
    return 1;
  }

  final targetVersion = version ?? await resolveReleaseTrainVersion(repoRoot);
  final edits = await syncReleaseTrainMetadata(
    repoRoot,
    version: targetVersion,
    write: !checkOnly,
  );

  if (checkOnly) {
    if (edits.isNotEmpty) {
      stderr.writeln('FAIL: IntentCall release train metadata needs sync.');
      for (final edit in edits) {
        stderr.writeln('  - $edit');
      }
      return 1;
    }
    print(
      'OK: IntentCall release train metadata is synchronized at $targetVersion.',
    );
    return 0;
  }

  if (edits.isEmpty) {
    print('OK: IntentCall release train metadata already at $targetVersion.');
  } else {
    print('Updated IntentCall release train metadata to $targetVersion:');
    for (final edit in edits) {
      print('  - $edit');
    }
  }
  return 0;
}

Future<bool> usesPerPackageReleaseTrain(Directory repoRoot) async {
  if (File(joinPath([repoRoot.path, releaseTrainMaintenanceFile])).existsSync()) {
    return true;
  }
  final manifestVersions = await readManifestVersions(repoRoot);
  return manifestVersions.values.toSet().length > 1;
}

Future<Map<String, String>> readManifestVersions(Directory repoRoot) async {
  final manifest = File(
    joinPath([repoRoot.path, '.release-please-manifest.json']),
  );
  final versions = <String, String>{};
  if (!manifest.existsSync()) {
    return versions;
  }
  final decoded = jsonDecode(await manifest.readAsString());
  if (decoded is! Map<String, Object?>) {
    return versions;
  }
  for (final packageName in publishablePackages) {
    final value = decoded['packages/$packageName'];
    if (value is String && value.isNotEmpty) {
      versions[packageName] = value;
    }
  }
  return versions;
}

final class ReleaseTrainMaintenanceOverride {
  const ReleaseTrainMaintenanceOverride({
    required this.version,
    this.dependencyFloors = const {},
  });

  final String version;
  final Map<String, String> dependencyFloors;
}

Future<Map<String, ReleaseTrainMaintenanceOverride>>
readMaintenanceOverrides(Directory repoRoot) async {
  final file = File(joinPath([repoRoot.path, releaseTrainMaintenanceFile]));
  if (!file.existsSync()) {
    return {};
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, Object?>) {
    throw StateError('$releaseTrainMaintenanceFile must be a JSON object.');
  }
  final overrides = <String, ReleaseTrainMaintenanceOverride>{};
  for (final entry in decoded.entries) {
    final packageName = entry.key;
    if (!publishablePackages.contains(packageName)) {
      continue;
    }
    final value = entry.value;
    if (value is! Map<String, Object?>) {
      throw StateError(
        '$releaseTrainMaintenanceFile.$packageName must be an object.',
      );
    }
    final version = value['version'];
    if (version is! String || version.isEmpty) {
      throw StateError(
        '$releaseTrainMaintenanceFile.$packageName.version is required.',
      );
    }
    final floors = <String, String>{};
    final rawFloors = value['dependencyFloors'];
    if (rawFloors is Map<String, Object?>) {
      for (final floorEntry in rawFloors.entries) {
        final floor = floorEntry.value;
        if (floor is String && floor.isNotEmpty) {
          floors[floorEntry.key] = floor;
        }
      }
    }
    overrides[packageName] = ReleaseTrainMaintenanceOverride(
      version: version,
      dependencyFloors: floors,
    );
  }
  return overrides;
}

Future<List<String>> releaseTrainMaintenanceFindings(
  Directory repoRoot, {
  required Map<String, String> manifestVersions,
  required Map<String, ReleaseTrainMaintenanceOverride> maintenance,
}) async {
  final findings = <String>[];

  for (final packageName in publishablePackages) {
    final pubspec = await readPubspec(repoRoot, packageName);
    final actual = pubspecVersion(pubspec);
    final expected = _expectedPackageVersion(
      packageName,
      manifestVersions: manifestVersions,
      maintenance: maintenance,
    );
    if (expected == null) {
      findings.add('$packageName has no manifest/maintenance version.');
      continue;
    }
    if (actual != expected) {
      findings.add('$packageName version is $actual, expected $expected');
    }
  }

  for (final packageName in allInternalPackages) {
    final pubspec = await readPubspec(repoRoot, packageName);
    for (final dependency in publishablePackages) {
      if (dependency == packageName) {
        continue;
      }
      final actual = dependencyFloor(pubspec, dependency);
      if (actual == null) {
        continue;
      }
      final consumerOverride = maintenance[packageName];
      final floorOverride = consumerOverride?.dependencyFloors[dependency];
      if (floorOverride != null) {
        if (actual != floorOverride) {
          findings.add(
            '$packageName depends on $dependency ^$actual, expected ^$floorOverride',
          );
        }
        continue;
      }

      final dependencyVersion = manifestVersions[dependency];
      if (dependencyVersion == null) {
        continue;
      }
      if (!caretFloorAllowsVersion(actual, dependencyVersion)) {
        findings.add(
          '$packageName depends on $dependency ^$actual, which does not allow $dependencyVersion',
        );
      }
    }
  }

  return findings;
}

String? _expectedPackageVersion(
  String packageName, {
  required Map<String, String> manifestVersions,
  required Map<String, ReleaseTrainMaintenanceOverride> maintenance,
}) {
  final override = maintenance[packageName];
  if (override != null) {
    return override.version;
  }
  return manifestVersions[packageName];
}

bool caretFloorAllowsVersion(String floor, String version) {
  final floorParts = _parseVersionParts(floor);
  final versionParts = _parseVersionParts(version);
  if (floorParts[0] != versionParts[0]) {
    return false;
  }
  for (var i = 0; i < 3; i++) {
    if (versionParts[i] > floorParts[i]) {
      return true;
    }
    if (versionParts[i] < floorParts[i]) {
      return false;
    }
  }
  return true;
}

List<int> _parseVersionParts(String version) {
  return version
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .take(3)
      .followedBy(List.filled(3, 0))
      .take(3)
      .toList();
}

Future<String> resolveReleaseTrainVersion(Directory repoRoot) async {
  final manifest = File(
    joinPath([repoRoot.path, '.release-please-manifest.json']),
  );
  if (manifest.existsSync()) {
    final decoded = jsonDecode(await manifest.readAsString());
    if (decoded is Map<String, Object?>) {
      final values = <String>{};
      for (final packageName in publishablePackages) {
        final value = decoded['packages/$packageName'];
        if (value is String && value.isNotEmpty) {
          values.add(value);
        }
      }
      if (values.length == 1) {
        return values.single;
      }
      if (values.length > 1) {
        if (await usesPerPackageReleaseTrain(repoRoot)) {
          return 'maintenance (${values.join(", ")})';
        }
        throw StateError(
          'Release manifest contains multiple train versions: ${values.join(", ")}',
        );
      }
    }
  }

  String? version;
  for (final packageName in publishablePackages) {
    final pubspec = await readPubspec(repoRoot, packageName);
    final packageVersion = pubspecVersion(pubspec);
    if (packageVersion == null) {
      throw StateError('$packageName pubspec.yaml has no version.');
    }
    version ??= packageVersion;
    if (version != packageVersion) {
      throw StateError(
        '$packageName is $packageVersion, expected train version $version.',
      );
    }
  }
  return version!;
}

Future<List<String>> releaseTrainFindings(
  Directory repoRoot, {
  required String version,
}) async {
  final findings = <String>[];

  for (final packageName in publishablePackages) {
    final pubspec = await readPubspec(repoRoot, packageName);
    final actual = pubspecVersion(pubspec);
    if (actual != version) {
      findings.add('$packageName version is $actual, expected $version');
    }
  }

  for (final packageName in allInternalPackages) {
    final pubspec = await readPubspec(repoRoot, packageName);
    for (final dependency in publishablePackages) {
      if (dependency == packageName) {
        continue;
      }
      final actual = dependencyFloor(pubspec, dependency);
      if (actual != null && actual != version) {
        findings.add(
          '$packageName depends on $dependency ^$actual, expected ^$version',
        );
      }
    }
  }

  return findings;
}

Future<List<String>> syncReleaseTrainMetadata(
  Directory repoRoot, {
  required String version,
  required bool write,
}) async {
  final edits = <String>[];

  for (final packageName in publishablePackages) {
    final file = pubspecFile(repoRoot, packageName);
    final original = await file.readAsString();
    final updated = replacePubspecVersion(original, version);
    if (updated != original) {
      edits.add('${relativePath(repoRoot, file)} version -> $version');
      if (write) {
        await file.writeAsString(updated);
      }
    }
  }

  for (final packageName in allInternalPackages) {
    final file = pubspecFile(repoRoot, packageName);
    final original = await file.readAsString();
    final updated = replaceInternalDependencyFloors(
      original,
      packageName: packageName,
      version: version,
    );
    if (updated != original) {
      edits.add('${relativePath(repoRoot, file)} internal floors -> ^$version');
      if (write) {
        await file.writeAsString(updated);
      }
    }
  }

  return edits;
}

String replacePubspecVersion(String content, String version) {
  return content.replaceFirst(
    RegExp(r'^version:\s*[^\s]+', multiLine: true),
    'version: $version',
  );
}

String replaceInternalDependencyFloors(
  String content, {
  required String packageName,
  required String version,
}) {
  var updated = content;
  for (final dependency in publishablePackages) {
    if (dependency == packageName) {
      continue;
    }
    updated = updated.replaceAllMapped(
      RegExp(
        '^(\\s{2}${RegExp.escape(dependency)}:\\s*)\\^([^\\s#]+)',
        multiLine: true,
      ),
      (match) => '${match.group(1)}^$version',
    );
  }
  return updated;
}

String? pubspecVersion(String content) {
  return RegExp(
    r'^version:\s*([^\s]+)',
    multiLine: true,
  ).firstMatch(content)?.group(1);
}

String? dependencyFloor(String content, String dependency) {
  return RegExp(
    '^\\s{2}${RegExp.escape(dependency)}:\\s*\\^([^\\s#]+)',
    multiLine: true,
  ).firstMatch(content)?.group(1);
}

Future<String> readPubspec(Directory repoRoot, String packageName) {
  return pubspecFile(repoRoot, packageName).readAsString();
}

File pubspecFile(Directory repoRoot, String packageName) {
  return File(
    joinPath([repoRoot.path, 'packages', packageName, 'pubspec.yaml']),
  );
}

String relativePath(Directory repoRoot, File file) {
  final root = repoRoot.uri;
  final uri = file.uri;
  return root.toString() == uri.toString()
      ? '.'
      : uri.toString().replaceFirst(root.toString(), '');
}

String joinPath(List<String> parts) {
  return parts.where((part) => part.isNotEmpty).join(Platform.pathSeparator);
}

String? _option(List<String> args, String name) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == name && i + 1 < args.length) {
      return args[i + 1];
    }
    if (arg.startsWith('$name=')) {
      return arg.substring(name.length + 1);
    }
  }
  return null;
}

int _usage() {
  stderr.writeln(
    'Usage: dart tool/intentcall/bin/release_train.dart <check|sync>',
  );
  stderr.writeln('  check                 Verify release train metadata.');
  stderr.writeln(
    '  sync [--version X]    Rewrite train versions and internal floors.',
  );
  stderr.writeln('  sync --check          Report the edits sync would make.');
  stderr.writeln(
    '  sync --force          Allow sync on maintenance-line branches.',
  );
  return 64;
}
