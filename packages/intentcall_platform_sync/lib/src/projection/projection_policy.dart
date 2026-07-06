import '../agent_manifest.dart';

/// Default surface inclusion when no per-entry override exists.
bool defaultSurfaceInclude(final AgentManifestSurface surface) =>
    switch (surface) {
      AgentManifestSurface.appleAppShortcuts => false,
      AgentManifestSurface.androidShortcuts ||
      AgentManifestSurface.webManifestShortcuts ||
      AgentManifestSurface.webProtocolHandlers ||
      AgentManifestSurface.webMcp ||
      AgentManifestSurface.windowsProtocolActivation ||
      AgentManifestSurface.windowsMsixProtocol ||
      AgentManifestSurface.linuxSchemeHandler => true,
    };

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
    this.defaultSurfaces = const AgentManifestSurfacePolicy(
      <AgentManifestSurface, AgentManifestSurfaceExposure>{},
    ),
    this.overlays = const <String, EntryProjection>{},
  });

  factory ProjectionPolicy.fromYamlMap(final Map<Object?, Object?> yaml) {
    final defaultsRaw = yaml['defaults'];
    var dispatchMode = AgentManifestDispatchMode.openApp;
    var defaultSurfaces = const AgentManifestSurfacePolicy(
      <AgentManifestSurface, AgentManifestSurfaceExposure>{},
    );
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

  AgentManifestSurfacePolicy resolvedDefaultSurfaces() {
    if (!defaultSurfaces.isEmpty) {
      return defaultSurfaces;
    }
    final overrides = <AgentManifestSurface, AgentManifestSurfaceExposure>{};
    for (final surface in AgentManifestSurface.values) {
      overrides[surface] = AgentManifestSurfaceExposure(
        include: defaultSurfaceInclude(surface),
      );
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
