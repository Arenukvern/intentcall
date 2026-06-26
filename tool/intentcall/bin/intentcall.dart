// ignore_for_file: avoid_print, prefer_final_parameters, avoid_catches_without_on_clauses, prefer_if_elements_to_conditional_expressions

import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

const publishOrder = [
  'intentcall_schema',
  'intentcall_core',
  'intentcall_session',
  'intentcall_mcp',
  'intentcall_webmcp',
  'intentcall_apple',
  'intentcall_android',
  'intentcall_codegen',
  'intentcall_platform',
  'intentcall_testing',
];

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('doctor')
    ..addCommand('validate')
    ..addCommand('check-path-deps')
    ..addCommand(
      'publish-preflight',
      ArgParser()..addFlag(
        'first-publish',
        negatable: false,
        help:
            'Also require all pub.dev package names to be currently available.',
      ),
    )
    ..addCommand(
      'print-hosted-deps',
      ArgParser()..addOption(
        'version',
        abbr: 'v',
        help: 'Version to print dependencies for',
      ),
    )
    ..addCommand(
      'publish-all',
      ArgParser()
        ..addFlag(
          'execute',
          negatable: false,
          help: 'Execute publishing instead of dry-run',
        )
        ..addFlag(
          'dry-run',
          negatable: false,
          help: 'Run publish in dry-run mode (default)',
          defaultsTo: true,
        )
        ..addFlag(
          'ignore-warnings',
          negatable: false,
          help:
              'Diagnostic dry-run only: continue despite pub warnings such as dirty git state.',
        ),
    )
    ..addCommand(
      'publish-tag',
      ArgParser()
        ..addOption(
          'tag',
          help:
              'Release tag in the form <package>-v<version>, for example intentcall_core-v0.2.1.',
        )
        ..addFlag(
          'execute',
          negatable: false,
          help: 'Execute publishing instead of dry-run preflight.',
        )
        ..addFlag(
          'skip-existing',
          negatable: false,
          help: 'Skip when pub.dev already exposes this package version.',
        ),
    );

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } catch (e) {
    stderr.writeln('Error: $e');
    printUsage(parser);
    exit(64);
  }

  if (results.command == null) {
    printUsage(parser);
    exit(64);
  }

  final repoRoot = findRepoRoot();

  switch (results.command!.name) {
    case 'doctor':
      final code = await runDoctor(repoRoot);
      exit(code);

    case 'validate':
      final code = await runValidate(repoRoot);
      exit(code);

    case 'check-path-deps':
      final code = await runCheckPathDeps(repoRoot);
      exit(code);

    case 'publish-preflight':
      final cmdResults = results.command!;
      final firstPublish = cmdResults['first-publish'] as bool? ?? false;
      final code = await runPublishPreflight(
        repoRoot,
        firstPublish: firstPublish,
      );
      exit(code);

    case 'print-hosted-deps':
      final cmdResults = results.command!;
      final envVersion = Platform.environment['INTENTCALL_VERSION'];
      final version = cmdResults['version'] as String? ?? envVersion ?? '0.2.1';
      runPrintHostedDeps(version);
      exit(0);

    case 'publish-all':
      final cmdResults = results.command!;
      // If --execute is passed, dryRun is false. If only --dry-run is passed or neither, dryRun is true.
      final execute = cmdResults['execute'] as bool? ?? false;
      final ignoreWarnings = cmdResults['ignore-warnings'] as bool? ?? false;
      final dryRun = !execute;
      final code = await runPublishAll(
        repoRoot,
        dryRun: dryRun,
        ignoreWarnings: ignoreWarnings,
      );
      exit(code);

    case 'publish-tag':
      final cmdResults = results.command!;
      final tag =
          cmdResults['tag'] as String? ??
          Platform.environment['GITHUB_REF_NAME'];
      final execute = cmdResults['execute'] as bool? ?? false;
      final skipExisting = cmdResults['skip-existing'] as bool? ?? false;
      final code = await runPublishTag(
        repoRoot,
        tag: tag,
        dryRun: !execute,
        skipExisting: skipExisting,
      );
      exit(code);

    default:
      printUsage(parser);
      exit(64);
  }
}

Directory findRepoRoot() {
  var dir = Directory(p.dirname(Platform.script.toFilePath()));
  while (dir.path != dir.parent.path) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: intentcall_workspace')) {
        return dir;
      }
    }
    dir = dir.parent;
  }
  // Fallback to current directory
  return Directory.current;
}

