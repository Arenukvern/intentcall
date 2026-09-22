import 'dart:io';

import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_platform_sync/io.dart';

/// Publishes the Flutter process as the link owner for [protocolScheme].
///
/// The returned function closes the socket. It does not redraw the app.
Future<Future<void> Function()?> publishIntentCallSurfaceLink({
  required final IntentCallNativeBridge bridge,
  required final String protocolScheme,
  final String owner = 'flutter',
  final String? linkDirectory,
}) async {
  final hub = AgentInvocationHub(bridge: bridge, registry: bridge.registry);
  final surface = await AgentWebSocketSurface.serve(
    link: hub,
    protocolScheme: protocolScheme,
    owner: owner,
    directory: linkDirectory == null
        ? null
        : AgentLinkDirectory(root: Directory(linkDirectory)),
  );
  return () async {
    await surface.close();
    await hub.close();
  };
}
