import 'dart:io';

import 'package:intentcall_hooks/intentcall_hooks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String fixtureRoot(final String name) {
  final candidates = <String>[
    p.join('packages', 'intentcall_cli', 'test', 'fixtures', name),
    p.join('test', 'fixtures', name),
  ];
  for (final candidate in candidates) {
    final dir = Directory(candidate);
    if (dir.existsSync()) {
      return p.normalize(p.absolute(candidate));
    }
  }
  throw StateError(
    'fixture $name not found from ${Directory.current.path}',
  );
}

void main() {
  group('IntentCallHookRunner', () {
    late String projectRoot;

    setUpAll(() async {
      projectRoot = fixtureRoot('jaspr_web_project');
      final result = await Process.run(
        'dart',
        <String>['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
        workingDirectory: projectRoot,
        runInShell: true,
      );
      if (result.exitCode != 0) {
        fail(
          'build_runner failed for jaspr fixture:\n${result.stdout}\n${result.stderr}',
        );
      }
    });

    test('check spine passes on jaspr fixture', () async {
      final result = await const IntentCallHookRunner().run(
        projectRoot: projectRoot,
        checkOnly: true,
      );

      expect(result.platforms, <String>['web']);
      expect(result.manifestPath, endsWith('web/agent_manifest.json'));
      expect(result.dependencies, hasLength(3));
    });

    test('export+sync spine writes fresh artifacts', () async {
      final result = await const IntentCallHookRunner().run(
        projectRoot: projectRoot,
      );

      expect(result.platforms, <String>['web']);
      expect(File(result.manifestPath!).existsSync(), isTrue);
      expect(result.syncChanged, isFalse);
    });
  });
}
