import 'dart:io';

import 'package:intentcall_cli/src/command_runner.dart';
import 'package:intentcall_cli/src/config/intentcall_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory flutterFixture;
  late Directory jasprFixture;

  setUpAll(() {
    flutterFixture = _fixtureRoot('flutter_project');
    jasprFixture = _fixtureRoot('jaspr_web_project');
  });

  group('IntentCallCommandRunner', () {
    test('prints usage for missing command', () async {
      final runner = IntentCallCommandRunner();
      expect(await runner.run(<String>[]) ?? 64, 64);
    });

    test('config show reads intentcall.yaml', () async {
      final runner = IntentCallCommandRunner();
      final exitCode = await runner.run(<String>[
        'config',
        'show',
        '--json',
        '--project-dir',
        flutterFixture.path,
      ]);
      expect(exitCode, 0);
    });

    test('config validate fails for flutter with empty platforms.enabled',
        () async {
      final root = _tempConfigProject(
        'host: flutter\nplatforms:\n  enabled: []\n',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final exitCode = await IntentCallCommandRunner().run(<String>[
        'config',
        'validate',
        '--project-dir',
        root.path,
      ]);
      expect(exitCode, 65);
    });

    test('config validate passes for flutter with explicit platforms.enabled',
        () async {
      final root = _tempConfigProject(
        'host: flutter\n'
        'platforms:\n'
        '  enabled:\n'
        '    - android\n'
        '    - ios\n',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final exitCode = await IntentCallCommandRunner().run(<String>[
        'config',
        'validate',
        '--project-dir',
        root.path,
      ]);
      expect(exitCode, 0);
    });

    test('config validate fails for jaspr with empty platforms.enabled',
        () async {
      final root = _tempConfigProject(
        'host: jaspr\nplatforms:\n  enabled: []\n',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final exitCode = await IntentCallCommandRunner().run(<String>[
        'config',
        'validate',
        '--project-dir',
        root.path,
      ]);
      expect(exitCode, 65);
    });

    test('config validate passes for dart with empty platforms.enabled',
        () async {
      final root = _tempConfigProject(
        'host: dart\nplatforms:\n  enabled: []\n',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final exitCode = await IntentCallCommandRunner().run(<String>[
        'config',
        'validate',
        '--project-dir',
        root.path,
      ]);
      expect(exitCode, 0);
    });

    test('manifest validate accepts fixture manifest', () async {
      final runner = IntentCallCommandRunner();
      final exitCode = await runner.run(<String>[
        'manifest',
        'validate',
        '--project-dir',
        flutterFixture.path,
      ]);
      expect(exitCode, 0);
    });

    test('manifest export --check passes for synced fixture manifest', () async {
      final runner = IntentCallCommandRunner();
      final exitCode = await runner.run(<String>[
        'manifest',
        'export',
        '--check',
        '--project-dir',
        flutterFixture.path,
      ]);
      expect(exitCode, 0);
    });

    test('platform sync --check passes for flutter fixture', () async {
      final runner = IntentCallCommandRunner();
      final exitCode = await runner.run(<String>[
        'platform',
        'sync',
        '--platform',
        'web',
        '--check',
        '--project-dir',
        flutterFixture.path,
      ]);
      expect(exitCode, 0);
    });

    test('platform sync --check passes for jaspr fixture', () async {
      final runner = IntentCallCommandRunner();
      final exitCode = await runner.run(<String>[
        'platform',
        'sync',
        '--platform',
        'web',
        '--check',
        '--project-dir',
        jasprFixture.path,
      ]);
      expect(exitCode, 0);
    });

    test('codegen sync aliases platform sync', () async {
      final runner = IntentCallCommandRunner();
      final exitCode = await runner.run(<String>[
        'codegen',
        'sync',
        '--platform',
        'web',
        '--check',
        '--project-dir',
        jasprFixture.path,
      ]);
      expect(exitCode, 0);
    });

    test('platform hooks print emits android snippet', () async {
      final runner = IntentCallCommandRunner();
      final exitCode = await runner.run(<String>[
        'platform',
        'hooks',
        'print',
        '--platform',
        'android',
      ]);
      expect(exitCode, 0);
    });

    test('hooks spine --json resolves from fixture', () async {
      final runner = IntentCallCommandRunner();
      final exitCode = await runner.run(<String>[
        'hooks',
        'spine',
        '--json',
        '--project-dir',
        flutterFixture.path,
      ]);
      expect(exitCode, 0);
    });

    test('hooks render emits jaspr snippet for host', () async {
      final runner = IntentCallCommandRunner();
      final exitCode = await runner.run(<String>[
        'hooks',
        'render',
        '--host',
        'jaspr',
        '--platform',
        'web',
        '--project-dir',
        jasprFixture.path,
      ]);
      expect(exitCode, 0);
    });
  });

  group('IntentCallConfig', () {
    test('parses host and layout fields', () {
      final file = File(p.join(flutterFixture.path, 'intentcall.yaml'));
      final config = IntentCallConfig.parse(file.readAsStringSync());
      expect(config.host, IntentCallHost.flutter);
      expect(config.protocolScheme, 'demoapp');
      expect(config.layout.manifest, 'web/agent_manifest.json');
    });
  });
}

Directory _fixtureRoot(final String name) {
  final candidates = <String>[
    p.join(Directory.current.path, 'test', 'fixtures', name),
    p.join(Directory.current.path, 'packages/intentcall_cli/test/fixtures', name),
  ];
  for (final candidate in candidates) {
    final root = Directory(candidate);
    if (root.existsSync()) {
      return Directory(p.normalize(p.absolute(candidate)));
    }
  }
  throw StateError('Missing fixture directory for $name');
}

Directory _tempConfigProject(final String yaml) {
  final root = Directory.systemTemp.createTempSync('intentcall_config_validate_');
  File(p.join(root.path, 'intentcall.yaml')).writeAsStringSync(yaml);
  return root;
}
