import 'dart:io';

import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Resolves `mcp_flutter/flutter_test_app` when cloned as a sibling of agentkit.
String? resolveMcpFlutterTestAppRoot() {
  final envRoot = Platform.environment['MCP_FLUTTER_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) {
    final candidate = p.normalize(p.join(envRoot, 'flutter_test_app'));
    if (File(p.join(candidate, 'web', 'agent_manifest.json')).existsSync()) {
      return candidate;
    }
  }

  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    final candidate = p.normalize(p.join(dir.path, '..', 'mcp_flutter'));
    final testApp = p.join(candidate, 'flutter_test_app');
    if (File(p.join(testApp, 'web', 'agent_manifest.json')).existsSync()) {
      return testApp;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  return null;
}

void main() {
  final projectRoot = resolveMcpFlutterTestAppRoot();

  group('mcp_flutter flutter_test_app Apple platform sync', () {
    test(
      'ios/macos artifacts are fresh and emit AppSetGreetingIntent',
      () {
        final root = projectRoot!;
        const sync = PlatformSync();
        expect(
          sync.checkPlatforms(root, const ['ios', 'macos']),
          isTrue,
          reason:
              'run: intentcall platform sync --platform ios,macos '
              '--project-dir $root',
        );

        for (final platform in const ['ios', 'macos']) {
          final swiftPath = p.join(
            root,
            platform,
            'Runner',
            'Generated',
            'IntentCallGenerated.swift',
          );
          final swift = File(swiftPath);
          expect(swift.existsSync(), isTrue, reason: swiftPath);
          final source = swift.readAsStringSync();
          expect(source, contains('import intentcall_platform_apple'));
          expect(source, isNot(contains('enum IntentCallNativeBridge {')));
          expect(source, contains('struct AppSetGreetingIntent: AppIntent'));
          expect(
            source,
            contains(
              'IntentCallNativeBridge.enqueue(qualifiedName: "app_set_greeting"',
            ),
          );
          expect(
            source,
            contains('AppShortcut(intent: AppSetGreetingIntent()'),
          );
        }
      },
      skip: projectRoot == null
          ? 'mcp_flutter sibling not found — clone ../mcp_flutter or set MCP_FLUTTER_ROOT'
          : false,
    );
  });
}
