import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';

/// Builds `agent_manifest.json` for Android App Actions / shortcuts (Phase 3).
String generateAndroidAgentManifest(
  final Iterable<AgentIntentDescriptor> descriptors, {
  final String? protocolScheme,
}) {
  final shortcuts = <Map<String, Object?>>[];
  for (final descriptor in descriptors) {
    final resolvedResourceUri = _manifestResourceUri(
      descriptor,
      protocolScheme,
    );
    shortcuts.add(<String, Object?>{
      'qualifiedName': descriptor.qualifiedName,
      'namespace': descriptor.namespace,
      'name': descriptor.name,
      'description': descriptor.description,
      'kind': descriptor.kind.name,
      'resourceUri': ?resolvedResourceUri,
      'inputSchema': descriptor.inputSchema,
    });
  }
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'version': 1,
    'platform': 'android',
    'shortcuts': shortcuts,
  });
}

String? _manifestResourceUri(
  final AgentIntentDescriptor descriptor,
  final String? protocolScheme,
) {
  if (descriptor.resourceUri != null) {
    return descriptor.resourceUri;
  }
  if (descriptor.kind != AgentIntentKind.resource) {
    return null;
  }
  final scheme = protocolScheme?.trim() ?? '';
  if (scheme.isEmpty) {
    return null;
  }
  return descriptor.effectiveResourceUri(scheme);
}
