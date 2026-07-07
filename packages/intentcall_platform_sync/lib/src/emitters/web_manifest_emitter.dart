import 'dart:convert';

import '../agent_manifest.dart';

/// Patches [web/manifest.json] with agent shortcuts and protocol handlers.
final class WebManifestEmitter {
  const WebManifestEmitter({
    this.invokePath = '/agent/invoke',
    this.protocol = 'web+intentcall',
  });

  final String invokePath;
  final String protocol;

  String emit({
    required final String existingManifestJson,
    required final AgentManifest manifest,
  }) {
    final base = jsonDecode(existingManifestJson);
    if (base is! Map) {
      throw const FormatException('web/manifest.json must be a JSON object');
    }
    final map = Map<String, Object?>.from(base.cast<String, Object?>());

    final shortcutTools = manifest.tools.where(
      (final tool) => tool.surfaces.includes(
        AgentManifestSurface.webManifestShortcuts,
        defaultValue: false,
      ),
    );
    final protocolTools = manifest.tools.where(
      (final tool) => tool.surfaces.includes(
        AgentManifestSurface.webProtocolHandlers,
        defaultValue: false,
      ),
    );

    map['shortcuts'] = shortcutTools
        .map(
          (final tool) => <String, Object?>{
            'name': _humanize(tool.name),
            'short_name': _humanize(tool.name),
            'description': tool.description,
            'url': _invokeUrl(tool.qualifiedName),
          },
        )
        .toList(growable: false);

    final protocolHandlerRows = protocolTools
        .map(
          (final tool) => <String, Object?>{
            'protocol': protocol,
            'url':
                '$invokePath?name=${Uri.encodeQueryComponent(tool.qualifiedName)}&payload=%s',
          },
        )
        .toList(growable: false);
    map['protocol_handlers'] = <Map<String, Object?>>[
      if (protocolHandlerRows.isNotEmpty)
        <String, Object?>{
          'protocol': protocol,
          'url': '$invokePath?protocol=%s',
        },
      ...protocolHandlerRows,
    ];

    return const JsonEncoder.withIndent('    ').convert(map);
  }

  String _invokeUrl(final String qualifiedName) =>
      '$invokePath?name=${Uri.encodeQueryComponent(qualifiedName)}';

  String _humanize(final String name) =>
      name.split('_').map(_titleCaseWord).join(' ');
}

String _titleCaseWord(final String word) {
  if (word.isEmpty) {
    return word;
  }
  return '${word[0].toUpperCase()}${word.substring(1)}';
}
