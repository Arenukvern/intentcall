import 'dart:io';

import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../bin/intentcall.dart' as intentcall_cli;
import '../bin/release_train.dart' as release_train;

void main() {
  group('publish args', () {
    test('strict dry-run does not ignore warnings', () {
      expect(
        intentcall_cli.buildPublishArgs(dryRun: true, ignoreWarnings: false),
        ['pub', 'publish', '--dry-run'],
      );
    });

    test('diagnostic dry-run can ignore warnings', () {
      expect(
        intentcall_cli.buildPublishArgs(dryRun: true, ignoreWarnings: true),
        ['pub', 'publish', '--dry-run', '--ignore-warnings'],
      );
    });

    test('execute uses force without ignore warnings', () {
      expect(
        intentcall_cli.buildPublishArgs(dryRun: false, ignoreWarnings: false),
        ['pub', 'publish', '--force'],
      );
    });

    test('execute rejects ignore warnings', () async {
      final exitCode = await intentcall_cli.runPublishAll(
        Directory.systemTemp,
        dryRun: false,
        ignoreWarnings: true,
      );

      expect(exitCode, 64);
    });
  });

  group('release tag publishing', () {
    test('parses package release tags', () {
      final release = intentcall_cli.parsePackageReleaseTag(
        'intentcall_session-v0.1.2',
      );

      expect(release, isNotNull);
      expect(release!.package, 'intentcall_session');
      expect(release.version, '0.1.2');
    });

    test('rejects non-package release tags', () {
      expect(intentcall_cli.parsePackageReleaseTag('v0.1.2'), isNull);
      expect(
        intentcall_cli.parsePackageReleaseTag('intentcall_session-0.1.2'),
        isNull,
      );
    });

    test('detects same-train dependencies for publish waits', () {
      final dependencies = intentcall_cli.sameTrainDependencies(
        '''
dependencies:
  intentcall_core: ^0.2.0
  path: ^1.9.1
dev_dependencies:
  intentcall_testing: ^0.2.0
''',
        const intentcall_cli.PackageRelease(
          package: 'intentcall_mcp',
          version: '0.2.0',
        ),
      );

      expect(dependencies, ['intentcall_core', 'intentcall_testing']);
    });

    test('detects stale internal dependency floors', () {
      final mismatches = intentcall_cli.internalDependencyFloorMismatches(
        '''
dependencies:
  intentcall_core: ^0.2.0
  intentcall_schema: ^0.2.1
dev_dependencies:
  intentcall_testing: ^0.2.0
''',
        '0.2.1',
        packageName: 'intentcall_mcp',
      );

      expect(mismatches, [
        'intentcall_mcp depends on intentcall_core ^0.2.0, expected ^0.2.1',
        'intentcall_mcp depends on intentcall_testing ^0.2.0, expected ^0.2.1',
      ]);
    });

    test('derives major/minor train from package version', () {
      expect(intentcall_cli.majorMinorTrain('0.3.0'), '0.3.x');
      expect(intentcall_cli.majorMinorTrain('1.2.3'), '1.2.x');
    });

    test('detects hardcoded docs package versions', () {
      final findings = intentcall_cli.hardcodedDocVersionFindings(
        '''
Pre-release `0.3.x` train.
dependencies:
  intentcall_core: ^0.3.0
Release tag: intentcall_core-v0.3.0
''',
        version: '0.3.0',
        trainVersion: '0.3.x',
      );

      expect(findings, contains('current exact package version `0.3.0`'));
      expect(findings, contains('current train version `0.3.x`'));
      expect(findings, contains('hosted dependency floor `^0.3.0`'));
      expect(findings, contains('IntentCall pre-1.0 train literal'));
      expect(findings, contains('IntentCall hosted dependency literal'));
      expect(
        findings,
        contains('IntentCall release tag example with literal version'),
      );
    });

    test('allows version-neutral docs guidance', () {
      final findings = intentcall_cli.hardcodedDocVersionFindings(
        '''
Pre-release train.
Run dart pub add intentcall_core intentcall_schema.
Use intentcall_core-v<version> for release tag examples.
''',
        version: '0.3.0',
        trainVersion: '0.3.x',
      );

      expect(findings, isEmpty);
    });

    test('detects local-only docs references', () {
      final findings = intentcall_cli.localDocumentationReferenceFindings('''
Clone path: ~/mcp/agentkit
Absolute path: /Users/alice/work/agentkit
File URL: file:///Users/alice/work/agentkit/docs
Temp path: /var/folders/example/screenshot.png
Loopback URL: ws://127.0.0.1:8181/ws
Custom loopback URI: visual://localhost/view/details
''');

      expect(findings, contains(contains('home-relative path')));
      expect(findings, contains(contains('user-home absolute path')));
      expect(findings, contains(contains('file URL')));
      expect(findings, contains(contains('machine-local absolute path')));
      expect(findings, contains(contains('loopback endpoint')));
    });

    test('allows repo-relative and public docs references', () {
      final findings = intentcall_cli.localDocumentationReferenceFindings('''
[North Star](/NORTH_STAR)
Use ../agentkit/packages/intentcall_core during local development.
Use wss://runtime.example.com/ws for placeholder runtime docs.
INTENTCALL_ROOT="\$(pwd)/../agentkit" make check-intentcall-integration
''');

      expect(findings, isEmpty);
    });

    test('reads CocoaPods podspec versions', () {
      expect(
        intentcall_cli.podspecVersion(
          "Pod::Spec.new do |s|\n  s.version          = '0.3.0'\nend\n",
        ),
        '0.3.0',
      );
    });

    test('validates Swift Package Manager plugin layout', () async {
      final packageRoot = await Directory.systemTemp.createTemp(
        'intentcall_platform_spm_',
      );
      addTearDown(() => packageRoot.deleteSync(recursive: true));

      await _writeSwiftPackageFixture(
        packageRoot,
        packageDir: 'ios',
        platform: '.iOS("13.0")',
        importLine: 'import Flutter',
      );
      await _writeSwiftPackageFixture(
        packageRoot,
        packageDir: 'macos',
        platform: '.macOS("10.14")',
        importLine: 'import FlutterMacOS',
      );

      expect(
        await intentcall_cli.swiftPackageManagerFindings(packageRoot),
        isEmpty,
      );

      File(
        p.join(
          packageRoot.path,
          'macos',
          'intentcall_platform',
          'Sources',
          'intentcall_platform',
          'IntentCallPlatformPlugin.swift',
        ),
      ).deleteSync();

      expect(
        await intentcall_cli.swiftPackageManagerFindings(packageRoot),
        contains(
          'macos/intentcall_platform/Sources/intentcall_platform/IntentCallPlatformPlugin.swift is missing',
        ),
      );
    });
  });

  group('Apple AppIntentsTesting CLI helpers', () {
    test('reads entity fixtures from JSON', () async {
      final dir = await Directory.systemTemp.createTemp(
        'intentcall_appintents_fixtures_',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'entities.json'))
        ..writeAsStringSync('''
{
  "app_project": {
    "identifier": "project-1",
    "search": "Apollo",
    "expectedTitle": "Apollo Roadmap"
  }
}
''');

      final fixtures = intentcall_cli.readAppleAppIntentsTestingEntityFixtures(
        file,
      );

      expect(fixtures.keys, ['app_project']);
      expect(fixtures['app_project']!.identifier, 'project-1');
      expect(fixtures['app_project']!.search, 'Apollo');
      expect(fixtures['app_project']!.expectedTitle, 'Apollo Roadmap');
    });

    test('rejects incomplete entity fixtures', () async {
      final dir = await Directory.systemTemp.createTemp(
        'intentcall_appintents_bad_fixtures_',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'entities.json'))
        ..writeAsStringSync('{"app_project":{"identifier":"project-1"}}');

      expect(
        () => intentcall_cli.readAppleAppIntentsTestingEntityFixtures(file),
        throwsFormatException,
      );
    });

    test('derives starter fixture JSON from manifest', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'apple',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_echo',
            'namespace': 'app',
            'name': 'echo',
            'description': 'Echo',
            'kind': 'tool',
            'inputSchema': <String, Object?>{
              'type': 'object',
              'required': <String>['message', 'count', 'ratio', 'enabled'],
              'properties': <String, Object?>{
                'message': <String, Object?>{'type': 'string'},
                'count': <String, Object?>{'type': 'integer'},
                'ratio': <String, Object?>{'type': 'number'},
                'enabled': <String, Object?>{'type': 'boolean'},
                'optionalNote': <String, Object?>{'type': 'string'},
              },
            },
          },
        ],
        'entityTypes': [
          <String, Object?>{
            'qualifiedName': 'app_project',
            'namespace': 'app',
            'name': 'project',
            'displayName': 'Project',
            'description': 'Project',
            'idKey': 'projectId',
          },
        ],
      });

      expect(
        intentcall_cli.appIntentsTestingSampleArgumentsTemplate(manifest),
        {
          'app_echo': {
            'message': '<sample string>',
            'count': 1,
            'ratio': 1.0,
            'enabled': true,
          },
        },
      );
      expect(intentcall_cli.appIntentsTestingEntityFixturesTemplate(manifest), {
        'app_project': {
          'identifier': '<projectId>',
          'search': '<search text>',
          'expectedTitle': '<Project title>',
        },
      });
    });

    test('emits scaffold from manifest and JSON fixtures', () async {
      final dir = await Directory.systemTemp.createTemp(
        'intentcall_appintents_scaffold_',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      final manifest = File(p.join(dir.path, 'agent_manifest.json'))
        ..writeAsStringSync('''
{
  "version": 1,
  "platform": "apple",
  "tools": [
    {
      "qualifiedName": "app_echo",
      "namespace": "app",
      "name": "echo",
      "description": "Echo",
      "kind": "tool",
      "inputSchema": {
        "type": "object",
        "required": ["message"],
        "properties": {
          "message": {"type": "string"}
        }
      }
    }
  ],
  "entityTypes": [
    {
      "qualifiedName": "app_project",
      "namespace": "app",
      "name": "project",
      "displayName": "Project",
      "description": "Project"
    }
  ]
}
''');
      final sampleArguments = File(p.join(dir.path, 'arguments.json'))
        ..writeAsStringSync('''
{
  "app_echo": {
    "message": "hello"
  }
}
''');
      final entityFixtures = File(p.join(dir.path, 'entities.json'))
        ..writeAsStringSync('''
{
  "app_project": {
    "identifier": "project-1",
    "search": "Apollo",
    "expectedTitle": "Apollo Roadmap"
  }
}
''');

      final swift = intentcall_cli.emitAppleAppIntentsTestingScaffold(
        manifestFile: manifest,
        bundleIdentifier: 'com.example.intentcall',
        testClassName: 'IntentCallAppIntentsTests',
        sampleArgumentsFile: sampleArguments,
        entityFixturesFile: entityFixtures,
      );

      expect(swift, contains('final class IntentCallAppIntentsTests'));
      expect(
        swift,
        contains(
          'IntentDefinitions(bundleIdentifier: "com.example.intentcall")',
        ),
      );
      expect(
        swift,
        contains(
          'definitions.intents["AppEchoIntent"].makeIntent(message: "hello")',
        ),
      );
      expect(swift, contains('definitions.entities["AppProjectEntity"]'));
      expect(swift, contains('spotlightQuery("Apollo")'));
    });
  });

  group('release train sync', () {
    test('checks and synchronizes dependency floors and podspecs', () async {
      final repo = await _createReleaseTrainFixture();
      addTearDown(() => repo.deleteSync(recursive: true));

      expect(await release_train.runReleaseTrainCheck(repo), 1);

      final syncCode = await release_train.runReleaseTrainSync(repo);

      expect(syncCode, 0);
      expect(await release_train.runReleaseTrainCheck(repo), 0);
      expect(
        File(
          p.join(repo.path, 'packages', 'intentcall_session', 'pubspec.yaml'),
        ).readAsStringSync(),
        contains('  intentcall_schema: ^0.6.0'),
      );
      expect(
        File(
          p.join(repo.path, 'packages', 'intentcall_gemma', 'pubspec.yaml'),
        ).readAsStringSync(),
        contains('  intentcall_testing: ^0.6.0'),
      );
      expect(
        File(
          p.join(
            repo.path,
            'packages',
            'intentcall_platform',
            'ios',
            'intentcall_platform.podspec',
          ),
        ).readAsStringSync(),
        contains("s.version          = '0.6.0'"),
      );
    });

    test('check-only sync reports stale metadata without writing', () async {
      final repo = await _createReleaseTrainFixture();
      addTearDown(() => repo.deleteSync(recursive: true));
      final pubspec = File(
        p.join(repo.path, 'packages', 'intentcall_core', 'pubspec.yaml'),
      );
      final before = pubspec.readAsStringSync();

      final syncCode = await release_train.runReleaseTrainSync(
        repo,
        checkOnly: true,
      );

      expect(syncCode, 1);
      expect(pubspec.readAsStringSync(), before);
    });
  });

  group('runReleaseGitCleanCheck', () {
    test('passes when release-critical files are clean', () async {
      final repo = await _createGitRepo();
      addTearDown(() => repo.deleteSync(recursive: true));

      final exitCode = await intentcall_cli.runReleaseGitCleanCheck(repo);

      expect(exitCode, 0);
    });

    test('fails for untracked files in publish package tree', () async {
      final repo = await _createGitRepo();
      addTearDown(() => repo.deleteSync(recursive: true));
      final file = File(
        p.join(repo.path, 'packages', 'intentcall_core', 'lib', 'new_api.dart'),
      );
      file.createSync(recursive: true);
      file.writeAsStringSync('library;\n');

      final exitCode = await intentcall_cli.runReleaseGitCleanCheck(repo);

      expect(exitCode, 1);
    });

    test('fails for modified tracked files in publish package tree', () async {
      final repo = await _createGitRepo();
      addTearDown(() => repo.deleteSync(recursive: true));
      final file = File(
        p.join(repo.path, 'packages', 'intentcall_core', 'lib', 'api.dart'),
      );
      file.createSync(recursive: true);
      file.writeAsStringSync('library;\n');
      await _runGit(repo, ['add', '.']);
      await _runGit(repo, [
        '-c',
        'user.name=IntentCall Test',
        '-c',
        'user.email=intentcall@example.invalid',
        'commit',
        '-m',
        'initial',
      ]);
      file.writeAsStringSync('library;\n\nfinal answer = 42;\n');

      final exitCode = await intentcall_cli.runReleaseGitCleanCheck(repo);

      expect(exitCode, 1);
    });

    test('fails for untracked files in release tooling', () async {
      final repo = await _createGitRepo();
      addTearDown(() => repo.deleteSync(recursive: true));
      final file = File(
        p.join(repo.path, 'tool', 'intentcall', 'lib', 'publish_helper.dart'),
      );
      file.createSync(recursive: true);
      file.writeAsStringSync('library;\n');

      final exitCode = await intentcall_cli.runReleaseGitCleanCheck(repo);

      expect(exitCode, 1);
    });

    test('ignores untracked files outside release-critical paths', () async {
      final repo = await _createGitRepo();
      addTearDown(() => repo.deleteSync(recursive: true));
      final file = File(
        p.join(repo.path, 'packages', 'scratch_tool', 'lib', 'scratch.dart'),
      );
      file.createSync(recursive: true);
      file.writeAsStringSync('library;\n');

      final exitCode = await intentcall_cli.runReleaseGitCleanCheck(repo);

      expect(exitCode, 0);
    });
  });
}

