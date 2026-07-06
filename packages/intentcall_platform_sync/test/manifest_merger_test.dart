import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

void main() {
  test('ManifestMerger applies defaults and overlays', () {
    const merger = ManifestMerger();
    const policy = ProjectionPolicy(
      overlays: {
        'app_ping': EntryProjection(
          dispatchMode: AgentManifestDispatchMode.queueOnly,
          surfaces: {AgentManifestSurface.webMcp: false},
        ),
      },
    );
    final manifest = merger.mergeManifest(
      catalog: [
        AgentRegistryCatalogEntry(
          registryKey: 'app.ping',
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'ping',
            description: 'Ping',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{'type': 'object'},
          ),
        ),
      ],
      policy: policy,
      protocolScheme: 'myapp',
    );
    expect(manifest.protocolScheme, 'myapp');
    expect(
      manifest.entries.single.dispatchMode,
      AgentManifestDispatchMode.queueOnly,
    );
    expect(
      manifest.entries.single.surfaces.includes(
        AgentManifestSurface.webMcp,
        defaultValue: true,
      ),
      isFalse,
    );
  });
}
