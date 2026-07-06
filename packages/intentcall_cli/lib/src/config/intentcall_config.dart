import 'package:yaml/yaml.dart';

/// Parsed `intentcall.yaml` v1 host wiring (no per-tool descriptor rows).
final class IntentCallConfig {
  const IntentCallConfig({
    this.host = IntentCallHost.custom,
    this.protocolScheme,
    this.layout = const IntentCallLayout(),
    this.platforms = const IntentCallPlatforms(),
    this.defaults = const IntentCallProjectionDefaults(),
    this.projectionOverlay,
    this.hooks = const IntentCallHooks(),
    this.sourcePath,
  });

  factory IntentCallConfig.fromYamlMap(
    final Map<Object?, Object?> yaml, {
    final String? sourcePath,
  }) {
    final hostName = yaml['host']?.toString().trim();
    final host = tryParseIntentCallHost(hostName) ?? IntentCallHost.custom;

    final layoutRaw = yaml['layout'];
    final layout = layoutRaw is Map
        ? IntentCallLayout.fromYamlMap(layoutRaw)
        : const IntentCallLayout();

    final platformsRaw = yaml['platforms'];
    final platforms = platformsRaw is Map
        ? IntentCallPlatforms.fromYamlMap(platformsRaw)
        : const IntentCallPlatforms();

    final defaultsRaw = yaml['defaults'];
    final defaults = defaultsRaw is Map
        ? IntentCallProjectionDefaults.fromYamlMap(defaultsRaw)
        : const IntentCallProjectionDefaults();

    final hooksRaw = yaml['hooks'];
    final hooks = hooksRaw is Map
        ? IntentCallHooks.fromYamlMap(hooksRaw)
        : const IntentCallHooks();

    final overlay = yaml['projectionOverlay']?.toString().trim();
    return IntentCallConfig(
      host: host,
      protocolScheme: _nonEmpty(yaml['protocolScheme']?.toString()),
      layout: layout,
      platforms: platforms,
      defaults: defaults,
      projectionOverlay: overlay?.isEmpty ?? true ? null : overlay,
      hooks: hooks,
      sourcePath: sourcePath,
    );
  }

  factory IntentCallConfig.parse(final String yamlText, {final String? sourcePath}) {
    final doc = loadYaml(yamlText);
    if (doc is! YamlMap) {
      throw FormatException('intentcall.yaml must be a YAML mapping.');
    }
    return IntentCallConfig.fromYamlMap(doc, sourcePath: sourcePath);
  }

  final IntentCallHost host;
  final String? protocolScheme;
  final IntentCallLayout layout;
  final IntentCallPlatforms platforms;
  final IntentCallProjectionDefaults defaults;
  final String? projectionOverlay;
  final IntentCallHooks hooks;
  final String? sourcePath;

  Map<String, Object?> toJson() => <String, Object?>{
    'host': host.name,
    if (protocolScheme != null) 'protocolScheme': protocolScheme,
    'layout': layout.toJson(),
    'platforms': platforms.toJson(),
    'defaults': defaults.toJson(),
    if (projectionOverlay != null) 'projectionOverlay': projectionOverlay,
    'hooks': hooks.toJson(),
    if (sourcePath != null) 'sourcePath': sourcePath,
  };
}

enum IntentCallHost { flutter, jaspr, dart, custom }

IntentCallHost? tryParseIntentCallHost(final String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return switch (value.toLowerCase()) {
    'flutter' => IntentCallHost.flutter,
    'jaspr' => IntentCallHost.jaspr,
    'dart' => IntentCallHost.dart,
    'custom' => IntentCallHost.custom,
    _ => null,
  };
}

/// Layout paths for generated artifacts.
final class IntentCallLayout {
  const IntentCallLayout({
    this.manifest = 'web/agent_manifest.json',
    this.webDir = 'web',
  });

  factory IntentCallLayout.fromYamlMap(final Map<Object?, Object?> yaml) =>
      IntentCallLayout(
        manifest: yaml['manifest']?.toString() ?? 'web/agent_manifest.json',
        webDir: yaml['webDir']?.toString() ?? 'web',
      );

  final String manifest;
  final String webDir;

  Map<String, Object?> toJson() => <String, Object?>{
    'manifest': manifest,
    'webDir': webDir,
  };
}

/// Enabled platform targets for sync hooks.
final class IntentCallPlatforms {
  const IntentCallPlatforms({this.enabled = const <String>[]});

  factory IntentCallPlatforms.fromYamlMap(final Map<Object?, Object?> yaml) {
    final enabledRaw = yaml['enabled'];
    final enabled = <String>[];
    if (enabledRaw is YamlList) {
      for (final value in enabledRaw) {
        final name = value?.toString().trim();
        if (name != null && name.isNotEmpty) {
          enabled.add(name.toLowerCase());
        }
      }
    }
    return IntentCallPlatforms(enabled: enabled);
  }

  final List<String> enabled;

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
  };
}

/// Global projection defaults merged into [ProjectionPolicy].
final class IntentCallProjectionDefaults {
  const IntentCallProjectionDefaults({
    this.dispatchMode,
    this.surfaces = const <String, bool>{},
  });

  factory IntentCallProjectionDefaults.fromYamlMap(
    final Map<Object?, Object?> yaml,
  ) {
    final surfaces = <String, bool>{};
    final surfacesRaw = yaml['surfaces'];
    if (surfacesRaw is Map) {
      for (final entry in surfacesRaw.entries) {
        if (entry.value is bool) {
          surfaces[entry.key.toString()] = entry.value as bool;
        }
      }
    }
    return IntentCallProjectionDefaults(
      dispatchMode: yaml['dispatchMode']?.toString(),
      surfaces: surfaces,
    );
  }

  final String? dispatchMode;
  final Map<String, bool> surfaces;

  Map<String, Object?> toJson() => <String, Object?>{
    if (dispatchMode != null) 'dispatchMode': dispatchMode,
    if (surfaces.isNotEmpty) 'surfaces': surfaces,
  };
}

/// Build hook command wiring.
final class IntentCallHooks {
  const IntentCallHooks({this.syncCommand});

  factory IntentCallHooks.fromYamlMap(final Map<Object?, Object?> yaml) =>
      IntentCallHooks(syncCommand: _nonEmpty(yaml['syncCommand']?.toString()));

  final String? syncCommand;

  Map<String, Object?> toJson() => <String, Object?>{
    if (syncCommand != null) 'syncCommand': syncCommand,
  };
}

String? _nonEmpty(final String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
