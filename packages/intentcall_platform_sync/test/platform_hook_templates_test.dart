import 'dart:io';

import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('PlatformHookSpine', () {
    test('default flutter spine uses dart run cli invocation', () {
      final spine = PlatformHookSpine.resolve(
        const PlatformHookSpineInput(host: 'flutter'),
      );
      expect(spine.cliInvocation, kDefaultHookCliInvocation);
      expect(
        spine.manifestPhase.shellLine,
        contains('dart run intentcall_cli:intentcall manifest export --check'),
      );
      expect(spine.syncPhase.shellLine, contains('platform sync --platform'));
    });

    test('honors hooks.syncCommand override', () {
      final spine = PlatformHookSpine.resolve(
        const PlatformHookSpineInput(
          host: 'flutter',
          syncCommand: 'intentcall',
        ),
      );
      expect(spine.cliInvocation, 'intentcall');
      expect(
        spine.manifestPhase.argv,
        <String>['intentcall', 'manifest', 'export', '--check'],
      );
    });

    test('resolves platform list from yaml enabled platforms', () {
      final dir = Directory.systemTemp.createTempSync('hook_spine_yaml_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'intentcall.yaml')).writeAsStringSync('''
host: flutter
platforms:
  enabled:
    - web
    - android
hooks:
  syncCommand: intentcall
''');
      final spine = PlatformHookSpine.resolveFromProjectRoot(dir.path);
      expect(spine.platformList, <String>['web', 'android']);
      expect(spine.renderGradle(), contains('"intentcall"'));
      expect(spine.renderGradle(), contains('"android"'));
    });

    test('gradle template is generated from spine phases', () {
      final spine = kDefaultFlutterHookSpine;
      final gradle = spine.renderGradle();
      expect(gradle, contains(kPlatformHookMarkerBegin));
      expect(gradle, contains('build_runner'));
      expect(gradle, contains('manifest'));
      expect(gradle, contains('platform'));
      expect(gradle, contains('sync'));
      expect(gradle, contains(kPlatformHookMarkerEnd));
    });

    test('apple and jaspr templates include three-gate spine', () {
      final flutter = kDefaultFlutterHookSpine;
      final apple = flutter.renderAppleXcode();
      expect(apple, contains('build_runner build'));
      expect(apple, contains('manifest export --check'));
      expect(apple, contains('platform sync --platform'));

      final jaspr = kDefaultJasprHookSpine.renderJasprWeb();
      expect(jaspr, contains('build_runner build'));
      expect(jaspr, contains('platform sync --platform web'));
    });

    test('legacy template getters delegate to default spine', () {
      expect(kAndroidGradleCodegenHook, kDefaultFlutterHookSpine.renderGradle());
      expect(
        kAppleXcodeCodegenRunScript,
        kDefaultFlutterHookSpine.renderAppleXcode(),
      );
      expect(kJasprWebCodegenHook, kDefaultJasprHookSpine.renderJasprWeb());
    });

    test('tokenizeShellCommand supports quoted segments', () {
      expect(
        tokenizeShellCommand('dart run intentcall_cli:intentcall'),
        <String>['dart', 'run', 'intentcall_cli:intentcall'],
      );
      expect(
        tokenizeShellCommand('"dart run" intentcall'),
        <String>['dart run', 'intentcall'],
      );
    });
  });
}
