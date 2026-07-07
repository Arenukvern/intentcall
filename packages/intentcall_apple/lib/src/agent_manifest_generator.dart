import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';

/// Builds `agent_manifest.json` for App Intents / Shortcuts codegen (Phase 3).
String generateAppleAgentManifest(
  final Iterable<AgentIntentDescriptor> descriptors, {
  final Iterable<AgentEntityTypeDescriptor> entityTypeDescriptors = const [],
  final Iterable<Map<String, Object?>> entityTypes = const [],
}) {
  final intents = <Map<String, Object?>>[];
  for (final descriptor in descriptors) {
    intents.add(<String, Object?>{
      'qualifiedName': descriptor.qualifiedName,
      'namespace': descriptor.namespace,
      'name': descriptor.name,
      'description': descriptor.description,
      'kind': descriptor.kind.name,
      if (descriptor.kind == AgentIntentKind.resource)
        'resourceUri': descriptor.effectiveResourceUri,
      if (descriptor.mimeType != null) 'mimeType': descriptor.mimeType,
      'inputSchema': descriptor.inputSchema,
    });
  }
  final entities = <Map<String, Object?>>[
    ...entityTypeDescriptors.map(_entityTypeDescriptorManifest),
    ...entityTypes.map(Map<String, Object?>.from),
  ];
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'version': 1,
    'platform': 'apple',
    'intents': intents,
    if (entities.isNotEmpty) 'entityTypes': entities,
  });
}

Map<String, Object?> _entityTypeDescriptorManifest(
  final AgentEntityTypeDescriptor descriptor,
) {
  final keys = AgentEntitySnapshotKeys.fromDescriptor(descriptor);
  return <String, Object?>{
    'qualifiedName': descriptor.qualifiedName,
    'namespace': descriptor.namespace,
    'name': descriptor.name,
    'displayName': descriptor.displayName ?? _humanizeName(descriptor.name),
    'idKey': keys.idKey,
    'titleKey': keys.titleKey,
    'subtitleKey': keys.subtitleKey,
    'keywordsKey': keys.keywordsKey,
    'snapshotSchema': agentEntitySnapshotSchema(descriptor),
  };
}

String _humanizeName(final String name) {
  final parts = name
      .split(RegExp(r'[_\s-]+'))
      .where((final part) => part.trim().isNotEmpty);
  if (parts.isEmpty) {
    return name;
  }
  return parts
      .map((final part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
