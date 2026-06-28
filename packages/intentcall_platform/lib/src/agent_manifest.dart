import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';

/// Supported [agent_manifest.json] schema version.
const kAgentManifestSchemaVersion = 1;

/// Manifest-local native dispatch behavior.
enum AgentManifestDispatchMode { inlineRuntime, openApp, queueOnly }

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
    this.includeInShortcuts = false,
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
    return AgentManifestEntry(
      qualifiedName: qualifiedName,
      namespace: namespace,
      name: name,
      description: '${json['description'] ?? ''}'.trim(),
      kind: AgentIntentKind.values.byName(kindName),
      inputSchema: _readInputSchema(json['inputSchema']),
      dispatchMode: _readDispatchMode(json['dispatchMode']),
      includeInShortcuts: _readIncludeInShortcuts(json['includeInShortcuts']),
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
  final bool includeInShortcuts;
  final String? resourceUri;

  Map<String, Object?> toJson() => <String, Object?>{
    'qualifiedName': qualifiedName,
    'namespace': namespace,
    'name': name,
    'description': description,
    'kind': kind.name,
    'dispatchMode': dispatchMode.name,
    'includeInShortcuts': includeInShortcuts,
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

bool _readIncludeInShortcuts(final Object? value) {
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  throw const FormatException('includeInShortcuts must be a boolean.');
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
