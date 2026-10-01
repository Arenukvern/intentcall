import 'dart:io';

import 'package:intentcall_platform_sync/src/sync/apple_xcode_project_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('adds generated Swift to the main Runner target sources', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_xcode_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final projectFile = _writeProject(temp);

    final result = const AppleXcodeProjectSync().sync(appleRoot: temp.path);

    expect(result.changed, isTrue);
    final content = projectFile.readAsStringSync();
    expect(_count(content, 'isa = PBXFileReference;'), 3);
    expect(_count(content, 'IntentCallGenerated.swift in Sources'), 2);
    expect(_runnerSourcesBlock(content), contains('IntentCallGenerated.swift'));
    expect(
      _runnerTestsSourcesBlock(content),
      isNot(contains('IntentCallGenerated.swift')),
    );
    expect(const AppleXcodeProjectSync().check(temp.path), isTrue);
  });

  test('is idempotent on repeated sync', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_xcode_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final projectFile = _writeProject(temp);

    const AppleXcodeProjectSync().sync(appleRoot: temp.path);
    final once = projectFile.readAsStringSync();
    final second = const AppleXcodeProjectSync().sync(appleRoot: temp.path);

    expect(second.changed, isFalse);
    expect(projectFile.readAsStringSync(), once);
  });

  test('repairs duplicate stale generated Swift references', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_xcode_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final projectFile = _writeProject(temp);
    var content = projectFile.readAsStringSync();
    content = content.replaceFirst(
      '/* End PBXFileReference section */',
      '\t\tAAAAAAAAAAAAAAAAAAAAAAAA /* IntentCallGenerated.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = IntentCallGenerated.swift; sourceTree = "<group>"; };\n'
          '\t\tBBBBBBBBBBBBBBBBBBBBBBBB /* IntentCallGenerated.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Generated/IntentCallGenerated.swift; sourceTree = "<group>"; };\n'
          '/* End PBXFileReference section */',
    );
    content = content.replaceFirst(
      'files = (\n',
      'files = (\n'
          '\t\t\t\tCCCCCCCCCCCCCCCCCCCCCCCC /* IntentCallGenerated.swift in Sources */,\n',
    );
    projectFile.writeAsStringSync(content);

    const AppleXcodeProjectSync().sync(appleRoot: temp.path);
    final repaired = projectFile.readAsStringSync();

    expect(repaired, isNot(contains('AAAAAAAAAAAAAAAAAAAAAAAA')));
    expect(repaired, isNot(contains('BBBBBBBBBBBBBBBBBBBBBBBB')));
    expect(repaired, isNot(contains('CCCCCCCCCCCCCCCCCCCCCCCC')));
    expect(_count(repaired, 'IntentCallGenerated.swift in Sources'), 2);
    expect(
      _runnerSourcesBlock(repaired),
      contains('IntentCallGenerated.swift'),
    );
  });

  test('removes the default generated Swift when custom file name is used', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_xcode_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final projectFile = _writeProject(temp);

    const AppleXcodeProjectSync().sync(appleRoot: temp.path);
    const AppleXcodeProjectSync(
      generatedFileName: 'CustomIntentCall.swift',
    ).sync(appleRoot: temp.path);

    final content = projectFile.readAsStringSync();
    expect(content, isNot(contains('IntentCallGenerated.swift')));
    expect(_runnerSourcesBlock(content), contains('CustomIntentCall.swift'));
    expect(
      const AppleXcodeProjectSync(
        generatedFileName: 'CustomIntentCall.swift',
      ).check(temp.path),
      isTrue,
    );
  });

  test('does not strip unrelated references containing a short custom name', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_xcode_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final projectFile = _writeProject(temp);
    var content = projectFile.readAsStringSync();
    content = content.replaceFirst(
      '/* End PBXFileReference section */',
      '\t\tAAAAAAAAAAAAAAAAAAAAAAAA /* MyA.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MyA.swift; sourceTree = "<group>"; };\n'
          '\t\tBBBBBBBBBBBBBBBBBBBBBBBB /* A.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Generated/A.swift; sourceTree = "<group>"; };\n'
          '/* End PBXFileReference section */',
    );
    content = content.replaceFirst(
      'files = (\n',
      'files = (\n'
          '\t\t\t\tCCCCCCCCCCCCCCCCCCCCCCCC /* MyA.swift in Sources */,\n'
          '\t\t\t\tDDDDDDDDDDDDDDDDDDDDDD01 /* A.swift in Sources */,\n',
    );
    projectFile.writeAsStringSync(content);

    const AppleXcodeProjectSync(
      generatedFileName: 'A.swift',
      staleGeneratedFileNames: <String>['A.swift'],
    ).sync(appleRoot: temp.path);
    final repaired = projectFile.readAsStringSync();

    expect(repaired, contains('MyA.swift'));
    expect(repaired, isNot(contains('BBBBBBBBBBBBBBBBBBBBBBBB')));
    expect(repaired, isNot(contains('DDDDDDDDDDDDDDDDDDDDDD01')));
  });

  test('dry run reports drift without modifying project', () {
    final temp = Directory.systemTemp.createTempSync('intentcall_xcode_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final projectFile = _writeProject(temp);
    final before = projectFile.readAsStringSync();

    final result = const AppleXcodeProjectSync().sync(
      appleRoot: temp.path,
      dryRun: true,
    );

    expect(result.changed, isTrue);
    expect(projectFile.readAsStringSync(), before);
  });
}

File _writeProject(final Directory root) {
  final projectDir = Directory(p.join(root.path, 'Runner.xcodeproj'))
    ..createSync(recursive: true);
  final projectFile = File(p.join(projectDir.path, 'project.pbxproj'))
    ..writeAsStringSync(_minimalPbxproj);
  return projectFile;
}

int _count(final String content, final String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(content).length;

String _runnerSourcesBlock(final String content) => RegExp(
  r'DDDDDDDDDDDDDDDDDDDDDDDD /\* Sources \*/ = \{[\s\S]*?\n\t\t\};',
).firstMatch(content)!.group(0)!;

String _runnerTestsSourcesBlock(final String content) => RegExp(
  r'EEEEEEEEEEEEEEEEEEEEEEEE /\* Sources \*/ = \{[\s\S]*?\n\t\t\};',
).firstMatch(content)!.group(0)!;

const _minimalPbxproj = r'''
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 54;
	objects = {

/* Begin PBXBuildFile section */
		111111111111111111111111 /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = 222222222222222222222222 /* AppDelegate.swift */; };
		333333333333333333333333 /* RunnerTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = 444444444444444444444444 /* RunnerTests.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		222222222222222222222222 /* AppDelegate.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
		444444444444444444444444 /* RunnerTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RunnerTests.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
		555555555555555555555555 = {
			isa = PBXGroup;
			children = (
				666666666666666666666666 /* Runner */,
				777777777777777777777777 /* RunnerTests */,
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
		777777777777777777777777 /* RunnerTests */ = {
			isa = PBXGroup;
			children = (
				444444444444444444444444 /* RunnerTests.swift */,
			);
			path = RunnerTests;
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
		999999999999999999999999 /* RunnerTests */ = {
			isa = PBXNativeTarget;
			buildPhases = (
				EEEEEEEEEEEEEEEEEEEEEEEE /* Sources */,
			);
			name = RunnerTests;
			productName = RunnerTests;
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
		EEEEEEEEEEEEEEEEEEEEEEEE /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				333333333333333333333333 /* RunnerTests.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */
	};
	rootObject = FFFFFFFFFFFFFFFFFFFFFFFF;
}
''';
