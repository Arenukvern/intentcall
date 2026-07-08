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

const workspaceOnlyPackages = [
  'intentcall_gemma',
  'intentcall_apple',
  'intentcall_android',
];

const allInternalPackages = [...publishablePackages, ...workspaceOnlyPackages];

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
}) async {
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
  return 64;
}
