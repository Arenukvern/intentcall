import 'dart:io';

import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
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
    _writeMinimalInfoPlist(p.join(temp.path, 'ios'));
    _writeMinimalInfoPlist(p.join(temp.path, 'macos'));
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
    expect(result.wroteIosInfoPlist, isTrue);
    expect(result.wroteMacosInfoPlist, isTrue);
    expect(result.wroteLinuxDesktop, isTrue);
    expect(result.wroteWindowsProtocol, isTrue);
    expect(result.changed, isTrue);
    expect(result.artifacts.map((final artifact) => artifact.target), [
      'android',
      'ios',
      'ios',
      'ios',
      'macos',
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
      result.artifacts.map((final artifact) => artifact.operation),
      contains('protocol-scheme'),
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
    _writeMinimalInfoPlist(p.join(temp.path, 'ios'));

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
    final infoPlist = _writeMinimalInfoPlist(p.join(temp.path, 'ios'));
    final before = projectFile.readAsStringSync();
    final plistBefore = infoPlist.readAsStringSync();

    const sync = PlatformSync();
    final result = sync.syncIos(projectRoot: temp.path, dryRun: true);

    expect(result.dryRun, isTrue);
    expect(result.changed, isTrue);
    expect(result.wroteIosGenerated, isTrue);
    expect(result.wroteIosXcodeProject, isTrue);
    expect(result.wroteIosInfoPlist, isTrue);
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
    expect(infoPlist.readAsStringSync(), plistBefore);
  });

  test('Apple sync target-members custom generated file names', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_native_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    File(
      p.join(temp.path, 'agent_manifest.json'),
    ).writeAsStringSync(manifestJson);
    Directory(p.join(temp.path, 'ios', 'Runner')).createSync(recursive: true);
    final projectFile = _writeMinimalXcodeProject(p.join(temp.path, 'ios'));
    _writeMinimalInfoPlist(p.join(temp.path, 'ios'));

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
    _writeMinimalInfoPlist(p.join(temp.path, 'ios'));

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
      _writeMinimalInfoPlist(p.join(temp.path, 'ios'));
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

  test('Apple sync adds protocol scheme to Info.plist idempotently', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_native_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    File(
      p.join(temp.path, 'agent_manifest.json'),
    ).writeAsStringSync(manifestJson);
    Directory(p.join(temp.path, 'ios', 'Runner')).createSync(recursive: true);
    _writeMinimalXcodeProject(p.join(temp.path, 'ios'));
    final infoPlist = _writeMinimalInfoPlist(p.join(temp.path, 'ios'));

    const sync = PlatformSync();
    final result = sync.syncIos(projectRoot: temp.path);
    final content = infoPlist.readAsStringSync();

    expect(result.iosInfoPlistPath, infoPlist.path);
    expect(result.wroteIosInfoPlist, isTrue);
    expect(content, contains('<key>CFBundleURLTypes</key>'));
    expect(content, contains('<key>CFBundleURLSchemes</key>'));
    expect(content, contains('<string>demoapp</string>'));
    expect(sync.checkIos(temp.path), isTrue);
    expect(sync.syncIos(projectRoot: temp.path, dryRun: true).changed, isFalse);
  });

  test('Apple check fails when Info.plist is missing protocol scheme', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_native_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    File(
      p.join(temp.path, 'agent_manifest.json'),
    ).writeAsStringSync(manifestJson);
    Directory(p.join(temp.path, 'ios', 'Runner')).createSync(recursive: true);
    _writeMinimalXcodeProject(p.join(temp.path, 'ios'));
    final infoPlist = _writeMinimalInfoPlist(p.join(temp.path, 'ios'));

    final sync = const PlatformSync()..syncIos(projectRoot: temp.path);
    infoPlist.writeAsStringSync(_minimalInfoPlistXml());

    expect(sync.checkIos(temp.path), isFalse);
  });

  test('Apple sync preserves existing URL types', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_native_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    File(
      p.join(temp.path, 'agent_manifest.json'),
    ).writeAsStringSync(manifestJson);
    Directory(p.join(temp.path, 'ios', 'Runner')).createSync(recursive: true);
    _writeMinimalXcodeProject(p.join(temp.path, 'ios'));
    final infoPlist = _writeMinimalInfoPlist(
      p.join(temp.path, 'ios'),
      extraContent: '''
\t<key>CFBundleURLTypes</key>
\t<array>
\t\t<dict>
\t\t\t<key>CFBundleTypeRole</key>
\t\t\t<string>Editor</string>
\t\t\t<key>CFBundleURLName</key>
\t\t\t<string>existingapp</string>
\t\t\t<key>CFBundleURLSchemes</key>
\t\t\t<array>
\t\t\t\t<string>existingapp</string>
\t\t\t</array>
\t\t</dict>
\t</array>
''',
    );

    final sync = const PlatformSync()..syncIos(projectRoot: temp.path);
    final content = infoPlist.readAsStringSync();

    expect(content, contains('<string>existingapp</string>'));
    expect(content, contains('<string>demoapp</string>'));
    expect(
      RegExp(r'<key>\s*CFBundleURLTypes\s*</key>').allMatches(content),
      hasLength(1),
    );
    expect(sync.checkIos(temp.path), isTrue);
  });
}

File _writeMinimalInfoPlist(
  final String appleRoot, {
  final String extraContent = '',
}) {
  final runnerDir = Directory(p.join(appleRoot, 'Runner'))
    ..createSync(recursive: true);
  return File(p.join(runnerDir.path, 'Info.plist'))
    ..writeAsStringSync(_minimalInfoPlistXml(extraContent: extraContent));
}

String _minimalInfoPlistXml({final String extraContent = ''}) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>CFBundleName</key>
\t<string>Runner</string>
$extraContent</dict>
</plist>
''';

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