void printUsage(ArgParser parser) {
  print('Usage: dart run tool/intentcall [command] [options]');
  print('\nCommands:');
  print('  doctor                Check developer environment health.');
  print(
    '  validate              Validate path dependencies and version consistency.',
  );
  print(
    '  check-path-deps       Scan workspace for invalid path dependencies.',
  );
  print(
    '  publish-preflight     Check release cleanliness and pub.dev credentials.',
  );
  print('  print-hosted-deps     Print hosted pub.dev dependency blocks.');
  print(
    '  publish-all           Publish all workspace packages to pub.dev in order.',
  );
  print(
    '  publish-tag           Publish one package selected by a release tag.',
  );
  print('\nOptions:');
  print(parser.usage);
}

Future<int> runDoctor(Directory repoRoot) async {
  print('== IntentCall Workspace Doctor ==');
  bool healthy = true;

  // 1. Check Dart CLI
  try {
    final result = await Process.run('dart', ['--version']);
    if (result.exitCode == 0) {
      print('✓ Dart SDK: ${result.stdout.toString().trim()}');
    } else {
      print('✗ Dart SDK check failed');
      healthy = false;
    }
  } catch (e) {
    print('✗ Dart SDK not found in PATH: $e');
    healthy = false;
  }

  // 2. Check Flutter CLI (needed for intentcall_platform)
  try {
    final result = await Process.run('flutter', ['--version']);
    if (result.exitCode == 0) {
      final line = result.stdout.toString().split('\n').first;
      print('✓ Flutter SDK: $line');
    } else {
      print('✗ Flutter SDK check failed');
      healthy = false;
    }
  } catch (e) {
    print('✗ Flutter SDK not found in PATH: $e');
    healthy = false;
  }

  // 3. Check just task runner
  try {
    final result = await Process.run('just', ['--version']);
    if (result.exitCode == 0) {
      print('✓ just task runner: ${result.stdout.toString().trim()}');
    } else {
      print('✗ just check failed');
      healthy = false;
    }
  } catch (e) {
    print('? just task runner not found (optional but recommended): $e');
  }

  // 4. Check workspace lockfile
  final lockFile = File(p.join(repoRoot.path, 'pubspec.lock'));
  if (lockFile.existsSync()) {
    print('✓ Workspace pubspec.lock exists');
  } else {
    print('✗ Workspace pubspec.lock is missing. Run "dart pub get"');
    healthy = false;
  }

  if (healthy) {
    print('\nWorkspace status: HEALTHY');
    return 0;
  } else {
    print('\nWorkspace status: UNHEALTHY (Please check the issues above)');
    return 1;
  }
}

Future<int> runValidate(Directory repoRoot) async {
  print('== Running Workspace Validation ==');

  // 1. Run check-path-deps
  final pathDepsExitCode = await runCheckPathDeps(repoRoot);
  if (pathDepsExitCode != 0) {
    return pathDepsExitCode;
  }

  // 2. Run version consistency check
  print('\nChecking version consistency across packages...');
  String? commonVersion;
  bool versionMismatch = false;

  for (final pkg in publishOrder) {
    final pubspecFile = File(
      p.join(repoRoot.path, 'packages', pkg, 'pubspec.yaml'),
    );
    if (!pubspecFile.existsSync()) {
      stderr.writeln('ERROR: pubspec.yaml not found for package: $pkg');
      return 1;
    }

    final content = await pubspecFile.readAsString();
    final versionMatch = RegExp(
      r'^version:\s*([^\s]+)',
      multiLine: true,
    ).firstMatch(content);
    if (versionMatch == null) {
      stderr.writeln(
        'ERROR: Could not find version in pubspec.yaml for package: $pkg',
      );
      return 1;
    }

    final version = versionMatch.group(1);
    print('  - $pkg: $version');
    if (commonVersion == null) {
      commonVersion = version;
    } else if (commonVersion != version) {
      stderr.writeln(
        'ERROR: Version mismatch for package $pkg ($version). Expected $commonVersion.',
      );
      versionMismatch = true;
    }
  }

  if (versionMismatch) {
    stderr.writeln('FAIL: Package versions are not synchronized.');
    return 1;
  }

  print('OK: All packages are synchronized at version $commonVersion.');

  // 3. Check internal hosted dependency floors
  final dependencyFloorCode = await runInternalDependencyFloorCheck(
    repoRoot,
    version: commonVersion!,
  );
  if (dependencyFloorCode != 0) {
    return dependencyFloorCode;
  }

  // 4. Run plan hygiene check
  print('\nChecking plan hygiene (active plan files)...');
  final activePlans = <String>[];
  final taskFile = File(p.join(repoRoot.path, 'task.md'));
  if (taskFile.existsSync()) activePlans.add('task.md');
  final planFile = File(p.join(repoRoot.path, 'implementation_plan.md'));
  if (planFile.existsSync()) activePlans.add('implementation_plan.md');

  final activePlansDir = Directory(
    p.join(repoRoot.path, 'docs', 'exec-plans', 'active'),
  );
  if (activePlansDir.existsSync()) {
    try {
      final files = activePlansDir.listSync().whereType<File>();
      for (final f in files) {
        final name = p.basename(f.path);
        if (!name.startsWith('.')) {
          activePlans.add('docs/exec-plans/active/$name');
        }
      }
    } catch (_) {}
  }

  if (activePlans.isNotEmpty) {
    stderr.writeln(
      'FAIL: Stale/active plan files found: ${activePlans.join(", ")}',
    );
    stderr.writeln(
      'Please extract durable findings to docs/decisions/ or DESIGN_FAQ.mdx, then delete the plan files.',
    );
    return 1;
  }

  print('OK: No active plan files found.');
  return 0;
}

