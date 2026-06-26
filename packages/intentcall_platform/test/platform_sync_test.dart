import 'dart:io';

import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('PlatformSync.syncWeb writes manifest and js artifacts', () {
    final temp = Directory.systemTemp.createTempSync(
      'intentcall_platform_sync_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));

    final webDir = Directory(p.join(temp.path, 'web'))..createSync();
    File(p.join(temp.path, 'agent_manifest.json')).writeAsStringSync('''
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
      "inputSchema": {"type": "object"}
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
    final result = sync.syncWeb(projectRoot: temp.path);
    expect(result.wroteManifest, isTrue);
    expect(result.wroteWebMcpJs, isTrue);
    expect(result.changed, isTrue);
    expect(result.artifacts, hasLength(2));
    expect(
      result.artifacts.map((final artifact) => artifact.kind),
      containsAll(<String>['web-manifest', 'webmcp-js']),
    );
    expect(File(result.webMcpJsPath!).existsSync(), isTrue);
    expect(
      File(result.webManifestPath!).readAsStringSync(),
      contains('"shortcuts"'),
    );
    expect(sync.checkWeb(temp.path), isTrue);
  });
}
