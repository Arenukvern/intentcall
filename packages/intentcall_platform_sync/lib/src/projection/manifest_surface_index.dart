import '../agent_manifest.dart';

/// Fast lookup of per-tool surface policy from a parsed [AgentManifest].
final class ManifestSurfaceIndex {
  ManifestSurfaceIndex.fromManifest(final AgentManifest manifest)
    : _byQualifiedName = {
        for (final entry in manifest.entries) entry.qualifiedName: entry.surfaces,
      };

  final Map<String, AgentManifestSurfacePolicy> _byQualifiedName;

  bool includes(
    final String qualifiedName,
    final AgentManifestSurface surface, {
    required final bool defaultValue,
  }) {
    final policy = _byQualifiedName[qualifiedName];
    if (policy == null) {
      return defaultValue;
    }
    return policy.includes(surface, defaultValue: defaultValue);
  }

  bool includesWebMcp(final String qualifiedName) => includes(
    qualifiedName,
    AgentManifestSurface.webMcp,
    defaultValue: false,
  );
}
