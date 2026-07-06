import 'package:intentcall_core/intentcall_core.dart';

/// One registry-backed row aggregated for manifest generation.
final class AgentRegistryCatalogEntry {
  const AgentRegistryCatalogEntry({
    required this.registryKey,
    this.descriptor,
    this.entry,
  }) : assert(descriptor != null || entry != null);

  final String registryKey;
  final AgentIntentDescriptor? descriptor;
  final AgentCallEntry? entry;

  AgentIntentDescriptor resolveDescriptor() =>
      descriptor ?? entry!.toRegistration().descriptor;

  String get qualifiedName => resolveDescriptor().qualifiedName;
}
