import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

void main() {
  test('every exported tool row has all surface keys with bool include', () {
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
    final json = manifest.entries.single.toJson();
    final surfaces = json['surfaces']! as Map<String, Object?>;
    expect(surfaces.length, AgentManifestSurface.values.length);
    for (final entry in surfaces.entries) {
      final exposure = entry.value! as Map<String, Object?>;
      expect(exposure['include'], isA<bool>());
    }
  });
}
