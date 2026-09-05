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
  /// Apple sub-channels: [AgentManifestSurface.appleAppIntents],
  /// [AgentManifestSurface.appleAppShortcuts],
  /// [AgentManifestSurface.appleSpotlight], and
  /// [AgentManifestSurface.appleEntities].
  final Map<AgentManifestSurface, bool> surfaces;
}
