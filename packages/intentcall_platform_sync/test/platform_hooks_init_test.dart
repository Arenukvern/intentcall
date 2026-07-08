import 'dart:io';

import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('platform_hooks_init_');
    Directory(p.join(tmp.path, 'web')).createSync();
    Directory(
      p.join(tmp.path, 'android', 'app', 'src', 'main'),
    ).createSync(recursive: true);
    Directory(
      p.join(tmp.path, 'ios', 'Runner.xcodeproj'),
    ).createSync(recursive: true);
    Directory(
      p.join(tmp.path, 'macos', 'Runner.xcodeproj'),
    ).createSync(recursive: true);
    File(
      p.join(tmp.path, 'web', 'index.html'),
    ).writeAsStringSync('<html></html>\n');
    File(
      p.join(tmp.path, 'android', 'app', 'build.gradle.kts'),
    ).writeAsStringSync('plugins {}\n');
    File(
      p.join(tmp.path, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    ).writeAsStringSync('<manifest><application></application></manifest>\n');
    File(
      p.join(tmp.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
    ).writeAsStringSync(
      '# intentcall-platform: begin\nflutter-mcp-toolkit codegen sync\n',
    );
    File(
      p.join(tmp.path, 'macos', 'Runner.xcodeproj', 'project.pbxproj'),
    ).writeAsStringSync(
      '# intentcall-platform: begin\nflutter-mcp-toolkit codegen sync\n',
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('apply then check passes for core hooks', () async {
    // No intentcall.yaml → flutter host defaults (web/android/ios/macos/…).
    const init = PlatformHooksInit();
    final applied = await init.run(projectRoot: tmp.path);
    expect(
      applied.targets.map((final t) => t.id).toSet(),
      containsAll(<String>{
        'web_index_html',
        'android_gradle',
        'android_manifest',
        'ios_codegen_script',
        'ios_xcode_run_script',
        'macos_codegen_script',
        'macos_xcode_run_script',
      }),
    );
    expect(
      applied.targets.firstWhere((final t) => t.id == 'web_index_html').ok,
      isTrue,
    );

    final checked = await init.run(projectRoot: tmp.path, checkOnly: true);
    expect(checked.ok, isTrue);
  });

  test('only patches platforms in platforms.enabled', () async {
    File(p.join(tmp.path, 'intentcall.yaml')).writeAsStringSync('''
host: flutter
platforms:
  enabled:
    - android
''');

    const init = PlatformHooksInit();
    final applied = await init.run(projectRoot: tmp.path);
    final ids = applied.targets.map((final t) => t.id).toSet();

    expect(ids, containsAll(<String>{'android_gradle', 'android_manifest'}));
    expect(
      ids.intersection(<String>{
        'web_index_html',
        'ios_codegen_script',
        'ios_xcode_run_script',
        'macos_codegen_script',
        'macos_xcode_run_script',
      }),
      isEmpty,
    );
    expect(
      applied.targets.every((final t) => t.ok),
      isTrue,
    );
  });
}
