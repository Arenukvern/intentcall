/// Platform projection hints for generated [agent_manifest.json] rows.
///
/// Types resolve through [intentcall_platform_sync] at build time.
class AgentProjection {
  const AgentProjection({
    this.dispatchMode = 'openApp',
    this.surfaces = const <String, bool>{},
  });

  /// `openApp`, `inlineRuntime`, or `queueOnly`.
  final String dispatchMode;

  /// Surface keys such as `web.webMcp`, `apple.appShortcuts`.
  final Map<String, bool> surfaces;
}
