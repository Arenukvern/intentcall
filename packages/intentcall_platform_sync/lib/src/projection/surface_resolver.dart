import '../agent_manifest.dart';
import 'projection_policy.dart';

/// Returns a dense [AgentManifestSurfacePolicy] with all surfaces resolved.
AgentManifestSurfacePolicy resolveEntrySurfaces({
  required final AgentManifestSurfacePolicy defaultSurfaces,
  final EntryProjection? overlay,
}) {
  final overrides =
      Map<AgentManifestSurface, AgentManifestSurfaceExposure>.from(
        defaultSurfaces.overrides,
      );
  if (overlay != null) {
    for (final entry in overlay.surfaces.entries) {
      overrides[entry.key] = AgentManifestSurfaceExposure(include: entry.value);
    }
  }
  return AgentManifestSurfacePolicy(_denseOverrides(overrides));
}

Map<AgentManifestSurface, AgentManifestSurfaceExposure> _denseOverrides(
  final Map<AgentManifestSurface, AgentManifestSurfaceExposure> sparse,
) {
  final out = <AgentManifestSurface, AgentManifestSurfaceExposure>{};
  for (final surface in AgentManifestSurface.values) {
    final exposure = sparse[surface];
    out[surface] = AgentManifestSurfaceExposure(
      include: exposure?.include ?? false,
    );
  }
  return Map.unmodifiable(out);
}
