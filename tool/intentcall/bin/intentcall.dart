// ignore_for_file: avoid_print, prefer_final_parameters, avoid_catches_without_on_clauses, prefer_if_elements_to_conditional_expressions

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:path/path.dart' as p;

import 'release_train.dart' as release_train;

const publishOrder = [
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

const flutterPublishPackages = {
  'intentcall_platform',
  'intentcall_platform_apple',
  'intentcall_platform_android',
};

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('doctor')
    ..addCommand('validate')
    ..addCommand('check-release-train')
    ..addCommand(
      'sync-release-train',
      ArgParser()
        ..addOption(
          'version',
          abbr: 'v',
          help:
              'Train version to sync. Defaults to .release-please-manifest.json or package versions.',
        )
        ..addFlag(
          'check',
          negatable: false,
          help: 'Report whether sync would edit files without writing them.',
        ),
    )
    ..addCommand('check-path-deps')
    ..addCommand('check-doc-versions')
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
      'apple-appintents-testing',
      ArgParser()
        ..addCommand(
          'generate-tests',
          ArgParser()
            ..addOption(
              'manifest',
              abbr: 'm',
              help: 'Path to agent_manifest.json.',
              defaultsTo: 'web/agent_manifest.json',
            )
            ..addOption(
              'bundle-id',
              help: 'Bundle identifier for IntentDefinitions lookup.',
            )
            ..addOption(
              'output',
              abbr: 'o',
              help: 'Swift output path. Defaults to stdout.',
            )
            ..addOption(
              'test-class',
              help: 'Generated XCTest class name.',
              defaultsTo: 'IntentCallAppIntentsLiveInvocationTests',
            )
            ..addOption(
              'sample-arguments',
              help:
                  'Optional JSON file keyed by manifest qualifiedName with primitive App Intent argument fixtures.',
            )
            ..addOption(
              'entity-fixtures',
              help:
                  'Optional JSON file keyed by entity qualifiedName with identifier/search/expectedTitle fixtures.',
            ),
        )
        ..addCommand(
          'generate-fixtures',
          ArgParser()
            ..addOption(
              'manifest',
              abbr: 'm',
              help: 'Path to agent_manifest.json.',
              defaultsTo: 'web/agent_manifest.json',
            )
            ..addOption(
              'sample-arguments-output',
              help:
                  'JSON output path for generated primitive argument fixtures.',
            )
            ..addOption(
              'entity-fixtures-output',
              help: 'JSON output path for generated AppEntity query fixtures.',
            ),
        )
        ..addCommand(
          'typecheck',
          ArgParser()..addOption(
            'xcode',
            help: 'Xcode.app path containing AppIntentsTesting.framework.',
            defaultsTo: '/Applications/Xcode-beta.app',
          ),
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
          help: 'Release tag in the form <package>-v<version>.',
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

    case 'check-release-train':
      final code = await release_train.runReleaseTrainCheck(repoRoot);
      exit(code);

    case 'sync-release-train':
      final cmdResults = results.command!;
      final code = await release_train.runReleaseTrainSync(
        repoRoot,
        version: cmdResults['version'] as String?,
        checkOnly: cmdResults['check'] as bool? ?? false,
      );
      exit(code);

    case 'check-path-deps':
      final code = await runCheckPathDeps(repoRoot);
      exit(code);

    case 'check-doc-versions':
      final version = await readSynchronizedPackageVersion(repoRoot);
      final code = await runDocVersionReferenceCheck(
        repoRoot,
        version: version,
      );
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
      final version =
          cmdResults['version'] as String? ??
          envVersion ??
          await readSynchronizedPackageVersion(repoRoot);
      runPrintHostedDeps(version);
      exit(0);

    case 'apple-appintents-testing':
      stderr.writeln(
        'Moved to intentcall_cli. Run: dart run intentcall_cli:intentcall apple-appintents-testing ...',
      );
      exit(64);

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
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: intentcall_workspace')) {
      return dir;
    }
    dir = dir.parent;
  }
  dir = Directory(p.dirname(Platform.script.toFilePath()));
  while (dir.path != dir.parent.path) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: intentcall_workspace')) {
      return dir;
    }
    dir = dir.parent;
  }
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
    '  check-release-train   Verify train versions and internal floors.',
  );
  print(
    '  sync-release-train    Rewrite train versions and internal floors.',
  );
  print(
    '  check-path-deps       Scan workspace for invalid path dependencies.',
  );
  print(
    '  check-doc-versions    Scan docs and skills for hardcoded package train versions.',
  );
  print(
    '  publish-preflight     Check release cleanliness and pub.dev credentials.',
  );
  print('  print-hosted-deps     Print hosted pub.dev dependency blocks.');
  print(
    '  apple-appintents-testing  Generate/typecheck AppIntentsTesting live proof scaffolds.',
  );
  print(
    '  publish-all           Publish all workspace packages to pub.dev in order.',
  );
  print(
    '  publish-tag           Publish one package selected by a release tag.',
  );
  print('\nOptions:');
  print(parser.usage);
}

