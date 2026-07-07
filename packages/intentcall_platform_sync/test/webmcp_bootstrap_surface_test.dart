import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('ManifestSurfaceIndex excludes web.webMcp:false tools', () {
    final manifest = AgentManifest.parse('''
{
  "version": 1,
  "platform": "web",
  "tools": [
    {
      "qualifiedName": "app_demo_ping",
      "namespace": "app",
      "name": "demo_ping",
      "description": "ping",
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
    },
    {
      "qualifiedName": "app_demo_cart",
      "namespace": "app",
      "name": "demo_cart",
      "description": "cart",
      "kind": "tool",
      "inputSchema": {"type": "object"},
      "surfaces": {
        "web.webMcp": {"include": false},
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
    final index = ManifestSurfaceIndex.fromManifest(manifest);

    expect(index.includesWebMcp('app_demo_ping'), isTrue);
    expect(index.includesWebMcp('app_demo_cart'), isFalse);
    expect(
      index.includes(
        'app_unknown',
        AgentManifestSurface.webMcp,
        defaultValue: false,
      ),
      isFalse,
    );
  });

  test('registerAgentWebMcpFromRegistry accepts surface index on VM', () {
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'echo',
            description: 'echo',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{},
            },
          ),
          execute: (_) async => AgentResult.success(),
        ),
      );
    final index = ManifestSurfaceIndex.fromManifest(
      AgentManifest.parse('''
{
  "version": 1,
  "platform": "web",
  "tools": [
    {
      "qualifiedName": "app_echo",
      "namespace": "app",
      "name": "echo",
      "description": "echo",
      "kind": "tool",
      "inputSchema": {"type": "object"},
      "surfaces": {
        "web.webMcp": {"include": false},
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
'''),
    );

    expect(
      () => registerAgentWebMcpFromRegistry(
        registry,
        surfaceIndex: index,
      ),
      returnsNormally,
    );
  });
}