Future<Directory> _createGitRepo() async {
  final repo = await Directory.systemTemp.createTemp('intentcall_cli_test_');
  final result = await Process.run('git', [
    'init',
  ], workingDirectory: repo.path);
  if (result.exitCode != 0) {
    throw StateError('git init failed: ${result.stderr}');
  }
  return repo;
}

Future<Directory> _createReleaseTrainFixture() async {
  final repo = await Directory.systemTemp.createTemp(
    'intentcall_release_train_',
  );
  File(p.join(repo.path, 'pubspec.yaml'))
    ..createSync(recursive: true)
    ..writeAsStringSync('name: intentcall_workspace\npublish_to: none\n');
  File(p.join(repo.path, '.release-please-manifest.json')).writeAsStringSync('''
{
  "packages/intentcall_schema": "0.6.0",
  "packages/intentcall_core": "0.6.0",
  "packages/intentcall_session": "0.6.0",
  "packages/intentcall_mcp": "0.6.0",
  "packages/intentcall_webmcp": "0.6.0",
  "packages/intentcall_apple": "0.6.0",
  "packages/intentcall_android": "0.6.0",
  "packages/intentcall_codegen": "0.6.0",
  "packages/intentcall_platform": "0.6.0",
  "packages/intentcall_testing": "0.6.0"
}
''');

  for (final packageName in release_train.publishablePackages) {
    final deps = switch (packageName) {
      'intentcall_schema' => '',
      'intentcall_core' => '  intentcall_schema: ^0.5.0\n',
      'intentcall_session' =>
        '  intentcall_core: ^0.5.0\n  intentcall_schema: ^0.5.0\n',
      'intentcall_mcp' =>
        '  intentcall_core: ^0.5.0\n  intentcall_schema: ^0.5.0\n',
      'intentcall_webmcp' =>
        '  intentcall_core: ^0.5.0\n  intentcall_testing: ^0.5.0\n',
      'intentcall_apple' => '  intentcall_core: ^0.5.0\n',
      'intentcall_android' => '  intentcall_core: ^0.5.0\n',
      'intentcall_codegen' =>
        '  intentcall_core: ^0.5.0\n  intentcall_schema: ^0.5.0\n',
      'intentcall_platform' =>
        '  intentcall_core: ^0.5.0\n  intentcall_schema: ^0.5.0\n',
      'intentcall_testing' =>
        '  intentcall_core: ^0.5.0\n  intentcall_schema: ^0.5.0\n',
      _ => '',
    };
    _writePubspec(repo, packageName, version: '0.6.0', dependencies: deps);
  }

  _writePubspec(
    repo,
    'intentcall_gemma',
    version: '0.1.0',
    publishToNone: true,
    dependencies:
        '  intentcall_core: ^0.5.0\n'
        '  intentcall_schema: ^0.5.0\n'
        '  intentcall_testing: ^0.5.0\n',
  );

  for (final platform in ['ios', 'macos']) {
    final podspec = File(
      p.join(
        repo.path,
        'packages',
        'intentcall_platform',
        platform,
        'intentcall_platform.podspec',
      ),
    )..createSync(recursive: true);
    podspec.writeAsStringSync('''
Pod::Spec.new do |s|
  s.name             = 'intentcall_platform'
  s.version          = '0.5.0'
end
''');
  }

  return repo;
}

