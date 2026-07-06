import 'dart:io';

import 'package:args/args.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;

import '../utils/cli_utils.dart';

Future<int> runAppleAppIntentsTesting(
  final ArgResults command,
  final String projectRoot,
) async {
  final subcommand = command.command;
  if (subcommand == null) {
    printUsageError(
      'apple-appintents-testing requires generate-tests, generate-fixtures, or typecheck.',
    );
    return usageExitCode();
  }

  return switch (subcommand.name) {
    'generate-tests' => _generateTests(projectRoot, subcommand),
    'generate-fixtures' => _generateFixtures(projectRoot, subcommand),
    'typecheck' => _typecheck(subcommand),
    _ => usageExitCode(),
  };
}

Future<int> _generateTests(
  final String projectRoot,
  final ArgResults command,
) async {
  final bundleIdentifier = '${command['bundle-id'] ?? ''}'.trim();
  if (bundleIdentifier.isEmpty) {
    printUsageError(
      '--bundle-id is required for IntentDefinitions(bundleIdentifier:).',
    );
    return usageExitCode();
  }

  final manifestPath = resolveProjectPath(projectRoot, '${command['manifest']}');
  if (!manifestPath.existsSync()) {
    printUsageError('manifest not found: ${manifestPath.path}');
    return inputMissingExitCode();
  }

  final sampleArgumentsPath = '${command['sample-arguments'] ?? ''}'.trim();
  final entityFixturesPath = '${command['entity-fixtures'] ?? ''}'.trim();
  final outputPath = '${command['output'] ?? ''}'.trim();

  try {
    final swift = _emitAppleAppIntentsTestingScaffold(
      manifestFile: manifestPath,
      bundleIdentifier: bundleIdentifier,
      testClassName: '${command['test-class']}',
      sampleArgumentsFile: sampleArgumentsPath.isEmpty
          ? null
          : resolveProjectPath(projectRoot, sampleArgumentsPath),
      entityFixturesFile: entityFixturesPath.isEmpty
          ? null
          : resolveProjectPath(projectRoot, entityFixturesPath),
    );

    if (outputPath.isEmpty) {
      stdout.write(swift);
    } else {
      final output = resolveProjectPath(projectRoot, outputPath);
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(swift);
      stdout.writeln(
        'OK: wrote AppIntentsTesting XCTest scaffold to ${output.path}',
      );
    }
    stdout.writeln(
      'Proof label: generated AppIntentsTesting scaffold only. Run the scaffold in an XCTest UI-test bundle for runtime proof.',
    );
    return 0;
  } on FormatException catch (error) {
    printUsageError('invalid AppIntentsTesting input: ${error.message}');
    return dataErrorExitCode();
  } on UnsupportedError catch (error) {
    printUsageError('cannot generate AppIntentsTesting scaffold: $error');
    return dataErrorExitCode();
  } on StateError catch (error) {
    printUsageError('cannot generate AppIntentsTesting scaffold: $error');
    return dataErrorExitCode();
  }
}

