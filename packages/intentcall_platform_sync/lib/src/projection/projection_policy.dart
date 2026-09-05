import '../agent_manifest.dart';

/// Default surface inclusion when no per-entry override exists.
bool defaultSurfaceInclude(final AgentManifestSurface surface) =>
    switch (surface) {
      AgentManifestSurface.appleAppIntents ||
      AgentManifestSurface.appleAppShortcuts ||
      AgentManifestSurface.appleSpotlight ||
      AgentManifestSurface.appleEntities => false,
      AgentManifestSurface.androidShortcuts ||
      AgentManifestSurface.webManifestShortcuts ||
      AgentManifestSurface.webProtocolHandlers ||
      AgentManifestSurface.webMcp ||
      AgentManifestSurface.windowsProtocolActivation ||
      AgentManifestSurface.windowsMsixProtocol ||
      AgentManifestSurface.linuxSchemeHandler => true,
    };

/// Platform tokens required for a manifest surface family to default on.
Set<String> platformsForManifestSurface(final AgentManifestSurface surface) =>
    switch (surface) {
      AgentManifestSurface.webMcp ||
      AgentManifestSurface.webManifestShortcuts ||
      AgentManifestSurface.webProtocolHandlers => {'web'},
      AgentManifestSurface.androidShortcuts => {'android'},
      AgentManifestSurface.appleAppIntents ||
      AgentManifestSurface.appleAppShortcuts ||
      AgentManifestSurface.appleSpotlight ||
      AgentManifestSurface.appleEntities => {'ios', 'macos'},
      AgentManifestSurface.windowsProtocolActivation ||
      AgentManifestSurface.windowsMsixProtocol => {'windows'},
      AgentManifestSurface.linuxSchemeHandler => {'linux'},
    };

bool defaultSurfaceIncludeForPlatforms(
  final AgentManifestSurface surface,
  final Set<String> enabledPlatforms,
) {
  // ADR 0016 / 0022: shortcuts, entities, spotlight never auto-enable.
  if (surface == AgentManifestSurface.appleAppShortcuts ||
      surface == AgentManifestSurface.appleSpotlight ||
      surface == AgentManifestSurface.appleEntities) {
    return false;
  }
  // ADR 0022: App Intent structs default on for ios/macos when platforms scoped.
  if (surface == AgentManifestSurface.appleAppIntents) {
    if (enabledPlatforms.isEmpty) {
      return defaultSurfaceInclude(surface);
    }
    return enabledPlatforms.contains('ios') ||
        enabledPlatforms.contains('macos');
  }
  if (enabledPlatforms.isEmpty) {
    return defaultSurfaceInclude(surface);
  }
  final required = platformsForManifestSurface(surface);
  return required.any(enabledPlatforms.contains);
}

/// Per-entry projection overlay (dispatch + surfaces only).
final class EntryProjection {
  const EntryProjection({
    this.dispatchMode,
    this.inlineRuntime,
    this.surfaces = const <AgentManifestSurface, bool>{},
  });

  factory EntryProjection.fromYamlMap(final Map<Object?, Object?> yaml) {
    final dispatchName = yaml['dispatchMode']?.toString();
    final dispatchMode = dispatchName == null
        ? null
        : AgentManifestDispatchMode.values.byName(dispatchName);
    final surfaces = <AgentManifestSurface, bool>{};
    final surfacesRaw = yaml['surfaces'];
    if (surfacesRaw is Map) {
      for (final entry in surfacesRaw.entries) {
        if (entry.value is! bool) {
          continue;
        }
        surfaces[resolveAgentManifestSurface(entry.key.toString())] =
            entry.value as bool;
      }
    }
    return EntryProjection(
      dispatchMode: dispatchMode,
      inlineRuntime: _readInlineRuntimeFromYaml(yaml['inlineRuntime']),
      surfaces: surfaces,
    );
  }

