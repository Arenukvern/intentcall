/// Builds `$protocolScheme://resource/...` from underscore-separated segments.
///
/// Example: `cool_runtime_snapshot` with scheme `demoapp` →
/// `demoapp://resource/spark/runtime/snapshot`.
///
/// Returns `$protocolScheme://resource/unknown` when [resourceName] is empty.
String resourceUri({
  required final String protocolScheme,
  required final String resourceName,
}) {
  if (resourceName.isEmpty) {
    return '$protocolScheme://resource/unknown';
  }
  return '$protocolScheme://resource/${resourceName.split('_').join('/')}';
}