Future<int> _generateFixtures(
  final String projectRoot,
  final ArgResults command,
) async {
  final sampleArgumentsOutput = '${command['sample-arguments-output'] ?? ''}'
      .trim();
  final entityFixturesOutput = '${command['entity-fixtures-output'] ?? ''}'
      .trim();
  if (sampleArgumentsOutput.isEmpty && entityFixturesOutput.isEmpty) {
    printUsageError(
      'generate-fixtures requires --sample-arguments-output, --entity-fixtures-output, or both.',
    );
    return usageExitCode();
  }

  final manifestPath = resolveProjectPath(projectRoot, '${command['manifest']}');
  if (!manifestPath.existsSync()) {
    printUsageError('manifest not found: ${manifestPath.path}');
    return inputMissingExitCode();
  }

  try {
    final manifest = AgentManifest.parse(manifestPath.readAsStringSync());
    if (sampleArgumentsOutput.isNotEmpty) {
      final output = resolveProjectPath(projectRoot, sampleArgumentsOutput);
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(
        '${encodePrettyJson(_sampleArgumentsTemplate(manifest))}\n',
      );
      stdout.writeln(
        'OK: wrote AppIntentsTesting sample arguments to ${output.path}',
      );
    }
    if (entityFixturesOutput.isNotEmpty) {
      final output = resolveProjectPath(projectRoot, entityFixturesOutput);
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(
        '${encodePrettyJson(_entityFixturesTemplate(manifest))}\n',
      );
      stdout.writeln(
        'OK: wrote AppIntentsTesting entity fixtures to ${output.path}',
      );
    }
    stdout.writeln(
      'Proof label: fixture template generation only. Replace placeholder values with seeded UI-test data before claiming runtime proof.',
    );
    return 0;
  } on FormatException catch (error) {
    printUsageError('invalid AppIntentsTesting input: ${error.message}');
    return dataErrorExitCode();
  } on UnsupportedError catch (error) {
    printUsageError('cannot generate AppIntentsTesting fixtures: $error');
    return dataErrorExitCode();
  }
}

Future<int> _typecheck(final ArgResults command) async {
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
    printUsageError('Xcode developer dir not found: ${developerDir.path}');
    return inputMissingExitCode();
  }
  if (!framework.existsSync()) {
    printUsageError(
      'AppIntentsTesting.framework not found at ${framework.path}. '
      'Install/select a full Xcode that contains Apple 27+ SDK testing frameworks.',
    );
    return inputMissingExitCode();
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
      <String>[
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
      printUsageError(
        'AppIntentsTesting import typecheck failed with exit code $swiftcCode.',
      );
      return swiftcCode;
    }

    final xcodebuild = await Process.run(
      'xcrun',
      <String>['xcodebuild', '-version'],
      environment: <String, String>{'DEVELOPER_DIR': developerDir.path},
    );
    stdout.write(xcodebuild.stdout);
    stderr.write(xcodebuild.stderr);
    if (xcodebuild.exitCode != 0) {
      return xcodebuild.exitCode;
    }
    stdout.writeln(
      'Proof label: AppIntentsTesting import compile proof only. This does not execute generated intents.',
    );
    return 0;
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

String _emitAppleAppIntentsTestingScaffold({
  required final File manifestFile,
  required final String bundleIdentifier,
  required final String testClassName,
  final File? sampleArgumentsFile,
  final File? entityFixturesFile,
}) {
  final manifest = AgentManifest.parse(manifestFile.readAsStringSync());
  return AppleAppIntentsTestingEmitter(
    bundleIdentifier: bundleIdentifier,
    testClassName: testClassName,
    sampleArguments: sampleArgumentsFile == null
        ? const <String, Map<String, Object?>>{}
        : _readSampleArguments(sampleArgumentsFile),
    entityFixtures: entityFixturesFile == null
        ? const <String, AppleAppIntentsTestingEntityFixture>{}
        : _readEntityFixtures(entityFixturesFile),
  ).emitUiTests(manifest);
}

Map<String, Map<String, Object?>> _sampleArgumentsTemplate(
  final AgentManifest manifest,
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
      sample[parameterName] = _sampleValueForSchema(
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

Map<String, Map<String, Object?>> _entityFixturesTemplate(
  final AgentManifest manifest,
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

Object? _sampleValueForSchema(
  final String schemaType, {
  required final String qualifiedName,
  required final String parameterName,
}) =>
    switch (schemaType) {
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

Map<String, Map<String, Object?>> _readSampleArguments(final File file) {
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

Map<String, AppleAppIntentsTestingEntityFixture> _readEntityFixtures(
  final File file,
) {
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

ArgParser buildAppleAppIntentsTestingParser() {
  return ArgParser()
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
      ArgParser()
        ..addOption(
          'xcode',
          help: 'Xcode.app path containing AppIntentsTesting.framework.',
          defaultsTo: '/Applications/Xcode-beta.app',
        ),
    );
}