Future<int> runInternalDependencyFloorCheck(
  Directory repoRoot, {
  required String version,
}) async {
  print('\nChecking internal dependency floors...');
  final mismatches = <String>[];
  for (final pkg in publishOrder) {
    final pubspecFile = File(
      p.join(repoRoot.path, 'packages', pkg, 'pubspec.yaml'),
    );
    final content = await pubspecFile.readAsString();
    for (final mismatch in internalDependencyFloorMismatches(
      content,
      version,
      packageName: pkg,
    )) {
      mismatches.add(mismatch);
    }
  }
  if (mismatches.isNotEmpty) {
    stderr.writeln('FAIL: Internal intentcall dependency floors are stale.');
    for (final mismatch in mismatches) {
      stderr.writeln('  - $mismatch');
    }
    return 1;
  }
  print('OK: internal dependencies use ^$version.');
  return 0;
}

List<String> internalDependencyFloorMismatches(
  String pubspecContent,
  String version, {
  required String packageName,
}) {
  final mismatches = <String>[];
  for (final pkg in publishOrder) {
    if (pkg == packageName) {
      continue;
    }
    final pattern = RegExp(
      '^\\s{2}${RegExp.escape(pkg)}:\\s*\\^([^\\s#]+)',
      multiLine: true,
    );
    final match = pattern.firstMatch(pubspecContent);
    if (match == null) {
      continue;
    }
    final actual = match.group(1);
    if (actual != version) {
      mismatches.add(
        '$packageName depends on $pkg ^$actual, expected ^$version',
      );
    }
  }
  return mismatches;
}

Future<int> runCheckPathDeps(Directory repoRoot) async {
  print('Checking for invalid intentcall path dependencies...');
  final matches = <String>[];
  for (final entity in repoRoot.listSync(recursive: true)) {
    if (entity is! File) {
      continue;
    }
    if (p.basename(entity.path) != 'pubspec.yaml') {
      continue;
    }
    final relativePath = p.relative(entity.path, from: repoRoot.path);
    if (relativePath.startsWith('.dart_tool${p.separator}') ||
        relativePath.startsWith('build${p.separator}')) {
      continue;
    }
    final content = entity.readAsStringSync();
    if (content.contains('intentcall/packages') ||
        content.contains('agentkit/packages')) {
      matches.add(relativePath);
    }
  }

  if (matches.isNotEmpty) {
    stderr.writeln(
      'FAIL: Sibling path overrides are not allowed in published packages.',
    );
    for (final path in matches) {
      stderr.writeln('  - $path');
    }
    return 1;
  }

  print('OK: no local intentcall path deps in publishable packages');
  return 0;
}

void runPrintHostedDeps(String version) {
  print('# Replace path: ../agentkit/packages/<name> with:');
  print('');
  for (final pkg in publishOrder) {
    print('$pkg: ^$version');
  }
}

