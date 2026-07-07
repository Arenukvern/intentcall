import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';

/// Supported [agent_manifest.json] schema version.
const kAgentManifestSchemaVersion = 1;

/// Manifest-local native dispatch behavior.
enum AgentManifestDispatchMode { inlineRuntime, openApp, queueOnly }

/// Runtime implementation used for [AgentManifestDispatchMode.inlineRuntime].
enum AgentManifestInlineRuntimeKind { nativeInline, dartExtensionInline }

/// Apple runtime target for inline dispatch.
enum AgentManifestAppleInlineRuntimeTarget { mainApp, appIntentsExtension }

/// App Intents typed value returned by an inline runtime.
enum AgentManifestInlineRuntimeResultType { string, integer, number, boolean }

/// Typed result metadata for inline runtime dispatch.
final class AgentManifestInlineRuntimeResult {
  const AgentManifestInlineRuntimeResult({
    required this.type,
    this.dataKey = 'value',
  });

  final AgentManifestInlineRuntimeResultType type;

  /// Key read from `AgentResult.data` for Dart-backed inline runtimes.
  ///
  /// Native Swift inline handlers return the typed value directly through
  /// `IntentCallInlineRuntimeResult.value`.
  final String dataKey;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.name,
    'dataKey': dataKey,
  };
}

/// Apple-specific inline runtime metadata.
final class AgentManifestAppleInlineRuntime {
  const AgentManifestAppleInlineRuntime({required this.target});

  final AgentManifestAppleInlineRuntimeTarget target;

  Map<String, Object?> toJson() => <String, Object?>{'target': target.name};
}

/// Platform-specific inline runtime metadata.
final class AgentManifestInlineRuntimePlatforms {
  const AgentManifestInlineRuntimePlatforms({this.apple});

  final AgentManifestAppleInlineRuntime? apple;

  bool get isEmpty => apple == null;

  Map<String, Object?> toJson() => <String, Object?>{
    if (apple != null) 'apple': apple!.toJson(),
  };
}

/// Inline runtime selection metadata.
final class AgentManifestInlineRuntime {
  const AgentManifestInlineRuntime({
    required this.kind,
    this.result,
    this.platforms = const AgentManifestInlineRuntimePlatforms(),
  });

  final AgentManifestInlineRuntimeKind kind;
  final AgentManifestInlineRuntimeResult? result;
  final AgentManifestInlineRuntimePlatforms platforms;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    if (result != null) 'result': result!.toJson(),
    if (!platforms.isEmpty) 'platforms': platforms.toJson(),
  };
}

