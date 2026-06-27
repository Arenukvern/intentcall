import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../bin/intentcall.dart' as intentcall_cli;

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
