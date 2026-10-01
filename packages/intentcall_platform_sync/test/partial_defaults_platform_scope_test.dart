import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

void main() {
  test('partial yaml defaults merge with platform scope', () {
    const merger = ManifestMerger();
    const policy = ProjectionPolicy(
      defaultSurfaces: AgentManifestSurfacePolicy({
        AgentManifestSurface.webMcp: AgentManifestSurfaceExposure(include: true),
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
      enabledPlatforms: ['web'],
    );
    final surfaces = manifest.entries.single.surfaces;
    expect(
      surfaces.includes(AgentManifestSurface.webMcp, defaultValue: false),
      isTrue,
    );
    expect(
      surfaces.includes(
        AgentManifestSurface.androidShortcuts,
        defaultValue: true,
      ),
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
