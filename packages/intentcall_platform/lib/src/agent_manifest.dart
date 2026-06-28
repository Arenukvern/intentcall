import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';

/// Supported [agent_manifest.json] schema version.
const kAgentManifestSchemaVersion = 1;

/// Manifest-local native dispatch behavior.
enum AgentManifestDispatchMode { inlineRuntime, openApp, queueOnly }

/// Platform projection surfaces that can expose a manifest entry.
enum AgentManifestSurface {
  appleAppShortcuts,
  androidShortcuts,
  webManifestShortcuts,
  webProtocolHandlers,
  webMcp,
  windowsProtocolActivation,
  windowsMsixProtocol,
  linuxSchemeHandler,
}

/// Per-surface exposure override.
final class AgentManifestSurfaceExposure {
  const AgentManifestSurfaceExposure({this.include, this.options = const {}});

  final bool? include;
  final Map<String, Object?> options;

  Map<String, Object?> toJson() => <String, Object?>{
    if (include != null) 'include': include,
    ...options,
  };
}

/// Entry-local platform projection policy.
final class AgentManifestSurfacePolicy {
  const AgentManifestSurfacePolicy(this.overrides);

  static const empty = AgentManifestSurfacePolicy(
    <AgentManifestSurface, AgentManifestSurfaceExposure>{},
  );

  final Map<AgentManifestSurface, AgentManifestSurfaceExposure> overrides;

  bool get isEmpty => overrides.isEmpty;

  bool includes(
    final AgentManifestSurface surface, {
    required final bool defaultValue,
  }) => overrides[surface]?.include ?? defaultValue;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{};
    for (final surface in AgentManifestSurface.values) {
      final exposure = overrides[surface];
      if (exposure == null) {
        continue;
      }
      out[surface.manifestKey] = exposure.toJson();
    }
    return out;
  }
}

/// One tool/intent row from [agent_manifest.json].
final class AgentManifestEntry {
  const AgentManifestEntry({
    required this.qualifiedName,
    required this.namespace,
    required this.name,
    required this.description,
    required this.kind,
    required this.inputSchema,
    this.dispatchMode = AgentManifestDispatchMode.openApp,
    this.surfaces = AgentManifestSurfacePolicy.empty,
    this.resourceUri,
  });

  factory AgentManifestEntry.fromJson(final Map<String, Object?> json) {
    final namespace = '${json['namespace'] ?? ''}'.trim();
    final name = '${json['name'] ?? ''}'.trim();
    final qualifiedName = '${json['qualifiedName'] ?? ''}'.trim().isNotEmpty
        ? '${json['qualifiedName']}'.trim()
        : qualifyName(namespace: namespace, name: name);
    _validateQualifiedName(qualifiedName);
    final kindName = '${json['kind'] ?? 'tool'}'.trim();
    if (json.containsKey('includeInShortcuts')) {
      throw const FormatException(
        'includeInShortcuts is not supported; use surfaces["apple.appShortcuts"].',
      );
    }
    return AgentManifestEntry(
      qualifiedName: qualifiedName,
      namespace: namespace,
      name: name,
      description: '${json['description'] ?? ''}'.trim(),
      kind: AgentIntentKind.values.byName(kindName),
      inputSchema: _readInputSchema(json['inputSchema']),
      dispatchMode: _readDispatchMode(json['dispatchMode']),
      surfaces: _readSurfaces(json['surfaces']),
      resourceUri: json['resourceUri'] as String?,
    );
  }

  final String qualifiedName;
  final String namespace;
  final String name;
  final String description;
  final AgentIntentKind kind;
  final Map<String, Object?> inputSchema;
  final AgentManifestDispatchMode dispatchMode;
  final AgentManifestSurfacePolicy surfaces;
  final String? resourceUri;

  Map<String, Object?> toJson() => <String, Object?>{
    'qualifiedName': qualifiedName,
    'namespace': namespace,
    'name': name,
    'description': description,
    'kind': kind.name,
    'dispatchMode': dispatchMode.name,
    if (!surfaces.isEmpty) 'surfaces': surfaces.toJson(),
    if (resourceUri != null) 'resourceUri': resourceUri,
    'inputSchema': inputSchema,
  };

  AgentIntentDescriptor toDescriptor() => AgentIntentDescriptor(
    namespace: namespace,
    name: name,
    description: description,
    kind: kind,
    inputSchema: inputSchema,
    resourceUri: resourceUri,
  );
}

/// Parsed canonical [agent_manifest.json].
final class AgentManifest {
  const AgentManifest({
    required this.version,
    required this.platform,
    required this.entries,
    this.protocolScheme,
  });