Future<int> runPublishPreflight(
  Directory repoRoot, {
  required bool firstPublish,
}) async {
  print('== IntentCall Publish Preflight ==');

  final validateCode = await runValidate(repoRoot);
  if (validateCode != 0) {
    return validateCode;
  }

  final gitCode = await runReleaseGitCleanCheck(repoRoot);
  final tokenCode = await runPubTokenCheck();
  final availabilityCode = firstPublish ? await runFirstPublishNameCheck() : 0;

  if (gitCode != 0 || tokenCode != 0 || availabilityCode != 0) {
    return 1;
  }

  print('\nOK: publish preflight passed.');
  return 0;
}

Future<int> runFirstPublishNameCheck() async {
  print('\nChecking pub.dev first-publish package name availability...');
  final client = HttpClient();
  var hasConflict = false;
  try {
    for (final pkg in publishOrder) {
      final uri = Uri.https('pub.dev', '/api/packages/$pkg');
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        await response.drain<void>();

        if (response.statusCode == HttpStatus.notFound) {
          print('OK: $pkg is available (404)');
        } else if (response.statusCode == HttpStatus.ok) {
          stderr.writeln('FAIL: $pkg already exists on pub.dev.');
          hasConflict = true;
        } else {
          stderr.writeln(
            'FAIL: Unexpected pub.dev response for $pkg: HTTP ${response.statusCode}',
          );
          hasConflict = true;
        }
      } catch (e) {
        stderr.writeln('FAIL: Could not check pub.dev package $pkg: $e');
        hasConflict = true;
      }
    }
  } finally {
    client.close(force: true);
  }

  if (hasConflict) {
    return 1;
  }

  print('OK: all first-publish package names are available.');
  return 0;
}

Future<int> runReleaseGitCleanCheck(Directory repoRoot) async {
  print('\nChecking release git state...');
  final result = await Process.run('git', [
    'status',
    '--porcelain=v1',
    '--untracked-files=all',
    '--',
    'packages',
    'tool/intentcall',
  ], workingDirectory: repoRoot.path);

  if (result.exitCode != 0) {
    stderr.writeln('FAIL: git status failed while checking release state.');
    stderr.write(result.stderr);
    return result.exitCode;
  }

  final dirtyLines = result.stdout
      .toString()
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .where(_isReleaseStatusLine)
      .toList();

  if (dirtyLines.isNotEmpty) {
    stderr.writeln(
      'FAIL: Release-critical files are not clean. Commit or revert these files before publishing:',
    );
    for (final line in dirtyLines) {
      stderr.writeln('  $line');
    }
    return 1;
  }

  print('OK: release-critical files are clean.');
  return 0;
}

Future<int> runPackageGitCleanCheck(Directory repoRoot) =>
    runReleaseGitCleanCheck(repoRoot);

bool _isReleaseStatusLine(String line) {
  final path = line.length > 3 ? line.substring(3).trim() : '';
  final normalized = path.replaceAll('\\', '/');
  if (publishOrder.any((pkg) => normalized.startsWith('packages/$pkg/'))) {
    return true;
  }
  return normalized.startsWith('tool/intentcall/');
}

Future<int> runPubTokenCheck() async {
  print('\nChecking pub.dev token configuration...');
  final result = await Process.run('dart', ['pub', 'token', 'list']);
  final output = '${result.stdout}${result.stderr}';

  if (result.exitCode != 0) {
    stderr.writeln('FAIL: dart pub token list failed.');
    stderr.write(output);
    return result.exitCode;
  }

  if (output.contains('You do not have any secret tokens')) {
    stderr.writeln(
      'FAIL: No pub.dev token configured. Run: dart pub token add https://pub.dev',
    );
    return 1;
  }

  print('OK: pub.dev token is configured.');
  return 0;
}

Future<int> runPublishAll(
  Directory repoRoot, {
  required bool dryRun,
  bool ignoreWarnings = false,
}) async {
  if (!dryRun && ignoreWarnings) {
    stderr.writeln('FAIL: --ignore-warnings is only allowed with dry-runs.');
    return 64;
  }

  print('== Workspace pub get ==');
  final pubGetCode = await runCommand('dart', ['pub', 'get'], repoRoot.path);
  if (pubGetCode != 0) {
    stderr.writeln('FAIL: workspace pub get failed');
    return pubGetCode;
  }

  for (final pkg in publishOrder) {
    final dirPath = p.join(repoRoot.path, 'packages', pkg);
    print('\n== Publishing package: $pkg ==');

    final isPlatform = pkg == 'intentcall_platform';
    final exec = isPlatform ? 'flutter' : 'dart';
    final args = buildPublishArgs(
      dryRun: dryRun,
      ignoreWarnings: ignoreWarnings,
    );

    final exitCode = await runCommand(exec, args, dirPath);
    if (exitCode != 0) {
      stderr.writeln('FAIL: publishing $pkg failed with exit code $exitCode');
      return exitCode;
    }
  }

  print('\nOK: publish_all complete (dryRun=$dryRun)');
  return 0;
}