void _writePubspec(
  Directory repo,
  String packageName, {
  required String version,
  String dependencies = '',
  bool publishToNone = false,
}) {
  final file = File(p.join(repo.path, 'packages', packageName, 'pubspec.yaml'))
    ..createSync(recursive: true);
  file.writeAsStringSync('''
name: $packageName
${publishToNone ? 'publish_to: none\n' : ''}version: $version
environment:
  sdk: ^3.9.0
dependencies:
$dependencies''');
}

Future<void> _runGit(Directory repo, List<String> args) async {
  final result = await Process.run('git', args, workingDirectory: repo.path);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

Future<void> _writeSwiftPackageFixture(
  Directory packageRoot, {
  required String packageDir,
  required String platform,
  required String importLine,
}) async {
  final spmRoot = Directory(
    p.join(packageRoot.path, packageDir, 'intentcall_platform'),
  );
  final sourceDir = Directory(
    p.join(spmRoot.path, 'Sources', 'intentcall_platform'),
  )..createSync(recursive: true);

  File(p.join(spmRoot.path, 'Package.swift')).writeAsStringSync('''
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "intentcall_platform",
    platforms: [
        $platform
    ],
    products: [
        .library(name: "intentcall-platform", targets: ["intentcall_platform"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "intentcall_platform",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
''');

  File(
    p.join(sourceDir.path, 'IntentCallPlatformPlugin.swift'),
  ).writeAsStringSync('''
$importLine

public class IntentCallPlatformPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {}

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let channel = "intentcall_platform/invocations"
    result(channel)
  }
}
''');

  File(p.join(sourceDir.path, 'PrivacyInfo.xcprivacy')).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict/></plist>
''');
}