  factory AgentManifest.fromJson(final Map<String, Object?> json) {
    final version = json['version'];
    if (version is! num || version.toInt() != kAgentManifestSchemaVersion) {
      throw FormatException(
        'Unsupported agent_manifest.json version: $version '
        '(expected $kAgentManifestSchemaVersion)',
      );
    }

    final entries = <AgentManifestEntry>[];
    for (final row in _entryRows(json)) {
      entries.add(AgentManifestEntry.fromJson(row));
    }

    return AgentManifest(
      version: version.toInt(),
      platform: '${json['platform'] ?? 'unknown'}',
      entries: entries,
      protocolScheme: _readOptionalProtocolScheme(json['protocolScheme']),
    );
  }

  factory AgentManifest.parse(final String source) =>
      AgentManifest.fromJson(jsonDecode(source) as Map<String, Object?>);

  final int version;
  final String platform;
  final List<AgentManifestEntry> entries;
  final String? protocolScheme;

  Iterable<AgentManifestEntry> get tools =>
      entries.where((final entry) => entry.kind == AgentIntentKind.tool);
}

Iterable<Map<String, Object?>> _entryRows(
  final Map<String, Object?> json,
) sync* {
  for (final key in <String>['tools', 'shortcuts', 'intents']) {
    final value = json[key];
    if (value is! List) {
      continue;
    }
    for (final row in value) {
      if (row is Map<String, Object?>) {
        yield row;
        continue;
      }
      if (row is Map) {
        yield row.cast<String, Object?>();
      }
    }
  }
}

Map<String, Object?> _readInputSchema(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const <String, Object?>{'type': 'object'};
}

AgentManifestDispatchMode _readDispatchMode(final Object? value) {
  final name = '${value ?? ''}'.trim();
  if (name.isEmpty) {
    return AgentManifestDispatchMode.openApp;
  }
  for (final mode in AgentManifestDispatchMode.values) {
    if (mode.name == name) {
      return mode;
    }
  }
  throw FormatException(
    'Invalid dispatchMode "$name"; expected one of '
    '${AgentManifestDispatchMode.values.map((final mode) => mode.name).join(', ')}.',
  );
}

AgentManifestSurfacePolicy _readSurfaces(final Object? value) {
  final overrides = <AgentManifestSurface, AgentManifestSurfaceExposure>{};
  if (value != null) {
    final raw = switch (value) {
      final Map<String, Object?> map => map,
      final Map map => map.cast<String, Object?>(),
      _ => throw const FormatException('surfaces must be an object.'),
    };
    for (final entry in raw.entries) {
      final surface = _readSurface(entry.key);
      overrides[surface] = _readSurfaceExposure(entry.value);
    }
  }

  if (overrides.isEmpty) {
    return AgentManifestSurfacePolicy.empty;
  }
  return AgentManifestSurfacePolicy(Map.unmodifiable(overrides));
}

AgentManifestSurface _readSurface(final String key) {
  final trimmed = key.trim();
  for (final surface in AgentManifestSurface.values) {
    if (surface.manifestKey == trimmed) {
      return surface;
    }
  }
  throw FormatException(
    'Invalid surface "$trimmed"; expected one of '
    '${AgentManifestSurface.values.map((final s) => s.manifestKey).join(', ')}.',
  );
}

AgentManifestSurfaceExposure _readSurfaceExposure(final Object? value) {
  if (value is bool) {
    return AgentManifestSurfaceExposure(include: value);
  }
  final raw = switch (value) {
    final Map<String, Object?> map => map,
    final Map map => map.cast<String, Object?>(),
    _ => throw const FormatException(
      'surface exposure must be a boolean or object.',
    ),
  };
  final include = raw['include'];
  if (include != null && include is! bool) {
    throw const FormatException('surface include must be a boolean.');
  }
  return AgentManifestSurfaceExposure(
    include: include as bool?,
    options: Map.unmodifiable(
      Map<String, Object?>.from(raw)..remove('include'),
    ),
  );
}

void _validateQualifiedName(final String qualifiedName) {
  if (!RegExp(r'^[a-z][a-z0-9_]*_[a-z][a-z0-9_]*$').hasMatch(qualifiedName)) {
    throw FormatException(
      'Invalid qualifiedName "$qualifiedName"; expected lowercase '
      'namespace_name identifier.',
    );
  }
}

String? _readOptionalProtocolScheme(final Object? value) {
  final scheme = '${value ?? ''}'.trim();
  if (scheme.isEmpty) {
    return null;
  }
  return scheme;
}

extension AgentManifestSurfaceKey on AgentManifestSurface {
  String get manifestKey => switch (this) {
    AgentManifestSurface.appleAppShortcuts => 'apple.appShortcuts',
    AgentManifestSurface.androidShortcuts => 'android.shortcuts',
    AgentManifestSurface.webManifestShortcuts => 'web.manifestShortcuts',
    AgentManifestSurface.webProtocolHandlers => 'web.protocolHandlers',
    AgentManifestSurface.webMcp => 'web.webMcp',
    AgentManifestSurface.windowsProtocolActivation =>
      'windows.protocolActivation',
    AgentManifestSurface.windowsMsixProtocol => 'windows.msixProtocol',
    AgentManifestSurface.linuxSchemeHandler => 'linux.schemeHandler',
  };
}