Future<int> runPublishTag(
  Directory repoRoot, {
  required String? tag,
  required bool dryRun,
  required bool skipExisting,
}) async {
  if (tag == null || tag.trim().isEmpty) {
    stderr.writeln(
      'FAIL: publish-tag requires --tag or GITHUB_REF_NAME in the form <package>-v<version>.',
    );
    return 64;
  }

  final release = parsePackageReleaseTag(tag.trim());
  if (release == null) {
    stderr.writeln(
      'FAIL: release tag "$tag" does not match an IntentCall package tag. Expected one of:',
    );
    for (final pkg in publishOrder) {
      stderr.writeln('  - $pkg-v<version>');
    }
    return 64;
  }

  print(
    '== IntentCall package release: ${release.package} ${release.version} ==',
  );

  final validateCode = await runValidate(repoRoot);
  if (validateCode != 0) {
    return validateCode;
  }

  final staticCode = await runReleasePackageStaticCheck(repoRoot, release);
  if (staticCode != 0) {
    return staticCode;
  }

  if (skipExisting &&
      await packageHasVersion(release.package, release.version)) {
    print(
      'OK: pub.dev already exposes ${release.package} ${release.version}; skipping.',
    );
    return 0;
  }

  final packageDir = p.join(repoRoot.path, 'packages', release.package);
  final isPlatform = release.package == 'intentcall_platform';
  final exec = isPlatform ? 'flutter' : 'dart';

  if (dryRun) {
    final args = ['pub', 'publish', '--dry-run'];
    final code = await runCommand(exec, args, packageDir);
    if (code != 0) {
      stderr.writeln(
        'FAIL: publish preflight for ${release.package} failed with exit code $code',
      );
      return code;
    }
    print('\nOK: publish-tag preflight complete.');
    return 0;
  }

  final dependencyWaitCode = await waitForReleaseDependencies(
    repoRoot,
    release,
  );
  if (dependencyWaitCode != 0) {
    return dependencyWaitCode;
  }

  var code = await runCommand(exec, [
    'pub',
    'publish',
    '--dry-run',
  ], packageDir);
  if (code != 0) {
    stderr.writeln(
      'FAIL: strict publish dry-run for ${release.package} failed with exit code $code',
    );
    return code;
  }

  code = await runCommand(exec, ['pub', 'publish', '--force'], packageDir);
  if (code != 0) {
    stderr.writeln(
      'FAIL: publishing ${release.package} failed with exit code $code',
    );
    return code;
  }

  final waitCode = await waitForPubVersion(release.package, release.version);
  if (waitCode != 0) {
    return waitCode;
  }

  print('\nOK: publish-tag complete.');
  return 0;
}

PackageRelease? parsePackageReleaseTag(String tag) {
  for (final pkg in publishOrder) {
    final prefix = '$pkg-v';
    if (tag.startsWith(prefix)) {
      final version = tag.substring(prefix.length);
      if (isSemver(version)) {
        return PackageRelease(package: pkg, version: version);
      }
    }
  }
  return null;
}

bool isSemver(String version) => RegExp(
  r'^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$',
).hasMatch(version);

