import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

/// Platform projection hints for generated [agent_manifest.json] rows.
class AgentProjection {
  const AgentProjection({
    this.dispatchMode = 'openApp',
    this.surfaces = const <AgentManifestSurface, bool>{},
  });

  /// `openApp`, `inlineRuntime`, or `queueOnly`.
  final String dispatchMode;

  /// Per-surface inclusion overrides using typed [AgentManifestSurface] keys.
  ///
  /// Sub-channel hints (for example Apple Siri vs Spotlight) use
  /// [AgentManifestSurfaceExposure.options] on handwritten [EntryProjection]
  /// rows until emitters support them.
  final Map<AgentManifestSurface, bool> surfaces;
}
