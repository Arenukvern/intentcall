import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

/// VM-only. Web and tests without `dart:io` keep the link unpublished.
Future<Future<void> Function()?> publishIntentCallSurfaceLink({
  required final IntentCallNativeBridge bridge,
  required final String protocolScheme,
  final String owner = 'flutter',
  final String? linkDirectory,
}) async => null;
