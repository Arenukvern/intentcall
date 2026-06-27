import 'dart:io';

import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const manifestJson = '''
{
  "version": 1,
  "platform": "android",
  "protocolScheme": "demoapp",
  "shortcuts": [
    {
      "qualifiedName": "app_cart_total",
      "namespace": "app",
      "name": "cart_total",
      "description": "Return cart total",
      "kind": "tool",
      "inputSchema": {"type": "object"}
    }
  ]
}
''';

  test('PlatformSync syncs android, ios, linux, windows', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_native_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));

    File(
      p.join(temp.path, 'agent_manifest.json'),
    ).writeAsStringSync(manifestJson);
    Directory(
      p.join(temp.path, 'android', 'app', 'src', 'main', 'res', 'xml'),
    ).createSync(recursive: true);
    Directory(p.join(temp.path, 'ios', 'Runner')).createSync(recursive: true);
    Directory(p.join(temp.path, 'macos', 'Runner')).createSync(recursive: true);
    _writeMinimalXcodeProject(p.join(temp.path, 'ios'));
    _writeMinimalXcodeProject(p.join(temp.path, 'macos'));
    Directory(p.join(temp.path, 'linux')).createSync();
    Directory(p.join(temp.path, 'windows')).createSync();

    const sync = PlatformSync();
    final result = sync.syncPlatforms(
      projectRoot: temp.path,
      platforms: ['android', 'ios', 'macos', 'linux', 'windows'],
    );

    expect(result.wroteAndroidShortcuts, isTrue);
    expect(result.wroteIosGenerated, isTrue);
    expect(result.wroteMacosGenerated, isTrue);
    expect(result.wroteIosXcodeProject, isTrue);
    expect(result.wroteMacosXcodeProject, isTrue);
    expect(result.wroteLinuxDesktop, isTrue);
    expect(result.wroteWindowsProtocol, isTrue);
    expect(result.changed, isTrue);
    expect(result.artifacts.map((final artifact) => artifact.target), [
      'android',
      'ios',
      'ios',
      'macos',
      'macos',
      'linux',
      'windows',
      'windows',
    ]);
    expect(
      result.artifacts.map((final artifact) => artifact.operation),
      contains('target-membership'),
    );

    expect(
      sync.checkPlatforms(temp.path, [
        'android',
        'ios',
        'macos',
        'linux',
        'windows',
      ]),
      isTrue,
    );
  });

  test('Apple check fails when generated Swift is not target-membered', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_native_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    File(
      p.join(temp.path, 'agent_manifest.json'),
    ).writeAsStringSync(manifestJson);
    Directory(
      p.join(temp.path, 'ios', 'Runner', 'Generated'),
    ).createSync(recursive: true);
    _writeMinimalXcodeProject(p.join(temp.path, 'ios'));

    const sync = PlatformSync();
    final manifest = sync.readManifest(temp.path);
    File(
      p.join(
        temp.path,
        'ios',
        'Runner',
        'Generated',
        'IntentCallGenerated.swift',
      ),
    ).writeAsStringSync('${sync.appleSwiftEmitter.emit(manifest)}\n');

    expect(sync.checkIos(temp.path), isFalse);
    sync.syncIos(projectRoot: temp.path);
    expect(sync.checkIos(temp.path), isTrue);
  });

  test('Apple dry run reports project drift without writing', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_native_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    File(
      p.join(temp.path, 'agent_manifest.json'),
    ).writeAsStringSync(manifestJson);
    Directory(p.join(temp.path, 'ios', 'Runner')).createSync(recursive: true);
    final projectFile = _writeMinimalXcodeProject(p.join(temp.path, 'ios'));
    final before = projectFile.readAsStringSync();

    const sync = PlatformSync();
    final result = sync.syncIos(projectRoot: temp.path, dryRun: true);

    expect(result.dryRun, isTrue);
    expect(result.changed, isTrue);
    expect(result.wroteIosGenerated, isTrue);
    expect(result.wroteIosXcodeProject, isTrue);
    expect(
      File(
        p.join(
          temp.path,
          'ios',
          'Runner',
          'Generated',
          'IntentCallGenerated.swift',
        ),
      ).existsSync(),
      isFalse,
    );
    expect(projectFile.readAsStringSync(), before);
  });

  test('Apple sync target-members custom generated file names', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_native_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    File(
      p.join(temp.path, 'agent_manifest.json'),
    ).writeAsStringSync(manifestJson);
    Directory(p.join(temp.path, 'ios', 'Runner')).createSync(recursive: true);
    final projectFile = _writeMinimalXcodeProject(p.join(temp.path, 'ios'));

    const sync = PlatformSync(appleGeneratedFileName: 'CustomIntentCall.swift');
    final result = sync.syncIos(projectRoot: temp.path);

    expect(result.iosGeneratedSwiftPath, endsWith('CustomIntentCall.swift'));
    expect(File(result.iosGeneratedSwiftPath!).existsSync(), isTrue);
    final project = projectFile.readAsStringSync();
    expect(project, contains('CustomIntentCall.swift in Sources'));
    expect(project, isNot(contains('IntentCallGenerated.swift')));
    expect(sync.checkIos(temp.path), isTrue);
  });

  test('Apple sync removes stale default generated file for custom names', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_native_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    File(
      p.join(temp.path, 'agent_manifest.json'),
    ).writeAsStringSync(manifestJson);
    Directory(p.join(temp.path, 'ios', 'Runner')).createSync(recursive: true);
    final projectFile = _writeMinimalXcodeProject(p.join(temp.path, 'ios'));

    const PlatformSync().syncIos(projectRoot: temp.path);
    final sync = const PlatformSync(
      appleGeneratedFileName: 'CustomIntentCall.swift',
    )..syncIos(projectRoot: temp.path);

    expect(
      File(
        p.join(
          temp.path,
          'ios',
          'Runner',
          'Generated',
          'IntentCallGenerated.swift',
        ),
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        p.join(
          temp.path,
          'ios',
          'Runner',
          'Generated',
          'CustomIntentCall.swift',
        ),
      ).existsSync(),
      isTrue,
    );
    final project = projectFile.readAsStringSync();
    expect(project, isNot(contains('IntentCallGenerated.swift')));
    expect(project, contains('CustomIntentCall.swift in Sources'));
    expect(sync.checkIos(temp.path), isTrue);
  });

  test(
    'Apple sync does not write generated Swift for unsupported projects',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'intentcall_native_sync_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      File(
        p.join(temp.path, 'agent_manifest.json'),
      ).writeAsStringSync(manifestJson);
      Directory(p.join(temp.path, 'ios', 'Runner')).createSync(recursive: true);
      Directory(p.join(temp.path, 'ios', 'Runner.xcodeproj')).createSync();
      File(
        p.join(temp.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
      ).writeAsStringSync('// unsupported\n');

      expect(
        () => const PlatformSync().syncIos(projectRoot: temp.path),
        throwsStateError,
      );
      expect(
        File(
          p.join(
            temp.path,
            'ios',
            'Runner',
            'Generated',
            'IntentCallGenerated.swift',
          ),
        ).existsSync(),
        isFalse,
      );
    },
  );
}