/// Platform projection surfaces that can expose a manifest entry.
enum AgentManifestSurface {
  appleAppIntents,
  appleAppShortcuts,
  appleSpotlight,
  appleEntities,
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
      out[surface.manifestKey] = AgentManifestSurfaceExposure(
        include: exposure?.include ?? false,
        options: exposure?.options ?? const {},
      ).toJson();
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
    this.inlineRuntime,
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
    final dispatchMode = _readDispatchMode(json['dispatchMode']);
    final inlineRuntime = _readInlineRuntime(json['inlineRuntime']);
    if (dispatchMode == AgentManifestDispatchMode.inlineRuntime &&
        inlineRuntime == null) {
      throw const FormatException(
        'dispatchMode "inlineRuntime" requires an inlineRuntime object.',
      );
    }
    if (dispatchMode != AgentManifestDispatchMode.inlineRuntime &&
        inlineRuntime != null) {
      throw const FormatException(
        'inlineRuntime metadata requires dispatchMode "inlineRuntime".',
      );
    }
    return AgentManifestEntry(
      qualifiedName: qualifiedName,
      namespace: namespace,
      name: name,
      description: '${json['description'] ?? ''}'.trim(),
      kind: AgentIntentKind.values.byName(kindName),
      inputSchema: _readInputSchema(json['inputSchema']),
      dispatchMode: dispatchMode,
      inlineRuntime: inlineRuntime,
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
  final AgentManifestInlineRuntime? inlineRuntime;
  final AgentManifestSurfacePolicy surfaces;
  final String? resourceUri;

  Map<String, Object?> toJson() => <String, Object?>{
    'qualifiedName': qualifiedName,
    'namespace': namespace,
    'name': name,
    'description': description,
    'kind': kind.name,
    'dispatchMode': dispatchMode.name,
    if (inlineRuntime != null) 'inlineRuntime': inlineRuntime!.toJson(),
    'surfaces': surfaces.toJson(),
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

/// One entity type row from the top-level `entityTypes` manifest section.
///
/// This stays platform-neutral: emitters decide how to project these snapshot
/// keys into native concepts such as indexed entities or search metadata.
final class AgentManifestEntityType {
  const AgentManifestEntityType({
    required this.qualifiedName,
    required this.namespace,
    required this.name,
    required this.displayName,
    required this.description,
    this.pluralDisplayName,
    this.idKey = 'id',
    this.titleKey = 'title',
    this.subtitleKey = 'subtitle',
    this.keywordsKey = 'keywords',
    this.urlKey = 'url',
    this.defaultQueryLimit = 20,
    this.snapshotSchema = const <String, Object?>{},
  });

  factory AgentManifestEntityType.fromJson(final Map<String, Object?> json) {
    final namespace = '${json['namespace'] ?? ''}'.trim();
    final name = '${json['name'] ?? ''}'.trim();
    final qualifiedName = '${json['qualifiedName'] ?? ''}'.trim().isNotEmpty
        ? '${json['qualifiedName']}'.trim()
        : qualifyName(namespace: namespace, name: name);
    _validateQualifiedName(qualifiedName);
    final displayName = '${json['displayName'] ?? _humanizeName(name)}'.trim();
    if (displayName.isEmpty) {
      throw const FormatException(
        'entityTypes[].displayName must not be empty.',
      );
    }
    final pluralDisplayName =
        '${json['pluralDisplayName'] ?? ''}'.trim().isEmpty
        ? null
        : '${json['pluralDisplayName']}'.trim();
    final defaultQueryLimit = _readPositiveInt(
      json['defaultQueryLimit'],
      field: 'entityTypes[].defaultQueryLimit',
      defaultValue: 20,
    );
    return AgentManifestEntityType(
      qualifiedName: qualifiedName,
      namespace: namespace,
      name: name,
      displayName: displayName,
      description: '${json['description'] ?? ''}'.trim(),
      pluralDisplayName: pluralDisplayName,
      idKey: _readSnapshotKey(
        json['idKey'],
        field: 'entityTypes[].idKey',
        defaultValue: 'id',
      ),
      titleKey: _readSnapshotKey(
        json['titleKey'],
        field: 'entityTypes[].titleKey',
        defaultValue: 'title',
      ),
      subtitleKey: _readSnapshotKey(
        json['subtitleKey'],
        field: 'entityTypes[].subtitleKey',
        defaultValue: 'subtitle',
      ),
      keywordsKey: _readSnapshotKey(
        json['keywordsKey'],
        field: 'entityTypes[].keywordsKey',
        defaultValue: 'keywords',
      ),
      urlKey: _readSnapshotKey(
        json['urlKey'],
        field: 'entityTypes[].urlKey',
        defaultValue: 'url',
      ),
      defaultQueryLimit: defaultQueryLimit,
      snapshotSchema: _readOptionalObject(json['snapshotSchema']),
    );
  }

  final String qualifiedName;
  final String namespace;
  final String name;
  final String displayName;
  final String description;
  final String? pluralDisplayName;
  final String idKey;
  final String titleKey;
  final String subtitleKey;
  final String keywordsKey;
  final String urlKey;
  final int defaultQueryLimit;
  final Map<String, Object?> snapshotSchema;

  Map<String, Object?> toJson() => <String, Object?>{
    'qualifiedName': qualifiedName,
    'namespace': namespace,
    'name': name,
    'displayName': displayName,
    'description': description,
    if (pluralDisplayName != null) 'pluralDisplayName': pluralDisplayName,
    'idKey': idKey,
    'titleKey': titleKey,
    'subtitleKey': subtitleKey,
    'keywordsKey': keywordsKey,
    'urlKey': urlKey,
    'defaultQueryLimit': defaultQueryLimit,
    if (snapshotSchema.isNotEmpty) 'snapshotSchema': snapshotSchema,
  };
}

/// Parsed canonical [agent_manifest.json].
final class AgentManifest {
  const AgentManifest({
    required this.version,
    required this.platform,
    required this.entries,
    this.entityTypes = const <AgentManifestEntityType>[],
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
      entityTypes: _readEntityTypes(json['entityTypes']),
      protocolScheme: _readOptionalProtocolScheme(json['protocolScheme']),
    );
  }

  factory AgentManifest.parse(final String source) =>
      AgentManifest.fromJson(jsonDecode(source) as Map<String, Object?>);

  final int version;
  final String platform;
  final List<AgentManifestEntry> entries;
  final List<AgentManifestEntityType> entityTypes;
  final String? protocolScheme;

  Iterable<AgentManifestEntry> get tools =>
      entries.where((final entry) => entry.kind == AgentIntentKind.tool);

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'platform': platform,
    'tools': entries.map((final e) => e.toJson()).toList(growable: false),
    if (entityTypes.isNotEmpty)
      'entityTypes': entityTypes
          .map((final e) => e.toJson())
          .toList(growable: false),
    if (protocolScheme != null) 'protocolScheme': protocolScheme,
  };

  String encode({final String indent = '  '}) =>
      const JsonEncoder.withIndent('  ').convert(toJson());
}

List<AgentManifestEntityType> _readEntityTypes(final Object? value) {
  if (value == null) {
    return const <AgentManifestEntityType>[];
  }
  if (value is! List) {
    throw const FormatException('entityTypes must be an array.');
  }
  final out = <AgentManifestEntityType>[];
  final seen = <String>{};
  for (final row in value) {
    final map = switch (row) {
      final Map<String, Object?> typed => typed,
      final Map raw => raw.cast<String, Object?>(),
      _ => throw const FormatException('entityTypes entries must be objects.'),
    };
    final entityType = AgentManifestEntityType.fromJson(map);
    if (!seen.add(entityType.qualifiedName)) {
      throw FormatException(
        'Duplicate entityTypes qualifiedName "${entityType.qualifiedName}".',
      );
    }
    out.add(entityType);
  }
  return List<AgentManifestEntityType>.unmodifiable(out);
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

Map<String, Object?> _readOptionalObject(final Object? value) {
  if (value == null) {
    return const <String, Object?>{};
  }
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  throw const FormatException('Expected an object.');
}

String _humanizeName(final String name) {
  final parts = name
      .split(RegExp(r'[_\s-]+'))
      .where((final part) => part.trim().isNotEmpty);
  if (parts.isEmpty) {
    return '';
  }
  return parts
      .map((final part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

int _readPositiveInt(
  final Object? value, {
  required final String field,
  required final int defaultValue,
}) {
  if (value == null) {
    return defaultValue;
  }
  final parsed = switch (value) {
    final int integer => integer,
    final num number => number.toInt(),
    _ => throw FormatException('$field must be a positive integer.'),
  };
  if (parsed <= 0) {
    throw FormatException('$field must be a positive integer.');
  }
  return parsed;
}

String _readSnapshotKey(
  final Object? value, {
  required final String field,
  required final String defaultValue,
}) {
  final key = '${value ?? defaultValue}'.trim();
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) {
    throw FormatException(
      'Invalid $field "$key"; expected a snapshot field identifier.',
    );
  }
  return key;
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

AgentManifestInlineRuntime? _readInlineRuntime(final Object? value) {
  if (value == null) {
    return null;
  }
  final raw = switch (value) {
    final Map<String, Object?> map => map,
    final Map map => map.cast<String, Object?>(),
    _ => throw const FormatException('inlineRuntime must be an object.'),
  };
  return AgentManifestInlineRuntime(
    kind: _readInlineRuntimeKind(raw['kind']),
    result: _readInlineRuntimeResult(raw['result']),
    platforms: _readInlineRuntimePlatforms(raw['platforms']),
  );
}

AgentManifestInlineRuntimeKind _readInlineRuntimeKind(final Object? value) {
  final name = '${value ?? ''}'.trim();
  if (name.isEmpty) {
    throw const FormatException('inlineRuntime.kind is required.');
  }
  for (final kind in AgentManifestInlineRuntimeKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }
  throw FormatException(
    'Invalid inlineRuntime.kind "$name"; expected one of '
    '${AgentManifestInlineRuntimeKind.values.map((final k) => k.name).join(', ')}.',
  );
}

AgentManifestInlineRuntimeResult? _readInlineRuntimeResult(
  final Object? value,
) {
  if (value == null) {
    return null;
  }
  final raw = switch (value) {
    final Map<String, Object?> map => map,
    final Map map => map.cast<String, Object?>(),
    _ => throw const FormatException('inlineRuntime.result must be an object.'),
  };
  final dataKey = '${raw['dataKey'] ?? 'value'}'.trim();
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(dataKey)) {
    throw FormatException(
      'Invalid inlineRuntime.result.dataKey "$dataKey"; expected an identifier.',
    );
  }
  return AgentManifestInlineRuntimeResult(
    type: _readInlineRuntimeResultType(raw['type']),
    dataKey: dataKey,
  );
}

AgentManifestInlineRuntimeResultType _readInlineRuntimeResultType(
  final Object? value,
) {
  final name = '${value ?? ''}'.trim();
  if (name.isEmpty) {
    throw const FormatException('inlineRuntime.result.type is required.');
  }
  for (final type in AgentManifestInlineRuntimeResultType.values) {
    if (type.name == name) {
      return type;
    }
  }
  throw FormatException(
    'Invalid inlineRuntime.result.type "$name"; expected one of '
    '${AgentManifestInlineRuntimeResultType.values.map((final t) => t.name).join(', ')}.',
  );
}

AgentManifestInlineRuntimePlatforms _readInlineRuntimePlatforms(
  final Object? value,
) {
  if (value == null) {
    return const AgentManifestInlineRuntimePlatforms();
  }
  final raw = switch (value) {
    final Map<String, Object?> map => map,
    final Map map => map.cast<String, Object?>(),
    _ => throw const FormatException(
      'inlineRuntime.platforms must be an object.',
    ),
  };
  return AgentManifestInlineRuntimePlatforms(
    apple: _readAppleInlineRuntime(raw['apple']),
  );
}

AgentManifestAppleInlineRuntime? _readAppleInlineRuntime(final Object? value) {
  if (value == null) {
    return null;
  }
  final raw = switch (value) {
    final Map<String, Object?> map => map,
    final Map map => map.cast<String, Object?>(),
    _ => throw const FormatException(
      'inlineRuntime.platforms.apple must be an object.',
    ),
  };
  return AgentManifestAppleInlineRuntime(
    target: _readAppleInlineRuntimeTarget(raw['target']),
  );
}

AgentManifestAppleInlineRuntimeTarget _readAppleInlineRuntimeTarget(
  final Object? value,
) {
  final name = '${value ?? ''}'.trim();
  if (name.isEmpty) {
    throw const FormatException(
      'inlineRuntime.platforms.apple.target is required.',
    );
  }
  for (final target in AgentManifestAppleInlineRuntimeTarget.values) {
    if (target.name == name) {
      return target;
    }
  }
  throw FormatException(
    'Invalid inlineRuntime.platforms.apple.target "$name"; expected one of '
    '${AgentManifestAppleInlineRuntimeTarget.values.map((final t) => t.name).join(', ')}.',
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
    AgentManifestSurface.appleAppIntents => 'apple.appIntents',
    AgentManifestSurface.appleAppShortcuts => 'apple.appShortcuts',
    AgentManifestSurface.appleSpotlight => 'apple.spotlight',
    AgentManifestSurface.appleEntities => 'apple.entities',
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

/// Resolves a manifest surface key without throwing.
AgentManifestSurface? lookupAgentManifestSurface(final String key) {
  final trimmed = key.trim();
  for (final surface in AgentManifestSurface.values) {
    if (surface.manifestKey == trimmed || surface.name == trimmed) {
      return surface;
    }
  }
  return null;
}

/// Resolves a surface key or throws with valid key hints.
AgentManifestSurface resolveAgentManifestSurface(final String key) {
  final surface = lookupAgentManifestSurface(key);
  if (surface != null) {
    return surface;
  }
  final valid = AgentManifestSurface.values
      .map((final s) => '${s.manifestKey} (${s.name})')
      .join(', ');
  throw FormatException('Unknown surface key "$key". Valid keys: $valid');
}