Future<int> runAppleAppIntentsTesting(
  Directory repoRoot,
  ArgResults command,
) async {
  final subcommand = command.command;
  if (subcommand == null) {
    stderr.writeln(
      'FAIL: apple-appintents-testing requires generate-tests, generate-fixtures, or typecheck.',
    );
    return 64;
  }

  return switch (subcommand.name) {
    'generate-tests' => runAppleAppIntentsTestingGenerate(repoRoot, subcommand),
    'generate-fixtures' => runAppleAppIntentsTestingGenerateFixtures(
      repoRoot,
      subcommand,
    ),
    'typecheck' => runAppleAppIntentsTestingTypecheck(subcommand),
    _ => Future<int>.value(64),
  };
}

Future<int> runAppleAppIntentsTestingGenerate(
  Directory repoRoot,
  ArgResults command,
) async {
  final bundleIdentifier = '${command['bundle-id'] ?? ''}'.trim();
  if (bundleIdentifier.isEmpty) {
    stderr.writeln(
      'FAIL: --bundle-id is required for IntentDefinitions(bundleIdentifier:).',
    );
    return 64;
  }

  final manifestPath = resolveCliPath(repoRoot, '${command['manifest']}');
  if (!manifestPath.existsSync()) {
    stderr.writeln('FAIL: manifest not found: ${manifestPath.path}');
    return 66;
  }

  final sampleArgumentsPath = '${command['sample-arguments'] ?? ''}'.trim();
  final entityFixturesPath = '${command['entity-fixtures'] ?? ''}'.trim();
  final outputPath = '${command['output'] ?? ''}'.trim();

  try {
    final swift = emitAppleAppIntentsTestingScaffold(
      manifestFile: manifestPath,
      bundleIdentifier: bundleIdentifier,
      testClassName: '${command['test-class']}',
      sampleArgumentsFile: sampleArgumentsPath.isEmpty
          ? null
          : resolveCliPath(repoRoot, sampleArgumentsPath),
      entityFixturesFile: entityFixturesPath.isEmpty
          ? null
          : resolveCliPath(repoRoot, entityFixturesPath),
    );

    if (outputPath.isEmpty) {
      stdout.write(swift);
    } else {
      final output = resolveCliPath(repoRoot, outputPath);
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(swift);
      print('OK: wrote AppIntentsTesting XCTest scaffold to ${output.path}');
    }
    print(
      'Proof label: generated AppIntentsTesting scaffold only. Run the scaffold in an XCTest UI-test bundle for runtime proof.',
    );
    return 0;
  } on FormatException catch (error) {
    stderr.writeln('FAIL: invalid AppIntentsTesting input: ${error.message}');
    return 65;
  } on UnsupportedError catch (error) {
    stderr.writeln('FAIL: cannot generate AppIntentsTesting scaffold: $error');
    return 65;
  } on StateError catch (error) {
    stderr.writeln('FAIL: cannot generate AppIntentsTesting scaffold: $error');
    return 65;
  }
}

