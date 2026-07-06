/// Shared helpers for platform artifact emitters.
String humanizeAgentName(final String name) =>
    name.split('_').map(_titleCaseWord).join(' ');

String _titleCaseWord(final String word) {
  if (word.isEmpty) {
    return word;
  }
  return '${word[0].toUpperCase()}${word.substring(1)}';
}

/// `app_cart_total` → `AppCartTotalIntent`
String swiftIntentTypeName(final String qualifiedName) {
  final parts = qualifiedName.split('_').where((final p) => p.isNotEmpty);
  final base = parts.map(_titleCaseWord).join();
  return '${base}Intent';
}

String escapeXml(final String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String escapeSwiftString(final String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

String requireProtocolScheme(
  final String? protocolScheme, {
  required final String artifact,
}) {
  final scheme = protocolScheme?.trim() ?? '';
  if (scheme.isEmpty) {
    throw StateError(
      '$artifact needs an app-owned protocolScheme. Set "protocolScheme" in '
      'agent_manifest.json or pass one to the emitter/sync API.',
    );
  }
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*$').hasMatch(scheme)) {
    throw FormatException('Invalid protocol scheme "$scheme" for $artifact.');
  }
  return scheme;
}

String invokeUri({
  required final String protocolScheme,
  required final String qualifiedName,
}) => '$protocolScheme://invoke/$qualifiedName';
