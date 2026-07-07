import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

void main() {
  test('ManifestMerger applies defaults and catalog row projection', () {
    const merger = ManifestMerger();
    const policy = ProjectionPolicy();
    final manifest = merger.mergeManifest(
      catalog: [
        AgentRegistryCatalogEntry(
          registryKey: 'app_ping',
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'ping',
            description: 'Ping',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{'type': 'object'},
          ),
          projection: const EntryProjection(
            dispatchMode: AgentManifestDispatchMode.queueOnly,
            surfaces: {AgentManifestSurface.webMcp: false},
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

  test('web-only enabledPlatforms scopes default surfaces', () {
    const merger = ManifestMerger();
    const policy = ProjectionPolicy();
    final manifest = merger.mergeManifest(
      catalog: [
        AgentRegistryCatalogEntry(
          registryKey: 'app_ping',
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
      enabledPlatforms: ['web'],
    );
    final surfaces = manifest.entries.single.surfaces;
    expect(
      surfaces.includes(AgentManifestSurface.webMcp, defaultValue: false),
      isTrue,
    );
    expect(
      surfaces.includes(AgentManifestSurface.androidShortcuts, defaultValue: true),
      isFalse,
    );
    expect(
      surfaces.includes(
        AgentManifestSurface.windowsProtocolActivation,
        defaultValue: true,
      ),
      isFalse,
    );
  });
}
