/// VM-safe fallback for host tests and non-Flutter analysis.
final class IntentCallInvokeLinkListener {
  IntentCallInvokeLinkListener({
    required this.protocolScheme,
    required this.onQualifiedName,
  });

  final String protocolScheme;
  final void Function(String qualifiedName) onQualifiedName;

  static String? qualifiedNameFromUri(
    final Uri uri, {
    required final String protocolScheme,
  }) {
    if (uri.scheme != protocolScheme) {
      return null;
    }
    if (uri.host != 'invoke') {
      return null;
    }
    final raw = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> start() async {}

  Future<void> dispose() async {}
}