Future<int> runReleasePackageStaticCheck(
  Directory repoRoot,
  PackageRelease release,
) async {
  final packageDir = p.join(repoRoot.path, 'packages', release.package);
  final pubspec = File(p.join(packageDir, 'pubspec.yaml'));
  final changelog = File(p.join(packageDir, 'CHANGELOG.md'));

  if (!pubspec.existsSync()) {
    stderr.writeln('FAIL: missing ${release.package}/pubspec.yaml');
    return 1;
  }
  final pubspecContent = await pubspec.readAsString();
  if (RegExp(
    r'^publish_to:\s*none\b',
    multiLine: true,
  ).hasMatch(pubspecContent)) {
    stderr.writeln('FAIL: ${release.package} is marked publish_to: none');
    return 1;
  }
  if (!RegExp(
    '^version:\\s*${RegExp.escape(release.version)}(?:\\s|#|\$)',
    multiLine: true,
  ).hasMatch(pubspecContent)) {
    stderr.writeln(
      'FAIL: ${release.package}/pubspec.yaml version does not match ${release.version}.',
    );
    return 1;
  }
  if (RegExp(
    r'^\s{4}(path|git):\s',
    multiLine: true,
  ).hasMatch(pubspecContent)) {
    stderr.writeln(
      'FAIL: ${release.package}/pubspec.yaml contains a path/git dependency.',
    );
    return 1;
  }

  if (!changelog.existsSync()) {
    stderr.writeln('FAIL: missing ${release.package}/CHANGELOG.md');
    return 1;
  }
  final changelogContent = await changelog.readAsString();
  if (!RegExp(
    '(^#\\s+${RegExp.escape(release.version)}\\b|'
    '^##\\s+\\[${RegExp.escape(release.version)}\\]|'
    '^##\\s+${RegExp.escape(release.version)}\\b)',
    multiLine: true,
  ).hasMatch(changelogContent)) {
    stderr.writeln(
      'FAIL: ${release.package}/CHANGELOG.md has no entry for ${release.version}.',
    );
    return 1;
  }

  print('OK: static release checks passed for ${release.package}.');
  return 0;
}

Future<int> waitForReleaseDependencies(
  Directory repoRoot,
  PackageRelease release,
) async {
  final packageDir = p.join(repoRoot.path, 'packages', release.package);
  final pubspec = File(p.join(packageDir, 'pubspec.yaml'));
  final content = await pubspec.readAsString();
  final dependencies = sameTrainDependencies(content, release);
  for (final dependency in dependencies) {
    print(
      'Waiting for pub.dev to expose $dependency ${release.version} before publishing ${release.package}...',
    );
    final code = await waitForPubVersion(dependency, release.version);
    if (code != 0) {
      return code;
    }
  }
  return 0;
}

List<String> sameTrainDependencies(
  String pubspecContent,
  PackageRelease release,
) {
  final dependencies = <String>[];
  for (final pkg in publishOrder) {
    if (pkg == release.package) {
      continue;
    }
    final pattern = RegExp(
      '^\\s{2}${RegExp.escape(pkg)}:\\s*\\^${RegExp.escape(release.version)}(?:\\s|#|\$)',
      multiLine: true,
    );
    if (pattern.hasMatch(pubspecContent)) {
      dependencies.add(pkg);
    }
  }
  return dependencies;
}

Future<bool> packageHasVersion(String package, String version) async {
  final client = HttpClient();
  try {
    final uri = Uri.https('pub.dev', '/api/packages/$package');
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode == HttpStatus.notFound) {
      await response.drain<void>();
      return false;
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      stderr.writeln(
        'FAIL: Unexpected pub.dev response for $package: HTTP ${response.statusCode}',
      );
      throw StateError('Unexpected pub.dev response');
    }

    final body = await response.transform(SystemEncoding().decoder).join();
    return body.contains('"version":"$version"');
  } finally {
    client.close(force: true);
  }
}

Future<int> waitForPubVersion(String package, String version) async {
  final waitSeconds =
      int.tryParse(Platform.environment['PUB_PUBLISH_WAIT_SECONDS'] ?? '') ??
      300;
  final deadline = DateTime.now().add(Duration(seconds: waitSeconds));

  while (DateTime.now().isBefore(deadline)) {
    try {
      if (await packageHasVersion(package, version)) {
        print('OK: pub.dev exposes $package $version.');
        return 0;
      }
    } catch (_) {
      return 1;
    }
    await Future<void>.delayed(const Duration(seconds: 10));
  }

  stderr.writeln('FAIL: timed out waiting for $package $version on pub.dev.');
  return 1;
}

List<String> buildPublishArgs({
  required bool dryRun,
  required bool ignoreWarnings,
}) {
  final args = ['pub', 'publish', dryRun ? '--dry-run' : '--force'];
  if (ignoreWarnings) {
    args.add('--ignore-warnings');
  }
  return args;
}

Future<int> runCommand(
  String executable,
  List<String> arguments,
  String workingDirectory,
) async {
  print(
    'Running command: $executable ${arguments.join(' ')} (in $workingDirectory)',
  );
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

final class PackageRelease {
  const PackageRelease({required this.package, required this.version});

  final String package;
  final String version;
}
