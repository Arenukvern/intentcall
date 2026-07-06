import 'package:intentcall_core/intentcall_core.dart';

import '../projection/projection_policy.dart';

/// One registry-backed row aggregated for manifest generation.
final class AgentRegistryCatalogEntry {
  const AgentRegistryCatalogEntry({
    required this.registryKey,
    this.descriptor,
    this.entry,
    this.projection,
  }) : assert(descriptor != null || entry != null);

  final String registryKey;
  final AgentIntentDescriptor? descriptor;
  final AgentCallEntry? entry;

  /// Per-tool projection from `@AgentProjection` or a handwritten catalog row.
  final EntryProjection? projection;

  AgentIntentDescriptor resolveDescriptor() =>
      descriptor ?? entry!.toRegistration().descriptor;

  String get qualifiedName => resolveDescriptor().qualifiedName;
}