  final AgentManifestDispatchMode? dispatchMode;
  final AgentManifestInlineRuntime? inlineRuntime;
  final Map<AgentManifestSurface, bool> surfaces;

  AgentManifestSurfacePolicy resolveSurfaces({
    required final AgentManifestSurfacePolicy defaults,
  }) {
    if (surfaces.isEmpty) {
      return defaults;
    }
    final overrides =
        Map<AgentManifestSurface, AgentManifestSurfaceExposure>.from(
          defaults.overrides,
        );
    for (final entry in surfaces.entries) {
      overrides[entry.key] = AgentManifestSurfaceExposure(include: entry.value);
    }
    return AgentManifestSurfacePolicy(overrides);
  }
}

/// Global defaults + per-qualified-name overlays for manifest merge.
final class ProjectionPolicy {
  const ProjectionPolicy({
    this.defaultDispatchMode = AgentManifestDispatchMode.openApp,
    this.defaultSurfaces = AgentManifestSurfacePolicy.empty,
    this.overlays = const <String, EntryProjection>{},
  });

  factory ProjectionPolicy.fromYamlMap(final Map<Object?, Object?> yaml) {
    final defaultsRaw = yaml['defaults'];
    var dispatchMode = AgentManifestDispatchMode.openApp;
    var defaultSurfaces = AgentManifestSurfacePolicy.empty;
    if (defaultsRaw is Map) {
      final dispatchName = defaultsRaw['dispatchMode']?.toString();
      if (dispatchName != null) {
        dispatchMode = AgentManifestDispatchMode.values.byName(dispatchName);
      }
      final surfacesRaw = defaultsRaw['surfaces'];
      if (surfacesRaw is Map) {
        final overrides =
            <AgentManifestSurface, AgentManifestSurfaceExposure>{};
        for (final entry in surfacesRaw.entries) {
          if (entry.value is! bool) {
            continue;
          }
          overrides[resolveAgentManifestSurface(entry.key.toString())] =
              AgentManifestSurfaceExposure(include: entry.value as bool);
        }
        defaultSurfaces = AgentManifestSurfacePolicy(overrides);
      }
    }

    return ProjectionPolicy(
      defaultDispatchMode: dispatchMode,
      defaultSurfaces: defaultSurfaces,
    );
  }

  final AgentManifestDispatchMode defaultDispatchMode;
  final AgentManifestSurfacePolicy defaultSurfaces;
  final Map<String, EntryProjection> overlays;

  ProjectionPolicy mergeOverlays(final Map<String, EntryProjection> more) =>
      ProjectionPolicy(
        defaultDispatchMode: defaultDispatchMode,
        defaultSurfaces: defaultSurfaces,
        overlays: <String, EntryProjection>{...overlays, ...more},
      );

  EntryProjection? overlayFor(final String qualifiedName) =>
      overlays[qualifiedName];

  AgentManifestSurfacePolicy resolvedDefaultSurfaces({
    final Iterable<String> enabledPlatforms = const [],
  }) {
    final normalized = enabledPlatforms
        .map((final platform) => platform.trim().toLowerCase())
        .where((final platform) => platform.isNotEmpty)
        .toSet();
    final overrides = <AgentManifestSurface, AgentManifestSurfaceExposure>{};
    for (final surface in AgentManifestSurface.values) {
      final explicit = defaultSurfaces.overrides[surface]?.include;
      final include =
          explicit ?? defaultSurfaceIncludeForPlatforms(surface, normalized);
      overrides[surface] = AgentManifestSurfaceExposure(include: include);
    }
    return AgentManifestSurfacePolicy(overrides);
  }
}

AgentManifestInlineRuntime? _readInlineRuntimeFromYaml(final Object? value) {
  if (value is! Map) {
    return null;
  }
  final kindName = value['kind']?.toString();
  if (kindName == null) {
    return null;
  }
  final kind = AgentManifestInlineRuntimeKind.values.byName(kindName);
  return AgentManifestInlineRuntime(kind: kind);
}