Future<int> runAppleAppIntentsTestingGenerateFixtures(
  Directory repoRoot,
  ArgResults command,
) async {
  final sampleArgumentsOutput = '${command['sample-arguments-output'] ?? ''}'
      .trim();
  final entityFixturesOutput = '${command['entity-fixtures-output'] ?? ''}'
      .trim();
  if (sampleArgumentsOutput.isEmpty && entityFixturesOutput.isEmpty) {
    stderr.writeln(
      'FAIL: generate-fixtures requires --sample-arguments-output, --entity-fixtures-output, or both.',
    );
    return 64;
  }

  final manifestPath = resolveCliPath(repoRoot, '${command['manifest']}');
  if (!manifestPath.existsSync()) {
    stderr.writeln('FAIL: manifest not found: ${manifestPath.path}');
    return 66;
  }

  try {
    final manifest = AgentManifest.parse(manifestPath.readAsStringSync());
    if (sampleArgumentsOutput.isNotEmpty) {
      final output = resolveCliPath(repoRoot, sampleArgumentsOutput);
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(
        '${encodePrettyJson(appIntentsTestingSampleArgumentsTemplate(manifest))}\n',
      );
      print('OK: wrote AppIntentsTesting sample arguments to ${output.path}');
    }
    if (entityFixturesOutput.isNotEmpty) {
      final output = resolveCliPath(repoRoot, entityFixturesOutput);
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(
        '${encodePrettyJson(appIntentsTestingEntityFixturesTemplate(manifest))}\n',
      );
      print('OK: wrote AppIntentsTesting entity fixtures to ${output.path}');
    }
    print(
      'Proof label: fixture template generation only. Replace placeholder values with seeded UI-test data before claiming runtime proof.',
    );
    return 0;
  } on FormatException catch (error) {
    stderr.writeln('FAIL: invalid AppIntentsTesting input: ${error.message}');
    return 65;
  } on UnsupportedError catch (error) {
    stderr.writeln('FAIL: cannot generate AppIntentsTesting fixtures: $error');
    return 65;
  }
}

String emitAppleAppIntentsTestingScaffold({
  required File manifestFile,
  required String bundleIdentifier,
  required String testClassName,
  File? sampleArgumentsFile,
  File? entityFixturesFile,
}) {
  final manifest = AgentManifest.parse(manifestFile.readAsStringSync());
  return AppleAppIntentsTestingEmitter(
    bundleIdentifier: bundleIdentifier,
    testClassName: testClassName,
    sampleArguments: sampleArgumentsFile == null
        ? const <String, Map<String, Object?>>{}
        : readAppleAppIntentsTestingSampleArguments(sampleArgumentsFile),
    entityFixtures: entityFixturesFile == null
        ? const <String, AppleAppIntentsTestingEntityFixture>{}
        : readAppleAppIntentsTestingEntityFixtures(entityFixturesFile),
  ).emitUiTests(manifest);
}

Map<String, Map<String, Object?>> appIntentsTestingSampleArgumentsTemplate(
  AgentManifest manifest,
) {
  final out = <String, Map<String, Object?>>{};
  for (final tool in manifest.tools) {
    final properties = tool.inputSchema['properties'];
    if (properties is! Map) {
      continue;
    }
    final required = <String>{
      ...((tool.inputSchema['required'] is List)
              ? tool.inputSchema['required'] as List
              : const <Object?>[])
          .whereType<String>(),
    };
    final sample = <String, Object?>{};
    for (final entry in properties.entries) {
      final parameterName = '${entry.key}';
      if (!required.contains(parameterName)) {
        continue;
      }
      final schema = entry.value;
      if (schema is! Map) {
        continue;
      }
      sample[parameterName] = sampleValueForAppIntentsTestingSchema(
        '${schema['type']}',
        qualifiedName: tool.qualifiedName,
        parameterName: parameterName,
      );
    }
    if (sample.isNotEmpty) {
      out[tool.qualifiedName] = sample;
    }
  }
  return out;
}

