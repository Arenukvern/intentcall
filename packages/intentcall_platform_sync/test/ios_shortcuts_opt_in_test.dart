import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

void main() {
  test('ios enabled keeps apple.appShortcuts opt-in false', () {
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
      enabledPlatforms: ['ios'],
    );
    final surfaces = manifest.entries.single.surfaces;
    expect(
      surfaces.includes(AgentManifestSurface.appleAppShortcuts, defaultValue: true),
      isFalse,
    );
    expect(
      surfaces.includes(AgentManifestSurface.appleAppIntents, defaultValue: false),
      isTrue,
    );
    expect(
      surfaces.includes(AgentManifestSurface.webMcp, defaultValue: true),
      isFalse,
    );
  });

  test('ios enabled with explicit apple.appShortcuts true honors overlay', () {
    const merger = ManifestMerger();
    const policy = ProjectionPolicy(
      defaultSurfaces: AgentManifestSurfacePolicy({
        AgentManifestSurface.appleAppShortcuts:
            AgentManifestSurfaceExposure(include: true),
      }),
    );
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
      enabledPlatforms: ['ios'],
    );
    expect(
      manifest.entries.single.surfaces.includes(
        AgentManifestSurface.appleAppShortcuts,
        defaultValue: false,
      ),
      isTrue,
    );
  });
}