File _writeMinimalXcodeProject(final String appleRoot) {
  final projectDir = Directory(p.join(appleRoot, 'Runner.xcodeproj'))
    ..createSync(recursive: true);
  final projectFile = File(p.join(projectDir.path, 'project.pbxproj'))
    ..writeAsStringSync(r'''
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 54;
	objects = {

/* Begin PBXBuildFile section */
		111111111111111111111111 /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = 222222222222222222222222 /* AppDelegate.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		222222222222222222222222 /* AppDelegate.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
		555555555555555555555555 = {
			isa = PBXGroup;
			children = (
				666666666666666666666666 /* Runner */,
			);
			sourceTree = "<group>";
		};
		666666666666666666666666 /* Runner */ = {
			isa = PBXGroup;
			children = (
				222222222222222222222222 /* AppDelegate.swift */,
			);
			path = Runner;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		888888888888888888888888 /* Runner */ = {
			isa = PBXNativeTarget;
			buildPhases = (
				DDDDDDDDDDDDDDDDDDDDDDDD /* Sources */,
			);
			name = Runner;
			productName = Runner;
		};
/* End PBXNativeTarget section */

/* Begin PBXSourcesBuildPhase section */
		DDDDDDDDDDDDDDDDDDDDDDDD /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				111111111111111111111111 /* AppDelegate.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */
	};
	rootObject = FFFFFFFFFFFFFFFFFFFFFFFF;
}
''');
  return projectFile;
}