Map<String, Map<String, Object?>> appIntentsTestingEntityFixturesTemplate(
  AgentManifest manifest,
) {
  final out = <String, Map<String, Object?>>{};
  for (final entityType in manifest.entityTypes) {
    out[entityType.qualifiedName] = <String, Object?>{
      'identifier': '<${entityType.idKey}>',
      'search': '<search text>',
      'expectedTitle': '<${entityType.displayName} title>',
    };
  }
  return out;
}

Object? sampleValueForAppIntentsTestingSchema(
  String schemaType, {
  required String qualifiedName,
  required String parameterName,
}) => switch (schemaType) {
  'string' => '<sample string>',
  'integer' => 1,
  'number' => 1.0,
  'boolean' => true,
  _ => throw UnsupportedError(
    'AppIntentsTesting fixture templates support only primitive '
    'string/integer/number/boolean parameters in $qualifiedName; '
    '"$parameterName" has unsupported type "$schemaType".',
  ),
};

String encodePrettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

Future<int> runAppleAppIntentsTestingTypecheck(ArgResults command) async {
  final xcodeApp = Directory('${command['xcode']}');
  final developerDir = Directory(
    p.join(xcodeApp.path, 'Contents', 'Developer'),
  );
  final frameworkDir = Directory(
    p.join(
      developerDir.path,
      'Platforms',
      'MacOSX.platform',
      'Developer',
      'Library',
      'Frameworks',
    ),
  );
  final framework = Directory(
    p.join(frameworkDir.path, 'AppIntentsTesting.framework'),
  );

  if (!developerDir.existsSync()) {
    stderr.writeln('FAIL: Xcode developer dir not found: ${developerDir.path}');
    return 66;
  }
  if (!framework.existsSync()) {
    stderr.writeln(
      'FAIL: AppIntentsTesting.framework not found at ${framework.path}. '
      'Install/select a full Xcode that contains Apple 27+ SDK testing frameworks.',
    );
    return 66;
  }

  final tempDir = Directory.systemTemp.createTempSync(
    'intentcall_appintentstesting_',
  );
  try {
    final probe = File(p.join(tempDir.path, 'probe.swift'))
      ..writeAsStringSync('import AppIntentsTesting\nimport XCTest\n');
    final moduleCache = Directory(p.join(tempDir.path, 'module-cache'))
      ..createSync();
    final swiftc = await Process.start(
      'xcrun',
      [
        'swiftc',
        '-typecheck',
        '-F',
        frameworkDir.path,
        '-module-cache-path',
        moduleCache.path,
        probe.path,
      ],
      environment: <String, String>{'DEVELOPER_DIR': developerDir.path},
      mode: ProcessStartMode.inheritStdio,
    );
    final swiftcCode = await swiftc.exitCode;
    if (swiftcCode != 0) {
      stderr.writeln(
        'FAIL: AppIntentsTesting import typecheck failed with exit code $swiftcCode.',
      );
      return swiftcCode;
    }

    final xcodebuild = await Process.run(
      'xcrun',
      ['xcodebuild', '-version'],
      environment: <String, String>{'DEVELOPER_DIR': developerDir.path},
    );
    stdout.write(xcodebuild.stdout);
    stderr.write(xcodebuild.stderr);
    if (xcodebuild.exitCode != 0) {
      return xcodebuild.exitCode;
    }
    print(
      'Proof label: AppIntentsTesting import compile proof only. This does not execute generated intents.',
    );
    return 0;
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

File resolveCliPath(Directory repoRoot, String path) {
  final normalized = p.normalize(path);
  if (p.isAbsolute(normalized)) {
    return File(normalized);
  }
  return File(p.join(repoRoot.path, normalized));
}

Map<String, Map<String, Object?>> readAppleAppIntentsTestingSampleArguments(
  File file,
) {
  final raw = readJsonObjectFile(file);
  return raw.map((final key, final value) {
    final values = switch (value) {
      final Map<String, Object?> typed => typed,
      final Map map => map.cast<String, Object?>(),
      _ => throw FormatException(
        'sample argument fixture "$key" must be an object.',
      ),
    };
    return MapEntry(key, values);
  });
}

Map<String, AppleAppIntentsTestingEntityFixture>
readAppleAppIntentsTestingEntityFixtures(File file) {
  final raw = readJsonObjectFile(file);
  return raw.map((final key, final value) {
    final values = switch (value) {
      final Map<String, Object?> typed => typed,
      final Map map => map.cast<String, Object?>(),
      _ => throw FormatException('entity fixture "$key" must be an object.'),
    };
    final identifier = '${values['identifier'] ?? ''}'.trim();
    final search = '${values['search'] ?? ''}'.trim();
    final expectedTitle = '${values['expectedTitle'] ?? ''}'.trim();
    if (identifier.isEmpty || search.isEmpty || expectedTitle.isEmpty) {
      throw FormatException(
        'entity fixture "$key" requires identifier, search, and expectedTitle.',
      );
    }
    return MapEntry(
      key,
      AppleAppIntentsTestingEntityFixture(
        identifier: identifier,
        search: search,
        expectedTitle: expectedTitle,
      ),
    );
  });
}

Map<String, Object?> readJsonObjectFile(File file) {
  if (!file.existsSync()) {
    throw FormatException('JSON file not found: ${file.path}');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  return switch (decoded) {
    final Map<String, Object?> typed => typed,
    final Map map => map.cast<String, Object?>(),
    _ => throw FormatException(
      'JSON file must contain an object: ${file.path}',
    ),
  };
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

  final synchronizedVersion = commonVersion!;
  print('OK: All packages are synchronized at version $synchronizedVersion.');

  // 3. Check native package metadata for Flutter plugin hygiene
  final nativePackageCode = await runNativePackageHygieneCheck(repoRoot);
  if (nativePackageCode != 0) {
    return nativePackageCode;
  }

  // 4. Check internal hosted dependency floors
  final dependencyFloorCode = await runInternalDependencyFloorCheck(
    repoRoot,
    version: synchronizedVersion,
  );
  if (dependencyFloorCode != 0) {
    return dependencyFloorCode;
  }

  // 5. Check public docs and skills do not hardcode the package train
  final docVersionCode = await runDocVersionReferenceCheck(
    repoRoot,
    version: synchronizedVersion,
  );
  if (docVersionCode != 0) {
    return docVersionCode;
  }

  // 6. Check public docs avoid local-only paths and endpoints
  final docLocalReferenceCode = await runDocLocalReferenceCheck(repoRoot);
  if (docLocalReferenceCode != 0) {
    return docLocalReferenceCode;
  }

  // 7. Run plan hygiene check
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

Future<int> runNativePackageHygieneCheck(Directory repoRoot) async {
  print('\nChecking native package hygiene...');
  final mismatches = <String>[];

  final applePackageRoot = Directory(
    p.join(repoRoot.path, 'packages', 'intentcall_platform_apple'),
  );
  if (!applePackageRoot.existsSync()) {
    mismatches.add('packages/intentcall_platform_apple is missing');
  } else {
    mismatches.addAll(await swiftPackageManagerFindings(applePackageRoot));
  }

  mismatches.addAll(await federatedPlatformPodspecFindings(repoRoot));

  final androidPlugin = File(
    p.join(
      repoRoot.path,
      'packages',
      'intentcall_platform_android',
      'android',
      'src',
      'main',
      'kotlin',
      'dev',
      'intentcall',
      'intentcall_platform',
      'IntentCallPlatformPlugin.kt',
    ),
  );
  if (!androidPlugin.existsSync()) {
    mismatches.add(
      'packages/intentcall_platform_android/android/src/main/kotlin/dev/intentcall/intentcall_platform/IntentCallPlatformPlugin.kt is missing',
    );
  }

  if (mismatches.isNotEmpty) {
    stderr.writeln('FAIL: Native package hygiene drift detected.');
    for (final mismatch in mismatches) {
      stderr.writeln('  - $mismatch');
    }
    return 1;
  }
  print(
    'OK: federated Apple SPM layout and Android plugin sources are synchronized.',
  );
  return 0;
}

Future<List<String>> federatedPlatformPodspecFindings(
  final Directory repoRoot,
) async {
  final findings = <String>[];
  final packagesDir = Directory(p.join(repoRoot.path, 'packages'));
  if (!packagesDir.existsSync()) {
    return findings;
  }
  for (final entity in packagesDir.listSync()) {
    if (entity is! Directory) {
      continue;
    }
    final name = p.basename(entity.path);
    if (!name.startsWith('intentcall_platform')) {
      continue;
    }
    for (final file in entity.listSync(recursive: true)) {
      if (file is! File) {
        continue;
      }
      if (p.extension(file.path) != '.podspec') {
        continue;
      }
      findings.add(
        '${p.relative(file.path, from: repoRoot.path)} must not exist (SPM-only hardcut)',
      );
    }
  }
  return findings;
}

Future<List<String>> swiftPackageManagerFindings(
  final Directory packageRoot,
) async {
  final findings = <String>[];
  final spmRoot = Directory(
    p.join(packageRoot.path, 'darwin', 'intentcall_platform_apple'),
  );
  final packageFile = File(p.join(spmRoot.path, 'Package.swift'));
  final sourcesDir = p.join(
    spmRoot.path,
    'Sources',
    'intentcall_platform_apple',
  );
  final sourceFile = File(
    p.join(sourcesDir, 'IntentCallPlatformPlugin.swift'),
  );
  final privacyFile = File(p.join(sourcesDir, 'PrivacyInfo.xcprivacy'));
  final bridgeFile = File(
    p.join(sourcesDir, 'IntentCallPlatformBridge.g.swift'),
  );

  if (!packageFile.existsSync()) {
    findings.add(
      'darwin/intentcall_platform_apple/Package.swift is missing',
    );
    return findings;
  }

  final content = await packageFile.readAsString();
  final requiredSnippets = <String>[
    'name: "intentcall_platform_apple"',
    '.library(name: "intentcall-platform-apple", targets: ["intentcall_platform_apple"])',
    '.package(name: "FlutterFramework", path: "../FlutterFramework")',
    '.product(name: "FlutterFramework", package: "FlutterFramework")',
    '.iOS("13.0")',
    '.macOS("10.14")',
  ];
  for (final snippet in requiredSnippets) {
    if (!content.contains(snippet)) {
      findings.add(
        'darwin/intentcall_platform_apple/Package.swift is missing `$snippet`',
      );
    }
  }

  if (!sourceFile.existsSync()) {
    findings.add(
      'darwin/intentcall_platform_apple/Sources/intentcall_platform_apple/IntentCallPlatformPlugin.swift is missing',
    );
  } else {
    final source = await sourceFile.readAsString();
    if (!source.contains('public class IntentCallPlatformPlugin')) {
      findings.add(
        'darwin SwiftPM source is missing IntentCallPlatformPlugin',
      );
    }
    if (!source.contains('IntentCallInvocationsHostApiSetup.setUp')) {
      findings.add(
        'darwin SwiftPM source is missing the Pigeon invocation bridge',
      );
    }
  }

  if (!privacyFile.existsSync()) {
    findings.add(
      'darwin/intentcall_platform_apple/Sources/intentcall_platform_apple/PrivacyInfo.xcprivacy is missing',
    );
  }

  if (!bridgeFile.existsSync()) {
    findings.add(
      'darwin/intentcall_platform_apple/Sources/intentcall_platform_apple/IntentCallPlatformBridge.g.swift is missing',
    );
  }

  return findings;
}

Future<String> readSynchronizedPackageVersion(Directory repoRoot) async {
  String? commonVersion;
  for (final pkg in publishOrder) {
    final pubspecFile = File(
      p.join(repoRoot.path, 'packages', pkg, 'pubspec.yaml'),
    );
    if (!pubspecFile.existsSync()) {
      throw StateError('pubspec.yaml not found for package: $pkg');
    }
    final content = await pubspecFile.readAsString();
    final versionMatch = RegExp(
      r'^version:\s*([^\s]+)',
      multiLine: true,
    ).firstMatch(content);
    if (versionMatch == null) {
      throw StateError('Could not find version in pubspec.yaml for $pkg');
    }
    final version = versionMatch.group(1)!;
    commonVersion ??= version;
    if (commonVersion != version) {
      throw StateError(
        'Version mismatch for package $pkg ($version). Expected $commonVersion.',
      );
    }
  }
  return commonVersion!;
}

Future<int> runDocVersionReferenceCheck(
  Directory repoRoot, {
  required String version,
}) async {
  print('\nChecking docs for hardcoded IntentCall train versions...');
  final trainVersion = majorMinorTrain(version);
  final mismatches = <String>[];
  for (final relativePath in docVersionCheckPaths(repoRoot)) {
    final file = File(p.join(repoRoot.path, relativePath));
    if (!file.existsSync()) {
      continue;
    }
    final content = await file.readAsString();
    final findings = hardcodedDocVersionFindings(
      content,
      version: version,
      trainVersion: trainVersion,
    );
    for (final finding in findings) {
      mismatches.add('$relativePath: $finding');
    }
  }

  if (mismatches.isNotEmpty) {
    stderr.writeln(
      'FAIL: Docs or skills hardcode IntentCall package versions.',
    );
    stderr.writeln(
      'Use version-neutral wording, `dart pub add`, or `just print-hosted-deps`.',
    );
    for (final mismatch in mismatches) {
      stderr.writeln('  - $mismatch');
    }
    return 1;
  }
  print('OK: docs avoid hardcoded IntentCall train versions.');
  return 0;
}

Future<int> runDocLocalReferenceCheck(Directory repoRoot) async {
  print('\nChecking docs for local-only paths and endpoints...');
  final mismatches = <String>[];
  for (final relativePath in docLocalReferenceCheckPaths(repoRoot)) {
    final file = File(p.join(repoRoot.path, relativePath));
    if (!file.existsSync()) {
      continue;
    }
    final content = await file.readAsString();
    final findings = localDocumentationReferenceFindings(content);
    for (final finding in findings) {
      mismatches.add('$relativePath: $finding');
    }
  }

  if (mismatches.isNotEmpty) {
    stderr.writeln('FAIL: Docs contain local-only paths or endpoints.');
    stderr.writeln(
      'Use repo-relative paths or neutral placeholder endpoints instead.',
    );
    for (final mismatch in mismatches) {
      stderr.writeln('  - $mismatch');
    }
    return 1;
  }
  print('OK: docs avoid local-only paths and endpoints.');
  return 0;
}

String majorMinorTrain(String version) {
  final parts = version.split('.');
  if (parts.length < 2) {
    return version;
  }
  return '${parts[0]}.${parts[1]}.x';
}

List<String> docVersionCheckPaths(Directory repoRoot) {
  final paths = <String>[
    'README.md',
    'PRE_RELEASE.md',
    'AGENTS.md',
    p.join('docs', 'DESIGN_FAQ.mdx'),
    p.join('docs', 'DX_FAQ.mdx'),
    p.join('docs', 'NORTH_STAR.mdx'),
    p.join('docs', 'index.mdx'),
    p.join('docs', 'start_here', 'docs_map.mdx'),
    p.join('docs', 'start_here', 'how_it_works.mdx'),
    p.join('docs', 'start_here', 'choose_your_path.mdx'),
    p.join('docs', 'start_here', 'platform_support.mdx'),
    p.join('docs', 'start_here', 'roadmap.mdx'),
  ];

  final packagesDir = Directory(p.join(repoRoot.path, 'packages'));
  if (packagesDir.existsSync()) {
    for (final entity in packagesDir.listSync()) {
      if (entity is Directory) {
        paths.add(p.join('packages', p.basename(entity.path), 'README.md'));
      }
    }
  }

  final skillsDir = Directory(p.join(repoRoot.path, 'skills'));
  if (skillsDir.existsSync()) {
    for (final entity in skillsDir.listSync()) {
      if (entity is Directory) {
        paths.add(p.join('skills', p.basename(entity.path), 'SKILL.md'));
      }
    }
  }

  paths.sort();
  return paths;
}

List<String> docLocalReferenceCheckPaths(Directory repoRoot) {
  final paths = <String>{...docVersionCheckPaths(repoRoot)};

  for (final entity in repoRoot.listSync()) {
    if (entity is File && p.extension(entity.path).toLowerCase() == '.md') {
      paths.add(p.relative(entity.path, from: repoRoot.path));
    }
  }

  final docsDir = Directory(p.join(repoRoot.path, 'docs'));
  if (docsDir.existsSync()) {
    for (final entity in docsDir.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final extension = p.extension(entity.path).toLowerCase();
      if (extension == '.md' || extension == '.mdx') {
        paths.add(p.relative(entity.path, from: repoRoot.path));
      }
    }
  }

  final sorted = paths.toList()..sort();
  return sorted;
}

List<String> hardcodedDocVersionFindings(
  String content, {
  required String version,
  required String trainVersion,
}) {
  final findings = <String>[];
  final checks = <String, RegExp>{
    'current exact package version `$version`': RegExp(
      '\\b${RegExp.escape(version)}\\b',
    ),
    'current train version `$trainVersion`': RegExp(
      '\\b${RegExp.escape(trainVersion)}\\b',
    ),
    'hosted dependency floor `^$version`': RegExp(
      '\\^${RegExp.escape(version)}\\b',
    ),
    'IntentCall pre-1.0 train literal': RegExp(r'\b0\.\d+\.x\b'),
    'IntentCall hosted dependency literal': RegExp(r'\^0\.\d+\.\d+\b'),
    'IntentCall release tag example with literal version': RegExp(
      r'intentcall_[a-z_]+-v0\.\d+\.\d+\b',
    ),
  };

  for (final entry in checks.entries) {
    if (entry.value.hasMatch(content)) {
      findings.add(entry.key);
    }
  }
  return findings;
}

List<String> localDocumentationReferenceFindings(String content) {
  final findings = <String>[];
  final checks = <String, RegExp>{
    'home-relative path': RegExp(r'~\/[^\s)`\]]+'),
    'user-home absolute path': RegExp(r'\/Users\/[^\s)`\]]+'),
    'file URL': RegExp(r'file:\/\/[^\s)`\]]+'),
    'machine-local absolute path': RegExp(
      r'\/(?:private\/|var\/folders\/|tmp\/|Volumes\/)[^\s)`\]]+',
    ),
    'loopback endpoint': RegExp(
      r'\b(?:[a-z][a-z0-9+.-]*:\/\/)?(?:localhost|127\.0\.0\.1|0\.0\.0\.0)(?::\d+)?(?:\/[^\s)`\]]*)?',
      caseSensitive: false,
    ),
  };

  final lines = content.split('\n');
  for (var index = 0; index < lines.length; index += 1) {
    final line = lines[index];
    for (final entry in checks.entries) {
      final match = entry.value.firstMatch(line);
      if (match != null) {
        findings.add('line ${index + 1}: ${entry.key} `${match.group(0)}`');
      }
    }
  }
  return findings;
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

    final isPlatform = flutterPublishPackages.contains(pkg);
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
  final isPlatform = flutterPublishPackages.contains(release.package);
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
