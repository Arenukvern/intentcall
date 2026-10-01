import 'dart:io';

import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('PlatformSync reads custom layout.manifest and layout.webDir', () {
    final temp = Directory.systemTemp.createTempSync(
      'intentcall_platform_sync_layout_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));

    final assetsDir = Directory(p.join(temp.path, 'assets'))..createSync();
    final webDir = Directory(p.join(assetsDir.path, 'web'))..createSync();
    File(p.join(temp.path, 'intentcall.yaml')).writeAsStringSync('''
host: dart
layout:
  manifest: assets/agent_manifest.json
  webDir: assets/web
''');
    File(p.join(assetsDir.path, 'agent_manifest.json')).writeAsStringSync('''
{
  "version": 1,
  "platform": "web",
  "tools": [
    {
      "qualifiedName": "app_cart_total",
      "namespace": "app",
      "name": "cart_total",
      "description": "Return cart total",
      "kind": "tool",
      "inputSchema": {"type": "object"},
      "surfaces": {
        "web.webMcp": {"include": true},
        "web.manifestShortcuts": {"include": false},
        "web.protocolHandlers": {"include": false},
        "android.shortcuts": {"include": false},
        "apple.appShortcuts": {"include": false},
        "windows.protocolActivation": {"include": false},
        "windows.msixProtocol": {"include": false},
        "linux.schemeHandler": {"include": false}
      }
    }
  ]
}
''');
    File(p.join(webDir.path, 'manifest.json')).writeAsStringSync('''
{
  "name": "demo",
  "start_url": "."
}
''');

    const sync = PlatformSync();
    expect(
      sync.readManifest(temp.path).tools.single.qualifiedName,
      'app_cart_total',
    );
    final result = sync.syncWeb(projectRoot: temp.path);
    expect(result.wroteWebMcpJs, isTrue);
    expect(
      p.dirname(result.webMcpJsPath!),
      p.join(temp.path, 'assets', 'web'),
    );
    expect(sync.checkWeb(temp.path), isTrue);
  });
}
